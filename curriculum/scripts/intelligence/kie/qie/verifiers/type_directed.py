"""Method 5 — `type_directed+per_step_independent`: same as method 4 but for AUTO-chained (type-directed)
pipelines built by `autocompose`.

Wraps `autocompose.verify_auto`, which re-runs the auto-built pipeline (`compose.run_pipeline`) with every
step independently checked and confirms the recorded answer/options. Needs the generator's
`_env0`/`_steps`/`_answer_key` payload; a stored pilot row re-verifies honest-null (`unavailable`).
"""
from __future__ import annotations

from typing import Any, Dict

from kie.qie.autocompose import verify_auto
from kie.qie.verifiers.protocol import VerdictResult, _from_agree, unavailable

NAME = "type_directed"
METHOD = "type_directed+per_step_independent"
IS_DETERMINISTIC = True

_REQUIRED = ("_env0", "_steps", "_answer_key", "options", "answer_text")


def applicable(record: Dict[str, Any]) -> bool:
    m = str(record.get("method") or record.get("refuter_verdict") or "").lower()
    if m and m != METHOD.lower():
        return False
    return "_env0" in record and "_steps" in record and "_answer_key" in record


def verify(record: Dict[str, Any]) -> VerdictResult:
    if not all(k in record for k in _REQUIRED):
        return unavailable(METHOD, "autocompose structured payload (_env0,_steps,_answer_key) not present")
    verdict = verify_auto(record)
    return _from_agree(METHOD, verdict, reason="type-directed chain, per-step independent re-run")
