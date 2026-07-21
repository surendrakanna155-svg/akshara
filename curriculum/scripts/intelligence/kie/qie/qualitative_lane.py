"""R4-3 qualitative certification lane — apply the non-model re-derivation across the governed-fact substrate.

Uses `verifiers.qualitative` (the ONLY non-model certification signal for qualitative items: independent,
>=2-source KVS corroboration) to classify every VERIFIED governed_fact into an honest grounding class:

  * `independently_corroborated`      — qualitatively CERTIFIABLE (a non-model, source-grounded re-derivation
                                        agreed). This is the qualitative analogue of `sympy_rederived`.
  * `held_awaiting_independent_evidence` — HELD (honest-null): the fact rests on the model examiner + a single
                                        source; no independent corroboration exists in the owned estate yet.
  * `contradicted`                    — an independent assertion attests a different answer (quarantine).

This is an EVIDENCE examination, orthogonal to product promotion: a corroborated fact is qualitatively
certifiable but still reaches the product bank only through the full R2 chain (solution stage + distractor
verification + cross-family judge + RI-8 provenance) — which needs the R4-2 model actors + a live key. The
lane is deterministic and needs NO model, so it runs and is verifiable offline.
"""
from __future__ import annotations

import sqlite3
from typing import Dict, Optional

from kie import config
from kie.qie.verifiers import qualitative as Q

QIE_DB_PATH = config.KIE_HOME / "qie.db"


def _ro(path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def classify_facts(qie: sqlite3.Connection) -> Dict[str, str]:
    """{fact_id -> grounding_label} for every VERIFIED governed_fact (deterministic, non-model)."""
    index = Q.build_corroboration_index(qie)
    out: Dict[str, str] = {}
    for r in qie.execute("SELECT * FROM governed_fact WHERE status='verified'"):
        row = dict(r)
        v = Q.reverify_fact(row, index)
        out[row["fact_id"]] = Q.grounding_label(v)
    return out


def yield_report(qie_path: Optional[object] = None) -> Dict[str, object]:
    """The honest qualitative-certification yield over the owned substrate."""
    qie = _ro(qie_path or QIE_DB_PATH)
    try:
        index = Q.build_corroboration_index(qie)
        buckets: Dict[str, int] = {}
        by_subject_certifiable: Dict[str, int] = {}
        total = 0
        for r in qie.execute("SELECT * FROM governed_fact WHERE status='verified'"):
            row = dict(r)
            total += 1
            label = Q.grounding_label(Q.reverify_fact(row, index))
            buckets[label] = buckets.get(label, 0) + 1
            if label == Q.GROUNDING_CORROBORATED:
                by_subject_certifiable[row.get("subject")] = \
                    by_subject_certifiable.get(row.get("subject"), 0) + 1
        return {
            "verified_facts": total,
            "independent_corroboration_index_size": len(index),
            "certifiable_now": buckets.get(Q.GROUNDING_CORROBORATED, 0),
            "held_awaiting_independent_evidence": buckets.get(Q.GROUNDING_HELD, 0),
            "contradicted": buckets.get("contradicted", 0),
            "certifiable_by_subject": by_subject_certifiable,
            "note": ("qualitative certification requires a NON-MODEL re-derivation; the only such signal in the "
                     "owned estate is KVS corroboration from >=2 source docs that EXCLUDE the fact's own source "
                     "(counting the fact's own document would be circular, not independent). On the current "
                     "substrate that yields 0 — the honest state: the governed-fact and KVS lanes largely read "
                     "the same corpus answer keys, so genuinely-independent cross-substrate corroboration is "
                     "absent until independent evidence is acquired (R5-4/R5-6 PYQ corpus) or a cross-family "
                     "judge is added (R4-2 + a live key). Model agreement never certifies."),
        }
    finally:
        qie.close()


if __name__ == "__main__":
    import json
    print(json.dumps(yield_report(), indent=2))
