"""Characterization tests — Phase 0 preservation lock (Question Planning Layer: factory verify + certify).

These PIN the CURRENT behaviour of the deterministic downstream that makes structured specs certifiable:
    factory/gates.py    — the sympy independent solver + notation comparator + gate battery
    factory/controls.py — the adversarial self-test of that battery (must-catch + must-not-cry-wolf)
    factory/certify.py  — the exact promotion rule (structured-numeric certifiable; qualitative parked)

They assert behaviour AS-IS so a Phase 1+ refactor cannot silently weaken the verification/certification
spine. They are not a specification of desired behaviour.
"""
from __future__ import annotations

import unittest

from kie.qie.factory import certify as CERT
from kie.qie.factory import controls as C
from kie.qie.factory import corpus as CO
from kie.qie.factory import gates as G


class IndependentSolverChar(unittest.TestCase):
    def test_newton_second_law_is_solved(self):
        st = {"givens": {"F": {"value": 12, "unit": "N"}, "m": {"value": 3, "unit": "kg"},
                         "a": {"value": None, "unit": "m/s**2"}},
              "relation": "F = m * a", "solve_for": "a"}
        out = G.independent_solve(st)
        self.assertEqual(out["verdict"], "solved")
        self.assertAlmostEqual(out["solver_answer"], 4.0, places=6)

    def test_undetermined_symbol_is_refused_not_guessed(self):
        st = {"givens": {"F": {"value": 12, "unit": "N"}, "m": {"value": 3, "unit": "kg"},
                         "a": {"value": None, "unit": "m/s**2"}},
              "relation": "F = m * a * k", "solve_for": "a"}
        out = G.independent_solve(st)
        self.assertNotEqual(out["verdict"], "solved")

    def test_answers_agree_tolerance_is_pinned(self):
        ok, _ = G.answers_agree(4.0, "4")
        self.assertTrue(ok)
        ok, _ = G.answers_agree(4e-7, "8e-7")
        self.assertFalse(ok)


class GateBatteryControlsChar(unittest.TestCase):
    """The factory's own adversarial control suites. Each raises on a battery hole / comparator misread."""

    def test_magnitude_controls_hold(self):
        res = C.check_magnitude_controls()
        self.assertTrue(res["all_ok"])

    def test_notation_controls_hold(self):
        res = C.check_notation_controls()
        self.assertTrue(res["all_ok"])

    def test_full_gate_battery_catches_all_known_bad(self):
        ctx = {"spec": C._spec(), "seen_norm": {}, "corpus": [], "certified_relations": {}}
        res = C.check_controls(ctx)
        self.assertTrue(res["all_caught"])
        self.assertTrue(res["good_control_survives"])


class CertificationRuleChar(unittest.TestCase):
    """Pin the exact promotion matrix of certify.certify_run against an in-memory corpus."""

    def _seed(self, conn, spec_id, lane, structure_ok=True):
        CO.save_specs(conn, [{
            "spec_id": spec_id, "run_id": "R", "lane": lane, "board": "CBSE", "exam_profile": "NEET",
            "class_level": 11, "subject": "Physics", "concept_code": "C1", "concept_title": "T",
            "composition": "single", "archetype": "single_step_numerical", "question_type": "MCQ",
            "intended_depth": 1, "intended_difficulty": "easy", "visual_required": 0,
            "created_at": "2026-01-01T00:00:00+00:00",
        }])
        item = {
            "spec_id": spec_id, "stem": "A block experiences a net force. Find its acceleration.",
            "options": {"a": "1", "b": "2", "c": "3", "d": "4"}, "answer_label": "b", "answer_value": "2",
            "structure": ({"givens": {}, "relation": "x = 1", "solve_for": "x"} if structure_ok else {}),
        }
        CO.ingest(conn, "R", [item], "gen", "b1")
        return CO._cid("R", spec_id)

    def _status(self, conn, cid):
        return conn.execute("SELECT status FROM candidate WHERE candidate_id=?", (cid,)).fetchone()[0]

    def test_promotion_matrix(self):
        conn = CO.open_store(":memory:")
        try:
            # 1. structured + judge accept + independent agree -> CERTIFIED
            c1 = self._seed(conn, "SPEC_a", "STRUCTURED_NUMERIC")
            CO.record_independent(conn, c1, "sympy", "2", "2", "agree", "")
            CO.record_judge(conn, c1, "judge", True, {"verdict": "accept"})
            # 2. structured + judge accept + independent disagree -> QUARANTINED (held_no_independent)
            c2 = self._seed(conn, "SPEC_b", "STRUCTURED_NUMERIC")
            CO.record_independent(conn, c2, "sympy", "9", "2", "disagree", "")
            CO.record_judge(conn, c2, "judge", True, {"verdict": "accept"})
            # 3. judge reject -> REJECTED (even with independent agree)
            c3 = self._seed(conn, "SPEC_c", "STRUCTURED_NUMERIC")
            CO.record_independent(conn, c3, "sympy", "2", "2", "agree", "")
            CO.record_judge(conn, c3, "judge", True, {"verdict": "reject"})
            # 4. qualitative + judge accept + NO independent -> QUARANTINED (awaiting_independent_evidence)
            c4 = self._seed(conn, "SPEC_d", "QUALITATIVE")
            CO.record_judge(conn, c4, "judge", False, {"verdict": "accept"})
            # 5. judge missing -> skipped, stays CANDIDATE
            c5 = self._seed(conn, "SPEC_e", "STRUCTURED_NUMERIC")
            CO.record_independent(conn, c5, "sympy", "2", "2", "agree", "")

            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 1)
            self.assertEqual(m["judge_rejected"], 1)
            self.assertEqual(m["held_no_independent"], 2)  # disagree + no-independent both parked
            self.assertEqual(m["judge_missing"], 1)

            self.assertEqual(self._status(conn, c1), CO.CERTIFIED)
            self.assertEqual(self._status(conn, c2), CO.QUARANTINED)
            self.assertEqual(self._status(conn, c3), CO.REJECTED)
            self.assertEqual(self._status(conn, c4), CO.QUARANTINED)
            self.assertEqual(self._status(conn, c5), CO.CANDIDATE)

            # the quarantine boundary: only CERTIFIED is ever product-visible
            inv = CO.product_inventory(conn, "R")
            self.assertEqual({r["candidate_id"] for r in inv}, {c1})
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
