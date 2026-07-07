#!/usr/bin/env python3
"""Metadata validation + secondary-index rebuild (spec Part 08).

The verification engine (V9/V10) already writes one metadata record per resource
and the master/download/checksum indexes. This module adds the Part-08 duties:
  - `validate`: metadata↔file bijection, required-field completeness, one
    master-index entry per resource, checksum present (AT-D3/AT-D4).
  - `rebuild_indexes`: derive the secondary indexes (board/class/subject/
    document_type/search) from the master index, always kept in sync.

Config-driven off metadata_schema.json / paths.json. Stdlib-only.

Usage:
  metadata_tools.py --validate
  metadata_tools.py --rebuild-indexes
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]


def validate(ws: Workspace) -> list[str]:
    required = ws.config("metadata_schema")["required"]
    master = load_json(ws.index("master"), {}) or {}
    meta_dir = ws.p("metadata_resources_dir")
    problems: list[str] = []

    seen_meta_files = set()
    for rid, e in master.items():
        if e.get("verification_status") != "VERIFIED":
            continue
        fname = Path(e.get("repository_path", "")).name
        mpath = meta_dir / f"{fname}.metadata.json"
        if not mpath.is_file():
            problems.append(f"MISSING_METADATA: {rid} → {mpath.name}")
            continue
        seen_meta_files.add(mpath.name)
        meta = load_json(mpath, {}) or {}
        missing = [f for f in required if not meta.get(f)]
        if missing:
            problems.append(f"INCOMPLETE_METADATA: {rid} missing {missing}")
        if not e.get("checksum_sha256"):
            problems.append(f"MISSING_CHECKSUM: {rid}")

    # reverse bijection: metadata files with no live VERIFIED master entry = orphans
    verified_files = {Path(e.get("repository_path", "")).name
                      for e in master.values() if e.get("verification_status") == "VERIFIED"}
    if meta_dir.exists():
        for mf in meta_dir.glob("*.metadata.json"):
            base = mf.name[: -len(".metadata.json")]
            if base not in verified_files:
                problems.append(f"ORPHAN_METADATA: {mf.name} (no VERIFIED resource)")
    return problems


def seed_indexes(ws: Workspace) -> list[str]:
    """Ensure the engine-owned mutable indexes exist as valid empty JSON.

    master/download/checksum/duplicates are written by the verification engine at
    runtime; seed them empty so the Part-04 'no resource outside the indexes' shape
    holds on a fresh (empty) repository. Never clobbers a populated index.
    """
    seeded: list[str] = []
    for key in ("master", "download", "checksum", "duplicates"):
        if not ws.index(key).exists():
            write_json(ws.index(key), {})
            seeded.append(ws.index(key).name)
    return seeded


def rebuild_indexes(ws: Workspace) -> dict:
    seed_indexes(ws)
    master = load_json(ws.index("master"), {}) or {}
    board_idx: dict[str, list] = {}
    class_idx: dict[str, list] = {}
    subject_idx: dict[str, list] = {}
    doctype_idx: dict[str, list] = {}
    search_idx: list[dict] = []
    resource_idx: dict[str, dict] = {}
    metadata_idx: dict[str, str] = {}

    for rid, e in master.items():
        board_idx.setdefault(e.get("board", "?"), []).append(rid)
        class_idx.setdefault(e.get("class_label", "?"), []).append(rid)
        subject_idx.setdefault(e.get("subject", "?"), []).append(rid)
        doctype_idx.setdefault(e.get("document_type", "?"), []).append(rid)
        search_idx.append({
            "resource_id": rid,
            "title": e.get("title"),
            "board": e.get("board"),
            "class_label": e.get("class_label"),
            "subject": e.get("subject"),
            "document_type": e.get("document_type"),
            "keywords": [str(e.get(k, "")) for k in ("board", "class_label", "subject", "document_type")],
        })
        resource_idx[rid] = {
            "board": e.get("board"),
            "class_label": e.get("class_label"),
            "subject": e.get("subject"),
            "document_type": e.get("document_type"),
            "repository_path": e.get("repository_path"),
            "checksum_sha256": e.get("checksum_sha256"),
            "verification_status": e.get("verification_status"),
        }
        if e.get("metadata_path"):
            metadata_idx[rid] = e.get("metadata_path")

    write_json(ws.index("board"), {"generated_at": utcnow(), "index": board_idx})
    write_json(ws.index("class"), {"generated_at": utcnow(), "index": class_idx})
    write_json(ws.index("subject"), {"generated_at": utcnow(), "index": subject_idx})
    write_json(ws.index("document_type"), {"generated_at": utcnow(), "index": doctype_idx})
    write_json(ws.index("search"), {"generated_at": utcnow(), "entries": search_idx})
    write_json(ws.index("resource"), {"generated_at": utcnow(), "index": resource_idx})
    write_json(ws.index("metadata"), {"generated_at": utcnow(), "index": metadata_idx})
    return {"boards": len(board_idx), "classes": len(class_idx), "subjects": len(subject_idx),
            "document_types": len(doctype_idx), "resources": len(search_idx)}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--validate", action="store_true")
    ap.add_argument("--rebuild-indexes", action="store_true")
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    rc = 0

    if args.rebuild_indexes or not args.validate:
        counts = rebuild_indexes(ws)
        print(f"rebuild-indexes: {counts}")

    if args.validate or not args.rebuild_indexes:
        problems = validate(ws)
        ws.log("metadata", f"metadata validation: {len(problems)} problem(s)")
        if problems:
            print(f"metadata validation FAILED — {len(problems)} problem(s):")
            for p in problems[:50]:
                print(f"  {p}")
            rc = 1
        else:
            print("metadata validation PASSED")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
