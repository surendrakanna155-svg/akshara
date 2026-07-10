"""Promotion — copy an APPROVED staged document into the production Knowledge Base
additively, record its version, then refresh the global derived layers.

Immutability contract (enforced here + covered by tests):
  * Every content write is ADDITIVE and scoped to the NEW doc_id — the 360-doc baseline's
    rows are never UPDATEd or DELETEd. Concepts/formulas use INSERT OR IGNORE, so a
    concept_code shared with the baseline keeps the baseline's row verbatim (history
    preserved, nothing overwritten). New codes are inserted.
  * The two DERIVED projections (concept graph, question intelligence) are recomputed
    deterministically over the COMBINED corpus — the "Knowledge Graph Update" and
    "Question Intelligence Update" pipeline steps. This re-derives from already-parsed
    chunks; it never re-parses/re-chunks any source document.

Cross-DB copy uses ATTACH so the copy is a single transactional unit on the production
connection. Promotion is idempotent (guarded by promoted_at at the center; the writes
themselves are OR-IGNORE / delete-by-new-doc-then-insert).
"""
from __future__ import annotations

from pathlib import Path

from kie import phase6_graph, phase7_questions
from kie.intake.models import Disposition
from kie.intake.store_ext import now_iso

# single-row-per-doc tables: additive insert keyed by doc_id (baseline rows never collide)
_SINGLE_ROW_TABLES = ("source_documents", "parsed_documents", "document_metadata")


def promote_document(prod_conn, staging_db_path: Path, doc_id: str, detection: dict,
                     item_id: str | None = None) -> dict:
    """Additively copy one approved staged doc (doc_id) from its staging DB into production
    and record its version lineage. Returns a small summary. Idempotent."""
    # ATTACH/DETACH cannot run inside a transaction — start from a clean (committed) conn.
    prod_conn.commit()
    prod_conn.execute("ATTACH DATABASE ? AS stg", (str(staging_db_path),))
    try:
        # 1) source registry + parse index + catalog metadata (one row per doc)
        for tbl in _SINGLE_ROW_TABLES:
            prod_conn.execute(
                f"INSERT OR IGNORE INTO main.{tbl} SELECT * FROM stg.{tbl} WHERE doc_id=?", (doc_id,))

        # 2) section outline — scoped delete-then-insert (only this new doc; idempotent)
        prod_conn.execute("DELETE FROM main.document_sections WHERE doc_id=?", (doc_id,))
        prod_conn.execute(
            "INSERT INTO main.document_sections SELECT * FROM stg.document_sections WHERE doc_id=?", (doc_id,))

        # 3) chunks + FTS in lockstep — scoped to this new doc only (baseline chunks untouched)
        prod_conn.execute(
            "DELETE FROM main.chunks_fts WHERE chunk_id IN "
            "(SELECT chunk_id FROM main.chunks WHERE doc_id=?)", (doc_id,))
        prod_conn.execute("DELETE FROM main.chunks WHERE doc_id=?", (doc_id,))
        prod_conn.execute("INSERT INTO main.chunks SELECT * FROM stg.chunks WHERE doc_id=?", (doc_id,))
        prod_conn.execute(
            "INSERT INTO main.chunks_fts(text, chunk_id) SELECT text, chunk_id FROM stg.chunks WHERE doc_id=?",
            (doc_id,))

        # 4) concepts + formulas — ADDITIVE MERGE: new codes inserted, existing preserved
        #    verbatim (INSERT OR IGNORE ⇒ a baseline concept_code is never overwritten).
        prod_conn.execute(
            "INSERT OR IGNORE INTO main.concepts SELECT * FROM stg.concepts "
            "WHERE json_extract(evidence,'$.doc')=?", (doc_id,))
        prod_conn.execute(
            "INSERT OR IGNORE INTO main.formulas SELECT * FROM stg.formulas "
            "WHERE json_extract(evidence,'$.doc')=?", (doc_id,))

        # 5) per-doc stage ledger (mark processed so production never reprocesses it)
        prod_conn.execute(
            "INSERT OR REPLACE INTO main.stage_ledger SELECT * FROM stg.stage_ledger WHERE doc_id=?", (doc_id,))

        # 6) version lineage (append-only; supersede the prior head, do not delete it)
        _record_version(prod_conn, doc_id, detection, item_id)
        prod_conn.commit()
    except Exception:
        prod_conn.rollback()
        raise
    finally:
        prod_conn.execute("DETACH DATABASE stg")
    return {"doc_id": doc_id, "disposition": detection.get("disposition")}


def _record_version(prod_conn, doc_id: str, detection: dict, item_id: str | None) -> None:
    lineage = detection["lineage_key"]
    vno = detection.get("version_no") or 1
    sha = _sha_of(prod_conn, doc_id)   # sha of the just-copied source row
    prod_conn.execute(
        "INSERT OR IGNORE INTO document_versions"
        "(version_id, lineage_key, doc_id, version_no, sha256, year, source_item, superseded_by, created_at)"
        " VALUES (?,?,?,?,?,?,?,?,?)",
        (f"{lineage}@v{vno}", lineage, doc_id, vno, sha, detection.get("year"), item_id, None, now_iso()),
    )
    # a new version supersedes the prior head (history preserved — the old row stays)
    if detection.get("disposition") == Disposition.NEW_VERSION and detection.get("version_of"):
        prod_conn.execute(
            "UPDATE document_versions SET superseded_by=? WHERE doc_id=? AND superseded_by IS NULL",
            (doc_id, detection["version_of"]))


def _sha_of(prod_conn, doc_id: str) -> str:
    row = prod_conn.execute("SELECT sha256 FROM source_documents WHERE doc_id=?", (doc_id,)).fetchone()
    return row["sha256"] if row else ""


def refresh_derived(prod_conn) -> dict:
    """Knowledge Graph Update + Question Intelligence Update — recompute the two derived
    projections deterministically over the combined corpus. No source doc is re-parsed."""
    graph = phase6_graph.run(prod_conn)
    questions = phase7_questions.run(prod_conn)
    return {"graph": graph, "questions": questions}
