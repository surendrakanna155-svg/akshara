"""CLI for the question-corpus staging lane.

  python -m qcorpus.cli inventory                 # filesystem inventory only
  python -m qcorpus.cli benchmark                  # parser-route benchmark on a slice
  python -m qcorpus.cli biology                    # Priority-1 (Biology) + checkpoint
  python -m qcorpus.cli run [--resume]             # full corpus, priority order (resumable)
  python -m qcorpus.cli run --only P4_mathongo_jee_main
  python -m qcorpus.cli manifests                  # rebuild derived manifests
  python -m qcorpus.cli report                     # regenerate final report
  python -m qcorpus.cli gate                        # isolation + integrity gate

Resume is automatic — re-running `run`/`biology` skips completed docs. Nothing here ever
writes the KIE DB, Phase-0 artifacts, or kie/qpgen/.
"""
from __future__ import annotations

import argparse
import json
import sys

from qcorpus import config, isolation, pipeline, report


def _log(msg: str) -> None:
    print(msg, flush=True)


def cmd_inventory(_args) -> int:
    inv = pipeline.discover()
    by_prio = {}
    for it in inv:
        by_prio.setdefault(it["priority"], 0)
        by_prio[it["priority"]] += 1
    print(json.dumps({"total_pdfs": len(inv), "by_priority": dict(sorted(by_prio.items()))}, indent=2))
    return 0


def cmd_biology(args) -> int:
    isolation.record_baseline()
    _log("=== Priority 1: StudentBro Biology ===")
    summary = pipeline.run(only_priority="P1_studentbro_biology",
                           checkpoint_every=5, progress=_log, force=args.force)
    report.biology_checkpoint()
    report.final_report()
    gate = isolation.verify()
    print(json.dumps({"run": summary, "isolation_ok": gate["ok"]}, indent=2))
    print(f"\nBiology checkpoint -> {config.REPORTS_DIR / 'BIOLOGY_PRIORITY_CHECKPOINT.md'}")
    return 0 if gate["ok"] else 3


def cmd_run(args) -> int:
    isolation.record_baseline()
    summary = pipeline.run(only_priority=args.only, limit=args.limit,
                           checkpoint_every=args.checkpoint_every, progress=_log,
                           force=args.force)
    report.biology_checkpoint()
    report.final_report()
    gate = isolation.verify()
    print(json.dumps({"run": summary, "isolation_ok": gate["ok"]}, indent=2))
    return 0 if gate["ok"] else 3


def cmd_manifests(_args) -> int:
    counts = pipeline.rebuild_manifests()
    print(json.dumps(counts, indent=2))
    return 0


def cmd_report(_args) -> int:
    report.biology_checkpoint()
    report.final_report()
    print(json.dumps(report.aggregate(), indent=2))
    return 0


def cmd_gate(_args) -> int:
    gate = isolation.verify()
    print(json.dumps(gate, indent=2))
    return 0 if gate["ok"] else 3


def cmd_benchmark(args) -> int:
    from qcorpus import benchmark
    print(json.dumps(benchmark.run_benchmark(), indent=2, default=str))
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="qcorpus")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("inventory").set_defaults(fn=cmd_inventory)
    sub.add_parser("benchmark").set_defaults(fn=cmd_benchmark)

    b = sub.add_parser("biology"); b.add_argument("--force", action="store_true")
    b.set_defaults(fn=cmd_biology)

    r = sub.add_parser("run")
    r.add_argument("--only", default=None, help="process a single priority label")
    r.add_argument("--limit", type=int, default=None)
    r.add_argument("--checkpoint-every", type=int, default=10)
    r.add_argument("--resume", action="store_true", help="(default behaviour; explicit no-op)")
    r.add_argument("--force", action="store_true", help="re-process even terminal docs")
    r.set_defaults(fn=cmd_run)

    sub.add_parser("manifests").set_defaults(fn=cmd_manifests)
    sub.add_parser("report").set_defaults(fn=cmd_report)
    sub.add_parser("gate").set_defaults(fn=cmd_gate)

    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
