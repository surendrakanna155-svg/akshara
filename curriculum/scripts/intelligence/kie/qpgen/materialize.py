"""Materialization — turn selected slots into concrete questions.

Deterministic-first: descriptive slots (short/long answer) are rendered into ORIGINAL question
stems grounded ONLY in the concept title/definition (no fabricated facts, no copied source
text). Objective slots (mcq/numerical/assertion_reason/match) cannot be materialized
deterministically from the current KIE (templates/distractors/values = 0) without fabrication,
so they become validated SPECS describing what an authorized AI author must produce.

The AI-fill seam is GATED: AI is never invoked unless the request opts in AND the KIE AI
authorization is set. The deterministic path stands fully on its own.
"""
from __future__ import annotations

import hashlib
import os
import re
from typing import Dict, List, Optional

from kie.qpgen.models import (Bloom, PaperRequest, QuestionSlot, QuestionType,
                              RenderMode, SlotStatus)

DESCRIPTIVE_TYPES = frozenset({QuestionType.SHORT_ANSWER, QuestionType.LONG_ANSWER})

_SHORT_VERBS = ("Define", "Explain", "Describe", "Write a short note on", "State the meaning of")
_LONG_VERBS = ("Explain {t} in detail with suitable examples.",
               "Describe {t} and discuss its significance.",
               "Discuss {t}, illustrating your answer with examples.",
               "Give a detailed account of {t}.")


class AiFillGatedError(RuntimeError):
    """AI fill requested but not authorized (KIE_AI_AUTHORIZED unset / request opt-out)."""


class AiProviderNotWired(RuntimeError):
    """AI authorized but no offline provider is wired (deterministic path is the default)."""


def ai_authorized() -> bool:
    return os.environ.get("KIE_AI_AUTHORIZED") == "1"


def _pick(options, key: str, seed: int):
    idx = int(hashlib.sha256(f"{key}|{seed}".encode()).hexdigest()[:8], 16) % len(options)
    return options[idx]


_LEAD_ARTICLE = re.compile(r"^(the|a|an)\s+", re.I)


def display_title(title: str) -> str:
    """Readable concept title for a stem: title-case ALL-CAPS headings (PROTEINS → Proteins)
    while leaving normal/Title-Case text intact (keeps DNA/RNA-style acronyms untouched)."""
    words = title.split()
    out = []
    for w in words:
        if len(w) >= 4 and w.isupper():           # heading-case word → Title Case
            out.append(w.capitalize())
        else:
            out.append(w)                          # keep acronyms (DNA) and normal case
    return " ".join(out)


def embed_title(title: str) -> str:
    """Title embedded after a verb: drop a leading article so 'Define The momentum' → 'Define
    the momentum' reads naturally."""
    t = display_title(title)
    return _LEAD_ARTICLE.sub(lambda m: m.group(1).lower() + " ", t)


def _definitions(conn, codes: List[str]) -> Dict[str, str]:
    if not conn or not codes:
        return {}
    ph = ",".join("?" * len(codes))
    return {r["concept_code"]: (r["definition"] or "")
            for r in conn.execute(
                f"SELECT concept_code, definition FROM concepts WHERE concept_code IN ({ph})", codes).fetchall()}


def render_deterministic(slot: QuestionSlot, definition: str, seed: int) -> QuestionSlot:
    """Render an original descriptive stem grounded in the concept. Sets stem/answer + FILLED."""
    title = display_title(slot.concept_title)
    embedded = embed_title(slot.concept_title)
    if slot.question_type == QuestionType.SHORT_ANSWER:
        verb = _pick(_SHORT_VERBS, slot.concept_code, seed)
        slot.stem = f"{verb} {embedded}."
    else:  # LONG_ANSWER
        slot.stem = _pick(_LONG_VERBS, slot.concept_code, seed).format(t=embedded)
    # answer = the certified definition when present, else an explicit teacher MARKING GUIDELINE
    # (never a fabricated fact and never copied source text — copyright-safe).
    if definition.strip():
        slot.answer = definition.strip()
        slot.solution = f"Award marks for a correct explanation of {title}: {definition.strip()}"
    else:
        slot.answer = (f"[Marking guideline — award full marks for a correct, in-syllabus "
                       f"explanation of {title}; teacher to confirm key points.]")
        slot.solution = f"Award up to {slot.marks} marks for a complete, correct account of {title}."
    slot.render_mode = RenderMode.DETERMINISTIC
    slot.status = SlotStatus.FILLED
    return slot


def build_spec(slot: QuestionSlot) -> QuestionSlot:
    """Objective slot → a validated authoring SPEC for a gated AI (kept out of the paper body
    until filled). Structural only; no fabricated content."""
    reqs = {
        QuestionType.MCQ: "4 options, exactly one correct, 3 plausible distractors",
        QuestionType.NUMERICAL: "a numeric answer with units and a worked solution",
        QuestionType.ASSERTION_REASON: "an assertion + a reason with the standard 4-way key",
        QuestionType.MATCH: "two columns to match (4x4)",
    }.get(slot.question_type, "an original question")
    slot.stem = (f"[SPEC · author via approved AI] {slot.question_type} on '{slot.concept_title}' "
                 f"({slot.subject}) — bloom={slot.bloom}, difficulty={slot.difficulty}, "
                 f"marks={slot.marks}; requires {reqs}; must stay within syllabus, original, "
                 f"no copied source text.")
    slot.render_mode = RenderMode.SPEC_ONLY
    slot.status = SlotStatus.SPEC
    slot.provenance = {**slot.provenance, "author_requirements": reqs}
    return slot


def materialize(slots: List[QuestionSlot], conn, request: PaperRequest) -> Dict:
    """Materialize every slot. Returns counts. AI is only consulted if the request opts in AND
    authorization is set — otherwise objective slots remain specs (deterministic default)."""
    defs = _definitions(conn, [s.concept_code for s in slots])
    filled = spec = 0
    for s in slots:
        if s.render_mode == RenderMode.DETERMINISTIC or s.question_type in DESCRIPTIVE_TYPES:
            render_deterministic(s, defs.get(s.concept_code, ""), request.seed)
            filled += 1
        else:
            build_spec(s)
            spec += 1

    ai = {"attempted": False, "filled": 0}
    if request.allow_ai_fill:
        ai = ai_fill([s for s in slots if s.status == SlotStatus.SPEC])
        spec -= ai["filled"]
        filled += ai["filled"]
    return {"filled": filled, "spec_only": spec, "ai": ai}


def ai_fill(spec_slots: List[QuestionSlot]) -> Dict:
    """GATED seam. Authors original questions for spec slots via the KIE AI gateway.

    Never called unless the request opted in. Raises unless KIE_AI_AUTHORIZED=1, and (until an
    offline provider is wired) raises AiProviderNotWired even when authorized — the deterministic
    path remains the shipping default. Any AI output MUST re-pass the validation gate (Q6).
    """
    if not spec_slots:
        return {"attempted": False, "filled": 0}
    if not ai_authorized():
        raise AiFillGatedError(
            "AI question authoring is gated (set KIE_AI_AUTHORIZED=1 and use the approved "
            "governed gateway). The deterministic engine does not require it.")
    raise AiProviderNotWired(
        "AI authorized but no offline authoring provider is wired here; objective items remain "
        "specs. Wire the KIE governed gateway to enable, then re-run validation on its output.")
