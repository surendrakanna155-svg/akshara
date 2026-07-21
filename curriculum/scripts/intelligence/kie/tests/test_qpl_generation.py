"""Candidate-generation driver tests — the deterministic wiring of the AI candidate factory (Decision C):
brief emission, tolerant JSON loading, and the full ingest -> sympy verify -> judge -> certify loop on a
hand-built clean candidate (no model calls). Proves a structured-numeric item certifies iff sympy agrees."""
from __future__ import annotations

import os
import tempfile
import unittest

from kie import config
from kie.qie.factory import corpus as CO
from kie.qie.factory import judge as JUDGE
from kie.qie.factory import run_generation as G
from kie.qie.factory import solutions as SOL

QIE_STORE = config.KIE_HOME / "qie.db"


class GenerationWiring(unittest.TestCase):
    def test_generator_brief_contains_specs(self):
        rows = [{"spec_id": "S1", "class_level": 11, "subject": "Chemistry", "exam_profile": "JEE_MAIN",
                 "lane": "STRUCTURED_NUMERIC", "concept_title": "Molar Mass",
                 "concept_codes_all": '["Molar Mass"]', "composition": "single",
                 "archetype": "multi_step_numerical", "question_type": "MCQ", "intended_depth": 2,
                 "intended_difficulty": "moderate", "visual_required": 0,
                 "boundary": '{"forbidden_terms": ["calculus"]}'}]
        b = G.generator_brief(rows)
        self.assertIn("S1", b)
        self.assertIn("STRUCTURED_NUMERIC", b)

    def test_load_json_array_tolerates_fence(self):
        p = os.path.join(tempfile.mkdtemp(), "c.json")
        with open(p, "w") as f:
            f.write('```json\n[{"a": 1}]\n```')
        self.assertEqual(G.load_json_array(p), [{"a": 1}])


@unittest.skipUnless(QIE_STORE.exists(), "qie store not present (gitignored / local only)")
class GenerationEndToEnd(unittest.TestCase):
    def test_clean_structured_candidate_certifies_via_sympy(self):
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [{
                "spec_id": "S1", "run_id": "R", "lane": "STRUCTURED_NUMERIC", "board": None,
                "exam_profile": "JEE_MAIN", "class_level": 11, "subject": "Physics", "concept_code": "C",
                "concept_title": "Linear momentum", "concept_codes_all": '["Linear momentum"]',
                "composition": "single", "archetype": "single_step_numerical", "question_type": "MCQ",
                "intended_depth": 1, "intended_difficulty": "easy", "visual_required": 0,
                "boundary": '{"forbidden_terms": []}', "planner_evidence": "{}", "created_at": "planned"}])
            # base-unit relation (p = m*v) so the conservative dimensional gate confirms it outright
            cand = {
                "spec_id": "S1",
                "stem": "An object of mass 3 kg moves in a straight line at 4 m/s. Find the magnitude of its "
                        "linear momentum.",
                "options": {"a": "7 kg m/s", "b": "12 kg m/s", "c": "0.75 kg m/s", "d": "1 kg m/s"},
                "answer_label": "b", "answer_value": "12",
                "claimed": {"concepts": ["Linear momentum"], "archetype": "single_step_numerical",
                            "depth": 1, "difficulty": "easy", "composition": "single"},
                "structure": {"givens": {"m": {"value": 3, "unit": "kg"}, "v": {"value": 4, "unit": "m/s"},
                                         "p": {"value": None, "unit": "kg*m/s"}},
                              "relation": "p = m * v", "solve_for": "p", "answer_unit": "kg*m/s"},
            }
            self.assertEqual(G.ingest_candidates(conn, "R", [cand])["ingested"], 1)
            m = G.verify(conn, "R")
            self.assertEqual(m["independent"].get("agree"), 1)   # sympy re-derived 12/3 = 4
            cid = CO._cid("R", "S1")
            # R2-2 mandatory solution stage: each distractor's mis_relation must compute its option
            #   a: m+v=7 ; c: m/v=0.75 ; d: v-m=1
            SOL.ingest(conn, "R", [{"candidate_id": cid, "dispute": False,
                                    "solution": {"steps": ["p = m*v = 3*4"], "final": "12"},
                                    "distractor_rationale": {
                                        "a": {"misconception": "added instead of multiplied", "mis_relation": "p = m + v"},
                                        "c": {"misconception": "divided instead of multiplied", "mis_relation": "p = m/v"},
                                        "d": {"misconception": "subtracted the masses", "mis_relation": "p = v - m"}}}])
            # R2-1 independence: a CROSS-FAMILY (human) judge disposes the verdict with its OWN chosen_label
            JUDGE.ingest(conn, "R", [{
                "candidate_id": cid, "verdict": "accept", "chosen_label": "b", "well_posed": True,
                "curriculum_ok": True, "unique_answer": True, "concepts_real": True,
                "difficulty_plausible": True, "distractors_plausible": True}],
                "human-examiner", judge_family="human-review", require_controls=False)
            self.assertEqual(G.certify(conn, "R")["certified"], 1)
            self.assertEqual(len(CO.product_inventory(conn, "R")), 1)  # certified -> product-visible
        finally:
            conn.close()

    def test_wrong_key_is_not_certified(self):
        # a candidate whose relation refutes its own key must NOT certify (sympy disagree -> rejected)
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [{
                "spec_id": "S2", "run_id": "R", "lane": "STRUCTURED_NUMERIC", "board": None,
                "exam_profile": "JEE_MAIN", "class_level": 11, "subject": "Physics", "concept_code": "C",
                "concept_title": "Newton's second law", "concept_codes_all": '["Newton\'s second law"]',
                "composition": "single", "archetype": "single_step_numerical", "question_type": "MCQ",
                "intended_depth": 1, "intended_difficulty": "easy", "visual_required": 0,
                "boundary": '{"forbidden_terms": []}', "planner_evidence": "{}", "created_at": "planned"}])
            cand = {"spec_id": "S2", "stem": "A block of mass 3 kg under a net force of 12 N. Find acceleration.",
                    "options": {"a": "2 m/s^2", "b": "4 m/s^2", "c": "6 m/s^2", "d": "9 m/s^2"},
                    "answer_label": "c", "answer_value": "6",  # WRONG: 12/3 = 4, not 6
                    "claimed": {"concepts": ["Newton's second law"], "archetype": "single_step_numerical",
                                "depth": 1, "difficulty": "easy", "composition": "single"},
                    "structure": {"givens": {"F": {"value": 12, "unit": "N"}, "m": {"value": 3, "unit": "kg"},
                                             "a": {"value": None, "unit": "m/s**2"}},
                                  "relation": "F = m * a", "solve_for": "a", "answer_unit": "m/s**2"}}
            G.ingest_candidates(conn, "R", [cand])
            G.verify(conn, "R")
            cid = CO._cid("R", "S2")
            G.ingest_judgements(conn, "R", [{"candidate_id": cid, "verdict": "accept", "answer_correct": True}])
            self.assertEqual(G.certify(conn, "R")["certified"], 0)  # sympy disagree -> never certified
            self.assertEqual(len(CO.product_inventory(conn, "R")), 0)
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
