"""Gold-benchmark harness (GOLD_BENCHMARK_PLAN.md + Phase-0b amendment).

Promoted from the Phase-0/0b throwaway paneling into a reusable, tested module. It:
  * builds a BLIND, anonymized, deterministically-shuffled review packet from labelled items,
  * aggregates N independent judge score-sets into per-engine medians + lift + inter-judge agreement
    (Krippendorff's alpha, interval) + majority-direction,
  * applies the PRE-REGISTERED thresholds (PHASE0_PREREGISTRATION.md) UNCHANGED, and
  * returns a structured pass/fail verdict with the evidence attached.

LABELLING: when the judges are model passes this yields **AI-PANEL VALIDATED PROXY EVIDENCE**, not teacher
validation. Real independent teacher validation remains MANDATORY before any production/market quality claim
(the harness records `evidence_kind` so a caller can never silently mislabel it).

Thresholds are constants here so they cannot be quietly moved per run; changing them is a reviewed code edit.
Deterministic, stdlib-only.
"""
from __future__ import annotations

import hashlib
import statistics as st
from collections import defaultdict
from typing import Dict, List, Optional, Sequence, Tuple

# ── rubric + PRE-REGISTERED thresholds (do not move without a reviewed edit) ─────────────────────
DIMENSIONS: Tuple[str, ...] = (
    "correctness", "syllabus_alignment", "concept_precision", "cognitive_depth", "difficulty_accuracy",
    "distractor_quality", "ambiguity", "originality", "solution_quality",
)
ABSOLUTE_BAR_DIMS: Tuple[str, ...] = ("correctness", "syllabus_alignment", "concept_precision", "ambiguity")
LIFT_DIMS: Tuple[str, ...] = ("cognitive_depth", "distractor_quality", "difficulty_accuracy", "solution_quality")
NO_REGRESSION_DIMS: Tuple[str, ...] = ("correctness", "syllabus_alignment", "ambiguity")
REVERSE_SCORED: Tuple[str, ...] = ("ambiguity",)   # 5 = best (unambiguous); already scored that way by judges

ABSOLUTE_BAR = 4.0        # B median must be >= this on ABSOLUTE_BAR_DIMS
LIFT_MIN = 1.0            # B median must exceed A median by >= this on LIFT_DIMS
ALPHA_FLOOR = 0.6         # inter-judge Krippendorff alpha floor on gated dims
SHUFFLE_SEED = 20260712   # fixed so the blind order is reproducible


def build_blind_packet(items: List[dict], seed: int = SHUFFLE_SEED
                       ) -> Tuple[List[dict], Dict[str, dict]]:
    """items: list of dicts each with at least 'engine' + the item fields. Returns (blind_packet, key).

    The blind packet strips engine/lane/source labels and assigns opaque uids in a deterministic shuffled
    order (seeded, no wall-clock/RNG). The key maps uid -> the withheld labels for later unblinding.
    """
    order = sorted(range(len(items)),
                   key=lambda i: hashlib.sha256(f"{seed}|{i}".encode()).hexdigest())
    blind, key = [], {}
    for pos, i in enumerate(order):
        it = items[i]
        uid = f"Q{pos + 1:03d}"
        blind.append({k: v for k, v in it.items()
                      if k not in ("engine", "lane", "source", "item_model_id")} | {"uid": uid})
        key[uid] = {k: it.get(k) for k in ("engine", "lane", "subject")}
    return blind, key


def krippendorff_interval(units: Sequence[Sequence[float]]) -> Optional[float]:
    """Interval Krippendorff's alpha across raters. units = list of per-item rating lists (len>=2)."""
    o: Dict[Tuple[float, float], float] = defaultdict(float)
    vals = set()
    for ratings in units:
        m = len(ratings)
        if m < 2:
            continue
        for a in range(m):
            for b in range(m):
                if a != b:
                    o[(ratings[a], ratings[b])] += 1.0 / (m - 1)
        vals.update(ratings)
    n = sum(o.values())
    if n == 0:
        return None
    nc = {v: sum(o[(v, k)] for k in vals) for v in vals}
    do = sum(o[(c, k)] * ((c - k) ** 2) for c in vals for k in vals) / n
    if n <= 1:
        return 1.0
    de = sum(nc[c] * nc[k] * ((c - k) ** 2) for c in vals for k in vals) / (n * (n - 1))
    if de == 0:
        return 1.0
    return 1 - do / de


def _scores(judges: List[dict], uids: List[str], dim: str) -> List[float]:
    out = []
    for u in uids:
        for jd in judges:
            if u in jd and dim in jd[u]:
                try:
                    out.append(float(jd[u][dim]))
                except (TypeError, ValueError):
                    pass
    return out


def aggregate(judges: List[dict], key: Dict[str, dict],
              extra_gate: Optional[Dict[str, bool]] = None,
              evidence_kind: str = "ai_panel_proxy") -> dict:
    """judges: list of {uid: {dim: score, ...}}. key: uid -> {'engine': 'A'|'B', ...}.

    Returns per-dimension medians/lift/alpha, majority-direction, the pre-registered threshold checks, the
    set of PROVEN lift dims, and an overall pass verdict. `extra_gate` (e.g. a Biology-specific bar) is ANDed
    into the verdict. `evidence_kind` is recorded so proxy evidence is never mislabelled as teacher-validated.
    """
    uids = list(key.keys())
    by_engine = {"A": [u for u in uids if key[u]["engine"] == "A"],
                 "B": [u for u in uids if key[u]["engine"] == "B"]}
    per_dim, alpha = {}, {}
    for dim in DIMENSIONS:
        a, b = _scores(judges, by_engine["A"], dim), _scores(judges, by_engine["B"], dim)
        per_dim[dim] = {
            "A_median": st.median(a) if a else None, "B_median": st.median(b) if b else None,
            "A_mean": round(st.mean(a), 2) if a else None, "B_mean": round(st.mean(b), 2) if b else None,
            "lift_median": (st.median(b) - st.median(a)) if a and b else None,
        }
        units = [[float(jd[u][dim]) for jd in judges if u in jd and dim in jd[u]] for u in uids]
        units = [x for x in units if len(x) >= 2]
        al = krippendorff_interval(units) if units else None
        alpha[dim] = round(al, 3) if al is not None else None

    def judge_median(jidx, engine, dim):
        v = [float(judges[jidx][u][dim]) for u in by_engine[engine]
             if u in judges[jidx] and dim in judges[jidx][u]]
        return st.median(v) if v else None

    majority = {}
    for dim in LIFT_DIMS:
        votes = sum(1 for j in range(len(judges))
                    if (judge_median(j, "A", dim) is not None and judge_median(j, "B", dim) is not None
                        and judge_median(j, "B", dim) > judge_median(j, "A", dim)))
        majority[dim] = {"judges_B_gt_A": votes, "majority": votes * 2 >= len(judges)}

    checks = {
        "absolute_bar": {d: (per_dim[d]["B_median"] is not None and per_dim[d]["B_median"] >= ABSOLUTE_BAR)
                         for d in ABSOLUTE_BAR_DIMS},
        "lift_min": {d: (per_dim[d]["lift_median"] is not None and per_dim[d]["lift_median"] >= LIFT_MIN)
                     for d in LIFT_DIMS},
        "no_regression": {d: (per_dim[d]["B_median"] is not None and per_dim[d]["A_median"] is not None
                              and per_dim[d]["B_median"] >= per_dim[d]["A_median"]) for d in NO_REGRESSION_DIMS},
        "agreement": {d: (alpha[d] is not None and alpha[d] >= ALPHA_FLOOR)
                      for d in (ABSOLUTE_BAR_DIMS + LIFT_DIMS)},
        "majority_direction": {d: majority[d]["majority"] for d in LIFT_DIMS},
    }
    proven_lift = [d for d in LIFT_DIMS
                   if checks["lift_min"][d] and checks["agreement"].get(d) and checks["majority_direction"][d]]
    extra_ok = all((extra_gate or {}).values())
    passed = (all(checks["absolute_bar"].values()) and all(checks["no_regression"].values())
              and len(proven_lift) == len(LIFT_DIMS) and extra_ok)
    return {
        "evidence_kind": evidence_kind,
        "teacher_validation_required": True,
        "n_items": {"A": len(by_engine["A"]), "B": len(by_engine["B"])},
        "per_dimension": per_dim, "alpha": alpha, "majority_direction": majority,
        "threshold_checks": checks, "extra_gate": extra_gate or {},
        "proven_lift_dims": proven_lift, "passed": passed,
    }
