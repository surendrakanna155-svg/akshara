"""Canonical assessment-profile taxonomy (Phase C, slice 1).

A profile is NOT a subject. It is the ruleset of a target examination: which question archetypes are valid and
expected, and how difficulty behaves. Question Intelligence is measured over (subject x profile x concept x
archetype), so the profile is a first-class axis — the ≥8-per-subject gate's fatal omission.

This module ratifies the profile list, the deterministic source->profile map (grounded in the measured B9
corpus: kie.db `source_documents.exam` + qcorpus `group`), and each profile's VALID archetype set (archetype
names are validated against `archetypes.ARCHETYPES` at import so the two vocabularies cannot drift). It does
NOT fabricate evidence: a profile whose only sources are textbooks has no *assessment* evidence, and that is
surfaced by the capability matrix (recovered MCQs = assessment evidence), never asserted here.

Pure data + validation. Deterministic, stdlib-only, no kie.db mutation.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Dict, FrozenSet, Optional, Tuple

from kie.qie import archetypes as A


@dataclass(frozen=True)
class Profile:
    name: str
    level: str                      # "6_10" | "11_12_foundation" | "competitive"
    kind: str                       # "board" | "foundation" | "competitive"
    valid_archetypes: FrozenSet[str]
    core_archetypes: FrozenSet[str]  # archetypes expected to be well-represented (a subset of valid)
    permitted: bool = True           # JEE_ADVANCED gated: only where explicitly permitted
    note: str = ""


# ── archetype bundles (names must exist in archetypes.ARCHETYPES) ─────────────────────────────────────
_RECALL = frozenset({"direct_recall", "definition_recognition", "factual_single_best_answer"})
_CONCEPTUAL = frozenset({"property_application", "comparison", "cause_effect", "assertion_reason",
                         "misconception_detection", "case_interpretation"})
_NUMERIC = frozenset({"single_step_numerical", "multi_step_numerical", "reverse_numerical",
                      "missing_variable_inference"})
_DATA_VISUAL = frozenset({"graph_interpretation", "table_interpretation", "diagram_interpretation",
                          "experiment_inference"})
_ADVANCED = frozenset({"constraint_reasoning", "multi_concept_integration", "error_analysis"})

# NEET medical-entrance: recall + conceptual dominant, numeric (Phys/Chem), data/visual, some advanced
_NEET = _RECALL | _CONCEPTUAL | _NUMERIC | _DATA_VISUAL | {"multi_concept_integration"}
# JEE: numeric + advanced + data dominant; recall NOT a core archetype
_JEE_MAIN = _NUMERIC | _ADVANCED | _DATA_VISUAL | {"property_application", "comparison", "assertion_reason"}
_JEE_ADV = _JEE_MAIN | {"multi_concept_integration", "constraint_reasoning"}
# Board 6-10: understanding/application oriented; recall permitted but CAPPED (not a core/dominant archetype)
_BOARD = _RECALL | {"property_application", "comparison", "cause_effect", "case_interpretation",
                    "experiment_inference", "graph_interpretation", "table_interpretation",
                    "diagram_interpretation", "single_step_numerical", "error_analysis"}
_BOARD_CORE = frozenset({"property_application", "case_interpretation", "experiment_inference",
                         "single_step_numerical", "comparison", "cause_effect"})
_FOUNDATION = _NEET | _JEE_MAIN | _RECALL   # broad foundational (board+competitive prep)


PROFILES: Dict[str, Profile] = {p.name: p for p in (
    Profile("BOARD_6_10", "6_10", "board", _BOARD, _BOARD_CORE,
            note="generic board 6-10; recall permitted but capped, understanding/application core"),
    Profile("CBSE_6_10", "6_10", "board", _BOARD, _BOARD_CORE, note="CBSE 6-10"),
    Profile("AP_SCERT_6_10", "6_10", "board", _BOARD, _BOARD_CORE, note="Andhra SCERT 6-10"),
    Profile("TS_SCERT_6_10", "6_10", "board", _BOARD, _BOARD_CORE, note="Telangana SCERT 6-10"),
    Profile("ICSE_6_10", "6_10", "board", _BOARD, _BOARD_CORE, note="ICSE/CISCE 6-10"),
    Profile("FOUNDATION", "11_12_foundation", "foundation", _FOUNDATION, _NUMERIC | _RECALL,
            note="mixed board+competitive foundational practice"),
    Profile("JEE_FOUNDATION", "11_12_foundation", "foundation", _JEE_MAIN, _NUMERIC,
            note="JEE foundational practice"),
    Profile("NEET_FOUNDATION", "11_12_foundation", "foundation", _NEET, _RECALL | _CONCEPTUAL,
            note="NEET foundational practice / sample papers"),
    Profile("JEE_MAIN", "competitive", "competitive", _JEE_MAIN, _NUMERIC | {"multi_concept_integration"},
            note="JEE Main"),
    Profile("NEET", "competitive", "competitive", _NEET, _RECALL | _CONCEPTUAL,
            note="NEET (biology-heavy medical entrance)"),
    Profile("JEE_ADVANCED", "competitive", "competitive", _JEE_ADV,
            _NUMERIC | {"multi_concept_integration", "constraint_reasoning"},
            permitted=False, note="JEE Advanced — only where explicitly permitted"),
)}

# ── deterministic source -> profile map (measured B9 corpus: exam names + qcorpus groups) ──────────────
# Ordered, longest/most-specific patterns first. A source that matches nothing -> None (UNRESOLVED profile).
_SOURCE_PATTERNS: Tuple[Tuple[str, "re.Pattern[str]"], ...] = (
    ("JEE_ADVANCED", re.compile(r"jee[_ ]?adv|advanced|jeeadv", re.I)),
    ("JEE_MAIN", re.compile(r"jee[_ ]?main|mathongo_jee_main|allen_jee|jeebooks|nta_sample", re.I)),
    ("NEET_FOUNDATION", re.compile(r"practice_resources|target[_ ]?neet|mock", re.I)),
    ("NEET", re.compile(r"\bneet\b|studentbro|aiims|aipmt", re.I)),
    ("FOUNDATION", re.compile(r"physicsaholics|foundation", re.I)),
    ("CBSE_6_10", re.compile(r"cbse|ncert", re.I)),
    ("TS_SCERT_6_10", re.compile(r"ts[_ ]?scert|telangana", re.I)),
    ("AP_SCERT_6_10", re.compile(r"ap[_ ]?scert|andhra", re.I)),
    ("ICSE_6_10", re.compile(r"icse|cisce", re.I)),
)


def profile_for_source(source: str) -> Optional[str]:
    """Map a source identifier (kie.db exam / qcorpus group / rel-path token) to a canonical profile, or None
    when unresolved. Deterministic; never guesses beyond the ratified patterns."""
    s = source or ""
    for prof, pat in _SOURCE_PATTERNS:
        if pat.search(s):
            return prof
    return None


def is_valid_archetype_for(profile: str, archetype: str) -> bool:
    """True iff `archetype` is valid for `profile`. Profile-invalid evidence must NOT certify an Item Model."""
    p = PROFILES.get(profile)
    return bool(p and archetype in p.valid_archetypes)


def is_permitted(profile: str) -> bool:
    p = PROFILES.get(profile)
    return bool(p and p.permitted)


def _validate_against_archetypes() -> None:
    """Fail fast if any profile references an archetype not in the canonical vocabulary (prevents drift)."""
    for p in PROFILES.values():
        unknown = (p.valid_archetypes | p.core_archetypes) - set(A.ARCHETYPES)
        if unknown:
            raise ValueError(f"profile {p.name} references unknown archetypes: {sorted(unknown)}")
        if not p.core_archetypes <= p.valid_archetypes:
            raise ValueError(f"profile {p.name}: core archetypes must be a subset of valid")


_validate_against_archetypes()
