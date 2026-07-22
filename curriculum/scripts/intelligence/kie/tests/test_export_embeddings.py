"""Program D · M4.3 — the offline near-dup hashing vectorizer (hashvec-128-v1).

Deterministic, offline, no DB (except reading the pure fixture generator for realistic paraphrase pairs).
Always runs. Proves: determinism, L2-unit output, fixed dim, number-invariance (the numbers→'#' discipline),
and that template-paraphrase stems cluster (cosine ≥ 0.82) while distinct templates separate (< 0.82).
"""
from __future__ import annotations

import math
import unittest

from kie.qie.export import embeddings as E
from kie.qie.export import fixtures as F

_STEM = "A crate holds 49 apples, and 14 more apples are packed in. How many apples are there in total?"


class HashVec(unittest.TestCase):
    def test_version_and_threshold_tags(self):
        self.assertEqual(E.HASHVEC_MODEL_VERSION, "hashvec-128-v1")
        self.assertEqual(E.NEAR_DUP_THRESHOLD_VERSION, "cosine-0.82-v1")
        self.assertEqual(E.NEAR_DUP_THRESHOLD, 0.82)
        self.assertEqual(E.HASHVEC_DIM, 128)

    def test_deterministic(self):
        self.assertEqual(E.hashvec_128(_STEM), E.hashvec_128(_STEM))

    def test_dim_is_128(self):
        self.assertEqual(len(E.hashvec_128(_STEM)), 128)
        self.assertEqual(len(E.hashvec_128("")), 128)          # even the empty stem is dim 128

    def test_l2_normalised_to_unit(self):
        v = E.hashvec_128(_STEM)
        self.assertAlmostEqual(math.sqrt(sum(x * x for x in v)), 1.0, places=9)

    def test_empty_stem_is_zero_vector_never_nan(self):
        v = E.hashvec_128("")
        self.assertEqual(v, [0.0] * 128)                       # honest zero vector, never NaN
        self.assertEqual(E.cosine(v, v), 0.0)                  # cosine of a zero vector is defined as 0.0

    def test_self_cosine_is_one(self):
        v = E.hashvec_128(_STEM)
        self.assertAlmostEqual(E.cosine(v, v), 1.0, places=9)

    def test_number_invariance(self):
        # Two stems differing ONLY in their numeric literals normalise to the same tokens (numbers→'#'),
        # so their vectors are identical and cosine is exactly 1.0 — the template-flooding signal.
        a = E.hashvec_128("Add 5 apples and 3 apples to the crate. How many apples?")
        b = E.hashvec_128("Add 12 apples and 99 apples to the crate. How many apples?")
        self.assertEqual(a, b)
        self.assertAlmostEqual(E.cosine(a, b), 1.0, places=9)


class NearDupSeparation(unittest.TestCase):
    """A paraphrase pair (same template, different context noun) must clear the 0.82 threshold while two
    different-template items stay below it — the property WP-D's cosine check relies on."""

    def setUp(self):
        self.rows = F.make_certified_fixture(12, 0)            # indices i and i+6 share a template

    def test_paraphrase_pair_above_threshold(self):
        for i in range(6):                                     # every same-template pair in the fixture
            a = E.hashvec_128(self.rows[i]["stem"])
            b = E.hashvec_128(self.rows[i + 6]["stem"])
            self.assertGreaterEqual(E.cosine(a, b), E.NEAR_DUP_THRESHOLD,
                                    f"same-template pair ({i},{i + 6}) fell below the near-dup threshold")

    def test_different_template_pair_below_threshold(self):
        # index 0 (_t_sum) vs index 1 (_t_diff) — genuinely different questions.
        a = E.hashvec_128(self.rows[0]["stem"])
        b = E.hashvec_128(self.rows[1]["stem"])
        self.assertLess(E.cosine(a, b), E.NEAR_DUP_THRESHOLD)

    def test_all_cross_template_pairs_below_threshold(self):
        # No two DISTINCT-template items (representatives 0..5) may look like near-dups.
        import itertools
        reps = [E.hashvec_128(self.rows[i]["stem"]) for i in range(6)]
        for i, j in itertools.combinations(range(6), 2):
            self.assertLess(E.cosine(reps[i], reps[j]), E.NEAR_DUP_THRESHOLD,
                            f"distinct templates {i},{j} wrongly look like a near-dup")


if __name__ == "__main__":
    unittest.main()
