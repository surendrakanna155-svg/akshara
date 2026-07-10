"""Assembly + rendering — turn validated slots into a numbered paper and render it.

Rejected slots are excluded (the validation gate already flagged them); the remaining valid
slots are renumbered within their sections. Renders to a structured dict (JSON) and to a
teacher-facing Markdown paper with an answer key.
"""
from __future__ import annotations

from dataclasses import asdict
from typing import Dict, List

from kie.qpgen.models import (Blueprint, Difficulty, GeneratedPaper, PaperRequest, QuestionSlot,
                              RenderMode, SlotStatus)
from kie.qpgen.scope import SyllabusScope


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
    return {
        "title": paper.title, "exam_profile": paper.exam_profile, "subjects": paper.subjects,
        "blueprint": paper.blueprint_name, "total_marks": paper.total_marks,
        "total_questions": paper.total_questions, "filled": paper.filled, "spec_only": paper.spec_only,
        "warnings": paper.warnings, "provenance": paper.provenance,
        "questions": [
            {"number": s.number, "section": s.section, "type": s.question_type, "marks": s.marks,
             "subject": s.subject, "concept": s.concept_title, "concept_code": s.concept_code,
             "bloom": s.bloom, "difficulty": s.difficulty, "status": s.status,
             "render_mode": s.render_mode, "stem": s.stem, "answer": s.answer,
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

    section_notes = paper.provenance.get("section_notes") or {}
    current = None
    for s in paper.slots:
        if s.section != current:
            current = s.section
            low = s.section.lower()
            head = s.section if ("section" in low or "part" in low) else f"Section {s.section}"
            L += ["", f"## {head}", ""]
            for note in section_notes.get(s.section, []):
                L.append(f"*{note}*")
            if section_notes.get(s.section):
                L.append("")
        body = s.stem or f"[{s.question_type} on {s.concept_title}]"
        L.append(f"**{s.number}.** {body}  *({s.marks} mark{'s' if s.marks != 1 else ''})*")
        if s.render_mode == RenderMode.SPEC_ONLY:
            L.append(f"   _[objective item — author via approved AI; concept: {s.concept_title}]_")
        L.append("")

    # answer key
    L += ["", "---", "", "## Answer Key & Marking", ""]
    for s in paper.slots:
        if s.status == SlotStatus.FILLED and s.answer:
            L.append(f"**{s.number}.** {s.answer}")
        else:
            L.append(f"**{s.number}.** _[to be authored — {s.question_type} on {s.concept_title}]_")
    if paper.warnings:
        L += ["", "---", "", "## Generation Notes", ""]
        L += [f"- {w}" for w in paper.warnings]
    return "\n".join(L) + "\n"
