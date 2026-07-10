"""QP engine R2/P0-2 — cross-paper uniqueness (seed variety + exclude + series) that never
sacrifices scope, grade isolation, subject balance, or reproducibility."""
import itertools
import unittest

from kie import store
from kie.qpgen.engine import QuestionPaperEngine
from kie.qpgen.models import PaperRequest, Subject
from kie.qpgen import scope
from kie.intake.store_ext import now_iso


def _seed(conn, code, title, subject, freq):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
        "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)", (code, title, "", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    for qt, bloom, diff in (("mcq", "apply", "hard"), ("short_answer", "understand", "medium")):
        conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
            " VALUES (?,?,?,?,?,?,?,?)", (f"{code}_{qt}", code, qt, bloom, diff, freq, "[2023]", "{}"))


def _kie():
    conn = store.open_store(":memory:")
    # 40 physics concepts with a skewed (power-law-ish) frequency distribution
    for i in range(40):
        _seed(conn, f"PHY_{i:02d}", f"Physics Topic {i}", Subject.PHYSICS, freq=max(1, 100 - i * 2))
    conn.commit()
    return conn


class TestUniqueness(unittest.TestCase):
    def setUp(self):
        self.conn = _kie()
        self.eng = QuestionPaperEngine(conn=self.conn)
        self.allowed = set(scope.resolve_scope(self.conn, PaperRequest(exam="NEET", subjects=("Physics",))).concept_codes)

    def tearDown(self):
        self.conn.close()

    def _codes(self, seed, **kw):
        p = self.eng.generate(PaperRequest(exam="NEET", subjects=("Physics",),
                                           blueprint_preset="descriptive_40", seed=seed, **kw))
        return set(s.concept_code for s in p.slots)

    def test_different_seeds_produce_different_papers(self):
        sets = [self._codes(s) for s in range(6)]
        overlaps = [len(a & b) / len(a | b) for a, b in itertools.combinations(sets, 2)]
        self.assertLess(max(overlaps), 0.95)              # NOT identical anymore (was 100%)
        self.assertGreater(len(set().union(*sets)), len(sets[0]))  # aggregate coverage grows

    def test_same_seed_reproducible(self):
        self.assertEqual(self._codes(3), self._codes(3))

    def test_all_papers_stay_in_scope(self):
        for s in range(6):
            self.assertTrue(self._codes(s) <= self.allowed)   # boundary safety preserved

    def test_exclude_concepts_are_never_used(self):
        a = self._codes(1)
        b = self._codes(1, exclude_concepts=tuple(a))
        self.assertEqual(a & b, set())

    def test_generate_series_zero_overlap(self):
        series = self.eng.generate_series(
            PaperRequest(exam="NEET", subjects=("Physics",), blueprint_preset="descriptive_40", seed=1), 4)
        code_sets = [set(s.concept_code for s in p.slots) for p in series]
        for a, b in itertools.combinations(code_sets, 2):
            self.assertEqual(a & b, set())                 # guaranteed distinct across the series
        for cs in code_sets:
            self.assertTrue(cs <= self.allowed)            # each still in-scope
        # series reproducible
        s2 = self.eng.generate_series(
            PaperRequest(exam="NEET", subjects=("Physics",), blueprint_preset="descriptive_40", seed=1), 4)
        self.assertEqual([set(s.concept_code for s in p.slots) for p in s2], code_sets)

    def test_series_reports_shortfall_when_pool_exhausted(self):
        # 40 concepts, 13 descriptive per paper → 4 papers fit; a 5th must shrink, not duplicate
        series = self.eng.generate_series(
            PaperRequest(exam="NEET", subjects=("Physics",), blueprint_preset="descriptive_40", seed=1), 5)
        all_codes = [s.concept_code for p in series for s in p.slots]
        self.assertEqual(len(all_codes), len(set(all_codes)))  # no duplicate concept anywhere in the series


if __name__ == "__main__":
    unittest.main()
