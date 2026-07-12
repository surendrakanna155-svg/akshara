"""E-lite ingestion — boundary + option + answer detection, visual preservation. Synthetic parsed doc."""
import unittest

from kie.qie import store as qstore, elite_ingest as E

# A synthetic parsed document mimicking phase2 output (text + images + equations phase4 drops).
PARSED = [
    {"page": 1,
     "text": ("1. A charge of 24 C flows through a conductor in 6 s. Calculate the current.\n"
              "(1) 4 A (2) 24 A (3) 144 A (4) 6 A\nAnswer (1)\nSol. I = Q/t = 24/6 = 4 A.\n"
              "2. Which organelle is the powerhouse of the cell?\n"
              "(1) Mitochondrion (2) Ribosome (3) Nucleus (4) Golgi\nAnswer (1)\n"),
     "images": [{"digest": "d1", "bbox": [0, 0, 10, 10], "width": 100, "height": 80}],
     "equations": [{"text": "I = Q/t", "bbox": [1, 1, 5, 2], "latex": "I=\\frac{Q}{t}"}]},
]


class TestEliteIngest(unittest.TestCase):
    def setUp(self):
        self.qie = qstore.open_store(":memory:")

    def test_question_boundaries_detected(self):
        qs = E.extract_questions("doc1", PARSED[0]["text"], page=1)
        self.assertEqual(len(qs), 2)
        q0 = qs[0]
        self.assertIn("charge of 24 C", q0["stem"])
        self.assertEqual(len(q0["options"]), 4)
        self.assertEqual(q0["answer_key"], "1")
        self.assertIsNotNone(q0["solution_ref"])
        self.assertEqual(q0["extraction_confidence"], 1.0)

    def test_visuals_preserved(self):
        vs = E.extract_visuals("doc1", PARSED)
        kinds = {v["kind"] for v in vs}
        self.assertIn("raster", kinds)     # image phase4 would have dropped
        self.assertIn("equation", kinds)   # equation phase4 would have dropped
        eq = next(v for v in vs if v["kind"] == "equation")
        self.assertEqual(eq["raw"], "I=\\frac{Q}{t}")   # LaTeX preserved

    def test_full_ingest_persists(self):
        res = E.ingest_parsed_doc(self.qie, "doc1", PARSED, "t")
        self.assertEqual(res["questions_persisted"], 2)
        self.assertEqual(res["visuals_persisted"], 2)
        n_q = self.qie.execute("SELECT COUNT(*) FROM elite_question WHERE doc_id='doc1'").fetchone()[0]
        n_v = self.qie.execute("SELECT COUNT(*) FROM elite_visual_asset WHERE doc_id='doc1'").fetchone()[0]
        self.assertEqual((n_q, n_v), (2, 2))

    def test_ingest_idempotent(self):
        E.ingest_parsed_doc(self.qie, "doc1", PARSED, "t")
        E.ingest_parsed_doc(self.qie, "doc1", PARSED, "t")   # same ids -> INSERT OR IGNORE
        n_q = self.qie.execute("SELECT COUNT(*) FROM elite_question").fetchone()[0]
        self.assertEqual(n_q, 2)


if __name__ == "__main__":
    unittest.main()
