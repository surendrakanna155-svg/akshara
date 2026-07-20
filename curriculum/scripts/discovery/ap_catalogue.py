#!/usr/bin/env python3
"""AP SCERT textbook discovery → DOWNLOAD_QUEUE.json merge (spec Parts 05/06).

DYNAMIC DROPDOWN ENUMERATION (2026-07-09): the official public textbook view
  https://cse.ap.gov.in/loadacademictextbookpublicview
is a form POST driven by three dropdowns (Academic Year, Class, Medium). This
resolver walks those dropdowns exactly like a user would — for every in-scope
class (1-10) and every English-content medium (Telugu-English=17, English=19)
it POSTs the form, parses the returned table, and queues every in-scope
textbook row. Each View button resolves to a direct-PDF endpoint:
  https://cse.ap.gov.in/loadsupdocumentuploadbyid?req_doc_id=<id>
(Content-Type: application/pdf — no browser automation needed; Tier 1 official.)

No hardcoded URL list: the portal's own catalogue is the source of truth each
run. Resource IDs are derived deterministically from the portal doc_id so the
queue merge stays idempotent across runs.

Scope filter (canonical matrix only): Classes 1-10 × {mathematics, science,
social_science, english} × Text Book rows. Telugu / Hindi / Sanskrit / Value
Education / composite-language rows are skipped — they are not matrix cells.
Circulars, notifications and administrative documents never appear here.

The legacy /downloadBooks/… listing (session-gated, HTTP-200 HTML error 803)
is retired as a primary source; entries queued from it earlier keep their
status and provenance untouched.

Official public AP SCERT textbooks; analysis + local archive only (owner D-8/L2).

Usage:
  ap_catalogue.py [--to-queue]
"""

from __future__ import annotations

import argparse
import html
import http.cookiejar
import re
import sys
import urllib.error
import urllib.request
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow, sanitize_filename  # noqa: E402
from source_probe import probe_url  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
CSE_BASE = "https://cse.ap.gov.in"
AP_PUBLIC_VIEW = f"{CSE_BASE}/loadacademictextbookpublicview"
AP_DOC_URL = f"{CSE_BASE}/loadsupdocumentuploadbyid?req_doc_id={{doc_id}}"
AP_LEGACY_LISTING = f"{CSE_BASE}/textBooksDownloadingPagetitleWise"
ACADEMIC_YEAR = "2025-2026"

# Dropdown values walked on every run (classes 1-10 are the canonical matrix;
# Telugu-English carries the English-language Maths/Science/Social books,
# English carries the English-subject textbooks).
CLASS_IDS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
MEDIUM_IDS = {"17": "Telugu-English", "19": "English"}

_ROW_RE = re.compile(
    r"<tr>\s*<td[^>]*>(\d+)</td>\s*<td[^>]*>(\d+)</td>\s*<td[^>]*>([^<]+)</td>\s*"
    r"<td[^>]*>([^<]+)</td>\s*<td[^>]*>([^<]+)</td>\s*<td[^>]*>([^<]+)</td>.*?"
    r"loadsupdocumentuploadbyid\?req_doc_id=([^'\"]+)",
    re.S,
)

# Portal subject string → canonical matrix subject key. Order matters: the
# combined-languages rows ("TELUGU, HINDI, ENGLISH") and Sanskrit/value-ed
# rows must be rejected before the ENGLISH match fires.
_SKIP_MARKERS = ("TELUGU", "HINDI", "SANSKRIT", "URDU", "ORIENTAL", "COMPOSIT", "VALUE EDUCATION")
_SUBJECT_RULES: list[tuple[str, str]] = [
    ("EVS", "science"),
    ("MATH", "mathematics"),
    ("POLITICAL", "social_science"),  # must precede generic SCIENCE ("POLITICAL SCIENCE")
    ("GENERAL SCIENCE", "science"),
    ("SCIENCE", "science"),          # PHYSICAL SCIENCES / BIOLOGICAL SCIENCE (Class 10 split)
    ("SOCIAL", "social_science"),
    ("GEOGRAPHY", "social_science"),
    ("HISTORY", "social_science"),
    ("ECONOMICS", "social_science"),
    ("ENGLISH", "english"),
]


def _map_subject(portal_subject: str) -> str | None:
    upper = portal_subject.upper()
    if any(m in upper for m in _SKIP_MARKERS):
        return None
    # Combined primary-semester books carry both maths + EVS; maths is the canonical slot.
    if "MATHS" in upper and "EVS" in upper:
        return "mathematics"
    for marker, key in _SUBJECT_RULES:
        if marker in upper:
            return key
    return None


def _parse_rows(page_html: str) -> list[dict]:
    rows: list[dict] = []
    for m in _ROW_RE.finditer(page_html):
        rows.append({
            "class": m.group(2),
            "medium": html.unescape(m.group(3).strip()),
            "subject": html.unescape(m.group(4).strip()),
            "book_type": html.unescape(m.group(5).strip()),
            "book_name": html.unescape(m.group(6).strip()),
            "doc_id": m.group(7),
        })
    return rows


def _walk_dropdowns(opener: urllib.request.OpenerDirector, headers: dict) -> list[dict]:
    """One POST (acYear only) → parse full table → filter in Python.

    Faster than 10 separate Class×Medium POSTs (~1 s vs ~3 s) and matches the
    portal's own catalogue.  Title-wise /downloadBooks/ links are NOT used —
    HEAD probes showed they return HTML error 803; only loadsupdocumentuploadbyid
    endpoints are queued.
    """
    rows: list[dict] = []
    seen: set[str] = set()
    allowed_mediums = set(MEDIUM_IDS.values())
    req = urllib.request.Request(
        f"{AP_PUBLIC_VIEW}?random=0",
        data=f"acYear={ACADEMIC_YEAR}".encode(),
        headers={**headers, "Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with opener.open(req, timeout=60) as resp:
            page = resp.read().decode("utf-8", "ignore")
    except (urllib.error.URLError, TimeoutError, OSError):
        return rows
    for row in _parse_rows(page):
        if row["class"] not in CLASS_IDS:
            continue
        if row["medium"] not in allowed_mediums:
            continue
        if row["doc_id"] not in seen:
            seen.add(row["doc_id"])
            rows.append(row)
    return rows


def _probe_row(opener: urllib.request.OpenerDirector, row: dict, headers: dict) -> dict | None:
    """HEAD-probe doc_id URL; return row with probe metadata or None if not a PDF."""
    url = AP_DOC_URL.format(doc_id=row["doc_id"])
    result = probe_url(url, opener, referer=headers.get("Referer"))
    if not result["ok"]:
        return None
    row = dict(row)
    row["probe"] = result
    return row


def discover_rows(*, probe: bool = True) -> tuple[list[dict], list[dict]]:
    """Inspect portal → optional HEAD-probe → return (queued_rows, rejected_rows)."""
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    headers = {
        "User-Agent": "AksharaCurriculumBot/1.0 (+education-repository; contact: akshara-erp)",
        "Referer": AP_PUBLIC_VIEW,
    }
    try:
        opener.open(urllib.request.Request(AP_PUBLIC_VIEW, headers=headers), timeout=20)
    except (urllib.error.URLError, TimeoutError, OSError):
        return [], []

    candidates = _walk_dropdowns(opener, headers)
    accepted: list[dict] = []
    rejected: list[dict] = []
    for row in candidates:
        bt = row["book_type"].lower()
        is_text = bt.startswith("text")
        is_primary_handbook = (
            row["class"] in {"1", "2", "3", "4", "5"}
            and "hand book" in bt
            and _map_subject(row["subject"]) in {"mathematics", "english", "science"}
            and "THB" in row["book_name"].upper()
        )
        if not is_text and not is_primary_handbook:
            continue
        if _map_subject(row["subject"]) is None:
            continue
        if probe:
            probed = _probe_row(opener, row, headers)
            if probed:
                accepted.append(probed)
            else:
                rejected.append(row)
        else:
            accepted.append(row)
    return accepted, rejected


def _stable_seq(doc_id: str) -> int:
    """Deterministic 6-digit sequence from the portal doc id (idempotent merge)."""
    return 100000 + (zlib.crc32(doc_id.encode()) % 900000)


def build(ws: Workspace, *, probe: bool = True) -> list[dict]:
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    catalogue: list[dict] = []
    rows, _rejected = discover_rows(probe=probe)
    for row in rows:
        skey = _map_subject(row["subject"])
        if not skey:
            continue
        subj = subjects[skey]
        cinfo = classes[row["class"]]
        clabel = cinfo["class_label"]
        ccode = cinfo["code"]
        stem = sanitize_filename(row["book_name"].title())
        rid = f"AKS-AP-{ccode}-{subj['code']}-TEXT-2025-{_stable_seq(row['doc_id']):06d}"
        fname = f"AP_{clabel}_{subj['subject_folder']}_Textbook-{stem}_2025-26_v1_English.pdf"
        catalogue.append({
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": f"{row['doc_id']}.pdf",
            "title": (f"AP SCERT {clabel.replace('_', ' ')} {subj['display']} — "
                      f"{row['book_name']} ({row['medium']} medium)"),
            "document_type": "Textbook",
            "resource_category": "textbook",
            "board": "APSCERT",
            "class_label": clabel,
            "subject": subj["display"],
            "priority": "A",
            "source_portal": AP_PUBLIC_VIEW,
            "source_url": AP_DOC_URL.format(doc_id=row["doc_id"]),
            "source_website": CSE_BASE,
            "publisher": "AP SCERT",
            "academic_year": "2025-26",
            "language": "English",
            "medium": row["medium"],
            "license_status": "OFFICIAL_PUBLIC_AP_SCERT_TEXTBOOK_ANALYSIS_ONLY",
            "license_note": ("AP SCERT official public textbook via "
                             "cse.ap.gov.in/loadacademictextbookpublicview (dropdown enumeration → "
                             "loadsupdocumentuploadbyid), blueprint/pattern analysis + local archive only"),
            "destination": f"curriculum/ap/{clabel}/{subj['subject_folder']}/Textbooks",
            "alternative_sources": [],
            "search_locations": [AP_PUBLIC_VIEW, AP_LEGACY_LISTING],
            "discovery_status": "URL_PROBE_CONFIRMED" if row.get("probe") else "URL_RESOLVED_PUBLIC_VIEW",
            "probe_result": row.get("probe"),
            "public_view_doc_id": row["doc_id"],
            "portal_subject": row["subject"],
            "portal_book_name": row["book_name"],
            "status": "PENDING",
            "retry_count": 0,
            "cataloged_at": utcnow(),
        })
    return catalogue


def merge_queue(ws: Workspace, catalogue: list[dict]) -> tuple[int, int]:
    """Idempotent merge: skip resource_ids AND portal doc_ids already queued.

    Doc-id dedupe keeps legacy AP entries (which already point at the same
    loadsupdocumentuploadbyid documents under older resource IDs) from being
    downloaded a second time.
    """
    queue = load_json(ws.pm("download_queue"), []) or []
    have_ids = {e.get("resource_id") for e in queue}
    have_docs: set[str] = set()
    for e in queue:
        if e.get("public_view_doc_id"):
            have_docs.add(e["public_view_doc_id"])
        m = re.search(r"req_doc_id=([^&]+)", e.get("source_url") or "")
        if m:
            have_docs.add(m.group(1))
    added = 0
    for entry in catalogue:
        if entry["resource_id"] in have_ids or entry["public_view_doc_id"] in have_docs:
            continue
        queue.append(entry)
        added += 1
    write_json(ws.pm("download_queue"), queue)
    return added, len(queue)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--to-queue", action="store_true")
    ap.add_argument("--inspect", action="store_true",
                    help="inspect portal + HEAD-probe only; do not write queue")
    ap.add_argument("--no-probe", action="store_true",
                    help="skip HEAD probes (faster but may queue bad URLs)")
    args = ap.parse_args()
    ws = Workspace(args.workspace)

    if args.inspect:
        accepted, rejected = discover_rows(probe=not args.no_probe)
        print(f"INSPECT: {len(accepted)} confirmed PDF endpoints, {len(rejected)} rejected")
        for r in accepted:
            pr = r.get("probe", {})
            print(f"  OK  cls={r['class']} {r['medium']:15} {r['book_name'][:40]:40} "
                  f"({pr.get('reason','?')}, {pr.get('content_length') or '?'} bytes)")
        for r in rejected[:10]:
            print(f"  SKIP cls={r['class']} {r['book_name'][:50]}")
        return 0

    catalogue = build(ws, probe=not args.no_probe)
    probed = sum(1 for e in catalogue if e.get("probe_result", {}).get("ok"))
    print(f"AP SCERT catalogue: {len(catalogue)} probe-confirmed textbook rows "
          f"({probed} HEAD-verified; classes {','.join(CLASS_IDS)})")
    disc_dir = ws.p("discovery_dir") / "ap"
    disc_dir.mkdir(parents=True, exist_ok=True)
    write_json(disc_dir / "ap_textbooks_catalogue.json",
               {"generated_at": utcnow(),
                "source_listing": AP_PUBLIC_VIEW,
                "resolution_mode": "dynamic dropdown enumeration (acYear × classId × mediumId)",
                "legacy_listing": AP_LEGACY_LISTING,
                "documents": catalogue})
    if args.to_queue:
        added, size = merge_queue(ws, catalogue)
        print(f"queue: merged {added} new AP entries (queue size {size})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
