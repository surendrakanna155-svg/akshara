#!/usr/bin/env python3
"""Exhaustive matrix gap-fill wave — discover + acquire for 148-cell readiness.

Targets every PARTIAL/MISSING Board→Class→Subject cell from SUBJECT_COVERAGE_AUDIT.
Does not treat the 234-slot universe as complete.

Usage:
  run_matrix_gap_fill.py [--dry-run] [--board all|ap|telangana|icse]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery", "reports", "acquisition"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, load_json, write_json, utcnow  # noqa: E402
import downloader  # noqa: E402
import diksha_catalogue  # noqa: E402
import cisce_catalogue  # noqa: E402
import cisce_discover  # noqa: E402
import ap_catalogue  # noqa: E402
import telangana_catalogue  # noqa: E402
import build_provenance  # noqa: E402
import provenance_reconciliation  # noqa: E402

LOG = WORKSPACE_ROOT / "acquisition" / "matrix_gap_fill.log"
AUDIT_JSON = WORKSPACE_ROOT / "reports" / "SUBJECT_COVERAGE_AUDIT.json"
GAP_REPORT = WORKSPACE_ROOT / "reports" / "MATRIX_GAP_FILL_REPORT.json"

BOARD_KEYS = {
    "ap": "APSCERT",
    "telangana": "TSSCERT",
    "icse": "CISCE",
    "cbse": "CBSE",
    "all": None,
}


def log(msg: str) -> None:
    line = f"[{utcnow()}] {msg}"
    print(line, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def _load_gaps(ws: Workspace) -> list[dict]:
    audit = load_json(AUDIT_JSON, {})
    if not audit.get("rows"):
        import subject_coverage_audit  # noqa: E402
        audit = subject_coverage_audit.audit(ws)
        write_json(AUDIT_JSON, audit)
    return [r for r in audit["rows"] if r["status"] in ("PARTIAL", "MISSING")]


def _merge_queue(ws: Workspace, entries: list[dict]) -> int:
    queue = load_json(ws.pm("download_queue"), []) or []
    have_rid = {e.get("resource_id") for e in queue}
    have_url = {e.get("source_url") for e in queue if e.get("source_url")}
    added = 0
    for e in entries:
        if e.get("resource_id") in have_rid:
            continue
        if e.get("source_url") in have_url:
            continue
        queue.append(e)
        have_rid.add(e.get("resource_id"))
        if e.get("source_url"):
            have_url.add(e["source_url"])
        added += 1
    write_json(ws.pm("download_queue"), queue)
    return added


def _gap_targets(gaps: list[dict], board_filter: str | None) -> set[tuple[str, str, str]]:
    out: set[tuple[str, str, str]] = set()
    for g in gaps:
        if board_filter and g["board"] != board_filter:
            continue
        out.add((g["board"], g["class"], g["subject"]))
    return out


def discover_phase(ws: Workspace, targets: set[tuple[str, str, str]]) -> dict:
    stats: dict[str, int] = {}
    entries: list[dict] = []

    boards_needed = {b for b, _, _ in targets}

    if "CISCE" in boards_needed:
        cisce_cat = cisce_catalogue.build(ws)
        cisce_new = cisce_discover.discover(ws)
        entries.extend(cisce_cat)
        entries.extend(cisce_new)
        stats["cisce_catalogue"] = len(cisce_cat)
        stats["cisce_crawl"] = len(cisce_new)

    if "TSSCERT" in boards_needed or "APSCERT" in boards_needed:
        diksha = diksha_catalogue.build(ws, probe=True)
        filtered = [e for e in diksha if e["board"] in boards_needed]
        entries.extend(filtered)
        stats["diksha"] = len(filtered)

    if "TSSCERT" in boards_needed:
        ts_cat = telangana_catalogue.build(ws)
        # Only queue DIKSHA-trusted TS entries in gap fill (skip GDrive re-queue)
        ts_trusted = [e for e in ts_cat if "DIKSHA" in e.get("license_status", "")]
        entries.extend(ts_trusted)
        stats["ts_diksha_static"] = len(ts_trusted)

    if "APSCERT" in boards_needed:
        ap_cat = ap_catalogue.build(ws)
        entries.extend(ap_cat)
        stats["ap_portal"] = len(ap_cat)

    added = _merge_queue(ws, entries)
    stats["queue_added"] = added
    return stats


def acquire_phase(ws: Workspace, *, dry_run: bool, limit: int | None) -> dict:
    if dry_run:
        queue = load_json(ws.pm("download_queue"), []) or []
        pending = [e for e in queue if e.get("status") not in ("VERIFIED", "NOT_PUBLICLY_AVAILABLE")]
        return {"dry_run": True, "pending": len(pending)}

    rules = ws.config("download_rules")
    rules = dict(rules)
    rules["allow_network"] = True
    rules["default_mode"] = "live"
    tmp_rules = ws.configs_dir / "download_rules.live.json"
    write_json(tmp_rules, rules)

    argv = ["downloader.py", "--workspace", str(ws.root), "--allow-network"]
    if limit:
        argv.extend(["--limit", str(limit)])
    old = sys.argv
    sys.argv = argv
    try:
        rc = downloader.main()
    finally:
        sys.argv = old
        tmp_rules.unlink(missing_ok=True)
    completed = load_json(ws.pm("completed_downloads"), []) or []
    return {"downloader_rc": rc, "completed_total": len(completed)}


def _slot_id(board: str, clabel: str, subject: str, title: str, rtype: str) -> str:
    raw = f"{board}|{clabel}|{subject}|{title}|{rtype}|gapfill"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]


def _trusted_license(lic: str) -> bool:
    if not lic or lic.startswith("UNOFFICIAL"):
        return False
    if "DIKSHA" in lic or lic.startswith("OFFICIAL"):
        return True
    return not lic.startswith("UNOFFICIAL")


def _extend_matrix(ws: Workspace) -> int:
    """Append verified gap-fill resources to CANONICAL_CURRICULUM_MATRIX."""
    matrix_path = ws.p("reports_dir") / "CANONICAL_CURRICULUM_MATRIX.json"
    matrix = load_json(matrix_path, {"slots": []})
    have = {s.get("slot_id") for s in matrix.get("slots", [])}
    completed = load_json(ws.pm("completed_downloads"), []) or []
    queue = {e["resource_id"]: e for e in (load_json(ws.pm("download_queue"), []) or [])}
    added = 0

    rtype_map = {
        "textbook": "CORE_TEXTBOOK",
        "syllabus": "SYLLABUS",
        "sample_paper": "SAMPLE_QUESTION_PAPER",
        "question_bank": "ASSESSMENT_RESOURCE",
        "previous_paper": "SAMPLE_QUESTION_PAPER",
        "blueprint": "MARKING_SCHEME",
    }
    tier_map = {
        "OFFICIAL_PUBLIC_CISCE_CURRICULUM_ANALYSIS_ONLY": "A1_OFFICIAL_DIRECT",
        "OFFICIAL_GOVERNMENT_DIKSHA_MIRROR_TS_SCERT": "A2_OFFICIAL_GOVERNMENT_MIRROR",
        "OFFICIAL_GOVERNMENT_DIKSHA_MIRROR": "A2_OFFICIAL_GOVERNMENT_MIRROR",
        "OFFICIAL_MIRROR_DIKSHA_TEXTBOOK_ANALYSIS_ONLY": "A2_OFFICIAL_GOVERNMENT_MIRROR",
        "OFFICIAL_PUBLIC_AP_SCERT_TEXTBOOK_ANALYSIS_ONLY": "A1_OFFICIAL_DIRECT",
        "OFFICIAL_PUBLIC_TS_SCERT_DIRECT": "A1_OFFICIAL_DIRECT",
    }

    for c in completed:
        q = queue.get(c.get("resource_id"), {})
        row = {**q, **c}
        vstat = row.get("verification_status") or row.get("status")
        if vstat != "VERIFIED":
            continue
        board = row.get("board")
        clabel = row.get("class_label")
        lic = row.get("license_status", "")
        if not _trusted_license(lic):
            continue
        if not board or not clabel:
            continue
        cat = row.get("resource_category", "textbook")
        rtype = rtype_map.get(cat, "CORE_TEXTBOOK")
        subj = row.get("subject") or row.get("official_subject") or "General"
        title = row.get("title") or row.get("expected_filename", "")
        sid = _slot_id(board, clabel, subj, title, rtype)
        if sid in have:
            continue
        tier = tier_map.get(lic, "A1_OFFICIAL_DIRECT")
        if "DIKSHA" in lic:
            tier = "A2_OFFICIAL_GOVERNMENT_MIRROR"
        matrix.setdefault("slots", []).append({
            "slot_id": sid,
            "board": board,
            "class_label": clabel,
            "official_subject": subj,
            "book_title": title[:120],
            "resource_type": rtype,
            "provenance_tier": tier,
            "trusted_ocr_corpus": True,
            "license_status": lic,
            "gap_fill": True,
        })
        have.add(sid)
        added += 1

    matrix["slot_count"] = len(matrix["slots"])
    matrix["gap_fill_extended_at"] = utcnow()
    write_json(matrix_path, matrix)
    return added


def run(ws: Workspace, *, board: str, dry_run: bool, limit: int | None) -> dict:
    log(f"MATRIX GAP FILL start board={board} dry_run={dry_run}")
    gaps_before = _load_gaps(ws)
    targets = _gap_targets(gaps_before, BOARD_KEYS.get(board))
    log(f"gap cells targeted: {len(targets)}")

    disc = discover_phase(ws, targets)
    log(f"discovery: {disc}")

    acq = acquire_phase(ws, dry_run=dry_run, limit=limit)
    log(f"acquisition: {acq}")

    if not dry_run:
        extended = _extend_matrix(ws)
        log(f"matrix slots extended: {extended}")
        build_provenance.main()
        provenance_reconciliation.reconcile(ws)

    import subject_coverage_audit  # noqa: E402
    audit_after = subject_coverage_audit.audit(ws)
    write_json(AUDIT_JSON, audit_after)
    audit_md = ws.p("reports_dir") / "SUBJECT_COVERAGE_AUDIT.md"
    sc = audit_after["status_counts"]
    audit_md.write_text(
        f"# Subject Coverage Audit\n\nGenerated: {audit_after['generated_at']}\n\n"
        f"COMPLETE={sc['COMPLETE']} PARTIAL={sc['PARTIAL']} "
        f"MISSING={sc['MISSING']} OOS={sc['OUT_OF_SCOPE_WITH_REASON']}\n",
        encoding="utf-8",
    )

    trusted_slots = sum(
        1 for s in load_json(ws.p("reports_dir") / "CANONICAL_CURRICULUM_MATRIX.json", {}).get("slots", [])
        if s.get("trusted_ocr_corpus")
    )

    report = {
        "generated_at": utcnow(),
        "wave": "MATRIX_GAP_FILL",
        "board_filter": board,
        "dry_run": dry_run,
        "gaps_before": len(gaps_before),
        "discovery_stats": disc,
        "acquisition_stats": acq,
        "status_counts_after": audit_after["status_counts"],
        "trusted_extraction_ready_slots": trusted_slots,
        "kie_all_ready": audit_after["kie_all_ready"],
        "remaining_not_qp_ready": audit_after["not_ready_for_question_generation"],
        "remaining_partial_missing": audit_after["partial_missing"],
    }
    write_json(GAP_REPORT, report)
    log(f"AFTER: {audit_after['status_counts']} trusted_slots={trusted_slots} KIE={audit_after['kie_all_ready']}")
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--board", default="all", choices=list(BOARD_KEYS))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    run(ws, board=args.board, dry_run=args.dry_run, limit=args.limit)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
