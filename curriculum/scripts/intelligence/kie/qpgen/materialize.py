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

import json

from kie.qpgen import templates
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

# a certified definition is usable as a model answer only if it reads as a COMPLETE statement.
# The KIE concept layer occasionally captures a truncated clause ("the amount of", "below :"),
# which must NOT be shown as an authoritative answer — those fall back to the honest marking
# guideline (same safe path as a missing definition). Conservative: only clear fragments are
# rejected, so real definitions ("the force per unit area") are kept.
_DANGLING_TAIL = {
    "of", "to", "the", "a", "an", "and", "or", "per", "in", "on", "for", "with", "as", "is",
    "are", "from", "into", "by", "that", "which", "than", "then", "between", "about", "its",
    "their", "this", "these", "at", "be", "was", "were", "has", "have", "when", "where",
}
_DEF_MIN_LEN = 12


def usable_definition(definition: str) -> bool:
    """True if a certified definition is complete enough to present as a model answer.

    Rejects clear extraction fragments (too short, terminal non-period punctuation, a dangling
    function word or a truncated final token). Deterministic + conservative."""
    d = (definition or "").strip()
    if len(d) < _DEF_MIN_LEN:
        return False
    if d[-1] in ":;,-–—":                              # ends mid-clause
        return False
    words = re.findall(r"[A-Za-z][A-Za-z'\-]*", d)
    if not words:
        return False
    last = words[-1].lower()
    if last in _DANGLING_TAIL:                          # "... the amount of"
        return False
    if len(words[-1]) <= 2 and last not in ("ph",):     # truncated final token ("... ratio of re")
        return False
    return True


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
    # answer = the certified definition when present AND complete, else an explicit teacher
    # MARKING GUIDELINE (never a fabricated fact and never copied source text — copyright-safe).
    # A truncated/fragmentary definition is NOT shown as an authoritative answer.
    if usable_definition(definition):
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


def render_template(slot: QuestionSlot, seed: int) -> bool:
    """Fill an objective slot deterministically from the certified template registry (zero AI,
    solver-verified). Returns True if a template matched. This is tried BEFORE any spec/AI."""
    tmpl = templates.find_template(slot.subject, slot.concept_title, slot.question_type)
    if not tmpl:
        return False
    out = templates.instantiate(tmpl, slot.concept_code, seed, slot.question_type)
    slot.stem, slot.answer = out["stem"], out["answer"]
    slot.options, slot.solution = out.get("options"), out.get("solution")
    slot.render_mode = RenderMode.DETERMINISTIC
    slot.status = SlotStatus.FILLED
    slot.provenance = {**slot.provenance, "source": "template", "template_id": out["template_id"],
                       "solver_verified": True}
    return True


def materialize(slots: List[QuestionSlot], conn, request: PaperRequest,
                provider=None, ai_cache: Optional[Dict] = None) -> Dict:
    """Deterministic-first materialization:
      descriptive → original stem; objective → certified TEMPLATE (solver-verified) if one
      matches, else a spec. AI is consulted only if the request opts in AND authorization is set,
      and every AI question then re-passes the SAME validation gate downstream.
    """
    defs = _definitions(conn, [s.concept_code for s in slots])
    filled = spec = template_filled = 0
    for s in slots:
        if s.question_type in DESCRIPTIVE_TYPES:
            render_deterministic(s, defs.get(s.concept_code, ""), request.seed)
            filled += 1
        elif render_template(s, request.seed):          # deterministic objective, no AI
            filled += 1
            template_filled += 1
        else:
            build_spec(s)
            spec += 1

    ai = {"attempted": False, "filled": 0}
    if request.allow_ai_fill:
        ai = ai_fill([s for s in slots if s.status == SlotStatus.SPEC], provider, ai_cache)
        spec -= ai["filled"]
        filled += ai["filled"]
    return {"filled": filled, "spec_only": spec, "template_filled": template_filled, "ai": ai}


def spec_of(slot: QuestionSlot) -> Dict:
    """The authoring contract handed to an AI provider (structural only, no source text)."""
    return {"concept_code": slot.concept_code, "concept_title": slot.concept_title,
            "subject": slot.subject, "question_type": slot.question_type, "bloom": slot.bloom,
            "difficulty": slot.difficulty, "marks": slot.marks,
            "chapter": (slot.provenance or {}).get("chapter"),
            "requirements": "original, in-syllabus, no copied source text; the stem MUST reference "
                            "the concept by name (it is re-validated for grounding); MCQ needs one "
                            "correct option + 3 plausible distractors; numerical needs a worked solution"}


def _spec_hash(spec: Dict) -> str:
    return hashlib.sha256(json.dumps(spec, sort_keys=True).encode()).hexdigest()[:16]


def ai_fill(spec_slots: List[QuestionSlot], provider=None, cache: Optional[Dict] = None) -> Dict:
    """GATED, cached, validated AI seam.

    Contract: never runs unless the request opted in AND KIE_AI_AUTHORIZED=1 AND a governed
    provider is wired. For each spec it hands the provider a structural spec, CACHES the result
    by spec-hash (→ reproducible + minimal API calls), and applies it as a concrete question.
    Applied AI questions carry source='ai' and are re-validated by the SAME downstream validation
    gate as every other question (out-of-syllabus / ungrounded / duplicate AI output is rejected).
    """
    if not spec_slots:
        return {"attempted": False, "filled": 0}
    if not ai_authorized():
        raise AiFillGatedError(
            "AI question authoring is gated (set KIE_AI_AUTHORIZED=1 and use the approved "
            "governed gateway). The deterministic engine does not require it.")
    if provider is None:
        raise AiProviderNotWired(
            "AI authorized but no governed authoring provider is wired; objective items remain "
            "specs. Pass a provider implementing author(spec)->{stem,answer,options,solution}.")
    cache = cache if cache is not None else {}
    filled = cached = 0
    for slot in spec_slots:
        spec = spec_of(slot)
        key = _spec_hash(spec)
        if key in cache:
            out, was_cached = cache[key], True
        else:
            out = provider.author(spec) or {}
            cache[key] = out
            was_cached = False
        if not out.get("stem"):
            continue
        slot.stem = out["stem"]
        slot.answer = out.get("answer")
        slot.options = out.get("options")
        slot.solution = out.get("solution")
        slot.render_mode = RenderMode.DETERMINISTIC
        slot.status = SlotStatus.FILLED
        slot.provenance = {**slot.provenance, "source": "ai", "ai_spec_hash": key,
                           "ai_cached": was_cached}
        filled += 1
        cached += 1 if was_cached else 0
    return {"attempted": True, "filled": filled, "cache_hits": cached}
