"""Phase B9 — governed stranded-source reuse bridge tests (multi-format recovery, answer sources, guards)."""
import sqlite3
import unittest

from kie.qie import stranded_recover as SR


def _kie(rows):
    """rows: list of (doc_id, exam, doc_type, subject, chunk_text). Build a minimal read-model kie.db."""
    c = sqlite3.connect(":memory:")
    c.execute("CREATE TABLE source_documents(doc_id TEXT, exam TEXT, doc_type TEXT, subject TEXT)")
    c.execute("CREATE TABLE chunks(doc_id TEXT, text TEXT)")
    seen = set()
    for doc_id, exam, doc_type, subject, text in rows:
        if doc_id not in seen:
            c.execute("INSERT INTO source_documents VALUES (?,?,?,?)", (doc_id, exam, doc_type, subject))
            seen.add(doc_id)
        c.execute("INSERT INTO chunks VALUES (?,?)", (doc_id, text))
    c.commit()
    return c


class TestOptionFormats(unittest.TestCase):
    def test_paren_num(self):
        o = SR.parse_options_multiformat("stem (1) alpha (2) beta (3) gamma (4) delta")
        self.assertEqual(o, {"1": "alpha", "2": "beta", "3": "gamma", "4": "delta"})

    def test_dot_num(self):
        o = SR.parse_options_multiformat("stem 1. Fe 2. Zn 3. Mg 4. Cu")
        self.assertEqual(o["1"], "Fe"); self.assertEqual(o["4"], "Cu")

    def test_paren_alpha_maps_to_numeric(self):
        o = SR.parse_options_multiformat("stem (a) one (b) two (c) three (d) four")
        self.assertEqual(o, {"1": "one", "2": "two", "3": "three", "4": "four"})

    def test_fewer_than_three_options_rejected(self):
        self.assertEqual(SR.parse_options_multiformat("stem (1) only one"), {})


class TestAnswerGrid(unittest.TestCase):
    def test_grid_detected_from_run(self):
        g = SR.build_answer_grid("KEY 1. (3) 2. (1) 3. (4) 4. (2) 5. (3) 6. (1)")
        self.assertEqual(g[1], "3"); self.assertEqual(g[4], "2"); self.assertEqual(g[6], "1")

    def test_short_run_not_a_grid(self):
        self.assertEqual(SR.build_answer_grid("see 1. (2) and 2. (3)"), {})


class TestRecoveredItems(unittest.TestCase):
    def test_inline_answer_recovery(self):
        c = _kie([("d1", "Practice_Resources", "sample_paper", "Physics",
                   "1. A body has velocity 10 m/s and acceleration 2. Find v after 5s. "
                   "(1) 20 (2) 30 (3) 40 (4) 50 Answer (1)")])
        items = list(SR.recovered_items(c))
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["answer_label"], "1")
        self.assertEqual(items[0]["answer_text"], "20")
        self.assertEqual(items[0]["recovery"], "inline_answer")
        self.assertEqual(items[0]["source"], "Practice_Resources")

    def test_answer_grid_association(self):
        # a question with no inline answer, but a same-doc key grid supplies it by question number
        txt = ("2. In this reaction which molecule forms? (1) H2 (2) O2 (3) N2 (4) CO2\n"
               "ANSWER KEY 1. (2) 2. (4) 3. (1) 4. (3) 5. (2) 6. (1)")
        c = _kie([("d2", "Practice_Resources", "sample_paper", "Chemistry", txt)])
        items = list(SR.recovered_items(c))
        self.assertTrue(any(it["qnum"] == 2 and it["answer_label"] == "4"
                            and it["recovery"] == "answer_grid" for it in items))

    def test_no_answer_no_fabrication(self):
        # options present but no inline answer and no grid -> item is NOT yielded (never invents an answer)
        c = _kie([("d3", "Practice_Resources", "sample_paper", "Physics",
                   "1. Some physics question about force. (1) 10 (2) 20 (3) 30 (4) 40")])
        self.assertEqual(list(SR.recovered_items(c)), [])

    def test_solution_doc_type_excluded(self):
        # solution/answer-key docs are prose OCR -> excluded to avoid injecting noise
        c = _kie([("d4", "AIIMS", "solution", "Physics",
                   "1. (a): explanation text (1) 10 (2) 20 (3) 30 (4) 40 Answer (2)")])
        self.assertEqual(list(SR.recovered_items(c)), [])

    def test_only_stranded_sources(self):
        # NEET is recovered natively by the miner; the bridge must not touch it
        c = _kie([("d5", "NEET", "dpp", "Biology",
                   "1. Question? (1) a (2) b (3) c (4) d Answer (1)")])
        self.assertEqual(list(SR.recovered_items(c, sources=("JEE_Main", "AIIMS"))), [])


if __name__ == "__main__":
    unittest.main()
