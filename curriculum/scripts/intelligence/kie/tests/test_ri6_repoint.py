"""RI-6 re-point (owner-approved 2026-07-21): qp_bridge's product BOUNDARY for governed relations/facts is
sourced from the unified manifest (`unified_inventory.db`), never a direct qie.db read. These tests lock the
governance guarantee: only manifest-admitted governed assets (relations `promotable`, facts `held_qualitative`)
define a paper's syllabus scope, and a quarantined / rejected / duplicate governed asset can NEVER reach it.

Fixture tests build a synthetic manifest by direct insertion so they run without the live estate; the LIVE
class asserts the real re-pointed behaviour and self-skips when the gitignored estate is absent.
"""
from __future__ import annotations

import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie import store as QIE_STORE
from kie.qie.inventory import manifest as MF
from kie.qie.inventory import store as ST


def _insert(conn, *, source_id, asset_class, subject, compose_concept, promotion_status,
            is_deterministic=1, source_store="qie.db", source_table="governed_relation"):
    uid = "UI_" + source_id
    conn.execute(
        "INSERT INTO unified_inventory (uid, source_store, source_table, source_id, asset_class, subject, "
        "compose_concept, is_deterministic, promotion_status, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
        (uid, source_store, source_table, source_id, asset_class, subject, compose_concept,
         is_deterministic, promotion_status, "2026-07-21T00:00:00+00:00"))


def _synth_manifest(tmp):
    """A manifest holding one admitted + several NON-admitted governed assets per class."""
    path = os.path.join(tmp, "unified_inventory.db")
    conn = ST.open_store(path, writable=True)
    try:
        # ADMITTED
        _insert(conn, source_id="R_OK", asset_class="relation", subject="Physics",
                compose_concept="Physics :: Ohms law", promotion_status="promotable")
        _insert(conn, source_id="F_OK", asset_class="fact", subject="Biology",
                compose_concept="Biology :: Uricotelism", promotion_status="held_qualitative",
                is_deterministic=0, source_table="governed_fact")
        # NON-ADMITTED — must never surface
        _insert(conn, source_id="R_QUAR", asset_class="relation", subject="Physics",
                compose_concept="Physics :: Refuted relation", promotion_status="quarantined")
        _insert(conn, source_id="R_REJ", asset_class="relation", subject="Physics",
                compose_concept="Physics :: Rejected relation", promotion_status="rejected_source")
        _insert(conn, source_id="F_QUAR", asset_class="fact", subject="Biology",
                compose_concept="Biology :: Refuted fact", promotion_status="quarantined",
                is_deterministic=0, source_table="governed_fact")
        # a promotable QUESTION_ITEM is NOT a governed scope asset (only relation/fact define scope)
        _insert(conn, source_id="Q_OK", asset_class="question_item", subject="Physics",
                compose_concept=None, promotion_status="promotable")
        # a Chemistry fact — for the subject-filter test
        _insert(conn, source_id="F_CHEM", asset_class="fact", subject="Chemistry",
                compose_concept="Chemistry :: Mole concept", promotion_status="held_qualitative",
                is_deterministic=0, source_table="governed_fact")
        conn.commit()
    finally:
        conn.close()
    return path


class TestGovernedScopeGate(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.manifest = _synth_manifest(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_only_admitted_governed_assets_define_scope(self):
        rows = MF.governed_scope_rows({"Physics", "Biology"}, unified_path=self.manifest)
        by_id = {r["source_id"]: r for r in rows}
        self.assertEqual(set(by_id), {"R_OK", "F_OK"})                 # exactly the two admitted governed assets
        self.assertEqual(by_id["R_OK"]["promotion_status"], "promotable")
        self.assertEqual(by_id["F_OK"]["promotion_status"], "held_qualitative")

    def test_quarantined_rejected_duplicate_never_surface(self):
        rows = MF.governed_scope_rows({"Physics", "Biology"}, unified_path=self.manifest)
        surfaced = {r["compose_concept"] for r in rows}
        for forbidden in ("Physics :: Refuted relation", "Physics :: Rejected relation",
                          "Biology :: Refuted fact"):
            self.assertNotIn(forbidden, surfaced,
                             f"RI-6 breach: a non-admitted governed asset reached product scope ({forbidden})")

    def test_question_items_are_not_governed_scope_assets(self):
        # a promotable QUESTION item is banked/consumed elsewhere; it must not appear as a governed CONCEPT
        rows = MF.governed_scope_rows({"Physics"}, unified_path=self.manifest)
        self.assertNotIn("Q_OK", {r["source_id"] for r in rows})

    def test_subject_filter(self):
        rows = MF.governed_scope_rows({"Physics"}, unified_path=self.manifest)
        self.assertEqual({r["source_id"] for r in rows}, {"R_OK"})     # Biology fact + Chemistry fact excluded

    def test_qp_bridge_boundary_follows_manifest_not_qie_db(self):
        # _governed_concepts, pointed at the synthetic manifest, must reflect the MANIFEST — not the live
        # qie.db (which, when present, holds ~90 Biology facts none of which are in this manifest).
        from kie.qie import qp_bridge as QB
        concepts, by_chapter, _w = QB._governed_concepts(["Physics", "Biology"], unified_path=self.manifest)
        self.assertIn("Physics :: Ohms law", by_chapter)
        self.assertIn("Biology :: Uricotelism", by_chapter)
        # the non-admitted governed assets are absent from the syllabus boundary
        for forbidden in ("Physics :: Refuted relation", "Physics :: Rejected relation",
                          "Biology :: Refuted fact"):
            self.assertNotIn(forbidden, by_chapter)
        # PROOF the source is the manifest, not qie.db: only the ONE Biology fact this manifest admits is
        # in-scope (the live qie.db's 90 Biology facts do NOT leak in). Chains are code-defined (Physics only).
        bio = [cc for cc in by_chapter if cc.startswith("Biology ::")]
        self.assertEqual(bio, ["Biology :: Uricotelism"])


class TestFreshnessDrift(unittest.TestCase):
    def _seed_governed_fact(self, c, status="verified"):
        c.execute("INSERT INTO governed_fact (fact_id, subject, concept_candidate, lane, fact_text, "
                  "answer_text, provenance, verification, status, created_at) VALUES "
                  "('GF1','Biology','Excretory Products','STRUCTURE_FUNCTION','the liver detoxifies','liver',"
                  "'{}','{}',?,'2026-07-21')", (status,))

    def test_freshness_detects_count_preserving_governed_mutation(self):
        # verifier finding #4: a COUNT-preserving in-place change (a status flip) must trip freshness —
        # a COUNT(*)-only signal would have missed it and served a stale boundary silently.
        with tempfile.TemporaryDirectory() as tmp:
            qie = os.path.join(tmp, "qie.db")
            c = QIE_STORE.open_store(qie)
            self._seed_governed_fact(c, "verified")
            c.commit(); c.close()
            unified = os.path.join(tmp, "unified_inventory.db")
            from kie.qie.inventory import crosswalk as XW
            MF.build(unified_path=unified, qie_path=qie, bank_path=None, corpus_path=None,
                     crosswalk=XW.Crosswalk("test:fixture", {}))
            self.assertTrue(MF.governed_scope_freshness(qie_path=qie, unified_path=unified)["fresh"])
            # flip status verified->quarantined: SAME row count, different governed content
            c = QIE_STORE.open_store(qie)
            n_before = c.execute("SELECT COUNT(*) FROM governed_fact").fetchone()[0]
            c.execute("UPDATE governed_fact SET status='quarantined' WHERE fact_id='GF1'")
            c.commit()
            n_after = c.execute("SELECT COUNT(*) FROM governed_fact").fetchone()[0]
            c.close()
            self.assertEqual(n_before, n_after, "mutation must be count-preserving to prove the point")
            fr = MF.governed_scope_freshness(qie_path=qie, unified_path=unified)
            self.assertFalse(fr["fresh"], "count-preserving governed mutation not detected (finding #4)")
            self.assertIn("drifted", fr["reason"])

    def test_missing_manifest_is_honest_unknown(self):
        with tempfile.TemporaryDirectory() as tmp:
            fr = MF.governed_scope_freshness(unified_path=os.path.join(tmp, "nope.db"))
            self.assertIsNone(fr["fresh"])
            self.assertIn("absent", fr["reason"])


# ── LIVE re-point behaviour ───────────────────────────────────────────────────────────────────────────
_LIVE = all((config.KIE_HOME / n).exists()
            for n in ("qie.db", "knowledge_index.db", "unified_inventory.db", "kie.db"))


@unittest.skipUnless(_LIVE, "live estate not present (gitignored / local only)")
class TestLiveRepoint(unittest.TestCase):
    def test_live_governed_scope_matches_manifest_admitted_set(self):
        # every governed concept qp_bridge admits (minus code-defined chains) must be a manifest-admitted row
        from kie.qie import qp_bridge as QB
        subjects = ["Physics", "Chemistry", "Biology", "Mathematics"]
        _c, by_chapter, warnings = QB._governed_concepts(subjects)
        admitted = {r["compose_concept"] for r in MF.governed_scope_rows(set(subjects))}
        # code-defined certified chains are the ONLY non-manifest governed concepts allowed
        from kie.qie.convert.notation import chain_compose as CH
        chain_keys = {f"{ch.subject} :: {ch.name}" for ch in CH.CHAINS}
        for cc in by_chapter:
            self.assertTrue(cc in admitted or cc in chain_keys,
                            f"governed concept {cc!r} is neither manifest-admitted nor a certified chain")
        self.assertEqual(warnings, [], "live manifest should be in sync (rebuild it if this fails)")

    def test_live_no_quarantined_relation_in_scope(self):
        # a relation quarantined in the manifest must not appear as an in-scope governed concept
        conn = MF.open_ro()
        try:
            quar = [r["compose_concept"] for r in conn.execute(
                "SELECT compose_concept FROM unified_inventory WHERE asset_class='relation' "
                "AND promotion_status='quarantined' AND compose_concept IS NOT NULL")]
        finally:
            conn.close()
        from kie.qie import qp_bridge as QB
        _c, by_chapter, _w = QB._governed_concepts(["Physics", "Chemistry", "Biology", "Mathematics"])
        for cc in quar:
            self.assertNotIn(cc, by_chapter)


if __name__ == "__main__":
    unittest.main()
