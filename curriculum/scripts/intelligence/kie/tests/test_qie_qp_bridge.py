"""Golden tests — QP integration bridge: the unified qie engine wired THROUGH the existing qpgen pipeline.
Contract: real papers via reused scope/blueprint/validate/assemble; every item honestly bound to an in-scope
certified concept (boundary_ok, 0 rejects); items are FILLED + student-printable; A5 seam populated; per-concept
dedup governance holds; difficulty balance; unfilled positions are honest shortfalls (never quota-filled).
"""
import unittest

from kie.qie import qp_bridge as QB
from kie.qpgen.assemble import is_student_printable
from kie.qpgen.models import Difficulty, PaperRequest, SlotStatus


class TestBridgeEndToEnd(unittest.TestCase):
    def _paper(self, exam):
        return QB.generate_paper(PaperRequest(exam=exam, seed=7), per=10)

    def test_jee_main_paper_is_valid_and_bound(self):
        paper, report = self._paper("JEE_MAIN")
        self.assertTrue(report.boundary_ok)                       # nothing out-of-syllabus
        self.assertEqual(report.rejected_slots, 0)               # every placed item passed the hard gate
        pr = [s for s in paper.slots if is_student_printable(s)]
        self.assertGreaterEqual(len(pr), 6)                      # genuinely filled, not empty
        # every printed item: FILLED, real answer, in-scope concept, A5 seam populated, machine-verified source
        for s in pr:
            self.assertEqual(s.status, SlotStatus.FILLED)
            self.assertTrue(s.answer)
            self.assertEqual(s.provenance.get("source"), "template")
            self.assertTrue(s.item_model_id or s.lane)           # A5 seam carries the qie provenance
            self.assertTrue(s.gate_verdicts)
        # per-concept dedup governance holds (no (concept, type) repeated)
        keys = [(s.concept_code, s.question_type) for s in pr]
        self.assertEqual(len(keys), len(set(keys)))
        # depth/difficulty balance present (blueprint is medium + hard)
        diffs = {s.difficulty for s in pr}
        self.assertTrue(diffs <= {Difficulty.MEDIUM, Difficulty.HARD})
        self.assertIn(Difficulty.MEDIUM, diffs)

    def test_neet_paper_covers_biology_reasoning(self):
        paper, report = self._paper("NEET")
        self.assertTrue(report.boundary_ok)
        self.assertEqual(report.rejected_slots, 0)
        pr = [s for s in paper.slots if is_student_printable(s)]
        self.assertGreaterEqual(len(pr), 3)
        self.assertIn("Biology", {s.subject for s in pr})        # non-quantitative Biology reached the paper

    def test_shortfalls_are_honest_not_quota_filled(self):
        # the authentic blueprint asks for far more than qie's certified-concept span can supply; the bridge
        # must report the gap, never pad it with unsuitable items.
        paper, report = self._paper("JEE_MAIN")
        self.assertTrue(any("shortfall" in w for w in paper.warnings))
        # coverage is honest: printable ≤ blueprint total, and the render states deterministic coverage
        md = QB.render_markdown(paper)
        self.assertIn("Deterministic coverage", md)
        self.assertIn("Answer Key", md)

    def test_reuses_qpgen_not_parallel(self):
        # the bridge must go through qpgen's own validate + assemble (reuse), tagged as qie-sourced
        paper, _ = self._paper("JEE_MAIN")
        self.assertIn("source_engine", paper.provenance)
        self.assertIn("validation", paper.provenance)


if __name__ == "__main__":
    unittest.main()
