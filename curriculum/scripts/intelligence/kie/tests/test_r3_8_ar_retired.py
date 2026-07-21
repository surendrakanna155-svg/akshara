"""R3-8 regression — the known-defective qpgen assertion-reason (AR) path is UNREACHABLE.

Confirmed defect (red team 2026-07-11, #red-team-10; roadmap R3-8): the frozen qpgen engine
hard-codes the AR answer to `_AR_OPTS[0]` in `kie/qpgen/templates.py::_ar_family.build` — every AR
item's key is option (a) regardless of truth. `kie/qpgen/` is FROZEN (reuse-not-edit), so the fix is
a QIE-side reachability retirement: `kie.qie.retired_families` declares the retirement and
`kie.qie.qp_bridge` (the sanctioned caller) honors it, at BOTH the item-pool and the question-type
layers. These tests prove:
  1. the denylist covers EVERY AR family the frozen engine still registers (fail-closed);
  2. the AR question TYPE is retired; MCQ/NUMERICAL are not;
  3. a retired item is dropped from the bridge's reachable pool (synthetic — no DB needed);
  4. end-to-end, a blueprint containing an AR cell yields NO AR slot and an explicit R3-8 refusal;
  5. the frozen engine was NOT edited — the AR defect is still present verbatim in qpgen (proving
     the retirement lives entirely at the reachability layer).
"""
import os
import unittest

from kie import config
from kie.qie import qp_bridge as QB
from kie.qie import retired_families as RF
from kie.qpgen import templates as QPGEN_TEMPLATES
from kie.qpgen.models import PaperRequest, QuestionType
from kie.qie import store as QS


class TestDenylistCoversFrozenEngine(unittest.TestCase):
    def test_denylist_covers_every_live_ar_family(self):
        """The QIE denylist must retire EVERY AR family the frozen REGISTRY still exposes. If qpgen
        ever adds a new AR family, this fails loudly rather than leaking a defective family."""
        live_ar = {t.template_id for t in QPGEN_TEMPLATES.REGISTRY
                   if QuestionType.ASSERTION_REASON in t.types}
        self.assertTrue(live_ar, "expected the frozen engine to still expose AR families")
        missing = live_ar - RF.RETIRED_QPGEN_FAMILIES
        self.assertEqual(missing, set(),
                         f"un-retired AR families leak through the reachability layer: {missing}")

    def test_no_retired_family_is_a_bridge_pool_source(self):
        """Sanity: the retired ids are qpgen AR families (Physics), matching the audited defect."""
        self.assertEqual(RF.RETIRED_QPGEN_FAMILIES,
                         {"ar_newton_first", "ar_ohm", "ar_momentum_conservation", "ar_archimedes"})


class TestQuestionTypeRetired(unittest.TestCase):
    def test_ar_type_is_retired(self):
        self.assertTrue(RF.is_retired_question_type(QuestionType.ASSERTION_REASON))

    def test_servable_types_are_not_retired(self):
        self.assertFalse(RF.is_retired_question_type(QuestionType.MCQ))
        self.assertFalse(RF.is_retired_question_type(QuestionType.NUMERICAL))


class TestPoolReachabilityFilter(unittest.TestCase):
    """The reachability seam proven WITHOUT a DB: a retired item cannot survive the pool filter."""

    def test_retired_item_detected_by_frame_id(self):
        self.assertTrue(RF.is_retired_item({"frame_id": "ar_ohm"}))

    def test_retired_item_detected_by_provenance_template(self):
        self.assertTrue(RF.is_retired_item(
            {"frame_id": "x", "provenance": {"template": "ar_archimedes"}}))

    def test_retired_item_detected_by_archetype(self):
        self.assertTrue(RF.is_retired_item({"frame_id": "x", "archetype": "assertion_reason"}))
        self.assertTrue(RF.is_retired_item(
            {"frame_id": "x", "provenance": {"archetype": "assertion_reason"}}))

    def test_legitimate_item_survives(self):
        legit = {"frame_id": "area_between_roots",
                 "provenance": {"template": "area_between_roots"}, "archetype": "multi_step_numerical"}
        self.assertFalse(RF.is_retired_item(legit))

    def test_filter_removes_only_retired(self):
        pool = [
            {"frame_id": "ar_ohm"},                                   # retired AR family
            {"frame_id": "area_between_roots"},                       # legit composition
            {"frame_id": "phy_kinetic_energy", "archetype": "assertion_reason"},  # retired archetype
        ]
        kept = [it for it in pool if not RF.is_retired_item(it)]
        self.assertEqual([it["frame_id"] for it in kept], ["area_between_roots"])


_DBS_PRESENT = os.path.exists(config.DB_PATH) and os.path.exists(QS.QIE_DB_PATH)


@unittest.skipUnless(_DBS_PRESENT, "requires certified kie.db + qie.db (gitignored; canonical machine)")
class TestBridgeNeverAssemblesAR(unittest.TestCase):
    """End-to-end: force the AR-containing `mixed_50` blueprint through the bridge and prove no AR
    slot is ever produced, and that the retirement is reported explicitly (not silently absent)."""

    def _paper(self):
        # mixed_50 has section C = ASSERTION_REASON (presets.py:129). Route it through the bridge.
        return QB.generate_paper(PaperRequest(exam="FOUNDATION", blueprint_preset="mixed_50", seed=7), per=10)

    def test_no_assertion_reason_slot_in_paper(self):
        paper, _ = self._paper()
        ar_slots = [s for s in paper.slots if s.question_type == QuestionType.ASSERTION_REASON]
        self.assertEqual(ar_slots, [], "an assertion-reason slot reached the assembled paper")

    def test_ar_cell_reported_as_retired(self):
        paper, _ = self._paper()
        self.assertTrue(any("RETIRED" in w and "R3-8" in w for w in paper.warnings),
                        f"expected an explicit R3-8 AR-retirement warning; got {paper.warnings}")

    def test_bridge_still_produces_mcq_items(self):
        # Retiring AR must not break the bridge — legitimate MCQ slots still assemble.
        paper, report = self._paper()
        self.assertTrue(report.boundary_ok)
        self.assertTrue(any(s.question_type == QuestionType.MCQ for s in paper.slots),
                        "the bridge produced no MCQ items — AR retirement over-pruned the pool")


class TestFrozenEngineUntouched(unittest.TestCase):
    """Prove the fix is purely at the reachability layer: qpgen was NOT edited. The AR defect is
    still present verbatim in the frozen engine (retired by unreachability, not by patching)."""

    def _templates_src(self) -> str:
        with open(QPGEN_TEMPLATES.__file__, "r", encoding="utf-8") as fh:
            return fh.read()

    def test_qpgen_ar_defect_still_present_verbatim(self):
        src = self._templates_src()
        # the exact hard-coded-answer defect (templates.py ~541) must be UNCHANGED
        self.assertIn('"answer": _AR_OPTS[0]', src,
                      "qpgen AR defect was altered — R3-8 must not edit the frozen engine")

    def test_qpgen_still_registers_ar_families(self):
        # the frozen engine still registers AR families and the AR question type — we did not remove
        # them from qpgen; we made them unreachable from the QIE side.
        self.assertTrue(any(QuestionType.ASSERTION_REASON in t.types for t in QPGEN_TEMPLATES.REGISTRY))
        src = self._templates_src()
        self.assertIn("QuestionType.ASSERTION_REASON", src)
        self.assertIn("def _ar_family(", src)

    def test_qpgen_path_is_under_the_frozen_engine_dir(self):
        # documents WHERE the untouched engine lives (kie/qpgen) vs the QIE seam (kie/qie)
        self.assertIn(os.path.join("kie", "qpgen", "templates.py"), QPGEN_TEMPLATES.__file__)


if __name__ == "__main__":
    unittest.main()
