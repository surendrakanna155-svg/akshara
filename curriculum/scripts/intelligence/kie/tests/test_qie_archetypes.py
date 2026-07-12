"""Phase C slice 2 — canonical archetype vocabulary + classifier (archetype = form, never a lane)."""
import unittest

from kie.qie import archetypes as A


class TestVocabulary(unittest.TestCase):
    def test_ratified_archetypes_present(self):
        for a in ("direct_recall", "definition_recognition", "factual_single_best_answer",
                  "single_step_numerical", "assertion_reason", "cause_effect", "comparison",
                  "multi_concept_integration"):
            self.assertIn(a, A.ARCHETYPES)
        self.assertEqual(len(A.ARCHETYPES), len(set(A.ARCHETYPES)))  # no dups

    def test_factual_recall_is_an_archetype_not_a_lane(self):
        self.assertTrue(A.is_archetype("factual_single_best_answer"))
        # it verifies via a conceptual lane, but is NOT itself a lane named FACTUAL_RECALL
        self.assertEqual(A.verification_lane("factual_single_best_answer"), "CONCEPTUAL_CAUSAL")
        self.assertNotIn("FACTUAL_RECALL", A.ARCHETYPES)


class TestClassify(unittest.TestCase):
    def test_numeric_with_relation(self):
        self.assertEqual(A.classify("A resistor of 30 ohm carries 9 A. Find voltage.", is_numeric=True,
                                    relation_verified=True), "single_step_numerical")

    def test_structural_markers(self):
        self.assertEqual(A.classify("Assertion (A): x. Reason (R): y."), "assertion_reason")
        self.assertEqual(A.classify("What is the difference between mitosis and meiosis?"), "comparison")
        self.assertEqual(A.classify("Blood calcium level is lowered by the deficiency of"), "cause_effect")
        self.assertEqual(A.classify("Define osmosis."), "definition_recognition")
        self.assertEqual(A.classify("Match List I with List II and choose the correct option"),
                         "multi_concept_integration")
        self.assertEqual(A.classify("From the graph, the acceleration is"), "graph_interpretation")

    def test_plain_factual_defaults_to_factual_single_best_answer(self):
        # the corrected home of the old CONCEPTUAL_GENERIC black hole
        self.assertEqual(A.classify("The basic functional unit of the human kidney is"),
                         "factual_single_best_answer")
        self.assertEqual(A.classify("Hypoglycemic hormone is"), "factual_single_best_answer")

    def test_archetype_never_equals_lane(self):
        # every classified archetype maps to a lane that is a DIFFERENT string identity
        for stem in ("The functional unit of the kidney is", "Assertion x Reason y",
                     "difference between a and b"):
            arch = A.classify(stem)
            self.assertIn(arch, A.ARCHETYPES)
            self.assertNotEqual(arch, A.verification_lane(arch))


if __name__ == "__main__":
    unittest.main()
