"""Program B · B6 — the Exam DNA v2 consumer contract (integration).

Any downstream consumer (a blueprint, a paper generator, an "exam-representative" claim) reads the measured DNA
THROUGH this layer, which does two things the roadmap requires:

  1. **Surfaces `provenance_class` on every cell** — a consumer can never read a probability without also seeing
     whether it is `pyq_measured` / `structural_proxy` / `published` / `insufficient_evidence`. (An
     insufficient_evidence cell has NO probability — the consumer must handle honest-null, not a fabricated 0.)

  2. **Gates every "exam-representative" claim on v2** — `assert_exam_representative(exam, dimension)` is
     FAIL-CLOSED: it raises unless that dimension for that exam is genuinely measured (`pyq_measured`). So a paper
     that wants to claim it matches NEET's question-type mix may (NEET is measured); the same claim for JEE Main
     (insufficient_evidence — only 6 mined docs) is REFUSED. This is the enforcement point for the standing rule
     "any exam-representative claim gates on the measured v2".

Read-only over the derived `pyq_corpus.db`; never touches the frozen substrate or examdna.db v1.
"""
from __future__ import annotations

from typing import Dict, List, Optional

from kie.qie.pyq import dna_v2 as D2
from kie.qie.pyq import store as ST

# provenance classes that constitute a genuine MEASUREMENT of the exam's observed structure (the only basis on
# which an "exam-representative" claim may stand). `published` is a mandated fact, not a per-exam MEASUREMENT of
# this corpus; `structural_proxy` is a proxy, not measured student behaviour; `insufficient_evidence` is null.
_MEASURED = frozenset({"pyq_measured"})


class ExamDnaV2InsufficientEvidence(Exception):
    """An exam-representative claim was made on a dimension that v2 does not measure (fail-closed)."""


def exam_dna(exam: str, dimension: Optional[str] = None, version: str = D2.VERSION,
             pyq_db_path=None) -> List[Dict[str, object]]:
    """All v2 cells for `exam` (optionally one `dimension`), each WITH `provenance_class` surfaced. An
    insufficient_evidence cell is returned with `probability=None` (honest-null) — never a fabricated number."""
    conn = ST.open_store(pyq_db_path, writable=False)
    try:
        q = ("SELECT dimension, bucket, probability, provenance_class, n_docs, n_items, basis "
             "FROM exam_dna_v2 WHERE version=? AND exam=?")
        args: list = [version, exam]
        if dimension:
            q += " AND dimension=?"
            args.append(dimension)
        return [dict(zip(("dimension", "bucket", "probability", "provenance_class", "n_docs", "n_items", "basis"), r))
                for r in conn.execute(q + " ORDER BY dimension, bucket", args)]
    finally:
        conn.close()


def is_exam_representative(exam: str, dimension: str, version: str = D2.VERSION, pyq_db_path=None) -> bool:
    """True iff `dimension` for `exam` is genuinely MEASURED in v2 (so an exam-representative claim may stand)."""
    cells = exam_dna(exam, dimension, version, pyq_db_path)
    return bool(cells) and all(c["provenance_class"] in _MEASURED for c in cells)


def assert_exam_representative(exam: str, dimension: str, version: str = D2.VERSION, pyq_db_path=None) -> None:
    """FAIL-CLOSED gate. Raise unless `dimension` for `exam` is measured. Every product / blueprint claim of
    'exam-representativeness' on this dimension must pass this call first."""
    if not is_exam_representative(exam, dimension, version, pyq_db_path):
        cells = exam_dna(exam, dimension, version, pyq_db_path)
        prov = sorted({c["provenance_class"] for c in cells}) or ["absent"]
        raise ExamDnaV2InsufficientEvidence(
            f"'{exam}' {dimension} is not exam-representative in v2 (provenance={prov}); "
            f"a measured (pyq_measured) distribution is required — this corpus has insufficient evidence.")


def coverage(version: str = D2.VERSION, pyq_db_path=None) -> Dict[str, Dict[str, str]]:
    """Per (exam, dimension) → provenance_class summary — what a consumer may and may not treat as measured."""
    conn = ST.open_store(pyq_db_path, writable=False)
    try:
        out: Dict[str, Dict[str, str]] = {}
        for exam, dim, prov in conn.execute(
                "SELECT exam, dimension, provenance_class FROM exam_dna_v2 WHERE version=? "
                "GROUP BY exam, dimension, provenance_class ORDER BY exam, dimension", (version,)):
            out.setdefault(exam, {})[dim] = prov
        return out
    finally:
        conn.close()
