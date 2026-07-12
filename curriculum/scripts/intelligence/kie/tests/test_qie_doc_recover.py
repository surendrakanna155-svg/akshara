"""Phase B8 Track 1 — governed document-structure recovery (option de-glue) tests."""
import unittest

from kie.qie import doc_recover as DR


class TestDeglue(unittest.TestCase):
    def test_splits_merged_sibling_option(self):
        # option (b)'s text was OCR-glued onto option (a); (b) is the answer
        raw = [{"label": "a", "text": "effector organs to CNS (b) receptors to CNS"},
               {"label": "c", "text": "CNS to receptors"},
               {"label": "d", "text": "CNS to muscles"}]
        opts = DR.deglue_options(raw)
        self.assertEqual(opts["a"], "effector organs to CNS")
        self.assertEqual(opts["b"], "receptors to CNS")
        self.assertEqual(opts["c"], "CNS to receptors")
        self.assertEqual(opts["d"], "CNS to muscles")

    def test_splits_c_into_c_and_d(self):
        raw = [{"label": "a", "text": "thyroid gland"}, {"label": "b", "text": "pineal gland"},
               {"label": "c", "text": "posterior pituitary (d) adrenal glands"}]
        opts = DR.deglue_options(raw)
        self.assertEqual(opts["c"], "posterior pituitary")
        self.assertEqual(opts["d"], "adrenal glands")

    def test_does_not_split_on_same_or_earlier_label(self):
        # a stray '(a)' inside prose must NOT create a spurious boundary (only distinct *later* letters split)
        raw = [{"label": "a", "text": "process (a) is shown"}, {"label": "b", "text": "two"}]
        opts = DR.deglue_options(raw)
        self.assertEqual(opts["a"], "process (a) is shown")
        self.assertEqual(opts["b"], "two")

    def test_truly_empty_option_not_fabricated(self):
        # no text for the merged option -> it is simply absent, never invented
        raw = [{"label": "a", "text": ""}, {"label": "b", "text": ""},
               {"label": "c", "text": "O2 & N2"}, {"label": "d", "text": "CO & CO2"}]
        opts = DR.deglue_options(raw)
        self.assertNotIn("a", opts)
        self.assertNotIn("b", opts)
        self.assertEqual(opts["c"], "O2 & N2")

    def test_normalize_requires_source_answer_present(self):
        q = {"answer_ref": "b", "doc_id": "d1", "question_id": "d1:q1", "stem": "x",
             "visual_dependent": False}
        # answer 'b' recovered -> item yielded
        self.assertIsNotNone(DR._normalize(q, "Biology", {"a": "one", "b": "two"}, "option_deglue"))
        # answer 'b' absent -> dropped (no fabrication)
        self.assertIsNone(DR._normalize(q, "Biology", {"a": "one", "c": "three"}, "option_deglue"))


if __name__ == "__main__":
    unittest.main()
