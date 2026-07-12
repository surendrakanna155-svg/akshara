"""Concept resolver — strict, confidence-gated answer/stem entity-linking; never forces uncertain maps."""
import unittest

from kie.qie import concept_resolve as CR


# index rows: (concept_code, normalized_title, title_root)
def _idx(pairs):
    return [(c, CR._norm(t), " ".join(CR._root(w) for w in CR._norm(t).split() if w not in CR._STOP))
            for c, t in pairs]


class TestResolve(unittest.TestCase):
    def setUp(self):
        self.index = _idx([
            ("BIO_MITOCHONDRIA", "Mitochondria"),
            ("BIO_NEPHRON", "Nephron"),
            ("BIO_RIBOSOME", "Ribosome"),
            ("PHY_ELECTRIC_CELL", "Electric cell"),
        ])

    def test_answer_singular_plural_root_match(self):
        # answer "mitochondrion" resolves to the "Mitochondria" concept via latin-plural root
        self.assertEqual(CR.resolve("Which organelle is the powerhouse?", "mitochondrion", self.index),
                         "BIO_MITOCHONDRIA")

    def test_exact_answer_match(self):
        self.assertEqual(CR.resolve("stem", "Nephron", self.index), "BIO_NEPHRON")

    def test_uncertain_returns_none_not_forced(self):
        # a vague answer that matches no concept confidently -> None (must NOT force a mapping)
        self.assertIsNone(CR.resolve("Which of the following is correct?", "all of the above", self.index))
        self.assertIsNone(CR.resolve("random stem about cells", "increases", self.index))

    def test_short_token_does_not_overmatch(self):
        # "cell" (short) must NOT resolve to "Electric cell" — avoids the coarse-bucket over-match
        self.assertIsNone(CR.resolve("what is a cell", "cell", self.index))


if __name__ == "__main__":
    unittest.main()
