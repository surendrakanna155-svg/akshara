#!/usr/bin/env python3
"""Retry immediate_acquire FETCH_FAIL entries from log."""
from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery", "reports", "acquisition"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, utcnow  # noqa: E402
import immediate_acquire  # noqa: E402

FAIL_RE = re.compile(r"FETCH_FAIL (AKS-[^:]+):")


def failed_ids(log_paths: list[Path]) -> list[str]:
    ids: list[str] = []
    seen: set[str] = set()
    for path in log_paths:
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            m = FAIL_RE.search(line)
            if m and m.group(1) not in seen:
                seen.add(m.group(1))
                ids.append(m.group(1))
    return ids


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--log", action="append", type=Path, default=None)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    logs = args.log or [
        args.workspace / "acquisition" / "immediate_acquire.log",
        Path("/Users/surendrakanna/.cursor/projects/Users-surendrakanna-Documents-Akshara-ERP/terminals/371549.txt"),
    ]
    target = failed_ids(logs)
    if not target:
        print("no FETCH_FAIL ids found")
        return 0

    engine = get_engine(ws.root)
    entries = immediate_acquire.discover_all(ws, immediate_acquire.BOARD_FILTER["all"], assessment_only=False)
    by_id = {e["resource_id"]: e for e in entries}
    stats = Counter()
    for rid in target:
        entry = by_id.get(rid)
        if not entry:
            stats["NOT_IN_CATALOGUE"] += 1
            continue
        outcome = immediate_acquire.acquire_one(ws, entry, engine, allow_network=True)
        stats[outcome] += 1
        immediate_acquire.log(f"RETRY {rid} -> {outcome}")
    immediate_acquire.log(f"RETRY_DONE {dict(stats)}")
    print(dict(stats))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
