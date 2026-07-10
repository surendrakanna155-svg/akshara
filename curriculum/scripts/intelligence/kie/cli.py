"""KIE command-line entry.

Run a single phase or the whole deterministic pipeline (resumable via the stage
ledger; content-hash checkpointed; no LLM). Uses ONLY the canonical kie/ phases —
this is an operational runner, not a new implementation.

  PYTHONPATH=curriculum/scripts/intelligence curriculum/.venv/bin/python3 -m kie.cli verify
  ...-m kie.cli run --stage all            # parse → metadata → chunk → concept → graph → questions
  ...-m kie.cli run --stage parse          # a single stage
  ...-m kie.cli run --stage all --force    # ignore the ledger and reprocess
"""
from __future__ import annotations

import argparse
import json
import sys

from kie import (config, phase1_verify, phase2_parse, phase3_metadata, phase4_chunk,
                 phase5_concept, phase6_graph, phase7_questions, store)

# Ordered pipeline after Phase-1 verification. Each maps to an existing phase run().
PIPELINE = ("parse", "metadata", "chunk", "concept", "graph", "questions")


def _run_stage(conn, stage: str, force: bool) -> dict:
    if stage == "verify":
        return phase1_verify.run(conn)
    if stage == "parse":
        return phase2_parse.run(conn, force=force)
    if stage == "metadata":
        return phase3_metadata.run(conn, force=force)
    if stage == "chunk":
        return phase4_chunk.run(conn, force=force)
    if stage == "concept":
        return phase5_concept.run(conn, force=force)
    if stage == "graph":
        return phase6_graph.run(conn, force=force)
    if stage == "questions":
        return phase7_questions.run(conn, force=force)
    raise ValueError(f"unknown stage: {stage}")


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


def cmd_run(args) -> int:
    config.ensure_dirs()
    stages = list(PIPELINE) if args.stage == "all" else [args.stage]
    conn = store.open_store(args.db)
    results = {}
    try:
        for stage in stages:
            summary = _run_stage(conn, stage, args.force)
            results[stage] = summary
            print(f"[{stage}] {json.dumps(summary, sort_keys=True)}", flush=True)
    finally:
        conn.close()
    failed = sum(int(r.get("failed", 0) or 0) for r in results.values())
    return 1 if failed else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="kie", description="Knowledge Intelligence Engine")
    sub = ap.add_subparsers(dest="phase", required=True)

    v = sub.add_parser("verify", help="Phase 1 — repository verification + D-5 certification")
    v.add_argument("--manifest", default=None, help="verifier manifest json (default: known path)")
    v.add_argument("--corpus", default=config.DEFAULT_CORPUS, choices=list(config.CORPORA))
    v.add_argument("--db", default=None, help="SQLite store path (default: knowledge/kie/kie.db)")
    v.set_defaults(func=cmd_verify)

    r = sub.add_parser("run", help="run a pipeline stage (or 'all'); resumable, no LLM")
    r.add_argument("--stage", default="all", choices=("all",) + PIPELINE)
    r.add_argument("--force", action="store_true", help="ignore the ledger and reprocess")
    r.add_argument("--db", default=None, help="SQLite store path (default: knowledge/kie/kie.db)")
    r.set_defaults(func=cmd_run)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
