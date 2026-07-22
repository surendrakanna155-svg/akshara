"""Program B · B4 — structural difficulty (OD-3) + marking-scheme extraction (OD-6).

The load-bearing checks: difficulty is ALWAYS labelled `structural_proxy` (never a measured student-difficulty
claim, OD-3); a marking scheme is `parsed_from_paper` / `published` / `honest_null` and a VARIABLE scheme (JEE
Advanced, JEE Main numerical) is honest-null — never fabricated (OD-6). Live tests self-skip when DBs absent.
"""
from __future__ import annotations

import hashlib
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie.pyq import difficulty as DF
from kie.qie.pyq import marking as MK
from kie.qie.pyq import mining as MI
from kie.qie.pyq import source_class as SC
from kie.qie.pyq import subject_seg as SS

_KIE_DB = config.DB_PATH


class TestStructuralDifficulty(unittest.TestCase):
    def test_type_and_length_drive_the_proxy(self):
        self.assertEqual(DF.structural_difficulty("mcq", 100)[0], "easy")         # short single MCQ
        self.assertEqual(DF.structural_difficulty("mcq", 500)[0], "easy")         # one length bump → score 1
        self.assertEqual(DF.structural_difficulty("mcq", 1000)[0], "moderate")    # two length bumps → score 2
        self.assertEqual(DF.structural_difficulty("assertion_reason", 500)[0], "hard")
        self.assertEqual(DF.structural_difficulty("match", 100)[0], "moderate")   # type weight 2
        self.assertEqual(DF.structural_difficulty("numerical", 1000)[0], "hard")

    def test_deterministic(self):
        self.assertEqual(DF.structural_difficulty("mcq", 300), DF.structural_difficulty("mcq", 300))


class TestMarkingParse(unittest.TestCase):
    def test_parse_plus4_minus1_in_marking_context(self):
        p4, n1 = MK.parse_doc_scheme("+4 marks will be awarded for a correct answer and 1 mark will be "
                                     "deducted for each incorrect response.")
        self.assertTrue(p4 and n1)

    def test_stray_physics_tokens_are_not_a_scheme(self):
        # the P2 fix: a physics quantity like "+4 μC ... −1 m" must NOT count as marking-scheme evidence
        p4, n1 = MK.parse_doc_scheme("A +4 μC charge moves −1 m along the field; oxidation state +4 to −1.")
        self.assertFalse(p4 or n1, "token co-occurrence is not a marking scheme (dishonest provenance otherwise)")

    def test_no_scheme_text(self):
        p4, n1 = MK.parse_doc_scheme("A block of mass M slides down a frictionless plane.")
        self.assertFalse(p4 or n1)

    def test_variable_schemes_are_honest_null_never_fabricated(self):
        # OD-6: JEE Advanced (section/year dependent) and JEE Main numerical (changed by year) must be honest-null
        self.assertIn(("JEE_ADVANCED", "any"), MK._HONEST_NULL)
        self.assertIn(("JEE_MAIN", "numerical"), MK._HONEST_NULL)
        # published schemes are only the STABLE ones
        self.assertEqual(set(MK._PUBLISHED), {("NEET", "mcq"), ("JEE_MAIN", "mcq")})


@unittest.skipUnless(_KIE_DB.exists(), "kie.db not present (gitignored, local only)")
class TestLiveB4(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.pyq = os.path.join(cls.tmp.name, "pyq_corpus.db")
        cls.b = hashlib.md5(_KIE_DB.read_bytes()).hexdigest()
        SC.build(pyq_db_path=cls.pyq)
        SS.build(pyq_db_path=cls.pyq)
        MI.build(pyq_db_path=cls.pyq)
        cls.diff = DF.build(pyq_db_path=cls.pyq)
        cls.mark = MK.build(pyq_db_path=cls.pyq)
        cls.a = hashlib.md5(_KIE_DB.read_bytes()).hexdigest()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _q(self, sql):
        c = sqlite3.connect(f"file:{self.pyq}?mode=ro", uri=True)
        try:
            return c.execute(sql).fetchall()
        finally:
            c.close()

    def test_freeze_byte_identical(self):
        self.assertEqual(self.b, self.a)

    def test_every_item_has_structural_proxy_difficulty_only(self):
        # OD-3: NOTHING may be labelled measured; every difficulty row is a structural proxy
        total_items = self._q("SELECT COUNT(*) FROM pyq_item")[0][0]
        diff_items = self._q("SELECT COUNT(*) FROM pyq_item_difficulty")[0][0]
        self.assertEqual(diff_items, total_items, "every item gets a structural difficulty")
        non_proxy = self._q("SELECT COUNT(*) FROM pyq_item_difficulty WHERE difficulty_basis <> 'structural_proxy'")[0][0]
        self.assertEqual(non_proxy, 0, "OD-3: difficulty must never be labelled measured/pilot")

    def test_marking_variable_schemes_are_null(self):
        # JEE Advanced + JEE Main numerical must be honest-null with NULL marks (never a fabricated value)
        bad = self._q("SELECT COUNT(*) FROM marking_scheme WHERE provenance_class='honest_null' "
                      "AND (marks_correct IS NOT NULL OR marks_incorrect IS NOT NULL)")[0][0]
        self.assertEqual(bad, 0, "an honest-null marking scheme must carry NULL marks")
        adv = self._q("SELECT provenance_class FROM marking_scheme WHERE exam='JEE_ADVANCED'")
        self.assertTrue(adv and all(p == "honest_null" for (p,) in adv),
                        "JEE Advanced marking is variable → honest-null, never fabricated")

    def test_stable_mcq_schemes_present(self):
        neet = self._q("SELECT marks_correct, marks_incorrect FROM marking_scheme WHERE exam='NEET' AND question_type='mcq'")
        self.assertEqual(neet, [(4, -1)])

    def test_determinism(self):
        with tempfile.TemporaryDirectory() as t:
            p = os.path.join(t, "p.db")
            SC.build(pyq_db_path=p)
            SS.build(pyq_db_path=p)
            MI.build(pyq_db_path=p)
            d2 = DF.build(pyq_db_path=p)
            m2 = MK.build(pyq_db_path=p)
        self.assertEqual(self.diff["stats"], d2["stats"])
        self.assertEqual(self.mark["by_provenance"], m2["by_provenance"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
