"""KIE command-line entry.

Run:  PYTHONPATH=curriculum/scripts/intelligence \
      curriculum/.venv/bin/python3 -m kie.cli verify [--corpus foundation]
"""
from __future__ import annotations

import argparse
import json
import sys

from kie import config, phase1_verify, store


def cmd_verify(args) -> int:
    config.ensure_dirs()
    conn = store.open_store(args.db)
    try:
        summary = phase1_verify.run(conn, manifest_path=args.manifest, corpus=args.corpus)
        (config.REPORTS_DIR / "KIE_PHASE1_REPORT.md").write_text(
            phase1_verify.render_report(conn, summary)
        )
    finally:
        conn.close()
    print(json.dumps(summary, indent=2))
    return 0 if summary["repository_certified"] else 2


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="kie", description="Knowledge Intelligence Engine")
    sub = ap.add_subparsers(dest="phase", required=True)

    v = sub.add_parser("verify", help="Phase 1 — repository verification + D-5 certification")
    v.add_argument("--manifest", default=None, help="verifier manifest json (default: known path)")
    v.add_argument("--corpus", default=config.DEFAULT_CORPUS, choices=list(config.CORPORA))
    v.add_argument("--db", default=None, help="SQLite store path (default: knowledge/kie/kie.db)")
    v.set_defaults(func=cmd_verify)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
