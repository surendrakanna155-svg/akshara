#!/usr/bin/env python3
"""Project-management file bootstrap (spec Part 02 §170-388).

Materializes ALL EIGHT PM files at the workspace root with the exact Part-02
field sets, idempotently:

  TODO.md               Pending / In Progress / Completed / Blocked / Skipped
  PROGRESS.md           stage/board/class/subject, files downloaded/verified/failed,
                        retry queue, remaining work, completion %, last update
  SESSION_LOG.md        append-only chronological engineering log
  CHECKPOINTS.md        recovery checkpoints (append-only)
  DOWNLOAD_QUEUE.json   array of expected-resource records (schema: download_queue.schema.json)
  FAILED_DOWNLOADS.json array of failure records
  COMPLETED_DOWNLOADS.json array of verified-download records
  PROJECT_STATUS.json   machine-readable status summary

Idempotent + append-safe:
  * The three JSON queues are created as `[]` only when absent (never clobber live state).
  * TODO/PROGRESS are seeded only when absent (pm_sync.py maintains PROGRESS live).
  * SESSION_LOG/CHECKPOINTS are append-only — a header + one bootstrap entry is
    written only when the file does not yet exist; re-runs never rewrite history.
  * PROJECT_STATUS is created/backfilled with the Part-02 fields while the D-5
    certification fields (`repository_certified`, `repository_status`,
    `certification`) are LEFT UNTOUCHED — they are owned solely by
    repository_audit.py so the certification gate stays authoritative.

Usage:
  pm_bootstrap.py [--workspace DIR]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]

STAGE = "CI-A0"


def _write_text_if_absent(path: Path, text: str) -> bool:
    if path.exists():
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return True


def _todo_seed() -> str:
    return (
        "# TODO\n\n"
        f"_Stage: {STAGE} — curriculum workspace scaffolding + dry-run. "
        "Every completed task moves immediately into Completed._\n\n"
        "## Pending\n"
        "- CI-A1 CBSE/NCERT discovery → Priority-A acquisition (needs a networked run).\n\n"
        "## In Progress\n"
        "- (none)\n\n"
        "## Completed\n"
        "- CI-A0 workspace scaffolding: Part-04 directory standard materialized.\n"
        "- CI-A0 PM files bootstrapped (Part-02).\n"
        "- Download Verification & Recovery Engine (V1-V11) + D-5 certifier in place.\n\n"
        "## Blocked\n"
        "- Real acquisition (CI-A1+) — requires a networked environment + legal source review.\n\n"
        "## Skipped\n"
        "- (none)\n"
    )


def _progress_seed() -> str:
    return (
        "# Progress\n\n"
        f"_Last update: {utcnow()}_\n\n"
        "| Field | Value |\n|---|---|\n"
        f"| Current stage | {STAGE} |\n"
        "| Current board | — |\n"
        "| Current class | — |\n"
        "| Current subject | — |\n"
        "| Files downloaded | 0 |\n"
        "| Files verified | 0 |\n"
        "| Files failed | 0 |\n"
        "| Retry queue | 0 |\n"
        "| Estimated remaining work | acquisition not started |\n"
        "| Overall completion | 0.0% |\n"
    )


def _session_log_seed() -> str:
    return (
        "# Session Log\n\n"
        "Chronological engineering log (append-only — never overwrite previous sessions).\n\n"
        f"## Session {utcnow()}\n"
        "- **Session start:** bootstrap\n"
        "- **Actions performed:** materialized the Part-02 PM file set; workspace scaffolded.\n"
        "- **Resources downloaded:** 0\n"
        "- **Errors encountered:** none\n"
        "- **Recovery actions:** none\n"
        "- **Next planned step:** CI-A1 discovery (networked run) once authorized.\n"
        "- **Session end:** bootstrap complete\n"
    )


def _checkpoints_seed() -> str:
    return (
        "# Checkpoints\n\n"
        "Recovery checkpoints (append-only). If execution stops, resume from the latest.\n\n"
        "## Checkpoint 000 — CI-A0 bootstrap\n"
        "- **Completed boards:** none\n"
        "- **Completed classes:** none\n"
        "- **Completed subjects:** none\n"
        "- **Downloaded files:** 0\n"
        "- **Metadata generated:** 0\n"
        "- **Reports generated:** yes (empty-state)\n"
        "- **Pending work:** CI-A1 discovery + acquisition (networked run required)\n"
        "- **Recovery instructions:** re-run scaffold_workspace.py + pm_bootstrap.py "
        "(idempotent), then pm_sync.py; state is reconstructed from the queues + indexes.\n"
    )


def bootstrap(ws: Workspace) -> dict:
    created: list[str] = []
    existed: list[str] = []

    def track(key: str, made: bool) -> None:
        (created if made else existed).append(key)

    # append-only / seed-if-absent markdown files
    track("TODO.md", _write_text_if_absent(ws.pm("todo"), _todo_seed()))
    track("PROGRESS.md", _write_text_if_absent(ws.pm("progress"), _progress_seed()))
    track("SESSION_LOG.md", _write_text_if_absent(ws.pm("session_log"), _session_log_seed()))
    track("CHECKPOINTS.md", _write_text_if_absent(ws.pm("checkpoints"), _checkpoints_seed()))

    # JSON queues — create as [] only when absent (never clobber live data)
    for key, fname in (("download_queue", "DOWNLOAD_QUEUE.json"),
                       ("failed_downloads", "FAILED_DOWNLOADS.json"),
                       ("completed_downloads", "COMPLETED_DOWNLOADS.json")):
        p = ws.pm(key)
        if p.exists():
            existed.append(fname)
        else:
            write_json(p, [])
            created.append(fname)

    # PROJECT_STATUS.json — backfill Part-02 fields, preserve D-5 cert fields verbatim
    ps_path = ws.pm("project_status")
    status = load_json(ps_path, {}) or {}
    fresh = not ps_path.exists()
    status.setdefault("repository_certified", False)      # owned by repository_audit.py
    status.setdefault("repository_status", "NOT_READY")   # owned by repository_audit.py
    status.setdefault("current_stage", STAGE)
    status.setdefault("overall_progress_pct", 0.0)
    status.setdefault("board_progress", {})
    status.setdefault("class_progress", {})
    status.setdefault("subject_progress", {})
    status.setdefault("downloads", 0)
    status.setdefault("failures", 0)
    status.setdefault("warnings", 0)
    status["last_updated"] = utcnow()
    write_json(ps_path, status)
    (created if fresh else existed).append("PROJECT_STATUS.json")

    return {"created": created, "existed": existed}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    result = bootstrap(ws)
    print(f"pm_bootstrap: created={result['created']} existed={result['existed']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
