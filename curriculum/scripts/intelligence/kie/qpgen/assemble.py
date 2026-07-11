"""Assembly + rendering — turn validated slots into a numbered paper and render it.

Rejected slots are excluded (the validation gate already flagged them); the remaining valid
slots are renumbered within their sections. Renders to a structured dict (JSON) and to a
teacher-facing Markdown paper with an answer key.

RENDER-HONESTY CONTRACT (2026-07-11 QP Content Readiness remediation — see
docs/engineering/eos/KIE_QP_CONTENT_READINESS_*). Documented, regression-locked exception to
the qpgen freeze: it fixes proven student-facing correctness/gate defects that have NO
knowledge/content-layer fix (they live only in the presentation functions). The upstream
pipeline — scope, selection, materialization, validation, assemble() numbering — is UNCHANGED.
  * A FILLED MCQ carries valid options at the data layer, but the renderers never emitted
    them → an unanswerable MCQ printed with no choices. Now rendered/emitted.
  * A SPEC (authoring stub) and a filled-but-only-generic-marking-guideline answer were
    printed into the student body → a placeholder masquerading as a question / answer key.
    Now the STUDENT paper contains ONLY teacher-ready items (real stem, real key, valid
    options); everything else is moved to a clearly-separated "Authoring worklist" that is
    explicitly NOT part of the student paper, and the paper header states honest coverage.
    (Directive P0-1/P0-2: never present a spec as a question; if evidence is insufficient,
    keep the item unfilled rather than pretend it has an answer.)
Nothing here fabricates content; it only decides what is print-ready and formats it.
"""
from __future__ import annotations

import re
from dataclasses import asdict
from typing import Dict, List

from kie.qpgen import sanitize
from kie.qpgen.models import (Blueprint, Difficulty, GeneratedPaper, PaperRequest, QuestionSlot,
                              QuestionType, RenderMode, SlotStatus)
from kie.qpgen.scope import SyllabusScope

# an answer that is only a generic marking guideline is NOT a teacher-ready key
_GENERIC_KEY = re.compile(
    r"marking guideline|award full marks for a correct|teacher to confirm|"
    r"to be authored|award up to \d+ marks for a complete",
    re.I,
)
_SPEC_MARK = re.compile(r"\[SPEC", re.I)
_FOUR_OPTION_TYPES = (QuestionType.MCQ, QuestionType.ASSERTION_REASON)
_OPTION_LABELS = ("A", "B", "C", "D", "E", "F")
# render-time defense-in-depth: a concept title that is a clause/merged fragment which the
# runtime sanitizer is (deliberately) too lenient to reject (the at-rest curate pass removes
# these from the store, so in production they never reach here — this is the belt-and-braces).
_FRAGMENT_MERGED = re.compile(r"[a-z][A-Z]")                          # case-SENSITIVE internal glue
_FRAGMENT_CLAUSE = re.compile(r"\b(was|were|led to|discovered|formulated)\b|\bhis law\b", re.I)


def _title_fragment(title: str) -> bool:
    t = title or ""
    return bool(_FRAGMENT_MERGED.search(t) or _FRAGMENT_CLAUSE.search(t))


def _real_key(answer) -> bool:
    """True if `answer` is a concrete, teacher-usable key (not a generic guideline / stub)."""
    a = (answer or "").strip()
    return bool(a) and not _GENERIC_KEY.search(a)


def _options_ok(slot: QuestionSlot) -> bool:
    opts = slot.options
    if not isinstance(opts, list) or len(opts) != 4:
        return False
    norm = [(o or "").strip() for o in opts]
    if any(not o for o in norm) or len(set(norm)) != 4:
        return False
    ans = (slot.answer or "").strip()
    return bool(ans) and norm.count(ans) == 1


def is_student_printable(slot: QuestionSlot) -> bool:
    """A slot a teacher can print AS-IS — no rewrite of the question or the key needed.

    Requires: FILLED, a real stem free of authoring markers and OCR artifacts, a clean
    concept title, valid options for option-types, and a real (non-generic) answer key for
    everything else. Anything failing this is routed to the authoring worklist, never printed
    as a student question."""
    if slot.status != SlotStatus.FILLED:
        return False
    stem = slot.stem or ""
    if not stem or _SPEC_MARK.search(stem) or not sanitize.stem_quality_ok(stem):
        return False
    if not sanitize.is_clean_concept(slot.concept_title) or _title_fragment(slot.concept_title):
        return False
    if slot.question_type in _FOUR_OPTION_TYPES:
        return _options_ok(slot)
    if slot.question_type in (QuestionType.NUMERICAL, QuestionType.MATCH):
        return bool((slot.answer or "").strip())
    return _real_key(slot.answer)   # descriptive: a real model answer / key


def _marking_scheme(slot: QuestionSlot) -> str:
    """A mark-weighted, concept-grounded marking scheme for a descriptive key. Structure scales
    with the marks; the content is the slot's own (grounded) answer — nothing is fabricated."""
    core = (slot.answer or "").strip().rstrip(".")
    title = slot.concept_title
    parts = [f"[{slot.marks} mark{'s' if slot.marks != 1 else ''}] {core}."]
    scheme = [f"correct statement/definition of {title}"]
    if slot.marks >= 3:
        scheme.append("a supporting explanation or related principle")
    if slot.marks >= 5:
        scheme.append("a relevant example, diagram, or derivation")
    parts.append("Award marks for: " + "; ".join(scheme) + ".")
    return " ".join(parts)


def assemble(request: PaperRequest, scope: SyllabusScope, blueprint: Blueprint,
             slots: List[QuestionSlot], warnings: List[str]) -> GeneratedPaper:
    valid = [s for s in slots if s.status != SlotStatus.REJECTED]
    # renumber within blueprint section order, with a difficulty PROGRESSION inside each section
    # (easy → medium → hard); unlabelled difficulty sits at medium. Stable + deterministic.
    order = {sec: i for i, sec in enumerate(blueprint.sections())}
    valid.sort(key=lambda s: (order.get(s.section, 99),
                              Difficulty.RANK.get(s.difficulty, 1), s.number))
    for i, s in enumerate(valid, start=1):
        s.number = i

    # per-section notes (internal choice / "attempt any N of M") from the blueprint cells,
    # surfaced under each section header so the printed paper reads like the real exam.
    section_notes: Dict[str, List[str]] = {}
    for c in blueprint.cells:
        note = c.note
        if c.choose and c.choose != c.count:
            note = (note + " " if note else "") + f"(Attempt any {c.count} of {c.choose}.)"
        if note:
            section_notes.setdefault(c.section, [])
            if note not in section_notes[c.section]:
                section_notes[c.section].append(note)

    filled = sum(1 for s in valid if s.status == SlotStatus.FILLED)
    spec = sum(1 for s in valid if s.status == SlotStatus.SPEC)
    paper = GeneratedPaper(
        request=request, blueprint_name=blueprint.name,
        title=request.title or f"{scope.exam_profile} Practice Paper",
        subjects=scope.subjects, exam_profile=scope.exam_profile, slots=valid,
        warnings=warnings, total_marks=sum(s.marks for s in valid),
        total_questions=len(valid), filled=filled, spec_only=spec,
        provenance={"scope": scope.stats, "blueprint": blueprint.name, "seed": request.seed,
                    "instructions": blueprint.instructions, "exam": blueprint.exam,
                    "duration_min": blueprint.duration_min,
                    "negative_marking": blueprint.negative_marking,
                    "weightage": blueprint.weightage, "section_notes": section_notes})
    return paper


def render_json(paper: GeneratedPaper) -> Dict:
    printable = [s for s in paper.slots if is_student_printable(s)]
    return {
        "title": paper.title, "exam_profile": paper.exam_profile, "subjects": paper.subjects,
        "blueprint": paper.blueprint_name, "total_marks": paper.total_marks,
        "total_questions": paper.total_questions, "filled": paper.filled, "spec_only": paper.spec_only,
        # honest print-readiness: how many blueprint positions are student-ready as-is
        "printable_questions": len(printable),
        "printable_marks": sum(s.marks for s in printable),
        "warnings": paper.warnings, "provenance": paper.provenance,
        "questions": [
            {"number": s.number, "section": s.section, "type": s.question_type, "marks": s.marks,
             "subject": s.subject, "concept": s.concept_title, "concept_code": s.concept_code,
             "bloom": s.bloom, "difficulty": s.difficulty, "status": s.status,
             "render_mode": s.render_mode, "stem": s.stem,
             "options": s.options, "answer": s.answer, "solution": s.solution,
             "printable": is_student_printable(s),
             "provenance": s.provenance}
            for s in paper.slots
        ],
    }


def render_markdown(paper: GeneratedPaper) -> str:
    exam = paper.provenance.get("exam")
    header = f"**Exam profile:** {paper.exam_profile}"
    if exam:
        header += f"  ·  **Pattern:** {exam}"
    header += (f"  ·  **Subjects:** {', '.join(paper.subjects)}  ·  "
               f"**Total marks:** {paper.total_marks}  ·  **Questions:** {paper.total_questions}")
    dur, neg = paper.provenance.get("duration_min"), paper.provenance.get("negative_marking")
    meta_bits = []
    if dur:
        meta_bits.append(f"**Time:** {dur // 60} h {dur % 60} min")
    if neg:
        meta_bits.append(f"**Negative marking:** {neg}")
    L = [f"# {paper.title}", "", header, ""]
    if meta_bits:
        L += ["  ·  ".join(meta_bits), ""]
    instructions = paper.provenance.get("instructions") or []
    if instructions:
        L += ["**General Instructions**", ""]
        L += [f"{i}. {t}" for i, t in enumerate(instructions, 1)]
        L.append("")

    # ── split into the STUDENT paper (print-ready) and the authoring worklist ──
    printable = [s for s in paper.slots if is_student_printable(s)]
    pending = [s for s in paper.slots if not is_student_printable(s)]

    # honest coverage line — the teacher sees exactly how much is ready to print
    total = len(paper.slots)
    cov = (f"**Deterministic coverage (AI OFF):** {len(printable)} of {total} blueprint "
           f"question{'s' if total != 1 else ''} are ready to print with a complete answer key. ")
    if pending:
        cov += (f"The remaining {len(pending)} could not be produced deterministically from the "
                f"certified corpus and are listed under *Items requiring authoring* (they are NOT "
                f"part of the student paper).")
    else:
        cov += "The paper is complete."
    L += [cov, ""]

    section_notes = paper.provenance.get("section_notes") or {}
    if printable:
        # renumber the student paper 1..N (blueprint section order preserved by slot order)
        current = None
        n = 0
        for s in printable:
            if s.section != current:
                current = s.section
                low = s.section.lower()
                head = s.section if ("section" in low or "part" in low) else f"Section {s.section}"
                L += ["", f"## {head}", ""]
                for note in section_notes.get(s.section, []):
                    L.append(f"*{note}*")
                if section_notes.get(s.section):
                    L.append("")
            n += 1
            L.append(f"**{n}.** {s.stem}  *({s.marks} mark{'s' if s.marks != 1 else ''})*")
            if s.options:
                L.append("   " + "  ".join(f"({_OPTION_LABELS[i]}) {opt}"
                                           for i, opt in enumerate(s.options)))
            L.append("")

        # answer key — only the printed questions, with mark-weighted grounded schemes
        L += ["", "---", "", "## Answer Key & Marking", ""]
        n = 0
        for s in printable:
            n += 1
            if s.question_type in _FOUR_OPTION_TYPES:
                key = f"Correct option: **{s.answer}**"
                if s.solution:
                    key += f" — {s.solution}"
            elif s.question_type in (QuestionType.NUMERICAL, QuestionType.MATCH):
                key = f"**{s.answer}**" + (f" — {s.solution}" if s.solution else "")
            else:
                key = _marking_scheme(s)
            L.append(f"**{n}.** {key}")
    else:
        L += ["", "_No question could be produced deterministically for this scope with AI off._", ""]

    # authoring worklist — explicitly OUTSIDE the student paper (no placeholder is ever shown
    # as a question above). Gives the teacher an honest, actionable list of what remains.
    if pending:
        L += ["", "---", "", "## Items requiring authoring (NOT part of the student paper)", "",
              "_These blueprint positions have no deterministic, corpus-grounded question/key. "
              "Author them (or enable the governed AI author) before including them._", ""]
        for i, s in enumerate(pending, 1):
            reason = ("no deterministic model answer for this concept"
                      if s.question_type in (QuestionType.SHORT_ANSWER, QuestionType.LONG_ANSWER)
                      else "no solver-verified template / grounded distractors for this concept")
            L.append(f"{i}. {s.question_type} · {s.subject} · {s.concept_title} "
                     f"({s.marks} mark{'s' if s.marks != 1 else ''}) — {reason}.")

    if paper.warnings:
        L += ["", "---", "", "## Generation Notes", ""]
        L += [f"- {w}" for w in paper.warnings]
    return "\n".join(L) + "\n"
