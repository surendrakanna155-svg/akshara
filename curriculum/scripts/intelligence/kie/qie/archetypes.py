"""Canonical Question Archetype vocabulary + deterministic classifier (Phase C, slice 2).

An ARCHETYPE is the assessment FORM / cognitive pattern the student sees. It is NOT a structure-intelligence
lane (that is *how evidence is verified*). The B-series conflated them (`mine.py` wrote archetype = lane); this
module restores the mission's separate archetype axis (QUESTION_DNA_SPECIFICATION §5, 19 values) plus the
explicitly-ratified `factual_single_best_answer` — the dominant, legitimate NEET form the lane taxonomy could
not represent.

`classify()` maps an item to exactly one archetype from surface structure, deterministically. The DEFAULT for a
plain single-best-answer conceptual MCQ is `factual_single_best_answer` (a real archetype), NOT discard — the
correction of the old `CONCEPTUAL_GENERIC` black hole. `verification_lane()` bridges archetype -> the lane
whose independent-verification strategy applies, so the two axes stay linked but distinct.

Deterministic, stdlib-only, read-only.
"""
from __future__ import annotations

import re
from typing import Dict, Optional, Tuple

# ── canonical archetype vocabulary (mission §5 + ratified factual_single_best_answer) ─────────────────
ARCHETYPES: Tuple[str, ...] = (
    "direct_recall", "definition_recognition", "factual_single_best_answer", "property_application",
    "single_step_numerical", "multi_step_numerical", "reverse_numerical", "missing_variable_inference",
    "misconception_detection", "comparison", "cause_effect", "assertion_reason", "case_interpretation",
    "experiment_inference", "graph_interpretation", "table_interpretation", "diagram_interpretation",
    "error_analysis", "constraint_reasoning", "multi_concept_integration",
)
_SET = set(ARCHETYPES)

# archetype -> the structure-intelligence lane whose independent-verification strategy applies.
# (verification stays lane-specific; several archetypes verify via the same lane.)
_ARCHETYPE_LANE: Dict[str, str] = {
    "single_step_numerical": "NUMERIC_RELATIONAL", "multi_step_numerical": "NUMERIC_RELATIONAL",
    "reverse_numerical": "NUMERIC_RELATIONAL", "missing_variable_inference": "NUMERIC_RELATIONAL",
    "graph_interpretation": "DATA_INTERPRETATION", "table_interpretation": "DATA_INTERPRETATION",
    "diagram_interpretation": "DIAGRAM_VISUAL", "experiment_inference": "EXPERIMENT_OBSERVATION",
    "assertion_reason": "ASSERTION_RELATION", "comparison": "COMPARATIVE",
    "cause_effect": "CONCEPTUAL_CAUSAL", "misconception_detection": "MISCONCEPTION_DIAGNOSTIC",
    # conceptual/recall forms verify via the KVS-assertion + Tier-2 conceptual lane
    "direct_recall": "CONCEPTUAL_CAUSAL", "definition_recognition": "CONCEPTUAL_CAUSAL",
    "factual_single_best_answer": "CONCEPTUAL_CAUSAL", "property_application": "CONCEPTUAL_CAUSAL",
    "case_interpretation": "CONCEPTUAL_CAUSAL", "error_analysis": "CONCEPTUAL_CAUSAL",
    "constraint_reasoning": "CONCEPTUAL_CAUSAL", "multi_concept_integration": "CONCEPTUAL_CAUSAL",
}

# surface markers, checked in priority order (first hit wins). Numeric handled separately by the caller.
_MARKERS: Tuple[Tuple[str, "re.Pattern[str]"], ...] = (
    ("assertion_reason", re.compile(r"assertion.*reason|reason.*assertion|\bassertion\b.*\bA\b.*\breason\b", re.I)),
    ("graph_interpretation", re.compile(r"\bgraph\b|from the (?:plot|curve)|in the (?:plot|graph)|y-?axis|x-?axis", re.I)),
    ("table_interpretation", re.compile(r"\btable\b|given in the table|from the table|column\s*i\b.*column\s*ii", re.I)),
    ("diagram_interpretation", re.compile(r"\b(figure|diagram)\b|shown in the (?:figure|diagram)|labelled|in the given fig", re.I)),
    ("experiment_inference", re.compile(r"\bexperiment\b|was observed|student (?:performed|set up)|apparatus|on heating|when .* is added and", re.I)),
    ("error_analysis", re.compile(r"incorrect statement|which .* is (?:wrong|incorrect)|error in|mistake in|the incorrect", re.I)),
    ("case_interpretation", re.compile(r"read the (?:passage|paragraph)|based on the (?:passage|case)|following case|comprehension", re.I)),
    ("comparison", re.compile(r"difference between|compared to|as compared|higher than|lower than|greater than|more than|less than|arrange in (?:increasing|decreasing) order", re.I)),
    ("cause_effect", re.compile(r"\bwhy\b|because|due to|reason for|deficiency of|leads to|results in|responsible for|caused by|on account of|regulated by|controlled by", re.I)),
    ("definition_recognition", re.compile(r"\bdefine\b|definition of|what is meant by|is defined as|the term .* refers", re.I)),
    ("direct_recall", re.compile(r"\bS\.?\s?I\.?\s?unit\b|discovered by|chemical symbol of|chemical formula of|who (?:discovered|proposed|gave|invented)", re.I)),
    ("misconception_detection", re.compile(r"which .* is NOT|which of the following is not|cannot be|is never|is always", re.I)),
    ("multi_concept_integration", re.compile(r"match (?:list|column).*with.*(?:list|column)|match the following", re.I)),
)


def classify(stem: str, is_numeric: bool = False, relation_verified: bool = False) -> str:
    """Return exactly one canonical archetype for an item's assessment FORM (never a lane).

    Numeric items with a verifying relation -> single_step_numerical (multi/reverse/missing require structure
    we do not over-claim). Otherwise the first matching surface marker; else the ratified default
    `factual_single_best_answer` (a real archetype — the corrected home of the old CONCEPTUAL_GENERIC)."""
    if is_numeric and relation_verified:
        return "single_step_numerical"
    t = stem or ""
    for arch, pat in _MARKERS:
        if pat.search(t):
            return arch
    return "factual_single_best_answer"


def verification_lane(archetype: str) -> Optional[str]:
    """The structure-intelligence lane whose independent-verification strategy applies to this archetype."""
    return _ARCHETYPE_LANE.get(archetype)


def is_archetype(name: str) -> bool:
    return name in _SET
