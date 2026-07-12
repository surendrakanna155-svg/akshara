"""Question Paper Generation Engine — value types.

Deterministic + stdlib-only. Enums are plain string constants so they round-trip through
SQLite/JSON. The engine reads the local certified KIE (`kie.db`) as its ONLY knowledge
source and never mutates it.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional


class Subject:
    PHYSICS = "Physics"
    CHEMISTRY = "Chemistry"
    BIOLOGY = "Biology"
    MATHEMATICS = "Mathematics"
    ALL = (PHYSICS, CHEMISTRY, BIOLOGY, MATHEMATICS)


class QuestionType:
    MCQ = "mcq"
    NUMERICAL = "numerical"
    SHORT_ANSWER = "short_answer"
    LONG_ANSWER = "long_answer"
    ASSERTION_REASON = "assertion_reason"
    MATCH = "match"
    ALL = (MCQ, NUMERICAL, SHORT_ANSWER, LONG_ANSWER, ASSERTION_REASON, MATCH)


class Difficulty:
    EASY = "easy"
    MEDIUM = "medium"
    HARD = "hard"
    ALL = (EASY, MEDIUM, HARD)
    RANK = {EASY: 0, MEDIUM: 1, HARD: 2}


class Bloom:
    REMEMBER = "remember"
    UNDERSTAND = "understand"
    APPLY = "apply"
    ANALYZE = "analyze"
    HOTS = "hots"
    ALL = (REMEMBER, UNDERSTAND, APPLY, ANALYZE, HOTS)


class RenderMode:
    DETERMINISTIC = "deterministic"   # original stem rendered with no AI
    SPEC_ONLY = "spec_only"           # structural spec left for the GATED AI fill


class SlotStatus:
    FILLED = "filled"       # a concrete question (deterministic or AI-filled + validated)
    SPEC = "spec"           # a validated spec awaiting a (gated) AI author
    REJECTED = "rejected"   # failed validation → never in the paper


@dataclass(frozen=True)
class PaperRequest:
    """A generation request. `exam` is the primary certified scope dimension; `board`/
    `class_label` are optional aliases resolved to an exam profile (presets)."""
    exam: Optional[str] = None                 # NEET | JEE_MAIN | JEE_ADVANCED | AIIMS | FOUNDATION
    board: Optional[str] = None                # alias → exam profile
    class_label: Optional[str] = None          # alias → exam profile / grade band
    subjects: tuple = ()                        # subset of Subject.ALL; empty ⇒ profile default
    chapters: tuple = ()                        # free-text chapter/topic filters (optional)
    blueprint_preset: Optional[str] = None      # named preset; else `blueprint` is used
    difficulty_mix: Optional[Dict[str, float]] = None  # soft target, e.g. {easy:.3,medium:.5,hard:.2}
    title: Optional[str] = None
    seed: int = 0                               # deterministic seed — different seeds → different papers
    exclude_concepts: tuple = ()                # concept_codes to avoid (cross-paper non-overlap / Set A/B)
    allow_ai_fill: bool = False                 # gated; AI is NEVER called unless True AND authorized


@dataclass
class BlueprintCell:
    section: str
    question_type: str
    marks_each: int
    count: int                                  # number of questions that COUNT toward marks
    bloom: Optional[str] = None
    difficulty: Optional[str] = None
    note: Optional[str] = None
    subject: Optional[str] = None               # bind this cell to one subject (per-subject
                                                #   sections, e.g. NEET "Physics · Section A")
    topic: Optional[str] = None                 # optional chapter/topic hint (weightage / display)
    choose: Optional[int] = None                # internal choice: this cell is "attempt any `count`
                                                #   of `choose` printed" (rendered as an instruction;
                                                #   marks stay count·marks_each so totals are official)

    @property
    def total_marks(self) -> int:
        return self.marks_each * self.count


@dataclass
class Blueprint:
    name: str
    cells: List[BlueprintCell] = field(default_factory=list)
    instructions: List[str] = field(default_factory=list)
    exam: Optional[str] = None                  # authentic exam label (e.g. "NEET (UG)")
    duration_min: Optional[int] = None          # official duration in minutes
    negative_marking: Optional[str] = None       # e.g. "-1 per incorrect answer" (None ⇒ no negative)
    weightage: Optional[Dict[str, int]] = None   # chapter/topic → target % (display + Phase-4 target)

    @property
    def total_questions(self) -> int:
        return sum(c.count for c in self.cells)

    @property
    def total_marks(self) -> int:
        return sum(c.total_marks for c in self.cells)

    def sections(self) -> List[str]:
        seen, out = set(), []
        for c in self.cells:
            if c.section not in seen:
                seen.add(c.section)
                out.append(c.section)
        return out


@dataclass
class QuestionSlot:
    """One question position in the paper, bound to a KIE concept + pattern."""
    number: int
    section: str
    concept_code: str
    concept_title: str
    subject: Optional[str]
    question_type: str
    marks: int
    bloom: Optional[str]
    difficulty: Optional[str]
    render_mode: str
    status: str
    stem: Optional[str] = None
    options: Optional[List[str]] = None
    answer: Optional[str] = None
    solution: Optional[str] = None
    provenance: Dict = field(default_factory=dict)   # frequency, years, exam, pattern_id
    validation: List[str] = field(default_factory=list)
    # ── Phase-A5 INERT engine-v2 seam (additive only) ────────────────────────────────────────────
    # Optional fields the quality-first architecture (kie/qie) will populate in later phases. Nothing in
    # the engine reads or writes them yet, so generation behavior and the frozen matrix are UNCHANGED.
    # This is the minimal reviewed seam per OPUS_FABLE_RECONCILIATION_RECORD.md §4 surface #1 — no
    # selection/label/dedup behavior is altered here (those are Phase C/D changes, benchmark-gated).
    item_model_id: Optional[str] = None
    lane: Optional[str] = None
    difficulty_drivers: Optional[Dict] = None
    gate_verdicts: List = field(default_factory=list)
    solution_steps: Optional[List] = None


@dataclass
class GeneratedPaper:
    request: PaperRequest
    blueprint_name: str
    title: str
    subjects: List[str]
    exam_profile: str
    slots: List[QuestionSlot] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    total_marks: int = 0
    total_questions: int = 0
    filled: int = 0
    spec_only: int = 0
    provenance: Dict = field(default_factory=dict)
