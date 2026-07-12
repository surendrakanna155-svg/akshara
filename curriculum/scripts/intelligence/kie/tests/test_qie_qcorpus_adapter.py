"""qcorpus read-only adapter — subject attribution + normalized item shaping (synthetic manifests)."""
import json
import os
import tempfile
import unittest

from kie.qie import qcorpus_adapter as qa


class TestSubjectAttribution(unittest.TestCase):
    def test_rel_path_subject_wins(self):
        self.assertEqual(qa._doc_subject("x/JEE_Advanced/DPP/Mathematics/algebra.pdf", "P6", "g"), "Mathematics")
        self.assertEqual(qa._doc_subject("studentbro/Biology/dpp01.pdf", "P1_studentbro_biology", "g"), "Biology")
        self.assertEqual(qa._doc_subject("x/Chemistry/y.pdf", "P2", "g"), "Chemistry")
        self.assertEqual(qa._doc_subject("x/Physics/y.pdf", "P3", "g"), "Physics")

    def test_priority_fallback(self):
        self.assertEqual(qa._doc_subject("archive/unknown.pdf", "P5_studentbro_mathematics", "g"), "Mathematics")


class TestAdapterItems(unittest.TestCase):
    def test_yields_answer_associated_nonvisual_items(self):
        with tempfile.TemporaryDirectory() as d:
            man = os.path.join(d, "manifests")
            os.makedirs(man)
            with open(os.path.join(man, "corpus_inventory.jsonl"), "w") as f:
                f.write(json.dumps({"doc_id": "D1", "rel_path": "x/Biology/a.pdf",
                                    "priority": "P1_studentbro_biology", "group": "g"}) + "\n")
            with open(os.path.join(man, "extracted_questions.jsonl"), "w") as f:
                # a good keyed MCQ, a visual-dependent one (excluded), a non-answer one (excluded)
                f.write(json.dumps({"doc_id": "D1", "is_mcq": True, "answer_associated": True, "answer_ref": "b",
                                    "visual_dependent": False, "stem": "Which is the powerhouse of the cell?",
                                    "options": [{"label": "a", "text": "Ribosome"},
                                                {"label": "b", "text": "Mitochondrion"}]}) + "\n")
                f.write(json.dumps({"doc_id": "D1", "is_mcq": True, "answer_associated": True, "answer_ref": "a",
                                    "visual_dependent": True, "stem": "Identify the labelled part",
                                    "options": [{"label": "a", "text": "X"}]}) + "\n")
                f.write(json.dumps({"doc_id": "D1", "is_mcq": True, "answer_associated": False, "answer_ref": "",
                                    "stem": "No key", "options": [{"label": "a", "text": "Y"}]}) + "\n")
            items = list(qa.recovered_items(d))
            self.assertEqual(len(items), 1)                       # only the keyed non-visual MCQ
            it = items[0]
            self.assertEqual(it["subject"], "Biology")
            self.assertEqual(it["answer_text"], "Mitochondrion")  # answer_ref 'b' -> option b text
            self.assertFalse(it["visual_dependent"])


if __name__ == "__main__":
    unittest.main()
