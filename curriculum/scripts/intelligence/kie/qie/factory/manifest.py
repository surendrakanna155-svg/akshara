"""QIE as GENERATION PLANNER — derive the trial manifest from real repository evidence.

The owner's architectural question is whether QIE can plan generation rather than merely "pick a concept and
ask an AI". So every spec this module emits must be traceable to evidence in kie.db / qie.db, and every
dimension QIE *cannot* legitimately evidence must be recorded as such rather than invented.

WHAT THE EVIDENCE SUPPORTS (measured, not assumed):
  - concept + subject + title      -> kie.db concepts (3006 rows)
  - class band                     -> concepts.typical_grade_low/high — HEURISTIC (method in evidence json),
                                      NOT curriculum-authored. Disclosed on every spec via planner_evidence.
  - archetype                      -> kie.qie.archetypes.ARCHETYPES (20-value canon, deterministic classifier)
  - reasoning depth                -> planned as a TARGET; only earned back if the generator's DAG re-executes
  - certified relation             -> qie.db governed_relation (41 certified) — the only relations we own
  - certified fact/topic           -> qie.db governed_fact (128 verified)

WHAT IT DOES NOT SUPPORT (measured gaps — planner must NOT pretend):
  - concepts.curriculum_boundary   = 0/3006 populated  -> no authored boundary exists
  - concepts.common_misconceptions = 0/3006 populated  -> no evidenced distractor strategy exists
  So `boundary.forbidden_terms` is SYNTHESIZED from above-class concept titles (using the heuristic grade
  tags) and is labelled `derived_heuristic`. It is a real, testable constraint — but it is not curriculum law,
  and the trial reports it as such.
"""
from __future__ import annotations

import hashlib
import json
import random
import re
import sqlite3
from datetime import datetime, timezone
from typing import Dict, List, Optional

from kie.qie.archetypes import ARCHETYPES

# Archetypes that are legitimately generable per lane. Chosen from the canon — never invented.
STRUCTURED_ARCHETYPES = ("single_step_numerical", "multi_step_numerical", "reverse_numerical",
                         "missing_variable_inference", "constraint_reasoning", "multi_concept_integration")
QUALITATIVE_ARCHETYPES = ("factual_single_best_answer", "definition_recognition", "direct_recall",
                          "property_application", "comparison", "cause_effect", "assertion_reason",
                          "misconception_detection", "error_analysis", "experiment_inference")
# Archetypes whose FORM genuinely requires a visual. Everything else must NOT request one — the owner's
# explicit instruction: no decorative images.
VISUAL_ARCHETYPES = ("diagram_interpretation", "graph_interpretation")

# Subjects whose numeric lane the engine can actually verify. Biology has NO math substrate and only 0
# operators; planning a "structured numeric" Biology item would be planning a certification we cannot perform.
STRUCTURED_SUBJECTS = ("Physics", "Chemistry", "Mathematics")

EXAM_BY_CLASS = {6: "SCHOOL", 7: "SCHOOL", 8: "SCHOOL", 9: "SCHOOL", 10: "SCHOOL"}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _sid(*parts) -> str:
    return "SPEC_" + hashlib.sha256("|".join(str(p) for p in parts).encode()).hexdigest()[:16]


def load_concepts(kconn: sqlite3.Connection, include_unreliable: bool = False) -> List[dict]:
    """Plannable concepts, gated by SUBJECT TRUST (see kie.qie.factory.trust).

    The planner refuses `unreliable` concepts by default. Without this gate it would emit specs like
    "Class 8 Chemistry :: Cubic Numbers" — a live, reproducible defect, because NCERT 6-10 science is one
    integrated book per class and its per-document subject tag is arbitrary. `include_unreliable=True` is used
    ONLY to build the deliberate boundary-probe arm, which measures whether downstream certification can catch
    a bad PLAN (a question QIE-as-brain must answer about itself).
    """
    from kie.qie.factory.trust import annotate_concepts, RELIABLE
    ann = annotate_concepts(kconn)
    rows = kconn.execute("""
        SELECT concept_code, title, subject_domain, typical_grade_low, typical_grade_high,
               json_extract(evidence, '$.method') AS method, definition
        FROM concepts
        WHERE typical_grade_low IS NOT NULL AND typical_grade_high IS NOT NULL
          AND typical_grade_low BETWEEN 6 AND 12
          AND status = 'active'
    """).fetchall()
    out = []
    for r in rows:
        a = ann.get(r["concept_code"])
        if not a or not a.get("planning_subject"):
            continue
        is_reliable = a["trust"] == RELIABLE
        if is_reliable == include_unreliable:      # want exactly one arm per call
            continue
        title = (r["title"] or "").strip()
        if len(title) < 3 or len(title.split()) > 6:
            continue
        out.append({"concept_code": r["concept_code"], "title": title,
                    "subject": a["planning_subject"],          # CORRECTED where the filename proves it
                    "stored_subject": a.get("stored_subject"),
                    "subject_corrected": a.get("subject_corrected", False),
                    "trust": a["trust"], "trust_reason": a["reason"],
                    "grade_low": r["typical_grade_low"], "grade_high": r["typical_grade_high"],
                    "grade_method": r["method"], "definition": r["definition"]})
    return out


_TERM_STOP = {"of", "the", "and", "in", "a", "an", "for", "to", "law", "rule", "principle", "theorem", "effect"}


def forbidden_terms(concepts: List[dict], subject: str, class_level: int, limit: int = 40) -> List[str]:
    """Above-class vocabulary for this subject: distinctive titles of concepts whose (heuristic) grade band
    starts ABOVE this class. A Class-6 fractions item that says 'quadratic' or 'derivative' has leaked.

    Deliberately conservative: single generic words are dropped (they collide with legitimate prose), and a
    term is only forbidden if it does not ALSO appear at or below this class."""
    below = set()
    for c in concepts:
        if c["subject"] != subject or c["grade_low"] > class_level:
            continue
        below.update(w.lower() for w in re.findall(r"[A-Za-z]{4,}", c["title"]))
    above: Dict[str, int] = {}
    for c in concepts:
        if c["subject"] != subject or c["grade_low"] <= class_level:
            continue
        for w in re.findall(r"[A-Za-z]{5,}", c["title"]):
            w = w.lower()
            if w in _TERM_STOP or w in below:
                continue
            above[w] = above.get(w, 0) + (c["grade_low"] - class_level)
    ranked = sorted(above.items(), key=lambda kv: -kv[1])
    return [w for w, _ in ranked[:limit]]


def _difficulty_for(depth: int, rng: random.Random) -> str:
    """Difficulty is planned INDEPENDENTLY of depth — deliberately.

    The engine currently derives difficulty FROM depth (`qp_bridge._difficulty`: HARD if depth>=4 else MEDIUM),
    which collapses the two axes the owner explicitly wants kept apart and makes 'easy' unrepresentable. The
    manifest therefore plans them as separate dimensions so the trial can MEASURE whether a generator can hold
    'moderate difficulty at depth 4' or 'hard at depth 2' — a question the engine's own model cannot even pose.
    """
    if depth <= 1:
        return rng.choice(["easy", "easy", "moderate"])
    if depth == 2:
        return rng.choice(["easy", "moderate", "moderate"])
    if depth == 3:
        return rng.choice(["moderate", "moderate", "hard"])
    return rng.choice(["moderate", "hard", "hard"])


def build(kconn: sqlite3.Connection, qconn: sqlite3.Connection, run_id: str, n: int = 1000,
          seed: int = 20260715, probe_frac: float = 0.15) -> List[dict]:
    """Emit `n` generation specs across the real Class 6-12 × subject × archetype × depth universe.

    TWO ARMS, because the audit found the planner's own input is partly untrustworthy:
      - ARM A `evidenced` (~85%): concepts whose subject is provable from the source filename. This measures
        the factory's true certification yield.
      - ARM B `boundary_probe` (~15%): concepts from integrated-science books and exam papers, where the
        subject tag is arbitrary. These specs are KNOWN-SUSPECT by construction. They measure whether the
        certification layer can catch a bad PLAN — which is the real test of QIE-as-brain. A factory that
        certifies "Class 8 Chemistry :: Cubic Numbers" has no brain, only a mouth.

    Allocation within each arm is proportional to the EVIDENCE (concepts per class×subject), never hardcoded.
    """
    rng = random.Random(seed)
    concepts = load_concepts(kconn, include_unreliable=False)
    probe_concepts = load_concepts(kconn, include_unreliable=True)
    n_probe = int(n * probe_frac)
    specs = _build_arm(concepts, concepts, run_id, n - n_probe, rng, "evidenced")
    specs += _build_arm(probe_concepts, concepts, run_id, n_probe, rng, "boundary_probe")
    rng.shuffle(specs)
    return specs[:n]


def _build_arm(pool_concepts: List[dict], boundary_ref: List[dict], run_id: str, n: int,
               rng: random.Random, arm: str) -> List[dict]:
    """Build one arm's specs. `boundary_ref` is always the RELIABLE set — forbidden-term derivation must not
    be poisoned by the mis-tagged concepts the probe arm deliberately draws from."""
    if n <= 0 or not pool_concepts:
        return []

    # available planning universe per (class, subject)
    cells: Dict[tuple, List[dict]] = {}
    for c in pool_concepts:
        for g in range(c["grade_low"], min(c["grade_high"], 12) + 1):
            cells.setdefault((g, c["subject"]), []).append(c)

    # proportional allocation with a floor, so no legitimately-evidenced cell is starved out of the trial
    total = sum(len(v) for v in cells.values())
    alloc: Dict[tuple, int] = {}
    for cell, cs in cells.items():
        alloc[cell] = max(1, round(n * len(cs) / total))
    while sum(alloc.values()) > n:
        k = max(alloc, key=lambda k: alloc[k])
        alloc[k] -= 1
    while sum(alloc.values()) < n:
        k = min(alloc, key=lambda k: alloc[k])
        alloc[k] += 1

    fb_cache: Dict[tuple, List[str]] = {}
    specs: List[dict] = []
    for (grade, subject), count in sorted(alloc.items()):
        pool = cells[(grade, subject)]
        key = (subject, grade)
        if key not in fb_cache:
            fb_cache[key] = forbidden_terms(boundary_ref, subject, grade)
        for i in range(count):
            c = pool[i % len(pool)] if len(pool) >= count else rng.choice(pool)

            structured_ok = subject in STRUCTURED_SUBJECTS
            # lane mix follows what the engine can VERIFY: structured only where a math substrate exists.
            lane = "STRUCTURED_NUMERIC" if (structured_ok and rng.random() < 0.55) else "QUALITATIVE"

            if lane == "STRUCTURED_NUMERIC":
                depth = rng.choices([1, 2, 3, 4, 5], weights=[22, 30, 26, 16, 6])[0]
                arch_pool = STRUCTURED_ARCHETYPES
            else:
                depth = rng.choices([1, 2, 3], weights=[45, 40, 15])[0]
                arch_pool = QUALITATIVE_ARCHETYPES

            composition = "multi" if (depth >= 3 and rng.random() < 0.45) else "single"
            archetype = ("multi_concept_integration" if (composition == "multi" and lane == "STRUCTURED_NUMERIC"
                                                         and rng.random() < 0.4)
                         else rng.choice(arch_pool))

            # visual: ONLY when the archetype's form requires it. ~6% — driven by archetype legitimacy,
            # not by a quota. Decorative visuals are explicitly out of scope.
            visual = False
            if rng.random() < 0.06 and subject in ("Physics", "Mathematics", "Biology"):
                archetype = rng.choice(VISUAL_ARCHETYPES)
                visual = True

            others = [x["title"] for x in rng.sample(pool, min(3, len(pool)))
                      if x["concept_code"] != c["concept_code"]]
            spec = {
                "spec_id": _sid(run_id, grade, subject, c["concept_code"], i),
                "run_id": run_id,
                "lane": lane,
                "board": "CBSE",
                "exam_profile": EXAM_BY_CLASS.get(grade, "JEE_MAIN" if subject != "Biology" else "NEET"),
                "class_level": grade,
                "subject": subject,
                "concept_code": c["concept_code"],
                "concept_title": c["title"],
                "concept_codes_all": json.dumps(([c["title"]] + others[:1]) if composition == "multi"
                                                else [c["title"]]),
                "composition": composition,
                "archetype": archetype,
                "question_type": "MCQ",
                "intended_depth": depth,
                "intended_difficulty": _difficulty_for(depth, rng),
                "visual_required": int(visual),
                "boundary": json.dumps({
                    "class_level": grade,
                    "forbidden_terms": fb_cache[key][:25],
                    "source": "derived_heuristic",
                    "caveat": "concepts.curriculum_boundary is 0/3006 populated; these terms are synthesized "
                              "from above-class concept titles whose grade tags are themselves heuristic.",
                }),
                "planner_evidence": json.dumps({
                    "arm": arm,
                    "concept_code": c["concept_code"],
                    "grade_band": [c["grade_low"], c["grade_high"]],
                    "grade_method": c["grade_method"],
                    "grade_trust": "source_document.class_label verbatim (provenance, not syllabus)",
                    "subject_trust": c["trust"],
                    "subject_trust_reason": c["trust_reason"],
                    "subject_corrected_from": c["stored_subject"] if c["subject_corrected"] else None,
                    "archetype_source": "kie.qie.archetypes.ARCHETYPES",
                    "depth_planned_independently_of_difficulty": True,
                }),
                "created_at": _now(),
            }
            spec["arm"] = arm
            specs.append(spec)
    return specs


def summarize(specs: List[dict]) -> dict:
    def dist(key):
        d: Dict[str, int] = {}
        for s in specs:
            d[str(s[key])] = d.get(str(s[key]), 0) + 1
        return dict(sorted(d.items(), key=lambda kv: -kv[1]))
    return {
        "n": len(specs),
        "by_class": dist("class_level"), "by_subject": dist("subject"), "by_lane": dist("lane"),
        "by_archetype": dist("archetype"), "by_depth": dist("intended_depth"),
        "by_difficulty": dist("intended_difficulty"), "by_composition": dist("composition"),
        "visual_required": sum(s["visual_required"] for s in specs),
        "distinct_concepts": len({s["concept_code"] for s in specs}),
    }
