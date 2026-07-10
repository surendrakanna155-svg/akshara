"""Authentic examination-blueprint library — deterministic reference data (Phase 3).

Each factory returns a Blueprint that mirrors the REAL structure of a public examination:
authentic sections, marks distribution, question types, difficulty progression (cells run
easy → hard within a section), a Bloom spread, and the exam's own instructions (duration,
negative marking, internal choice). Like presets/chapters/templates this is curated reference
data — it grows without any engine change.

Modelling notes (honest + deterministic):
  * `count` is the number of questions that COUNT toward marks, so `total_marks` equals the
    official paper total. Internal choice ("attempt any N of M", CBSE/SCERT "OR" alternatives)
    is carried as an instruction + a cell `choose`/`note`, never by inflating the marks total.
  * Board papers (CBSE/SCERT) reproduce the published section blueprint; the current CBSE/SCERT
    counts are used, and any item the KIE cannot yet ground stays an honest spec downstream.
  * JEE Advanced changes format year to year — its blueprint here is a representative recent
    structure (mixed single-correct / numerical / match), clearly labelled as such.
"""
from __future__ import annotations

from typing import Callable, Dict

from kie.qpgen.models import Blueprint, BlueprintCell, Bloom, Difficulty, QuestionType, Subject

_C = BlueprintCell
E, M, H = Difficulty.EASY, Difficulty.MEDIUM, Difficulty.HARD
RE, UN, AP, AN, HO = Bloom.REMEMBER, Bloom.UNDERSTAND, Bloom.APPLY, Bloom.ANALYZE, Bloom.HOTS
MCQ, NUM, AR, MATCH = (QuestionType.MCQ, QuestionType.NUMERICAL,
                       QuestionType.ASSERTION_REASON, QuestionType.MATCH)
SA, LA = QuestionType.SHORT_ANSWER, QuestionType.LONG_ANSWER


# ── NEET (UG) — 720 marks, all single-correct MCQ, 3 subjects, negative marking ──────────
def neet() -> Blueprint:
    cells = []
    # Physics & Chemistry: Section A 35 compulsory + Section B attempt 10 of 15
    for subj in ("Physics", "Chemistry"):
        cells += [
            _C(f"{subj} · Section A", MCQ, 4, 35, bloom=UN, difficulty=M, subject=subj,
               note="All 35 questions are compulsory."),
            _C(f"{subj} · Section B", MCQ, 4, 10, bloom=AP, difficulty=H, choose=15, subject=subj,
               note="15 questions given; attempt any 10."),
        ]
    # Biology (Botany + Zoology): 90 that count
    cells += [
        _C("Biology · Section A", MCQ, 4, 70, bloom=UN, difficulty=M, subject="Biology",
           note="All 70 questions are compulsory (Botany + Zoology)."),
        _C("Biology · Section B", MCQ, 4, 20, bloom=AP, difficulty=H, choose=30, subject="Biology",
           note="30 questions given; attempt any 20."),
    ]
    return Blueprint(
        "neet", cells=cells, exam="NEET (UG)", duration_min=200,
        negative_marking="+4 for correct, −1 for incorrect, 0 if unattempted",
        weightage={"Physics": 25, "Chemistry": 25, "Biology": 50},
        instructions=[
            "Duration: 3 hours 20 minutes. Maximum marks: 720.",
            "All questions are single-correct-answer objective type (4 marks each).",
            "Negative marking: +4 for each correct answer, −1 for each incorrect answer.",
            "Each subject has Section A (compulsory) and Section B (internal choice).",
        ])


# ── JEE Main — 300 marks, 3 subjects, Section A MCQ + Section B numerical-value ──────────
def jee_main() -> Blueprint:
    cells = []
    for subj in ("Physics", "Chemistry", "Mathematics"):
        cells += [
            _C(f"{subj} · Section A", MCQ, 4, 20, bloom=AP, difficulty=M, subject=subj,
               note="20 single-correct MCQs (compulsory)."),
            _C(f"{subj} · Section B", NUM, 4, 5, bloom=HO, difficulty=H, subject=subj,
               note="5 numerical-value questions (all compulsory)."),
        ]
    return Blueprint(
        "jee_main", cells=cells, exam="JEE (Main)", duration_min=180,
        negative_marking="+4 for correct, −1 for incorrect (both sections)",
        weightage={"Physics": 33, "Chemistry": 33, "Mathematics": 34},
        instructions=[
            "Duration: 3 hours. Maximum marks: 300.",
            "Section A: single-correct MCQs. Section B: numerical-value answers.",
            "Negative marking: +4 correct, −1 incorrect in both sections.",
        ])


# ── JEE Advanced — representative recent structure (format varies yearly) ────────────────
def jee_advanced() -> Blueprint:
    cells = []
    for subj in ("Physics", "Chemistry", "Mathematics"):
        cells += [
            _C(f"{subj} · Single Correct", MCQ, 3, 6, bloom=AP, difficulty=M, subject=subj,
               note="One option correct (+3, −1)."),
            _C(f"{subj} · Numerical Value", NUM, 4, 4, bloom=HO, difficulty=H, subject=subj,
               note="Numerical answer (+4, no negative marking)."),
            _C(f"{subj} · Matching", MATCH, 3, 1, bloom=AN, difficulty=H, subject=subj,
               note="Match-the-column (List I with List II)."),
        ]
    return Blueprint(
        "jee_advanced", cells=cells, exam="JEE (Advanced) — representative", duration_min=180,
        negative_marking="varies by section (partial marking; see each section)",
        weightage={"Physics": 33, "Chemistry": 33, "Mathematics": 34},
        instructions=[
            "Representative structure — JEE (Advanced) format changes every year.",
            "Two papers in the actual exam; this is one representative paper.",
            "Section marking varies: single-correct (+3/−1), numerical (+4/0), matching (+3).",
        ])


# ── CBSE Class X — Science (Theory 80) ──────────────────────────────────────────────────
def cbse_x_science() -> Blueprint:
    cells = [
        _C("Section A", MCQ, 1, 16, bloom=RE, difficulty=E, note="Objective / multiple-choice."),
        _C("Section A", AR, 1, 4, bloom=UN, difficulty=M, note="Assertion–Reason type."),
        _C("Section B", SA, 2, 6, bloom=UN, difficulty=M, choose=6,
           note="Very short answer; internal choice in some questions."),
        _C("Section C", SA, 3, 7, bloom=AP, difficulty=M, choose=7,
           note="Short answer; internal choice in some questions."),
        _C("Section D", LA, 5, 3, bloom=AN, difficulty=H, choose=3,
           note="Long answer; internal choice provided."),
        _C("Section E", SA, 4, 3, bloom=AN, difficulty=H,
           note="Case-based / source-based integrated questions."),
    ]
    return Blueprint(
        "cbse_x_science", cells=cells, exam="CBSE Class X — Science (Theory)", duration_min=180,
        weightage={"Physics": 33, "Chemistry": 33, "Biology": 34},
        instructions=[
            "Duration: 3 hours. Maximum marks: 80 (theory).",
            "All questions are compulsory; internal choice is provided in some questions.",
            "Section A: objective (1 mark). Section B: 2 marks. Section C: 3 marks. "
            "Section D: 5 marks. Section E: case-based (4 marks).",
        ])


# ── CBSE Class XII — Physics (Theory 70) ────────────────────────────────────────────────
def cbse_xii_physics() -> Blueprint:
    cells = [
        _C("Section A", MCQ, 1, 16, bloom=RE, difficulty=E, note="Objective / multiple-choice."),
        _C("Section A", AR, 1, 2, bloom=UN, difficulty=M, note="Assertion–Reason type."),
        _C("Section B", SA, 2, 7, bloom=UN, difficulty=M, choose=7, note="Very short answer."),
        _C("Section C", SA, 3, 5, bloom=AP, difficulty=M, choose=5, note="Short answer."),
        _C("Section D", SA, 4, 2, bloom=AN, difficulty=H, note="Case-based questions."),
        _C("Section E", LA, 5, 3, bloom=HO, difficulty=H, choose=3,
           note="Long answer; internal choice provided."),
    ]
    return Blueprint(
        "cbse_xii_physics", cells=cells, exam="CBSE Class XII — Physics (Theory)", duration_min=180,
        instructions=[
            "Duration: 3 hours. Maximum marks: 70 (theory).",
            "All questions are compulsory; internal choice is provided in some questions.",
            "Sections A–E carry 1, 2, 3, 4 and 5 marks respectively.",
        ])


# ── Telangana SCERT (SSC) Class X — Science (representative, 40) ─────────────────────────
def ts_scert_x_science() -> Blueprint:
    cells = [
        _C("Part A · Section I", SA, 1, 6, bloom=RE, difficulty=E,
           note="Very short answer (answer in 1–2 sentences)."),
        _C("Part A · Section II", SA, 2, 6, bloom=UN, difficulty=M,
           note="Short answer."),
        _C("Part A · Section III", LA, 4, 3, bloom=AN, difficulty=H, choose=3,
           note="Essay type with internal choice (answer any 3 of the given)."),
        _C("Part B · Objective", MCQ, 1, 10, bloom=RE, difficulty=E,
           note="Objective (bits) — 20 bits of ½ mark are grouped here as 10 × 1."),
    ]
    return Blueprint(
        "ts_scert_x_science", cells=cells,
        exam="Telangana SSC Class X — Science (representative)", duration_min=165,
        weightage={"Physical Science": 50, "Biological Science": 50},
        instructions=[
            "Representative Telangana SSC Science blueprint. Maximum marks: 40.",
            "Part A carries essay/short/very-short questions; Part B carries objective bits.",
            "Internal choice is provided in the essay section.",
            "Assessment maps to Academic Standards (AS1–AS7).",
        ])


# ── Andhra Pradesh SCERT (SSC) Class X — Science (representative, 40) ────────────────────
def ap_scert_x_science() -> Blueprint:
    cells = [
        _C("Section I", SA, 1, 6, bloom=RE, difficulty=E, note="Very short answer."),
        _C("Section II", SA, 2, 6, bloom=UN, difficulty=M, choose=8,
           note="Short answer; answer any 6 of 8."),
        _C("Section III", LA, 4, 3, bloom=AN, difficulty=H, choose=4,
           note="Essay type; answer any 3 of 4."),
        _C("Section IV", MCQ, 1, 10, bloom=RE, difficulty=E, note="Objective / multiple-choice."),
    ]
    return Blueprint(
        "ap_scert_x_science", cells=cells,
        exam="Andhra Pradesh SSC Class X — Science (representative)", duration_min=165,
        weightage={"Physical Science": 50, "Biological Science": 50},
        instructions=[
            "Representative AP SSC Science blueprint. Maximum marks: 40.",
            "Sections carry very-short, short, essay and objective questions.",
            "Internal choice is provided in the short-answer and essay sections.",
            "Assessment maps to Academic Standards (AS1–AS7).",
        ])


AUTHENTIC_BLUEPRINTS: Dict[str, Callable[[], Blueprint]] = {
    "neet": neet,
    "jee_main": jee_main,
    "jee_advanced": jee_advanced,
    "cbse_x_science": cbse_x_science,
    "cbse_xii_physics": cbse_xii_physics,
    "ts_scert_x_science": ts_scert_x_science,
    "ap_scert_x_science": ap_scert_x_science,
}
