#!/usr/bin/env python3
"""CBSE curriculum/syllabus discovery → DOWNLOAD_QUEUE.json merge (spec Parts 05/06).

Resolves the official CBSE Secondary (Class IX-X) curriculum & syllabus PDFs from
cbseacademic.nic.in (curriculum_2026.html → web_material/CurriculumMain26/Sec/*),
in-scope core academic subjects, and merges one queue cell per document into
DOWNLOAD_QUEUE.json (idempotent by resource_id). Each URL was HEAD-confirmed
200 / application/pdf at discovery (byte size recorded).

Official public CBSE curriculum documents. Used for blueprint/pattern analysis +
local archive only (owner D-8 / L2). Download + V1-V11 verification is done by
downloader.py through the certified VerificationEngine.

Usage:
  cbse_catalogue.py [--to-queue]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
CUR_BASE = "https://cbseacademic.nic.in/web_material/CurriculumMain26/Sec"
CUR_LISTING = "https://cbseacademic.nic.in/curriculum_2026.html"

# file_stem, class_num, subject_display, subject_folder, doc_type, title, head_bytes
SYLLABI: list[tuple[str, int, str, str, str, str, int]] = [
    ("Curriculum_Sec_2025-26", 10, "Secondary Curriculum", "Syllabus", "Curriculum",
     "CBSE Secondary (IX-X) Curriculum 2025-26 — all subjects (master document)", 2256805),
    ("English_LL_2025-26", 10, "English", "English", "Syllabus",
     "CBSE Secondary (IX-X) English Language & Literature — Syllabus 2025-26", 625030),
    ("English_Communicative_Sec_2025-26", 10, "English", "English", "Syllabus",
     "CBSE Secondary (IX-X) English (Communicative) — Syllabus 2025-26", 457730),
    ("Maths_Sec_2025-26", 10, "Mathematics", "Mathematics", "Syllabus",
     "CBSE Secondary (IX-X) Mathematics — Syllabus 2025-26", 573399),
    ("Maths_SecIX_2025-26RM", 9, "Mathematics", "Mathematics", "Syllabus",
     "CBSE Class IX Mathematics — Rationalised Material / Syllabus 2025-26", 19693893),
    ("Science_Sec_2025-26", 10, "Science", "Science", "Syllabus",
     "CBSE Secondary (IX-X) Science — Syllabus 2025-26", 314752),
    ("Science_SecIX_2025-26_RM", 9, "Science", "Science", "Syllabus",
     "CBSE Class IX Science — Rationalised Material / Syllabus 2025-26", 1021954),
    ("Social_Science_Sec_2025-26", 10, "Social Science", "Social_Science", "Syllabus",
     "CBSE Secondary (IX-X) Social Science — Syllabus 2025-26", 631732),
    ("Computer_Applications_Sec_2025-26", 10, "Computer Science", "Computer_Science", "Syllabus",
     "CBSE Secondary (IX-X) Computer Applications — Syllabus 2025-26", 300422),
]

SUBJ_CODE = {"Mathematics": "MATH", "Science": "SCI", "Social Science": "SST",
             "English": "ENG", "Computer Science": "CS", "Secondary Curriculum": "GEN"}


def build(ws: Workspace) -> list[dict]:
    classes = ws.config("classes")["classes"]
    seq = 200  # CBSE syllabus cells occupy a distinct seq band
    catalogue: list[dict] = []
    for stem, cnum, subj_disp, subj_folder, doc_type, title, head_bytes in SYLLABI:
        seq += 1
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        ccode = classes[ckey]["code"]
        scode = SUBJ_CODE[subj_disp]
        rid = f"AKS-CBSE-{ccode}-{scode}-SYLL-2025-{seq:06d}"
        fname = f"CBSE_{clabel}_{subj_folder}_Syllabus-{stem}_2025-26_v1_English.pdf"
        dest = f"curriculum/cbse/{clabel}/{subj_folder}/Syllabus"
        catalogue.append({
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": f"{stem}.pdf",
            "title": title,
            "document_type": doc_type,
            "resource_category": "syllabus",
            "board": "CBSE",
            "class_label": clabel,
            "subject": subj_disp,
            "priority": "A",
            "source_portal": "https://cbseacademic.nic.in",
            "source_url": f"{CUR_BASE}/{stem}.pdf",
            "source_website": "https://cbseacademic.nic.in",
            "publisher": "CBSE",
            "academic_year": "2025-26",
            "language": "English",
            "medium": "English",
            "license_status": "OFFICIAL_PUBLIC_CBSE_CURRICULUM_ANALYSIS_ONLY",
            "license_note": ("CBSE official public curriculum/syllabus (cbseacademic.nic.in), "
                             "used for blueprint/pattern analysis + local archive only"),
            "destination": dest,
            "alternative_sources": [],
            "search_locations": [CUR_LISTING, f"{CUR_BASE}/{stem}.pdf"],
            "discovery_status": "URL_RESOLVED",
            "head_content_length": head_bytes,
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
    total = sum(e["head_content_length"] for e in catalogue)
    print(f"CBSE syllabus catalogue: {len(catalogue)} docs, {total/1_048_576:.1f} MiB expected")
    disc_dir = ws.p("discovery_dir") / "cbse"
    disc_dir.mkdir(parents=True, exist_ok=True)
    write_json(disc_dir / "cbse_syllabus_catalogue.json",
               {"generated_at": utcnow(), "source_listing": CUR_LISTING, "documents": catalogue})
    if args.to_queue:
        added, size = merge_queue(ws, catalogue)
        print(f"queue: merged {added} new CBSE syllabus entries (queue size {size})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
