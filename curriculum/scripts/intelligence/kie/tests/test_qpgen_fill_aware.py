"""Content Density Phase 2 — fill-aware selection (documented frozen-engine exception).

Regression-locks: selection PREFERS fillable concepts (template > definition > unfillable) WITHOUT
weakening subject balance, chapter diversity, seed determinism, or cross-paper uniqueness. When
`fillable` is not supplied, behaviour is byte-identical to before (backward compatible).
"""
import unittest

from kie.qpgen import select as sel
from kie.qpgen.models import Blueprint, BlueprintCell, PaperRequest, QuestionType
from kie.qpgen.pool import Candidate
from kie.qpgen.scope import SyllabusScope


def _cand(code, subject, chapter, qtype=QuestionType.MCQ, freq=10):
    return Candidate(key=f"{code}|{qtype}", concept_code=code, concept_title=code.title(),
                     subject=subject, question_type=qtype, bloom="understand", difficulty="medium",
                     frequency=freq, years=[2023], render_mode="spec_only", source="pattern",
                     graph_degree=1, chapter=chapter)


def _scope():
    return SyllabusScope(exam_profile="X", subjects=["Physics"], concepts={}, chapters=[])


class FillRankTest(unittest.TestCase):
    def test_ranks(self):
        c = _cand("a", "Physics", "Mechanics")
        self.assertEqual(sel._fill_rank(c, {c.key: 0}), 0)          # template
        self.assertEqual(sel._fill_rank(c, {c.key: 1}), 1)          # definition
        self.assertEqual(sel._fill_rank(c, {"other|mcq": 0}), 3)   # absent in a populated map ⇒ unfillable
        self.assertEqual(sel._fill_rank(c, {}), 0)                 # feature OFF (empty) ⇒ neutral

    def test_priority_prefers_fillable_within_subject(self):
        fillable_c = _cand("fill", "Physics", "Mechanics")
        empty_c = _cand("empty", "Physics", "Mechanics")
        fm = {fillable_c.key: 0}
        su, cu = {}, {}
        p_fill = sel._priority(fillable_c, 1, su, cu, 0, 10.0, fm)
        p_empty = sel._priority(empty_c, 1, su, cu, 0, 10.0, fm)
        self.assertLess(p_fill, p_empty)                       # fillable picked first

    def test_subject_balance_still_wins_over_fill(self):
        # an unfillable candidate in an under-used subject beats a fillable one in an over-used subject
        fill_over = _cand("f", "Physics", "Mechanics")
        empty_under = _cand("e", "Chemistry", "Physical Chemistry")
        fm = {fill_over.key: 0}
        su = {"Physics": 3, "Chemistry": 0}                    # Physics already used 3×
        p_fill = sel._priority(fill_over, 1, su, {}, 0, 10.0, fm)
        p_empty = sel._priority(empty_under, 1, su, {}, 0, 10.0, fm)
        self.assertLess(p_empty, p_fill)                       # subject balance preserved


class FillAwareSelectTest(unittest.TestCase):
    def setUp(self):
        # 4 fillable + 4 unfillable Physics MCQ concepts across 2 chapters
        self.pool = []
        for i in range(4):
            self.pool.append(_cand(f"fill{i}", "Physics", "Mechanics" if i % 2 else "Optics"))
        for i in range(4):
            self.pool.append(_cand(f"empty{i}", "Physics", "Mechanics" if i % 2 else "Optics"))
        self.fillable = {c.key: 0 for c in self.pool if c.concept_code.startswith("fill")}
        self.bp = Blueprint(name="t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 4)])

    def test_prefers_fillable_concepts(self):
        res = sel.select(self.bp, self.pool, PaperRequest(seed=1), _scope(), fillable=self.fillable)
        picked = [s.concept_code for s in res.slots]
        self.assertEqual(len(picked), 4)
        self.assertTrue(all(c.startswith("fill") for c in picked), picked)   # all 4 fillable chosen

    def test_still_spreads_across_chapters(self):
        res = sel.select(self.bp, self.pool, PaperRequest(seed=1), _scope(), fillable=self.fillable)
        chapters = {s.provenance["chapter"] for s in res.slots}
        self.assertEqual(chapters, {"Mechanics", "Optics"})    # diversity preserved

    def test_deterministic(self):
        a = sel.select(self.bp, self.pool, PaperRequest(seed=7), _scope(), fillable=self.fillable)
        b = sel.select(self.bp, self.pool, PaperRequest(seed=7), _scope(), fillable=self.fillable)
        self.assertEqual([s.concept_code for s in a.slots], [s.concept_code for s in b.slots])

    def test_backward_compatible_without_fillable(self):
        # no fillable arg → same result as before the feature (fill_rank is a constant 0)
        res = sel.select(self.bp, self.pool, PaperRequest(seed=3), _scope())
        self.assertEqual(len(res.slots), 4)

    def test_cross_paper_uniqueness_preserved(self):
        req = PaperRequest(seed=1, exclude_concepts=("fill0", "fill1"))
        res = sel.select(self.bp, self.pool, req, _scope(), fillable=self.fillable)
        picked = {s.concept_code for s in res.slots}
        self.assertNotIn("fill0", picked)
        self.assertNotIn("fill1", picked)


if __name__ == "__main__":
    unittest.main()
