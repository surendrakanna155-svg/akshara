"""Program B · B5 — measured Exam DNA v2 (roadmap R5-4).

The MEASURED layer, derived from the re-mined PYQ corpus (B3 `pyq_item` + B4 `pyq_item_difficulty`), in Program
B's OWN store (`pyq_corpus.db`) so `examdna.db` v1 is left BYTE-IDENTICAL (OD-6) — v2 supersedes by versioning,
never mutating v1.

INDEPENDENCE IS THE UNIT (the load-bearing honesty point). OD-5 requires "30 INDEPENDENT PYQs". One exam SITTING
(exam, year) is often present as many PDFs — different booklet codes / shifts of the SAME questions — which are
NOT independent samples. So the floor and the normalization key on the distinct **sitting** (exam, year), not on
raw `doc_id`s: a distribution is averaged over sittings (each sitting first averaged over its own docs, each doc
over its items), so neither within-doc booklet instances NOR cross-doc booklet PDFs of the same sitting can
distort it. A dimension is measured (`pyq_measured` for observed question-type; `structural_proxy` for B4's
difficulty — never "measured student difficulty", OD-3) ONLY when the exam has **≥ 30 distinct sittings**; below
that it is honest-null **`insufficient_evidence`** (probability NULL — never fabricated). Subject weight stays
**`published`** (the exam mandates its subject split). Measured student difficulty stays honest-null (R5-5).
"""
from __future__ import annotations

import json
from collections import Counter, defaultdict
from datetime import datetime, timezone
from typing import Dict, List, Tuple

from kie.qie.knowledge import examdna as ED   # read-only: reuse v1's published weights + curated priors (constants)
from kie.qie.pyq import store as ST

VERSION = "v2"
FLOOR = 30   # OD-5: a measured cell needs ≥ 30 INDEPENDENT sittings (not raw booklet/shift PDFs)


def _sitting_key(exam: str, doc_id: str, year) -> str:
    """The independent-sitting identity: (exam, year). A doc with no resolved year cannot be proven a duplicate,
    so it stands as its own sitting (the permissive direction — but every exam is far below the floor regardless)."""
    return f"{exam}:{year}" if year is not None else f"{exam}:doc:{doc_id}"


def _per_sitting_normalized(rows: List[Tuple[str, str, str]]) -> Tuple[Dict[str, float], int, int, int]:
    """(avg_props, n_sittings, n_docs, n_items) from (sitting, doc_id, bucket). Averaged sitting→doc→item so a
    sitting present as many booklet PDFs, and a doc holding many booklet instances, each count once."""
    by_sitting_doc: Dict[str, Dict[str, Counter]] = defaultdict(lambda: defaultdict(Counter))
    n_items = 0
    for sitting, doc, bucket in rows:
        by_sitting_doc[sitting][doc][bucket] += 1
        n_items += 1
    docs = set()
    sitting_props: List[Dict[str, float]] = []
    for docmap in by_sitting_doc.values():
        doc_props: List[Dict[str, float]] = []
        for doc, counts in docmap.items():
            docs.add(doc)
            tot = sum(counts.values())
            if tot:
                doc_props.append({b: c / tot for b, c in counts.items()})
        s_avg: Dict[str, float] = defaultdict(float)
        for dp in doc_props:
            for b, p in dp.items():
                s_avg[b] += p
        if doc_props:
            sitting_props.append({b: v / len(doc_props) for b, v in s_avg.items()})
    avg: Dict[str, float] = defaultdict(float)
    for sp in sitting_props:
        for b, p in sp.items():
            avg[b] += p
    ns = len(sitting_props)
    dist = {b: round(v / ns, 6) for b, v in avg.items()} if ns else {}
    return dist, ns, len(docs), n_items


def build(pyq_db_path=None) -> Dict[str, object]:
    """Build the measured Exam DNA v2 in pyq_corpus.db. Reads B3+B4; NEVER touches examdna.db (v1 byte-identical).
    Deterministic + idempotent."""
    conn = ST.open_store(pyq_db_path, writable=True)
    try:
        year_of = {r[0]: r[1] for r in conn.execute(
            "SELECT doc_id, year_resolved FROM pyq_source_class WHERE eligible_for_dna=1")}
        items = conn.execute("SELECT doc_id, exam, question_type FROM pyq_item").fetchall()
        diffs = conn.execute("SELECT p.doc_id, p.exam, d.difficulty_label FROM pyq_item p "
                             "JOIN pyq_item_difficulty d ON d.item_id=p.item_id").fetchall()
    finally:
        conn.close()

    now = datetime.now(timezone.utc).isoformat()
    rows: List[tuple] = []
    deltas: List[tuple] = []
    coverage: Dict[str, Dict[str, str]] = {}

    def cells_for(exam, dimension, triples, measured_prov, v1_prior=None):
        dist, ns, nd, ni = _per_sitting_normalized(triples)
        coverage.setdefault(exam, {})
        if ns >= FLOOR:
            coverage[exam][dimension] = f"{measured_prov} ({ns} sittings)"
            for bucket, p in sorted(dist.items()):
                rows.append((VERSION, exam, "", dimension, bucket, p, measured_prov, ns, nd, ni,
                             f"{measured_prov}: per-sitting-normalized over {ns} independent sittings "
                             f"({nd} booklet/shift docs, {ni} instances)", now))
                if v1_prior is not None:
                    v1p = v1_prior.get(bucket)
                    deltas.append((VERSION, exam, dimension, bucket, v1p, "curated_prior", p, measured_prov,
                                   round(p - v1p, 6) if v1p is not None else None,
                                   "v2 structural proxy vs v1 authored prior — a structural comparison, not measured"))
        else:
            coverage[exam][dimension] = f"insufficient_evidence ({ns} sittings < {FLOOR})"
            rows.append((VERSION, exam, "", dimension, "(insufficient)", None, "insufficient_evidence", ns, nd, ni,
                         f"insufficient_evidence: {ns} independent sittings ({nd} docs) < OD-5 floor {FLOOR}", now))

    for exam in ED.EXAMS:
        cells_for(exam, "question_type",
                  [(_sitting_key(exam, d, year_of.get(d)), d, t) for (d, e, t) in items if e == exam],
                  "pyq_measured")
        cells_for(exam, "structural_difficulty",
                  [(_sitting_key(exam, d, year_of.get(d)), d, l) for (d, e, l) in diffs if e == exam],
                  "structural_proxy", v1_prior=ED.EXAM_DIFFICULTY_DIST.get(exam, {}))
        coverage.setdefault(exam, {})["subject_weight"] = "published (mandated structure)"
        for subj, w in ED.EXAM_SUBJECT_WEIGHT[exam].items():
            rows.append((VERSION, exam, subj, "subject_weight", subj, round(w, 6), "published", None, None, None,
                         "published exam structure (mandated subject split); measured OCR attribution too thin to improve", now))

    conn = ST.open_store(pyq_db_path, writable=True)
    try:
        conn.execute("DELETE FROM exam_dna_v2 WHERE version=?", (VERSION,))
        conn.execute("DELETE FROM exam_dna_v2_delta WHERE version=?", (VERSION,))
        conn.executemany("INSERT INTO exam_dna_v2 (version, exam, subject, dimension, bucket, probability, "
                         "provenance_class, n_sittings, n_docs, n_items, basis, created_at) "
                         "VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", rows)
        conn.executemany("INSERT INTO exam_dna_v2_delta (version, exam, dimension, bucket, v1_probability, "
                         "v1_provenance, v2_probability, v2_provenance, delta, note) VALUES (?,?,?,?,?,?,?,?,?,?)",
                         deltas)
        conn.execute("INSERT INTO pyq_meta(key,value) VALUES ('b5_dna_v2_built_at',?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (now,))
        conn.commit()
    finally:
        conn.close()
    return {"version": VERSION, "floor_sittings": FLOOR, "cells": len(rows), "deltas": len(deltas),
            "coverage": coverage}


def report(pyq_db_path=None) -> Dict[str, object]:
    conn = ST.open_store(pyq_db_path, writable=False)
    try:
        prov = {r[0]: r[1] for r in conn.execute(
            "SELECT provenance_class, COUNT(*) FROM exam_dna_v2 WHERE version=? GROUP BY provenance_class", (VERSION,))}
        insufficient = [dict(zip(("exam", "dimension", "n_sittings", "n_docs"), r)) for r in conn.execute(
            "SELECT exam, dimension, n_sittings, n_docs FROM exam_dna_v2 WHERE version=? "
            "AND provenance_class='insufficient_evidence' ORDER BY exam, dimension", (VERSION,))]
        measured = [dict(zip(("exam", "dimension", "bucket", "probability", "n_sittings"), r)) for r in conn.execute(
            "SELECT exam, dimension, bucket, probability, n_sittings FROM exam_dna_v2 WHERE version=? "
            "AND provenance_class IN ('pyq_measured','structural_proxy') ORDER BY exam, dimension, bucket", (VERSION,))]
        return {"version": VERSION, "floor_sittings": FLOOR, "by_provenance": dict(sorted(prov.items())),
                "measured_cells": measured, "insufficient_cells": insufficient,
                "note": "the OD-5 floor keys on distinct INDEPENDENT SITTINGS (exam, year), not raw booklet/shift "
                        "PDFs. Below the floor is honest-null insufficient_evidence; subject weight is published "
                        "(mandated); measured student difficulty is honest-null pending pilot data (R5-5). "
                        "examdna.db v1 is byte-identical (OD-6)."}
    finally:
        conn.close()


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
