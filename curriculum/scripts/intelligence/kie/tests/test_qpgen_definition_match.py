"""Content Density CP4 — grounded definition-match MCQ materialization.

Locks the invariants: the concept's own verified definition is the clue (answer name removed so it
is not given away); the concept is the single correct answer; distractors are DISTINCT clean
sibling concepts (same subject); exactly 4 distinct options with exactly one correct; fails CLOSED
(stays a spec) when the definition is unusable or fewer than 3 valid siblings exist. No fabrication.
"""
import unittest

from kie import store
from kie.qpgen import materialize
from kie.qpgen.models import PaperRequest, QuestionSlot, QuestionType, RenderMode, SlotStatus


def _c(conn, code, title, subject, definition=""):
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at)"
        " VALUES (?,?,?,?, 'active','{}', datetime('now'))", (code, title, definition, subject))


def _slot(code, title, subject="Chemistry"):
    return QuestionSlot(number=1, section="A", concept_code=code, concept_title=title,
                        subject=subject, question_type=QuestionType.MCQ, marks=1,
                        bloom="remember", difficulty="easy", render_mode=RenderMode.SPEC_ONLY,
                        status=SlotStatus.SPEC, provenance={})


class DefinitionMatchTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        # target concept with a grounded definition + several clean same-subject siblings
        _c(self.conn, "C_OX", "Oxidation", "Chemistry", "Oxidation is the gain of oxygen or loss of hydrogen.")
        for i, name in enumerate(("Reduction", "Neutralisation", "Corrosion", "Electrolysis")):
            _c(self.conn, f"C_{i}", name, "Chemistry")
        self.conn.commit()

    def tearDown(self):
        self.conn.close()

    def _defn(self, code):
        return self.conn.execute("SELECT definition FROM concepts WHERE concept_code=?",
                                 (code,)).fetchone()[0]

    def test_builds_valid_grounded_mcq(self):
        s = _slot("C_OX", "Oxidation")
        ok = materialize.render_definition_match_mcq(s, self.conn, self._defn("C_OX"), seed=42)
        self.assertTrue(ok)
        self.assertEqual(s.status, SlotStatus.FILLED)
        self.assertEqual(len(s.options), 4)
        self.assertEqual(len(set(s.options)), 4)                 # 4 distinct
        self.assertEqual(s.options.count(s.answer), 1)          # exactly one correct
        self.assertEqual(s.answer, "Oxidation")
        self.assertIn("gain of oxygen", s.stem)                 # clue is the predicate
        self.assertNotIn("Oxidation is", s.stem)               # answer name NOT given away

    def test_fails_closed_without_usable_definition(self):
        s = _slot("C_OX", "Oxidation")
        self.assertFalse(materialize.render_definition_match_mcq(s, self.conn, "", seed=1))
        self.assertEqual(s.status, SlotStatus.SPEC)

    def test_fails_closed_without_enough_siblings(self):
        conn = store.open_store(":memory:")
        _c(conn, "C_X", "Photosynthesis", "Biology", "Photosynthesis is the process of making food.")
        conn.commit()
        s = _slot("C_X", "Photosynthesis", subject="Biology")
        # only 0 siblings in Biology → fail closed
        self.assertFalse(materialize.render_definition_match_mcq(
            s, conn, "Photosynthesis is the process of making food.", seed=1))
        self.assertEqual(s.status, SlotStatus.SPEC)
        conn.close()

    def test_only_for_mcq(self):
        s = _slot("C_OX", "Oxidation")
        s.question_type = QuestionType.SHORT_ANSWER
        self.assertFalse(materialize.render_definition_match_mcq(s, self.conn, self._defn("C_OX"), 1))


if __name__ == "__main__":
    unittest.main()
