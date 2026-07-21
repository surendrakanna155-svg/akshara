"""Method 8 (the strongest deterministic gate) — `notation_recovery`: the LOCKED 5-gate relation certifier.

Wraps `convert/notation/verify.certify` — the deterministic, non-model hierarchy that certifies a recovered
governed_relation: PROVENANCE (owned-source page), PARSE (sympy), DIMENSIONAL (base-dimension identity — the
OCR/transcription guard), DOMAIN (subject match), ROUND-TRIP (solvable + re-substitutes). Answer-key match is
CORROBORATION only, never sufficient. These 41 certified relations are the highest-integrity assets in qie.db,
and R4-1 RE-RUNS this gate over each during reconciliation.

Unlike methods 2–7, this verifier IS fully re-runnable from a STORED governed_relation row — the row persists
`equation`, `symbols`, `lhs_unit`, `subject`, `provenance` — so `reverify_relation_row` gives a real,
reproducible re-certification (not honest-null).
"""
from __future__ import annotations

import json
from typing import Any, Dict, Optional

from kie.qie.convert.notation.verify import certify
from kie.qie.verifiers.protocol import VerdictResult

NAME = "notation_recovery"
METHOD = "notation_recovery"
IS_DETERMINISTIC = True


def _loads(v, default):
    if v is None:
        return default
    if isinstance(v, (dict, list)):
        return v
    try:
        return json.loads(v)
    except (json.JSONDecodeError, TypeError):
        return default


def rel_from_row(row: Dict[str, Any]) -> Dict[str, Any]:
    """Reconstruct the `certify()` relation dict from a stored governed_relation row (json columns parsed)."""
    return {
        "name": row.get("name"),
        "subject": row.get("subject"),
        "concept_candidate": row.get("concept_candidate"),
        "equation": row.get("equation"),
        "lhs_unit": row.get("lhs_unit") or "",
        "symbols": _loads(row.get("symbols"), {}),
        "meanings": _loads(row.get("meanings"), {}),
        "constants": _loads(row.get("constants"), []),
        "provenance": _loads(row.get("provenance"), {}),
    }


def applicable(record: Dict[str, Any]) -> bool:
    return bool(record.get("equation")) and bool(record.get("symbols"))


def verify(record: Dict[str, Any]) -> VerdictResult:
    """`record` is a relation dict (or a governed_relation row). Re-run the 5 deterministic gates."""
    rel = record if "equation" in record and isinstance(record.get("symbols"), dict) else rel_from_row(record)
    verdict = certify(rel)
    ok = verdict["status"] == "certified"
    return VerdictResult(
        ok=ok, verdict="certified" if ok else "rejected", method=METHOD, is_deterministic=True,
        reason="" if ok else f"failed gates: {verdict.get('failed_gates')}",
        evidence={"gates": {g: verdict["gates"][g].get("ok") for g in verdict.get("gates", {})},
                  "failed_gates": verdict.get("failed_gates", [])})


def reverify_relation_row(row: Dict[str, Any]) -> VerdictResult:
    """Convenience: re-certify a stored governed_relation row directly."""
    return verify(rel_from_row(row))


def certify_verdict(row: Dict[str, Any]) -> dict:
    """The raw certify() verdict dict (gates + corroboration) for a stored governed_relation row."""
    return certify(rel_from_row(row))
