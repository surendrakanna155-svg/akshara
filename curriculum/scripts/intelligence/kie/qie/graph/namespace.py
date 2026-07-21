"""R5-2 [C14] — converge the three live concept ontologies onto the KC_ spine.

Ontologies the audit found (none joinable): (1) KC_ ids in the frozen index, (2) authored "Subject :: topic"
governed-fact codes (`certified_concept_code` empty on all 128), (3) legacy factory codes (incl. OCR-junk like
`PHY_QUESTIONS_ANSWERS`). Mastery / coverage / dedup cannot join across them.

This builds a DERIVED convergence table (`concept_namespace` in graph_edges.db) mapping every non-KC_ source
concept to its KC_ id — reusing R5-1's CONFIRMED multimap resolver (canonical_name + aliases, honest-null on
unresolved/ambiguous). OCR-junk legacy codes are RETIRED (resolved_kc NULL, retired=1) so they can never be
mistaken for a real concept. READ-ONLY over the frozen index + the source stores; writes only graph_edges.db.
No source store is mutated (RI-6: qie.db stays an evidence source; the backfill lives in this derived layer).
"""
from __future__ import annotations

import re
from typing import Dict, List, Optional, Tuple

from kie import config
from kie.qie.graph import store as ST
from kie.qie.graph.prereq_edges import _build_multimaps, _resolve
from kie.qie.inventory import crosswalk as XW

QIE_DB_PATH = config.KIE_HOME / "qie.db"
CORPUS_DB_PATH = config.KIE_HOME / "factory_corpus.db"

# exam-scaffolding words that, ALONE, make up an OCR-junk "concept" code (never a real syllabus concept).
_JUNK_WORDS = {"answer", "answers", "question", "questions", "solution", "solutions"}
_BOILERPLATE = _JUNK_WORDS | {"above", "following", "for", "and", "of", "the", "given", "below", "key",
                              "exercise", "exercises"}
# a SINGLE token that is a junk word repeated with no separator: ANSWERANSWER, ANSWERSANSWERS, SOLUTIONSSOLUTIONS.
_CONCAT_DOUBLE = re.compile(r"^(answers?|questions?|solutions?){2,}$", re.IGNORECASE)


def _is_ocr_junk(code: str) -> bool:
    """OCR-junk = a name-tail with NO real content, only exam scaffolding. Three fail-safe signatures:
      (a) a single token that is a junk word doubled with no separator (ANSWERANSWER);
      (b) two ADJACENT identical junk tokens (SOLUTIONS_SOLUTIONS, ANSWERS_ANSWERS);
      (c) the tail is ENTIRELY boilerplate AND contains a junk word (QUESTIONS_ANSWERS, ANSWERS_FOR_THE_ABOVE).
    Conservative on the OVER-retire side (the dangerous one): any real content token (THEORY, WORK, IMMUNITY,
    SETS) makes the code NOT junk — so 'THE_THEORY_OF_EVOLUTION' is safe (adversarial-verifier Finding 2: the
    old code stripped underscores and matched a manufactured 'THETHEORY' double). NEVER strips separators."""
    if not code:
        return False
    tail = code.split("_", 1)[1] if "_" in code else code
    toks = [t for t in re.split(r"[^a-z]+", tail.lower()) if t]
    if not toks:
        return False
    if any(_CONCAT_DOUBLE.match(t) for t in toks):                       # (a)
        return True
    if any(a == b and a in _JUNK_WORDS for a, b in zip(toks, toks[1:])):  # (b)
        return True
    return all(t in _BOILERPLATE for t in toks) and any(t in _JUNK_WORDS for t in toks)  # (c)


def _code_name(code: str) -> str:
    """The human name buried in a legacy code: REL_OHMS_LAW -> 'ohms law', PHY_WORK_ENERGY -> 'work energy'."""
    tail = code.split("_", 1)[1] if "_" in code else code
    return tail.replace("_", " ")


def build(graph_path=None, index_path=XW.INDEX_DB_PATH, qie_path=QIE_DB_PATH,
          corpus_path=CORPUS_DB_PATH) -> Dict[str, object]:
    """Reconcile governed-fact topics + factory legacy codes onto the KC_ spine. Idempotent. READ-ONLY over the
    frozen index and the source stores; writes only concept_namespace in graph_edges.db."""
    import sqlite3
    from pathlib import Path

    xw_version = XW.build(index_path).version
    idx = XW.open_index_ro(index_path)
    try:
        by_subj, by_norm = _build_multimaps(idx)
        certified_ids = {r[0] for r in idx.execute("SELECT concept_id FROM ki_concept WHERE status='certified'")}
    finally:
        idx.close()

    rows: List[tuple] = []

    # (2) governed-fact topics: resolve the fine-grained topic, else its chapter (nearest certified ancestor).
    if Path(qie_path).exists():
        q = sqlite3.connect(f"file:{qie_path}?mode=ro", uri=True)
        q.row_factory = sqlite3.Row
        try:
            for r in q.execute("SELECT fact_id, subject, topic, concept_candidate FROM governed_fact "
                               "WHERE status='verified'"):
                subject = r["subject"]
                chapter = (r["concept_candidate"] or "").split("::")[-1].strip()
                kc, method = None, "unresolved"
                # record the method TRUTHFULLY: a fine-grained topic hit vs a coarser chapter fallback are
                # different provenance and must not both be stamped 'topic_name' (adversarial-verifier Finding 1).
                for cand_method, cand in (("topic_name", r["topic"]), ("chapter_fallback", chapter)):
                    if not cand:
                        continue
                    rkc, m, _ = _resolve(by_subj, by_norm, subject, XW._norm(cand))
                    if rkc:
                        kc, method = rkc, cand_method
                        break
                    if m == "ambiguous" and method == "unresolved":
                        method = "ambiguous"
                src_code = r["topic"] or r["concept_candidate"]
                rows.append(("governed_fact_topic", r["fact_id"], src_code, subject, kc, method, 0))
        finally:
            q.close()

    # (3) factory legacy codes: retire OCR-junk; else resolve the code's name-tail (subject from the spec).
    if Path(corpus_path).exists():
        fc = sqlite3.connect(f"file:{corpus_path}?mode=ro", uri=True)
        fc.row_factory = sqlite3.Row
        try:
            seen = set()
            for r in fc.execute("SELECT DISTINCT concept_code, subject FROM generation_spec "
                                "WHERE concept_code IS NOT NULL"):
                code = r["concept_code"]
                if code in seen:
                    continue
                seen.add(code)
                if str(code).startswith("KC_"):
                    # a KC_-prefixed code is only 'resolved' if it is a REAL certified concept; a bogus KC_ id
                    # is honest-null, not a phantom passthrough (adversarial-verifier Finding 4).
                    if code in certified_ids:
                        rows.append(("factory_legacy_code", code, code, r["subject"], code, "already_kc", 0))
                    else:
                        rows.append(("factory_legacy_code", code, code, r["subject"], None, "unknown_kc", 0))
                    continue
                if _is_ocr_junk(code):
                    rows.append(("factory_legacy_code", code, code, r["subject"], None, "ocr_junk_retired", 1))
                    continue
                kc, method, _ = _resolve(by_subj, by_norm, r["subject"], XW._norm(_code_name(code)))
                rows.append(("factory_legacy_code", code, code, r["subject"], kc,
                             method if kc else ("ambiguous" if method == "ambiguous" else "unresolved"), 0))
        finally:
            fc.close()

    conn = ST.open_store(graph_path, writable=True)
    try:
        conn.execute("DELETE FROM concept_namespace")
        conn.executemany(
            "INSERT OR REPLACE INTO concept_namespace (src_ontology, src_id, src_code, subject, resolved_kc, "
            "method, retired) VALUES (?,?,?,?,?,?,?)", rows)
        conn.execute("INSERT INTO prereq_meta(key, value) VALUES ('namespace_crosswalk_version', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (xw_version,))
        conn.commit()
    finally:
        conn.close()
    return _summary(rows, xw_version)


def _summary(rows: List[tuple], version: str) -> Dict[str, object]:
    out: Dict[str, Dict[str, int]] = {}
    for ont, _sid, _sc, _subj, kc, method, retired in rows:
        b = out.setdefault(ont, {"total": 0, "resolved": 0, "retired": 0, "honest_null": 0})
        b["total"] += 1
        if retired:
            b["retired"] += 1
        elif kc is not None:
            b["resolved"] += 1
        else:
            b["honest_null"] += 1
    for ont, b in out.items():
        b["resolution_rate"] = round(b["resolved"] / b["total"], 4) if b["total"] else 0.0
    return {"by_ontology": out, "crosswalk_version": version, "total": len(rows),
            "note": "unresolved/ambiguous are honest-null; OCR-junk legacy codes are RETIRED (never a concept)."}


# ── query helpers ─────────────────────────────────────────────────────────────────────────────────────
def resolve_to_kc(src_ontology: str, src_id: str, graph_path=None) -> Optional[str]:
    conn = ST.open_store(graph_path, writable=False)
    try:
        r = conn.execute("SELECT resolved_kc FROM concept_namespace WHERE src_ontology=? AND src_id=?",
                         (src_ontology, src_id)).fetchone()
        return r[0] if r else None
    finally:
        conn.close()


def convergence_report(graph_path=None) -> Dict[str, object]:
    conn = ST.open_store(graph_path, writable=False)
    try:
        by = {}
        for r in conn.execute("SELECT src_ontology, method, COUNT(*) n FROM concept_namespace "
                              "GROUP BY src_ontology, method ORDER BY 1, 3 DESC"):
            by.setdefault(r["src_ontology"], {})[r["method"]] = r["n"]
        retired = conn.execute("SELECT COUNT(*) FROM concept_namespace WHERE retired=1").fetchone()[0]
        return {"by_ontology_method": by, "retired_total": retired}
    finally:
        conn.close()


if __name__ == "__main__":
    import json
    print(json.dumps(build(), indent=2))
