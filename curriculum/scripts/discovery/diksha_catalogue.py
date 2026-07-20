#!/usr/bin/env python3
"""DIKSHA dynamic discovery — POST search API, probe, queue-shaped entries.

Official government mirror (Tier 2). Fills gaps when board portals lack direct PDFs:
  CBSE ICT/CS, AP EVS/supplementary, Telangana extras, sample/previous papers where listed.

Usage:
  diksha_catalogue.py [--inspect] [--to-queue]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow, sanitize_filename  # noqa: E402
from source_probe import probe_url  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
DIKSHA_SEARCH = "https://diksha.gov.in/api/content/v1/search"
DIKSHA_PORTAL = "https://diksha.gov.in"

# workspace board key → (matrix board code, DIKSHA board filter)
BOARD_MAP = {
    "cbse": ("CBSE", "CBSE"),
    "ap": ("APSCERT", "State (Andhra Pradesh)"),
    "telangana": ("TSSCERT", "State (Telangana)"),
}

# DIKSHA subject display/list → canonical slug
_SUBJ_HINTS: list[tuple[str, str]] = [
    ("mathematics", "mathematics"), ("maths", "mathematics"),
    ("general science", "science"), ("physical science", "science"),
    ("biological science", "science"), ("science", "science"), ("evs", "science"),
    ("social studies", "social_science"), ("social science", "social_science"),
    ("english", "english"),
    ("computer", "computer_science"), ("ict", "computer_science"),
    ("information and communication", "computer_science"),
]

_SKIP_NAME = re.compile(
    r"handbook|teacher resource|training manual|course assessment framework|learning resource kit|"
    r"explanation content only|worksheet only|copy of andhra",
    re.I,
)


def _post_search(filters: dict, *, query: str | None = None, limit: int = 50) -> list[dict]:
    body: dict = {"request": {"filters": {**filters, "status": ["Live"]}, "limit": limit}}
    if query:
        body["request"]["query"] = query
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        DIKSHA_SEARCH, data=data,
        headers={"Content-Type": "application/json", "User-Agent": "AksharaCurriculumBot/1.0"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=45) as resp:
        payload = json.load(resp)
    return payload.get("result", {}).get("content", []) or []


def _map_subject(item: dict, in_scope: set[str]) -> str | None:
    parts: list[str] = []
    subj = item.get("subject")
    if isinstance(subj, list):
        parts.extend(str(s).lower() for s in subj)
    elif subj:
        parts.append(str(subj).lower())
    parts.append((item.get("name") or "").lower())
    blob = " ".join(parts)
    best: tuple[int, str] | None = None
    for needle, slug in _SUBJ_HINTS:
        if slug not in in_scope:
            continue
        if needle in blob:
            score = len(needle)
            if best is None or score > best[0]:
                best = (score, slug)
    return best[1] if best else None


def _doc_kind(item: dict) -> tuple[str, str, str, str] | None:
    """Return (resource_category, document_type, id_token, assessment_subtype) or None."""
    name = (item.get("name") or "").lower()
    ct = (item.get("contentType") or item.get("primaryCategory") or "").lower()
    subtype = "other_assessment"
    if any(k in name for k in ("marking scheme", "answer key", "solution")):
        return ("blueprint", "Marking Scheme", "MS", "marking_scheme")
    if "weightage" in name:
        return ("blueprint", "Blueprint", "BLPR", "weightage")
    if any(k in name for k in ("blueprint", "assessment guideline", "exam pattern")):
        return ("blueprint", "Blueprint", "BLPR", "blueprint")
    if re.search(r"\bfa[\s_-]*1\b|formative.*\b1\b", name):
        return ("sample_paper", "FA1 Paper", "FA1", "fa1")
    if re.search(r"\bfa[\s_-]*2\b|formative.*\b2\b", name):
        return ("sample_paper", "FA2 Paper", "FA2", "fa2")
    if re.search(r"\bfa[\s_-]*3\b", name):
        return ("sample_paper", "FA3 Paper", "FA3", "fa3")
    if re.search(r"\bfa[\s_-]*4\b", name):
        return ("sample_paper", "FA4 Paper", "FA4", "fa4")
    if re.search(r"\bsa[\s_-]*1\b|summative.*\b1\b", name):
        return ("sample_paper", "SA1 Paper", "SA1", "sa1")
    if re.search(r"\bsa[\s_-]*2\b|summative.*\b2\b", name):
        return ("sample_paper", "SA2 Paper", "SA2", "sa2")
    if re.search(r"\bsa[\s_-]*3\b", name):
        return ("sample_paper", "SA3 Paper", "SA3", "sa3")
    if "unit test" in name:
        return ("sample_paper", "Unit Test Paper", "UNIT", "unit_test")
    if re.search(r"practice question|cba module", name):
        return ("sample_paper", "Practice Paper", "PRAC", "unit_test")
    if "abhyasa" in name or ("formative" in name and "summative" in name):
        return ("sample_paper", "Formative Summative Paper", "FASA", "formative_summative")
    if any(k in name for k in ("formative", "fa-", "fa ")):
        return ("sample_paper", "Formative Paper", "FA", "formative_summative")
    if any(k in name for k in ("summative", "sa-", "sa ")):
        return ("sample_paper", "Summative Paper", "SA", "formative_summative")
    if "quarterly" in name:
        return ("sample_paper", "Quarterly Exam Paper", "QTR", "quarterly")
    if any(k in name for k in ("half yearly", "half-yearly", "halfyearly")):
        return ("sample_paper", "Half Yearly Paper", "HY", "half_yearly")
    if any(k in name for k in ("annual exam", "final exam", "annual examination")):
        return ("sample_paper", "Annual Exam Paper", "ANN", "annual_final")
    if "previous" in name or "previous year" in name:
        return ("previous_paper", "Previous Paper", "PREV", "previous_paper")
    if "specimen" in name:
        return ("sample_paper", "Specimen Paper", "SPEC", "specimen_paper")
    if "model" in name and "paper" in name:
        return ("sample_paper", "Model Paper", "MODL", "model_paper")
    if any(k in name for k in ("sample", "question paper")) and "model" not in name:
        return ("sample_paper", "Sample Paper", "SAMP", "sample_paper")
    if "textbook" in ct or "textbook" in name or "etextbook" in name:
        return ("textbook", "Textbook", "TEXT", "")
    if item.get("contentType") == "TextBook":
        return ("textbook", "Textbook", "TEXT", "")
    return None


def _entry_from_item(
    ws: Workspace,
    *,
    board_code: str,
    board_folder: str,
    class_num: int,
    subject_slug: str,
    category: str,
    doc_type: str,
    id_token: str,
    assessment_subtype: str,
    item: dict,
    url: str,
) -> dict:
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    cat_folder = ws.config("download_rules")["category_to_subject_folder"]
    ckey = str(class_num)
    clabel = classes[ckey]["class_label"]
    ccode = classes[ckey]["code"]
    subj = subjects[subject_slug]
    did = item.get("identifier") or url
    seq = zlib.crc32(did.encode()) & 0xFFFFFF
    rid = f"AKS-{board_code}-{ccode}-{subj['code']}-DIK-{id_token}-2025-{seq:06d}"
    orig = url.rsplit("/", 1)[-1]
    stem = sanitize_filename(orig.rsplit(".", 1)[0] if "." in orig else orig)
    ext = ".zip" if orig.lower().endswith((".ecar", ".zip")) else ".pdf"
    if ext == ".zip" and not orig.lower().endswith(".zip"):
        orig = stem + ".zip"
    doc_tok = sanitize_filename(doc_type.replace(" ", "_"))
    fname = (f"{board_code}_{clabel}_{subj['subject_folder']}_{doc_tok}-"
             f"DIKSHA_{stem}_2025-26_v1_English{ext}")
    dest = f"curriculum/{board_folder}/{clabel}/{subj['subject_folder']}/{cat_folder.get(category, 'Reference')}"
    return {
        "resource_id": rid,
        "expected_filename": fname,
        "original_filename": orig,
        "title": f"{board_code} {clabel.replace('_', ' ')} {subj['display']} — {item.get('name', 'DIKSHA')} (mirror)",
        "document_type": doc_type,
        "resource_category": category,
        "board": board_code,
        "class_label": clabel,
        "subject": subj["display"],
        "priority": "A",
        "source_portal": DIKSHA_PORTAL,
        "source_url": url,
        "source_website": DIKSHA_PORTAL,
        "diksha_content_id": item.get("identifier"),
        "publisher": board_code,
        "academic_year": "2025-26",
        "language": "English",
        "medium": "English",
        "license_status": "OFFICIAL_GOVERNMENT_DIKSHA_MIRROR",
        "license_note": "DIKSHA official government mirror; analysis + local archive only",
        "destination": dest,
        "alternative_sources": [],
        "search_locations": [DIKSHA_SEARCH, DIKSHA_PORTAL, url],
        "discovery_status": "URL_RESOLVED_DIKSHA_MIRROR",
        "status": "PENDING",
        "retry_count": 0,
        "cataloged_at": utcnow(),
        "assessment_subtype": assessment_subtype or None,
    }


def build(ws: Workspace, *, probe: bool = True) -> list[dict]:
    boards_cfg = ws.config("boards")["boards"]
    catalogue: list[dict] = []
    seen_urls: set[str] = set()

    queries = [
        (None, {}),
        ("sample question paper", {"contentType": ["PracticeResource", "TextBook"]}),
        ("model question paper", {"contentType": ["PracticeResource"]}),
        ("specimen question paper", {"contentType": ["PracticeResource"]}),
        ("previous year question paper", {"contentType": ["PracticeResource"]}),
        ("marking scheme", {"contentType": ["PracticeResource"]}),
        ("blueprint", {"contentType": ["PracticeResource"]}),
        ("weightage", {"contentType": ["PracticeResource"]}),
        ("unit test", {"contentType": ["PracticeResource"]}),
        ("unit test question paper", {"contentType": ["PracticeResource"]}),
        ("formative assessment 1", {"contentType": ["PracticeResource"]}),
        ("formative assessment 2", {"contentType": ["PracticeResource"]}),
        ("formative assessment", {"contentType": ["PracticeResource"]}),
        ("summative assessment 1", {"contentType": ["PracticeResource"]}),
        ("summative assessment 2", {"contentType": ["PracticeResource"]}),
        ("summative assessment", {"contentType": ["PracticeResource"]}),
        ("FA1 question paper", {"contentType": ["PracticeResource"]}),
        ("FA2 question paper", {"contentType": ["PracticeResource"]}),
        ("SA1 question paper", {"contentType": ["PracticeResource"]}),
        ("SA2 question paper", {"contentType": ["PracticeResource"]}),
        ("quarterly examination", {"contentType": ["PracticeResource"]}),
        ("half yearly examination", {"contentType": ["PracticeResource"]}),
        ("annual examination", {"contentType": ["PracticeResource"]}),
        ("final examination", {"contentType": ["PracticeResource"]}),
        ("abhyasa deepika", {"contentType": ["PracticeResource", "TextBook"]}),
        ("practice question paper", {"contentType": ["PracticeResource"]}),
        ("assessment guideline", {"contentType": ["PracticeResource"]}),
        ("telangana formative", {"contentType": ["PracticeResource"]}),
        ("telangana summative", {"contentType": ["PracticeResource"]}),
        ("andhra pradesh formative", {"contentType": ["PracticeResource"]}),
        ("andhra pradesh summative", {"contentType": ["PracticeResource"]}),
        ("CBSE sample paper", {"contentType": ["PracticeResource"]}),
        ("computer application", {"contentType": ["TextBook", "PracticeResource"]}),
        ("EVS textbook", {"contentType": ["TextBook"]}),
        ("english medium textbook", {"contentType": ["TextBook"]}),
        ("telangana textbook", {"contentType": ["TextBook"]}),
        ("andhra pradesh textbook", {"contentType": ["TextBook"]}),
    ]

    for bkey, (bcode, diksha_board) in BOARD_MAP.items():
        bcfg = boards_cfg[bkey]
        if not bcfg.get("in_scope"):
            continue
        board_folder = bcfg["board_folder"]
        for cnum in bcfg["subjects_by_class"]:
            in_scope = set(bcfg["subjects_by_class"][cnum])
            gl = f"Class {cnum}"
            for qi, (query, extra) in enumerate(queries):
                filters = {"board": [diksha_board], "gradeLevel": [gl], **extra}
                try:
                    items = _post_search(filters, query=query, limit=40)
                except (urllib.error.URLError, TimeoutError, OSError, json.JSONDecodeError):
                    continue
                added_this = 0
                for item in items:
                    name = item.get("name") or ""
                    if _SKIP_NAME.search(name):
                        continue
                    kind = _doc_kind(item)
                    if not kind:
                        continue
                    category, doc_type, id_token, assessment_subtype = kind
                    slug = _map_subject(item, in_scope)
                    if not slug:
                        continue
                    url = item.get("downloadUrl") or item.get("artifactUrl")
                    if not url or url in seen_urls:
                        continue
                    if probe:
                        pr = probe_url(url, referer=DIKSHA_PORTAL)
                        if not pr["ok"]:
                            continue
                    seen_urls.add(url)
                    catalogue.append(_entry_from_item(
                        ws, board_code=bcode, board_folder=board_folder,
                        class_num=int(cnum), subject_slug=slug,
                        category=category, doc_type=doc_type, id_token=id_token,
                        assessment_subtype=assessment_subtype,
                        item=item, url=url,
                    ))
                    added_this += 1
                if added_this and qi % 5 == 0:
                    print(f"  DIKSHA {bcode} {gl} q={qi+1}/{len(queries)} +{added_this} total={len(catalogue)}", flush=True)
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
    ap.add_argument("--inspect", action="store_true")
    ap.add_argument("--to-queue", action="store_true")
    ap.add_argument("--no-probe", action="store_true")
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    cat = build(ws, probe=not args.no_probe)
    print(f"DIKSHA catalogue: {len(cat)} probe-confirmed entries")
    out = ws.p("discovery_dir") / "diksha_catalogue.json"
    write_json(out, {"generated_at": utcnow(), "portal": DIKSHA_PORTAL, "documents": cat})
    if args.inspect:
        for e in cat[:30]:
            print(e["board"], e["class_label"], e["subject"], e["resource_category"], e["source_url"][:70])
        return 0
    if args.to_queue:
        a, n = merge_queue(ws, cat)
        print(f"queue: +{a} (size {n})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
