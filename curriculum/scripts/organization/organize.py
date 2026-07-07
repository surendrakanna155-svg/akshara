#!/usr/bin/env python3
"""Repository organization + directory validation (spec Part 04).

The verification engine already MOVES each verified file into resources/ (V11);
this module owns the surrounding organization duties:
  - `ensure_destinations`: pre-create the resources/ folders a queue targets.
  - `validate`: the Part-04 DIRECTORY VALIDATION checks (missing required
    folders, files outside the standard tree, invalid filenames, spaces).

Config-driven off folder_rules.json / paths.json / verification_rules.json.
Stdlib-only. Returns a machine-readable problem list; exit 1 on any violation.

Usage:
  organize.py --validate            run directory validation
  organize.py --ensure-destinations create resources/ folders for the queue
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]


def ensure_destinations(ws: Workspace) -> int:
    queue = load_json(ws.pm("download_queue"), []) or []
    n = 0
    for entry in queue:
        dest = entry.get("destination")
        if dest:
            (ws.p("resources_dir") / dest).mkdir(parents=True, exist_ok=True)
            n += 1
    return n


def validate(ws: Workspace) -> list[str]:
    fr = ws.config("folder_rules")
    rules = fr["directory_validation"]
    problems: list[str] = []

    # missing required top-level folders
    if rules.get("check_missing_required_folders", True):
        for d in fr["top_level_dirs"]:
            if not (ws.root / d).is_dir():
                problems.append(f"MISSING_REQUIRED_FOLDER: {d}")

    # filename hygiene inside resources/
    pattern = re.compile(ws.config("verification_rules")["filename_pattern"])
    resources = ws.p("resources_dir")
    master = load_json(ws.index("master"), {}) or {}
    indexed_paths = {str((ws.root / e["repository_path"]).resolve())
                     for e in master.values()
                     if e.get("verification_status") == "VERIFIED" and e.get("repository_path")}
    if resources.exists():
        for f in resources.rglob("*"):
            if not f.is_file() or f.name == ".gitkeep":
                continue
            if rules.get("check_spaces_in_filenames", True) and " " in f.name:
                problems.append(f"SPACE_IN_FILENAME: {f.relative_to(ws.root)}")
            if rules.get("check_invalid_filenames", True) and not pattern.match(f.name):
                problems.append(f"INVALID_FILENAME: {f.relative_to(ws.root)}")
            if rules.get("check_files_outside_standard_tree", True):
                # every real resource file must be tracked by the master index
                if str(f.resolve()) not in indexed_paths:
                    problems.append(f"FILE_OUTSIDE_INDEX: {f.relative_to(ws.root)}")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--validate", action="store_true")
    ap.add_argument("--ensure-destinations", action="store_true")
    args = ap.parse_args()
    ws = Workspace(args.workspace)

    if args.ensure_destinations:
        n = ensure_destinations(ws)
        print(f"ensure-destinations: created/verified {n} folders")

    if args.validate or not args.ensure_destinations:
        problems = validate(ws)
        ws.log("processing", f"directory validation: {len(problems)} problem(s)")
        if problems:
            print(f"directory validation FAILED — {len(problems)} problem(s):")
            for p in problems[:50]:
                print(f"  {p}")
            return 1
        print("directory validation PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
