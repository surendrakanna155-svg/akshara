"""Method 3 — `independent_second_method`: a structurally different computation reproduces the answer.

Wraps `generate_jee_math.verify_jee_math` (which calls `_agrees(_ans, _payload)` — a second, genuinely
different method per family) + well-formed-options + unique-key. Needs the generator's `_ans`/`_payload`
structured payload, so a stored pilot row re-verifies honest-null (`unavailable`).
"""
from __future__ import annotations

from typing import Any, Dict

from kie.qie.generate_jee_math import verify_jee_math
from kie.qie.verifiers.protocol import VerdictResult, _from_agree, unavailable

NAME = "independent_second_method"
METHOD = "independent_second_method"
IS_DETERMINISTIC = True

_REQUIRED = ("_ans", "_payload", "options", "answer_text")


def applicable(record: Dict[str, Any]) -> bool:
    m = str(record.get("method") or record.get("refuter_verdict") or "").lower()
    if m and m != METHOD:
        return False
    return "_ans" in record and "_payload" in record


def verify(record: Dict[str, Any]) -> VerdictResult:
    if not all(k in record for k in _REQUIRED):
        return unavailable(METHOD, "jee_math structured payload (_ans,_payload) not present on this record")
    verdict = verify_jee_math(record)
    return _from_agree(METHOD, verdict, reason="independent second method reproduced the answer")
