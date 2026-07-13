"""Phase C slice 1 — canonical assessment-profile taxonomy + source map + profile-gated archetype validity."""
import unittest

from kie.qie import profiles as P


class TestTaxonomy(unittest.TestCase):
    def test_ratified_profiles_present(self):
        for name in ("BOARD_6_10", "CBSE_6_10", "AP_SCERT_6_10", "TS_SCERT_6_10", "ICSE_6_10",
                     "FOUNDATION", "JEE_FOUNDATION", "NEET_FOUNDATION", "JEE_MAIN", "NEET", "JEE_ADVANCED"):
            self.assertIn(name, P.PROFILES)

    def test_jee_advanced_gated(self):
        self.assertFalse(P.is_permitted("JEE_ADVANCED"))
        self.assertTrue(P.is_permitted("NEET"))

    def test_archetype_vocab_validated_at_import(self):
        # if this import succeeded, every profile's archetypes are in the canonical vocabulary
        self.assertTrue(P.PROFILES)  # import-time _validate_against_archetypes did not raise


class TestSourceMap(unittest.TestCase):
    def test_measured_sources_map_correctly(self):
        self.assertEqual(P.profile_for_source("studentbro_neet_dpps"), "NEET")
        self.assertEqual(P.profile_for_source("AIPMT"), "NEET")
        self.assertEqual(P.profile_for_source("AIIMS"), "NEET")
        self.assertEqual(P.profile_for_source("mathongo_jee_main_chapterwise"), "JEE_MAIN")
        self.assertEqual(P.profile_for_source("JEE_Advanced"), "JEE_ADVANCED")
        self.assertEqual(P.profile_for_source("jeeadv_ac_in_archive"), "JEE_ADVANCED")
        self.assertEqual(P.profile_for_source("Practice_Resources"), "NEET_FOUNDATION")
        self.assertEqual(P.profile_for_source("physicsaholics_dpps"), "FOUNDATION")
        self.assertEqual(P.profile_for_source("CBSE_NCERT"), "CBSE_6_10")
        self.assertEqual(P.profile_for_source("TS_SCERT"), "TS_SCERT_6_10")

    def test_unknown_source_is_unresolved(self):
        self.assertIsNone(P.profile_for_source("totally_unknown_source_xyz"))


class TestProfileGating(unittest.TestCase):
    def test_factual_recall_valid_for_neet_not_for_jee_main(self):
        # the profile-gate: factual recall is a legitimate NEET archetype, invalid as a JEE_MAIN item
        self.assertTrue(P.is_valid_archetype_for("NEET", "factual_single_best_answer"))
        self.assertFalse(P.is_valid_archetype_for("JEE_MAIN", "factual_single_best_answer"))

    def test_calculus_style_multi_step_valid_for_jee_not_board(self):
        self.assertTrue(P.is_valid_archetype_for("JEE_MAIN", "multi_step_numerical"))
        # board 6-10 does not admit multi-step competitive numerical as a valid archetype
        self.assertFalse(P.is_valid_archetype_for("CBSE_6_10", "multi_step_numerical"))

    def test_recall_permitted_but_capped_on_board(self):
        # recall is VALID on board (permitted) but not a CORE (dominant) archetype there
        self.assertTrue(P.is_valid_archetype_for("CBSE_6_10", "direct_recall"))
        self.assertNotIn("direct_recall", P.PROFILES["CBSE_6_10"].core_archetypes)


class TestItemProfile(unittest.TestCase):
    def test_depth_based_not_source_based(self):
        # calculus -> JEE regardless of source (even a NEET-labelled source)
        self.assertEqual(P.item_profile("Mathematics", "Evaluate the integral of x^2 dx",
                                        source_profile="NEET_FOUNDATION"), "JEE_MAIN")
        # single-relation numeric -> FOUNDATION (shared), even from a JEE-labelled source
        self.assertEqual(P.item_profile("Physics", "A resistor of 10 ohm carries 2 A. Find V.",
                                        single_relation=True, source_profile="JEE_MAIN"), "FOUNDATION")
        # multi-quantity unsolved-by-one-relation -> JEE_MAIN (multi-step depth)
        self.assertEqual(P.item_profile("Physics", "A projectile ... with these five values",
                                        distinct_given=5, single_relation=False), "JEE_MAIN")

    def test_biology_is_neet_domain(self):
        self.assertEqual(P.item_profile("Biology", "The functional unit of the kidney is",
                                        source_profile="FOUNDATION"), "NEET")

    def test_calculus_regex_no_biology_false_positive(self):
        # a Biology stem with a stray 'dx'-like token must NOT be flagged calculus
        self.assertNotEqual(P.item_profile("Chemistry", "The oxidation state of Cr in K2Cr2O7 is",
                                           single_relation=False, source_profile="NEET"), "JEE_MAIN")

    def test_indeterminate_falls_back_to_source(self):
        self.assertEqual(P.item_profile("Physics", "Which statement about waves is correct?",
                                        source_profile="NEET"), "NEET")


if __name__ == "__main__":
    unittest.main()
