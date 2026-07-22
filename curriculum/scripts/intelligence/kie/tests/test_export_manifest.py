"""Program D · M2.1 — the export manifest (freeze fingerprints + version tags).

Fixtures-only (in-memory production bank); always runs. Proves the two content-derived fingerprints are
present, stable, and honestly distinct (content_fp tracks shipped rows; substrate_fp tracks what was read).
"""
from __future__ import annotations

import hashlib
import unittest

from kie.qie.export import erp_promote
from kie.qie.export import fixtures as F
from kie.qie.export import manifest as M
from kie.qie.export.vocabulary import Concept, Vocabulary

_HEX64 = 64


def _sha256(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


class FingerprintPrimitives(unittest.TestCase):
    def test_content_fp_order_independent_and_sensitive(self):
        self.assertEqual(M.content_fp(["a", "b", "c"]), M.content_fp(["c", "a", "b"]))   # sorted internally
        self.assertNotEqual(M.content_fp(["a", "b"]), M.content_fp(["a", "b", "c"]))     # a new row changes it
        self.assertEqual(M.content_fp(["b", "a"]), _sha256("a\nb"))                       # exact recipe

    def test_substrate_fp_order_independent(self):
        self.assertEqual(M.substrate_fp(["x|1", "y|2"]), M.substrate_fp(["y|2", "x|1"]))


class BuiltManifest(unittest.TestCase):
    def setUp(self):
        self.fixture_rows = F.make_certified_fixture(12, 0)
        self.conn = F.build_fixture_bank(rows=self.fixture_rows)
        self.vocab = Vocabulary.from_concepts(
            [Concept(r["concept_code"], r["subject"], r["concept_title"]) for r in self.fixture_rows],
            "program-d-fixture")

    def tearDown(self):
        self.conn.close()

    def _manifest(self, vocab=None):
        return erp_promote.export_certified(self.conn, vocab or self.vocab)["manifest"]

    def test_all_fields_and_version_tags_present(self):
        m = self._manifest()
        self.assertEqual(m["artifact_version"], "program-d-export/1")
        self.assertEqual(m["generated_from"], "fixture")
        self.assertEqual(m["frozen_version"], "program-d-fixture")
        self.assertEqual(m["near_dup_model_version"], "hashvec-128-v1")
        self.assertEqual(m["near_dup_threshold_version"], "cosine-0.82-v1")
        self.assertEqual(m["enum_map_version"], "program-d-enum/1")
        self.assertEqual(m["row_count"], 12)
        self.assertEqual(len(m["content_fp"]), _HEX64)
        self.assertEqual(len(m["substrate_fp"]), _HEX64)

    def test_fingerprints_stable_across_exports(self):
        m1, m2 = self._manifest(), self._manifest()
        self.assertEqual(m1["content_fp"], m2["content_fp"])
        self.assertEqual(m1["substrate_fp"], m2["substrate_fp"])

    def test_content_fp_recomputes_from_exported_rows(self):
        art = erp_promote.export_certified(self.conn, self.vocab)
        expected = M.content_fp([r["content_hash"] for r in art["rows"]])
        self.assertEqual(art["manifest"]["content_fp"], expected)

    def test_row_count_matches_rows(self):
        art = erp_promote.export_certified(self.conn, self.vocab)
        self.assertEqual(art["manifest"]["row_count"], len(art["rows"]))

    def test_partial_vocab_changes_content_fp_but_not_substrate_fp(self):
        # Dropping a concept ships fewer rows (content_fp changes) but the SAME bank is read (substrate_fp
        # is invariant) — the honest distinction between "what shipped" and "what was read".
        full = self._manifest()
        drop_kc = self.fixture_rows[0]["concept_code"]
        partial_vocab = Vocabulary.from_concepts(
            [Concept(r["concept_code"], r["subject"], r["concept_title"])
             for r in self.fixture_rows if r["concept_code"] != drop_kc], "program-d-fixture")
        partial = self._manifest(partial_vocab)
        self.assertLess(partial["row_count"], full["row_count"])
        self.assertNotEqual(partial["content_fp"], full["content_fp"])
        self.assertEqual(partial["substrate_fp"], full["substrate_fp"])   # same substrate read


if __name__ == "__main__":
    unittest.main()
