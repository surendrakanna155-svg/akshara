#!/usr/bin/env python3
"""CISCE exhaustive public PDF discovery — crawl cisce.org/wp-content/uploads.

Discovers syllabus, specimen, competency documents for Classes 6–10 without
relying on a frozen URL list. HTML index pages are walked; direct PDF URLs are
probed before queue merge.

Usage:
  cisce_discover.py [--to-queue] [--workspace DIR]
"""
from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow, sanitize_filename  # noqa: E402
from source_probe import probe_url  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
CISCE_BASE = "https://cisce.org"
UPLOADS = f"{CISCE_BASE}/wp-content/uploads/"

# Known index pages + seed paths (walked recursively one level)
SEED_PAGES = [
    f"{CISCE_BASE}/academics/",
    f"{CISCE_BASE}/academics/curriculum/",
    f"{CISCE_BASE}/academics/syllabus/",
    f"{CISCE_BASE}/examinations/",
    f"{CISCE_BASE}/examinations/specimen-question-papers/",
]

CLASS_PATTERNS = [
    (re.compile(r"class[\s_-]*(?:ix|9)\b|class[\s_-]*9\b|class-ix", re.I), "9"),
    (re.compile(r"class[\s_-]*(?:x|10)\b|class[\s_-]*10\b|class-x", re.I), "10"),
    (re.compile(r"class[\s_-]*(?:viii|8)\b|class[\s_-]*8\b", re.I), "8"),
    (re.compile(r"class[\s_-]*(?:vii|7)\b|class[\s_-]*7\b", re.I), "7"),
    (re.compile(r"class[\s_-]*(?:vi|6)\b|class[\s_-]*6\b", re.I), "6"),
    (re.compile(r"class[\s_-]*(?:v|5)\b|class[\s_-]*5\b", re.I), "5"),
    (re.compile(r"class[\s_-]*(?:iv|4)\b|class[\s_-]*4\b", re.I), "4"),
    (re.compile(r"class[\s_-]*(?:iii|3)\b|class[\s_-]*3\b", re.I), "3"),
    (re.compile(r"class[\s_-]*(?:ii|2)\b|class[\s_-]*2\b", re.I), "2"),
    (re.compile(r"class[\s_-]*(?:i|1)\b|class[\s_-]*1\b", re.I), "1"),
    (re.compile(r"upper[\s_-]*primary", re.I), "6"),
]

SUBJECT_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"mathematics|maths", re.I), "mathematics"),
    (re.compile(r"physics", re.I), "physics"),
    (re.compile(r"chemistry", re.I), "chemistry"),
    (re.compile(r"biology", re.I), "biology"),
    (re.compile(r"geography", re.I), "geography"),
    (re.compile(r"history|civics|hcg", re.I), "history"),
    (re.compile(r"english[\s_-]*language|english-language", re.I), "english"),
    (re.compile(r"literature[\s_-]*in[\s_-]*english|english[\s_-]*literature", re.I), "english"),
    (re.compile(r"computer[\s_-]*application", re.I), "computer_science"),
    (re.compile(r"science(?!.*social)", re.I), "science"),
    (re.compile(r"upperprimary|upper[\s_-]*primary", re.I), "general"),
]

TYPE_PATTERNS: list[tuple[re.Pattern, str, str, str]] = [
    (re.compile(r"syllabus|curriculum", re.I), "syllabus", "Syllabus", "SYLL"),
    (re.compile(r"specimen|sample[\s_-]*question|sqp", re.I), "sample_paper", "Sample Paper", "SAMP"),
    (re.compile(r"competency|cfq|question[\s_-]*bank", re.I), "question_bank", "Question Bank", "QBNK"),
]

_PDF_RE = re.compile(r'href=["\']([^"\']+\.pdf[^"\']*)["\']', re.I)
_LINK_RE = re.compile(r'href=["\']([^"\']+)["\']', re.I)


def _fetch_html(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "AksharaCurriculumBot/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read(500_000).decode("utf-8", "ignore")


def _abs_url(base: str, href: str) -> str:
    if href.startswith("http"):
        return href.split("#")[0]
    if href.startswith("/"):
        return CISCE_BASE + href
    return base.rsplit("/", 1)[0] + "/" + href


def _classify(url: str, title: str) -> tuple[str | None, str | None, str, str, str] | None:
    blob = f"{url} {title}"
    ckey = None
    for pat, ck in CLASS_PATTERNS:
        if pat.search(blob):
            ckey = ck
            break
    skey = None
    for pat, sk in SUBJECT_PATTERNS:
        if pat.search(blob):
            skey = sk
            break
    for pat, cat, dtype, tok in TYPE_PATTERNS:
        if pat.search(blob):
            if ckey and (skey or cat == "syllabus"):
                return ckey, skey, cat, dtype, tok
    return None


def discover(ws: Workspace) -> list[dict]:
    existing = load_json(ws.root / "discovery/icse/cisce_source_urls.json", {})
    seen = {r["source_url"] for r in (existing.get("documents") or []) if r.get("source_url")}
    found: list[dict] = []

    pages = list(SEED_PAGES)
    for year in ("2025", "2026"):
        pages.append(f"{UPLOADS}{year}/")
        pages.append(f"{UPLOADS}{year}/11/")

    crawled_pages: set[str] = set()
    pdf_urls: set[str] = set()

    for page in pages:
        if page in crawled_pages:
            continue
        crawled_pages.add(page)
        try:
            html = _fetch_html(page)
        except Exception:
            continue
        for m in _PDF_RE.finditer(html):
            pdf_urls.add(_abs_url(page, m.group(1)))
        for m in _LINK_RE.finditer(html):
            href = m.group(1)
            if "/wp-content/uploads/" in href and not href.endswith(".pdf"):
                pages.append(_abs_url(page, href))

    # Also merge existing DISCOVERED entries not yet in catalogue
    for r in existing.get("documents") or []:
        if r.get("source_url"):
            pdf_urls.add(r["source_url"])

    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    cat_folder = ws.config("download_rules")["category_to_subject_folder"]
    seq = 500

    for url in sorted(pdf_urls):
        if url in seen:
            continue
        title = url.rsplit("/", 1)[-1]
        meta = _classify(url, title)
        if not meta:
            continue
        ckey, skey, category, doc_type, id_token = meta
        if not ckey:
            continue
        # general upper-primary → duplicate queue entry per matrix subject for class 6-8
        targets: list[tuple[str, str]] = []
        if skey == "general" and ckey in {"6", "7", "8"}:
            bcfg = ws.config("boards")["boards"]["icse"]
            for sk in bcfg["subjects_by_class"][ckey]:
                targets.append((ckey, sk))
        elif skey and skey in subjects:
            targets.append((ckey, skey))
        else:
            continue

        pr = probe_url(url)
        if not pr["ok"]:
            continue

        for ck, sk in targets:
            clabel = classes[ck]["class_label"]
            ccode = classes[ck]["code"]
            subj = subjects[sk]
            seq += 1
            orig = title
            stem = sanitize_filename(orig[:-4] if orig.lower().endswith(".pdf") else orig)
            rid = f"AKS-CISCE-{ccode}-{subj['code']}-{id_token}-DISC-{seq:06d}"
            fname = (f"CISCE_{clabel}_{subj['subject_folder']}_{doc_type.replace(' ', '')}-"
                     f"{stem}_2025-26_v1_English.pdf")
            dest = f"curriculum/icse/{clabel}/{subj['subject_folder']}/{cat_folder.get(category, 'Reference')}"
            found.append({
                "resource_id": rid,
                "expected_filename": fname,
                "original_filename": orig,
                "title": f"CISCE {clabel.replace('_', ' ')} {subj['display']} — {doc_type} ({orig})",
                "document_type": doc_type,
                "resource_category": category,
                "board": "CISCE",
                "class_label": clabel,
                "subject": subj["display"],
                "priority": "A",
                "source_portal": CISCE_BASE,
                "source_url": url,
                "source_website": CISCE_BASE,
                "publisher": "CISCE",
                "academic_year": "2025-26",
                "language": "English",
                "medium": "English",
                "license_status": "OFFICIAL_PUBLIC_CISCE_CURRICULUM_ANALYSIS_ONLY",
                "license_note": "CISCE official public curriculum resource (cisce.org crawl)",
                "destination": dest,
                "alternative_sources": [],
                "search_locations": [CISCE_BASE, url],
                "discovery_status": "URL_RESOLVED_CISCE_CRAWL",
                "status": "PENDING",
                "retry_count": 0,
                "cataloged_at": utcnow(),
            })
            seen.add(url)

    return found


def merge_queue(ws: Workspace, entries: list[dict]) -> tuple[int, int]:
    queue = load_json(ws.pm("download_queue"), []) or []
    have = {e.get("resource_id") for e in queue}
    added = 0
    for e in entries:
        if e["resource_id"] not in have:
            queue.append(e)
            added += 1
    write_json(ws.pm("download_queue"), queue)
    return added, len(queue)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--to-queue", action="store_true")
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    entries = discover(ws)
    out = ws.p("discovery_dir") / "icse" / "cisce_discovered.json"
    write_json(out, {"generated_at": utcnow(), "documents": entries})
    print(f"CISCE crawl: {len(entries)} new probe-confirmed entries")
    if args.to_queue:
        a, n = merge_queue(ws, entries)
        print(f"queue: +{a} (size {n})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
