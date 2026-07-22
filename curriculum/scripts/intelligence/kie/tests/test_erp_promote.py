"""Program D · M1.2 / M2.1 / M2.2 — the OFFLINE deterministic QIE→ERP exporter.

Fixtures-only (in-memory production bank); always runs. Proves fail-closed admission (certified + mapped
only, honest-null on an unmapped KC), the boundary enum map, the M2.2 derivations, determinism
(byte-identical artifact), and — critically — that the exporter NEVER mutates the certified bank.
"""
from __future__ import annotations

import json
import unittest

from kie.qie.export import erp_promote
from kie.qie.export import fixtures as F
from kie.qie.export.vocabulary import Concept, Vocabulary, mint_uuid
from kie.qie.factory import corpus

_CONTRACT_ROW_FIELDS = {
    "content_hash", "stem_norm_hash", "question_text", "answer_text", "options", "answer_label",
    "question_type", "difficulty", "difficulty_calibration", "cognitive_level", "marks", "subject_name",
    "chapter", "topic", "program_track", "kc_id", "concept_uuid", "near_dup_embedding", "provenance",
    "frozen_version",
}
_PROVENANCE_FIELDS = {"generator_model", "generator_family", "evidence_class", "certification_class",
                      "run_id", "model_version", "generator_actor"}


def _full_vocab(fixture_rows):
    return Vocabulary.from_concepts(
        [Concept(r["concept_code"], r["subject"], r["concept_title"]) for r in fixture_rows],
        "program-d-fixture")


def _snapshot_bank(conn):
    """A stable, comparable snapshot of the certified bank (sqlite3.Row → tuple) for the read-only proof."""
    return [tuple(r) for r in corpus.certified_bank(conn)]


class ExportAdmission(unittest.TestCase):
    def setUp(self):
        self.fixture_rows = F.make_certified_fixture(12, 0)
        self.conn = F.build_fixture_bank(rows=self.fixture_rows)
        self.vocab = _full_vocab(self.fixture_rows)

    def tearDown(self):
        self.conn.close()

    def test_all_certified_and_mapped_exported(self):
        art = erp_promote.export_certified(self.conn, self.vocab)
        self.assertEqual(len(art["rows"]), 12)
        exported_hashes = {r["content_hash"] for r in art["rows"]}
        self.assertEqual(exported_hashes, {r["item_hash"] for r in self.fixture_rows})
        for r in art["rows"]:
            self.assertEqual(set(r.keys()), _CONTRACT_ROW_FIELDS)              # exact Contract-1 shape
            self.assertEqual(r["concept_uuid"], mint_uuid(r["kc_id"]))         # resolved, never guessed
            self.assertIsNotNone(r["concept_uuid"])

    def test_partial_vocab_excludes_unmapped_rows_honest_null(self):
        drop_kc = self.fixture_rows[0]["concept_code"]
        partial = Vocabulary.from_concepts(
            [Concept(r["concept_code"], r["subject"], r["concept_title"])
             for r in self.fixture_rows if r["concept_code"] != drop_kc], "program-d-fixture")
        dropped_hashes = {r["item_hash"] for r in self.fixture_rows if r["concept_code"] == drop_kc}
        self.assertTrue(dropped_hashes)                                        # the concept did cover rows
        art = erp_promote.export_certified(self.conn, partial)
        exported = {r["content_hash"] for r in art["rows"]}
        self.assertTrue(exported.isdisjoint(dropped_hashes))                   # unmapped KC → excluded
        self.assertTrue(all(r["kc_id"] != drop_kc for r in art["rows"]))
        self.assertEqual(len(art["rows"]), 12 - len(dropped_hashes))

    def test_empty_vocab_exports_nothing_but_substrate_still_read(self):
        art = erp_promote.export_certified(self.conn, Vocabulary.from_concepts([], "program-d-fixture"))
        self.assertEqual(art["rows"], [])                                      # every row honest-null excluded
        self.assertEqual(art["manifest"]["row_count"], 0)
        # substrate_fp still fingerprints the 12 rows that WERE read (proof of read, not of ship).
        self.assertEqual(len(art["manifest"]["substrate_fp"]), 64)


class EnumMapAndDerivations(unittest.TestCase):
    def setUp(self):
        self.fixture_rows = F.make_certified_fixture(12, 0)
        self.conn = F.build_fixture_bank(rows=self.fixture_rows)
        self.art = erp_promote.export_certified(self.conn, _full_vocab(self.fixture_rows))

    def tearDown(self):
        self.conn.close()

    def test_enum_map_no_qie_native_leak(self):
        for r in self.art["rows"]:
            self.assertEqual(r["question_type"], "mcq")                        # MCQ → mcq
            self.assertNotEqual(r["question_type"], "MCQ")                      # no QIE-native leak
            self.assertIn(r["difficulty"], ("easy", "medium", "hard"))
            self.assertNotEqual(r["difficulty"], "moderate")                    # moderate → medium, never leaks
        difficulties = {r["difficulty"] for r in self.art["rows"]}
        self.assertIn("medium", difficulties)                                  # the mapped value is present
        self.assertNotIn("moderate", difficulties)

    def test_difficulty_calibration_always_predicted(self):
        for r in self.art["rows"]:
            self.assertEqual(r["difficulty_calibration"], "predicted_uncalibrated")   # M2.1 / R2-5

    def test_marks_and_cognitive_level_derivation(self):
        for r in self.art["rows"]:
            self.assertEqual(r["marks"], 1)                                    # mcq → 1 (M2.2 table)
            self.assertGreater(r["marks"], 0)
            # cognitive_level derives from earned depth (1..3 in the fixture) → remember/understand/apply.
            self.assertIn(r["cognitive_level"], ("remember", "understand", "apply"))
        self.assertIn("understand", {r["cognitive_level"] for r in self.art["rows"]})

    def test_static_fields_and_provenance_shape(self):
        for r in self.art["rows"]:
            self.assertEqual(r["program_track"], "board")
            self.assertEqual(r["topic"], "")
            self.assertEqual(r["subject_name"], "Mathematics")
            self.assertEqual(set(r["provenance"].keys()), _PROVENANCE_FIELDS)
            self.assertEqual(r["provenance"]["certification_class"], "certified")
            self.assertEqual(r["provenance"]["evidence_class"], "sympy_rederived")
            self.assertEqual(r["frozen_version"], "program-d-fixture")
            # options projected to an array ordered by label A,B,C,D.
            self.assertIsInstance(r["options"], list)
            self.assertEqual(len(r["options"]), 4)
            self.assertIn(r["answer_text"], r["options"])                      # correct value is among options

    def test_near_dup_embedding_shape(self):
        for r in self.art["rows"]:
            self.assertEqual(len(r["near_dup_embedding"]), 128)


class DeterminismAndReadOnly(unittest.TestCase):
    def setUp(self):
        self.fixture_rows = F.make_certified_fixture(12, 0)
        self.conn = F.build_fixture_bank(rows=self.fixture_rows)
        self.vocab = _full_vocab(self.fixture_rows)

    def tearDown(self):
        self.conn.close()

    def test_rows_sorted_by_content_hash_ascending(self):
        rows = erp_promote.export_certified(self.conn, self.vocab)["rows"]
        self.assertEqual([r["content_hash"] for r in rows], sorted(r["content_hash"] for r in rows))

    def test_two_exports_are_byte_identical(self):
        a = json.dumps(erp_promote.export_certified(self.conn, self.vocab), sort_keys=True)
        b = json.dumps(erp_promote.export_certified(self.conn, self.vocab), sort_keys=True)
        self.assertEqual(a, b)

    def test_export_does_not_mutate_the_certified_bank(self):
        before = _snapshot_bank(self.conn)
        erp_promote.export_certified(self.conn, self.vocab)
        erp_promote.export_certified(self.conn, self.vocab)                    # twice, to be sure
        after = _snapshot_bank(self.conn)
        self.assertEqual(before, after)                                        # byte-identical substrate (read-only)


if __name__ == "__main__":
    unittest.main()
