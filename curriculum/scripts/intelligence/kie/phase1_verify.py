"""Phase 1 — Repository Verification + D-5 Certification gate.

Consumes the verifier manifest (curriculum/knowledge/repository_verification.json,
produced by the REUSED repository_verifier.py — integrity/hashing/parser-readiness
are never reimplemented), ingests every document into the local KIE store, and
applies the D-5 certification rule:

    Downloaded  ->  Verified  ->  Certified

Only CERTIFIED documents are eligible for downstream KB work (Phase 2+). Corrupt /
encrypted documents are quarantined; duplicates defer to their canonical. This is
the frozen gate: "KB work may never start before certification" (owner decision D-5).
"""
from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Tuple

from kie import config, ledger, store

_YEAR = re.compile(r"(?:/|_|-)(19|20)\d{2}(?:/|_|\.|-)")


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def doc_id_for(sha256: str) -> str:
    """Stable, deterministic document id derived from the content hash."""
    return sha256[:16]


def _year_from_path(path: str) -> Optional[int]:
    m = _YEAR.search(path)
    return int(m.group(0)[1:5]) if m else None


def classify(entry: dict) -> Tuple[str, str, str]:
    """Return (verify_status, certify_status, certify_reason) for one verifier entry (D-5).

    The store keys documents by content (doc_id = sha256[:16]), so identical files
    collapse to a single row — that IS content dedup. A duplicate of intact content
    is therefore still certified content (never a downgrade); only corruption and
    encryption quarantine a document.
    """
    if not entry.get("integrity_ok", False) or entry.get("corruption_reason"):
        return "corrupt", "quarantined", entry.get("corruption_reason") or "integrity_failed"
    if entry.get("encrypted"):
        return "encrypted", "quarantined", "encrypted_document"
    if entry.get("is_duplicate"):
        return "verified", "certified", f"duplicate_path_of:{entry.get('duplicate_of')}"
    return "verified", "certified", "verified_unique_intact"


def ingest_entry(conn, corpus: str, entry: dict) -> str:
    """Upsert one document; record the verify-stage ledger row. Returns certify_status."""
    verify_status, certify_status, certify_reason = classify(entry)
    did = doc_id_for(entry["sha256"])
    conn.execute(
        """INSERT INTO source_documents
             (doc_id, corpus, rel_path, category, exam, subject, class_label, doc_type, year, language,
              kind, bytes, pages, sha256, integrity_ok, corruption_reason, encrypted,
              parser_class, parser_strategy, is_duplicate, duplicate_of,
              verify_status, certify_status, certify_reason, created_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
           ON CONFLICT(doc_id) DO UPDATE SET
             corpus=excluded.corpus, rel_path=excluded.rel_path, category=excluded.category,
             exam=excluded.exam, year=excluded.year, kind=excluded.kind, bytes=excluded.bytes,
             pages=excluded.pages, integrity_ok=excluded.integrity_ok,
             corruption_reason=excluded.corruption_reason, encrypted=excluded.encrypted,
             parser_class=excluded.parser_class, parser_strategy=excluded.parser_strategy,
             is_duplicate=excluded.is_duplicate, duplicate_of=excluded.duplicate_of,
             verify_status=excluded.verify_status, certify_status=excluded.certify_status,
             certify_reason=excluded.certify_reason""",
        (
            did, corpus, entry["path"], entry.get("category"), entry.get("category"),
            None, None, None, _year_from_path(entry["path"]), None,
            entry.get("kind"), entry.get("bytes"), entry.get("pages"), entry["sha256"],
            1 if entry.get("integrity_ok") else 0, entry.get("corruption_reason"),
            1 if entry.get("encrypted") else 0, entry.get("parser_class"), entry.get("parser_strategy"),
            1 if entry.get("is_duplicate") else 0, entry.get("duplicate_of"),
            verify_status, certify_status, certify_reason, _now(),
        ),
    )
    ledger.record(conn, did, "verify", "done", input_sha256=entry["sha256"], output_ref=certify_status)
    return certify_status


def run(conn, manifest_path: Optional[Path] = None, corpus: Optional[str] = None) -> dict:
    """Ingest the verifier manifest and apply the D-5 certification gate.

    Returns a summary dict with per-status counts + the repository certification verdict.
    """
    corpus = corpus or config.DEFAULT_CORPUS
    path = Path(manifest_path) if manifest_path else config.VERIFICATION_MANIFEST
    manifest = json.loads(Path(path).read_text())
    entries = manifest.get("entries", [])

    entries_seen = duplicate_entries = 0
    with store.txn(conn):
        for entry in entries:
            entries_seen += 1
            if entry.get("is_duplicate"):
                duplicate_entries += 1
            ingest_entry(conn, corpus, entry)

    # Count DOCUMENTS (distinct content rows) for this corpus — duplicates collapsed.
    by_status = {
        r["certify_status"]: r["n"]
        for r in conn.execute(
            "SELECT certify_status, COUNT(*) AS n FROM source_documents "
            "WHERE corpus = ? GROUP BY certify_status",
            (corpus,),
        ).fetchall()
    }
    certified = by_status.get("certified", 0)
    quarantined = by_status.get("quarantined", 0)
    summary = {
        "corpus": corpus,
        "manifest": str(path),
        "entries": entries_seen,
        "duplicate_entries": duplicate_entries,
        "unique_documents": certified + quarantined,
        "certified": certified,
        "quarantined": quarantined,
        # D-5 verdict: repository is certified for KB work once ≥1 document certifies.
        "repository_certified": certified > 0,
    }
    return summary


def certified_docs(conn):
    """All documents eligible for downstream KB processing (Phase 2+)."""
    return [
        dict(r)
        for r in conn.execute(
            "SELECT * FROM source_documents WHERE certify_status = ? ORDER BY doc_id",
            (config.CERTIFIED,),
        ).fetchall()
    ]


def render_report(conn, summary: dict) -> str:
    by_class = conn.execute(
        "SELECT parser_class, COUNT(*) AS n FROM source_documents "
        "WHERE certify_status = 'certified' GROUP BY parser_class ORDER BY n DESC"
    ).fetchall()
    lines = [
        "# KIE Phase 1 — Repository Verification & Certification",
        "",
        f"- Corpus: **{summary['corpus']}**",
        f"- Manifest entries: **{summary['entries']}** "
        f"(duplicate paths collapsed: {summary['duplicate_entries']})",
        f"- Unique documents: **{summary['unique_documents']}** — certified "
        f"**{summary['certified']}**, quarantined **{summary['quarantined']}**",
        f"- Repository certified (D-5): **{summary['repository_certified']}**",
        "",
        "## Certified documents by parser class (Phase-2 routing)",
        "",
        "| parser_class | count |",
        "|---|---|",
    ]
    lines += [f"| {r['parser_class']} | {r['n']} |" for r in by_class]
    lines += ["", f"Store: `{config.DB_PATH}` · gate: only `certify_status='certified'` proceeds to Phase 2."]
    return "\n".join(lines) + "\n"
