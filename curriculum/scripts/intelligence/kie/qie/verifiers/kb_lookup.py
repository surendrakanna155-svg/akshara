"""Method 7 — `deterministic_kb_lookup`: answer + distractors validated by deterministic lookup/traversal of a
curated, evidence-grounded KB (no model in the truth path).

Qualitative Biology (`kie.qie.biology`) generates FROM and verifies AGAINST the canonical `bio_data` tables:
importing `biology` registers its operators + templates, and each item is re-verified by
`compositions.verify_composition` (the pipeline re-run re-checks every KB relation + the template's
independent `end_to_end` re-derivation). `bio_data.assert_consistent()` is asserted at import, so the KB is
functional (one canonical answer per relation). Needs the `_env0`/`_params`/`_answer` payload; a stored pilot
row re-verifies honest-null.

Note: the KB target is the in-code `kie.qie.bio_data` tables (self-contained, deterministic), NOT kie.db —
kept that way deliberately.
"""
from __future__ import annotations

from typing import Any, Dict

from kie.qie import bio_data as _bio_data          # noqa: F401 — asserts KB consistency at import
from kie.qie import biology as _biology            # noqa: F401 — import registers biology KB templates
from kie.qie.compositions import TEMPLATE_REGISTRY, verify_composition
from kie.qie.verifiers.protocol import VerdictResult, _from_agree, inapplicable, unavailable

NAME = "kb_lookup"
METHOD = "deterministic_kb_lookup"
IS_DETERMINISTIC = True

BIO_KB_FRAMES = frozenset(_biology.TEMPLATES.keys())
_REQUIRED = ("_env0", "_params", "_answer", "frame_id", "options", "answer_text")


def applicable(record: Dict[str, Any]) -> bool:
    m = str(record.get("method") or record.get("refuter_verdict") or "").lower()
    if m and m != METHOD:
        return False
    return record.get("frame_id") in BIO_KB_FRAMES


def verify(record: Dict[str, Any]) -> VerdictResult:
    if not all(k in record for k in _REQUIRED):
        return unavailable(METHOD, "biology-KB structured payload (_env0,_params,_answer) not present")
    if record["frame_id"] not in TEMPLATE_REGISTRY:
        return inapplicable(METHOD, f"biology KB frame {record['frame_id']!r} not registered")
    verdict = verify_composition(record)
    return _from_agree(METHOD, verdict, reason="deterministic canonical-KB lookup/traversal + independent e2e",
                       frame_id=record.get("frame_id"))
