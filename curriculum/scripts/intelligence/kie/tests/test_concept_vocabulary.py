"""Program D · M0.2 — the KC_ ↔ UUID concept vocabulary.

Fixtures-only tests ALWAYS run (deterministic mint + honest-null). One DB-gated test reads the real frozen
index and self-skips when the (gitignored, local-only) knowledge_index.db is absent.
"""
from __future__ import annotations

import unittest
import uuid

from kie.qie.export import fixtures as F
from kie.qie.export import vocabulary as V


class Mint(unittest.TestCase):
    def test_deterministic_and_uuid5(self):
        u1 = V.mint_uuid("KC_0c47f5ab2c2f59")
        u2 = V.mint_uuid("KC_0c47f5ab2c2f59")
        self.assertEqual(u1, u2)
        self.assertEqual(uuid.UUID(u1).version, 5)                 # a derived identity, not random
        self.assertEqual(uuid.UUID(u1).variant, uuid.RFC_4122)

    def test_distinct_kc_distinct_uuid(self):
        kcs = [f"KC_{i:014x}" for i in range(500)]
        self.assertEqual(len({V.mint_uuid(k) for k in kcs}), 500)  # collision-free in practice

    def test_empty_kc_rejected(self):
        with self.assertRaises(ValueError):
            V.mint_uuid("")


class VocabularyResolve(unittest.TestCase):
    def _vocab(self):
        concepts = [
            V.Concept("KC_aaaaaaaaaaaaaa", "Mathematics", "Addition of whole numbers"),
            V.Concept("KC_bbbbbbbbbbbbbb", "Mathematics", "Division as equal sharing"),
            V.Concept("KC_aaaaaaaaaaaaaa", "Mathematics", "dup — first wins"),   # dedup by kc_id
        ]
        return V.Vocabulary.from_concepts(concepts, frozen_version="test-frozen-v1")

    def test_known_resolves_to_minted_uuid_roundtrip(self):
        vocab = self._vocab()
        self.assertEqual(vocab.resolve("KC_aaaaaaaaaaaaaa"), V.mint_uuid("KC_aaaaaaaaaaaaaa"))
        self.assertEqual(vocab.resolve("KC_bbbbbbbbbbbbbb"), V.mint_uuid("KC_bbbbbbbbbbbbbb"))

    def test_unknown_is_honest_null_never_guessed(self):
        vocab = self._vocab()
        self.assertIsNone(vocab.resolve("KC_ffffffffffffff"))     # absent from source ⇒ None, never invented
        self.assertIsNone(vocab.resolve(""))

    def test_dedup_and_rows_stamped(self):
        vocab = self._vocab()
        self.assertEqual(len(vocab), 2)                            # the duplicate kc_id collapsed
        rows = vocab.rows()
        self.assertEqual([r["kc_id"] for r in rows], sorted(r["kc_id"] for r in rows))  # deterministic order
        for r in rows:
            self.assertEqual(r["frozen_version"], "test-frozen-v1")
            self.assertEqual(r["concept_uuid"], V.mint_uuid(r["kc_id"]))

    def test_partial_coverage_excludes_uncovered_items(self):
        # Build a vocabulary from ONLY the first concept of the fixture, then confirm items whose KC is not
        # covered resolve None (the exporter would drop them — honest-null, not a guessed mapping).
        rows = F.make_certified_fixture(12, 0)
        covered_kc = rows[0]["concept_code"]
        vocab = V.Vocabulary.from_concepts(
            [V.Concept(covered_kc, rows[0]["subject"], rows[0]["concept_title"])], frozen_version="fx")
        covered = [r for r in rows if r["concept_code"] == covered_kc]
        uncovered = [r for r in rows if r["concept_code"] != covered_kc]
        self.assertTrue(covered and uncovered)                    # the fixture spans several concepts
        for r in covered:
            self.assertEqual(vocab.resolve(r["concept_code"]), V.mint_uuid(covered_kc))
        for r in uncovered:
            self.assertIsNone(vocab.resolve(r["concept_code"]))

    def test_full_fixture_vocabulary_covers_every_item(self):
        rows = F.make_certified_fixture(24, 5)
        concepts = [V.Concept(r["concept_code"], r["subject"], r["concept_title"]) for r in rows]
        vocab = V.Vocabulary.from_concepts(concepts, frozen_version="fx")
        for r in rows:
            self.assertIsNotNone(vocab.resolve(r["concept_code"]))


class FrozenIndexSeed(unittest.TestCase):
    def test_load_real_certified_concepts(self):
        # DB-gated: reads the frozen knowledge_index.db (gitignored, local-only). Self-skips in CI.
        try:
            concepts = V.load_certified_concepts()
        except FileNotFoundError as e:
            self.skipTest(f"frozen knowledge_index.db not present (gitignored, local only): {e}")
        self.assertGreater(len(concepts), 0)
        for c in concepts[:50]:
            self.assertTrue(c.kc_id.startswith("KC_"))
        # a real seed builds cleanly and resolves its own KC ids.
        vocab = V.Vocabulary.from_concepts(concepts, frozen_version="frozen")
        self.assertGreater(len(vocab), 0)
        sample = concepts[0].kc_id
        self.assertEqual(vocab.resolve(sample), V.mint_uuid(sample))


if __name__ == "__main__":
    unittest.main()
