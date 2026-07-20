#!/usr/bin/env python3
"""CISCE (ICSE) discovery → DOWNLOAD_QUEUE.json merge (spec Parts 05/06).

Resolves the official CISCE (cisce.org) curriculum resources for the in-scope
canonical matrix (Classes 9-10, core academic subjects, Priority-A curriculum
document types) and merges one queue cell per document into DOWNLOAD_QUEUE.json
(idempotent by resource_id).

The resolved URL list lives in `discovery/icse/cisce_source_urls.json` (each URL
was fetched + V1-V11 verified on a prior official-source discovery run). This
builder applies the canonical-matrix filter so ONLY curriculum content is
queued — class-12, regulations, circulars, time-tables, prescribed-book lists,
and non-core electives are dropped by design (deterministic acquisition, not a
broad crawl). Download + verification is performed by downloader.py through the
certified VerificationEngine.

Usage:
  cisce_catalogue.py [--to-queue]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow, sanitize_filename  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
SOURCE_URLS = "discovery/icse/cisce_source_urls.json"
CISCE_LISTING = "https://cisce.org"

# canonical-matrix filters — anything not mapped here is dropped (out of scope).
CLASS_MAP = {
    "class-6": "6",
    "class-7": "7",
    "class-8": "8",
    "class-9": "9",
    "class-10": "10",
}
SUBJECT_MAP = {
    "mathematics": "mathematics",
    "physics": "physics",
    "chemistry": "chemistry",
    "biology": "biology",
    "geography": "geography",
    "history-and-civics": "history",
    "english": "english",
    "english-language": "english",
    "literature-in-english": "english",
    "computer-applications": "computer_science",
    "general": "__MULTI__",  # upper-primary combined curriculum
}
# CISCE type slug -> (resource_category, document_type, id_token)
TYPE_MAP = {
    "syllabus":             ("syllabus",      "Syllabus",      "SYLL"),
    "specimen-paper":       ("sample_paper",  "Sample Paper",  "SAMP"),
    "competency-questions": ("question_bank", "Question Bank", "QBNK"),
}


def build(ws: Workspace) -> list[dict]:
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    cat_folder = ws.config("download_rules")["category_to_subject_folder"]
    src = load_json(ws.root / SOURCE_URLS)
    if not src:
        return []
    recs = src["documents"] if isinstance(src, dict) else src

    seq = 400  # CISCE cells occupy a distinct seq band
    catalogue: list[dict] = []
    for r in recs:
        ckey = CLASS_MAP.get(r.get("class"))
        raw_skey = SUBJECT_MAP.get(r.get("subject"))
        tinfo = TYPE_MAP.get(r.get("type"))
        if not (ckey and raw_skey and tinfo and r.get("source_url")):
            continue
        category, doc_type, id_token = tinfo
        subject_keys = (
            ws.config("boards")["boards"]["icse"]["subjects_by_class"][ckey]
            if raw_skey == "__MULTI__"
            else [raw_skey]
        )
        for skey in subject_keys:
            clabel = classes[ckey]["class_label"]
            ccode = classes[ckey]["code"]
            subj = subjects[skey]
            seq += 1
            orig = r["source_url"].rsplit("/", 1)[-1]
            stem = sanitize_filename(orig[:-4] if orig.lower().endswith(".pdf") else orig)
            rid = f"AKS-CISCE-{ccode}-{subj['code']}-{id_token}-2025-{seq:06d}"
            fname = f"CISCE_{clabel}_{subj['subject_folder']}_{doc_type.replace(' ', '')}-{stem}_2025-26_v1_English.pdf"
            dest = f"curriculum/icse/{clabel}/{subj['subject_folder']}/{cat_folder.get(category, 'Reference')}"
            catalogue.append({
                "resource_id": rid,
                "expected_filename": fname,
                "original_filename": orig,
                "title": f"CISCE {clabel.replace('_', ' ')} {subj['display']} — {doc_type} ({r.get('title','')})".strip(),
                "document_type": doc_type,
                "resource_category": category,
                "board": "CISCE",
                "class_label": clabel,
                "subject": subj["display"],
                "priority": "A",
                "source_portal": CISCE_LISTING,
                "source_url": r["source_url"],
                "source_website": CISCE_LISTING,
                "publisher": "CISCE",
                "academic_year": "2025-26",
                "language": "English",
                "medium": "English",
                "license_status": "OFFICIAL_PUBLIC_CISCE_CURRICULUM_ANALYSIS_ONLY",
                "license_note": ("CISCE official public curriculum resource (cisce.org), used for "
                                 "blueprint/pattern analysis + local archive only"),
                "destination": dest,
                "alternative_sources": [],
                "search_locations": [CISCE_LISTING, r["source_url"]],
                "discovery_status": "URL_RESOLVED",
                "status": "PENDING",
                "retry_count": 0,
                "cataloged_at": utcnow(),
            })
    return catalogue


def merge_queue(ws: Workspace, catalogue: list[dict]) -> tuple[int, int]:
    queue = load_json(ws.pm("download_queue"), []) or []
    have = {e.get("resource_id") for e in queue}
    added = 0
    for entry in catalogue:
        if entry["resource_id"] not in have:
            queue.append(entry)
            added += 1
    write_json(ws.pm("download_queue"), queue)
    return added, len(queue)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--to-queue", action="store_true")
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    catalogue = build(ws)
    print(f"CISCE catalogue: {len(catalogue)} in-scope canonical cells (Classes 9-10, core subjects)")
    disc_dir = ws.p("discovery_dir") / "icse"
    disc_dir.mkdir(parents=True, exist_ok=True)
    write_json(disc_dir / "cisce_catalogue.json",
               {"generated_at": utcnow(), "source_listing": CISCE_LISTING, "documents": catalogue})
    if args.to_queue:
        added, size = merge_queue(ws, catalogue)
        print(f"queue: merged {added} new CISCE entries (queue size {size})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
