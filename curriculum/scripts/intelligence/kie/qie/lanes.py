"""The 11 structure-intelligence lanes (OPUS_FABLE_RECONCILIATION_RECORD.md §2).

A lane — not a subject — is the unit of assessment capability. Each lane declares how its items are
verified INDEPENDENTLY (the crux for non-numeric science): numeric lanes verify by relation-match-by-solver
against the relation library; conceptual lanes verify by entailment against the Knowledge Verification
Substrate (KVS) plus an independent model pass. This module is the single source of truth for lane identity,
readiness tier, and verification strategy; other QIE modules import from here.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Tuple


class Verify(str, Enum):
    """How a lane's answer key is INDEPENDENTLY verified (never by the generator)."""
    RELATION_SOLVER = "relation_solver"        # numeric: a library relation reproduces the key
    KVS_ASSERTION = "kvs_assertion"            # fact entailed by the assertion_base (+ model agreement)
    KVS_TAXONOMY = "kvs_taxonomy"              # deterministic class membership in taxonomy_store
    KVS_SEQUENCE = "kvs_sequence"              # deterministic order check in sequence_store
    KVS_STRUCTURE_FUNCTION = "kvs_structure_function"
    KVS_COMPARISON = "kvs_comparison"          # cell lookup in comparison_matrix
    KVS_TRUTH_TABLE = "kvs_truth_table"        # AR: truth(A), truth(R), explains(R,A) each checked
    DATA_RECOMPUTE = "data_recompute"          # recompute from the generated data/table spec
    VISUAL_SPEC = "visual_spec"                # answer_function reads the semantic visual spec (Phase E)


class Tier(str, Enum):
    A = "A"   # deterministic-verifiable now, corpus-rich (build first)
    B = "B"   # KVS-backed conceptual
    C = "C"   # visual / experiment (Phase E-full)


@dataclass(frozen=True)
class Lane:
    name: str
    tier: Tier
    verify: Verify
    numeric: bool
    subjects: Tuple[str, ...]      # primary subjects that use this lane
    description: str


# The canonical 11 lanes. Order is stable; `name` is the identity used everywhere (DNA.lane, ItemModel.lane).
LANES: Dict[str, Lane] = {l.name: l for l in (
    Lane("NUMERIC_RELATIONAL", Tier.A, Verify.RELATION_SOLVER, True,
         ("Physics", "Chemistry", "Mathematics"),
         "Quantities + relation -> computed answer; direct/reverse/missing-variable/multi-step."),
    Lane("DATA_INTERPRETATION", Tier.A, Verify.DATA_RECOMPUTE, True,
         ("Physics", "Chemistry", "Biology", "Mathematics"),
         "Read a table/graph, compute or infer; answer recomputed from the data spec."),
    Lane("MISCONCEPTION_DIAGNOSTIC", Tier.A, Verify.KVS_ASSERTION, False,
         ("Physics", "Chemistry", "Biology", "Mathematics"),
         "Distractor-first: options ARE named misconceptions; key is the non-misconception."),
    Lane("CONCEPTUAL_CAUSAL", Tier.B, Verify.KVS_ASSERTION, False,
         ("Biology", "Chemistry", "Physics"),
         "cause -> mechanism -> effect; forward/reverse/mechanism-identification."),
    Lane("CLASSIFICATION_TAXONOMIC", Tier.B, Verify.KVS_TAXONOMY, False,
         ("Biology", "Chemistry"),
         "is-a / belongs-to / odd-one-out over a curated taxonomy node."),
    Lane("PROCESS_SEQUENCE", Tier.B, Verify.KVS_SEQUENCE, False,
         ("Biology", "Chemistry"),
         "ordering of steps/stages; full-order / next / previous / insert-missing."),
    Lane("STRUCTURE_FUNCTION", Tier.B, Verify.KVS_STRUCTURE_FUNCTION, False,
         ("Biology", "Chemistry"),
         "part <-> role mapping over a curated structure-function map."),
    Lane("COMPARATIVE", Tier.B, Verify.KVS_COMPARISON, False,
         ("Physics", "Chemistry", "Biology", "Mathematics"),
         "compare entities across attributes; cell lookup in a comparison matrix."),
    Lane("ASSERTION_RELATION", Tier.B, Verify.KVS_TRUTH_TABLE, False,
         ("Physics", "Chemistry", "Biology"),
         "AR with all four relation classes reachable; key derived from 3 independent truth checks."),
    Lane("DIAGRAM_VISUAL", Tier.C, Verify.VISUAL_SPEC, False,
         ("Physics", "Biology", "Chemistry", "Mathematics"),
         "read/label a figure; answer_function reads the semantic visual spec (Phase E-full)."),
    Lane("EXPERIMENT_OBSERVATION", Tier.C, Verify.DATA_RECOMPUTE, False,
         ("Physics", "Chemistry", "Biology"),
         "observe -> infer; numeric inference recomputed, qualitative via KVS + model (Phase E-full)."),
)}

# The four fixed Assertion-Reason relation classes the AR lane MUST be able to produce (fixes the
# always-"(a)" defect: the correct class is sampled, not constant).
AR_RELATION_CLASSES: Tuple[str, ...] = (
    "A_true_R_true_R_explains_A",
    "A_true_R_true_R_not_explain_A",
    "A_true_R_false",
    "A_false_R_true",
)


def lane(name: str) -> Lane:
    if name not in LANES:
        raise KeyError(f"unknown lane: {name!r}; valid: {sorted(LANES)}")
    return LANES[name]


def names() -> List[str]:
    return list(LANES.keys())


def by_tier(tier: Tier) -> List[Lane]:
    return [l for l in LANES.values() if l.tier == tier]


def numeric_lanes() -> List[str]:
    return [n for n, l in LANES.items() if l.numeric]


def non_numeric_lanes() -> List[str]:
    return [n for n, l in LANES.items() if not l.numeric]
