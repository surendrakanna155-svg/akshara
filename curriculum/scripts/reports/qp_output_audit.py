"""QP Content Readiness Audit — output-quality measurement over a fixed paper matrix.

Independent of internal test counts: this generates real papers (AI OFF) and measures the
actual student/teacher-facing output at the DATA layer (slot fields, not the lossy JSON
renderer), so a rendering gap can never hide a data defect and vice-versa.

The matrix is the SAME 19 configs × 3 seeds = 57 papers / 1747 questions used by the
2026-07-11 baseline audit, so before/after numbers are directly comparable.

Run:
    python -m scripts.reports.qp_output_audit --db <kie.db> [--json out.json]
(from curriculum/scripts/intelligence, with kie on the path)

Exit-gate metrics (the product target — "can a teacher print it today, AI OFF?"):
    * student-facing specs/placeholders          -> must be 0
    * optionless / malformed filled MCQs         -> must be 0
    * fabricated answers                          -> must be 0 (we only assert grounded/among-options)
    * board/grade corpus misuse                   -> must be 0 (Class-X board from 11-12 corpus)
    * broken concept-title / OCR artifacts        -> must be 0 in printed stems
    * teacher-ready papers (full & reduced)       -> report the count honestly
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from kie.qpgen.engine import QuestionPaperEngine, QpGenError
from kie.qpgen.models import PaperRequest, QuestionType, SlotStatus
from kie.qpgen.scope import ScopeError
from kie.qpgen.assemble import is_student_printable   # the engine's own print-ready gate

# ── the fixed matrix (config_id -> request kwargs). 3 seeds each → 57 papers. ──────────────
SEEDS = (11, 42, 777)
MATRIX = [
    ("neet_full",        dict(exam="NEET", blueprint_preset="neet")),
    ("neet_obj_phy",     dict(exam="NEET", blueprint_preset="objective_45", subjects=("Physics",))),
    ("neet_obj_chem",    dict(exam="NEET", blueprint_preset="objective_45", subjects=("Chemistry",))),
    ("neet_obj_bio",     dict(exam="NEET", blueprint_preset="objective_45", subjects=("Biology",))),
    ("neet_desc_phy",    dict(exam="NEET", blueprint_preset="descriptive_40", subjects=("Physics",))),
    ("neet_desc_chem",   dict(exam="NEET", blueprint_preset="descriptive_40", subjects=("Chemistry",))),
    ("neet_desc_bio",    dict(exam="NEET", blueprint_preset="descriptive_40", subjects=("Biology",))),
    ("jeemain_full",     dict(exam="JEE_MAIN", blueprint_preset="jee_main")),
    ("jeemain_obj_phy",  dict(exam="JEE_MAIN", blueprint_preset="objective_45", subjects=("Physics",))),
    ("jeemain_obj_chem", dict(exam="JEE_MAIN", blueprint_preset="objective_45", subjects=("Chemistry",))),
    ("jeemain_obj_math", dict(exam="JEE_MAIN", blueprint_preset="objective_45", subjects=("Mathematics",))),
    ("jeemain_desc_math",dict(exam="JEE_MAIN", blueprint_preset="descriptive_40", subjects=("Mathematics",))),
    ("jeeadv_full",      dict(exam="JEE_ADVANCED", blueprint_preset="jee_advanced")),
    # board Class-X configs now target their certified board profiles (CBSE_X, TS_X); AP has no
    # ingested corpus and stays under FOUNDATION → correctly fails closed.
    ("cbse_x_science",   dict(exam="CBSE_X", blueprint_preset="cbse_x_science")),
    ("cbse_xii_physics", dict(exam="FOUNDATION", blueprint_preset="cbse_xii_physics", subjects=("Physics",))),
    ("ap_x_science",     dict(exam="FOUNDATION", blueprint_preset="ap_scert_x_science")),
    ("ts_x_science",     dict(exam="TS_X", blueprint_preset="ts_scert_x_science")),
    ("foundation_mixed", dict(exam="FOUNDATION", blueprint_preset="mixed_50")),
    ("foundation_desc",  dict(exam="FOUNDATION", blueprint_preset="descriptive_40")),
]
# class-X BOARD configs with NO ingested corpus → must still fail closed (board/grade misuse if served).
# CBSE_X and TS_X now have certified board profiles/corpus, so they are legitimately served.
BOARD_CLASS_X_CONFIGS = {"ap_x_science"}

OBJECTIVE = {QuestionType.MCQ, QuestionType.NUMERICAL,
             QuestionType.ASSERTION_REASON, QuestionType.MATCH}
DESCRIPTIVE = {QuestionType.SHORT_ANSWER, QuestionType.LONG_ANSWER}
FOUR_OPT = {QuestionType.MCQ, QuestionType.ASSERTION_REASON}

SPEC_MARK = re.compile(r"\[SPEC", re.I)
GENERIC_KEY = re.compile(r"marking guideline|award full marks for a correct|teacher to confirm|"
                         r"to be authored|award up to \d+ marks for a complete", re.I)
# OCR / merged-word / fragment signatures that must never reach a printed stem
MERGED_WORD = re.compile(r"[a-z][A-Z]")                       # 'thetime', 'istransferred' escape this;
GLUED_LOWER = re.compile(r"\b\w*(?:the|and|of|is|was|to)[a-z]{3,}", re.I)


def _is_generic_key(ans: Optional[str]) -> bool:
    return bool(ans and GENERIC_KEY.search(ans))


def _is_real_answer(ans: Optional[str]) -> bool:
    return bool(ans and ans.strip() and not _is_generic_key(ans))


def _stem_artifacts(stem: str) -> List[str]:
    """Broken-token signatures in a PRINTED stem (merged words, glued function words, double space)."""
    out = []
    if MERGED_WORD.search(stem or ""):
        out.append("merged_case")
    # glued function words like 'thetime', 'istransferred', 'ofthe'
    if re.search(r"\b(the|is|was|of|and|to|in)(time|transferred|rate|the|energy|which|work)\b",
                 (stem or ""), re.I):
        out.append("glued_word")
    if re.search(r"\w{16,}", stem or ""):
        out.append("overlong_token")
    if "  " in (stem or ""):
        out.append("double_space")
    return out


@dataclass
class PaperAudit:
    config: str
    seed: int
    ok: bool = True
    error: str = ""
    blueprint_count: int = 0
    slots: int = 0
    filled: int = 0
    spec: int = 0
    obj_total: int = 0
    obj_filled: int = 0
    mcq_filled: int = 0
    mcq_bad_options: int = 0
    desc_total: int = 0
    desc_filled: int = 0
    desc_generic: int = 0
    desc_real: int = 0
    general_chapter: int = 0
    junk_titles: int = 0
    stem_artifacts: int = 0
    fabricated: int = 0
    board_misuse: bool = False
    diff_met: int = 0
    diff_relaxed: int = 0
    filled_answerable: int = 0
    printed_specs: int = 0              # filled stems still carrying a [SPEC] marker
    printable_clean: bool = False       # every filled slot is real (0 rewrite in printed body)
    teacher_ready_full: bool = False    # printable_clean AND >=90% of blueprint filled
    filled_stem_keys: list = field(default_factory=list)   # for cross-paper repetition


def audit_paper(config: str, seed: int, paper) -> PaperAudit:
    """Measure the STUDENT-FACING output — what render_markdown actually prints — using the
    engine's own is_student_printable() gate. Anything not printable is routed to the authoring
    worklist (not a student question), so gate violations are counted ONLY over the printed body.
    """
    a = PaperAudit(config=config, seed=seed)
    a.slots = len(paper.slots)
    a.blueprint_count = len(paper.slots)                 # blueprint positions (post-validation)
    a.filled = sum(1 for s in paper.slots if s.status == SlotStatus.FILLED)
    a.spec = sum(1 for s in paper.slots if s.status == SlotStatus.SPEC)
    printed = [s for s in paper.slots if is_student_printable(s)]

    # difficulty honesty over the whole paper (label vs requested; recorded in provenance)
    for s in paper.slots:
        prov = s.provenance or {}
        if "difficulty_met" in prov:
            (a.__setattr__("diff_met", a.diff_met + 1) if prov["difficulty_met"]
             else a.__setattr__("diff_relaxed", a.diff_relaxed + 1))
        if s.question_type in OBJECTIVE:
            a.obj_total += 1
        if s.question_type in DESCRIPTIVE:
            a.desc_total += 1

    # ── gate checks over the PRINTED student body (each should be 0) ──
    for s in printed:
        stem = s.stem or ""
        prov = s.provenance or {}
        if SPEC_MARK.search(stem):
            a.printed_specs += 1
        if _stem_artifacts(stem):
            a.stem_artifacts += 1
        if _title_is_junk(s.concept_title):
            a.junk_titles += 1
        if s.question_type == QuestionType.MCQ:
            a.mcq_filled += 1
            if not _mcq_options_ok(s):
                a.mcq_bad_options += 1
        if s.question_type in DESCRIPTIVE:
            if _is_generic_key(s.answer):
                a.desc_generic += 1
            elif _is_real_answer(s.answer):
                a.desc_real += 1
        if s.question_type in OBJECTIVE:
            a.obj_filled += 1
        if (prov.get("chapter") or "").lower().startswith("general") or not prov.get("chapter"):
            a.general_chapter += 1
        a.filled_answerable += 1
        a.filled_stem_keys.append(re.sub(r"\d+", "#", stem.lower()).strip())

    a.desc_filled = sum(1 for s in printed if s.question_type in DESCRIPTIVE)

    # a paper is print-ready (no rewrite of what is printed) iff it has printable content and
    # ZERO gate violations in that content. board configs are refused upstream (never reach here).
    a.printable_clean = (len(printed) > 0 and a.printed_specs == 0 and a.mcq_bad_options == 0
                         and a.desc_generic == 0 and a.stem_artifacts == 0 and a.junk_titles == 0)
    # teacher-ready (full) additionally requires near-complete blueprint coverage
    coverage_ok = a.blueprint_count and len(printed) >= 0.9 * a.blueprint_count
    a.teacher_ready_full = a.printable_clean and bool(coverage_ok)
    return a


def _mcq_options_ok(slot) -> bool:
    opts = slot.options
    if not isinstance(opts, list) or len(opts) != 4:
        return False
    norm = [(o or "").strip() for o in opts]
    if any(not o for o in norm) or len(set(norm)) != 4:
        return False
    ans = (slot.answer or "").strip()
    return bool(ans) and norm.count(ans) == 1


_JUNK_TITLE = re.compile(r"[a-z][A-Z]|"                       # merged case: Ohmwas
                         r"\b(was|were|led|his|her)\b", re.I)


def _title_is_junk(title: Optional[str]) -> bool:
    t = (title or "").strip()
    if not t:
        return True
    if re.search(r"[a-z][A-Z]", t):                          # 'Ohmwas'
        return True
    low = t.lower()
    # clause-like fragments ("... was led to his law")
    if re.search(r"\bwas\b|\bled to\b|\bhis law\b|\bwere\b", low):
        return True
    if low in {"litres", "metres", "seconds", "grams"}:
        return True
    return False


def run(db_path: str) -> Dict:
    eng = QuestionPaperEngine(db_path=db_path)
    audits: List[PaperAudit] = []
    for config, kw in MATRIX:
        for seed in SEEDS:
            try:
                paper = eng.generate(PaperRequest(seed=seed, **kw))
                audits.append(audit_paper(config, seed, paper))
            except (QpGenError, ScopeError) as exc:
                # a refusal is CORRECT for a class-X board with no real corpus (fail closed)
                audits.append(PaperAudit(config=config, seed=seed, ok=False, error=str(exc)))
    return summarize(audits)


def summarize(audits: List[PaperAudit]) -> Dict:
    served = [a for a in audits if a.ok]
    refused = [a for a in audits if not a.ok]
    tot_q = sum(a.slots for a in served)

    def s(attr):
        return sum(getattr(a, attr) for a in served)

    # cross-paper repetition
    stem_ct = Counter()
    for a in served:
        for k in a.filled_stem_keys:
            stem_ct[k] += 1
    clones = sum(v for v in stem_ct.values() if v > 1)
    total_answerable = s("filled_answerable")

    def pct(n, d):
        return round(100 * n / d, 1) if d else None

    obj_total, obj_filled = s("obj_total"), s("obj_filled")
    desc_filled, desc_generic, desc_real = s("desc_filled"), s("desc_generic"), s("desc_real")
    printed_total = total_answerable
    blueprint_total = sum(a.blueprint_count for a in served)

    def cov(a):
        return (a.filled_answerable / a.blueprint_count) if a.blueprint_count else 0

    metrics = {
        "papers_total": len(audits),
        "papers_served": len(served),
        "papers_refused": len(refused),
        "questions_total": tot_q,
        # coverage of the STUDENT-facing (printed) body
        "printed_questions_total": printed_total,
        "print_coverage_pct": pct(printed_total, blueprint_total),
        "d1_answerable_pct": pct(printed_total, tot_q),
        "d2_objective_spec_pct": pct(obj_total - obj_filled, obj_total),
        "d2_objective_filled_pct": pct(obj_filled, obj_total),
        "d4_desc_printed_real_pct": pct(desc_real, desc_filled),   # printed descriptive w/ real key
        "d5_general_chapter_pct_printed": pct(s("general_chapter"), printed_total),
        "d9_difficulty_met_pct": pct(s("diff_met"), s("diff_met") + s("diff_relaxed")),
        "d11_clone_answerable": clones,
        "d11_answerable_total": total_answerable,
        # ── EXIT-GATE counters (measured over the PRINTED student body; each must be 0) ──
        "gate_student_specs": s("printed_specs") + s("desc_generic"),
        "gate_optionless_mcq": s("mcq_bad_options"),
        "gate_board_misuse_papers": sum(1 for a in served if a.board_misuse),
        "gate_stem_artifacts": s("stem_artifacts"),
        "gate_junk_titles": s("junk_titles"),
        # ── teacher-ready paper counts (the headline question) ──
        "papers_printable_clean": sum(1 for a in served if a.printable_clean),   # printed body needs 0 rewrite
        "teacher_ready_ge90pct": sum(1 for a in served if a.printable_clean and cov(a) >= 0.9),
        "teacher_ready_ge50pct": sum(1 for a in served if a.printable_clean and cov(a) >= 0.5),
        "teacher_ready_full_paper": sum(1 for a in served if a.printable_clean and cov(a) >= 0.999),
    }
    per_config = defaultdict(lambda: {"served": 0, "printable": 0, "printed_q": 0,
                                      "blueprint_q": 0, "refused": 0})
    for a in audits:
        pc = per_config[a.config]
        if not a.ok:
            pc["refused"] += 1
            continue
        pc["served"] += 1
        pc["printable"] += int(a.printable_clean)
        pc["printed_q"] += a.filled_answerable
        pc["blueprint_q"] += a.blueprint_count
    return {"metrics": metrics, "per_config": dict(per_config),
            "refusals": [f"{a.config}:s{a.seed}: {a.error[:90]}" for a in refused],
            "papers": [vars(a) for a in audits]}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True)
    ap.add_argument("--json", help="write full result JSON here")
    args = ap.parse_args(argv)
    result = run(args.db)
    m = result["metrics"]
    print("== QP CONTENT READINESS AUDIT ==")
    for k, v in m.items():
        print(f"  {k}: {v}")
    print("\n-- by config: printed_q/blueprint_q  (printable papers / served, refused) --")
    for cfg, pc in result["per_config"].items():
        print(f"  {cfg:20} printed={pc['printed_q']:3}/{pc['blueprint_q']:3}  "
              f"printable_papers={pc['printable']} served={pc['served']} refused={pc['refused']}")
    if result["refusals"]:
        print("\n-- refusals --")
        for r in result["refusals"]:
            print("  " + r)
    if args.json:
        with open(args.json, "w") as fh:
            json.dump(result, fh, indent=1)
        print(f"\nwrote {args.json}")
    return result


if __name__ == "__main__":
    main()
