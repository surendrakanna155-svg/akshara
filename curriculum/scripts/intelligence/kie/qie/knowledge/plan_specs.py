"""STAGE 2c — spec planning from the two certified layers.

Draws ONLY from:
  ki_concept.status='certified'   — independently-audited curriculum records (WHAT may be asked)
  qdi_pattern.status='certified'  — independently-audited design machinery  (HOW to build it well)

Every spec is validated by `planner.check_plan` before it can be issued, so a garbage plan costs zero
tokens. Archetype x depth is drawn from the compatibility table rather than sampled blindly — the trial's
planner emitted "direct_recall at depth 3" and paid Opus to refuse it.

Difficulty and reasoning depth are planned as INDEPENDENT axes, deliberately: the frozen engine derives
difficulty FROM depth (`qp_bridge._difficulty`: HARD if depth>=4 else MEDIUM), which collapses the two and
makes "easy" unrepresentable. Hard specs are attached to a certified `hard` design pattern, so difficulty
comes from a real, evidenced mechanism rather than from bigger numbers.
"""
from __future__ import annotations

import hashlib
import random
from datetime import datetime, timezone
from typing import Dict, List, Optional

from kie.qie.knowledge import planner as P

_STRUCTURED = ("single_step_numerical", "multi_step_numerical", "reverse_numerical",
               "missing_variable_inference", "constraint_reasoning", "multi_concept_integration")
_QUALITATIVE = ("property_application", "definition_recognition", "comparison", "error_analysis",
                "misconception_detection", "factual_single_best_answer")


def _sid(*parts) -> str:
    return "SPEC_" + hashlib.sha256("|".join(str(p) for p in parts).encode()).hexdigest()[:16]


def build_specs(universe: List[dict], patterns: List[dict], run_id: str, n: int = 120,
                seed: int = 20260716, subject: str = "Mathematics") -> Dict[str, object]:
    """Plan `n` specs across the certified universe. Returns issued specs + refusal telemetry."""
    rng = random.Random(seed)
    uni_by_id = {c["concept_id"]: c for c in universe}
    by_class: Dict[int, List[dict]] = {}
    for c in universe:
        by_class.setdefault(c["taught_at_class"], []).append(c)

    hard_pats = [p for p in patterns if p.get("difficulty_band") == "hard"]
    mod_pats = [p for p in patterns if p.get("difficulty_band") == "moderate"]

    specs: List[dict] = []
    classes = sorted(by_class)
    if not classes:
        return {"specs": [], "note": "no certified concepts"}

    # proportional to certified evidence per class — never a hardcoded distribution
    total = sum(len(v) for v in by_class.values())
    for cls in classes:
        pool = by_class[cls]
        want = max(1, round(n * len(pool) / total))
        for i in range(want):
            kc = pool[i % len(pool)]

            # lane: structured only where the concept's own evidence supports computation
            structured = rng.random() < 0.62
            arch_pool = _STRUCTURED if structured else _QUALITATIVE
            archetype = rng.choice(arch_pool)

            # depth from the archetype's OWN compatibility range — never sampled blind
            lo, hi = P._ARCH_DEPTH.get(archetype, (1, 3))
            depth = rng.randint(lo, min(hi, 4))

            # difficulty is an INDEPENDENT axis; hard is only claimed when a certified hard
            # design pattern supplies a real mechanism for it
            pat = None
            if depth >= 2 and hard_pats and rng.random() < 0.3:
                difficulty, pat = "hard", rng.choice(hard_pats)
            elif depth >= 2 and mod_pats and rng.random() < 0.45:
                difficulty, pat = "moderate", rng.choice(mod_pats)
            else:
                difficulty = rng.choice(["easy", "moderate"]) if depth <= 2 else "moderate"

            # composition only from a same-class, same-subject certified partner
            partners: List[str] = []
            composition = "single"
            if depth >= 3 and len(pool) > 1 and rng.random() < 0.4:
                cand = rng.choice([x for x in pool if x["concept_id"] != kc["concept_id"]])
                partners = [cand["concept_id"]]
                composition = "multi"
                archetype = "multi_concept_integration" if structured else archetype

            spec = {
                "spec_id": _sid(run_id, cls, kc["concept_id"], i),
                "run_id": run_id,
                "concept_id": kc["concept_id"],
                "concept_name": kc["canonical_name"],
                "chapter_id": kc["chapter_id"],
                "chapter_title": kc.get("chapter_title"),
                "subject": kc["subject"],
                "class_level": kc["taught_at_class"],
                # rich curriculum context, consumed straight from the CERTIFIED index (never synthesized)
                "sub_concepts": kc.get("sub_concepts", []),
                "prerequisites": kc.get("prerequisites", []),
                "curriculum_boundary": kc.get("boundary", {}),
                "lane": "STRUCTURED_NUMERIC" if structured else "QUALITATIVE",
                "archetype": archetype,
                "question_type": "MCQ",
                "intended_depth": depth,
                "intended_difficulty": difficulty,
                "composition": composition,
                "compose_with": partners,
                "pattern_id": (pat or {}).get("pattern_id"),
                "visual_required": False,
                # evidenced negative boundary: above-class vocabulary + this concept's own out_of_scope
                "forbidden_terms": P.forbidden_terms(universe, subject, cls),
            }
            specs.append(spec)

    rng.shuffle(specs)
    specs = specs[:n]

    # PRE-GENERATION validation — refusals here cost zero tokens
    issued, refused = [], []
    for s in specs:
        v = P.check_plan(s, uni_by_id)
        (issued if not v else refused).append((s, v))
    return {
        "issued": [s for s, _ in issued],
        "refused": [{"spec_id": s["spec_id"], "violations": v} for s, v in refused],
        "planned": len(specs),
    }
