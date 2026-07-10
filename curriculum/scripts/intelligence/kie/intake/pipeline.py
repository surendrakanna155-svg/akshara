"""Staging pipeline — runs the EXISTING deterministic phases 2-7 on an ISOLATED staging
store, so a batch's extracted knowledge can be reviewed before it ever touches production.

Zero duplication: the parser, metadata engine, chunker, concept extractor, knowledge graph
and question intelligence are the frozen kie.phaseN components — invoked here only with a
staging connection + the managed intake workspace. Nothing about Phases 1-7 is reimplemented.
"""
from __future__ import annotations

import re
import shutil
from pathlib import Path
from typing import List, Optional

from kie import (config, ledger, phase1_verify, phase2_parse, phase3_metadata,
                 phase4_chunk, phase5_concept, phase6_graph, phase7_questions)
from kie.intake.models import ItemStats, ReviewStatus

_SAFE = re.compile(r"[^A-Za-z0-9._-]+")

# per-doc phases (incremental, ledger-gated) then the two GLOBAL derived refreshes
PER_DOC_PHASES = ("parse", "metadata", "chunk", "concept")
DERIVED_PHASES = ("graph", "questions")

LOW_OCR_CONFIDENCE = 60.0


def safe_name(name: str) -> str:
    return _SAFE.sub("_", Path(name).name).strip("._") or "file"


def stage_resource(source_abs: Path, doc_id: str, name: str, intake_ws: Path) -> str:
    """Copy a raw input into the managed, content-addressed intake tree.

    Returns the rel_path under corpus 'intake' (which phase2 resolves via workspace=intake_ws).
    Content-addressed by doc_id, so re-staging identical content is idempotent.
    """
    rel = f"{doc_id}/{safe_name(name)}"
    dest = Path(intake_ws) / config.CORPORA["intake"] / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists():
        shutil.copyfile(str(source_abs), str(dest))
    return rel


def ingest_to_staging(staging_conn, verdict: dict, rel_path: str, category: str) -> str:
    """Register one verified document into the staging store (source_documents + verify
    ledger), reusing phase1_verify.ingest_entry. Returns the certify_status."""
    entry = {
        "path": rel_path,
        "category": category,
        "kind": verdict.get("kind"),
        "bytes": verdict.get("bytes"),
        "pages": verdict.get("pages"),
        "sha256": verdict["sha256"],
        "integrity_ok": verdict.get("integrity_ok", False),
        "corruption_reason": verdict.get("corruption_reason"),
        "encrypted": verdict.get("encrypted", False),
        "parser_class": verdict.get("parser_class"),
        "parser_strategy": verdict.get("parser_strategy"),
        "is_duplicate": False,      # dedup already decided upstream; staging holds unique content
        "duplicate_of": None,
    }
    return phase1_verify.ingest_entry(staging_conn, "intake", entry)


def run_phases(staging_conn, intake_ws: Path) -> dict:
    """Run parse → metadata → chunk → concept (per-doc, ledger-incremental) then graph →
    questions (global, over the staging content only). Returns per-phase summaries.

    Because the staging store contains ONLY this batch's documents, the per-doc phases
    process exactly those docs — the immutable 360-doc baseline is never seen here.
    """
    summaries = {}
    summaries["parse"] = phase2_parse.run(staging_conn, workspace=Path(intake_ws))
    summaries["metadata"] = phase3_metadata.run(staging_conn)
    summaries["chunk"] = phase4_chunk.run(staging_conn)
    summaries["concept"] = phase5_concept.run(staging_conn)
    summaries["graph"] = phase6_graph.run(staging_conn)
    summaries["questions"] = phase7_questions.run(staging_conn)
    return summaries


# ── per-document review signals read back from the staging store ───────────────────
def staged_stats(conn, doc_id: str) -> ItemStats:
    """Knowledge this document yielded (chunks/sections exact; concepts/formulas by the doc
    that introduced them; patterns via that doc's concepts)."""
    def one(sql, *a):
        return conn.execute(sql, a).fetchone()["n"]
    return ItemStats(
        chunks=one("SELECT COUNT(*) n FROM chunks WHERE doc_id=?", doc_id),
        sections=one("SELECT COUNT(*) n FROM document_sections WHERE doc_id=?", doc_id),
        concepts=one("SELECT COUNT(*) n FROM concepts WHERE json_extract(evidence,'$.doc')=?", doc_id),
        formulas=one("SELECT COUNT(*) n FROM formulas WHERE json_extract(evidence,'$.doc')=?", doc_id),
        patterns=one(
            "SELECT COUNT(*) n FROM question_patterns WHERE concept_code IN "
            "(SELECT concept_code FROM concepts WHERE json_extract(evidence,'$.doc')=?)", doc_id),
    )


def staged_flags(conn, doc_id: str) -> List[str]:
    """Auto review-flags: parse failure, low OCR confidence, no chunks, no concepts."""
    flags: List[str] = []
    status, _ = ledger.get(conn, doc_id, "parse")
    if status == "failed":
        flags.append("parse_failed")
    row = conn.execute("SELECT confidence FROM parsed_documents WHERE doc_id=?", (doc_id,)).fetchone()
    if row and row["confidence"] is not None and row["confidence"] < LOW_OCR_CONFIDENCE:
        flags.append("low_ocr")
    if conn.execute("SELECT COUNT(*) n FROM chunks WHERE doc_id=?", (doc_id,)).fetchone()["n"] == 0:
        flags.append("no_chunks")
    if conn.execute(
        "SELECT COUNT(*) n FROM concepts WHERE json_extract(evidence,'$.doc')=?", (doc_id,)
    ).fetchone()["n"] == 0:
        flags.append("no_concepts")
    return flags


def review_status_for(flags: List[str]) -> str:
    """Clean extraction → PENDING; anything flagged is routed to NEEDS_REVIEW."""
    return ReviewStatus.NEEDS_REVIEW if flags else ReviewStatus.PENDING


def sample_concepts(conn, doc_id: str, limit: int = 12) -> List[str]:
    """A few concept titles this document introduced, for the review preview."""
    return [
        r["title"]
        for r in conn.execute(
            "SELECT title FROM concepts WHERE json_extract(evidence,'$.doc')=? ORDER BY title LIMIT ?",
            (doc_id, limit),
        ).fetchall()
    ]
