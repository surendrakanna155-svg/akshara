#!/usr/bin/env python3
"""Directory-standard + storage-invariant validator (spec Part 04 ~1663-1703).

Asserts the Part-04 repository standard as data (configs/folder_rules.json:
directory_standard) and exits NON-ZERO on any violation, so it can gate a commit
or a pipeline step. Checks, in order:

  1. the 11 required top-level dirs exist (+ `discovery` is an allowed extra);
     any other top-level dir is flagged UNEXPECTED_TOP_LEVEL_DIR
  2. every required subdir of metadata/downloads/cache/archives/scripts exists
  3. every required index file exists and parses as JSON (8 spec indexes)
  4. every required report exists (12 Part-04 reports)
  5. every required log file exists (7 Part-04 logs)
  6. every required PM file exists (8 Part-02 files)
  7. filename hygiene + no files outside the index (delegated to organize.validate)
  8. the 7 STORAGE INVARIANTS hold for every VERIFIED resource:
     one file · one metadata record · one unique id · one source record ·
     one checksum · one index entry · one repository location

Config-driven, stdlib-only, additive (never mutates the repository).

Usage:
  validate_structure.py [--workspace DIR]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_COMMON = Path(__file__).resolve().parents[1] / "common"
_ORG = Path(__file__).resolve().parents[1] / "organization"
sys.path.insert(0, str(_COMMON))
sys.path.insert(0, str(_ORG))
from workspace import Workspace, load_json  # noqa: E402
import organize  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]


def _invariants(ws: Workspace) -> list[str]:
    """The Part-04 storage invariants over every VERIFIED master-index entry."""
    problems: list[str] = []
    master = load_json(ws.index("master"), {}) or {}
    download_idx = load_json(ws.index("download"), {}) or {}
    checksum_idx = load_json(ws.index("checksum"), {}) or {}
    search = (load_json(ws.index("search"), {}) or {}).get("entries", [])
    search_ids = {e.get("resource_id") for e in search}

    for rid, e in master.items():
        if e.get("verification_status") != "VERIFIED":
            continue
        # one file + one repository location
        if not (ws.root / e.get("repository_path", "")).is_file():
            problems.append(f"INVARIANT_ONE_FILE: {rid} — repository file missing")
        # one metadata record
        if not (ws.root / e.get("metadata_path", "")).is_file():
            problems.append(f"INVARIANT_ONE_METADATA: {rid} — metadata file missing")
        # one checksum (present + registered in the checksum index)
        chk = e.get("checksum_sha256")
        if not chk:
            problems.append(f"INVARIANT_ONE_CHECKSUM: {rid} — no checksum recorded")
        elif chk not in checksum_idx:
            problems.append(f"INVARIANT_ONE_CHECKSUM: {rid} — checksum absent from checksum index")
        # one source record
        if rid not in download_idx:
            problems.append(f"INVARIANT_ONE_SOURCE: {rid} — no download/source-index record")
        # one index entry (search/resource)
        if rid not in search_ids:
            problems.append(f"INVARIANT_ONE_INDEX_ENTRY: {rid} — missing from search index")
    return problems


def validate(ws: Workspace) -> list[str]:
    ds = ws.config("folder_rules")["directory_standard"]
    root = ws.root
    problems: list[str] = []

    # 1 — required top-level dirs + unexpected-folder detection
    for d in ds["required_top_level_dirs"]:
        if not (root / d).is_dir():
            problems.append(f"MISSING_TOP_LEVEL_DIR: {d}")
    allowed = set(ds["required_top_level_dirs"]) | set(ds.get("allowed_additional_top_level_dirs", []))
    for child in sorted(root.iterdir()):
        if child.is_dir() and not child.name.startswith(".") and child.name not in allowed:
            problems.append(f"UNEXPECTED_TOP_LEVEL_DIR: {child.name}")

    # 2 — required subdirs
    for parent, subs in ds["required_subdirs"].items():
        for s in subs:
            if not (root / parent / s).is_dir():
                problems.append(f"MISSING_SUBDIR: {parent}/{s}")

    # 3 — required index files exist + parse
    for key in ds["required_index_keys"]:
        p = ws.index(key)
        if not p.is_file():
            problems.append(f"MISSING_INDEX: {p.name}")
            continue
        try:
            json.loads(p.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            problems.append(f"INVALID_INDEX_JSON: {p.name}: {exc}")

    # 4 — required reports
    for key in ds["required_report_keys"]:
        if not ws.report(key).is_file():
            problems.append(f"MISSING_REPORT: {ws.report(key).name}")

    # 5 — required logs
    for key in ds["required_log_keys"]:
        if not ws.log_path(key).is_file():
            problems.append(f"MISSING_LOG: {ws.log_path(key).name}")

    # 6 — required PM files
    for key in ds["required_pm_keys"]:
        if not ws.pm(key).is_file():
            problems.append(f"MISSING_PM_FILE: {ws.pm(key).name}")

    # 7 — filename hygiene + files-outside-index (reuse the organize validator)
    problems.extend(organize.validate(ws))

    # 8 — storage invariants
    problems.extend(_invariants(ws))
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    problems = validate(ws)
    ws.log("processing", f"structure validation: {len(problems)} problem(s)")
    if problems:
        print(f"structure validation FAILED — {len(problems)} problem(s):")
        for p in problems[:80]:
            print(f"  {p}")
        return 1
    print("structure validation PASSED — Part-04 directory standard + storage invariants OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
