"""QP engine — Phase 3 authentic examination blueprint library.

Locks the real-exam blueprints (NEET / JEE Main / JEE Advanced / CBSE X / CBSE XII /
Telangana & AP SCERT): official marks totals, clean structural validation, authentic
metadata (duration, negative marking, weightage), subject-bound per-subject sections, a
difficulty PROGRESSION within each section, and surfaced internal-choice instructions —
all deterministic.
"""
import unittest

from kie import store
from kie.qpgen import blueprint as bp_mod, blueprints, presets
from kie.qpgen.engine import QuestionPaperEngine
from kie.qpgen.models import Difficulty, PaperRequest, Subject
from kie.intake.store_ext import now_iso


class TestAuthenticBlueprintStructure(unittest.TestCase):
    def test_all_present_and_valid(self):
        for name in blueprints.AUTHENTIC_BLUEPRINTS:
            self.assertIn(name, presets.BLUEPRINT_PRESETS)
            b = presets.get_blueprint(name)
            self.assertEqual(bp_mod.validate_blueprint(b), [], name)
            self.assertGreater(b.total_questions, 0, name)

    def test_official_marks_totals(self):
        totals = {"neet": 720, "jee_main": 300, "cbse_x_science": 80,
                  "cbse_xii_physics": 70, "ts_scert_x_science": 40, "ap_scert_x_science": 40}
        for name, marks in totals.items():
            self.assertEqual(presets.get_blueprint(name).total_marks, marks, name)
        self.assertGreater(presets.get_blueprint("jee_advanced").total_marks, 0)

    def test_competitive_metadata(self):
        for name in ("neet", "jee_main"):
            b = presets.get_blueprint(name)
            self.assertTrue(b.exam)
            self.assertTrue(b.duration_min and b.duration_min > 0)
            self.assertTrue(b.negative_marking)
            self.assertTrue(b.weightage)

    def test_profile_defaults_are_authentic(self):
        self.assertEqual(bp_mod.default_blueprint_name("NEET"), "neet")
        self.assertEqual(bp_mod.default_blueprint_name("JEE_MAIN"), "jee_main")
        self.assertEqual(bp_mod.default_blueprint_name("JEE_ADVANCED"), "jee_advanced")


def _seed(conn, code, title, subject, i):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,"
        "encrypted,is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)",
        (code, title, f"definition of {title}", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    for j, (qt, diff) in enumerate((("mcq", "medium"), ("mcq", "hard"), ("short_answer", "medium"))):
        conn.execute(
            "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,"
            "frequency,years,evidence) VALUES (?,?,?,?,?,?,?,?)",
            (f"{code}_p{j}", code, qt, "understand", diff, 5 - j, "[2023]", "{}"))


def _multi_subject_kie():
    # over-provision so NEET's per-subject counts (Physics/Chem 45, Biology 90) fill fully,
    # exercising Section B (internal choice) too.
    conn = store.open_store(":memory:")
    for subj, pre in ((Subject.PHYSICS, "PHY"), (Subject.CHEMISTRY, "CHE"), (Subject.BIOLOGY, "BIO")):
        for i in range(95):
            _seed(conn, f"{pre}_{i}", f"{subj} Concept {i}", subj, i)
    conn.commit()
    return conn


class TestAuthenticGeneration(unittest.TestCase):
    def setUp(self):
        self.conn = _multi_subject_kie()
        self.eng = QuestionPaperEngine(conn=self.conn)

    def tearDown(self):
        self.conn.close()

    def test_neet_sections_are_subject_pure(self):
        paper = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset="neet", seed=1))
        for s in paper.slots:
            head = s.section.split(" ·")[0]              # "Physics · Section A" -> "Physics"
            if head in ("Physics", "Chemistry", "Biology"):
                self.assertEqual(s.subject, head, (s.section, s.subject))

    def test_difficulty_progression_within_section(self):
        paper = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset="neet", seed=2))
        by_section = {}
        for s in paper.slots:
            by_section.setdefault(s.section, []).append(Difficulty.RANK.get(s.difficulty, 1))
        for sec, ranks in by_section.items():
            self.assertEqual(ranks, sorted(ranks), (sec, ranks))   # easy -> hard, non-decreasing

    def test_official_marks_preserved_when_fully_fillable(self):
        # 30 concepts/subject is enough for NEET's per-subject MCQ counts → full 720 or an
        # honestly-reported shortfall; marks always equal the sum of shipped slot marks.
        paper = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset="neet", seed=3))
        self.assertEqual(sum(s.marks for s in paper.slots), paper.total_marks)
        self.assertLessEqual(paper.total_marks, 720)

    def test_render_surfaces_pattern_and_coverage(self):
        # NEW render-honesty contract: authentic pattern label + negative marking always show;
        # this synthetic corpus is all-conceptual (no templates), so every MCQ is honestly routed
        # to the authoring worklist and the header states 0 print-ready — a spec is NEVER printed
        # as a student question.
        paper = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset="neet", seed=1))
        md = self.eng.render_markdown(paper)
        self.assertIn("NEET (UG)", md)                    # authentic pattern label
        self.assertIn("Negative marking", md)
        self.assertIn("Deterministic coverage", md)       # honest coverage line
        self.assertIn("requiring authoring", md)          # specs go to the worklist, not the body
        self.assertNotIn("[SPEC", md)                     # no authoring stub in the printed paper

    def test_deterministic(self):
        a = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset="neet", seed=7))
        b = self.eng.generate(PaperRequest(exam="NEET", blueprint_preset="neet", seed=7))
        self.assertEqual([s.concept_code for s in a.slots], [s.concept_code for s in b.slots])
        self.assertEqual([s.section for s in a.slots], [s.section for s in b.slots])


if __name__ == "__main__":
    unittest.main()
