"""Subject x Profile x Archetype capability matrix + five separate readiness metrics (Phase C, slices 5-6).

Aggregates the corrected `capability.mine_capability` records into:
  * a matrix of (subject x profile x archetype) cells with evidence/verification/diversity fields, and
  * an honest (subject x profile) rating: STRONG | MODERATE | THIN | ABSENT | PROFILE_MISMATCHED | UNRESOLVED.
  * the FIVE separate readiness metrics (never collapsed into one score): capability coverage, evidence
    readiness, quality readiness, scale readiness, paper readiness.

Fields the current pipeline cannot yet measure (difficulty-driver / solution-verification / visual support)
are reported as honest proxies with an explicit `measured` flag — never overclaimed. Pure aggregation +
a thin run helper. Deterministic, stdlib-only.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Dict, List, Optional

from kie.qie import profiles as P, archetypes as A


def build_matrix(records: List[dict]) -> dict:
    """records = capability.mine_capability()['models']. Returns cells + (subject,profile) ratings."""
    cells: Dict[tuple, dict] = defaultdict(lambda: {
        "candidate_models": 0, "certifiable_models": 0, "genuine_models": 0, "verified_models": 0,
        "total_dna": 0, "max_resources": 0, "max_distinct_stems": 0, "concepts": set()})
    for m in records:
        key = (m["subject"], m["profile"], m["archetype"])
        c = cells[key]
        c["candidate_models"] += 1
        c["certifiable_models"] += 1 if m["certifiable"] else 0
        c["genuine_models"] += 1 if m["genuine"] else 0
        c["verified_models"] += 1 if m["verified"] else 0
        c["total_dna"] += m["n_dna"]
        c["max_resources"] = max(c["max_resources"], m["n_resources"])
        c["max_distinct_stems"] = max(c["max_distinct_stems"], m["distinct_stems"])
        c["concepts"].add(m["concept"])

    def numeric_archetype(a):
        return A.verification_lane(a) == "NUMERIC_RELATIONAL"

    cell_list = []
    for (subj, profile, arch), c in cells.items():
        numeric = numeric_archetype(arch)
        cell_list.append({
            "subject": subj, "profile": profile, "archetype": arch,
            "evidence_depth_dna": c["total_dna"], "distinct_concepts": len(c["concepts"]),
            "resource_count_max": c["max_resources"], "distinct_stems_max": c["max_distinct_stems"],
            "verification_readiness": "solver" if numeric else "kvs+tier2",
            "verified_item_models": c["verified_models"], "genuine_item_models": c["genuine_models"],
            "certifiable_item_models": c["certifiable_models"],
            # honest proxies for not-yet-built capabilities:
            "difficulty_driver_support": {"measured": False,
                                          "proxy": "partial" if numeric else "absent"},
            "solution_verification_support": {"measured": True,
                                              "value": "relation_solver" if numeric else "kvs_tier2_agreement"},
            "visual_support": {"measured": False, "proxy": "assets_exist_not_generation_ready"},
            "generation_diversity_potential": {"measured": True,
                                               "distinct_stems": c["max_distinct_stems"],
                                               "concepts": len(c["concepts"])},
        })

    # (subject x profile) ratings
    sp = defaultdict(lambda: {"certifiable": 0, "genuine": 0, "candidate": 0, "archetypes": set(),
                              "dna": 0, "invalid_evidence": 0})
    for (subj, profile, arch), c in cells.items():
        r = sp[(subj, profile)]
        r["certifiable"] += c["certifiable_models"]
        r["genuine"] += c["genuine_models"]
        r["candidate"] += c["candidate_models"]
        r["dna"] += c["total_dna"]
        if c["certifiable_models"]:
            r["archetypes"].add(arch)
        # evidence present but archetype invalid for this profile -> mismatch signal
        if profile and c["candidate_models"] and not P.is_valid_archetype_for(profile, arch):
            r["invalid_evidence"] += c["candidate_models"]

    ratings = []
    for (subj, profile), r in sp.items():
        if profile is None:
            rating = "UNRESOLVED"
        elif r["dna"] == 0:
            rating = "ABSENT"
        elif r["certifiable"] >= 3 and len(r["archetypes"]) >= 2:
            rating = "STRONG"
        elif r["certifiable"] >= 1:
            rating = "MODERATE"
        elif r["invalid_evidence"] > 0 and r["genuine"] == 0:
            rating = "PROFILE_MISMATCHED"
        else:
            rating = "THIN"
        ratings.append({"subject": subj, "profile": profile, "rating": rating,
                        "certifiable_models": r["certifiable"], "genuine_models": r["genuine"],
                        "candidate_models": r["candidate"],
                        "archetypes_covered": sorted(r["archetypes"]),
                        "profile_invalid_evidence": r["invalid_evidence"]})
    ratings.sort(key=lambda x: (x["subject"], x["profile"] or "~"))
    return {"cells": sorted(cell_list, key=lambda c: (c["subject"], c["profile"] or "~", -c["evidence_depth_dna"])),
            "subject_profile_ratings": ratings}


def readiness_metrics(records: List[dict]) -> dict:
    """The FIVE separate readiness metrics — never collapsed into one score."""
    # 1. Capability coverage per profile = fraction of the profile's CORE archetypes with >=1 certifiable model
    cert_by_profile_arch = defaultdict(set)      # profile -> {archetype with a certifiable model}
    for m in records:
        if m["certifiable"] and m["profile"]:
            cert_by_profile_arch[m["profile"]].add(m["archetype"])
    capability_coverage = {}
    for name, prof in P.PROFILES.items():
        core = prof.core_archetypes
        covered = core & cert_by_profile_arch.get(name, set())
        capability_coverage[name] = {"core_archetypes": len(core), "covered": len(covered),
                                     "fraction": round(len(covered) / len(core), 3) if core else 0.0,
                                     "covered_archetypes": sorted(covered)}
    # 2. Evidence readiness = concepts with >=5 distinct DNA / >=2 resources, per (subject, profile)
    evidence = defaultdict(set)
    for m in records:
        if m["n_dna"] >= 5 and m["n_resources"] >= 2 and m["resolved_concept"]:
            evidence[(m["subject"], m["profile"])].add(m["concept"])
    evidence_readiness = {f"{s}/{p}": len(v) for (s, p), v in sorted(evidence.items())}
    # 3. Quality readiness = the gold benchmark (not re-run here); Phase-0 Hyp-B substance already PASSED
    quality_readiness = {"instrument": "gold_benchmark (blind teacher / AI-panel proxy)",
                         "status": "Phase-0 Hyp-B substance PASSED (absolute bar/agreement/Biology-specific); "
                                   "per-profile benchmark PENDING", "measured_here": False}
    # 4. Scale readiness = generation diversity after verification (distinct-stem breadth of certifiable models)
    cert = [m for m in records if m["certifiable"]]
    scale_readiness = {"certifiable_models": len(cert),
                       "median_distinct_stems": _median([m["distinct_stems"] for m in cert]),
                       "note": "distinct-stem breadth is a proxy for non-clone parameter/context diversity"}
    # 5. Paper readiness = ability to satisfy a real profile blueprint (needs qpgen feasibility; not run here)
    paper_readiness = {"instrument": "qpgen blueprint feasibility per profile", "measured_here": False,
                       "note": "requires a target blueprint per profile; not measured in this slice"}
    return {"capability_coverage_per_profile": capability_coverage,
            "evidence_readiness_concepts": evidence_readiness,
            "quality_readiness": quality_readiness, "scale_readiness": scale_readiness,
            "paper_readiness": paper_readiness}


def _median(xs):
    xs = sorted(xs)
    n = len(xs)
    if n == 0:
        return 0
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2
