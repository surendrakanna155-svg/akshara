#!/usr/bin/env python3
"""Direct paper fetch — scrape official sources, download one-by-one, verify + store.

No DOWNLOAD_QUEUE.json. Each file:
  1. discovered from live listing (CBSE) or cisce_source_urls.json (CISCE)
  2. HEAD-probed
  3. downloaded to downloads/incoming/
  4. verified (V1-V11) and moved to resources/... correct folder

Usage:
  fetch_papers_direct.py [--board cbse|cisce|all] [--dry-run] [--limit N]
"""

from __future__ import annotations

import argparse
import re
import sys
import time
import urllib.request
import zlib
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, load_json, utcnow, sanitize_filename  # noqa: E402
from source_probe import probe_url  # noqa: E402
import downloader  # noqa: E402

PORTAL = "https://cbseacademic.nic.in"
CBSE_INDEX = f"{PORTAL}/index.html"

LISTING_HINTS = (
    ("SQP_CLASSX_2025-26.html", (10,)),  # latest official secondary SQP — one class to avoid dup downloads
)

SUBJ_CODE = {
    "mathematics": "MATH", "science": "SCI", "social_science": "SST",
    "english": "ENG", "computer_science": "CS",
    "physics": "PHY", "chemistry": "CHEM", "biology": "BIO",
    "history": "HIST", "geography": "GEO",
}

CISCE_CLASS = {"class-9": "9", "class-10": "10"}
CISCE_SUBJ = {
    "mathematics": "mathematics", "physics": "physics", "chemistry": "chemistry",
    "biology": "biology", "geography": "geography",
    "history-and-civics": "history", "english": "english",
    "english-language": "english", "literature-in-english": "english",
    "computer-applications": "computer_science",
}
CISCE_TYPE = {
    "specimen-paper": ("sample_paper", "Sample Paper", "SAMP"),
}


def _abs_url(href: str) -> str:
    return href if href.startswith("http") else f"{PORTAL}/{href.lstrip('/')}"


def _pick_english_pdf(links: list[str]) -> str | None:
    """Prefer non-Hindi English PDF from a link column."""
    pdfs = [_abs_url(h) for h in links if h.lower().endswith(".pdf")]
    en = [u for u in pdfs if not re.search(r"[_-]hi\.pdf$", u, re.I)]
    return (en or pdfs)[0] if pdfs else None


def _match_subject(label: str, in_scope: set[str], subjects_cfg: dict) -> str | None:
    norm = re.sub(r"[^a-z0-9]+", " ", label.lower()).strip()
    # reject electives / false positives before fuzzy match
    if "home science" in norm or "book keeping" in norm or "elements of business" in norm:
        return None
    if norm.startswith("mathematics"):
        return "mathematics" if "mathematics" in in_scope else None
    if norm == "science":
        return "science" if "science" in in_scope else None
    if "social science" in norm:
        return "social_science" if "social_science" in in_scope else None
    if "computer application" in norm:
        return "computer_science" if "computer_science" in in_scope else None
    if norm.startswith("english"):
        return "english" if "english" in in_scope else None
    best: tuple[int, str] | None = None
    for slug in in_scope:
        s = subjects_cfg["subjects"][slug]
        needles = [s["display"].lower(), slug.replace("_", " ")]
        needles += [a.lower() for a in s.get("aliases", [])]
        for n in needles:
            if not n or len(n) < 4:
                continue
            if n in norm:
                score = len(n)
                if best is None or score > best[0]:
                    best = (score, slug)
    return best[1] if best else None


def _prefer_row_url(label: str, sqp_links: list[str], ms_links: list[str]) -> tuple[str | None, str | None]:
    """Pick best SQP/MS URLs for a canonical subject (Standard > Basic, Eng L > Comm)."""
    sqp = _pick_english_pdf(sqp_links)
    ms = _pick_english_pdf(ms_links)
    norm = re.sub(r"[^a-z0-9]+", " ", label.lower()).strip()
    if "mathematics" in norm and "standard" in norm:
        for links, out in ((sqp_links, "sqp"), (ms_links, "ms")):
            pref = next((u for u in (_pick_english_pdf([h]) for h in links) if u and "MathsStandard" in u), None)
            if pref:
                if out == "sqp":
                    sqp = pref
                else:
                    ms = pref
    if "english" in norm and "literature" in norm:
        for links, out in ((sqp_links, "sqp"), (ms_links, "ms")):
            pref = next((u for u in (_pick_english_pdf([h]) for h in links) if u and "EnglishL" in u), None)
            if pref:
                if out == "sqp":
                    sqp = pref
                else:
                    ms = pref
    return sqp, ms


def _rid(board: str, ccode: str, scode: str, token: str, url: str) -> str:
    seq = zlib.crc32(url.encode()) & 0xFFFFFF
    return f"AKS-{board}-{ccode}-{scode}-{token}-2025-{seq:06d}"


def _already_have(ws: Workspace, url: str) -> bool:
    master = load_json(ws.index("master"), {}) or {}
    for e in master.values():
        if e.get("verification_status") == "VERIFIED" and e.get("source_url") == url:
            return True
    return False


def _make_entry(
    ws: Workspace,
    *,
    board: str,
    class_num: int,
    subject_slug: str,
    category: str,
    doc_type: str,
    id_token: str,
    url: str,
    listing: str,
    title_suffix: str,
) -> dict:
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    cat_folder = ws.config("download_rules")["category_to_subject_folder"]
    board_folder = ws.config("boards")["boards"]["cbse" if board == "CBSE" else "icse"]["board_folder"]

    ckey = str(class_num)
    clabel = classes[ckey]["class_label"]
    ccode = classes[ckey]["code"]
    subj = subjects[subject_slug]
    scode = SUBJ_CODE.get(subject_slug, subj["code"])
    orig = url.rsplit("/", 1)[-1]
    stem = sanitize_filename(orig[:-4] if orig.lower().endswith(".pdf") else orig)
    kind = "SamplePaper" if category == "sample_paper" else "MarkingScheme"
    fname = f"{board}_{clabel}_{subj['subject_folder']}_{kind}-{stem}_2025-26_v1_English.pdf"
    dest = f"curriculum/{board_folder}/{clabel}/{subj['subject_folder']}/{cat_folder.get(category, 'Reference')}"
    return {
        "resource_id": _rid(board, ccode, scode, id_token, url),
        "expected_filename": fname,
        "original_filename": orig,
        "title": f"{board} {clabel.replace('_', ' ')} {subj['display']} — {title_suffix}",
        "document_type": doc_type,
        "resource_category": category,
        "board": board,
        "class_label": clabel,
        "subject": subj["display"],
        "priority": "A",
        "source_portal": listing,
        "source_url": url,
        "source_website": listing,
        "publisher": board,
        "academic_year": "2025-26",
        "language": "English",
        "medium": "English",
        "license_status": f"OFFICIAL_PUBLIC_{board}_CURRICULUM_ANALYSIS_ONLY",
        "license_note": f"{board} official public paper; local archive + analysis only",
        "destination": dest,
        "alternative_sources": [],
        "search_locations": [listing, url],
        "discovery_status": "URL_RESOLVED",
        "status": "PENDING",
        "retry_count": 0,
        "cataloged_at": utcnow(),
    }


def discover_cbse(ws: Workspace) -> list[dict]:
    """Scrape live CBSE SQP listing pages → in-scope paper entries."""
    boards = ws.config("boards")["boards"]["cbse"]
    subjects_cfg = ws.config("subjects")
    in_scope_all: set[str] = set()
    for slugs in boards["subjects_by_class"].values():
        in_scope_all.update(slugs)

    # find listing URLs from official index
    index_html = urllib.request.urlopen(CBSE_INDEX, timeout=30).read().decode("utf-8", "replace")
    listing_urls: list[tuple[str, tuple[int, ...]]] = []
    for hint, classes in LISTING_HINTS:
        m = re.search(rf'href="([^"]*{re.escape(hint)}[^"]*)"', index_html, re.I)
        if m:
            listing_urls.append((_abs_url(m.group(1)), classes))
    if not listing_urls:
        listing_urls.append((f"{PORTAL}/SQP_CLASSX_2025-26.html", (9, 10)))

    items: list[dict] = []
    seen_urls: set[str] = set()
    for listing, class_nums in listing_urls:
        html = urllib.request.urlopen(listing, timeout=30).read().decode("utf-8", "replace")
        for row in re.findall(r"<tr[^>]*>(.*?)</tr>", html, re.S | re.I):
            tds = re.findall(r"<td[^>]*>(.*?)</td>", row, re.S | re.I)
            if len(tds) < 3:
                continue
            subj_label = re.sub(r"<[^>]+>", "", tds[0]).strip()
            sqp_links = re.findall(r'href="([^"]+)"', tds[1])
            ms_links = re.findall(r'href="([^"]+)"', tds[2])
            slug = _match_subject(subj_label, in_scope_all, subjects_cfg)
            if not slug:
                continue
            sqp_url, ms_url = _prefer_row_url(subj_label, sqp_links, ms_links)
            for cnum in class_nums:
                if slug not in boards["subjects_by_class"].get(str(cnum), []):
                    continue
                for url, category, doc_type, token, suffix in (
                    (sqp_url, "sample_paper", "Sample Paper", "SAMP", "Sample Question Paper 2025-26"),
                    (ms_url, "blueprint", "Blueprint", "BLUE", "Marking Scheme 2025-26"),
                ):
                    if not url or url in seen_urls:
                        continue
                    seen_urls.add(url)
                    items.append(_make_entry(
                        ws, board="CBSE", class_num=cnum, subject_slug=slug,
                        category=category, doc_type=doc_type, id_token=token,
                        url=url, listing=listing, title_suffix=suffix,
                    ))
    return items


def discover_cisce(ws: Workspace) -> list[dict]:
    """Resolved CISCE specimen papers from discovery/icse/cisce_source_urls.json."""
    src = load_json(ws.root / "discovery/icse/cisce_source_urls.json")
    if not src:
        return []
    boards = ws.config("boards")["boards"]["icse"]
    subjects_cfg = ws.config("subjects")
    items: list[dict] = []
    recs = src["documents"] if isinstance(src, dict) else src
    for r in recs:
        cnum = CISCE_CLASS.get(r.get("class"))
        slug = CISCE_SUBJ.get(r.get("subject"))
        tinfo = CISCE_TYPE.get(r.get("type"))
        url = r.get("source_url")
        if not (cnum and slug and tinfo and url):
            continue
        if slug not in boards["subjects_by_class"].get(cnum, []):
            # history-and-civics → history slug in matrix
            if r.get("subject") == "history-and-civics" and "history" in boards["subjects_by_class"].get(cnum, []):
                slug = "history"
            else:
                continue
        category, doc_type, token = tinfo
        items.append(_make_entry(
            ws, board="CISCE", class_num=int(cnum), subject_slug=slug,
            category=category, doc_type=doc_type, id_token=token,
            url=url, listing="https://cisce.org", title_suffix=r.get("title", "Specimen Paper"),
        ))
    return items


def _mirror_class10_from_class9(ws: Workspace, engine, rules: dict) -> int:
    """Copy verified Class_09 papers to Class_10 folders (same CBSE secondary SQP)."""
    master = load_json(ws.index("master"), {}) or {}
    classes = ws.config("classes")["classes"]
    cat_folder = ws.config("download_rules")["category_to_subject_folder"]
    mirrored = 0
    for e in master.values():
        if e.get("verification_status") != "VERIFIED" or e.get("board") != "CBSE":
            continue
        if e.get("class_label") != "Class_09":
            continue
        cat = None
        dt = e.get("document_type", "")
        if dt == "Sample Paper":
            cat = "sample_paper"
        elif dt == "Blueprint":
            cat = "blueprint"
        else:
            continue
        subj = e.get("subject")
        subj_folder = next(
            (s["subject_folder"] for s in ws.config("subjects")["subjects"].values()
             if s["display"] == subj), None)
        if not subj_folder:
            continue
        src = ws.root / e["repository_path"]
        if not src.is_file():
            continue
        cl10 = classes["10"]["class_label"]
        fname = e.get("filename", src.name).replace("Class_09", "Class_10")
        dest_rel = (f"curriculum/cbse/{cl10}/{subj_folder}/"
                    f"{cat_folder.get(cat, 'Reference')}")
        dest = ws.p("resources_dir") / dest_rel / fname
        if dest.is_file():
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        import shutil
        incoming = ws.p("downloads_incoming") / fname
        shutil.copy(src, incoming)
        entry = {
            "resource_id": e["resource_id"].replace("-09-", "-10-"),
            "expected_filename": fname,
            "document_type": dt,
            "resource_category": cat,
            "board": "CBSE",
            "class_label": cl10,
            "subject": subj,
            "source_url": e.get("source_url"),
            "destination": dest_rel,
            "publisher": "CBSE",
            "academic_year": "2025-26",
            "language": "English",
            "medium": "English",
            "license_status": e.get("license_status", ""),
            "license_note": e.get("license_note", ""),
        }
        result = engine.verify_resource(entry, incoming)
        if result.status in ("VERIFIED", "DUPLICATE"):
            mirrored += 1
            print(f"MIRROR {subj} {cat} -> {dest}")
    return mirrored


def fetch_one(ws: Workspace, entry: dict, engine, rules: dict, *, dry_run: bool) -> str:
    url = entry["source_url"]
    if _already_have(ws, url):
        return "SKIP_ALREADY_VERIFIED"
    pr = probe_url(url, referer=entry.get("source_portal"))
    if not pr["ok"]:
        return f"SKIP_PROBE_{pr['reason']}"
    if dry_run:
        return f"WOULD_FETCH {entry['class_label']} {entry['subject']} {entry['resource_category']}"

    ok, incoming, note = downloader._fetch(entry, ws, rules, allow_network=True)
    if not ok or not incoming:
        return f"FAIL_FETCH {note}"

    result = engine.verify_resource(entry, incoming)
    if result.status == "VERIFIED":
        return f"OK {result.final_path}"
    if result.status == "DUPLICATE":
        return f"OK_DUPLICATE {result.detail}"
    return f"FAIL_VERIFY {result.reason_code} {result.detail}"


def run(board: str, dry_run: bool, limit: int | None) -> dict:
    ws = Workspace(WORKSPACE_ROOT)
    rules = ws.config("download_rules")
    engine = get_engine(WORKSPACE_ROOT)

    items: list[dict] = []
    if board in ("cbse", "all"):
        items.extend(discover_cbse(ws))
    if board in ("cisce", "all"):
        items.extend(discover_cisce(ws))

    # global URL dedupe (keep first = highest-priority class/subject)
    deduped: list[dict] = []
    seen: set[str] = set()
    for e in items:
        u = e["source_url"]
        if u in seen:
            continue
        seen.add(u)
        deduped.append(e)
    items = deduped

    stats = {"discovered": len(items), "ok": 0, "skip": 0, "fail": 0}
    print(f"discovered {len(items)} paper URLs (board={board})")

    for i, entry in enumerate(items, 1):
        if limit is not None and stats["ok"] + stats["fail"] >= limit:
            break
        label = f"[{i}/{len(items)}] {entry['board']} {entry['class_label']} {entry['subject']} {entry['resource_category']}"
        print(label, end=" … ", flush=True)
        try:
            outcome = fetch_one(ws, entry, engine, rules, dry_run=dry_run)
        except Exception as exc:  # noqa: BLE001
            outcome = f"ERROR {type(exc).__name__}: {exc}"
        print(outcome)
        if outcome.startswith("OK"):
            stats["ok"] += 1
        elif outcome.startswith("SKIP"):
            stats["skip"] += 1
        else:
            stats["fail"] += 1
        if not dry_run:
            time.sleep(rules["networking"].get("polite_delay_seconds", 2))

    engine.generate_report()
    return stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--board", choices=["cbse", "cisce", "all"], default="all")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--mirror-class10", action="store_true",
                    help="copy verified CBSE Class_09 papers into Class_10 folders")
    args = ap.parse_args()
    if args.mirror_class10 and not args.dry_run:
        ws = Workspace(WORKSPACE_ROOT)
        engine = get_engine(WORKSPACE_ROOT)
        rules = ws.config("download_rules")
        n = _mirror_class10_from_class9(ws, engine, rules)
        engine.generate_report()
        print(f"mirrored {n} Class_09 → Class_10 paper(s)")
        return 0

    stats = run(args.board, args.dry_run, args.limit)
    print("done:", stats)
    return 0 if stats["fail"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
