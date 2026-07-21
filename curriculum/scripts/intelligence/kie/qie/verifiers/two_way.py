"""Method 6 — `deterministic_two_way`: Punnett enumeration cross-checked by an independent second genetic
method (probability-product / full-grid); forward and reverse agree.

Genetics runs on the SAME compositional engine — importing `kie.qie.genetics` registers its operators +
templates into the shared `TEMPLATE_REGISTRY`, and each item is re-verified by `compositions.verify_composition`
(the pipeline re-run + the template's independent `end_to_end` check, e.g. `_mono_e2e`/`_di_e2e`). This
verifier is method 4's machinery specialised to the genetics frames, tagged with the two-way method label.
Needs the `_env0`/`_params`/`_answer` payload; a stored pilot row re-verifies honest-null.
"""
from __future__ import annotations

from typing import Any, Dict

from kie.qie import genetics as _genetics          # noqa: F401 — import registers genetics templates
from kie.qie.compositions import TEMPLATE_REGISTRY, verify_composition
from kie.qie.verifiers.protocol import VerdictResult, _from_agree, inapplicable, unavailable

NAME = "two_way"
METHOD = "deterministic_two_way"
IS_DETERMINISTIC = True

GENETICS_FRAMES = frozenset(_genetics.TEMPLATES.keys())
_REQUIRED = ("_env0", "_params", "_answer", "frame_id", "options", "answer_text")


def applicable(record: Dict[str, Any]) -> bool:
    m = str(record.get("method") or record.get("refuter_verdict") or "").lower()
    if m and m != METHOD:
        return False
    return record.get("frame_id") in GENETICS_FRAMES


def verify(record: Dict[str, Any]) -> VerdictResult:
    if not all(k in record for k in _REQUIRED):
        return unavailable(METHOD, "genetics structured payload (_env0,_params,_answer) not present")
    if record["frame_id"] not in TEMPLATE_REGISTRY:
        return inapplicable(METHOD, f"genetics frame {record['frame_id']!r} not registered")
    verdict = verify_composition(record)
    return _from_agree(METHOD, verdict, reason="Punnett enumeration vs independent second genetic method",
                       frame_id=record.get("frame_id"))
