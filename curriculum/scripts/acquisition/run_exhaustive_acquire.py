#!/usr/bin/env python3
"""Exhaustive legal/public acquisition wave — discover → immediate download → verify.

Runs all official discovery lanes, downloads each new probed source immediately,
extends matrix, rebuilds provenance, and regenerates honest coverage reports.

Does NOT weaken audit policy to fake COMPLETE status.

Usage:
  run_exhaustive_acquire.py [--board all|cbse|ap|telangana|icse] [--skip-diksha] [--limit N]
"""
from __future__ import annotations

import argparse
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
import immediate_acquire  # noqa: E402
import run_matrix_gap_fill as mgf  # noqa: E402

LOG = WORKSPACE_ROOT / "acquisition" / "exhaustive_acquire.log"
BOARD_SET = {
    "all": {"CBSE", "APSCERT", "TSSCERT", "CISCE"},
    "cbse": {"CBSE"},
    "ap": {"APSCERT"},
    "telangana": {"TSSCERT"},
    "icse": {"CISCE"},
}


def log(msg: str) -> None:
    line = f"[{utcnow()}] {msg}"
    print(line, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def discover_exhaustive(
    ws: Workspace,
    boards: set[str],
    *,
    skip_diksha: bool,
    no_probe: bool,
    assessment_only: bool,
) -> list[dict]:
    import ncert_catalogue  # noqa: E402
    import cbse_catalogue  # noqa: E402
    import cbse_sqp_catalogue  # noqa: E402
    import ap_catalogue  # noqa: E402
    import telangana_catalogue  # noqa: E402
    import cisce_catalogue  # noqa: E402
    import cisce_discover  # noqa: E402
    import diksha_catalogue  # noqa: E402
    import scert_portal_discover  # noqa: E402
    import fetch_papers_direct as fpd  # noqa: E402

    entries: list[dict] = []
    seen: set[str] = set()
    stats: dict[str, int] = {}

    ASSESSMENT_CATS = {"sample_paper", "blueprint", "question_bank", "previous_paper"}

    def add_batch(name: str, batch: list[dict], *, trusted_only: bool = False) -> None:
        n = 0
        for e in batch:
            if e.get("board") not in boards:
                continue
            if trusted_only and (e.get("license_status") or "").startswith("UNOFFICIAL"):
                continue
            cat = e.get("resource_category", "textbook")
            if assessment_only and cat not in ASSESSMENT_CATS:
                continue
            url = e.get("source_url")
            if not url or url in seen:
                continue
            seen.add(url)
            entries.append(e)
            n += 1
        stats[name] = n
        log(f"discovery done: {name} -> {n} urls (running total {len(entries)})")

    if "CBSE" in boards:
        if not assessment_only:
            log("discovery: ncert+cbse_meta...")
            add_batch("ncert", ncert_catalogue.build(ws))
            add_batch("cbse_meta", cbse_catalogue.build(ws))
        log("discovery: cbse_sqp+cbse_papers...")
        add_batch("cbse_sqp", cbse_sqp_catalogue.build(ws, probe=not no_probe))
        add_batch("cbse_papers", fpd.discover_cbse(ws))

    if "APSCERT" in boards and not assessment_only:
        log("discovery: ap_portal...")
        add_batch("ap_portal", ap_catalogue.build(ws, probe=not no_probe))

    if "TSSCERT" in boards:
        if not assessment_only:
            log("discovery: ts_catalogue...")
            add_batch("ts_catalogue", telangana_catalogue.build(ws), trusted_only=True)
        log("discovery: ts_scert portal...")
        add_batch("ts_scert", scert_portal_discover.discover(ws, "telangana"))

    if "CISCE" in boards:
        if not assessment_only:
            log("discovery: cisce_cat...")
            add_batch("cisce_cat", cisce_catalogue.build(ws))
        log("discovery: cisce_crawl (cisce.org)...")
        add_batch("cisce_crawl", cisce_discover.discover(ws))
        add_batch("cisce_papers", fpd.discover_cisce(ws))

    if not skip_diksha:
        log("discovery: diksha (probe=%s)..." % (not no_probe))
        add_batch("diksha", diksha_catalogue.build(ws, probe=not no_probe))

    log(f"discovery lanes: {stats} total_unique={len(entries)}")
    return entries


def _stream_lanes(
    ws: Workspace,
    boards: set[str],
    engine,
    *,
    skip_diksha: bool,
    no_probe: bool,
    assessment_only: bool,
    limit: int | None,
) -> tuple[Counter, int]:
    """Discover lane-by-lane and download each URL immediately (no batch wait)."""
    import ncert_catalogue  # noqa: E402
    import cbse_catalogue  # noqa: E402
    import cbse_sqp_catalogue  # noqa: E402
    import ap_catalogue  # noqa: E402
    import telangana_catalogue  # noqa: E402
    import cisce_catalogue  # noqa: E402
    import cisce_discover  # noqa: E402
    import diksha_catalogue  # noqa: E402
    import scert_portal_discover  # noqa: E402
    import fetch_papers_direct as fpd  # noqa: E402

    ASSESSMENT_CATS = {"sample_paper", "blueprint", "question_bank", "previous_paper"}
    seen: set[str] = set()
    stats: Counter = Counter()
    processed = 0

    def acquire_batch(name: str, batch: list[dict], *, trusted_only: bool = False) -> None:
        nonlocal processed
        added = 0
        for e in batch:
            if limit is not None and processed >= limit:
                return
            if e.get("board") not in boards:
                continue
            if trusted_only and (e.get("license_status") or "").startswith("UNOFFICIAL"):
                continue
            cat = e.get("resource_category", "textbook")
            if assessment_only and cat not in ASSESSMENT_CATS:
                continue
            url = e.get("source_url")
            if not url or url in seen:
                continue
            seen.add(url)
            added += 1
            outcome = immediate_acquire.acquire_one(ws, e, engine, allow_network=True)
            stats[outcome] += 1
            processed += 1
            if outcome == "VERIFIED":
                log(f"OK {e['board']} {e['class_label']} {e['subject']} "
                    f"{e.get('resource_category')}/{e.get('assessment_subtype')} "
                    f"-> {e['expected_filename']}")
            elif outcome not in ("EXISTING", "DUPLICATE", "SKIP_UNOFFICIAL"):
                time.sleep(0.15)
        if added:
            log(f"lane {name}: processed {added} (total {processed}) stats={dict(stats)}")

    if "CBSE" in boards:
        if not assessment_only:
            acquire_batch("ncert", ncert_catalogue.build(ws))
            acquire_batch("cbse_meta", cbse_catalogue.build(ws))
        acquire_batch("cbse_sqp", cbse_sqp_catalogue.build(ws, probe=not no_probe))
        acquire_batch("cbse_papers", fpd.discover_cbse(ws))
    if "APSCERT" in boards and not assessment_only:
        acquire_batch("ap_portal", ap_catalogue.build(ws, probe=not no_probe))
    if "TSSCERT" in boards:
        if not assessment_only:
            acquire_batch("ts_catalogue", telangana_catalogue.build(ws), trusted_only=True)
        acquire_batch("ts_scert", scert_portal_discover.discover(ws, "telangana"))
    if "CISCE" in boards:
        if not assessment_only:
            acquire_batch("cisce_cat", cisce_catalogue.build(ws))
        acquire_batch("cisce_crawl", cisce_discover.discover(ws))
        acquire_batch("cisce_papers", fpd.discover_cisce(ws))
    if not skip_diksha:
        acquire_batch("diksha", diksha_catalogue.build(ws, probe=not no_probe))
    return stats, processed


def run(
    ws: Workspace,
    *,
    board: str,
    skip_diksha: bool,
    no_probe: bool,
    assessment_only: bool,
    stream: bool,
    limit: int | None,
) -> dict:
    boards = BOARD_SET[board]
    log(f"EXHAUSTIVE ACQUIRE start boards={boards} skip_diksha={skip_diksha} "
        f"assessment_only={assessment_only} no_probe={no_probe} stream={stream}")
    engine = get_engine(ws.root)
    if stream:
        stats, discovered = _stream_lanes(
            ws, boards, engine,
            skip_diksha=skip_diksha, no_probe=no_probe,
            assessment_only=assessment_only, limit=limit,
        )
        log(f"stream complete: {discovered} urls stats={dict(stats)}")
    else:
        entries = discover_exhaustive(
            ws, boards, skip_diksha=skip_diksha,
            no_probe=no_probe, assessment_only=assessment_only,
        )
        log(f"discovery complete: {len(entries)} unique URLs — starting downloads...")
        stats = Counter()
        for i, entry in enumerate(entries):
            if limit is not None and i >= limit:
                break
            outcome = immediate_acquire.acquire_one(ws, entry, engine, allow_network=True)
            stats[outcome] += 1
            if outcome == "VERIFIED":
                log(f"OK {entry['board']} {entry['class_label']} {entry['subject']} "
                    f"{entry.get('resource_category')}/{entry.get('assessment_subtype')} "
                    f"-> {entry['expected_filename']}")
            elif outcome not in ("EXISTING", "DUPLICATE", "SKIP_UNOFFICIAL"):
                time.sleep(0.15)
            elif (i + 1) % 50 == 0:
                log(f"download progress {i+1}/{len(entries)} stats={dict(stats)}")
        discovered = len(entries)

    extended = mgf._extend_matrix(ws)
    log(f"matrix extended: {extended}")

    import build_provenance  # noqa: E402
    import subject_coverage_audit  # noqa: E402
    import assessment_evidence_matrix  # noqa: E402
    manifest = build_provenance.build(ws)
    write_json(ws.root / "PROVENANCE_MANIFEST.json", manifest)
    cov = subject_coverage_audit.audit(ws)
    write_json(ws.p("reports_dir") / "SUBJECT_COVERAGE_AUDIT.json", cov)
    ass = assessment_evidence_matrix.build(ws)
    write_json(ws.p("reports_dir") / "ASSESSMENT_EVIDENCE_MATRIX.json", ass)

    report = {
        "generated_at": utcnow(),
        "mode": "EXHAUSTIVE_ACQUIRE",
        "boards": sorted(boards),
        "discovered": discovered,
        "stats": dict(stats),
        "matrix_extended": extended,
        "coverage": cov["status_counts"],
        "assessment_cells_with_evidence": ass["cells_with_any_evidence"],
    }
    write_json(ws.p("reports_dir") / "EXHAUSTIVE_ACQUIRE_REPORT.json", report)
    log(f"DONE stats={dict(stats)} coverage={cov['status_counts']} "
        f"assessment_evidence={ass['cells_with_any_evidence']}/{ass['cell_count']}")
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--board", default="all", choices=list(BOARD_SET))
    ap.add_argument("--skip-diksha", action="store_true")
    ap.add_argument("--no-probe", action="store_true",
                    help="skip HEAD probes during discovery; fetch directly (faster)")
    ap.add_argument("--assessment-only", action="store_true",
                    help="only sample papers, blueprints, previous papers — skip textbooks")
    ap.add_argument("--stream", action="store_true", default=True,
                    help="discover lane-by-lane and download immediately (default)")
    ap.add_argument("--batch", action="store_true",
                    help="legacy: discover all URLs first, then download")
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    run(ws, board=args.board, skip_diksha=args.skip_diksha,
        no_probe=args.no_probe, assessment_only=args.assessment_only,
        stream=not args.batch, limit=args.limit)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
