#!/usr/bin/env python3
"""Classes 1-10 source acquisition wave — atomic discover→download→verify.

For every required source:
  DISCOVER → IMMEDIATE DOWNLOAD → VERIFY → HASH → STORE → RECORD → NEXT

Does NOT bulk-collect URLs first. Reuses existing files via hash/path inventory.
Scope: CBSE/NCERT, AP SCERT, Telangana SCERT, CISCE (free official only).

Usage:
  run_wave_classes_1_10.py [--board cbse|ap|telangana|icse|all] [--dry-run]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery", "reports", "acquisition"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, load_json, write_json, utcnow  # noqa: E402
from source_probe import probe_url  # noqa: E402
import downloader  # noqa: E402
import ncert_catalogue, ap_catalogue, telangana_catalogue, cisce_catalogue  # noqa: E402
import coverage_matrix, build_provenance  # noqa: E402

LOG = WORKSPACE_ROOT / "acquisition" / "wave_classes_1_10.log"
REPORT_JSON = WORKSPACE_ROOT / "acquisition" / "WAVE_CLASSES_1_10_RESULTS.json"
PRIMARY_CLASSES = {f"Class_{i:02d}" for i in range(1, 11)}

BOARD_FILTER = {
    "cbse": {"CBSE"},
    "ap": {"APSCERT"},
    "telangana": {"TSSCERT"},
    "icse": {"CISCE"},
    "all": {"CBSE", "APSCERT", "TSSCERT", "CISCE"},
}


def log(msg: str) -> None:
    line = f"[{utcnow()}] {msg}"
    print(line, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build_hash_inventory(ws: Workspace) -> dict:
    """Scan existing curriculum files → {sha256: path, ...}."""
    root = ws.p("resources_dir") / "curriculum"
    inv: dict[str, dict] = {}
    count = 0
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in {".pdf", ".zip"}:
            continue
        count += 1
        try:
            sha = _sha256(path)
            inv[sha] = {
                "path": str(path.relative_to(ws.root)),
                "size": path.stat().st_size,
                "name": path.name,
            }
        except OSError:
            pass
    return {"file_count": count, "hashes": inv}


def _final_path(ws: Workspace, entry: dict) -> Path:
    dest = entry.get("destination", "")
    fname = entry.get("expected_filename", "")
    return ws.p("resources_dir") / dest / fname


def _already_have(ws: Workspace, entry: dict, hash_inv: dict) -> str | None:
    """Return skip reason if the exact canonical file already exists."""
    fp = _final_path(ws, entry)
    if fp.is_file() and fp.stat().st_size > 0:
        return f"REUSE_PATH {fp}"
    # Same portal doc_id already stored under AP (doc-id dedupe)
    doc_id = entry.get("public_view_doc_id")
    if doc_id and entry.get("board") == "APSCERT":
        completed = load_json(ws.pm("completed_downloads"), []) or []
        for c in completed:
            if doc_id in (c.get("original_url") or ""):
                return f"REUSE_DOC_ID {doc_id}"
    return None


def _classify_bilingual(entry: dict) -> str:
    medium = (entry.get("medium") or "").lower()
    if "telugu" in medium or entry.get("board") == "APSCERT" and medium != "english":
        return "BILINGUAL_SOURCE_ENGLISH_PRESENT"
    return "ENGLISH"


def _acquire_one(ws: Workspace, entry: dict, engine, rules: dict,
                 hash_inv: dict, *, dry_run: bool) -> dict:
    """Discover→download→verify one entry; return outcome record."""
    rid = entry.get("resource_id", "?")
    outcome = {
        "resource_id": rid,
        "board": entry.get("board"),
        "class_label": entry.get("class_label"),
        "subject": entry.get("subject"),
        "title": entry.get("title"),
        "source_url": entry.get("source_url"),
        "classification": "UNKNOWN_REVIEW_REQUIRED",
        "bilingual_status": _classify_bilingual(entry),
        "verification_status": None,
        "local_path": None,
        "sha256": None,
        "detail": None,
    }

    reuse = _already_have(ws, entry, hash_inv)
    if reuse:
        outcome["classification"] = "VERIFIED_EXISTING_SOURCE"
        outcome["verification_status"] = "VERIFIED"
        outcome["detail"] = reuse
        fp = _final_path(ws, entry)
        if fp.is_file():
            outcome["local_path"] = str(fp.relative_to(ws.root))
            outcome["sha256"] = _sha256(fp)
        return outcome

    url = entry.get("source_url")
    if not url:
        outcome["classification"] = "SOURCE_MISSING"
        outcome["detail"] = "no source_url"
        return outcome

    if entry.get("license_status", "").startswith("UNOFFICIAL"):
        outcome["provenance_risk"] = "THIRD_PARTY_PROVENANCE_REVIEW"
    elif "OFFICIAL" in (entry.get("license_status") or ""):
        outcome["provenance_risk"] = "VERIFIED_OFFICIAL_SOURCE"

    pr = probe_url(url, referer=entry.get("source_portal"))
    if not pr["ok"] and entry.get("gdrive_file_id"):
        pr = {"ok": True, "reason": "GDRIVE_SKIP_PROBE"}
    if not pr["ok"] and "loadsupdocumentuploadbyid" in (url or ""):
        pr = {"ok": True, "reason": "AP_OFFICIAL_SKIP_PROBE"}
    if not pr["ok"] and "ncert.nic.in/textbook/pdf" in (url or ""):
        pr = {"ok": True, "reason": "NCERT_OFFICIAL_SKIP_PROBE"}
    if not pr["ok"]:
        outcome["classification"] = "DOWNLOAD_FAILED"
        outcome["detail"] = f"PROBE_FAIL {pr.get('reason')}"
        return outcome

    if dry_run:
        outcome["classification"] = "WOULD_DOWNLOAD"
        outcome["detail"] = "dry-run"
        return outcome

    ok, incoming, note = downloader._fetch(entry, ws, rules, allow_network=True)
    if not ok or not incoming:
        outcome["classification"] = "DOWNLOAD_FAILED"
        outcome["detail"] = f"FETCH_FAIL {note}"
        return outcome

    result = engine.verify_resource(entry, incoming)
    outcome["verification_status"] = result.status
    outcome["sha256"] = result.sha256
    outcome["local_path"] = result.final_path

    if result.status == "VERIFIED":
        lic = entry.get("license_status", "")
        if lic.startswith("UNOFFICIAL"):
            outcome["classification"] = "THIRD_PARTY_PROVENANCE_REVIEW"
        else:
            outcome["classification"] = "VERIFIED_OFFICIAL_SOURCE"
        outcome["detail"] = result.final_path
        if outcome["bilingual_status"] == "BILINGUAL_SOURCE_ENGLISH_PRESENT":
            outcome["english_content_status"] = "ENGLISH_PRESENT_BILINGUAL_LAYOUT"
    elif result.status == "DUPLICATE":
        outcome["classification"] = "VERIFIED_EXISTING_SOURCE"
        outcome["detail"] = result.detail
    else:
        outcome["classification"] = "DOWNLOAD_FAILED"
        outcome["detail"] = f"VERIFY_FAIL {result.reason_code}: {result.detail}"

    time.sleep(rules["networking"].get("polite_delay_seconds", 1))
    return outcome


def _iter_ncert_atomic(ws: Workspace):
    """Yield NCERT/CBSE entries one book at a time (Classes 1-10 focus)."""
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    board = ws.config("boards")["boards"]["cbse"]
    seq = 100
    for code, cnum, skey, title, head_bytes in ncert_catalogue.BOOKS:
        if cnum < 1 or cnum > 10:
            continue
        seq += 1
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        ccode = classes[ckey]["code"]
        subj = subjects[skey]
        rid = f"AKS-CBSE-{ccode}-{subj['code']}-TEXT-2025-{seq:06d}"
        fname = (f"NCERT_{clabel}_{subj['subject_folder']}_Textbook-{code}"
                 f"_2025-26_v1_English.zip")
        dest = f"curriculum/{board['board_folder']}/{clabel}/{subj['subject_folder']}/Textbooks"
        yield {
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": f"{code}dd.zip",
            "title": f"NCERT {clabel.replace('_', ' ')} {subj['display']} — {title}",
            "document_type": "Textbook",
            "resource_category": "textbook",
            "board": "CBSE",
            "class_label": clabel,
            "subject": subj["display"],
            "ncert_book_code": code,
            "priority": "A",
            "source_portal": "https://ncert.nic.in",
            "source_url": f"{ncert_catalogue.NCERT_PDF_BASE}/{code}dd.zip",
            "source_website": "https://ncert.nic.in",
            "publisher": "NCERT",
            "academic_year": "2025-26",
            "language": "English",
            "medium": "English",
            "license_status": "OFFICIAL_PUBLIC_NCERT_TEXTBOOK_ANALYSIS_ONLY",
            "destination": dest,
            "discovery_status": "URL_RESOLVED",
            "head_content_length": head_bytes,
            "status": "PENDING",
        }
    # Class 9 DIKSHA SST chapters
    for code, cnum, skey, book_title, chap_tag, chap_title, diksha_id, url, _bytes in ncert_catalogue.DIKSHA_MIRROR_CHAPTERS:
        if cnum != 9:
            continue
        seq += 1
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        ccode = classes[ckey]["code"]
        subj = subjects[skey]
        from workspace import sanitize_filename  # noqa: E402
        stem = sanitize_filename(f"{code}_{chap_tag}_{chap_title}")
        rid = f"AKS-CBSE-{ccode}-{subj['code']}-DIKSHA-{code.upper()}-{chap_tag}-2025-{seq:06d}"
        fname = f"NCERT_{clabel}_{subj['subject_folder']}_Textbook-{stem}_2025-26_v1_English.zip"
        dest = f"curriculum/cbse/{clabel}/{subj['subject_folder']}/Textbooks"
        yield {
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": url.rsplit("/", 1)[-1],
            "title": f"NCERT {clabel} {subj['display']} — {book_title}: {chap_title} (DIKSHA)",
            "document_type": "Textbook",
            "resource_category": "textbook",
            "board": "CBSE",
            "class_label": clabel,
            "subject": subj["display"],
            "ncert_book_code": code,
            "priority": "A",
            "source_portal": "https://diksha.gov.in",
            "source_url": url,
            "source_website": "https://diksha.gov.in",
            "publisher": "NCERT (DIKSHA mirror)",
            "academic_year": "2025-26",
            "language": "English",
            "medium": "English",
            "license_status": "OFFICIAL_GOVERNMENT_DIKSHA_MIRROR_NCERT",
            "destination": dest,
            "discovery_status": "URL_RESOLVED",
            "status": "PENDING",
        }


def _iter_ap_atomic(ws: Workspace):
    """Discover AP portal → yield+download each row immediately."""
    rows, _ = ap_catalogue.discover_rows(probe=True)
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    seen_docs: set[str] = set()
    for row in rows:
        if row["class"] not in ap_catalogue.CLASS_IDS:
            continue
        if row["doc_id"] in seen_docs:
            continue
        if not row["book_type"].lower().startswith("text"):
            continue
        skey = ap_catalogue._map_subject(row["subject"])
        if not skey:
            continue
        seen_docs.add(row["doc_id"])
        subj = subjects[skey]
        cinfo = classes[row["class"]]
        clabel = cinfo["class_label"]
        ccode = cinfo["code"]
        from workspace import sanitize_filename  # noqa: E402
        stem = sanitize_filename(row["book_name"].title())
        seq = ap_catalogue._stable_seq(row["doc_id"])
        rid = f"AKS-AP-{ccode}-{subj['code']}-TEXT-2025-{seq:06d}"
        fname = f"AP_{clabel}_{subj['subject_folder']}_Textbook-{stem}_2025-26_v1_English.pdf"
        yield {
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
            "source_portal": ap_catalogue.AP_PUBLIC_VIEW,
            "source_url": ap_catalogue.AP_DOC_URL.format(doc_id=row["doc_id"]),
            "source_website": ap_catalogue.CSE_BASE,
            "publisher": "AP SCERT",
            "academic_year": "2025-26",
            "language": "English",
            "medium": row["medium"],
            "license_status": "OFFICIAL_PUBLIC_AP_SCERT_TEXTBOOK_ANALYSIS_ONLY",
            "destination": f"curriculum/ap/{clabel}/{subj['subject_folder']}/Textbooks",
            "public_view_doc_id": row["doc_id"],
            "portal_subject": row["subject"],
            "portal_book_name": row["book_name"],
            "discovery_status": "URL_PROBE_CONFIRMED",
            "status": "PENDING",
        }


def _iter_ts_atomic(ws: Workspace):
    for entry in telangana_catalogue.build(ws):
        yield entry


def _iter_icse_atomic(ws: Workspace):
    for entry in cisce_catalogue.build(ws):
        if entry.get("class_label") in PRIMARY_CLASSES:
            yield entry


def run_wave(board: str, *, dry_run: bool) -> dict:
    ws = Workspace(WORKSPACE_ROOT)
    rules = ws.config("download_rules")
    rules = dict(rules)
    rules["allow_network"] = True
    engine = get_engine(WORKSPACE_ROOT)
    allowed = BOARD_FILTER[board]

    log(f"=== WAVE START board={board} dry_run={dry_run} ===")
    baseline = build_hash_inventory(ws)
    baseline_count = baseline["file_count"]
    log(f"baseline inventory: {baseline_count} PDF/ZIP files")

    generators = []
    if "CBSE" in allowed:
        generators.append(("ncert", _iter_ncert_atomic(ws)))
    if "APSCERT" in allowed:
        generators.append(("ap", _iter_ap_atomic(ws)))
    if "TSSCERT" in allowed:
        generators.append(("telangana", _iter_ts_atomic(ws)))
    if "CISCE" in allowed:
        generators.append(("icse", _iter_icse_atomic(ws)))

    outcomes: list[dict] = []
    all_entries: list[dict] = []
    stats = Counter()
    new_downloads = 0

    for label, gen in generators:
        log(f"--- board stream: {label} ---")
        for entry in gen:
            if entry.get("board") not in allowed:
                continue
            all_entries.append(entry)
            oc = _acquire_one(ws, entry, engine, rules, baseline, dry_run=dry_run)
            outcomes.append(oc)
            cls = oc["classification"]
            stats[cls] += 1
            if cls in ("VERIFIED_OFFICIAL_SOURCE", "THIRD_PARTY_PROVENANCE_REVIEW") and not dry_run:
                new_downloads += 1
            log(f"  {entry.get('board')} {entry.get('class_label')} {entry.get('subject')} → {cls} {oc.get('detail','')[:60]}")

    # Post-wave file count
    post = build_hash_inventory(ws)
    post_count = post["file_count"]

    # Merge outcomes into queue for provenance rebuild
    if not dry_run:
        queue = load_json(ws.pm("download_queue"), []) or []
        have = {e.get("resource_id") for e in queue}
        for entry in all_entries:
            if entry["resource_id"] not in have:
                queue.append(entry)
                have.add(entry["resource_id"])
        write_json(ws.pm("download_queue"), queue)
        import subprocess
        subprocess.run([sys.executable, str(SCRIPTS / "reports" / "coverage_matrix.py")],
                       cwd=str(WORKSPACE_ROOT), check=False)
        subprocess.run([sys.executable, str(SCRIPTS / "reports" / "build_provenance.py")],
                       cwd=str(WORKSPACE_ROOT), check=False)
        engine.generate_report()

    # Commercial / documented gaps
    commercial = [
        {"board": "CBSE", "class": "Class_10", "subject": "Computer Applications",
         "classification": "COMMERCIAL_TEXTBOOK_NOT_ACQUIRED",
         "note": "No free official NCERT textbook URL for Class 10 Computer Applications"},
        {"board": "CISCE", "class": "Class_01-10", "subject": "All textbooks",
         "classification": "COMMERCIAL_TEXTBOOK_NOT_ACQUIRED",
         "note": "ICSE textbooks are commercial; only syllabus/specimen acquired"},
        {"board": "TSSCERT", "class": "Class_05", "subject": "Social Science",
         "classification": "SOURCE_MISSING",
         "note": "No English-medium SST textbook found on DIKSHA or GDrive index"},
        {"board": "APSCERT", "class": "Class_05", "subject": "Social Science",
         "classification": "SOURCE_MISSING",
         "note": "AP portal has no Class 5 Social Studies textbook in English-content mediums"},
    ]

    result = {
        "wave": "CLASSES_1_10_SOURCE_ACQUISITION",
        "completed_at": utcnow(),
        "board_filter": board,
        "dry_run": dry_run,
        "baseline_file_count": baseline_count,
        "post_file_count": post_count,
        "new_files_downloaded": post_count - baseline_count,
        "new_verified_acquisitions": new_downloads,
        "outcome_stats": dict(stats),
        "outcomes": outcomes,
        "documented_gaps": commercial,
        "bilingual_sources": [o for o in outcomes
                              if o.get("bilingual_status") == "BILINGUAL_SOURCE_ENGLISH_PRESENT"
                              and o.get("classification") in ("VERIFIED_OFFICIAL_SOURCE",
                                                              "VERIFIED_EXISTING_SOURCE",
                                                              "THIRD_PARTY_PROVENANCE_REVIEW")],
    }
    write_json(REPORT_JSON, result)
    log(f"=== WAVE DONE baseline={baseline_count} post={post_count} new={post_count-baseline_count} stats={dict(stats)} ===")
    return result


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--board", choices=list(BOARD_FILTER), default="all")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    run_wave(args.board, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
