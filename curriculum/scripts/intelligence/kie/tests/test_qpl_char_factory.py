"""Characterization tests — Phase 0 preservation lock (Question Planning Layer: factory verify + certify).

These PIN the CURRENT behaviour of the deterministic downstream that makes structured specs certifiable:
    factory/gates.py    — the sympy independent solver + notation comparator + gate battery
    factory/controls.py — the adversarial self-test of that battery (must-catch + must-not-cry-wolf)
    factory/certify.py  — the exact promotion rule (structured-numeric certifiable; qualitative parked)

They assert behaviour AS-IS so a Phase 1+ refactor cannot silently weaken the verification/certification
spine. They are not a specification of desired behaviour.
"""
from __future__ import annotations

import sqlite3
import unittest

from kie import config
from kie.qie.factory import certify as CERT
from kie.qie.factory import controls as C
from kie.qie.factory import corpus as CO
from kie.qie.factory import gates as G

_QIE = config.KIE_HOME / "qie.db"


def _load_registry():
    """Real certified-relation index + equations from qie.db (read-only), or empty if the local store is
    absent. Blocking grounding (R1-1) needs a real registry so the good base + order-swap controls survive."""
    if not _QIE.exists():
        return {}, []
    q = sqlite3.connect(f"file:{_QIE}?mode=ro", uri=True)
    q.row_factory = sqlite3.Row
    try:
        return G.load_certified_relations(q), G.load_certified_relation_eqs(q)
    finally:
        q.close()


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
        # With blocking grounding (R1-1) the battery must be run against the REAL certified registry: the good
        # base item (F=m*a) and the order-swap survivor (F=a*m) ground, while the KE=m*v**2 and units-stripped
        # controls are caught. An empty registry would still pass (grounding fails known-bad), but real
        # relations exercise the must-not-cry-wolf path.
        cr, ceq = _load_registry()
        ctx = {"spec": C._spec(), "seen_norm": {}, "corpus": [],
               "certified_relations": cr, "certified_relation_eqs": ceq}
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
        cid = CO._cid("R", spec_id)
        # certify_run requires a gate battery bound to the candidate's CURRENT content (R1-2). This suite pins
        # the promotion MATRIX (ind + judge outcomes), not the gate battery, so seed one passing gate row.
        CO.record_gates(conn, cid, [{"gate": "schema", "ok": True, "severity": G.FATAL, "detail": "seed"}])
        return cid

    def _seed_solution_stage(self, conn, cid, solution=True, distractor=True):
        """R2-2: seed the solution_verified + distractor_verified gates (content-bound) so the matrix can
        isolate the ind/judge dimensions above the mandatory solution stage."""
        gs = []
        if solution:
            gs.append({"gate": "solution_verified", "ok": True, "severity": G.FATAL, "detail": "seed"})
        if distractor:
            gs.append({"gate": "distractor_verified", "ok": True, "severity": G.FATAL, "detail": "seed"})
        if gs:
            CO.record_gates(conn, cid, gs)

    def _status(self, conn, cid):
        return conn.execute("SELECT status FROM candidate WHERE candidate_id=?", (cid,)).fetchone()[0]

    def test_promotion_matrix(self):
        """The R2 promotion ladder: gates -> solution -> distractor -> independent -> cross-family judge.
        'gen' is the candidates' generator family; a judge_family != 'gen' is cross-family (R2-1)."""
        conn = CO.open_store(":memory:")
        try:
            # 1. full R2 evidence + independent agree + CROSS-FAMILY judge accept -> CERTIFIED (product-visible)
            c1 = self._seed(conn, "SPEC_a", "STRUCTURED_NUMERIC")
            self._seed_solution_stage(conn, c1)
            CO.record_independent(conn, c1, "sympy", "1", "1", "agree", "")
            CO.record_judge(conn, c1, "judge", True, {"verdict": "accept"}, judge_family="human-review")
            # 2. full R2 evidence + independent agree + SAME-FAMILY judge -> PROVISIONAL (product-invisible)
            c2 = self._seed(conn, "SPEC_b", "STRUCTURED_NUMERIC")
            self._seed_solution_stage(conn, c2)
            CO.record_independent(conn, c2, "sympy", "1", "1", "agree", "")
            CO.record_judge(conn, c2, "judge", False, {"verdict": "accept"}, judge_family="gen")
            # 3. full evidence but independent DISAGREE -> QUARANTINED (held_no_independent)
            c3 = self._seed(conn, "SPEC_c", "STRUCTURED_NUMERIC")
            self._seed_solution_stage(conn, c3)
            CO.record_independent(conn, c3, "sympy", "9", "1", "disagree", "")
            CO.record_judge(conn, c3, "judge", True, {"verdict": "accept"}, judge_family="human-review")
            # 4. NO solution stage -> QUARANTINED (held_no_solution), before the independent check is reached
            c4 = self._seed(conn, "SPEC_d", "STRUCTURED_NUMERIC")
            CO.record_independent(conn, c4, "sympy", "1", "1", "agree", "")
            CO.record_judge(conn, c4, "judge", True, {"verdict": "accept"}, judge_family="human-review")
            # 5. solution but NO distractor gate -> QUARANTINED (held_no_distractors)
            c5 = self._seed(conn, "SPEC_e", "STRUCTURED_NUMERIC")
            self._seed_solution_stage(conn, c5, distractor=False)
            CO.record_independent(conn, c5, "sympy", "1", "1", "agree", "")
            CO.record_judge(conn, c5, "judge", True, {"verdict": "accept"}, judge_family="human-review")
            # 6. judge reject -> REJECTED (before any R2 leg)
            c6 = self._seed(conn, "SPEC_f", "STRUCTURED_NUMERIC")
            self._seed_solution_stage(conn, c6)
            CO.record_independent(conn, c6, "sympy", "1", "1", "agree", "")
            CO.record_judge(conn, c6, "judge", True, {"verdict": "reject"}, judge_family="human-review")
            # 7. judge missing -> skipped, stays CANDIDATE
            c7 = self._seed(conn, "SPEC_g", "STRUCTURED_NUMERIC")
            self._seed_solution_stage(conn, c7)
            CO.record_independent(conn, c7, "sympy", "1", "1", "agree", "")

            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 1)
            self.assertEqual(m["provisional_same_actor"], 1)
            self.assertEqual(m["held_no_independent"], 1)
            self.assertEqual(m["held_no_solution"], 1)
            self.assertEqual(m["held_no_distractors"], 1)
            self.assertEqual(m["judge_rejected"], 1)
            self.assertEqual(m["judge_missing"], 1)

            self.assertEqual(self._status(conn, c1), CO.CERTIFIED)
            self.assertEqual(self._status(conn, c2), CO.CERTIFIED)          # status certified...
            self.assertEqual(conn.execute("SELECT certification_class FROM candidate WHERE candidate_id=?",
                                          (c2,)).fetchone()[0], CO.CERT_PROVISIONAL)  # ...but provisional
            self.assertEqual(self._status(conn, c3), CO.QUARANTINED)
            self.assertEqual(self._status(conn, c4), CO.QUARANTINED)
            self.assertEqual(self._status(conn, c5), CO.QUARANTINED)
            self.assertEqual(self._status(conn, c6), CO.REJECTED)
            self.assertEqual(self._status(conn, c7), CO.CANDIDATE)

            # the quarantine boundary: only the FULL (cross-family) certification is product-visible; the
            # provisional same-actor row (c2) is not.
            inv = CO.product_inventory(conn, "R")
            self.assertEqual({r["candidate_id"] for r in inv}, {c1})
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
