"""Method 2 — `symbolic_inverse`: the inverse operation recovers the input (∫ of a derivative, etc.).

Wraps `generate_calculus.verify_calculus`. Proves the answer is SYMBOLICALLY correct (not an arithmetic
coincidence) by applying the inverse operator and checking it returns the operand, plus a unique-key check.
Needs the generator's structured payload (`_f`, `_ans`, `_op`) — a rendered pilot row does not carry the
sympy objects, so re-verification of a stored calculus item is honest-null (`unavailable`).
"""
from __future__ import annotations

from typing import Any, Dict

from kie.qie.generate_calculus import verify_calculus
from kie.qie.verifiers.protocol import VerdictResult, _from_agree, unavailable

NAME = "symbolic_inverse"
METHOD = "symbolic_inverse"
IS_DETERMINISTIC = True

_REQUIRED = ("_f", "_ans", "_op", "options", "answer_text")


def applicable(record: Dict[str, Any]) -> bool:
    m = str(record.get("method") or record.get("refuter_verdict") or "").lower()
    if m and m != METHOD:
        return False
    return all(k in record for k in ("_f", "_ans", "_op"))


def verify(record: Dict[str, Any]) -> VerdictResult:
    if not all(k in record for k in _REQUIRED):
        return unavailable(METHOD, "calculus structured payload (_f,_ans,_op) not present on this record")
    verdict = verify_calculus(record)
    return _from_agree(METHOD, verdict, reason="inverse-operation symbolic recovery + unique key")
