"""R4-1 unified-inventory INVARIANTS: reproducibility, dedup/RI-9, model-agreement-never-promoted, honest-null,
RI-6 single product surface, freeze/read-only, and the qie.db evidence stamp. Fixture-only tests build a
synthetic manifest; DB-dependent tests assert the LIVE targets and self-skip when the estate is absent.
"""
from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie import store as QIE_STORE
from kie.qie.factory import corpus as CORPUS
from kie.qie.inventory import crosswalk as XW
from kie.qie.inventory import manifest as MF
from kie.qie.inventory import promote as PROMOTE
from kie.qie.inventory import register_evidence as RE
from kie.qie.inventory import store as ST

_PROMOTABLE = ("promotable", "practice_tier_eligible", "eligible")


def _synth_sources(tmp):
    """A synthetic qie.db with an EXACT-duplicate pair (same stem/options/answer) to exercise dedup."""
    path = os.path.join(tmp, "qie.db")
    conn = QIE_STORE.open_store(path)
    opts = json.dumps({"1": "100", "2": "200", "3": "50", "4": "25"})
    stem = ("A resistor of 20 ohm carries a steady current of 5 A. The potential difference across it "
            "(in volt) is:")
    base = ("IM1", "Physics", "NEET", "REL_OHMS_LAW", "single_step_numerical", "T_VIR", stem, opts, "100",
            "fk", "[]", None, "agree", "deterministic_solver", "det", "2026")
    conn.executemany(
        "INSERT INTO pilot_verified_item (gen_id,item_model_id,subject,profile,concept_code,archetype,"
        "frame_id,stem,options,answer_text,correct_fact_key,distractor_fact_keys,distractor_provenance,"
        "verifier_verdict,refuter_verdict,verifier_model,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [("D1", *base), ("D2", *base),                                    # EXACT duplicate pair
         ("M1", "IM2", "Biology", "NEET", "BIO_X", "ar", "F", "assoc insulin?",
          json.dumps({"1": "pancreas", "2": "liver"}), "pancreas", "fk", "[]", None, "agree", "agree",
          "judge", "2026")])                                             # model-agreement item
    conn.commit()
    conn.close()
    return path


def _build(tmp):
    qie = _synth_sources(tmp)
    unified = os.path.join(tmp, "unified_inventory.db")
    xw = XW.Crosswalk(version="test:fixture", by_name={})                # empty -> everything honest-null
    summ = MF.build(unified_path=unified, qie_path=qie, bank_path=None, corpus_path=None, crosswalk=xw)
    return unified, summ


class TestManifestReproducibility(unittest.TestCase):
    def test_two_builds_same_fingerprint(self):
        with tempfile.TemporaryDirectory() as tmp:
            u, s1 = _build(tmp)
            fp1 = s1["build_fingerprint"]
            s2 = MF.build(unified_path=u, qie_path=os.path.join(tmp, "qie.db"), bank_path=None,
                          corpus_path=None, crosswalk=XW.Crosswalk("test:fixture", {}))
            self.assertEqual(fp1, s2["build_fingerprint"])              # deterministic (excludes created_at)
            self.assertEqual(MF.build_fingerprint(u), fp1)


class TestDedupAndRI9(unittest.TestCase):
    def test_exact_dup_collapses_and_no_promotable_shares_item_hash(self):
        with tempfile.TemporaryDirectory() as tmp:
            u, summ = _build(tmp)
            self.assertEqual(summ["dedup"]["exact_dups_collapsed"], 1)  # D1/D2 -> one representative + one dup
            conn = ST.open_store(u, writable=False)
            try:
                dup = conn.execute("SELECT COUNT(*) FROM unified_inventory WHERE promotion_status='duplicate'"
                                   ).fetchone()[0]
                self.assertEqual(dup, 1)
                bad = conn.execute(
                    "SELECT item_hash, COUNT(*) n FROM unified_inventory WHERE promotion_status IN "
                    "('promotable','practice_tier_eligible','eligible') AND item_hash IS NOT NULL "
                    "GROUP BY item_hash HAVING n>1").fetchall()
                self.assertEqual(bad, [], "RI-9: two promotable rows share an item_hash")
            finally:
                conn.close()


class TestModelAgreementNeverPromoted(unittest.TestCase):
    def test_no_nondeterministic_row_is_promotable(self):
        with tempfile.TemporaryDirectory() as tmp:
            u, _ = _build(tmp)
            conn = ST.open_store(u, writable=False)
            try:
                rows = conn.execute(
                    "SELECT COUNT(*) FROM unified_inventory WHERE is_deterministic=0 AND promotion_status IN "
                    "('promotable','practice_tier_eligible','eligible','promoted')").fetchone()[0]
                self.assertEqual(rows, 0, "a model-agreement (is_deterministic=0) row reached a promotable state")
                # the model-agreement item is HELD
                m1 = conn.execute("SELECT promotion_status, is_deterministic FROM unified_inventory "
                                  "WHERE source_id='M1'").fetchone()
                self.assertEqual(m1["promotion_status"], "held_qualitative")
                self.assertEqual(m1["is_deterministic"], 0)
            finally:
                conn.close()


class TestHonestNullCrosswalk(unittest.TestCase):
    def test_unresolved_codes_are_null_never_guessed(self):
        with tempfile.TemporaryDirectory() as tmp:
            u, _ = _build(tmp)                                          # crosswalk is empty
            conn = ST.open_store(u, writable=False)
            try:
                guessed = conn.execute("SELECT COUNT(*) FROM unified_inventory WHERE concept_kc IS NOT NULL"
                                       ).fetchone()[0]
                self.assertEqual(guessed, 0, "empty crosswalk must leave every concept_kc NULL (honest-null)")
                unresolved = conn.execute("SELECT COUNT(*) FROM crosswalk WHERE resolved=0").fetchone()[0]
                self.assertGreater(unresolved, 0)
            finally:
                conn.close()


class TestRI6SingleProductSurface(unittest.TestCase):
    def test_manifest_store_is_not_a_product_bank(self):
        with tempfile.TemporaryDirectory() as tmp:
            u, _ = _build(tmp)
            conn = ST.open_store(u, writable=False)
            try:
                self.assertEqual(ST.store_role(conn), "unified_inventory")
                pv = conn.execute("SELECT value FROM unified_meta WHERE key='product_visible'").fetchone()[0]
                self.assertEqual(pv, "0")
            finally:
                conn.close()

    def test_corpus_product_reader_still_refuses_trial_and_unstamped(self):
        # RI-6 (unchanged by R4-1): only the production bank satisfies product_inventory.
        trial = CORPUS.open_store(":memory:", role=CORPUS.ROLE_TRIAL)
        with self.assertRaises(CORPUS.CorpusIntegrityError):
            CORPUS.product_inventory(trial, "run")
        trial.close()


class TestFreezeAndReadOnly(unittest.TestCase):
    def test_index_opener_is_read_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = os.path.join(tmp, "idx.db")
            c = sqlite3.connect(p)
            c.execute("CREATE TABLE ki_meta(key TEXT, value TEXT)")
            c.commit()
            c.close()
            ro = XW.open_index_ro(p)
            try:
                with self.assertRaises(sqlite3.OperationalError):
                    ro.execute("INSERT INTO ki_meta VALUES ('x','y')")
            finally:
                ro.close()

    def test_manifest_store_ro_default_refuses_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            u, _ = _build(tmp)
            ro = ST.open_store(u, writable=False)
            try:
                with self.assertRaises(sqlite3.OperationalError):
                    ro.execute("DELETE FROM unified_inventory")
            finally:
                ro.close()


class TestEvidenceRegistration(unittest.TestCase):
    def test_register_idempotent_and_refusal(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "qie.db")
            QIE_STORE.open_store(path).close()                          # a real qie.db with qie_meta
            r1 = RE.register(path)
            r2 = RE.register(path)                                       # idempotent
            self.assertEqual(r1, r2)
            self.assertEqual(r1["role"], "evidence_source")
            self.assertEqual(r1["product_visible"], "0")
            self.assertTrue(RE.is_registered(path))
            conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
            try:
                with self.assertRaises(RE.EvidenceOnlyViolation):
                    RE.assert_not_product_surface(conn)
            finally:
                conn.close()


class TestPromotionHonesty(unittest.TestCase):
    def test_zero_immediate_product_promotions(self):
        with tempfile.TemporaryDirectory() as tmp:
            u, _ = _build(tmp)
            a = PROMOTE.assess(u)
            self.assertEqual(a["promotable_to_product_bank_now"], 0)
            self.assertTrue(a["product_bar_gaps_blocking_pilot_items"])
            self.assertEqual(PROMOTE.promote(u)["promoted"], 0)
            self.assertFalse(PROMOTE.promote(u)["wrote_to_bank"])

    def test_ri6_followon_is_closed(self):
        # RI-6 re-point EXECUTED (owner-approved 2026-07-21): qp_bridge reads the manifest, not qie.db.
        f = PROMOTE.ri6_followon()
        self.assertIn("qp_bridge", f["issue"])
        self.assertEqual(f["status"], "CLOSED")
        self.assertIn("governed_scope_rows", f["closure"])


# ── LIVE targets (self-skip when the estate is absent) ────────────────────────────────────────────────
_LIVE = all((config.KIE_HOME / n).exists() for n in ("qie.db", "knowledge_index.db"))


@unittest.skipUnless(_LIVE, "live qie.db / knowledge_index.db not present (gitignored / local only)")
class TestLiveManifestTargets(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.summary = MF.build()                                        # writes the real unified_inventory.db

    def test_target_promotion_counts(self):
        pc = self.summary["promotion_counts"]
        self.assertEqual(pc.get("practice_tier_eligible"), 1434)       # 568 numeric re-verified + 866 honest-null
        self.assertEqual(pc.get("promotable"), 41)                     # governed_relations re-certified
        # held_qualitative tracks the LIVE governed_fact bank (grown by the offline examiner), so assert the
        # cross-source INVARIANT — 62 pilot model-agreement + the live governed_fact count — not a frozen number.
        import sqlite3
        gf_n = sqlite3.connect(f"file:{config.KIE_HOME / 'qie.db'}?mode=ro", uri=True).execute(
            "SELECT COUNT(*) FROM governed_fact WHERE status='verified'").fetchone()[0]
        self.assertEqual(pc.get("held_qualitative"), 62 + gf_n)        # 62 pilot model-agreement + governed_fact
        self.assertEqual(pc.get("eligible"), 77)                       # kvs assertions with >=2 source refs

    def test_no_nondeterministic_promotable_live(self):
        conn = MF.open_ro()
        try:
            bad = conn.execute(
                "SELECT COUNT(*) FROM unified_inventory WHERE is_deterministic=0 AND promotion_status IN "
                "('promotable','practice_tier_eligible','eligible','promoted')").fetchone()[0]
            self.assertEqual(bad, 0)
        finally:
            conn.close()

    def test_qie_registered_evidence_only(self):
        RE.register()
        self.assertTrue(RE.is_registered())


if __name__ == "__main__":
    unittest.main()
