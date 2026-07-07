#!/usr/bin/env python3
"""Discovery catalogue builder (spec Parts 05/06 — Resource Discovery).

Deterministically enumerates the expected resource cells for a board from the
config matrix (boards × classes × subjects × priority categories) and emits a
machine-readable catalogue the downloader consumes:

  discovery/<board>/catalogue.json  — one record per expected resource cell
  discovery/<board>/sources.json    — the official source ladder for the board

CATALOGUE ONLY — no download, no network. Each cell starts DISCOVERED /
PENDING_DISCOVERY with source_url=null (a networked discovery run resolves the
direct URL per cell; until then the downloader records it as needing network).
`--priority A` limits to the CI-A1 Priority-A set (default). `--to-queue` merges
the catalogue into DOWNLOAD_QUEUE.json (idempotent by resource_id).

Usage:
  build_catalogue.py --board cbse [--priority A|AB|ALL] [--to-queue]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]


def _canonical_document_types(download_rules: dict) -> dict[str, str]:
    """Inverse of document_type_to_category: first document_type seen per category."""
    inv: dict[str, str] = {}
    for doc_type, cat in download_rules["document_type_to_category"].items():
        inv.setdefault(cat, doc_type)
    return inv


def build(ws: Workspace, board_key: str, priority: str) -> list[dict]:
    boards = ws.config("boards")["boards"]
    if board_key not in boards:
        raise KeyError(f"unknown board '{board_key}' (known: {list(boards)})")
    board = boards[board_key]
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    fr = ws.config("folder_rules")
    dr = ws.config("download_rules")
    qr = ws.config("quality_rules")

    wanted_priorities = {"A": ["A"], "AB": ["A", "B"], "ALL": ["A", "B", "C"]}[priority]
    cat_priority = {}
    for prio, cats in qr["priority_categories"].items():
        for c in cats:
            cat_priority[c] = prio
    canonical_dt = _canonical_document_types(dr)
    cat_folder = dr["category_to_subject_folder"]
    year = str(__import__("datetime").datetime.now().year)

    catalogue: list[dict] = []
    seq = 0
    for ckey in ws.config("classes")["class_order"]:
        if ckey not in board["subjects_by_class"]:
            continue
        clabel = classes[ckey]["class_label"]
        ccode = classes[ckey]["code"]
        for skey in board["subjects_by_class"][ckey]:
            subj = subjects[skey]
            for prio in wanted_priorities:
                for category in qr["priority_categories"][prio]:
                    seq += 1
                    doc_type = canonical_dt.get(category, "Other")
                    resource_type = doc_type.replace(" ", "")
                    rid = ws.resource_id(board["code"], ccode, subj["code"], category, year, seq)
                    fname = ws.repo_filename(board["code"], clabel, subj["subject_folder"],
                                             resource_type, year, "v1", "English", "pdf")
                    dest = f"curriculum/{board['board_folder']}/{clabel}/{subj['subject_folder']}/{cat_folder.get(category, 'Reference')}"
                    catalogue.append({
                        "resource_id": rid,
                        "expected_filename": fname,
                        "title": f"{board['code']} {clabel} {subj['display']} — {doc_type}",
                        "document_type": doc_type,
                        "resource_category": category,
                        "board": board["code"],
                        "class_label": clabel,
                        "subject": subj["display"],
                        "priority": prio,
                        "source_portal": board["official_sources"][0],
                        "source_url": None,
                        "license_status": "PENDING_VERIFICATION",
                        "destination": dest,
                        "alternative_sources": [],
                        "search_locations": list(board["official_sources"]),
                        "discovery_status": "PENDING_DISCOVERY",
                        "status": "PENDING",
                        "retry_count": 0,
                        "cataloged_at": utcnow(),
                    })
    return catalogue


def to_queue(ws: Workspace, catalogue: list[dict]) -> int:
    queue = load_json(ws.pm("download_queue"), []) or []
    have = {e.get("resource_id") for e in queue}
    added = 0
    for entry in catalogue:
        if entry["resource_id"] not in have:
            queue.append(entry)
            added += 1
    write_json(ws.pm("download_queue"), queue)
    return added


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--board", default="cbse")
    ap.add_argument("--priority", default="A", choices=["A", "AB", "ALL"])
    ap.add_argument("--to-queue", action="store_true")
    args = ap.parse_args()
    ws = Workspace(args.workspace)

    catalogue = build(ws, args.board, args.priority)
    board = ws.config("boards")["boards"][args.board]
    disc_dir = ws.p("discovery_dir") / board["board_folder"]
    disc_dir.mkdir(parents=True, exist_ok=True)
    write_json(disc_dir / "catalogue.json", catalogue)
    write_json(disc_dir / "sources.json", {
        "board": board["code"],
        "content_authority": board.get("content_authority"),
        "official_sources": board["official_sources"],
        "source_priority_ladder": ws.config("download_rules")["source_priority_ladder"],
        "generated_at": utcnow(),
    })
    ws.log("processing", f"discovery catalogue for {board['code']}: {len(catalogue)} cells (priority {args.priority})")
    print(f"catalogue: {len(catalogue)} cells → {disc_dir / 'catalogue.json'}")

    if args.to_queue:
        added = to_queue(ws, catalogue)
        print(f"queue: merged {added} new entries into {ws.pm('download_queue')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
