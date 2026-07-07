#!/usr/bin/env python3
"""Project-management file synchronizer (spec Part 02).

Keeps PROGRESS.md and PROJECT_STATUS.json in sync with the live repository state
(queue + completed + failed + coverage). Does NOT touch the certification fields
(`repository_certified`, `repository_status`) — those are owned solely by
repository_audit.py so the D-5 gate stays authoritative. Append-only files
(SESSION_LOG.md, CHECKPOINTS.md) are never rewritten here.

Usage:
  pm_sync.py [--workspace DIR]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
import coverage as cov  # noqa: E402
from workspace import Workspace, load_json, write_json, utcnow  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]


def _current_focus(queue: list[dict]) -> tuple[str, str, str]:
    """First non-terminal queue cell → (board, class, subject) for PROGRESS."""
    terminal = {"VERIFIED", "NOT_PUBLICLY_AVAILABLE", "SKIPPED"}
    for e in queue:
        if e.get("status") not in terminal:
            return e.get("board", "—") or "—", e.get("class_label", "—") or "—", e.get("subject", "—") or "—"
    return "—", "—", "—"


def sync(ws: Workspace) -> dict:
    queue = load_json(ws.pm("download_queue"), []) or []
    completed = load_json(ws.pm("completed_downloads"), []) or []
    failed = load_json(ws.pm("failed_downloads"), []) or []
    data = cov.compute(ws)
    overall = data["overall"]

    by_status: dict[str, int] = {}
    for e in queue:
        by_status[e.get("status", "PENDING")] = by_status.get(e.get("status", "PENDING"), 0) + 1

    pct = overall["coverage_completeness"] * 100
    retry_queue = sum(1 for e in failed if e.get("status") == "RETRY_PENDING")
    board, klass, subject = _current_focus(queue)
    remaining = max(0, overall["expected_cells"] - overall["covered_cells"] - overall["documented_cells"])
    remaining_txt = "acquisition not started" if not queue else f"{remaining} of {overall['expected_cells']} cells"

    # PROGRESS.md — the full Part-02 field set (spec §207-233)
    progress_lines = [
        "# Progress", "", f"_Last update: {utcnow()}_", "",
        "| Field | Value |", "|---|---|",
        "| Current stage | CI-A0 (workspace scaffolding + dry-run) |",
        f"| Current board | {board} |",
        f"| Current class | {klass} |",
        f"| Current subject | {subject} |",
        f"| Files downloaded | {len(completed)} |",
        f"| Files verified | {len(completed)} |",
        f"| Files failed | {len(failed)} |",
        f"| Retry queue | {retry_queue} |",
        f"| Queue entries | {len(queue)} |",
        f"| Expected cells (A+B) | {overall['expected_cells']} |",
        f"| Estimated remaining work | {remaining_txt} |",
        f"| Overall completion | {pct:.1f}% |",
        "",
        "## Queue status breakdown", "",
        "| Status | Count |", "|---|---|",
    ]
    for status_name, n in sorted(by_status.items()):
        progress_lines.append(f"| {status_name} | {n} |")
    if not by_status:
        progress_lines.append("| (empty queue) | 0 |")
    ws.pm("progress").write_text("\n".join(progress_lines) + "\n", encoding="utf-8")

    # PROJECT_STATUS.json — preserve certification fields owned by the audit tool
    status = load_json(ws.pm("project_status"), {}) or {}
    status.setdefault("repository_certified", False)
    status.setdefault("repository_status", "NOT_READY")
    status.update({
        "current_stage": "CI-A0",
        "last_updated": utcnow(),
        "current_board": board,
        "current_class": klass,
        "current_subject": subject,
        "queue_entries": len(queue),
        "downloads": len(completed),
        "files_verified": len(completed),
        "failures": len(failed),
        "failures_outstanding": len(failed),
        "retry_queue": retry_queue,
        "warnings": 0,
        "queue_status": by_status,
        "overall_progress_pct": round(pct, 1),
        "coverage_completeness_pct": round(pct, 1),
        "verified_resources": overall["verified_resources"],
    })
    write_json(ws.pm("project_status"), status)
    return {"queue": len(queue), "verified": len(completed), "coverage_pct": round(pct, 1)}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    print(f"pm_sync: {sync(ws)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
