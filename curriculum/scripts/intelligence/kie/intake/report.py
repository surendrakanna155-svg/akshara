"""Intake reporting — live batch + queue summaries rendered from the control tables.

The standing architecture/certification narrative lives in
docs/knowledge-intelligence-engine/KNOWLEDGE_INTAKE_CENTER_CERTIFICATION.md; this module
renders the *operational* reports (what a given import batch did / the current queue state).
"""
from __future__ import annotations

import json
from typing import Optional

from kie.intake.models import ReviewStatus


def _counts(conn, col: str, where: str = "", args=()) -> dict:
    sql = f"SELECT {col} k, COUNT(*) n FROM intake_items"
    if where:
        sql += f" WHERE {where}"
    sql += f" GROUP BY {col} ORDER BY {col}"
    return {r["k"]: r["n"] for r in conn.execute(sql, args).fetchall()}


def batch_report(conn, batch_id: str) -> str:
    b = conn.execute("SELECT * FROM intake_batches WHERE batch_id=?", (batch_id,)).fetchone()
    if not b:
        return f"# Intake batch {batch_id}\n\n_Not found._\n"
    items = conn.execute(
        "SELECT * FROM intake_items WHERE batch_id=? ORDER BY item_id", (batch_id,)).fetchall()
    disp = _counts(conn, "disposition", "batch_id=?", (batch_id,))
    rev = _counts(conn, "review_status", "batch_id=?", (batch_id,))

    L = [
        f"# Knowledge Intake — Batch `{batch_id}`",
        "",
        f"- Source kind: **{b['source_kind']}** · status: **{b['status']}** · created: {b['created_at']}",
        f"- Items: **{len(items)}** · dispositions: {json.dumps(disp)} · review: {json.dumps(rev)}",
        "",
        "| Item | File | Disposition | Ver | Review | Chunks | Concepts | Patterns | Flags |",
        "|---|---|---|---|---|--:|--:|--:|---|",
    ]
    for it in items:
        stats = json.loads(it["stats"] or "{}")
        flags = ", ".join(json.loads(it["flags"] or "[]"))
        ver = f"v{it['version_no']}" if it["version_no"] else "-"
        L.append(
            f"| {it['item_id'].split('#')[-1]} | {it['original_name']} | {it['disposition']} | {ver} | "
            f"{it['review_status']} | {stats.get('chunks','-')} | {stats.get('concepts','-')} | "
            f"{stats.get('patterns','-')} | {flags} |")
    L += ["", f"_Staging store: `{b['staging_ref']}` (local-only)._", ""]
    return "\n".join(L)


def queue_report(conn) -> str:
    total = conn.execute("SELECT COUNT(*) n FROM intake_items").fetchone()["n"]
    rev = _counts(conn, "review_status")
    disp = _counts(conn, "disposition")
    promoted = conn.execute("SELECT COUNT(*) n FROM intake_items WHERE promoted_at IS NOT NULL").fetchone()["n"]
    versions = conn.execute("SELECT COUNT(*) n FROM document_versions").fetchone()["n"]
    open_n = rev.get(ReviewStatus.PENDING, 0) + rev.get(ReviewStatus.NEEDS_REVIEW, 0)
    L = [
        "# Knowledge Intake — Queue Status",
        "",
        f"- Total items seen: **{total}** · promoted to production: **{promoted}** · "
        f"document versions registered: **{versions}**",
        f"- Awaiting review (pending + needs_review): **{open_n}**",
        "",
        f"- By review status: {json.dumps(rev)}",
        f"- By disposition: {json.dumps(disp)}",
        "",
    ]
    return "\n".join(L)
