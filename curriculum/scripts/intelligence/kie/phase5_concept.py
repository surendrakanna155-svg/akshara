"""Phase 5 — Concept Extraction. Deterministic concept mining (AI hook wired, GATED).

Rule 2 (Concept Before Question): concepts are the permanent spine. This phase
mines concept CANDIDATES from the certified corpus with NO AI:
  * section-title concepts — chapter/topic headings (Phase 3) are concept nodes;
  * definitional concepts — "<Term> is/are defined as ..." sentences in chunks;
  * named laws/theorems/principles — folded into formulas + concept.reference_facts.

Concepts are global and keyed by a deterministic slug code (SUBJ_SLUG), so the
same concept seen across many documents merges (evidence accumulates). Rows mirror
canonical_concepts for clean Intake-Center promotion.

The AI enrichment hook (ai_enrich_concept) is present but GATED: it raises unless
KIE_AI_AUTHORIZED=1 (which only becomes true under the P3-AI governed runtime).
The deterministic path never calls it.
"""
from __future__ import annotations

import json
import os
import re
from typing import Dict, List, Optional, Tuple

from kie import config, ledger, store

SUBJ3 = {"Physics": "PHY", "Chemistry": "CHE", "Mathematics": "MAT", "Biology": "BIO"}

_ALPHA = re.compile(r"[A-Za-z]+")
_SLUG = re.compile(r"[^A-Z0-9]+")
_DATE = re.compile(r"\b(19|20)\d{2}\b")
_NOISE = re.compile(
    r"shift|careers?360|allen|resonance|www\.|https?:|\.com|page\s*\d|marking scheme|"
    r"sample\s+(?:test\s+)?paper|test\s+paper|question\s+paper|mock\s+test|answer\s+key|solution|"
    r"national testing agency|batch|advertisement|directors team|kotacrack|achiever|academy|"
    r"institute|toppers|rank\s+booster|coaching|enrol|registration|"
    r"section\s+[a-e]\b|part\s+[a-e]\b",
    re.I,
)
# bare subject / organizational markers are structure, not concepts
_SUBJECT_MARKER = {
    "physics", "chemistry", "biology", "botany", "zoology", "mathematics", "maths",
    "science", "general knowledge", "reasoning", "aptitude",
}
# equation-ish symbols, or alphanumeric-garble tokens (e.g. 12dBk, AkB0dt, 0lim) that
# leak in when heading detection fires on math fragments in exam papers.
_MATHY = re.compile(r"[=+*/^_→←↔∫∑√±×÷<>{}\\|]|[A-Za-z]\d|\d[A-Za-z]")
_DEF = re.compile(
    r"\b([A-Z][A-Za-z][A-Za-z'\- ]{2,45}?)\s+(?:is|are)\s+defined\s+as\s+(.{6,220}?)(?:\.|\n|$)"
)
_LAW = re.compile(
    r"\b([A-Z][A-Za-z'’\-]+(?:\s+[A-Za-z]+){0,3}?\s+(law|theorem|principle|rule))\b"
)
_LEAD_NUM = re.compile(r"^\d+(?:\.\d+)*\.?\s+")
# common sentence-initial words that must NOT be read as the name of a law/principle
_LAW_STOP = {
    "the", "this", "that", "so", "from", "by", "and", "but", "some", "an", "in", "on",
    "of", "for", "we", "it", "its", "then", "thus", "hence", "also", "now", "here",
    "these", "those", "such", "all", "each", "every", "no", "not", "a", "as", "if",
    "using", "applying", "consider", "let", "according",
    "can", "does", "do", "will", "would", "could", "should", "is", "are", "was",
    "were", "has", "have", "may", "might", "when", "where", "which", "what", "why",
    "state", "define", "explain", "prove", "find", "given",
}


# ── gated AI hook (wired, OFF) ───────────────────────────────────────────────────
class AiGatedError(RuntimeError):
    pass


def ai_available() -> bool:
    return os.environ.get("KIE_AI_AUTHORIZED") == "1"


def ai_enrich_concept(chunk_text: str):  # pragma: no cover - gated
    """Offline, small-chunk AI enrichment — GATED behind the P3-AI runtime."""
    if not ai_available():
        raise AiGatedError(
            "Phase-5 AI concept enrichment is gated; it runs only inside the P3-AI "
            "governed runtime (set KIE_AI_AUTHORIZED=1 once that is authorized)."
        )
    raise NotImplementedError("AI enrichment runtime not implemented (Phase 8 gate).")


# ── deterministic helpers ────────────────────────────────────────────────────────
def concept_code(subject: Optional[str], title: str) -> str:
    prefix = SUBJ3.get(subject or "", "GEN")
    slug = _SLUG.sub("_", title.upper()).strip("_")[:32].strip("_")
    return f"{prefix}_{slug}" if slug else f"{prefix}_UNNAMED"


def is_concept_title(title: str) -> bool:
    t = title.strip()
    words = t.split()
    if not (1 <= len(words) <= 8):
        return False
    alpha_words = [w for w in _ALPHA.findall(t) if len(w) >= 3]
    if len(alpha_words) < 1:
        return False
    if _DATE.search(t) or _NOISE.search(t) or _MATHY.search(t):
        return False
    if t.lower() in _SUBJECT_MARKER:
        return False
    letters = sum(c.isalpha() for c in t)
    digits = sum(c.isdigit() for c in t)
    if letters < 6 or digits > letters * 0.3:
        return False
    # ≥ 60% of tokens must be dictionary-shaped words (all-alpha, ≥3 chars)
    if sum(1 for w in words if w.isalpha() and len(w) >= 3) < max(1, len(words) * 0.6):
        return False
    return True


def extract_definitions(text: str) -> List[Tuple[str, str]]:
    out, seen = [], set()
    for m in _DEF.finditer(text):
        term = re.sub(r"\s+", " ", m.group(1).strip())
        definition = re.sub(r"\s+", " ", m.group(2).strip())
        key = term.lower()
        if len(term) < 3 or key in seen:
            continue
        seen.add(key)
        out.append((term, definition))
    return out


def extract_named_laws(text: str) -> List[Tuple[str, str]]:
    out, seen = [], set()
    for m in _LAW.finditer(text):
        name = re.sub(r"\s+", " ", m.group(1).strip())
        kind = m.group(2).lower()
        key = name.lower()
        if key in seen or name.split()[0].lower() in _LAW_STOP:
            continue
        seen.add(key)
        out.append((name, kind))
    return out


# ── persistence ──────────────────────────────────────────────────────────────────
def _upsert_concept(conn, code, title, subject, definition, method, did):
    ev = json.dumps({"method": method, "doc": did}, sort_keys=True)
    conn.execute(
        """INSERT INTO concepts(concept_code, title, definition, subject_domain, status, evidence, created_at)
           VALUES (?,?,?,?, 'active', ?, datetime('now'))
           ON CONFLICT(concept_code) DO UPDATE SET
             definition = COALESCE(NULLIF(concepts.definition, ''), excluded.definition),
             subject_domain = COALESCE(concepts.subject_domain, excluded.subject_domain)""",
        (code, title, definition or "", subject, ev),
    )


def _insert_formula(conn, code_concept, name, kind, did):
    import hashlib
    fid = "F_" + hashlib.sha256(f"{kind}:{name.lower()}".encode()).hexdigest()[:16]
    conn.execute(
        """INSERT INTO formulas(formula_id, concept_code, kind, expression, symbols, evidence)
           VALUES (?,?,?,?,?,?)
           ON CONFLICT(formula_id) DO NOTHING""",
        (fid, code_concept, kind, name, None, json.dumps({"doc": did}, sort_keys=True)),
    )


def process_document(conn, doc_row) -> dict:
    did = doc_row["doc_id"]
    subject = doc_row["subject"]
    stats = {"section_concepts": 0, "definition_concepts": 0, "laws": 0}

    with store.txn(conn):
        # 1. section-title concepts (strip leading "3.2 " numbering first)
        for (raw_title,) in conn.execute(
            "SELECT DISTINCT title FROM document_sections WHERE doc_id = ? ORDER BY title", (did,)
        ).fetchall():
            title = _LEAD_NUM.sub("", raw_title).strip()
            if not is_concept_title(title):
                continue
            _upsert_concept(conn, concept_code(subject, title), title, subject, "", "section_title", did)
            stats["section_concepts"] += 1

        # 2. definitions + 3. named laws over this doc's chunk text
        text = "\n".join(
            r["text"] for r in conn.execute(
                "SELECT text FROM chunks WHERE doc_id = ? ORDER BY ordinal", (did,)
            ).fetchall()
        )
        for term, definition in extract_definitions(text):
            _upsert_concept(conn, concept_code(subject, term), term, subject, definition, "definition", did)
            stats["definition_concepts"] += 1
        for name, kind in extract_named_laws(text):
            code = concept_code(subject, name)
            _upsert_concept(conn, code, name, subject, "", f"named_{kind}", did)
            _insert_formula(conn, code, name, kind, did)
            stats["laws"] += 1

        ledger.record(conn, did, "concept", "done", input_sha256=doc_row["sha256"],
                      output_ref=json.dumps(stats, sort_keys=True))
    return stats


def run(conn, limit: Optional[int] = None, force: bool = False) -> dict:
    summary = {"processed": 0, "skipped": 0, "failed": 0}
    # Concepts/formulas are GLOBAL derived aggregates — a forced full run rebuilds
    # them from scratch so stale candidates from an earlier heuristic don't linger.
    if force and not limit:
        with store.txn(conn):
            # delete concept-dependent derived tables first (FK order); the graph
            # (Phase 6) must be rebuilt after a concept-layer rebuild anyway.
            for tbl in ("concept_edges", "concept_board_mappings", "formulas", "concepts"):
                conn.execute(f"DELETE FROM {tbl}")
    rows = conn.execute(
        "SELECT DISTINCT s.* FROM source_documents s "
        "JOIN chunks c ON c.doc_id = s.doc_id WHERE s.certify_status = 'certified' ORDER BY s.doc_id"
    ).fetchall()
    for doc_row in rows:
        if limit and summary["processed"] >= limit:
            break
        did = doc_row["doc_id"]
        if not ledger.needs_run(conn, did, "concept", doc_row["sha256"], force=force):
            summary["skipped"] += 1
            continue
        try:
            process_document(conn, doc_row)
        except Exception as exc:
            ledger.record(conn, did, "concept", "failed", input_sha256=doc_row["sha256"],
                          error=f"{type(exc).__name__}: {exc}")
            conn.commit()
            summary["failed"] += 1
            continue
        summary["processed"] += 1
    summary["concepts_total"] = conn.execute("SELECT COUNT(*) n FROM concepts").fetchone()["n"]
    summary["formulas_total"] = conn.execute("SELECT COUNT(*) n FROM formulas").fetchone()["n"]
    return summary
