"""QP engine Q8 — golden end-to-end + property-based boundary safety across seeds.

Locks whole-pipeline behavior on a fixed synthetic KIE and proves the core invariant:
no matter the seed/blueprint, the engine NEVER emits an out-of-scope or garbage question.
"""
import unittest

from kie import store
from kie.qpgen.engine import QuestionPaperEngine
from kie.qpgen.models import PaperRequest, SlotStatus, Subject
from kie.qpgen import sanitize
from kie.intake.store_ext import now_iso


def _seed(conn, code, title, subject, patterns):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,encrypted,"
        "is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)",
        (code, title, f"the definition of {title}", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    for i, (qt, bloom, diff, freq) in enumerate(patterns):
        conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,frequency,years,evidence)"
            " VALUES (?,?,?,?,?,?,?,?)", (f"{code}_p{i}", code, qt, bloom, diff, freq, "[2021, 2023]", "{}"))


def _golden_kie():
    conn = store.open_store(":memory:")
    data = [
        ("PHY_1", "Newtons Laws of Motion", Subject.PHYSICS),
        ("PHY_2", "Work and Energy", Subject.PHYSICS),
        ("PHY_3", "Gravitation", Subject.PHYSICS),
        ("CHE_1", "Chemical Bonding", Subject.CHEMISTRY),
        ("CHE_2", "Thermodynamics", Subject.CHEMISTRY),
        ("BIO_1", "Photosynthesis", Subject.BIOLOGY),
        ("BIO_2", "Human Respiration", Subject.BIOLOGY),
        # an out-of-scope (Mathematics — not in NEET) + a garbage title that must NEVER appear
        ("MAT_1", "Integral Calculus", Subject.MATHEMATICS),
        ("NOISE", "GAJAHA", Subject.PHYSICS),
    ]
    for code, title, subj in data:
        _seed(conn, code, title, subj,
              [("mcq", "apply", "hard", 6), ("short_answer", "understand", "medium", 4)])
    conn.commit()
    return conn


class TestGolden(unittest.TestCase):
    def setUp(self):
        self.conn = _golden_kie()
        self.eng = QuestionPaperEngine(conn=self.conn)

    def tearDown(self):
        self.conn.close()

    def test_golden_descriptive_paper_stable(self):
        paper = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset="descriptive_40",
                                               seed=1, title="Golden NEET Paper"))
        # 7 in-scope NEET concepts (Physics+Chem+Bio); Math + GAJAHA excluded upstream
        self.assertTrue(all(s.subject in ("Physics", "Chemistry", "Biology") for s in paper.slots))
        self.assertNotIn("Integral Calculus", [s.concept_title for s in paper.slots])
        self.assertNotIn("GAJAHA", [s.concept_title for s in paper.slots])
        self.assertTrue(paper.provenance["validation"]["boundary_ok"])
        self.assertEqual(paper.spec_only, 0)                    # descriptive → all deterministic
        self.assertTrue(all(s.status == SlotStatus.FILLED for s in paper.slots))
        # marks conservation: sum of slot marks == reported total
        self.assertEqual(sum(s.marks for s in paper.slots), paper.total_marks)
        # deterministic golden: same paper twice
        p2 = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset="descriptive_40",
                                            seed=1, title="Golden NEET Paper"))
        self.assertEqual([s.stem for s in paper.slots], [s.stem for s in p2.slots])

    def test_boundary_safety_holds_across_all_seeds_and_blueprints(self):
        allowed = None
        for blueprint in ("descriptive_40", "objective_45", "mixed_50"):
            for seed in range(12):
                paper = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset=blueprint, seed=seed))
                if allowed is None:
                    from kie.qpgen import scope
                    allowed = set(scope.resolve_scope(self.conn, PaperRequest(exam="NEET")).concept_codes)
                for s in paper.slots:
                    self.assertIn(s.concept_code, allowed, f"out-of-scope leaked: {s.concept_code}")
                    self.assertIn(s.subject, ("Physics", "Chemistry", "Biology"))
                    self.assertTrue(sanitize.is_clean_concept(s.concept_title))
                self.assertTrue(paper.provenance["validation"]["boundary_ok"])

    def test_no_duplicate_concepts_in_any_paper(self):
        paper = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset="mixed_50", seed=5))
        pairs = [(s.concept_code, s.question_type) for s in paper.slots]
        self.assertEqual(len(pairs), len(set(pairs)))

    def test_subject_filter_end_to_end(self):
        paper = self.eng.generate(PaperRequest(exam="NEET", subjects=(Subject.BIOLOGY,),
                                               blueprint_preset="descriptive_40"))
        self.assertTrue(all(s.subject == Subject.BIOLOGY for s in paper.slots))


if __name__ == "__main__":
    unittest.main()
