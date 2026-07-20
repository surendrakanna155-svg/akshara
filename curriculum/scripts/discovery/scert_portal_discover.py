#!/usr/bin/env python3
"""Discover official SCERT direct PDFs from state publication pages.

Probes scert.telangana.gov.in and apscert/scert AP publication URL patterns.
Only probe-confirmed application/pdf endpoints are returned.

Usage: scert_portal_discover.py [--board ap|telangana|all]
"""
from __future__ import annotations

import argparse
import re
import sys
import urllib.parse
import urllib.request
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, write_json, utcnow, sanitize_filename  # noqa: E402
from source_probe import probe_url  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]

PORTALS = {
    "telangana": {
        "board": "TSSCERT",
        "board_folder": "telangana",
        "base": "https://scert.telangana.gov.in",
        "seeds": [
            "https://scert.telangana.gov.in/",
            "https://scert.telangana.gov.in/ebooks.html",
            "https://scert.telangana.gov.in/pdf/publication/ebooks/",
        ],
        "license": "OFFICIAL_PUBLIC_TS_SCERT_DIRECT",
    },
    "ap": {
        "board": "APSCERT",
        "board_folder": "ap",
        "base": "https://scert.ap.gov.in",
        "seeds": [
            "https://scert.ap.gov.in/",
            "https://apscert.gov.in/",
        ],
        "license": "OFFICIAL_PUBLIC_AP_SCERT_DIRECT",
    },
}

_CLASS_RE = [
    (re.compile(r"\b(?:class[\s_-]*)?10\b|10th|x(?:th)?\b", re.I), 10),
    (re.compile(r"\b(?:class[\s_-]*)?9\b|9th|ix\b", re.I), 9),
    (re.compile(r"\b(?:class[\s_-]*)?8\b|8th|viii\b", re.I), 8),
    (re.compile(r"\b(?:class[\s_-]*)?7\b|7th|vii\b", re.I), 7),
    (re.compile(r"\b(?:class[\s_-]*)?6\b|6th|vi\b", re.I), 6),
    (re.compile(r"\b(?:class[\s_-]*)?5\b|5th|v\b", re.I), 5),
    (re.compile(r"\b(?:class[\s_-]*)?4\b|4th|iv\b", re.I), 4),
    (re.compile(r"\b(?:class[\s_-]*)?3\b|3rd|iii\b", re.I), 3),
    (re.compile(r"\b(?:class[\s_-]*)?2\b|2nd|ii\b", re.I), 2),
    (re.compile(r"\b(?:class[\s_-]*)?1\b|1st|i\b", re.I), 1),
]

_SUBJ_MAP = [
    (re.compile(r"english", re.I), "english"),
    (re.compile(r"math|mathematics", re.I), "mathematics"),
    (re.compile(r"physical[\s_-]*science|physics", re.I), "science"),
    (re.compile(r"biological|science|evs", re.I), "science"),
    (re.compile(r"social", re.I), "social_science"),
]


def _fetch_html(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "AksharaCurriculumBot/1.0"})
    with urllib.request.urlopen(req, timeout=25) as resp:
        return resp.read(400_000).decode("utf-8", "ignore")


def _abs_url(base: str, href: str) -> str:
    if href.startswith("http"):
        raw = href.split("#")[0]
    elif href.startswith("/"):
        from urllib.parse import urlparse
        p = urlparse(base)
        raw = f"{p.scheme}://{p.netloc}{href}"
    else:
        raw = base.rsplit("/", 1)[0] + "/" + href
    parts = urllib.parse.urlsplit(raw)
    return urllib.parse.urlunsplit((
        parts.scheme, parts.netloc,
        urllib.parse.quote(parts.path, safe="/%"),
        urllib.parse.quote(parts.query, safe="=&%"),
        parts.fragment,
    ))


def _infer_class_subject(url: str, title: str) -> tuple[int | None, str | None, str, str, str, str]:
    blob = f"{url} {title}"
    cnum = None
    for pat, n in _CLASS_RE:
        if pat.search(blob):
            cnum = n
            break
    sk = None
    for pat, slug in _SUBJ_MAP:
        if pat.search(blob):
            sk = slug
            break
    cat = "textbook"
    dtype = "Textbook"
    tok = "TEXT"
    subtype = ""
    bl = blob.lower()
    if any(k in bl for k in ("model", "sample", "question paper", "sqp")):
        cat, dtype, tok, subtype = "sample_paper", "Sample Paper", "SAMP", "sample_paper"
    elif any(k in bl for k in ("formative", "fa1", "fa 1", "fa-1")):
        cat, dtype, tok, subtype = "sample_paper", "FA1 Paper", "FA1", "fa1"
    elif any(k in bl for k in ("summative", "sa1", "sa 1", "sa-1")):
        cat, dtype, tok, subtype = "sample_paper", "SA1 Paper", "SA1", "sa1"
    elif "blueprint" in bl or "weightage" in bl:
        cat, dtype, tok, subtype = "blueprint", "Blueprint", "BLPR", "blueprint"
    return cnum, sk, cat, dtype, tok, subtype


def discover_board(ws: Workspace, bkey: str) -> list[dict]:
    cfg = PORTALS[bkey]
    boards = ws.config("boards")["boards"][bkey]
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    cat_folder = ws.config("download_rules")["category_to_subject_folder"]
    pdf_urls: set[str] = set()
    pages = list(cfg["seeds"])
    seen_pages: set[str] = set()
    while pages:
        page = pages.pop()
        if page in seen_pages:
            continue
        seen_pages.add(page)
        try:
            html = _fetch_html(page)
        except Exception:
            continue
        for m in re.finditer(r'href=["\']([^"\']+\.pdf[^"\']*)["\']', html, re.I):
            pdf_urls.add(_abs_url(page, m.group(1)))
        for m in re.finditer(r'href=["\']([^"\']+)["\']', html, re.I):
            href = m.group(1)
            if any(k in href.lower() for k in ("ebook", "publication", "textbook", "download", "pdf")):
                pages.append(_abs_url(page, href))

    entries: list[dict] = []
    total = len(pdf_urls)
    print(f"  SCERT {bkey}: probing {total} PDF candidates...", flush=True)
    for i, url in enumerate(sorted(pdf_urls)):
        if i and i % 10 == 0:
            print(f"  SCERT {bkey}: probe {i}/{total} confirmed={len(entries)}", flush=True)
        try:
            pr = probe_url(url)
        except Exception:
            continue
        if not pr.get("ok"):
            continue
        title = url.rsplit("/", 1)[-1]
        cnum, sk, cat, dtype, tok, subtype = _infer_class_subject(url, title)
        if not cnum or not sk:
            continue
        ckey = str(cnum)
        if ckey not in boards["subjects_by_class"]:
            continue
        if sk not in boards["subjects_by_class"][ckey]:
            continue
        clabel = classes[ckey]["class_label"]
        subj = subjects[sk]
        seq = zlib.crc32(url.encode()) & 0xFFFFFF
        rid = f"AKS-{cfg['board']}-{classes[ckey]['code']}-{subj['code']}-SCERT-{tok}-2025-{seq:06d}"
        stem = sanitize_filename(title[:-4] if title.lower().endswith(".pdf") else title)
        fname = (f"{cfg['board']}_{clabel}_{subj['subject_folder']}_{dtype.replace(' ', '')}-"
                 f"SCERT_{stem}_2025-26_v1_English.pdf")
        dest = f"curriculum/{cfg['board_folder']}/{clabel}/{subj['subject_folder']}/{cat_folder.get(cat, 'Reference')}"
        entries.append({
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": title,
            "title": f"{cfg['board']} {clabel.replace('_', ' ')} {subj['display']} — SCERT ({title})",
            "document_type": dtype,
            "resource_category": cat,
            "board": cfg["board"],
            "class_label": clabel,
            "subject": subj["display"],
            "priority": "A",
            "source_portal": cfg["base"],
            "source_url": url,
            "source_website": cfg["base"],
            "publisher": cfg["board"],
            "academic_year": "2025-26",
            "language": "English",
            "medium": "English",
            "license_status": cfg["license"],
            "license_note": "Official state SCERT direct PDF",
            "destination": dest,
            "alternative_sources": [],
            "search_locations": [cfg["base"], url],
            "discovery_status": "URL_RESOLVED_SCERT_DIRECT",
            "status": "PENDING",
            "retry_count": 0,
            "cataloged_at": utcnow(),
            "assessment_subtype": subtype or None,
        })
    return entries


def discover(ws: Workspace, board: str = "all") -> list[dict]:
    keys = list(PORTALS) if board == "all" else [board]
    out: list[dict] = []
    seen: set[str] = set()
    for k in keys:
        for e in discover_board(ws, k):
            if e["source_url"] not in seen:
                seen.add(e["source_url"])
                out.append(e)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--board", default="all", choices=["all", "ap", "telangana"])
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    entries = discover(ws, args.board)
    out = ws.p("discovery_dir") / "scert_portal_catalogue.json"
    write_json(out, {"generated_at": utcnow(), "documents": entries})
    print(f"SCERT portal: {len(entries)} probe-confirmed PDFs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
