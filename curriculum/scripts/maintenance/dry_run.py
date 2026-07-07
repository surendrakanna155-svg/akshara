#!/usr/bin/env python3
"""End-to-end SYNTHETIC dry-run of the acquisition pipeline (CI-A0 acceptance).

Pushes ONE self-made, tiny, structurally-valid PDF fixture through the full wiring

    discover(queue) → download(file:) → verify(V1-V11) → organize → metadata → index
                    → reports → structure-validate → audit → certify

against an ISOLATED temporary workspace (configs are copied from the real
workspace; the real committed repository is never touched). This proves the
pipeline is wired without acquiring any copyrighted content (Risk R1) and without
polluting the committed indexes/reports with a fake resource.

The fixture covers exactly ONE Priority-A cell, so overall coverage stays ~0% and
the D-5 certifier MUST report NOT CERTIFIED — a single dry-run file can never
certify the repository. That assertion is the point of the exercise.

Usage:
  dry_run.py [--keep]     run the cycle; --keep leaves the temp workspace for inspection
"""

from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parents[1]
for _sub in ("common", "utilities", "discovery", "download",
             "organization", "metadata", "reports", "maintenance", "verification"):
    sys.path.insert(0, str(_SCRIPTS / _sub))

from workspace import Workspace, load_json, write_json, make_sample_pdf, utcnow  # noqa: E402
import scaffold_workspace  # noqa: E402
import pm_bootstrap  # noqa: E402
import pm_sync  # noqa: E402
import build_catalogue  # noqa: E402
import downloader  # noqa: E402
import organize  # noqa: E402
import metadata_tools  # noqa: E402
import generate_reports  # noqa: E402
import validate_structure  # noqa: E402
import repository_audit  # noqa: E402

REAL_ROOT = Path(__file__).resolve().parents[2]


def _prepare(tmp: Path) -> Workspace:
    """Materialize an isolated, fully-scaffolded + bootstrapped empty workspace.

    configs/ + scripts/ are copied so the temp is a faithful full workspace the
    structure validator can assert against; the copied scripts are inert (the
    dry-run imports the real modules via sys.path).
    """
    shutil.copytree(REAL_ROOT / "configs", tmp / "configs")
    shutil.copytree(REAL_ROOT / "scripts", tmp / "scripts",
                    ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    scaffold_workspace.build(tmp)
    ws = Workspace(tmp)
    pm_bootstrap.bootstrap(ws)
    metadata_tools.rebuild_indexes(ws)   # seeds 8 index files (empty)
    generate_reports.generate_all(ws)    # seeds 7 logs + 12 reports (empty-state)
    return ws


def run(tmp: Path) -> dict:
    ws = _prepare(tmp)

    # ---- discovery: one real Priority-A CBSE cell straight from the catalogue ----
    entry = build_catalogue.build(ws, "cbse", "A")[0]
    fixture = ws.p("temp_dir") / "fixture_source.pdf"
    fixture.parent.mkdir(parents=True, exist_ok=True)
    fixture.write_bytes(make_sample_pdf(pages=3))          # tiny, valid, self-made
    entry["source_url"] = "file://" + str(fixture.resolve())
    entry["status"] = "PENDING"
    write_json(ws.pm("download_queue"), [entry])

    # ---- download(file:) → verify(V1-V11) → organize(move) → metadata → index ----
    stats = downloader.run(tmp, allow_network=False)       # file: scheme only

    # ---- refresh derived indexes + validate + reports + PM sync ----
    index_counts = metadata_tools.rebuild_indexes(ws)
    organize_problems = organize.validate(ws)
    data = generate_reports.generate_all(ws)
    pm_sync.sync(ws)
    structure_problems = validate_structure.validate(ws)

    # ---- final structural audit + D-5 certification (must NOT certify) ----
    audit_rc = repository_audit.audit(tmp)
    certify_rc = repository_audit.certify(tmp)
    status = load_json(ws.pm("project_status"), {}) or {}

    master = load_json(ws.index("master"), {}) or {}
    rid = entry["resource_id"]
    m = master.get(rid, {})
    overall = data["overall"]

    artifacts = []
    if m.get("repository_path"):
        artifacts.append(m["repository_path"])
    if m.get("metadata_path"):
        artifacts.append(m["metadata_path"])
    artifacts += [f"indexes/{ws.paths['index_files'][k]}" for k in ("master", "download", "checksum",
                                                                     "board", "class", "subject",
                                                                     "resource", "metadata", "search")]

    return {
        "workspace": str(tmp),
        "download_stats": stats,
        "resource_id": rid,
        "expected_filename": entry["expected_filename"],
        "verified": stats.get("verified", 0),
        "repository_file": m.get("repository_path"),
        "metadata_file": m.get("metadata_path"),
        "checksum": m.get("checksum_sha256"),
        "master_entries": len(master),
        "index_counts": index_counts,
        "coverage_pct": round(overall["coverage_completeness"] * 100, 4),
        "expected_cells": overall["expected_cells"],
        "covered_cells": overall["covered_cells"],
        "organize_ok": not organize_problems,
        "structure_ok": not structure_problems,
        "structure_problems": structure_problems,
        "audit_passed": audit_rc == 0,
        "certified": bool(status.get("repository_certified")),
        "certify_rc": certify_rc,
        "certification_reasons": status.get("certification", {}).get("reasons", []),
        "artifacts": artifacts,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--keep", action="store_true", help="leave the temp workspace on disk")
    args = ap.parse_args()
    tmp = Path(tempfile.mkdtemp(prefix="ci_dry_run_"))
    try:
        res = run(tmp)
    finally:
        if not args.keep:
            shutil.rmtree(tmp, ignore_errors=True)

    print(f"\n=== DRY-RUN CYCLE @ {utcnow()} ===")
    print(f"workspace           : {res['workspace']}{'  (kept)' if args.keep else '  (cleaned)'}")
    print(f"fixture             : synthetic {res['expected_filename']}")
    print(f"download stats      : {res['download_stats']}")
    print(f"verified resource   : {res['resource_id']}")
    print(f"  → repository file : {res['repository_file']}")
    print(f"  → metadata file   : {res['metadata_file']}")
    print(f"  → sha256          : {res['checksum']}")
    print(f"master index entries: {res['master_entries']}")
    print(f"secondary indexes   : {res['index_counts']}")
    print(f"organize validate   : {'PASS' if res['organize_ok'] else 'FAIL'}")
    print(f"structure validate  : {'PASS' if res['structure_ok'] else 'FAIL ' + str(res['structure_problems'])}")
    print(f"coverage            : {res['coverage_pct']}%  ({res['covered_cells']}/{res['expected_cells']} cells)")
    print(f"structural audit    : {'PASS' if res['audit_passed'] else 'FAIL'}")
    print(f"D-5 certification    : {'CERTIFIED' if res['certified'] else 'NOT CERTIFIED (expected)'}")
    for r in res["certification_reasons"][:6]:
        print(f"    blocked: {r}")

    # the dry-run is a success when the pipeline ran AND the repo did NOT certify
    ok = (res["verified"] == 1 and res["audit_passed"]
          and res["structure_ok"] and not res["certified"])
    print(f"\nDRY-RUN {'OK — pipeline wired, repository correctly NOT certified' if ok else 'FAILED'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
