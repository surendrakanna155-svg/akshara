"""R3-1/R3-2/R3-6 store-governance + bank-dedup regression locks (audit P1 · [C8]/[C12] + #assessment-6,
#product-6, #ai-systems-9, #qa-reliability-4, #security-governance-9).

Permanent invariants (in-memory / tmp stores, ZERO model calls), plus the factory-5 migration and the
run-scoped excision/recall tooling:

  * RI-6 — exactly ONE product-visible certified store. product_inventory() / certified_bank() refuse any
           store that is not stamped role='production_bank'; a trial or un-stamped store fails CLOSED and can
           NEVER satisfy a product read, even when it holds status='certified' rows.
  * RI-9 — no NEW certification whose stem_norm_hash (or item_hash) matches a prior PRODUCT-certified row in the
           target bank. Enforced at three layers: validate_run seeds the dedup gate from all prior certified
           rows; certify quarantines a bank-duplicate; the partial UNIQUE index is the hard DB backstop.
  * factory-4 -> factory-5 migration is additive/idempotent, stamps the role, demotes a trial store's certified
           rows to 'trial_certified', closes forever-'candidate' rows to 'expired_unjudged', and NEVER changes
           the certified STATUS count.
  * R3-6 excision — a guarded, audited run-scoped recall that preserves prior state (never overwrites
           reject_reason) and removes rows from product visibility.
  * R3-2 blueprint_store no longer re-parents a re-issued spec's provenance to a new run.
"""
from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path

from kie import config
from kie.qie.factory import certify as CERT
from kie.qie.factory import corpus as CO
from kie.qie.factory import gates as G
from kie.qie.factory import judge as JUDGE
from kie.qie.factory import solutions as SOL
from kie.qie.knowledge import blueprint_store as BS
from kie.qie.remediation import excise_run as EX
from kie.qie.remediation import migrate_factory_r3 as MIG

QIE_STORE = config.KIE_HOME / "qie.db"


# ── fixtures: a clean structured-numeric item that earns the full R2 evidence chain ─────────────────────
def _spec_row(spec_id, run, cls=9, subject="Physics"):
    return {"spec_id": spec_id, "run_id": run, "lane": "STRUCTURED_NUMERIC", "board": "CBSE",
            "exam_profile": "NEET", "class_level": cls, "subject": subject, "concept_code": "C1",
            "concept_title": "Newton's second law", "composition": "single",
            "archetype": "single_step_numerical", "question_type": "MCQ", "intended_depth": 1,
            "intended_difficulty": "easy", "visual_required": 0, "created_at": "2026-01-01T00:00:00+00:00"}


def _item(spec_id, stem=None):
    return {"spec_id": spec_id,
            "stem": stem or "A net force of 12 N acts on a 3 kg block. Find the acceleration.",
            "options": {"a": "36 m/s^2", "b": "4 m/s^2", "c": "0.25 m/s^2", "d": "9 m/s^2"},
            "answer_label": "b", "answer_value": "4",
            "claimed": {"concepts": ["Newton's second law"], "archetype": "single_step_numerical",
                        "depth": 1, "difficulty": "easy", "composition": "single"},
            "structure": {"givens": {"F": {"value": 12, "unit": "N"}, "m": {"value": 3, "unit": "kg"},
                                     "a": {"value": None, "unit": "m/s**2"}},
                          "relation": "a = F/m", "solve_for": "a", "answer_unit": "m/s**2"}}


_DISTRACTORS = {"a": {"misconception": "F*m", "mis_relation": "a = F*m"},
                "c": {"misconception": "m/F", "mis_relation": "a = m/F"},
                "d": {"misconception": "F-m", "mis_relation": "a = F - m"}}


def _certify_one(conn, run, spec, stem=None, judge_family="human-review", cls=9, subject="Physics"):
    """Take one candidate through the full R2 chain (gates + independent + solution/distractor + cross-family
    judge) and certify it. Returns (candidate_id, certify_metrics)."""
    CO.save_specs(conn, [_spec_row(spec, run, cls=cls, subject=subject)])
    CO.ingest(conn, run, [_item(spec, stem)], "generator-agent", "b1")
    cid = CO._cid(run, spec)
    CO.record_gates(conn, cid, [{"gate": "schema", "ok": True, "severity": G.FATAL, "detail": ""},
                                {"gate": "dimensional", "ok": True, "severity": G.QUARANTINE, "detail": ""},
                                {"gate": "relation_grounded", "ok": True, "severity": G.QUARANTINE, "detail": ""}])
    CO.record_independent(conn, cid, "sympy_relation_solve", "4", "4", "agree", "ok")
    SOL.ingest(conn, run, [{"candidate_id": cid, "dispute": False,
                            "solution": {"steps": ["a = F/m = 12/3"], "final": "4"},
                            "distractor_rationale": _DISTRACTORS}])
    JUDGE.ingest(conn, run, [{"candidate_id": cid, "verdict": "accept", "chosen_label": "b"}],
                 "examiner-model", judge_family=judge_family, require_controls=False)
    m = CERT.certify_run(conn, run)
    return cid, m


# ── RI-6 · exactly one product-visible certified store ─────────────────────────────────────────────────
class RI6OnlyProductionBankServesProduct(unittest.TestCase):
    def test_production_bank_serves_certified(self):
        conn = CO.open_store(":memory:", role=CO.ROLE_PRODUCTION)
        try:
            cid, m = _certify_one(conn, "R", "S1")
            self.assertEqual(m["certified"], 1)
            self.assertEqual(CO.store_role(conn), CO.ROLE_PRODUCTION)
            self.assertEqual({r["candidate_id"] for r in CO.product_inventory(conn, "R")}, {cid})
            self.assertEqual({r["candidate_id"] for r in CO.certified_bank(conn)}, {cid})
        finally:
            conn.close()

    def test_trial_store_can_never_satisfy_product_inventory(self):
        # a store stamped trial_corpus, holding a genuinely certified row, still serves ZERO product (RI-6).
        conn = CO.open_store(":memory:", role=CO.ROLE_TRIAL)
        try:
            _certify_one(conn, "R", "S1")
            self.assertEqual(conn.execute("SELECT COUNT(*) FROM candidate WHERE status='certified'")
                             .fetchone()[0], 1)
            with self.assertRaises(CO.CorpusIntegrityError):
                CO.product_inventory(conn, "R")
            with self.assertRaises(CO.CorpusIntegrityError):
                CO.certified_bank(conn)
        finally:
            conn.close()

    def test_unstamped_store_is_refused_fail_closed(self):
        # a raw, un-migrated store (no role) — product reads refuse fail-closed.
        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        conn.executescript(CO.SCHEMA_PATH.read_text())
        try:
            self.assertIsNone(CO.store_role(conn))
            with self.assertRaises(CO.CorpusIntegrityError):
                CO.product_inventory(conn, "R")
        finally:
            conn.close()

    def test_role_cannot_be_silently_flipped_to_production(self):
        conn = CO.open_store(":memory:", role=CO.ROLE_TRIAL)
        try:
            with self.assertRaises(CO.CorpusIntegrityError):
                CO._stamp_role(conn, CO.ROLE_PRODUCTION, explicit=True)   # a trial corpus must never be promoted
        finally:
            conn.close()


# ── RI-9 · no duplicate product-certification across runs in the same bank ──────────────────────────────
class RI9BankLevelDedup(unittest.TestCase):
    def test_certify_quarantines_cross_run_duplicate_of_certified(self):
        conn = CO.open_store(":memory:", role=CO.ROLE_PRODUCTION)
        try:
            cid1, m1 = _certify_one(conn, "R1", "S1")
            self.assertEqual(m1["certified"], 1)
            # a SECOND run proposes the identical question — certify refuses to double-certify it (RI-9).
            cid2, m2 = _certify_one(conn, "R2", "S2")
            self.assertEqual(m2["certified"], 0)
            self.assertEqual(m2["duplicate_of_certified"], 1)
            self.assertEqual(conn.execute("SELECT status FROM candidate WHERE candidate_id=?",
                                          (cid2,)).fetchone()[0], CO.QUARANTINED)
            # the bank still holds exactly the one original certified question.
            self.assertEqual({r["candidate_id"] for r in CO.certified_bank(conn)}, {cid1})
        finally:
            conn.close()

    def test_partial_unique_index_is_the_hard_backstop(self):
        # bypass the certify pre-check: force a direct second product-certification of identical content — the
        # partial UNIQUE index rejects it (surfaced as CorpusIntegrityError).
        conn = CO.open_store(":memory:", role=CO.ROLE_PRODUCTION)
        try:
            CO.save_specs(conn, [_spec_row("S1", "R1"), _spec_row("S2", "R2")])
            CO.ingest(conn, "R1", [_item("S1")], "gen", "b1")
            CO.ingest(conn, "R2", [_item("S2")], "gen", "b1")   # identical stem/options/answer -> same hashes
            c1, c2 = CO._cid("R1", "S1"), CO._cid("R2", "S2")
            CO.mark_certified(conn, c1, CO.EVIDENCE_SYMPY, CO.CERT_CERTIFIED, "x")
            with self.assertRaises(CO.CorpusIntegrityError):
                CO.mark_certified(conn, c2, CO.EVIDENCE_SYMPY, CO.CERT_CERTIFIED, "x")
        finally:
            conn.close()

    def test_prior_certified_dedup_seeds_and_gate_fatals_a_duplicate(self):
        # the dedup-at-gate seed (used by validate_run) feeds duplicate_exact so a re-issued stem FATAL-fails.
        conn = CO.open_store(":memory:", role=CO.ROLE_PRODUCTION)
        try:
            _certify_one(conn, "R1", "S1")
            seen_norm, corpus = CO.prior_certified_dedup(conn)
            self.assertEqual(len(seen_norm), 1)
            self.assertIn((9, "Physics"), corpus)
            dup = _item("S2")   # identical stem
            ctx = {"spec": {"lane": "STRUCTURED_NUMERIC", "subject": "Physics"}, "seen_norm": seen_norm,
                   "corpus": corpus[(9, "Physics")], "certified_relations": {}, "certified_relation_eqs": []}
            by = {g["gate"]: g for g in G.run_gates(dup, ctx)}
            self.assertFalse(by["duplicate_exact"]["ok"], "a stem already in the bank must FATAL duplicate_exact")
            self.assertEqual(by["duplicate_exact"]["severity"], G.FATAL)
        finally:
            conn.close()

    @unittest.skipUnless(QIE_STORE.exists(), "qie store not present (gitignored / local only)")
    def test_end_to_end_second_run_cannot_recertify(self):
        # full pipeline: run1 certifies; run2's validate_run (seeded from the bank) rejects the duplicate before
        # it can be certified. Uses the real governed-relation registry (qie.db) for the gate battery/controls.
        from kie.qie.factory import validate_run as VR
        conn = CO.open_store(":memory:", role=CO.ROLE_PRODUCTION)
        qconn = sqlite3.connect(f"file:{QIE_STORE}?mode=ro", uri=True)
        qconn.row_factory = sqlite3.Row
        try:
            cid1, m1 = _certify_one(conn, "R1", "S1")
            self.assertEqual(m1["certified"], 1)
            CO.save_specs(conn, [_spec_row("S2", "R2")])
            CO.ingest(conn, "R2", [_item("S2")], "gen", "b1")
            VR.run(conn, qconn, "R2")     # seeded from the bank -> the duplicate is rejected at the gate
            self.assertEqual(conn.execute("SELECT status FROM candidate WHERE candidate_id=?",
                                          (CO._cid("R2", "S2"),)).fetchone()[0], CO.REJECTED)
            self.assertEqual({r["candidate_id"] for r in CO.certified_bank(conn)}, {cid1})
        finally:
            conn.close()
            qconn.close()


# ── factory-4 -> factory-5 migration (role stamp + trial demotion + run-closure) ────────────────────────
class Factory4To5Migration(unittest.TestCase):
    def _build_store(self, path, role_stamp=False):
        """A factory-5-shaped store with 1 certified (cert_class NULL) + 2 forever-candidate rows and NO role
        stamp — the pre-migration state of the live trial corpus in miniature."""
        conn = CO.open_store(str(path), role=(CO.ROLE_PRODUCTION if role_stamp else None))
        CO.save_specs(conn, [_spec_row("S1", "R"), _spec_row("S2", "R"), _spec_row("S3", "R")])
        CO.ingest(conn, "R", [_item("S1", "Certified trial stem one."),
                              _item("S2", "Forever candidate stem two."),
                              _item("S3", "Forever candidate stem three.")], "gen", "b1")
        # promote S1 the low-level way (no cert_class) to mirror a legacy trial 'certified' row
        conn.execute("UPDATE candidate SET status='certified' WHERE candidate_id=?", (CO._cid("R", "S1"),))
        conn.commit()
        conn.close()

    def test_trial_migration_stamps_role_demotes_and_closes(self):
        with tempfile.TemporaryDirectory() as d:
            old_home = config.KIE_HOME
            config.KIE_HOME = Path(d)
            try:
                path = Path(d) / "factory_corpus.db"     # filename -> inferred trial role + demotion
                self._build_store(path)
                before = MIG.migrate(path, check=True)["shape"]
                self.assertIsNone(before["role"])
                self.assertEqual(before["status_counts"].get("certified"), 1)
                self.assertEqual(before["status_counts"].get("candidate"), 2)

                out = MIG.migrate(path)                    # apply (defaults: trial role + demote)
                after = out["shape_after"]
                self.assertEqual(after["schema_version"], "factory-5")
                self.assertEqual(after["role"], CO.ROLE_TRIAL)
                self.assertTrue(after["has_dedup_indexes"])
                # certified STATUS count unchanged; product-visibility 0; the 1 cert row -> trial_certified
                self.assertEqual(out["before"].get("certified"), out["after"].get("certified"))
                self.assertEqual(after["product_visible_rows"], 0)
                self.assertEqual(after["trial_certified_rows"], 1)
                # the 2 forever-candidates -> expired_unjudged (with a status_audit trail)
                self.assertEqual(after["expired_unjudged_rows"], 2)
                self.assertEqual(after["status_counts"].get("candidate", 0), 0)
                conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
                self.assertEqual(conn.execute("SELECT COUNT(*) FROM status_audit WHERE to_status='expired_unjudged'")
                                 .fetchone()[0], 2)
                conn.close()
                # idempotent: a second apply changes nothing material
                out2 = MIG.migrate(path)
                self.assertEqual(out2["after"].get("certified"), out["after"].get("certified"))
                self.assertEqual(out2["shape_after"]["expired_unjudged_rows"], 2)
            finally:
                config.KIE_HOME = old_home

    def test_production_migration_stamps_role_without_demotion(self):
        with tempfile.TemporaryDirectory() as d:
            old_home = config.KIE_HOME
            config.KIE_HOME = Path(d)
            try:
                path = Path(d) / "qpl_question_bank.db"   # filename -> inferred production role, NO demotion
                self._build_store(path)
                out = MIG.migrate(path)
                after = out["shape_after"]
                self.assertEqual(after["role"], CO.ROLE_PRODUCTION)
                self.assertEqual(after["trial_certified_rows"], 0)          # never demoted in a production bank
                self.assertEqual(after["status_counts"].get("candidate"), 2)  # never closed in a production bank
                self.assertEqual(out["before"].get("certified"), out["after"].get("certified"))
            finally:
                config.KIE_HOME = old_home


# ── R3-6 · run-scoped excision / recall ─────────────────────────────────────────────────────────────────
class ExciseRunRecall(unittest.TestCase):
    def _store(self, d):
        old_home = config.KIE_HOME
        config.KIE_HOME = Path(d)
        path = Path(d) / "qpl_question_bank.db"
        conn = CO.open_store(str(path), role=CO.ROLE_PRODUCTION)
        cid, m = _certify_one(conn, "BAD_RUN", "S1")
        self.assertEqual(m["certified"], 1)
        conn.close()
        return old_home, path, cid

    def test_dry_run_changes_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            old_home, path, cid = self._store(d)
            try:
                out = EX.excise_run(path, "BAD_RUN", "recall-x", apply=False)
                self.assertEqual(out["eligible"], 1)
                self.assertEqual(out["excised"], 0)
                conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
                self.assertEqual(conn.execute("SELECT status FROM candidate WHERE candidate_id=?",
                                              (cid,)).fetchone()[0], CO.CERTIFIED)
                conn.close()
            finally:
                config.KIE_HOME = old_home

    def test_apply_excises_guarded_preserves_history_and_removes_from_product(self):
        with tempfile.TemporaryDirectory() as d:
            old_home, path, cid = self._store(d)
            try:
                # record a prior reject_reason substitute: the certified row's reject_reason holds the cert reason
                conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
                prior_reason = conn.execute("SELECT reject_reason FROM candidate WHERE candidate_id=?",
                                            (cid,)).fetchone()[0]
                conn.close()
                out = EX.excise_run(path, "BAD_RUN", "recall-2026-07-21", apply=True)
                self.assertEqual(out["excised"], 1)
                conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
                conn.row_factory = sqlite3.Row
                row = conn.execute("SELECT status, reject_reason FROM candidate WHERE candidate_id=?",
                                   (cid,)).fetchone()
                self.assertEqual(row["status"], EX.EXCISED)
                self.assertEqual(row["reject_reason"], prior_reason, "reject_reason history must be preserved")
                aud = conn.execute("SELECT from_status, to_status, reason FROM status_audit "
                                   "WHERE entity_id=?", (cid,)).fetchone()
                self.assertEqual((aud["from_status"], aud["to_status"], aud["reason"]),
                                 (CO.CERTIFIED, EX.EXCISED, "recall-2026-07-21"))
                self.assertEqual(CO.store_role(conn), CO.ROLE_PRODUCTION)
                self.assertEqual(len(CO.certified_bank(conn)), 0, "an excised row is not product-visible")
                conn.close()
                # idempotent: nothing left to excise
                self.assertEqual(EX.excise_run(path, "BAD_RUN", "recall-2026-07-21", apply=True)["excised"], 0)
            finally:
                config.KIE_HOME = old_home

    def test_apply_requires_a_reason(self):
        with tempfile.TemporaryDirectory() as d:
            old_home, path, cid = self._store(d)
            try:
                with self.assertRaises(ValueError):
                    EX.excise_run(path, "BAD_RUN", "", apply=True)
            finally:
                config.KIE_HOME = old_home


# ── R3-2 · blueprint_store no longer re-parents a re-issued spec ────────────────────────────────────────
class BlueprintNoReparent(unittest.TestCase):
    def _bp(self, run):
        return {"spec_id": "SPEC_shared", "blueprint_id": "SPEC_shared", "run_id": run,
                "lane": "STRUCTURED_NUMERIC", "exam": "NEET", "class_level": 9, "subject": "Physics",
                "chapter_id": "CH1", "chapter_title": "Laws of Motion", "concept_id": "C1",
                "concept_name": "Newton's second law", "composition": "single",
                "archetype": "single_step_numerical", "question_type": "MCQ", "reasoning_depth": 1,
                "difficulty": "easy", "target_difficulty": "easy", "blueprint_fingerprint": "FP1",
                "planner_evidence": {"foundation_version": "v1.5", "examdna_version": "e1"}}

    def test_reissued_spec_keeps_original_run_provenance(self):
        conn = CO.open_store(":memory:", role=CO.ROLE_PRODUCTION)
        try:
            BS.save_blueprints(conn, [self._bp("RUN_A")])
            BS.save_blueprints(conn, [self._bp("RUN_B")])   # SAME content-derived spec_id, re-issued in a new run
            rows = conn.execute("SELECT run_id FROM generation_spec WHERE spec_id='SPEC_shared'").fetchall()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["run_id"], "RUN_A", "a re-issued spec must NOT be re-parented to the new run")
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
