"""Program B · B5 — measured Exam DNA v2 (R5-4).

Load-bearing checks: a dimension is measured ONLY at/above the OD-5 floor of 30 mined docs (else honest-null
`insufficient_evidence` with NULL probability — never fabricated); measurement is per-doc-NORMALIZED (booklet
instance duplication cannot distort it); subject weight is `published`; measured student difficulty is never
claimed (structural_proxy only); and `examdna.db` v1 is byte-identical (OD-6). Live tests self-skip when absent.
"""
from __future__ import annotations

import hashlib
import math
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie.pyq import dna_v2 as D2
from kie.qie.pyq import difficulty as DF
from kie.qie.pyq import marking as MK
from kie.qie.pyq import mining as MI
from kie.qie.pyq import source_class as SC
from kie.qie.pyq import subject_seg as SS

_KIE_DB = config.DB_PATH
_EXAMDNA = config.KIE_HOME / "examdna.db"


class TestPerSittingNormalization(unittest.TestCase):
    def test_sitting_then_doc_then_item_averaging(self):
        # sitting A = 2 docs (a1: 2 mcq → {mcq:1}; a2: 1 match → {match:1}) → sitting A = {mcq:.5, match:.5};
        # sitting B = 1 doc (1 numerical) → {numerical:1}. Overall = avg(A,B) = {mcq:.25, match:.25, numerical:.5}.
        dist, ns, nd, ni = D2._per_sitting_normalized(
            [("A", "a1", "mcq"), ("A", "a1", "mcq"), ("A", "a2", "match"), ("B", "b1", "numerical")])
        self.assertEqual((ns, nd, ni), (2, 3, 4))
        self.assertAlmostEqual(dist["mcq"], 0.25)
        self.assertAlmostEqual(dist["match"], 0.25)
        self.assertAlmostEqual(dist["numerical"], 0.5)

    def test_booklet_pdfs_of_one_sitting_count_once(self):
        # the same sitting present as 40 near-identical booklet docs must NOT out-weight a single-doc sitting
        many = [(f"2020", f"d{i}", "mcq") for i in range(40)] + [("2019", "x", "match")]
        _, ns, _, _ = D2._per_sitting_normalized(many)
        self.assertEqual(ns, 2, "40 booklet PDFs of the 2020 sitting are ONE independent sitting")

    def test_floor_is_thirty_independent_sittings(self):
        self.assertEqual(D2.FLOOR, 30)   # OD-5: 30 INDEPENDENT PYQs (sittings), not raw docs


@unittest.skipUnless(_KIE_DB.exists(), "kie.db not present (gitignored, local only)")
class TestLiveB5(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.pyq = os.path.join(cls.tmp.name, "pyq_corpus.db")
        cls.v1_before = hashlib.md5(_EXAMDNA.read_bytes()).hexdigest() if _EXAMDNA.exists() else None
        for step in (SC.build, SS.build, MI.build, DF.build, MK.build):
            step(pyq_db_path=cls.pyq)
        cls.summary = D2.build(pyq_db_path=cls.pyq)
        cls.v1_after = hashlib.md5(_EXAMDNA.read_bytes()).hexdigest() if _EXAMDNA.exists() else None

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _q(self, sql, args=()):
        c = sqlite3.connect(f"file:{self.pyq}?mode=ro", uri=True)
        try:
            return c.execute(sql, args).fetchall()
        finally:
            c.close()

    def test_examdna_v1_byte_identical(self):
        self.assertEqual(self.v1_before, self.v1_after, "OD-6: examdna.db v1 must never be mutated by v2")

    def test_measured_only_above_sitting_floor(self):
        # any pyq_measured / structural_proxy cell must have n_sittings >= 30; nothing below the floor is measured
        bad = self._q("SELECT COUNT(*) FROM exam_dna_v2 WHERE provenance_class IN ('pyq_measured','structural_proxy') "
                      "AND (n_sittings IS NULL OR n_sittings < 30)")[0][0]
        self.assertEqual(bad, 0)

    def test_insufficient_is_honest_null(self):
        # an insufficient_evidence cell must carry a NULL probability (never a fabricated number)
        bad = self._q("SELECT COUNT(*) FROM exam_dna_v2 WHERE provenance_class='insufficient_evidence' "
                      "AND probability IS NOT NULL")[0][0]
        self.assertEqual(bad, 0)

    def test_all_exams_insufficient_at_independent_sitting_floor(self):
        # the honest truth of the owned corpus: NO exam has 30 INDEPENDENT sittings (NEET 10 / JEE_ADV 14 /
        # JEE_MAIN 6), so every measured distribution is insufficient_evidence — never fabricated to look measured.
        for exam in ("NEET", "JEE_ADVANCED", "JEE_MAIN"):
            for dim in ("question_type", "structural_difficulty"):
                provs = {p for (p,) in self._q("SELECT provenance_class FROM exam_dna_v2 WHERE exam=? "
                                               "AND dimension=?", (exam, dim))}
                self.assertEqual(provs, {"insufficient_evidence"},
                                 f"{exam} {dim} has < 30 independent sittings → honest-null")
        # and no cell anywhere is measured on this corpus
        self.assertEqual(self._q("SELECT COUNT(*) FROM exam_dna_v2 WHERE provenance_class IN "
                                 "('pyq_measured','structural_proxy')")[0][0], 0)

    def test_n_sittings_below_raw_docs(self):
        # sittings must be < raw docs where booklet duplication exists (proves the dedup-to-sitting is real)
        neet = self._q("SELECT n_sittings, n_docs FROM exam_dna_v2 WHERE exam='NEET' AND dimension='question_type'")[0]
        self.assertLess(neet[0], neet[1], "NEET's independent sittings must be fewer than its raw booklet docs")

    def test_no_measured_student_difficulty_claim(self):
        # OD-3: difficulty cells are structural_proxy, NEVER a 'measured'/'pilot' provenance
        bad = self._q("SELECT COUNT(*) FROM exam_dna_v2 WHERE dimension='structural_difficulty' "
                      "AND provenance_class NOT IN ('structural_proxy','insufficient_evidence')")[0][0]
        self.assertEqual(bad, 0)

    def test_subject_weight_published_and_sums_to_one(self):
        for exam in ("NEET", "JEE_MAIN", "JEE_ADVANCED"):
            rows = self._q("SELECT probability, provenance_class FROM exam_dna_v2 WHERE exam=? "
                           "AND dimension='subject_weight'", (exam,))
            self.assertTrue(rows and all(pc == "published" for _, pc in rows))
            self.assertTrue(math.isclose(sum(p for p, _ in rows), 1.0, abs_tol=1e-3))

    def test_every_row_versioned(self):
        n_null = self._q("SELECT COUNT(*) FROM exam_dna_v2 WHERE version IS NULL OR version=''")[0][0]
        self.assertEqual(n_null, 0)

    def test_delta_only_for_measured_cells(self):
        # a delta row (v2 vs v1) is emitted ONLY for a measured structural cell; with no measured cell on this
        # corpus, the delta table is honestly empty — not fabricated.
        n_deltas = self._q("SELECT COUNT(*) FROM exam_dna_v2_delta")[0][0]
        n_measured = self._q("SELECT COUNT(*) FROM exam_dna_v2 WHERE provenance_class='structural_proxy'")[0][0]
        self.assertEqual(n_deltas, n_measured, "deltas must correspond exactly to measured structural cells")

    def test_determinism(self):
        with tempfile.TemporaryDirectory() as t:
            p = os.path.join(t, "p.db")
            for step in (SC.build, SS.build, MI.build, DF.build, MK.build):
                step(pyq_db_path=p)
            s2 = D2.build(pyq_db_path=p)
        self.assertEqual(self.summary["coverage"], s2["coverage"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
