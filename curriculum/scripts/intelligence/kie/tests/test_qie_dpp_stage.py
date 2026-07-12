"""DPP staging — tolerant Q-numbering recovery + inline-key detection (synthetic text; no PDF/PyMuPDF)."""
import unittest

from kie.qie import dpp_stage


class TestDppRecover(unittest.TestCase):
    def test_q_numbering_and_inline_key(self):
        text = ("Q1. A resistor of 30 ohm carries 9 A. Find the voltage.\n"
                "(1) 270 (2) 39 (3) 21 (4) 3\nAns: (1)\n"
                "Q2. Which organelle is the powerhouse of the cell?\n"
                "(1) Mitochondrion (2) Ribosome (3) Nucleus (4) Golgi\nAnswer (1)\n")
        recs = dpp_stage.recover_dpp(text)
        self.assertEqual(len(recs), 2)
        self.assertEqual(recs[0]["key"], 1)          # "Ans: (1)" detected
        self.assertEqual(recs[1]["key"], 1)          # "Answer (1)" detected
        self.assertIn("resistor", recs[0]["stem"])

    def test_no_options_no_recovery(self):
        # image-heavy DPP: numbering present but options are figures (empty) -> recovered nothing (honest)
        text = "Q1. The ligand is:\n(1)\n(2)\n(3)\n(4)\nQ2. The configuration is:\n(1)\n(2)\n(3)\n(4)\n"
        self.assertEqual(dpp_stage.recover_dpp(text), [])

    def test_plain_numbering_also_works(self):
        text = "1. Find 2+2.\n(1) 4 (2) 5 (3) 6 (4) 3\nAnswer (1)\n"
        recs = dpp_stage.recover_dpp(text)
        self.assertEqual(len(recs), 1)
        self.assertEqual(recs[0]["key"], 1)


if __name__ == "__main__":
    unittest.main()
