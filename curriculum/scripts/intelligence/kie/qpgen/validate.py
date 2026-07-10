"""Validation gate — the hard safety net. Nothing out-of-syllabus, wrong-subject, garbage,
or duplicate may reach the paper.

HARD (reject the slot): concept not in the resolved scope; subject outside the scope; concept
title fails the sanitizer; unknown type / non-positive marks; a filled stem that does not
reference its concept; exam-profile mismatch; duplicate (concept, type).
SOFT (report only): blueprint count deviations (usually an upstream pool shortfall).

Rejected slots carry their reasons and are excluded from the final paper by the engine.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List

from kie.qpgen import sanitize
from kie.qpgen.models import Blueprint, QuestionSlot, QuestionType, SlotStatus
from kie.qpgen.scope import SyllabusScope


@dataclass
class ValidationReport:
    ok: bool
    total_slots: int
    valid_slots: int
    rejected_slots: int
    violations: List[str] = field(default_factory=list)
    conformance: List[str] = field(default_factory=list)
    boundary_ok: bool = True


def validate_slot(slot: QuestionSlot, scope: SyllabusScope) -> List[str]:
    v: List[str] = []
    if not scope.in_scope(slot.concept_code):
        v.append(f"OUT_OF_SYLLABUS: concept {slot.concept_code!r} not in resolved scope")
    if slot.subject not in scope.subjects:
        v.append(f"WRONG_SUBJECT: {slot.subject!r} not in scope subjects {scope.subjects}")
    if not sanitize.is_clean_concept(slot.concept_title):
        v.append(f"UNCLEAN_CONCEPT: title {slot.concept_title!r} failed the sanitizer")
    if slot.question_type not in QuestionType.ALL:
        v.append(f"BAD_TYPE: {slot.question_type!r}")
    if slot.marks <= 0:
        v.append(f"BAD_MARKS: {slot.marks}")
    prof = (slot.provenance or {}).get("exam")
    if prof and prof != scope.exam_profile:
        v.append(f"EXAM_MISMATCH: slot exam {prof!r} != scope {scope.exam_profile!r}")
    # a FILLED (deterministic) question must actually reference its in-scope concept
    if slot.status == SlotStatus.FILLED:
        if not slot.stem or slot.concept_title.lower() not in (slot.stem or "").lower():
            v.append("UNGROUNDED_STEM: filled stem does not reference its concept")
    return v


def validate_paper(slots: List[QuestionSlot], blueprint: Blueprint, scope: SyllabusScope) -> ValidationReport:
    violations: List[str] = []
    seen: set = set()
    rejected = 0

    for s in slots:
        reasons = validate_slot(s, scope)
        key = (s.concept_code, s.question_type)
        if key in seen:
            reasons.append(f"DUPLICATE: {s.concept_code}/{s.question_type} already used")
        else:
            seen.add(key)
        if reasons:
            s.status = SlotStatus.REJECTED
            s.validation = reasons
            rejected += 1
            violations.extend(f"Q{s.number}: {r}" for r in reasons)

    valid = [s for s in slots if s.status != SlotStatus.REJECTED]

    # blueprint conformance (soft): compare non-rejected counts per (section, type) to target
    target: Dict = {}
    for c in blueprint.cells:
        target[(c.section, c.question_type)] = target.get((c.section, c.question_type), 0) + c.count
    got: Dict = {}
    for s in valid:
        got[(s.section, s.question_type)] = got.get((s.section, s.question_type), 0) + 1
    conformance: List[str] = []
    for k, want in sorted(target.items()):
        have = got.get(k, 0)
        if have != want:
            conformance.append(f"section {k[0]}/{k[1]}: have {have}, blueprint wants {want}")

    boundary_ok = not any(("OUT_OF_SYLLABUS" in x or "WRONG_SUBJECT" in x or "UNCLEAN_CONCEPT" in x)
                          for x in violations)
    return ValidationReport(
        ok=(rejected == 0), total_slots=len(slots), valid_slots=len(valid),
        rejected_slots=rejected, violations=violations, conformance=conformance,
        boundary_ok=boundary_ok)
