"""QP engine — Phase 4 selection intelligence.

Locks the additive ranking upgrade: the composite importance score folds PYQ recency, concept-
graph centrality (previously computed but UNUSED in ranking) and evidence authority on top of
exam frequency — WITHOUT displacing the existing subject/chapter balancing or the seed-driven
cross-paper variety, and WITHOUT breaking determinism or the syllabus boundary.
"""
import unittest

from kie import store
from kie.qpgen import pool, scope, select
from kie.qpgen.select import importance_score
from kie.qpgen.pool import Candidate
from kie.qpgen.models import Blueprint, BlueprintCell, PaperRequest, QuestionType, Subject
from kie.intake.store_ext import now_iso


def _cand(code, freq, years, deg, ev):
    return Candidate(key=f"{code}|mcq", concept_code=code, concept_title=code, subject="Physics",
                     question_type="mcq", bloom="apply", difficulty="medium", frequency=freq,
                     years=years, render_mode="spec_only", source="pattern", graph_degree=deg,
                     evidence=ev, chapter="Mechanics")


class TestImportanceScore(unittest.TestCase):
    REF = 2024

    def test_equal_frequency_is_differentiated_by_modifiers(self):
        base = _cand("BASE", 5, [2010], 0, 5)
        recent = _cand("RECENT", 5, [2024, 2023], 0, 5)
        central = _cand("CENTRAL", 5, [2010], 10, 5)
        authority = _cand("AUTH", 5, [2010], 0, 11)
        b = importance_score(base, self.REF)
        for better in (recent, central, authority):
            self.assertGreater(importance_score(better, self.REF), b, better.concept_code)

    def test_frequency_stays_primary(self):
        # no SINGLE maxed modifier may overtake a clearly higher-frequency concept (+4 here);
        # the modifiers differentiate similar concepts, they do not replace exam frequency.
        high_freq = _cand("HF", 9, [2010], 0, 9)
        for single_maxed in (_cand("R", 5, [2024, 2023], 0, 5),   # recency maxed
                             _cand("G", 5, [2010], 10, 5),         # centrality maxed
                             _cand("E", 5, [2010], 0, 12)):        # authority maxed
            self.assertGreater(importance_score(high_freq, self.REF),
                               importance_score(single_maxed, self.REF), single_maxed.concept_code)

    def test_no_year_evidence_is_safe(self):
        self.assertEqual(importance_score(_cand("D", 3, [], 0, 3), None), 3.0)
        self.assertEqual(importance_score(_cand("D", 3, [], 0, 3), self.REF), 3.0)

    def test_deterministic(self):
        c = _cand("X", 7, [2020, 2024], 5, 9)
        self.assertEqual(importance_score(c, self.REF), importance_score(c, self.REF))


def _seed(conn, code, title, subject, freq, years, edges_to=()):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,"
        "encrypted,is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)",
        (code, title, "", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    conn.execute(
        "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,"
        "frequency,years,evidence) VALUES (?,?,?,?,?,?,?,?)",
        (code + "_p", code, "mcq", "apply", "medium", freq, str(list(years)), "{}"))


class TestSelectionUsesTheSignals(unittest.TestCase):
    _NEIGHBOURS = ("Kinematics", "Dynamics", "Acoustics", "Electrostatics", "Magnetism", "Optics")

    def _two_concept_scope(self, a_years, b_years, a_edges=0):
        conn = store.open_store(":memory:")
        _seed(conn, "A", "Nuclear Fission", Subject.PHYSICS, 5, a_years)
        _seed(conn, "B", "Nuclear Fusion", Subject.PHYSICS, 5, b_years)
        for i in range(a_edges):    # give A graph centrality; neighbours are BARE (no patterns →
            conn.execute(           # out of scope) so they don't pollute the A/B tiering.
                "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,"
                "created_at) VALUES (?,?,?,?, 'active', '{}', ?)",
                (f"N{i}", self._NEIGHBOURS[i], "", Subject.PHYSICS, now_iso()))
            conn.execute("INSERT INTO concept_edges(from_concept,to_concept,relationship_type) "
                         "VALUES ('A', ?, 'related')", (f"N{i}",))
        conn.commit()
        sc = scope.resolve_scope(conn, PaperRequest(exam="NEET"))
        return conn, sc, pool.build_pool(conn, sc)

    def test_recent_concept_is_preferred(self):
        conn, sc, pl = self._two_concept_scope(a_years=[2024, 2023], b_years=[2005])
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 1)])
        r = select.select(bp, pl, PaperRequest(exam="NEET", seed=1), sc)
        self.assertEqual(r.slots[0].concept_code, "A")   # recency lifted A into the top tier
        conn.close()

    def test_central_concept_is_preferred(self):
        conn, sc, pl = self._two_concept_scope(a_years=[2010], b_years=[2010], a_edges=6)
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 1)])
        r = select.select(bp, pl, PaperRequest(exam="NEET", seed=1), sc)
        self.assertEqual(r.slots[0].concept_code, "A")   # graph centrality lifted A
        self.assertGreater(r.slots[0].provenance["graph_degree"], 0)
        self.assertIn("importance_score", r.slots[0].provenance)
        conn.close()


class TestDiversityAndDeterminismPreserved(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        for i in range(12):
            _seed(self.conn, f"PHY_{i}", f"Physics Concept {i}", Subject.PHYSICS, 8 - (i % 4),
                  [2020 + (i % 5)])
        self.conn.commit()
        self.scope = scope.resolve_scope(self.conn, PaperRequest(exam="NEET"))
        self.pool = pool.build_pool(self.conn, self.scope)

    def tearDown(self):
        self.conn.close()

    def test_same_seed_reproducible(self):
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 5)])
        a = select.select(bp, self.pool, PaperRequest(exam="NEET", seed=3), self.scope)
        b = select.select(bp, self.pool, PaperRequest(exam="NEET", seed=3), self.scope)
        self.assertEqual([s.concept_code for s in a.slots], [s.concept_code for s in b.slots])

    def test_different_seeds_still_vary(self):
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 5)])
        picks = {tuple(s.concept_code for s in
                       select.select(bp, self.pool, PaperRequest(exam="NEET", seed=k), self.scope).slots)
                 for k in range(8)}
        self.assertGreater(len(picks), 1)   # the seed still drives cross-paper variety


if __name__ == "__main__":
    unittest.main()
