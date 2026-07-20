#!/usr/bin/env python3
"""Sequential board textbook fetch — crawl/discover then download one file at a time.

No bulk URL batching: each resource is probed and downloaded immediately before
moving to the next. SHA256 dedupe across ap / cbse / telangana prevents duplicates.

Usage:
  sequential_board_fetch.py [--board ap|cbse|telangana|all]
"""

from __future__ import annotations

import argparse
import hashlib
import html
import http.cookiejar
import json
import re
import shutil
import sys
import time
import urllib.request
import zipfile
from io import BytesIO
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, sanitize_filename, utcnow  # noqa: E402
import ncert_catalogue  # noqa: E402
import telangana_catalogue  # noqa: E402
import scert_portal_discover  # noqa: E402

LOG_DIR = WORKSPACE_ROOT / "resources/foundation/Cursor_Downloads/sequential_fetch"
CSE = "https://cse.ap.gov.in"
AP_PUBLIC = f"{CSE}/loadacademictextbookpublicview"
AP_DOC = f"{CSE}/loadsupdocumentuploadbyid?req_doc_id="
NCERT_BASE = ncert_catalogue.NCERT_PDF_BASE
UA = "AksharaCurriculumBot/1.0 (+education-repository)"


def log(msg: str) -> None:
    line = f"[{utcnow()}] {msg}"
    print(line, flush=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with (LOG_DIR / "run.log").open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build_hash_index(root: Path) -> dict[str, Path]:
    idx: dict[str, Path] = {}
    if not root.is_dir():
        return idx
    for f in root.rglob("*"):
        if not f.is_file() or f.stat().st_size < 5000:
            continue
        if f.suffix.lower() not in {".pdf", ".zip"}:
            continue
        try:
            idx[sha256_file(f)] = f
        except OSError:
            pass
    return idx


def ncert_code_on_disk(idx: dict[str, Path], code: str) -> Path | None:
    code = code.lower()
    for path in idx.values():
        if code in path.name.lower():
            return path
    return None


def fetch_url(opener, url: str, referer: str = "", timeout: int = 180) -> bytes:
    hdr = {"User-Agent": UA}
    if referer:
        hdr["Referer"] = referer
    with opener.open(urllib.request.Request(url, headers=hdr), timeout=timeout) as resp:
        return resp.read()


def fetch_gdrive(fid: str) -> bytes | None:
    import http.cookiejar  # noqa: E402

    base = "https://drive.usercontent.google.com/download"
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    headers = {"User-Agent": UA}

    def _open(url: str):
        return opener.open(urllib.request.Request(url, headers=headers), timeout=180)

    url = f"{base}?id={fid}&export=download"
    resp = _open(url)
    ctype = (resp.headers.get("Content-Type") or "").lower()
    if "text/html" in ctype:
        body = resp.read(200_000).decode("utf-8", "ignore")
        m = re.search(r"confirm=([0-9A-Za-z_-]+)", body)
        if not m:
            return None
        resp = _open(f"{base}?id={fid}&export=download&confirm={m.group(1)}")
        ctype = (resp.headers.get("Content-Type") or "").lower()
        if "text/html" in ctype:
            return None
    return resp.read()


def save_if_new(data: bytes, dest: Path, idx: dict[str, Path]) -> str:
    if len(data) < 5000:
        return "too_small"
    h = sha256_bytes(data)
    if h in idx:
        return "dup_hash"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    idx[h] = dest
    return "saved"


# ---- AP ----

_AP_ROW = re.compile(
    r"<tr>\s*<td[^>]*>(\d+)</td>\s*<td[^>]*>(\d+)</td>\s*<td[^>]*>([^<]+)</td>\s*"
    r"<td[^>]*>([^<]+)</td>\s*<td[^>]*>([^<]+)</td>\s*<td[^>]*>([^<]+)</td>.*?"
    r"loadsupdocumentuploadbyid\?req_doc_id=([^'\"]+)", re.S)
_CLASS = {str(i): f"Class_{i:02d}" for i in range(1, 11)}
_TE = {"Telugu-English", "English"}


def _ap_subject(subj: str, name: str) -> str:
    u, n = subj.upper(), name.upper()
    for m, f in [
        ("MATH", "Mathematics"), ("EVS", "Science"), ("ENGLISH", "English"),
        ("TELUGU", "Telugu"), ("HINDI", "Hindi"), ("URDU", "Urdu"),
        ("SANSKRIT", "Sanskrit"), ("PHYSICAL SCIENCE", "Physics"),
        ("BIOLOGY", "Biology"), ("BIOLOGICAL", "Biology"),
        ("GENERAL SCIENCE", "Science"), ("SCIENCE", "Science"),
        ("SOCIAL", "Social_Science"), ("GEOGRAPHY", "Geography"),
        ("HISTORY", "History"), ("ECONOMICS", "Economics"), ("POLITICAL", "Civics"),
    ]:
        if m in u or m in n:
            return f
    return "General"


def _ap_paths(row: dict) -> tuple[Path, str]:
    cl = _CLASS[row["class"]]
    sf = _ap_subject(row["subject"], row["book_name"])
    bt = row["book_type"].lower()
    if "work" in bt:
        folder, dtype = "Workbooks", "Workbook"
    elif "hand" in bt:
        folder, dtype = "Handbooks", "Handbook"
    else:
        folder, dtype = "Textbooks", "Textbook"
    stem = re.sub(r"\s+", "_", re.sub(r"[^\w\-. ]+", "_", row["book_name"].strip()))
    med = "English" if row["medium"] == "English" else "Telugu_English"
    fn = f"AP_{cl}_{sf}_{dtype}-{stem}_2025-26_v1_{med}.pdf"
    return Path(cl) / sf / folder / fn, fn


def fetch_ap(ws: Workspace, idx: dict[str, Path]) -> dict:
    root = ws.p("resources_dir") / "curriculum/ap"
    stats = {"saved": 0, "have": 0, "dup": 0, "fail": 0}
    cj = http.cookiejar.CookieJar()
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    hdr = {"User-Agent": UA, "Referer": AP_PUBLIC}
    op.open(urllib.request.Request(AP_PUBLIC, headers=hdr), timeout=30)
    req = urllib.request.Request(
        f"{AP_PUBLIC}?random=0", data=b"acYear=2025-2026",
        headers={**hdr, "Content-Type": "application/x-www-form-urlencoded"}, method="POST")
    with op.open(req, timeout=90) as resp:
        page = resp.read().decode("utf-8", "ignore")

    seen: set[str] = set()
    rows: list[dict] = []
    for m in _AP_ROW.finditer(page):
        doc = m.group(7)
        if doc in seen:
            continue
        seen.add(doc)
        row = {
            "class": m.group(2),
            "medium": html.unescape(m.group(3).strip()),
            "subject": html.unescape(m.group(4).strip()),
            "book_type": html.unescape(m.group(5).strip()),
            "book_name": html.unescape(m.group(6).strip()),
            "doc_id": doc,
        }
        if row["medium"] in _TE:
            rows.append(row)
    rows.sort(key=lambda r: (int(r["class"]), r["book_name"]))
    log(f"AP: {len(rows)} books to process")

    for i, row in enumerate(rows, 1):
        rel, fn = _ap_paths(row)
        dest = root / rel
        label = f"Class {row['class']} {row['book_name'][:40]}"
        if dest.exists() and dest.stat().st_size > 5000:
            stats["have"] += 1
            log(f"AP [{i}/{len(rows)}] SKIP already {label}")
            continue
        log(f"AP [{i}/{len(rows)}] DOWNLOAD {label}")
        try:
            data = fetch_url(op, AP_DOC + row["doc_id"], AP_PUBLIC)
            if data[:4] != b"%PDF":
                stats["fail"] += 1
                log(f"AP [{i}/{len(rows)}] FAIL not PDF {label}")
                continue
            st = save_if_new(data, dest, idx)
            if st == "saved":
                stats["saved"] += 1
                log(f"AP [{i}/{len(rows)}] OK {fn}")
            elif st == "dup_hash":
                stats["dup"] += 1
                log(f"AP [{i}/{len(rows)}] SKIP dup {label}")
            else:
                stats["fail"] += 1
            time.sleep(0.35)
        except Exception as exc:  # noqa: BLE001
            stats["fail"] += 1
            log(f"AP [{i}/{len(rows)}] ERROR {label}: {exc}")
    return stats


# ---- CBSE (NCERT) ----

def fetch_cbse(ws: Workspace, idx: dict[str, Path]) -> dict:
    root = ws.p("resources_dir") / "curriculum/cbse"
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    stats = {"saved": 0, "have": 0, "dup": 0, "fail": 0}
    op = urllib.request.build_opener()
    items: list[tuple[str, dict]] = []

    for code, cnum, skey, title, _sz in ncert_catalogue.BOOKS:
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        subj = subjects[skey]
        fname = f"NCERT_{clabel}_{subj['subject_folder']}_Textbook-{code}_2025-26_v1_English.zip"
        dest = root / clabel / subj["subject_folder"] / "Textbooks" / fname
        items.append(("ncert_zip", {
            "code": code, "title": title, "dest": dest, "fname": fname,
            "url": f"{NCERT_BASE}/{code}dd.zip", "clabel": clabel,
        }))

    for code, cnum, skey, book_title, chap_tag, chap_title, _did, url, _b in ncert_catalogue.DIKSHA_MIRROR_CHAPTERS:
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        subj = subjects[skey]
        stem = sanitize_filename(f"{code}_{chap_tag}_{chap_title}")
        fname = f"NCERT_{clabel}_{subj['subject_folder']}_Textbook-{stem}_2025-26_v1_English.zip"
        dest = root / clabel / subj["subject_folder"] / "Textbooks" / fname
        items.append(("diksha", {
            "code": code, "title": f"{book_title}/{chap_title}", "dest": dest,
            "fname": fname, "url": url, "clabel": clabel,
        }))

    log(f"CBSE: {len(items)} resources to process")
    for i, (kind, item) in enumerate(items, 1):
        dest: Path = item["dest"]
        label = f"{item['clabel']} {item['code']} {item['title'][:35]}"
        if dest.exists() and dest.stat().st_size > 5000:
            stats["have"] += 1
            log(f"CBSE [{i}/{len(items)}] SKIP already {label}")
            continue
        if ncert_code_on_disk(idx, item["code"]):
            stats["dup"] += 1
            log(f"CBSE [{i}/{len(items)}] SKIP dup code {label}")
            continue
        log(f"CBSE [{i}/{len(items)}] DOWNLOAD {label}")
        try:
            data = fetch_url(op, item["url"], ncert_catalogue.NCERT_LISTING)
            if data[:2] != b"PK":
                stats["fail"] += 1
                log(f"CBSE [{i}/{len(items)}] FAIL not zip {label}")
                continue
            st = save_if_new(data, dest, idx)
            if st == "saved":
                stats["saved"] += 1
                log(f"CBSE [{i}/{len(items)}] OK {item['fname']}")
            elif st == "dup_hash":
                stats["dup"] += 1
                log(f"CBSE [{i}/{len(items)}] SKIP dup hash {label}")
            else:
                stats["fail"] += 1
            time.sleep(0.5)
        except Exception as exc:  # noqa: BLE001
            stats["fail"] += 1
            log(f"CBSE [{i}/{len(items)}] ERROR {label}: {exc}")
    return stats


# ---- Telangana ----

def fetch_telangana(ws: Workspace, idx: dict[str, Path]) -> dict:
    root = ws.p("resources_dir") / "curriculum/telangana"
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    stats = {"saved": 0, "have": 0, "dup": 0, "fail": 0}
    op = urllib.request.build_opener()
    items: list[dict] = []

    # Official SCERT crawl
    try:
        for entry in scert_portal_discover.discover_board(ws, "telangana"):
            if entry.get("resource_category") != "textbook":
                continue
            dest = root.parent / entry["destination"] / entry["expected_filename"]
            # destination is curriculum/telangana/...
            dest = ws.p("resources_dir") / entry["destination"] / entry["expected_filename"]
            items.append({
                "kind": "scert", "dest": dest, "fname": entry["expected_filename"],
                "url": entry["source_url"], "label": entry["title"][:50],
            })
    except Exception as exc:  # noqa: BLE001
        log(f"TS SCERT crawl error: {exc}")

    for cnum, skey, label, fid in telangana_catalogue.GDRIVE_BOOKS:
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        subj = subjects[skey]
        stem = sanitize_filename(label)
        fname = f"TS_{clabel}_{subj['subject_folder']}_Textbook-{stem}_2025-26_v1_English.pdf"
        dest = root / clabel / subj["subject_folder"] / "Textbooks" / fname
        items.append({
            "kind": "gdrive", "dest": dest, "fname": fname, "fid": fid,
            "label": f"{clabel} {label}", "url": telangana_catalogue.DRIVE_DL.format(fid=fid),
        })

    for cnum, skey, label, _did, url in telangana_catalogue.DIKSHA_BOOKS:
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        subj = subjects[skey]
        stem = sanitize_filename(f"DIKSHA_{label}")
        fname = f"TS_{clabel}_{subj['subject_folder']}_Textbook-{stem}_2025-26_v1_English.zip"
        dest = root / clabel / subj["subject_folder"] / "Textbooks" / fname
        items.append({
            "kind": "diksha", "dest": dest, "fname": fname, "url": url,
            "label": f"{clabel} {label}",
        })

    log(f"TS: {len(items)} resources to process")
    for i, item in enumerate(items, 1):
        dest: Path = item["dest"]
        label = item["label"]
        if dest.exists() and dest.stat().st_size > 5000:
            stats["have"] += 1
            log(f"TS [{i}/{len(items)}] SKIP already {label}")
            continue
        log(f"TS [{i}/{len(items)}] DOWNLOAD {label}")
        try:
            if item.get("kind") == "gdrive":
                data = fetch_gdrive(item["fid"])
            else:
                data = fetch_url(op, item["url"], telangana_catalogue.DIKSHA_PORTAL)
            if not data:
                stats["fail"] += 1
                log(f"TS [{i}/{len(items)}] FAIL empty {label}")
                continue
            if dest.suffix.lower() == ".pdf" and data[:4] != b"%PDF":
                stats["fail"] += 1
                log(f"TS [{i}/{len(items)}] FAIL not PDF {label}")
                continue
            if dest.suffix.lower() == ".zip" and data[:2] != b"PK":
                stats["fail"] += 1
                log(f"TS [{i}/{len(items)}] FAIL not zip {label}")
                continue
            st = save_if_new(data, dest, idx)
            if st == "saved":
                stats["saved"] += 1
                log(f"TS [{i}/{len(items)}] OK {item['fname']}")
            elif st == "dup_hash":
                stats["dup"] += 1
                log(f"TS [{i}/{len(items)}] SKIP dup {label}")
            else:
                stats["fail"] += 1
            time.sleep(0.5)
        except Exception as exc:  # noqa: BLE001
            stats["fail"] += 1
            log(f"TS [{i}/{len(items)}] ERROR {label}: {exc}")
    return stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--board", default="all", choices=["ap", "cbse", "telangana", "all"])
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    res_root = ws.p("resources_dir") / "curriculum"
    log("Building cross-board hash index...")
    idx: dict[str, Path] = {}
    for b in ("ap", "cbse", "telangana"):
        for h, p in build_hash_index(res_root / b).items():
            idx[h] = p
    log(f"Indexed {len(idx)} unique files")

    summary: dict = {}
    if args.board in ("ap", "all"):
        log("=== AP ===")
        summary["ap"] = fetch_ap(ws, idx)
    if args.board in ("cbse", "all"):
        log("=== CBSE ===")
        summary["cbse"] = fetch_cbse(ws, idx)
    if args.board in ("telangana", "all"):
        log("=== TS ===")
        summary["telangana"] = fetch_telangana(ws, idx)

    log(f"DONE {json.dumps(summary)}")
    (LOG_DIR / "summary.json").write_text(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
