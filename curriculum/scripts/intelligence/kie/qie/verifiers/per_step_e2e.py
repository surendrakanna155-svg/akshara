"""Method 4 — `per_step+independent_e2e`: re-run the whole pipeline, every operator independently checked,
PLUS an independent end-to-end recomputation, and confirm answer/options untampered.

Wraps `compositions.verify_composition`, which resolves the frame from the shared cross-domain
`TEMPLATE_REGISTRY` and re-runs `compose.run_pipeline` (each `Operator.verify` is a genuinely different
second method). Needs the generator's `_env0`/`_params`/`_answer` structured payload + a registered
`frame_id`. A stored pilot row does not carry the env, so re-verification is honest-null (`unavailable`).

Importing this module registers the base composition templates; the genetics/biology frames are registered by
`two_way`/`kb_lookup` (imported by the battery), so any composition frame_id resolves.
"""
from __future__ import annotations

from typing import Any, Dict

from kie.qie.compositions import TEMPLATE_REGISTRY, verify_composition
from kie.qie.verifiers.protocol import VerdictResult, _from_agree, inapplicable, unavailable

NAME = "per_step_e2e"
METHOD = "per_step+independent_e2e"
IS_DETERMINISTIC = True

_REQUIRED = ("_env0", "_params", "_answer", "frame_id", "options", "answer_text")


def applicable(record: Dict[str, Any]) -> bool:
    m = str(record.get("method") or record.get("refuter_verdict") or "").lower()
    if m and m not in (METHOD.lower(),):
        return False
    # `_params` (not `_steps`) distinguishes a hand-built composition from an auto-chained (type_directed) one.
    return "_env0" in record and "_params" in record and "frame_id" in record


def verify(record: Dict[str, Any]) -> VerdictResult:
    if not all(k in record for k in _REQUIRED):
        return unavailable(METHOD, "composition structured payload (_env0,_params,_answer) not present")
    if record["frame_id"] not in TEMPLATE_REGISTRY:
        return inapplicable(METHOD, f"frame {record['frame_id']!r} not in TEMPLATE_REGISTRY")
    verdict = verify_composition(record)
    return _from_agree(METHOD, verdict, reason="per-step + independent end-to-end recompute",
                       frame_id=record.get("frame_id"))
