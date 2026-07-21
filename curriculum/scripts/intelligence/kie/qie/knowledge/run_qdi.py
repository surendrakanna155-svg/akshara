"""QDI design-pattern mining + certification driver (governed; Owner Decision 5).

AI PROPOSES (analyst) -> DETERMINISTIC FLOOR (anti-copying + structural, MANDATORY) -> INDEPENDENT AUDIT (a
SEPARATE model judges design-validity) -> CERTIFY (floor passed AND auditor accepted). Certified patterns live
in a SEPARATE `qdi.db`; the frozen knowledge_index.db is NEVER written. The planner reads certified patterns
from qdi.db and attaches design DNA to blueprints, scoped by exam profile.
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Dict, List

from kie import config
from kie.qie import store_open as SO
from kie.qie.archetypes import ARCHETYPES
from kie.qie.knowledge import qdi as QDI
from kie.qie.knowledge import qdi_link as QL

QDI_DB_PATH = config.KIE_HOME / "qdi.db"
INDEX_DB_PATH = config.KIE_HOME / "knowledge_index.db"
KIE_DB_PATH = config.DB_PATH  # kie.db owned source chunks

_PATTERN_COLS = ("pattern_id", "exam", "subject", "archetype", "pattern_name", "design_summary",
                 "concept_roles", "composition_kind", "dependency", "reasoning_chain", "step_depth",
                 "operators", "constraints", "difficulty_mechanism", "transformation", "difficulty_band",
                 "distractor_structure", "misconceptions", "visual_archetype", "visual_necessity",
                 "solution_structure", "evidence_refs", "evidence_count", "analyst_model", "audit_verdict",
                 "audit_reasons", "audit_model", "status", "created_at")

_JSON_FIELDS = ("reasoning_chain", "difficulty_mechanism", "operators", "constraints",
                "distractor_structure", "solution_structure", "misconceptions")


def open_store(path=None) -> sqlite3.Connection:
    # R3-4 (#database-9): route through the shared derived-store opener for row_factory + foreign_keys ON +
    # the standardized WAL journal_mode (qdi.db was previously left on the sqlite default `delete`) + the R0-4
    # path guard. Writable open; the QDI schema/migration is applied on top.
    conn = SO.open_store(path or QDI_DB_PATH, read_only=False)
    QDI.open_qdi(conn)
    return conn


def open_index_ro():
    conn = sqlite3.connect(f"file:{INDEX_DB_PATH}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def open_kie_ro():
    conn = sqlite3.connect(f"file:{KIE_DB_PATH}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def import_proposed_from_index(qconn: sqlite3.Connection, index_conn: sqlite3.Connection) -> int:
    """Copy prior analyst-proposed patterns out of the FROZEN index into the writable qdi.db, reset to
    'proposed' (they get re-run through the current deterministic floor + a fresh independent audit).

    Routed through the SAFE accessor (R1-5, cross-lane): a sanctioned v1.5+ freeze DROPs the legacy qdi_*
    tables from the index, so a raw SELECT would raise OperationalError; the accessor returns [] instead."""
    from kie.qie.knowledge import schema as S
    rows = S.legacy_qdi_proposed_from_index(index_conn)
    for r in rows:
        d = {c: (r[c] if c in r.keys() else None) for c in _PATTERN_COLS}
        d["status"], d["audit_verdict"], d["audit_reasons"], d["audit_model"] = "proposed", None, None, None
        qconn.execute(f"INSERT OR REPLACE INTO qdi_pattern ({','.join(_PATTERN_COLS)}) "
                      f"VALUES ({','.join('?' * len(_PATTERN_COLS))})", tuple(d[c] for c in _PATTERN_COLS))
    qconn.commit()
    return len(rows)


def _source_text(kconn: sqlite3.Connection, evidence_refs, limit: int = 6) -> str:
    refs = evidence_refs if isinstance(evidence_refs, list) else json.loads(evidence_refs or "[]")
    src = ""
    for ref in refs[:limit]:
        row = kconn.execute("SELECT text FROM chunks WHERE chunk_id=?", (ref.get("chunk_id"),)).fetchone()
        if row:
            src += " " + (row[0] or "")
    return src


def deterministic_floor(qconn: sqlite3.Connection, kconn: sqlite3.Connection) -> Dict[str, int]:
    """MANDATORY pre-audit gate (R1-3 hardened): re-run structural validity, anti-copying, AND the
    exam+subject PROVENANCE INVARIANT on every proposed pattern. Any failure is QUARANTINED so it can never
    be certified. FAIL CLOSED: if a pattern's evidence cannot be fetched, the anti-copy/provenance checks are
    unverifiable, so the pattern is quarantined (never silently skipped). Only a genuine, fully-verified pass
    STAMPS `floor_passed_at` (+ provenance_verified=1) — the marker that `ingest_qdi_audit` requires before it
    may certify anything."""
    m = {"passed": 0, "quarantined_copying": 0, "quarantined_structural": 0,
         "quarantined_unfetchable": 0, "quarantined_provenance": 0}
    rows = qconn.execute("SELECT pattern_id, exam, subject, design_summary, pattern_name, reasoning_chain, "
                         "difficulty_mechanism, operators, constraints, distractor_structure, "
                         "solution_structure, misconceptions, evidence_refs FROM qdi_pattern "
                         "WHERE status='proposed'").fetchall()
    for r in rows:
        if len((r["design_summary"] or "").strip()) < 20:
            qconn.execute("UPDATE qdi_pattern SET status='quarantined', audit_reasons=? WHERE pattern_id=?",
                          ("floor: empty/short design_summary", r["pattern_id"]))
            m["quarantined_structural"] += 1
            continue
        p = {"design_summary": r["design_summary"], "pattern_name": r["pattern_name"],
             "exam": r["exam"], "subject": r["subject"], "evidence_refs": r["evidence_refs"]}
        for j in _JSON_FIELDS:
            try:
                p[j] = json.loads(r[j] or "[]")
            except Exception:
                p[j] = []
        # FAIL CLOSED: unfetchable evidence means anti-copy/provenance cannot be verified — quarantine.
        src = _source_text(kconn, r["evidence_refs"])
        if not src.strip():
            qconn.execute("UPDATE qdi_pattern SET status='quarantined', audit_reasons=? WHERE pattern_id=?",
                          ("floor: evidence unfetchable — cannot verify anti-copy/provenance (fail-closed)",
                           r["pattern_id"]))
            m["quarantined_unfetchable"] += 1
            continue
        why = QDI.assert_no_copying(p, src)
        if why:
            qconn.execute("UPDATE qdi_pattern SET status='quarantined', audit_reasons=? WHERE pattern_id=?",
                          (f"floor: {why}", r["pattern_id"]))
            m["quarantined_copying"] += 1
            continue
        # PROVENANCE INVARIANT: pattern.exam+subject must hold for every evidence doc (canonical exam +
        # section-resolved subject). This is what recalls the 7 mis-provenanced pre-fix patterns.
        pv = QDI.assert_provenance(kconn, p)
        if pv:
            qconn.execute("UPDATE qdi_pattern SET status='quarantined', audit_reasons=? WHERE pattern_id=?",
                          (f"floor: {pv}", r["pattern_id"]))
            m["quarantined_provenance"] += 1
            continue
        # genuine pass: stamp the marker the certification gate requires
        qconn.execute("UPDATE qdi_pattern SET floor_passed_at=?, provenance_verified=1 WHERE pattern_id=?",
                      (QDI._now(), r["pattern_id"]))
        m["passed"] += 1
    qconn.commit()
    return m


# ── mining (analyst) ──────────────────────────────────────────────────────────────────────────────
def analyst_worksheet(kconn: sqlite3.Connection, exam: str, subject: str, path: str,
                      n_docs: int = 16, n_chunks: int = 40) -> int:
    # exam_sources returns ALL exam docs (subject is a section property); candidate_chunks(subject=...) keeps
    # only the requested subject's chunks -> pull from a wider doc pool to find enough real subject chunks.
    srcs = QDI.exam_sources(kconn, exams=(exam,))
    doc_ids = [s["doc_id"] for s in srcs][:n_docs]
    chunks = QDI.candidate_chunks(kconn, doc_ids, subject=subject, limit=n_chunks)
    return QDI.write_analyst_worksheet(kconn, chunks, path, ARCHETYPES)


def ingest_analyst(qconn: sqlite3.Connection, kconn: sqlite3.Connection, payload: dict, exam: str,
                   subject: str, model: str = "analyst-agent") -> Dict[str, int]:
    """Runs the deterministic anti-copying gate as it stores; only clean patterns land as 'proposed'."""
    return QDI.ingest_patterns(qconn, kconn, payload, exam, subject, model)


# ── audit ─────────────────────────────────────────────────────────────────────────────────────────
def audit_worksheet(qconn: sqlite3.Connection, exam: str, subject: str, path: str) -> int:
    return QDI.write_qdi_audit_worksheet(qconn, path, exam, subject)


def proposed_cells(qconn: sqlite3.Connection) -> List[tuple]:
    return [tuple(r) for r in qconn.execute(
        "SELECT exam, subject, COUNT(*) FROM qdi_pattern WHERE status='proposed' GROUP BY exam, subject")]


def ingest_audit(qconn: sqlite3.Connection, payload: List[dict], model: str = "auditor-agent") -> Dict[str, int]:
    return QDI.ingest_qdi_audit(qconn, payload, model)


def scope_link_certified(qconn: sqlite3.Connection) -> int:
    """Deterministically populate qdi_scope_link for every certified pattern (legal exam profile + min class)."""
    n = 0
    for r in qconn.execute("SELECT pattern_id, exam, subject FROM qdi_pattern WHERE status='certified'"):
        link = QL.scope_link_for({"pattern_id": r["pattern_id"], "exam": r["exam"], "subject": r["subject"]})
        if QL.validate_scope_link(link) is None:
            qconn.execute("INSERT OR REPLACE INTO qdi_scope_link (pattern_id, subject, min_class, "
                          "exam_profile, basis) VALUES (?,?,?,?,?)",
                          (link["pattern_id"], r["subject"], link["min_class"], link["exam_profile"],
                           link["basis"]))
            n += 1
    qconn.commit()
    return n


def certified_patterns_for_exam(qconn: sqlite3.Connection, exam_profile: str, subject: str) -> List[dict]:
    """Certified patterns legal for this exam profile + subject (via qdi_scope_link). The planner's reader."""
    q = ("SELECT p.* FROM qdi_pattern p JOIN qdi_scope_link s ON s.pattern_id=p.pattern_id "
         "WHERE p.status='certified' AND s.exam_profile=? AND p.subject=? ORDER BY p.pattern_id")
    out = []
    for r in qconn.execute(q, (exam_profile, subject)):
        d = {k: r[k] for k in r.keys()}
        for j in ("concept_roles", "reasoning_chain", "operators", "constraints", "difficulty_mechanism",
                  "transformation", "distractor_structure", "solution_structure", "misconceptions"):
            try:
                d[j] = json.loads(d[j] or "[]")
            except Exception:
                pass
        out.append(d)
    return out


def backfill_sources(qconn: sqlite3.Connection, kconn: sqlite3.Connection) -> Dict[str, int]:
    """R1-3 one-shot repair for EXISTING qdi.db rows: backfill each pattern's evidence-ref doc_id, populate
    the (previously-empty) qdi_source provenance table, and recompute evidence_count/evidence_resource_count
    from the actual refs (never the analyst's asserted number). Does NOT change any pattern's status."""
    m = {"patterns": 0, "sources": 0}
    rows = qconn.execute("SELECT pattern_id, evidence_refs FROM qdi_pattern").fetchall()
    for r in rows:
        try:
            refs = json.loads(r["evidence_refs"] or "[]")
        except Exception:
            refs = []
        for ref in refs:
            if not ref.get("doc_id"):
                did = QDI.ref_doc_id(kconn, ref)
                if did:
                    ref["doc_id"] = did
        m["sources"] += QDI.save_ref_sources(qconn, kconn, refs)
        n_items = len(refs)
        n_res = len({ref.get("doc_id") for ref in refs if ref.get("doc_id")})
        qconn.execute("UPDATE qdi_pattern SET evidence_refs=?, evidence_count=?, evidence_resource_count=? "
                      "WHERE pattern_id=?", (json.dumps(refs), n_items, n_res, r["pattern_id"]))
        m["patterns"] += 1
    qconn.commit()
    return m


def summary(qconn: sqlite3.Connection) -> dict:
    return {
        "by_status": {r[0]: r[1] for r in qconn.execute("SELECT status, COUNT(*) FROM qdi_pattern GROUP BY status")},
        "certified_by_cell": [tuple(r) for r in qconn.execute(
            "SELECT exam, subject, COUNT(*) FROM qdi_pattern WHERE status='certified' GROUP BY exam, subject")],
        "scope_links": qconn.execute("SELECT COUNT(*) FROM qdi_scope_link").fetchone()[0],
    }
