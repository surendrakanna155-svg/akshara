"""Program D · M0.1 — the deterministic synthetic certified-bank fixture harness.

Fixtures-only (in-memory production bank); ALWAYS runs (no gitignored-DB skip), so the fixture strategy
that decouples Program-D construction from the empty-certified-bank blocker is itself under test.
"""
from __future__ import annotations

import json
import unittest
from pathlib import Path

from kie import config
from kie.qie.export import fixtures as F
from kie.qie.factory import corpus

# The committed golden corpus the ERP-side (Deno) tests load — drift-guarded below.
_GOLDEN = (config.WORKSPACE.parent / "supabase" / "functions" / "_shared" / "education"
           / "__tests__" / "fixtures" / "certified_corpus.json")
_GOLDEN_N, _GOLDEN_SEED = 12, 0


class MakeCertifiedFixture(unittest.TestCase):
    def test_determinism_same_seed(self):
        self.assertEqual(F.make_certified_fixture(12, 0), F.make_certified_fixture(12, 0))

    def test_seed_varies_content(self):
        self.assertNotEqual(F.make_certified_fixture(12, 0), F.make_certified_fixture(12, 1))

    def test_shape_conformance(self):
        rows = F.make_certified_fixture(18, 3)
        for r in rows:
            # QIE-native enums (the exporter maps these at the boundary — never here).
            self.assertEqual(r["question_type"], "MCQ")
            self.assertIn(r["intended_difficulty"], ("easy", "moderate", "hard"))
            self.assertEqual(r["lane"], "STRUCTURED_NUMERIC")
            # options: exactly 4 labels, answer_label present, answer_value agrees with the chosen option.
            self.assertEqual(set(r["options"]), {"A", "B", "C", "D"})
            self.assertIn(r["answer_label"], r["options"])
            self.assertEqual(r["options"][r["answer_label"]], r["answer_value"])
            # concept id is the QIE spine shape: KC_ + 14 hex.
            self.assertTrue(r["concept_code"].startswith("KC_"))
            self.assertEqual(len(r["concept_code"]), 3 + 14)
            # content identity + certification stamps.
            self.assertTrue(r["item_hash"].startswith("IH_"))
            self.assertTrue(r["stem_norm_hash"].startswith("NH_"))
            self.assertEqual(r["certification_class"], corpus.CERT_CERTIFIED)
            self.assertEqual(r["evidence_class"], corpus.EVIDENCE_SYMPY)
            # Bloom is drawn from the ERP cognitive_level axis (M2.2 target).
            self.assertIn(r["bloom"], ("remember", "understand", "apply", "analyze", "hots"))
            # provenance is real (never a placeholder banned id).
            self.assertNotIn(r["provenance"]["model"].lower(), corpus.BANNED_PROVENANCE_IDS)
            self.assertNotIn(r["provenance"]["actor"].lower(), corpus.BANNED_PROVENANCE_IDS)

    def test_distinct_content_and_norm_hashes(self):
        rows = F.make_certified_fixture(40, 7)
        self.assertEqual(len({r["item_hash"] for r in rows}), 40)
        self.assertEqual(len({r["stem_norm_hash"] for r in rows}), 40)   # each item a distinct template/noun

    def test_noun_pool_cap_is_explicit(self):
        with self.assertRaises(ValueError):
            F.make_certified_fixture(len(F._NOUNS) + 1, 0)


class BuildFixtureBank(unittest.TestCase):
    def test_promotes_all_to_product_visible_certified(self):
        rows = F.make_certified_fixture(20, 0)
        conn = F.build_fixture_bank(rows=rows)
        try:
            cb = corpus.certified_bank(conn)
            self.assertEqual(len(cb), 20)
            for r in cb:
                self.assertEqual(r["status"], corpus.CERTIFIED)
                self.assertEqual(r["certification_class"], corpus.CERT_CERTIFIED)
            self.assertEqual({r["candidate_id"] for r in cb}, {r["candidate_id"] for r in rows})
        finally:
            conn.close()

    def test_ri9_bank_dedup_is_really_exercised(self):
        # A real production bank stamped production_bank; RI-9 UNIQUE(item_hash) over certified rows means a
        # second identical item cannot re-promote. Proves build uses the genuine guarded write path.
        rows = F.make_certified_fixture(3, 0)
        conn = F.build_fixture_bank(rows=rows)
        try:
            with self.assertRaises(corpus.CorpusIntegrityError):
                # attempt to ingest+certify a byte-identical duplicate of row 0 into a fresh run
                dup = dict(rows[0])
                dup["run_id"] = "pd_fixture_dup_run"
                dup["spec_id"] = "pd_fixture_dup_spec"
                dup["candidate_id"] = corpus._cid(dup["run_id"], dup["spec_id"])
                F.build_fixture_bank(rows=[dup], conn=conn)
        finally:
            conn.close()

    def test_never_routes_through_the_real_production_bank(self):
        # Guard: build must use open_store(':memory:'), never open_production_bank (the real qpl bank opener).
        called = {"n": 0}
        orig = corpus.open_production_bank

        def _boom(*a, **k):
            called["n"] += 1
            raise AssertionError("build_fixture_bank must never open the real production bank")

        corpus.open_production_bank = _boom
        try:
            conn = F.build_fixture_bank(n=5, seed=0)
            conn.close()
        finally:
            corpus.open_production_bank = orig
        self.assertEqual(called["n"], 0)


class GoldenCorpus(unittest.TestCase):
    def test_committed_corpus_matches_generator(self):
        # Drift guard: the golden the ERP tests load MUST equal the generator's output. If a template
        # changes, regenerate the golden (see __tests__/fixtures/README.md) — never let them silently drift.
        if not _GOLDEN.exists():
            self.skipTest(f"golden corpus not present at {_GOLDEN} (regenerate it)")
        committed = json.loads(_GOLDEN.read_text())
        self.assertEqual(committed, F.make_certified_fixture(_GOLDEN_N, _GOLDEN_SEED))


if __name__ == "__main__":
    unittest.main()
