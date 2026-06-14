#!/usr/bin/env python3
"""Multi-agent coordinator — file locks, dependencies, handoff board for Cursor subagents."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = ROOT / "qa/agents/work_manifest.json"
DEFAULT_BOARD = ROOT / "qa/agents/handoff_board.json"


def _utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def init_board(run_id: str, manifest_path: Path, board_path: Path) -> None:
    manifest = load_json(manifest_path)
    tasks = manifest.get("tasks", [])
    board = {
        "run_id": run_id,
        "manifest": str(manifest_path.relative_to(ROOT)),
        "status": "running",
        "updated_at": _utc_now(),
        "tasks": {},
    }
    for task in tasks:
        tid = task["id"]
        board["tasks"][tid] = {
            "agent": task["agent"],
            "title": task["title"],
            "status": "pending",
            "depends_on": task.get("depends_on", []),
            "files": task.get("files", []),
            "handoff": None,
            "blocked_reason": None,
            "started_at": None,
            "completed_at": None,
        }
    save_json(board_path, board)
    print(f"Initialized board for run {run_id} with {len(tasks)} tasks.")


def _task_done(board: dict, task_id: str) -> bool:
    entry = board["tasks"].get(task_id)
    return entry is not None and entry["status"] == "done"


def runnable_tasks(board: dict) -> list[str]:
    runnable: list[str] = []
    for tid, entry in board["tasks"].items():
        if entry["status"] not in ("pending", "blocked"):
            continue
        deps = entry.get("depends_on") or []
        if all(_task_done(board, d) for d in deps):
            runnable.append(tid)
    return runnable


def files_in_flight(board: dict) -> set[str]:
    locked: set[str] = set()
    for entry in board["tasks"].values():
        if entry["status"] == "in_progress":
            locked.update(entry.get("files") or [])
    return locked


def validate_board(board: dict) -> list[str]:
    errors: list[str] = []
    seen: dict[str, str] = {}
    for tid, entry in board["tasks"].items():
        for f in entry.get("files") or []:
            if f in seen and entry["status"] in ("in_progress", "done"):
                other = seen[f]
                if entry["status"] == "in_progress" or board["tasks"][other]["status"] == "in_progress":
                    errors.append(f"File conflict: {f} claimed by {other} and {tid}")
            seen[f] = tid
    in_progress = [t for t, e in board["tasks"].items() if e["status"] == "in_progress"]
    locked = files_in_flight(board)
    for tid in runnable_tasks(board):
        entry = board["tasks"][tid]
        overlap = set(entry.get("files") or []) & locked
        if overlap:
            errors.append(f"{tid} runnable but files locked: {sorted(overlap)}")
    if len(in_progress) > board.get("max_parallel", 4):
        errors.append(f"Too many in_progress tasks: {len(in_progress)}")
    return errors


def claim(board_path: Path, task_id: str, agent: str) -> None:
    board = load_json(board_path)
    entry = board["tasks"].get(task_id)
    if entry is None:
        sys.exit(f"Unknown task: {task_id}")
    if entry["agent"] != agent:
        sys.exit(f"Task {task_id} owned by Agent {entry['agent']}, not {agent}")
    if task_id not in runnable_tasks(board) and entry["status"] != "in_progress":
        sys.exit(f"Task {task_id} not runnable (deps or status)")
    overlap = set(entry.get("files") or []) & files_in_flight(board)
    if overlap and entry["status"] != "in_progress":
        sys.exit(f"Cannot claim {task_id}; files locked: {sorted(overlap)}")
    entry["status"] = "in_progress"
    entry["started_at"] = entry["started_at"] or _utc_now()
    entry["blocked_reason"] = None
    board["updated_at"] = _utc_now()
    save_json(board_path, board)
    print(json.dumps({"claimed": task_id, "agent": agent, "files": entry["files"]}))


def complete(board_path: Path, task_id: str, summary: str) -> None:
    board = load_json(board_path)
    entry = board["tasks"].get(task_id)
    if entry is None:
        sys.exit(f"Unknown task: {task_id}")
    entry["status"] = "done"
    entry["handoff"] = summary
    entry["completed_at"] = _utc_now()
    board["updated_at"] = _utc_now()
    pending = [t for t, e in board["tasks"].items() if e["status"] != "done"]
    if not pending:
        board["status"] = "complete"
    save_json(board_path, board)
    print(json.dumps({"completed": task_id, "remaining": len(pending)}))


def block(board_path: Path, task_id: str, reason: str, waiting_on: str | None) -> None:
    board = load_json(board_path)
    entry = board["tasks"].get(task_id)
    if entry is None:
        sys.exit(f"Unknown task: {task_id}")
    entry["status"] = "blocked"
    entry["blocked_reason"] = reason
    if waiting_on:
        entry["depends_on"] = list(set((entry.get("depends_on") or []) + [waiting_on]))
    board["updated_at"] = _utc_now()
    save_json(board_path, board)


def cmd_status(board_path: Path) -> None:
    board = load_json(board_path)
    print(json.dumps(board, indent=2))


def cmd_runnable(board_path: Path) -> None:
    board = load_json(board_path)
    ids = runnable_tasks(board)
    locked = sorted(files_in_flight(board))
    payload = {"runnable": ids, "files_locked": locked, "errors": validate_board(board)}
    print(json.dumps(payload, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description="Akshara ERP multi-agent coordinator")
    parser.add_argument("--board", type=Path, default=DEFAULT_BOARD)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    sub = parser.add_subparsers(dest="command", required=True)

    p_init = sub.add_parser("init", help="Initialize handoff board from manifest")
    p_init.add_argument("--run-id", required=True)

    sub.add_parser("runnable", help="List tasks ready to run (JSON)")
    sub.add_parser("status", help="Print handoff board")
    sub.add_parser("validate", help="Validate file locks and conflicts")

    p_claim = sub.add_parser("claim", help="Agent claims a task (in_progress)")
    p_claim.add_argument("task_id")
    p_claim.add_argument("--agent", required=True)

    p_done = sub.add_parser("complete", help="Mark task done with handoff summary")
    p_done.add_argument("task_id")
    p_done.add_argument("--summary", required=True)

    p_block = sub.add_parser("block", help="Mark task blocked waiting on another")
    p_block.add_argument("task_id")
    p_block.add_argument("--reason", required=True)
    p_block.add_argument("--waiting-on")

    args = parser.parse_args()

    if args.command == "init":
        init_board(args.run_id, args.manifest, args.board)
    elif args.command == "runnable":
        cmd_runnable(args.board)
    elif args.command == "status":
        cmd_status(args.board)
    elif args.command == "validate":
        board = load_json(args.board)
        errors = validate_board(board)
        if errors:
            print("\n".join(errors), file=sys.stderr)
            sys.exit(1)
        print("OK")
    elif args.command == "claim":
        claim(args.board, args.task_id, args.agent)
    elif args.command == "complete":
        complete(args.board, args.task_id, args.summary)
    elif args.command == "block":
        block(args.board, args.task_id, args.reason, args.waiting_on)


if __name__ == "__main__":
    main()
