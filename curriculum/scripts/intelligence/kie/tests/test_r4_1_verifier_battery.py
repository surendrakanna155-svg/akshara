"""R4-1(a) — the reusable 7-method verifier battery. Fixture-only (stdlib + sympy; NO DB), always runs in CI.

Each verifier re-verifies a real generator record → `agree`, and a deliberately corrupted control → `disagree`
(the lane's "ship >=1 damaged control, it MUST be rejected" law). The 8th deterministic gate
(`notation_recovery`) re-certifies a valid relation and rejects a dimensionally-broken one. And the standing
law is made structural: model agreement is NOT a verifier here and can never reach an `agree`.
"""
from __future__ import annotations

import unittest

from kie.qie import (autocompose, biology, compositions, generate_calculus, generate_jee_math,
                     generate_numeric, genetics)
from kie.qie.verifiers import battery, notation_recovery
from kie.qie.verifiers.protocol import (MODEL_AGREEMENT_METHOD, ModelAgreementIsNotAVerifier,
                                        assert_not_model_agreement)


def _first(cands):
    assert cands, "generator produced no candidate for the fixture"
    return cands[0]


class TestBatteryGoldenAndDamaged(unittest.TestCase):
    """Golden (agree) + damaged-control (disagree) for each of the 7 deterministic question-item methods."""

    def _agree_then_damage(self, name, cand, expect_method):
        r = battery.verify_any(cand)
        self.assertEqual(r.method, expect_method, f"{name}: wrong method dispatched")
        self.assertTrue(r.is_deterministic, f"{name}: must be deterministic")
        self.assertIs(r.ok, True, f"{name}: golden record must re-verify agree ({r.reason})")
        dmg = {**cand, "answer_text": "-987654321", "options": {**cand["options"]}}
        rd = battery.verify_any(dmg)
        self.assertIsNot(rd.ok, True, f"{name}: damaged control MUST NOT agree (got {rd.verdict})")

    def test_deterministic_solver(self):
        self._agree_then_damage("deterministic_solver",
                                _first(generate_numeric.run(seed="N1")["verified_bank"]),
                                "deterministic_solver")

    def test_symbolic_inverse(self):
        self._agree_then_damage("symbolic_inverse", _first(generate_calculus.generate(2, "C1")),
                                "symbolic_inverse")

    def test_independent_second_method(self):
        self._agree_then_damage("independent_second_method", _first(generate_jee_math.generate(2, "J1")),
                                "independent_second_method")

    def test_per_step_e2e(self):
        self._agree_then_damage("per_step_e2e", _first(compositions.generate(per_template=2, seed="K1")),
                                "per_step+independent_e2e")

    def test_type_directed(self):
        self._agree_then_damage("type_directed", _first(autocompose.generate(2, "AC1")),
                                "type_directed+per_step_independent")

    def test_two_way_genetics(self):
        self._agree_then_damage("two_way", _first(compositions.generate(genetics.TEMPLATES, 2, "G1")),
                                "deterministic_two_way")

    def test_kb_lookup_biology(self):
        self._agree_then_damage("kb_lookup", _first(compositions.generate(biology.TEMPLATES, 2, "B1")),
                                "deterministic_kb_lookup")


class TestNotationRecoveryGate(unittest.TestCase):
    """Method 8: the 5-gate deterministic relation certifier."""

    VALID = {
        "name": "Ohm's law", "subject": "Physics", "concept_candidate": "Physics :: Current Electricity",
        "equation": "V = I*R", "lhs_unit": "V",
        "symbols": {"V": "V", "I": "A", "R": "ohm"},
        "provenance": {"store_path": "resources/foundation/x.zip", "page": 3},
    }

    def test_valid_relation_certifies(self):
        r = notation_recovery.verify(self.VALID)
        self.assertIs(r.ok, True, f"valid relation should certify: {r.reason}")
        self.assertTrue(r.is_deterministic)

    def test_dimensionally_broken_relation_rejected(self):
        # RHS drops the resistance -> V and I*(dimensionless) no longer share base dimensions -> DIMENSIONAL fail.
        broken = {**self.VALID, "equation": "V = I", "symbols": {"V": "V", "I": "A"}}
        r = notation_recovery.verify(broken)
        self.assertIsNot(r.ok, True, "a dimensionally-broken relation MUST be rejected")

    def test_missing_provenance_rejected(self):
        noprov = {**self.VALID, "provenance": {}}
        self.assertIsNot(notation_recovery.verify(noprov).ok, True)


class TestModelAgreementIsNotAVerifier(unittest.TestCase):
    """The standing law (audit §11), made structural: model agreement can reject but never certify."""

    def test_assert_not_model_agreement_raises(self):
        with self.assertRaises(ModelAgreementIsNotAVerifier):
            assert_not_model_agreement(MODEL_AGREEMENT_METHOD)

    def test_agree_absent_from_registry(self):
        self.assertNotIn(MODEL_AGREEMENT_METHOD, battery.BY_METHOD)
        self.assertFalse(battery.is_deterministic_method(MODEL_AGREEMENT_METHOD))

    def test_verify_any_refuses_named_model_agreement(self):
        with self.assertRaises(ModelAgreementIsNotAVerifier):
            battery.verify_any({"method": "agree", "stem": "x", "options": {"1": "a"}, "answer_text": "a"})

    def test_reverify_model_agreement_row_is_held_never_agree(self):
        r = battery.reverify_from_record({"refuter_verdict": "agree", "stem": "s",
                                          "answer_text": "a", "options": "{}"})
        self.assertEqual(r.verdict, "held_qualitative")
        self.assertIs(r.ok, None)                       # honest-null, NEVER True
        self.assertFalse(r.is_deterministic)

    def test_all_registered_verifiers_are_deterministic(self):
        for mod in battery.ALL_VERIFIERS:
            self.assertTrue(mod.IS_DETERMINISTIC, f"{mod.NAME} must be deterministic")


class TestHonestNullReverify(unittest.TestCase):
    """A deterministic method whose structured payload was not persisted re-verifies honest-null (ok=None)."""

    def test_calculus_row_without_payload_is_unavailable(self):
        r = battery.reverify_from_record({"refuter_verdict": "symbolic_inverse", "stem": "Evaluate ...",
                                          "answer_text": "x^2", "options": "{}"})
        self.assertIs(r.ok, None)
        self.assertEqual(r.verdict, "unavailable")

    def test_rendered_numeric_reverifies_from_content(self):
        nb = _first(generate_numeric.run(seed="N1")["verified_bank"])
        row = {"refuter_verdict": "deterministic_solver", "stem": nb["stem"], "options": nb["options"],
               "answer_text": nb["answer_text"], "subject": nb["subject"]}
        self.assertIs(battery.reverify_from_record(row).ok, True)


if __name__ == "__main__":
    unittest.main()
