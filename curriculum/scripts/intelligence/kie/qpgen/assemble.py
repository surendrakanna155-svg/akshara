"""Assembly + rendering — turn validated slots into a numbered paper and render it.

Rejected slots are excluded (the validation gate already flagged them); the remaining valid
slots are renumbered within their sections. Renders to a structured dict (JSON) and to a
teacher-facing Markdown paper with an answer key.
"""
from __future__ import annotations

from dataclasses import asdict
from typing import Dict, List

from kie.qpgen.models import (Blueprint, GeneratedPaper, PaperRequest, QuestionSlot,
                              RenderMode, SlotStatus)
from kie.qpgen.scope import SyllabusScope


def assemble(request: PaperRequest, scope: SyllabusScope, blueprint: Blueprint,
             slots: List[QuestionSlot], warnings: List[str]) -> GeneratedPaper:
    valid = [s for s in slots if s.status != SlotStatus.REJECTED]
    # renumber within blueprint section order
    order = {sec: i for i, sec in enumerate(blueprint.sections())}
    valid.sort(key=lambda s: (order.get(s.section, 99), s.number))
    for i, s in enumerate(valid, start=1):
        s.number = i

    filled = sum(1 for s in valid if s.status == SlotStatus.FILLED)
    spec = sum(1 for s in valid if s.status == SlotStatus.SPEC)
    paper = GeneratedPaper(
        request=request, blueprint_name=blueprint.name,
        title=request.title or f"{scope.exam_profile} Practice Paper",
        subjects=scope.subjects, exam_profile=scope.exam_profile, slots=valid,
        warnings=warnings, total_marks=sum(s.marks for s in valid),
        total_questions=len(valid), filled=filled, spec_only=spec,
        provenance={"scope": scope.stats, "blueprint": blueprint.name, "seed": request.seed,
                    "instructions": blueprint.instructions})
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
    L = [
        f"# {paper.title}",
        "",
        f"**Exam profile:** {paper.exam_profile}  ·  **Subjects:** {', '.join(paper.subjects)}  ·  "
        f"**Total marks:** {paper.total_marks}  ·  **Questions:** {paper.total_questions}",
        "",
    ]
    instructions = paper.provenance.get("instructions") or []
    if instructions:
        L += ["**General Instructions**", ""]
        L += [f"{i}. {t}" for i, t in enumerate(instructions, 1)]
        L.append("")

    current = None
    for s in paper.slots:
        if s.section != current:
            current = s.section
            L += ["", f"## Section {s.section}", ""]
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
