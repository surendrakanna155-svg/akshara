"""Knowledge Intake Center — command-line entry.

Incremental ingestion + review + promotion. Operates on the production KB
(knowledge/kie/kie.db) by default; pass --db to target another store (tests/dry-runs).

  # import new resources (single/multiple/folder/zip/drag&drop all funnel through here)
  python -m kie.intake.cli import path/to/file.pdf another.pdf a_folder/ bundle.zip
  python -m kie.intake.cli queue [--status pending|needs_review|approved|rejected|skipped]
  python -m kie.intake.cli show   <item_id>
  python -m kie.intake.cli approve <item_id> [--reviewer NAME] [--note TEXT]
  python -m kie.intake.cli reject  <item_id> [--reviewer NAME] [--note TEXT]
  python -m kie.intake.cli refresh                         # KG + Question-Intelligence update
  python -m kie.intake.cli watch  <folder> [--once] [--interval SECONDS]
  python -m kie.intake.cli backfill-lineage                # enable versioning vs the baseline
  python -m kie.intake.cli url <URL>                       # placeholder — not implemented
"""
from __future__ import annotations

import argparse
import json
import sys
import time

from kie.intake import collector, report
from kie.intake.center import IntakeCenter
from kie.intake.models import SourceKind


def _center(args) -> IntakeCenter:
    return IntakeCenter(prod_db_path=args.db, intake_ws=args.workspace, staging_dir=args.staging_dir)


def cmd_import(args) -> int:
    kind = args.kind or (SourceKind.SINGLE if len(args.paths) == 1 else SourceKind.MULTIPLE)
    summary = _center(args).import_paths(args.paths, source_kind=kind, category=args.category, label=args.label)
    print(json.dumps(summary, indent=2))
    return 0


def cmd_queue(args) -> int:
    items = _center(args).list_queue(status=args.status, batch_id=args.batch)
    for it in items:
        v = f"v{it.version_no}" if it.version_no else "-"
        flags = (" [" + ",".join(it.flags) + "]") if it.flags else ""
        print(f"{it.item_id}  {it.review_status:<12} {it.disposition:<14} {v:<4} {it.original_name}{flags}")
    print(f"\n{len(items)} item(s)")
    return 0


def cmd_show(args) -> int:
    c = _center(args)
    it = c.get_item(args.item_id)
    if not it:
        print(f"unknown item: {args.item_id}", file=sys.stderr)
        return 1
    print(json.dumps({
        "item_id": it.item_id, "batch_id": it.batch_id, "doc_id": it.doc_id,
        "original_name": it.original_name, "category": it.category, "disposition": it.disposition,
        "version_no": it.version_no, "version_of": it.version_of, "lineage_key": it.lineage_key,
        "review_status": it.review_status, "verify_status": it.verify_status,
        "certify_status": it.certify_status, "flags": it.flags, "stats": it.stats, "notes": it.notes,
    }, indent=2))
    sample = c.preview_concepts(args.item_id)
    if sample:
        print("\nsample concepts:", ", ".join(sample))
    return 0


def cmd_approve(args) -> int:
    out = _center(args).approve(args.item_id, reviewer=args.reviewer, notes=args.note, refresh=not args.no_refresh)
    print(json.dumps({k: v for k, v in out.items() if k != "derived"}, indent=2))
    return 0


def cmd_reject(args) -> int:
    print(json.dumps(_center(args).reject(args.item_id, reviewer=args.reviewer, notes=args.note), indent=2))
    return 0


def cmd_refresh(args) -> int:
    out = _center(args).refresh_production()
    print(json.dumps({"graph_edges": out["graph"].get("edges_total"),
                      "question_patterns": out["questions"].get("patterns")}, indent=2))
    return 0


def cmd_watch(args) -> int:
    c = _center(args)
    while True:
        res = c.poll_watch_folder(args.folder, category=args.category)
        print(json.dumps({"folder": res["folder"], "new_or_changed": res["new_or_changed"],
                          "batch_id": res["batch_id"]}, indent=2), flush=True)
        if args.once:
            return 0
        time.sleep(max(1, args.interval))


def cmd_backfill(args) -> int:
    n = _center(args).register_baseline_lineage()
    print(json.dumps({"baseline_versions_registered": n}, indent=2))
    return 0


def cmd_report(args) -> int:
    c = _center(args)
    conn = c.open()
    try:
        print(report.batch_report(conn, args.batch_id) if args.batch_id else report.queue_report(conn))
    finally:
        conn.close()
    return 0


def cmd_url(args) -> int:
    try:
        collector.url_import(args.url)
    except collector.UrlImportNotImplemented as exc:
        print(str(exc))
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="kie.intake", description="Knowledge Intake Center")
    ap.add_argument("--db", default=None, help="production KB path (default: knowledge/kie/kie.db)")
    ap.add_argument("--workspace", default=None, help="intake workspace (default: curriculum/)")
    ap.add_argument("--staging-dir", default=None, dest="staging_dir")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("import", help="ingest new/updated resources")
    p.add_argument("paths", nargs="+")
    p.add_argument("--category", default=None)
    p.add_argument("--label", default=None)
    p.add_argument("--kind", default=None, choices=list(SourceKind.ALL))
    p.set_defaults(func=cmd_import)

    p = sub.add_parser("queue", help="list the review queue")
    p.add_argument("--status", default=None)
    p.add_argument("--batch", default=None)
    p.set_defaults(func=cmd_queue)

    p = sub.add_parser("show", help="show one item + concept preview")
    p.add_argument("item_id")
    p.set_defaults(func=cmd_show)

    p = sub.add_parser("approve", help="approve → additive promotion into the KB")
    p.add_argument("item_id")
    p.add_argument("--reviewer", default=None)
    p.add_argument("--note", default=None)
    p.add_argument("--no-refresh", action="store_true", help="defer the derived refresh (bulk approvals)")
    p.set_defaults(func=cmd_approve)

    p = sub.add_parser("reject", help="reject an item (never promoted)")
    p.add_argument("item_id")
    p.add_argument("--reviewer", default=None)
    p.add_argument("--note", default=None)
    p.set_defaults(func=cmd_reject)

    p = sub.add_parser("refresh", help="Knowledge Graph + Question Intelligence update")
    p.set_defaults(func=cmd_refresh)

    p = sub.add_parser("watch", help="watch a local folder for new/changed files")
    p.add_argument("folder")
    p.add_argument("--category", default=None)
    p.add_argument("--once", action="store_true")
    p.add_argument("--interval", type=int, default=30)
    p.set_defaults(func=cmd_watch)

    p = sub.add_parser("backfill-lineage", help="register baseline docs for versioning")
    p.set_defaults(func=cmd_backfill)

    p = sub.add_parser("report", help="render a batch report, or the queue status if no batch")
    p.add_argument("batch_id", nargs="?", default=None)
    p.set_defaults(func=cmd_report)

    p = sub.add_parser("url", help="Direct URL Import (placeholder — not implemented)")
    p.add_argument("url")
    p.set_defaults(func=cmd_url)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
