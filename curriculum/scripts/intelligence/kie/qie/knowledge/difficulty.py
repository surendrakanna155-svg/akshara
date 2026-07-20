"""Bounded difficulty driver model (Owner Decision 1, 2026-07-20).

difficulty = a DETERMINISTIC, VERSIONED function of a small, defensible driver vector:
    reasoning_depth        (1..5)         — the certified structural depth
    concept_count          (1 single, 2+ multi)
    misconception_pressure (0..1)         — how much the item turns on a NAMED misconception (0 until QDI v2)
    calculation_load       (0..1)         — computational burden implied by the lane

The three self-downgraded drivers (information_density, abstraction_level, context_novelty) and
prerequisite_depth are EXCLUDED until data supports them. The predicted band is recomputable and MUST be
re-verified on the generated instance downstream (GATE-9) — never merely stamped.
"""
from __future__ import annotations

from typing import Dict, Tuple

MODEL_VERSION = "diff-v1"

# fixed, versioned weights. depth dominates; composition/computation/misconception nudge the band.
W: Dict[str, float] = {"depth": 0.50, "concept_count": 0.20, "misconception_pressure": 0.15,
                       "calculation_load": 0.15}
T_EASY, T_MODERATE = 0.30, 0.60  # score < T_EASY -> easy; < T_MODERATE -> moderate; else hard
BANDS = ("easy", "moderate", "hard")

LANE_CALC_LOAD = {"STRUCTURED_NUMERIC": 0.8, "QUALITATIVE": 0.2}


def _depth_norm(depth: int) -> float:
    return max(0.0, min(1.0, (depth - 1) / 4.0))          # 1..5 -> 0..1


def _cc_norm(concept_count: int) -> float:
    return max(0.0, min(1.0, (concept_count - 1) / 2.0))  # 1->0, 2->0.5, 3->1.0


def score(depth: int, concept_count: int, misconception_pressure: float = 0.0,
          calculation_load: float = 0.0) -> float:
    return (W["depth"] * _depth_norm(depth)
            + W["concept_count"] * _cc_norm(concept_count)
            + W["misconception_pressure"] * misconception_pressure
            + W["calculation_load"] * calculation_load)


def band_for_score(s: float) -> str:
    return "easy" if s < T_EASY else ("moderate" if s < T_MODERATE else "hard")


def predict(depth: int, concept_count: int, misconception_pressure: float = 0.0,
            calculation_load: float = 0.0) -> Dict[str, object]:
    s = score(depth, concept_count, misconception_pressure, calculation_load)
    return {
        "band": band_for_score(s),
        "score": round(s, 6),
        "model_version": MODEL_VERSION,
        "drivers": {"reasoning_depth": depth, "concept_count": concept_count,
                    "misconception_pressure": misconception_pressure,
                    "calculation_load": calculation_load},
    }


def drivers_for_target(target_band: str, lane: str, composition: str,
                       arch_depth_range: Tuple[int, int]) -> Dict[str, object]:
    """Deterministically choose a driver vector whose predicted band matches `target_band`, staying inside
    the archetype's certified depth range. If no depth in range reaches the target band (e.g. direct_recall
    can never be 'hard'), return the CLOSEST achievable band honestly — the realized band may differ from
    the target, and the caller records that, never forcing an impossible difficulty."""
    lo, hi = arch_depth_range
    cc = 2 if composition == "multi" else 1
    cl = LANE_CALC_LOAD.get(lane, 0.3)
    mp = 0.0  # QDI misconception pressure is 0 until v2

    candidates = []
    for d in range(lo, hi + 1):
        p = predict(d, cc, mp, cl)
        candidates.append((d, p))
        if p["band"] == target_band:
            return {"realized_depth": d, "predicted": p, "target_met": True}
    ti = BANDS.index(target_band)
    d, p = min(candidates, key=lambda dp: (abs(BANDS.index(dp[1]["band"]) - ti), dp[0]))
    return {"realized_depth": d, "predicted": p, "target_met": p["band"] == target_band}
