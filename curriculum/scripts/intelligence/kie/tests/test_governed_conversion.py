"""Tests for the Phase-6 governed evidence conversion pipeline + canonical evidence registry."""
import json
import unittest

from kie.qie import store as S
from kie.qie.convert import candidates as C
from kie.qie.convert import docmeta as DM
from kie.qie.convert import register as R
from kie.evidence import lifecycle as L
from kie.evidence import registry as REG


class TestDocMeta(unittest.TestCase):
    def test_subject_hard_gate_and_chapter(self):
        rec = {"doc_id": "d1", "rel_path": "studentbro_neet_dpps/NEET/Chemistry/1/NEET_Chemistry_DPP_Alcohols.pdf",
               "priority": "P2_studentbro_chemistry", "group": "studentbro_neet_dpps"}
        dm = DM.classify(rec)
        self.assertEqual(dm.subject, "Chemistry")
        self.assertTrue(dm.subject_confident)
        self.assertEqual(dm.exam, "NEET")
        self.assertIn("Alcohols", dm.chapter_hint)

    def test_conflicting_subject_returns_none(self):
        # rel_path says Physics, priority says chemistry -> disagreement -> unknown (conservative)
        rec = {"doc_id": "d2", "rel_path": "x/NEET/Physics/y.pdf", "priority": "P2_studentbro_chemistry",
               "group": "g"}
        dm = DM.classify(rec)
        self.assertIsNone(dm.subject)
        self.assertFalse(dm.subject_confident)

    def test_unknown_subject_doc(self):
        rec = {"doc_id": "d3", "rel_path": "allen_jee_main_mock/JEE_Main/Mock/Leader.pdf",
               "priority": "P9_allen_and_jeebooks", "group": "allen_jee_main_mock"}
        dm = DM.classify(rec)
        self.assertIsNone(dm.subject)          # mixed mock -> no single subject -> not certifiable
        self.assertEqual(dm.exam, "JEE_MAIN")


class TestOcrQuality(unittest.TestCase):
    def test_clean_prose_scores_high(self):
        self.assertGreater(C.ocr_quality("Which of the following is the function of the nephron?"), 0.6)

    def test_garbled_scores_low(self):
        self.assertLess(C.ocr_quality("@@0@ 17.@®0@ 18.@®0@ ,..._ I{) ..... ,..._"), 0.5)

    def test_ordinary_letters_not_penalized(self):
        # regression: an earlier glyph set penalized common letters (l/i/k/a/m/n)
        self.assertGreater(C.ocr_quality("wavelength range continuous emission maximum kinetic"), 0.6)


class TestFactLane(unittest.TestCase):
    def test_lanes(self):
        self.assertEqual(C.fact_lane("The function of the nephron is"), "STRUCTURE_FUNCTION")
        self.assertEqual(C.fact_lane("Arrange the following in the correct order of"), "PROCESS_SEQUENCE")
        self.assertEqual(C.fact_lane("Which of the following is an example of"), "CLASSIFICATION_TAXONOMIC")


class TestRegisterProjection(unittest.TestCase):
    def setUp(self):
        self.conn = S.open_store(":memory:")

    def _cand(self, lane, concept="Biology :: Test"):
        return C.Candidate("doc1", "Biology", "NEET", "Test", concept, lane,
                           "stem?", {"a": "right", "b": "wrong1", "c": "wrong2", "d": "wrong3"},
                           "a", "right", False, 0.9, "fk", "sig")

    def test_structure_function_projection(self):
        cand = self._cand("STRUCTURE_FUNCTION")
        v = dict(item_hash="h1", keep=1, answer_correct=1, on_topic=1, fact_text="The nephron filters blood.",
                 structured=dict(structure="nephron", function="filtration of blood", system="excretory system"))
        res = R.register_verified(self.conn, cand, v, "t", "m")
        self.assertEqual(res["kvs_store"], "kvs_structure_function")
        self.assertEqual(res["distractors"], 3)                     # 3 real wrong options seeded
        row = self.conn.execute("SELECT structure, function FROM kvs_structure_function").fetchone()
        self.assertEqual(row[0], "nephron")

    def test_sequence_projection_requires_three_steps(self):
        cand = self._cand("PROCESS_SEQUENCE")
        v = dict(item_hash="h2", keep=1, answer_correct=1, on_topic=1, fact_text="order",
                 structured=dict(process="p", ordered_steps=["a", "b", "c"]))
        res = R.register_verified(self.conn, cand, v, "t", "m")
        self.assertEqual(res["kvs_store"], "kvs_sequence")

    def test_assertion_fallback(self):
        cand = self._cand("CONCEPTUAL_CAUSAL")
        v = dict(item_hash="h3", keep=1, answer_correct=1, on_topic=1, fact_text="x causes y",
                 structured=dict(subject_term="x", predicate="causes", object_term="y"))
        res = R.register_verified(self.conn, cand, v, "t", "m")
        self.assertEqual(res["kvs_store"], "kvs_assertion")

    def test_rejected_persisted_and_never_reexamined(self):
        cand = self._cand("STRUCTURE_FUNCTION")
        R.register_rejected(self.conn, cand, dict(item_hash="h9", reason="garbled"), "t", "m")
        self.assertIn("h9", R.already_examined(self.conn))
        self.assertEqual(R.counts(self.conn)["governed_fact_rejected"], 1)


class TestGovernedConceptTitles(unittest.TestCase):
    """Owner decision A: governed chapters are in-scope ONLY if their title passes the SAME concept
    sanitizer as every other in-scope concept (regression: verbose filename-derived titles caused
    UNCLEAN_CONCEPT boundary breaches)."""

    def test_clean_title_strips_lead_noise_dedups_and_caps(self):
        from kie.qie import qp_bridge as QB
        t = QB._clean_title("Adv Current Electricity Current Current Density Drift Velocity Resistance")
        self.assertLessEqual(len(t.split()), 5)
        self.assertFalse(t.lower().startswith("adv"))
        self.assertEqual(t.split()[0], "Current")

    def test_cleaned_titles_pass_the_qpgen_sanitizer(self):
        from kie.qie import qp_bridge as QB
        from kie.qpgen import sanitize
        for raw in ("Excretory Products And Their Elimination", "Cell The Unit Of Life",
                    "Adv Current Electricity Current Current Density Drift Velocity Resistance"):
            self.assertTrue(sanitize.is_clean_concept(QB._clean_title(raw)), raw)

    def test_governed_concepts_are_subject_gated_and_clean(self):
        from kie.qie import qp_bridge as QB
        from kie.qpgen import sanitize
        concepts, by_chapter = QB._governed_concepts(["Biology"])
        for code, ref in concepts.items():
            self.assertEqual(ref.subject, "Biology")        # hard subject gate
            self.assertTrue(sanitize.is_clean_concept(ref.title), ref.title)
        for cc in by_chapter:
            self.assertTrue(cc.startswith("Biology ::"), cc)


class TestAssertionGenerationGate(unittest.TestCase):
    """Authoring an assertion item reuses the source's REAL distractors; the gate must reject the shapes
    that produce broken or giveaway questions (regression: matching-pair answers and answer-in-stem)."""

    def _u(self, answer, subject_term, predicate, object_term, distractors):
        from kie.qie.convert import kvs_compose as KV
        return KV._assert_usable(answer, subject_term, predicate, object_term, distractors)

    def test_accepts_clean_entity_answer_with_real_distractors(self):
        self.assertTrue(self._u("Pyruvic acid", "Pyruvic acid (pyruvate)", "is the common intermediate in",
                                "all types of respiration",
                                ["Acetyl CoA", "Oxaloacetate", "Tricarboxylic acid"]))

    def test_rejects_matching_pair_answer(self):
        # "Aschelminthes : Ancylostoma, Enterobius, Tubifex" -> incoherent stem
        self.assertFalse(self._u("Aschelminthes : Ancylostoma, Enterobius, Tubifex", "Tubifex",
                                 "belongs to the phylum", "Annelida",
                                 ["Annelida : Aphrodite", "Mollusca : Teredo", "Arthropoda : Buthus"]))

    def test_rejects_giveaway_answer_word_in_stem(self):
        # stem would contain "yeast" and the answer is "Ethyl alcohol- Yeast"
        self.assertFalse(self._u("Ethyl alcohol- Yeast", "Ethyl alcohol (ethanol) production",
                                 "is carried out by", "yeast (fermentation)",
                                 ["Acetic acid- Lactobacillus", "Cheese - Nitrobacter", "Curd - Azotobacter"]))

    def test_rejects_when_fewer_than_three_real_distractors(self):
        self.assertFalse(self._u("Pyruvic acid", "Pyruvic acid", "is the common intermediate in",
                                 "all respiration", ["Acetyl CoA", "Acetyl CoA"]))

    def test_rejects_when_answer_does_not_match_subject_term(self):
        self.assertFalse(self._u("quaternary structure", "Some unrelated term", "describes",
                                 "an arrangement", ["a", "b", "c"]))


class TestEvidenceRegistry(unittest.TestCase):
    def test_every_store_scans_without_error(self):
        reg = REG.build("2026-01-01T00:00:00Z")
        self.assertEqual(reg["totals"]["stores"], len(L.STORES))
        ids = {s["canonical_id"] for s in reg["stores"]}
        # the previously-'invisible' stores the owner flagged are all present
        for cid in ("RAW_CURSOR_DOWNLOADS", "STG_QCORPUS", "KDB_KIE", "KDB_QIE", "ARCH_BOARD_OUT_OF_SCOPE"):
            self.assertIn(cid, ids)

    def test_lifecycle_states_monotonic(self):
        self.assertLess(L.State.RAW_SOURCE.rank, L.State.VERIFIED_KNOWLEDGE.rank)
        self.assertLess(L.State.VERIFIED_KNOWLEDGE.rank, L.State.QIE_AVAILABLE.rank)


if __name__ == "__main__":
    unittest.main()
