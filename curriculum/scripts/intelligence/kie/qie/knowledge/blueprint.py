"""QuestionBlueprint — the deterministic per-item plan (Phase 3).

Distinct from qpgen's paper-level `Blueprint`. One QuestionBlueprint = one fully-provenanced instruction to
generate ONE candidate question. Every field traces to a certified source (frozen `ki_concept`, Exam DNA, the
bounded difficulty model). Identity is a content hash of the SELECTING fields (no clock, no seed), so the same
inputs always mint the same blueprint. The planner refuses (never fabricates) any blueprint the pre-generation
gate rejects.
"""
from __future__ import annotations

import hashlib
from typing import Dict

BLUEPRINT_MODEL_VERSION = "qbp-v1"

# the fields that DEFINE a blueprint's identity (excludes provenance/version metadata)
_FINGERPRINT_FIELDS = ("exam", "concept_id", "archetype", "difficulty", "reasoning_depth", "composition")

_ARCH_VERB = {
    "direct_recall": "Recall", "definition_recognition": "Recognize the definition of",
    "factual_single_best_answer": "Identify the correct fact about",
    "property_application": "Apply the properties of", "comparison": "Compare",
    "cause_effect": "Reason about cause and effect in", "assertion_reason": "Evaluate assertion-and-reason for",
    "misconception_detection": "Detect the misconception in", "case_interpretation": "Interpret a case on",
    "single_step_numerical": "Compute a single-step result for", "multi_step_numerical": "Solve a multi-step problem on",
    "reverse_numerical": "Work backwards to find a quantity in", "missing_variable_inference": "Infer the missing quantity in",
    "constraint_reasoning": "Reason under constraints about", "multi_concept_integration": "Integrate concepts around",
    "error_analysis": "Analyze the error in", "experiment_inference": "Infer from an experiment on",
    "graph_interpretation": "Interpret a graph of", "table_interpretation": "Interpret tabular data on",
    "diagram_interpretation": "Interpret a diagram of",
}


def learning_objective(concept_name: str, archetype: str) -> str:
    return f"{_ARCH_VERB.get(archetype, 'Apply')} {concept_name}"


def _fingerprint(bp: Dict) -> str:
    payload = "|".join(f"{k}={bp.get(k)}" for k in _FINGERPRINT_FIELDS)
    return hashlib.sha256(payload.encode()).hexdigest()[:16]


def build_blueprint(slot: dict, run_id: str, chapter_weight: float, concept_weight: float,
                    foundation_version: str, examdna_version: str) -> dict:
    """Construct a QuestionBlueprint from an allocated slot + certified concept + weights. Deterministic."""
    kc = slot["concept"]
    oos = [str(x) for x in (kc.get("boundary") or {}).get("out_of_scope", [])]
    bp = {
        # identity + provenance metadata (not part of the fingerprint)
        "run_id": run_id,
        "blueprint_model": BLUEPRINT_MODEL_VERSION,
        # --- required blueprint contract (roadmap §6) ---
        "exam": slot["exam"],
        "class_level": kc["taught_at_class"],
        "subject": slot["subject"],
        "chapter_id": slot["chapter_id"],
        "chapter_title": kc.get("chapter_title"),
        "concept_id": kc["concept_id"],
        "concept_name": kc["canonical_name"],
        "sub_concept": (kc.get("sub_concepts") or [None])[0],
        "composition": slot["composition"],
        "compose_with": [],
        "prerequisites": kc.get("prerequisites", []),
        "curriculum_boundary": kc.get("boundary", {}),
        "forbidden_terms": oos,
        "chapter_weight": round(chapter_weight, 6),
        "concept_weight": round(concept_weight, 6),
        "archetype": slot["archetype"],
        "lane": slot["lane"],
        "question_type": "MCQ",
        "reasoning_depth": slot["reasoning_depth"],
        "intended_depth": slot["reasoning_depth"],   # alias consumed by planner.check_plan
        "difficulty": slot["difficulty"],
        "target_difficulty": slot["target_difficulty"],
        "difficulty_drivers": slot["difficulty_drivers"],
        "difficulty_basis": (f"bounded driver model {slot['difficulty_model']} "
                             f"score={slot['difficulty_score']}"
                             + ("" if slot["difficulty_target_met"]
                                else f"; target {slot['target_difficulty']!r} unreachable for archetype "
                                     f"-> realized {slot['difficulty']!r}")),
        "learning_objective": learning_objective(kc["canonical_name"], slot["archetype"]),
        "expected_solving_path": None,       # certified QDI solution_structure -> Phase 4
        "misconceptions_to_evaluate": [],    # certified QDI misconceptions   -> Phase 4
        "pattern_id": None,                  # certified QDI pattern           -> Phase 4
        "visual_required": False,
        "planner_evidence": {
            "foundation_version": foundation_version,
            "examdna_version": examdna_version,
            "difficulty_model": slot["difficulty_model"],
            "occurrence": slot["occurrence"],
            "provenance": "certified ki_concept + Exam DNA + bounded difficulty model",
        },
        "status": "planned",
    }
    bp["blueprint_fingerprint"] = _fingerprint(bp)
    bp["blueprint_id"] = "QBP_" + hashlib.sha256(
        f"{bp['blueprint_fingerprint']}|{slot['occurrence']}".encode()).hexdigest()[:16]
    bp["spec_id"] = bp["blueprint_id"]  # persistence PK (generation_spec)
    return bp
