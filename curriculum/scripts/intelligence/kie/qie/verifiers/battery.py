"""The reusable verifier battery — the artifact R4-1(a) delivers.

Registers the 7 deterministic question-item verifiers + the `notation_recovery` relation gate behind ONE
dispatcher. `verify_any(record)` runs the strongest applicable deterministic verifier over a structured
generator record; `reverify_from_record(row)` re-verifies a STORED pilot_verified_item row to the extent the
persisted data allows (honest-null where the generator's structured payload was never banked).

MODEL AGREEMENT IS NOT HERE. The pilot lane's 8th "method" (`refuter_verdict='agree'`, the 62 Biology items)
is a model-judge, which can reject but never independently certify (audit §11). `reverify_from_record` routes
it to a HELD result (`held_qualitative`, is_deterministic=False, ok=None) — it can never be re-verified into a
promotion here. That lane is R4-3.

FACTORY HAND-OFF (interface, not an R4-1 code change): the factory's independent-answer stage already accepts
a `method` label — `corpus.record_independent(conn, candidate_id, method=<battery method>, solver_answer,
generator_answer, verdict, detail)`. To wire the battery into the factory lane, the `factory/gates.py` owner
calls `verify_any(record)` and feeds `(result.method, result.evidence, 'agree' if result.ok else 'disagree')`
into `record_independent`. R4-1 delivers this library + signature; it does NOT edit gates.py (R2/R3 ownership).
"""
from __future__ import annotations

from types import ModuleType
from typing import Any, Dict, List, Optional

from kie.qie.verifiers import (deterministic_solver, independent_second_method, kb_lookup,
                               notation_recovery, per_step_e2e, symbolic_inverse, two_way, type_directed)
from kie.qie.verifiers.protocol import (MODEL_AGREEMENT_METHOD, VerdictResult, assert_not_model_agreement,
                                        inapplicable)

# Deterministic question-item verifiers, most-specific-first for dispatch when a record does not name its
# method. Genetics/biology frames are matched by their specific verifier BEFORE the generic composition one, so
# `verify_any` returns the precise method label (deterministic_two_way / deterministic_kb_lookup).
QUESTION_VERIFIERS: List[ModuleType] = [
    two_way, kb_lookup, per_step_e2e, type_directed,
    symbolic_inverse, independent_second_method, deterministic_solver,
]
# The relation gate is dispatched separately (its input is a relation, not a question item).
RELATION_VERIFIER: ModuleType = notation_recovery

ALL_VERIFIERS: List[ModuleType] = QUESTION_VERIFIERS + [RELATION_VERIFIER]

# canonical pilot method label -> verifier module (model agreement is deliberately ABSENT).
BY_METHOD: Dict[str, ModuleType] = {m.METHOD: m for m in ALL_VERIFIERS}

DETERMINISTIC_METHODS = frozenset(m.METHOD for m in ALL_VERIFIERS)


def is_deterministic_method(method: str) -> bool:
    """True iff `method` is one of the battery's deterministic verifiers. Model agreement ('agree') is False."""
    return str(method) in DETERMINISTIC_METHODS


def verify_any(record: Dict[str, Any]) -> VerdictResult:
    """Dispatch to the strongest applicable deterministic verifier for a structured generator record.

    If the record names a `method`/`refuter_verdict`, that verifier is preferred; otherwise the strongest
    applicable one wins. Model agreement is refused (a genuine verifier must run). Returns `inapplicable`
    (honest-null) when no deterministic verifier can handle the record."""
    named = str(record.get("method") or record.get("refuter_verdict") or "").strip()
    if named:
        assert_not_model_agreement(named)
        mod = BY_METHOD.get(named)
        if mod is not None and mod.applicable(record):
            return mod.verify(record)
    for mod in QUESTION_VERIFIERS:
        if mod.applicable(record):
            return mod.verify(record)
    if RELATION_VERIFIER.applicable(record):
        return RELATION_VERIFIER.verify(record)
    return inapplicable("verify_any", "no deterministic verifier applies to this record")


def reverify_from_record(row: Dict[str, Any]) -> VerdictResult:
    """Re-verify a STORED pilot_verified_item row (dict-like) using its recorded method label.

    Honest-null discipline:
      * `deterministic_solver` items re-verify from the rendered stem/options/answer via the independent
        library second-solver (a real, reproducible re-derivation — 568 items).
      * every other deterministic method needs the generator's structured payload, which the pilot lane never
        persisted → `unavailable` (ok=None): the recorded deterministic verdict stands, but this pass does not
        manufacture a fresh one.
      * model agreement ('agree') → HELD for R4-3: ok=None, is_deterministic=False, never re-verified here.
    """
    method = str(row.get("refuter_verdict") or row.get("method") or "").strip()
    rec = {
        "method": method,
        "stem": row.get("stem"),
        "options": _as_options(row.get("options")),
        "answer_text": row.get("answer_text"),
        "subject": row.get("subject"),
    }
    if method == MODEL_AGREEMENT_METHOD:
        return VerdictResult(ok=None, verdict="held_qualitative", method=MODEL_AGREEMENT_METHOD,
                             is_deterministic=False,
                             reason="model agreement is not an independent verifier — held for R4-3")
    if method == deterministic_solver.METHOD:
        return deterministic_solver.verify_rendered(rec)
    if method in BY_METHOD:
        # deterministic method whose structured payload the pilot lane did not persist → honest-null.
        return VerdictResult(ok=None, verdict="unavailable", method=method, is_deterministic=True,
                             reason="deterministic method requires the generator structured payload, "
                                    "which the pilot bank did not persist on the row (honest-null)")
    return VerdictResult(ok=None, verdict="unknown_method", method=method or "?", is_deterministic=False,
                         reason=f"unrecognized method label {method!r}")


def _as_options(v) -> Dict[str, str]:
    import json
    if isinstance(v, dict):
        return v
    if isinstance(v, str):
        try:
            d = json.loads(v)
            return d if isinstance(d, dict) else {}
        except (json.JSONDecodeError, TypeError):
            return {}
    return {}
