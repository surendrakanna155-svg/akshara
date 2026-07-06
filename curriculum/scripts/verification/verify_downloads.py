#!/usr/bin/env python3
"""CLI for the Download Verification & Recovery Engine.

Usage (run from anywhere; workspace root auto-resolved to curriculum/):
  verify_downloads.py --batch                 verify everything in downloads/incoming
                                              against DOWNLOAD_QUEUE.json entries
  verify_downloads.py --file F --expected E   verify one file against an expected-JSON file
  verify_downloads.py --report-only           regenerate DOWNLOAD_VERIFICATION_REPORT.md

Exit code 0 = all processed files verified (or report-only); 1 = at least one failure.
Every run regenerates the verification report (continuous-update requirement).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verification_engine import DUPLICATE, VERIFIED, VerificationEngine  # noqa: E402

WORKSPACE = Path(__file__).resolve().parents[2]


def _load(path: Path):
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--file", type=Path, help="single downloaded file to verify")
    ap.add_argument("--expected", type=Path, help="JSON file with the expected-resource record")
    ap.add_argument("--batch", action="store_true", help="verify downloads/incoming against DOWNLOAD_QUEUE.json")
    ap.add_argument("--report-only", action="store_true")
    ap.add_argument("--workspace", type=Path, default=WORKSPACE)
    args = ap.parse_args()

    engine = VerificationEngine(args.workspace)
    failures = 0

    if args.report_only:
        print(f"report: {engine.generate_report()}")
        return 0

    jobs: list[tuple[dict, Path]] = []
    if args.file:
        if not args.expected:
            ap.error("--file requires --expected")
        jobs.append((_load(args.expected), args.file))
    elif args.batch:
        queue_path = args.workspace / engine.paths["pm_files"]["download_queue"]
        queue = _load(queue_path) if queue_path.exists() else []
        incoming = args.workspace / engine.paths["downloads_incoming"]
        by_name = {e.get("expected_filename"): e for e in queue}
        for f in sorted(incoming.glob("*")) if incoming.exists() else []:
            if f.is_file() and f.name in by_name:
                jobs.append((by_name[f.name], f))
        unmatched = [f.name for f in (incoming.glob("*") if incoming.exists() else [])
                     if f.is_file() and f.name not in by_name]
        for name in unmatched:
            print(f"SKIP (no queue entry — anonymous files are not allowed): {name}")
    else:
        ap.error("choose --file, --batch or --report-only")

    for expected, path in jobs:
        result = engine.verify_resource(expected, path)
        tag = result.status
        print(f"{tag}: {result.resource_id} ({path.name})"
              + (f" — {result.reason_code}: {result.detail}" if tag not in (VERIFIED, DUPLICATE) else ""))
        if tag not in (VERIFIED, DUPLICATE):
            failures += 1
            action = engine.next_recovery_action(result.resource_id)
            print(f"  recovery → {action}")
            if action.get("action") == "RECORD_MISSING":
                engine.record_missing(expected, expected.get("search_locations", []),
                                      f"all sources exhausted; last failure {result.reason_code}")

    report = engine.generate_report()
    print(f"report: {report}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
