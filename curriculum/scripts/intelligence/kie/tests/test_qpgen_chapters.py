"""QP engine R6/P1-4 — chapter taxonomy + chapter balancing + robust chapter filter."""
import collections
import unittest

from kie import store
from kie.qpgen import chapters, scope, pool as pm, select as sm
from kie.qpgen.models import Blueprint, BlueprintCell, PaperRequest, QuestionType, Subject
from kie.intake.store_ext import now_iso


def _seed(conn, code, title, subject, freq=5):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
        "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)", (code, title, "", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    conn.execute(
        "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
        " VALUES (?,?,?,?,?,?,?,?)", (code + "_p", code, "mcq", "apply", "medium", freq, "[2023]", "{}"))


class TestChapterTaxonomy(unittest.TestCase):
    def test_resolve_chapter_maps_known_topics(self):
        self.assertEqual(chapters.resolve_chapter(Subject.PHYSICS, "Newton's Laws of Motion"), "Mechanics")
        self.assertEqual(chapters.resolve_chapter(Subject.PHYSICS, "Electromagnetic Induction"), "Electromagnetism")
        self.assertEqual(chapters.resolve_chapter(Subject.BIOLOGY, "Photosynthesis in plants"), "Plant Physiology")
        self.assertEqual(chapters.resolve_chapter(Subject.BIOLOGY, "DNA Replication"), "Genetics & Evolution")
        self.assertEqual(chapters.resolve_chapter(Subject.CHEMISTRY, "Mole Concept"), "Physical Chemistry")
        self.assertEqual(chapters.resolve_chapter(Subject.MATHEMATICS, "Definite Integral"), "Calculus")

    def test_unmatched_goes_to_general_bucket(self):
        self.assertEqual(chapters.resolve_chapter(Subject.BIOLOGY, "Characteristics"), "General Biology")


class TestChapterBalancing(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        # 4 concepts each in 4 Biology chapters
        cell = ["Cell Structure", "Cell Membrane", "Mitochondria function", "Nucleus role"]
        genetics = ["DNA structure", "Gene expression", "Evolution theory", "Mutation types"]
        physio = ["Human digestion", "Blood circulation", "Nervous coordination", "Hormone action"]
        ecology = ["Ecosystem dynamics", "Population ecology", "Biodiversity loss", "Food chain flow"]
        for grp, tag in ((cell, "CELL"), (genetics, "GEN"), (physio, "PHY"), (ecology, "ECO")):
            for i, t in enumerate(grp):
                _seed(self.conn, f"{tag}_{i}", t, Subject.BIOLOGY, freq=10 - i)
        self.conn.commit()
        self.scope = scope.resolve_scope(self.conn, PaperRequest(exam="NEET", subjects=("Biology",)))
        self.pool = pm.build_pool(self.conn, self.scope)

    def tearDown(self):
        self.conn.close()

    def test_scope_reports_chapters(self):
        by_ch = self.scope.stats["by_chapter"]
        self.assertEqual(by_ch["Cell Biology"], 4)
        self.assertEqual(by_ch["Genetics & Evolution"], 4)
        self.assertEqual(by_ch["Human Physiology"], 4)
        self.assertEqual(by_ch["Ecology"], 4)

    def test_paper_spreads_across_chapters(self):
        bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 8)])
        r = sm.select(bp, self.pool, PaperRequest(exam="NEET", subjects=("Biology",)), self.scope)
        chaps = collections.Counter(s.provenance["chapter"] for s in r.slots)
        # 8 questions, 4 chapters → balanced ~2 each; every chapter represented
        self.assertEqual(len(chaps), 4)
        self.assertTrue(all(2 <= n <= 3 for n in chaps.values()))

    def test_chapter_filter_matches_canonical_chapter(self):
        sc = scope.resolve_scope(self.conn, PaperRequest(exam="NEET", subjects=("Biology",),
                                                         chapters=("Genetics",)))
        self.assertEqual(sc.stats["in_scope"], 4)
        self.assertEqual(set(c.chapter for c in sc.concepts.values()), {"Genetics & Evolution"})

    def test_balance_holds_with_seed_variety(self):
        # different seeds still cover all chapters (uniqueness never breaks chapter balance)
        for seed in range(4):
            bp = Blueprint("t", cells=[BlueprintCell("A", QuestionType.MCQ, 4, 8)])
            r = sm.select(bp, self.pool, PaperRequest(exam="NEET", subjects=("Biology",), seed=seed), self.scope)
            chaps = set(s.provenance["chapter"] for s in r.slots)
            self.assertEqual(len(chaps), 4)   # all 4 chapters covered regardless of seed


if __name__ == "__main__":
    unittest.main()
