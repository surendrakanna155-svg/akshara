"""Deterministic apportionment for the Question Planning Layer (Phase 3).

Replaces `plan_specs`' seed-sampled content with a pure DETERMINISTIC allocation driven by Exam DNA:
the same (frozen index, Exam DNA, exam, N) always yields the identical multiset of slots. No RNG, no clock.

Two primitives:
  hamilton(total, weights)  — largest-remainder apportionment; integer counts that sum to `total`.
  spread(counts)            — interleave those counts into an even, deterministic sequence.

Then allocate_slots walks subject -> chapter -> concept by weight, and assigns difficulty + archetype per
(exam, subject) from the exam's distributions, keeping archetypes coherent with the subject (Biology stays
qualitative). Depth + drivers come from the bounded difficulty model.
"""
from __future__ import annotations

from typing import Dict, List

from kie.qie.knowledge import difficulty as DIFF
from kie.qie.knowledge import plan_specs as PS
from kie.qie.knowledge import planner as P

NUMERIC_ARCHETYPES = set(PS._STRUCTURED)
# subjects whose items are inherently non-computational: only qualitative archetypes are coherent
QUALITATIVE_ONLY_SUBJECTS = {"Biology"}


def hamilton(total: int, weights: Dict[str, float]) -> Dict[str, int]:
    """Largest-remainder apportionment. Deterministic (ties broken by key); result sums to `total`."""
    keys = list(weights)
    if total <= 0 or not keys:
        return {k: 0 for k in keys}
    tot_w = sum(max(0.0, weights[k]) for k in keys)
    if tot_w <= 0:
        return {k: 0 for k in keys}
    quota = {k: total * max(0.0, weights[k]) / tot_w for k in keys}
    floor = {k: int(quota[k]) for k in keys}
    remainder = total - sum(floor.values())
    order = sorted(keys, key=lambda k: (-(quota[k] - floor[k]), k))
    for k in order[:remainder]:
        floor[k] += 1
    return floor


def spread(counts: Dict[str, int]) -> List[str]:
    """Interleave counts into an even sequence: each key placed at evenly-spaced fractional positions.
    Deterministic and stable; length == sum(counts)."""
    placed = []
    for k in sorted(counts):
        c = counts[k]
        for i in range(c):
            placed.append(((i + 0.5) / c, k))
    placed.sort(key=lambda x: (x[0], x[1]))
    return [k for _, k in placed]


def _subject_archetype_pool(subject: str, arch_dist: Dict[str, float]) -> Dict[str, float]:
    """The exam's archetype distribution, filtered to archetypes coherent with the subject, renormalized."""
    if subject in QUALITATIVE_ONLY_SUBJECTS:
        pool = {a: p for a, p in arch_dist.items() if a not in NUMERIC_ARCHETYPES}
    else:
        pool = dict(arch_dist)
    tot = sum(pool.values())
    return {a: p / tot for a, p in pool.items()} if tot > 0 else {}


def _lane_for(archetype: str) -> str:
    return "STRUCTURED_NUMERIC" if archetype in NUMERIC_ARCHETYPES else "QUALITATIVE"


def _can_reach(archetype: str, band: str) -> bool:
    """True if some depth in the archetype's certified range makes the difficulty model predict `band`."""
    arng = P._ARCH_DEPTH.get(archetype, (1, 3))
    return bool(DIFF.drivers_for_target(band, _lane_for(archetype), "single", arng)["target_met"])


def allocate_slots(exam: str, total: int, subject_weights: Dict[str, float],
                   chapter_weights: Dict[str, Dict[str, float]],
                   concepts_by_chapter: Dict[str, List[dict]],
                   difficulty_dist: Dict[str, float],
                   archetype_dist: Dict[str, float]) -> List[dict]:
    """Deterministically apportion `total` slots for `exam`.

    subject_weights      : {subject: weight}
    chapter_weights      : {subject: {chapter_id: weight}}
    concepts_by_chapter  : {chapter_id: [certified concept dicts sorted by concept_id]}
    difficulty_dist      : {easy|moderate|hard: p}
    archetype_dist       : {archetype: p}  (exam-wide, pre-coherence)

    Returns a list of slot dicts (each ready for QuestionBlueprint construction). Deterministic.
    """
    # keep only subjects that actually have certified chapters+concepts available
    avail_subjects = {s: w for s, w in subject_weights.items()
                      if chapter_weights.get(s) and any(concepts_by_chapter.get(c)
                                                        for c in chapter_weights[s])}
    subj_counts = hamilton(total, avail_subjects)

    slots: List[dict] = []
    for subject in sorted(subj_counts):
        n_subj = subj_counts[subject]
        if n_subj <= 0:
            continue
        # chapters available for this subject (weight intersect concepts present)
        cw = {c: w for c, w in chapter_weights[subject].items() if concepts_by_chapter.get(c)}
        if not cw:
            continue
        chap_counts = hamilton(n_subj, cw)

        # build the ordered concept-slot list for this subject
        concept_slots: List[dict] = []
        for chap in sorted(chap_counts):
            k = chap_counts[chap]
            pool = concepts_by_chapter.get(chap) or []
            for j in range(k):
                concept_slots.append({"chapter_id": chap, "concept": pool[j % len(pool)],
                                      "occurrence": j // len(pool)})
        # 1. difficulty target per slot (PRIMARY dial) — deterministic spread of the exam's difficulty mix
        n = len(concept_slots)
        diff_seq = spread(hamilton(n, difficulty_dist))
        arch_pool = _subject_archetype_pool(subject, archetype_dist)

        # 2. archetype per slot, CONDITIONED on the target difficulty: only archetypes that can actually
        #    reach that band are eligible (so the difficulty mix is met where the pool allows). Where no
        #    eligible archetype exists (e.g. a 'hard' qualitative item without QDI misconception data),
        #    fall back to the full pool and let the difficulty model record the honest downgrade.
        arch_for: List[str] = [""] * n
        groups: Dict[str, List[int]] = {}
        for i, band in enumerate(diff_seq):
            groups.setdefault(band, []).append(i)
        for band, idxs in groups.items():
            eligible = {a: w for a, w in arch_pool.items() if _can_reach(a, band)}
            pool = eligible if eligible else arch_pool
            seq = spread(hamilton(len(idxs), pool)) if pool else []
            for pos, gi in enumerate(idxs):
                arch_for[gi] = seq[pos] if pos < len(seq) else "factual_single_best_answer"

        for idx, cs in enumerate(concept_slots):
            target_diff = diff_seq[idx]
            archetype = arch_for[idx] or "factual_single_best_answer"
            lane = _lane_for(archetype)
            arng = P._ARCH_DEPTH.get(archetype, (1, 3))
            dfit = DIFF.drivers_for_target(target_diff, lane, "single", arng)
            slots.append({
                "exam": exam,
                "subject": subject,
                "chapter_id": cs["chapter_id"],
                "concept": cs["concept"],
                "occurrence": cs["occurrence"],
                "archetype": archetype,
                "lane": lane,
                "composition": "single",
                "target_difficulty": target_diff,
                "reasoning_depth": dfit["realized_depth"],
                "difficulty": dfit["predicted"]["band"],
                "difficulty_drivers": dfit["predicted"]["drivers"],
                "difficulty_score": dfit["predicted"]["score"],
                "difficulty_model": dfit["predicted"]["model_version"],
                "difficulty_target_met": dfit["target_met"],
            })
    return slots
