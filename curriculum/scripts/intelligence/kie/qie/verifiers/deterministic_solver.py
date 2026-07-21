"""Method 1 — `deterministic_solver`: an INDEPENDENT second relation-solver reproduces the answer.

Wraps `generate_numeric.verify_numeric` (the generator's own deterministic check) for a full structured
record, AND exposes a `verify_rendered` path that re-derives agreement from ONLY a rendered item
(stem + options + answer) using `relations.verify` — the independent library second-solver. The rendered
path is what lets R4-1 re-verify the 568 stored NUMERIC_RELATIONAL pilot items, whose structured payload
(`params`/`relation`) the pilot lane never persisted: parse the quantities out of the stem, and ask whether
ANY library relation reproduces the stated answer. That is a genuinely independent re-derivation from the
student-visible content, not a replay of the generator's own arithmetic.
"""
from __future__ import annotations

from typing import Any, Dict

from kie.qie import relations as R
from kie.qie.generate_numeric import verify_numeric
from kie.qie.verifiers.protocol import VerdictResult, _from_agree, unavailable

NAME = "deterministic_solver"
METHOD = "deterministic_solver"
IS_DETERMINISTIC = True


def applicable(record: Dict[str, Any]) -> bool:
    m = str(record.get("method") or record.get("refuter_verdict") or "").lower()
    if m and m != METHOD:
        return False
    # a structured record carries params+relation; a rendered record carries stem+options+answer_text
    has_struct = bool(record.get("params")) and bool(record.get("relation"))
    has_rendered = bool(record.get("stem")) and bool(record.get("options")) and \
        (record.get("answer_text") is not None)
    return has_struct or has_rendered


def verify(record: Dict[str, Any]) -> VerdictResult:
    """Prefer the generator's structured check; fall back to the independent rendered-content re-derivation."""
    if record.get("params") and record.get("relation"):
        verdict = verify_numeric(record)
        return _from_agree(METHOD, verdict, reason="relations.verify second-solver over declared params",
                           relation=record.get("relation"))
    return verify_rendered(record)


def verify_rendered(record: Dict[str, Any]) -> VerdictResult:
    """Independent re-derivation from student-visible content only (stem/options/answer). Used to re-verify
    a stored pilot row. A wrong answer (a damaged control) yields `disagree` because no library relation
    reproduces it from the stem's numbers."""
    stem = record.get("stem") or ""
    options = record.get("options") or {}
    answer_text = record.get("answer_text")
    subject = record.get("subject")
    if not stem or answer_text is None:
        return unavailable(METHOD, "no stem/answer to re-derive from")
    target = R.first_number(str(answer_text))
    given = R.parse_numbers(stem)
    if target is None or not given:
        return unavailable(METHOD, "no numeric answer/quantities parseable from the rendered item")
    hit = R.verify(given, target, subject=subject if subject in
                   ("Physics", "Chemistry", "Mathematics") else None)
    if hit is None and subject not in ("Physics", "Chemistry", "Mathematics"):
        hit = R.verify(given, target)
    # unique-key: the answer text must appear exactly once among the options (no distractor equals it)
    vals = [str(v) for v in (options.values() if isinstance(options, dict) else options)]
    unique = vals.count(str(answer_text)) == 1 if vals else True
    if hit is None:
        return VerdictResult(ok=False, verdict="disagree", method=METHOD, is_deterministic=True,
                             reason="no library relation reproduces the answer from the stem quantities",
                             evidence={"given": given, "target": target})
    if not unique:
        return VerdictResult(ok=False, verdict="disagree", method=METHOD, is_deterministic=True,
                             reason="answer not unique among options", evidence={"relation": hit})
    return VerdictResult(ok=True, verdict="agree", method=METHOD, is_deterministic=True,
                         reason=f"independent second solver reproduced the answer via {hit}",
                         evidence={"relation": hit, "given": given, "target": target})
