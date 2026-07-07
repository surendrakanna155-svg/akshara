#!/usr/bin/env python3
"""Scaffold the Part-04 repository directory standard (config-driven).

Reads configs/folder_rules.json + paths.json and materializes the top-level
tree, the metadata/indexes/downloads/cache/archives/logs subdirs, and drops a
`.gitkeep` in every directory that must exist on disk. Binary/content trees
(resources, downloads, cache, temp, archives, logs) are gitignored (R10 guard),
so their `.gitkeep` is for local reproducibility only; committed trees
(indexes, metadata summaries, discovery) get a tracked `.gitkeep`.

Idempotent — safe to re-run. `--full-resources` additionally materializes the
whole curriculum board×class×subject×category tree (all gitignored) for a real
acquisition run; omit it for the committed shape.

Usage:
  scaffold_workspace.py [--workspace DIR] [--full-resources]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]


def _keep(dir_path: Path) -> None:
    dir_path.mkdir(parents=True, exist_ok=True)
    gk = dir_path / ".gitkeep"
    if not gk.exists():
        gk.write_text("", encoding="utf-8")


def build(root: Path, full_resources: bool = False) -> list[str]:
    ws = Workspace(root)
    fr = ws.config("folder_rules")
    created: list[str] = []

    def ensure(rel: str, keep: bool = True) -> None:
        d = root / rel
        d.mkdir(parents=True, exist_ok=True)
        if keep:
            _keep(d)
        created.append(rel)

    # top-level dirs
    for d in fr["top_level_dirs"]:
        ensure(d, keep=False)

    # committed-but-may-be-empty trees → tracked .gitkeep
    ensure("indexes")
    for sub in fr["metadata_subdirs"]:
        ensure(f"metadata/{sub}")
    ensure("discovery", keep=False)

    # runtime/binary trees → local .gitkeep (gitignored)
    for rel in fr["gitkept_dirs"]:
        ensure(rel)

    for sub in fr["cache_subdirs"]:
        ensure(f"cache/{sub}")
    for sub in fr["archives_subdirs"]:
        ensure(f"archives/{sub}")

    # full curriculum tree (all gitignored) — only on demand
    if full_resources:
        boards = ws.config("boards")["boards"]
        subjects = ws.config("subjects")["subjects"]
        classes = ws.config("classes")["classes"]
        cats = fr["resources_subtree"]["subject_category_folders"]
        for _bkey, b in boards.items():
            bslug = b["board_folder"]
            for ckey, subj_list in b["subjects_by_class"].items():
                clabel = classes[ckey]["class_label"]
                for skey in subj_list:
                    sfolder = subjects[skey]["subject_folder"]
                    for cat in cats:
                        ensure(f"resources/curriculum/{bslug}/{clabel}/{sfolder}/{cat}", keep=False)
        for f in fr["resources_subtree"]["foundation_folders"]:
            ensure(f"resources/foundation/{f}", keep=False)

    return created


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--full-resources", action="store_true",
                    help="also materialize the full curriculum tree (gitignored)")
    args = ap.parse_args()
    created = build(args.workspace, full_resources=args.full_resources)
    print(f"scaffold: ensured {len(created)} directories under {args.workspace}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
