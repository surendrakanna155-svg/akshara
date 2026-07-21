"""R1-2 regression lock (audit P0 · C1) — append-only, content-bound, immutable certification records.

The audit's replay probe, reproduced twice: ingest a clean item, certify it, then re-ingest a DIFFERENT stem
under the same candidate id → the row re-promotes to `certified` on the OLD evidence and the certified content
is silently destroyed. Root causes: `INSERT OR REPLACE`, a truncated colliding `_cid`, evidence tables keyed by
candidate_id alone with no content binding, and a `certify_run` that never consulted gate_result or item_hash.

These tests prove the probe now fails LOUDLY at both ends: re-ingest over an existing/certified row raises, and
certify refuses evidence whose item_hash != the candidate's current content. No model calls; in-memory stores.
"""
from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path

from kie.qie.factory import certify as CERT
from kie.qie.factory import corpus as CO
from kie.qie.factory import gates as G


def _spec_row(spec_id="S1", run="R"):
    return {"spec_id": spec_id, "run_id": run, "lane": "STRUCTURED_NUMERIC", "board": "CBSE",
            "exam_profile": "NEET", "class_level": 11, "subject": "Physics", "concept_code": "C1",
            "concept_title": "Linear momentum", "composition": "single", "archetype": "single_step_numerical",
            "question_type": "MCQ", "intended_depth": 1, "intended_difficulty": "easy", "visual_required": 0,
            "created_at": "2026-01-01T00:00:00+00:00"}


def _item(spec_id="S1", stem="An object of mass 3 kg moves at 4 m/s. Find its momentum.", ans="12"):
    return {"spec_id": spec_id, "stem": stem,
            "options": {"a": "7", "b": "12", "c": "1", "d": "9"}, "answer_label": "b", "answer_value": ans,
            "structure": {"givens": {"m": {"value": 3, "unit": "kg"}, "v": {"value": 4, "unit": "m/s"}},
                          "relation": "p = m*v", "solve_for": "p"}}


def _seed_full_evidence(conn, cid, agree=True, judge="accept"):
    """Record a passing gate battery + independent + judge, all content-stamped to the candidate's CURRENT
    item_hash (that is what record_* does). Mirrors a real verify+judge pass without any model call.

    R2 raised the certification bar, so 'full evidence' now also seeds the solution_verified + distractor_verified
    gates (R2-2) and a CROSS-FAMILY judge (judge_family != the candidate's generator_model 'gen', R2-1). The R1
    INVARIANTS being asserted (immutability, append-only, stale-evidence-refused, guarded transitions) are
    unchanged — only the fabricated 'certifiable' fixture is updated to the current bar."""
    CO.record_gates(conn, cid, [
        {"gate": "schema", "ok": True, "severity": G.FATAL, "detail": ""},
        {"gate": "dimensional", "ok": True, "severity": G.QUARANTINE, "detail": ""},
        {"gate": "solution_verified", "ok": True, "severity": G.FATAL, "detail": ""},
        {"gate": "distractor_verified", "ok": True, "severity": G.FATAL, "detail": ""}])
    CO.record_independent(conn, cid, "sympy_relation_solve", "12", "12",
                          "agree" if agree else "disagree", "ok")
    CO.record_judge(conn, cid, "judge", True, {"verdict": judge}, judge_family="human-review")
    conn.commit()


def _certify_one(conn, run="R", spec="S1"):
    conn2 = conn
    CO.save_specs(conn2, [_spec_row(spec, run)])
    CO.ingest(conn2, run, [_item(spec)], "gen", "b1")
    cid = CO._cid(run, spec)
    _seed_full_evidence(conn2, cid)
    m = CERT.certify_run(conn2, run)
    return cid, m


class CollisionFreeIdentity(unittest.TestCase):
    def test_cid_is_collision_free(self):
        # the exact audit collision: two run ids sharing their last 6 chars must NOT collapse to one id
        self.assertNotEqual(CO._cid("prod_jm_math", "SPEC_1"), CO._cid("gen_jm_math", "SPEC_1"))

    def test_cid_is_pure_deterministic(self):
        self.assertEqual(CO._cid("R", "S1"), CO._cid("R", "S1"))
        self.assertTrue(CO._cid("R", "S1").startswith("CAND_"))


class ReplayReingestIsBlocked(unittest.TestCase):
    def test_replay_reingest_is_blocked_and_certified_row_immutable(self):
        conn = CO.open_store(":memory:")
        try:
            cid, m = _certify_one(conn)
            self.assertEqual(m["certified"], 1)
            self.assertEqual(conn.execute("SELECT status FROM candidate WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], CO.CERTIFIED)
            orig = conn.execute("SELECT stem, item_hash FROM candidate WHERE candidate_id=?",
                                (cid,)).fetchone()

            # THE REPLAY: re-ingest a DIFFERENT stem for the SAME (run, spec) — must fail loudly at ingest
            with self.assertRaises(CO.CorpusIntegrityError):
                CO.ingest(conn, "R", [_item("S1", stem="A completely different, tampered question stem.",
                                            ans="999")], "gen", "b2")

            # the certified content is intact — not overwritten
            after = conn.execute("SELECT stem, item_hash FROM candidate WHERE candidate_id=?",
                                 (cid,)).fetchone()
            self.assertEqual(after["stem"], orig["stem"])
            self.assertEqual(after["item_hash"], orig["item_hash"])

            # re-running certify promotes nothing new and does not re-promote the (already certified) row
            m2 = CERT.certify_run(conn, "R")
            self.assertEqual(m2["certified"], 0)
            inv = CO.product_inventory(conn, "R")
            self.assertEqual(len(inv), 1)
            self.assertEqual(inv[0]["stem"], orig["stem"])
        finally:
            conn.close()

    def test_reingest_over_noncertified_row_also_blocked(self):
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "gen", "b1")
            with self.assertRaises(CO.CorpusIntegrityError):
                CO.ingest(conn, "R", [_item(stem="another stem for the same pair")], "gen", "b2")
        finally:
            conn.close()


class StaleEvidenceNeverCertifies(unittest.TestCase):
    def test_stale_evidence_is_quarantined_not_certified(self):
        """Independently of the ingest guard: if a candidate's CURRENT content differs from the item_hash its
        evidence was computed against (the replay, simulated by mutating content directly), certify must refuse
        it — it lands in `stale_evidence`, never `certified`."""
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "gen", "b1")
            cid = CO._cid("R", "S1")
            _seed_full_evidence(conn, cid)                 # evidence bound to item A's hash

            # simulate the replay by mutating the candidate content in place (item_hash now differs)
            new_stem = "A DIFFERENT question the evidence was never computed against."
            new_hash = G.item_hash(new_stem, {"a": "7", "b": "12", "c": "1", "d": "9"}, "12")
            conn.execute("UPDATE candidate SET stem=?, item_hash=? WHERE candidate_id=?",
                         (new_stem, new_hash, cid))
            conn.commit()

            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 0)
            self.assertEqual(m["stale_evidence"], 1)
            self.assertEqual(conn.execute("SELECT status FROM candidate WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], CO.QUARANTINED)
        finally:
            conn.close()

    def test_missing_gates_never_certifies(self):
        # judge accept + ind agree but NO gate battery for this content => cannot certify (gates now consulted)
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "gen", "b1")
            cid = CO._cid("R", "S1")
            CO.record_independent(conn, cid, "sympy", "12", "12", "agree", "ok")
            CO.record_judge(conn, cid, "judge", True, {"verdict": "accept"})
            conn.commit()
            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 0)
            self.assertEqual(m["stale_evidence"], 1)
        finally:
            conn.close()

    def test_quarantine_gate_failure_blocks_certification(self):
        """Defense-in-depth (R1-1 hardening — adversarial-verifier regression): certify independently
        re-derives the gate verdict, so a recorded QUARANTINE gate failure (e.g. an ungrounded relation) for
        this item_hash can NEVER certify — even if the candidate is somehow still in 'candidate' state because
        an upstream status flip was skipped. Previously certify enforced only FATAL, not QUARANTINE."""
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "gen", "b1")
            cid = CO._cid("R", "S1")
            CO.record_gates(conn, cid, [
                {"gate": "schema", "ok": True, "severity": G.FATAL, "detail": ""},
                {"gate": "relation_grounded", "ok": False, "severity": G.QUARANTINE, "detail": "ungrounded"},
            ])
            CO.record_independent(conn, cid, "sympy", "12", "12", "agree", "ok")
            CO.record_judge(conn, cid, "judge", True, {"verdict": "accept"})
            conn.commit()
            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 0, "a recorded QUARANTINE gate failure must never certify")
            self.assertEqual(m["stale_evidence"], 1)
            self.assertEqual(conn.execute("SELECT status FROM candidate WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], CO.QUARANTINED)
        finally:
            conn.close()


class GuardedSetStatus(unittest.TestCase):
    def test_set_status_refuses_to_flip_a_certified_row(self):
        conn = CO.open_store(":memory:")
        try:
            cid, _ = _certify_one(conn)
            # default expected=CANDIDATE — the row is certified, so 0 rows match and it must throw
            with self.assertRaises(CO.CorpusIntegrityError):
                CO.set_status(conn, cid, CO.REJECTED, "tamper")
            self.assertEqual(conn.execute("SELECT status FROM candidate WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], CO.CERTIFIED)
        finally:
            conn.close()

    def test_set_status_wrong_expected_state_throws(self):
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "gen", "b1")
            cid = CO._cid("R", "S1")
            CO.set_status(conn, cid, CO.QUARANTINED, "x")          # candidate -> quarantined (ok)
            with self.assertRaises(CO.CorpusIntegrityError):        # expected CANDIDATE but it's quarantined
                CO.set_status(conn, cid, CO.CERTIFIED, "y")
        finally:
            conn.close()


class EvidenceIsAppendOnly(unittest.TestCase):
    def test_two_attempts_both_persist_and_latest_wins(self):
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "gen", "b1")
            cid = CO._cid("R", "S1")
            CO.record_independent(conn, cid, "sympy", "1", "1", "disagree", "first")
            CO.record_independent(conn, cid, "sympy", "2", "2", "agree", "second")
            CO.record_judge(conn, cid, "judge", True, {"verdict": "reject"})
            CO.record_judge(conn, cid, "judge", True, {"verdict": "accept"})
            conn.commit()
            self.assertEqual(conn.execute("SELECT COUNT(*) FROM independent_answer WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], 2)
            self.assertEqual(conn.execute("SELECT COUNT(*) FROM judge_verdict WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], 2)
            self.assertEqual(conn.execute("SELECT verdict FROM independent_answer_latest WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], "agree")
            self.assertEqual(conn.execute("SELECT verdict FROM judge_verdict_latest WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], "accept")
        finally:
            conn.close()


# ── factory-1 → factory-2 migration (synthetic old-shape DB; the real live-DB copy is verified out of band) ──
_FACTORY1_DDL = """
CREATE TABLE factory_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE generation_spec (spec_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, lane TEXT NOT NULL,
  class_level INTEGER NOT NULL, subject TEXT NOT NULL, composition TEXT NOT NULL, archetype TEXT NOT NULL,
  question_type TEXT NOT NULL, intended_depth INTEGER NOT NULL, intended_difficulty TEXT NOT NULL,
  visual_required INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL);
CREATE TABLE candidate (candidate_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, spec_id TEXT, generator_model TEXT NOT NULL,
  stem TEXT NOT NULL, options TEXT, answer_label TEXT, answer_value TEXT, claimed TEXT, structure TEXT,
  status TEXT NOT NULL DEFAULT 'candidate',
  reject_reason TEXT, item_hash TEXT, stem_norm_hash TEXT, created_at TEXT NOT NULL);
CREATE TABLE gate_result (candidate_id TEXT NOT NULL, gate TEXT NOT NULL, ok INTEGER NOT NULL,
  severity TEXT NOT NULL, detail TEXT, checked_at TEXT NOT NULL, PRIMARY KEY (candidate_id, gate));
CREATE TABLE independent_answer (candidate_id TEXT PRIMARY KEY, method TEXT NOT NULL, solver_answer TEXT,
  generator_answer TEXT, verdict TEXT NOT NULL, detail TEXT, checked_at TEXT NOT NULL);
CREATE TABLE judge_verdict (candidate_id TEXT PRIMARY KEY, judge_model TEXT NOT NULL, independent INTEGER NOT NULL,
  verdict TEXT NOT NULL, well_posed INTEGER, curriculum_ok INTEGER, answer_correct INTEGER, unique_answer INTEGER,
  concepts_real INTEGER, composition_real INTEGER, difficulty_plausible INTEGER, distractors_plausible INTEGER,
  visual_judgement TEXT, reasons TEXT, checked_at TEXT NOT NULL);
CREATE TABLE run_telemetry (run_id TEXT NOT NULL, stage TEXT NOT NULL, model TEXT, batches INTEGER, items INTEGER,
  input_tokens INTEGER, output_tokens INTEGER, wall_seconds REAL, note TEXT, recorded_at TEXT NOT NULL,
  PRIMARY KEY (run_id, stage, model));
"""


class MigrationFactory1ToFactory2(unittest.TestCase):
    def _build_factory1(self, path):
        c = sqlite3.connect(path)
        c.executescript(_FACTORY1_DDL)
        c.execute("INSERT INTO factory_meta VALUES ('schema_version','factory-1')")
        c.execute("INSERT INTO candidate (candidate_id, run_id, spec_id, generator_model, stem, options, "
                  "answer_label, answer_value, structure, status, item_hash, created_at) VALUES "
                  "('CAND_old1','R','S1','gen','A stem','{}','b','12',"
                  "'{\"givens\":{\"m\":{\"value\":3},\"v\":{\"value\":4}},\"relation\":\"p = m*v\",\"solve_for\":\"p\"}',"
                  "'certified','IH_orig','2026-01-01T00:00:00.000+00:00')")
        c.execute("INSERT INTO gate_result VALUES ('CAND_old1','schema',1,'fatal','ok','2026-01-01T01:00:00.000+00:00')")
        c.execute("INSERT INTO independent_answer VALUES ('CAND_old1','sympy','12','12','agree','ok','2026-01-01T01:00:00.000+00:00')")
        c.execute("INSERT INTO judge_verdict (candidate_id, judge_model, independent, verdict, checked_at) "
                  "VALUES ('CAND_old1','judge',1,'accept','2026-01-01T01:00:00.000+00:00')")
        c.commit()
        c.close()

    def test_migration_upgrades_shape_and_preserves_counts(self):
        with tempfile.TemporaryDirectory() as d:
            path = str(Path(d) / "factory1.db")
            self._build_factory1(path)

            conn = sqlite3.connect(path)
            conn.row_factory = sqlite3.Row
            try:
                self.assertFalse(CO._has_col(conn, "gate_result", "item_hash"))   # old shape
                changed = CO.migrate_appendonly(conn)
                # the real path (open_store/migrate_db) runs the WHOLE forward chain before executescript, so the
                # factory-5 schema's partial UNIQUE index (which references certification_class) resolves. Mirror
                # it: r2 adds the R2 columns, r2_3 the provenance columns, r3 the bank-dedup index.
                CO.migrate_r2(conn)
                CO.migrate_r2_3(conn)
                CO.migrate_r3(conn)
                conn.executescript(CO.SCHEMA_PATH.read_text())
                conn.commit()
                self.assertTrue(changed)
                # new shape
                self.assertTrue(CO._has_col(conn, "gate_result", "item_hash"))
                self.assertTrue(CO._has_col(conn, "gate_result", "id"))
                self.assertTrue(CO._has_col(conn, "candidate", "relation_waiver"))
                # counts preserved; item_hash backfilled from candidate's current item_hash
                self.assertEqual(conn.execute("SELECT COUNT(*) FROM gate_result").fetchone()[0], 1)
                self.assertEqual(conn.execute("SELECT item_hash FROM gate_result").fetchone()[0], "IH_orig")
                self.assertEqual(conn.execute("SELECT COUNT(*) FROM candidate WHERE status='certified'")
                                 .fetchone()[0], 1)
                # views exist and resolve
                self.assertEqual(conn.execute("SELECT verdict FROM independent_answer_latest").fetchone()[0],
                                 "agree")
                # idempotent
                self.assertFalse(CO.migrate_appendonly(conn))
            finally:
                conn.close()

    def test_migration_certified_row_still_certifies_after_upgrade(self):
        # the migrated certified row must still satisfy the NEW certify preconditions when re-evaluated as a
        # candidate (freshness + item_hash binding both hold, since evidence postdates creation). Under R2 the
        # bar additionally needs the solution/distractor gates and a cross-family judge; seed them (all bound to
        # the migrated row's item_hash) to prove the full R2 chain certifies a legacy row after upgrade.
        with tempfile.TemporaryDirectory() as d:
            path = str(Path(d) / "factory1.db")
            self._build_factory1(path)
            conn = sqlite3.connect(path)
            conn.row_factory = sqlite3.Row
            try:
                CO.migrate_appendonly(conn)                       # factory-1 -> factory-2
                CO.migrate_r2(conn)                               # factory-2 -> factory-3 (backfills gen family)
                CO.migrate_r3(conn, role=CO.ROLE_PRODUCTION,      # factory-4 -> factory-5: dedup index + stamp
                              explicit_role=True)                 #   this migrated store as the production bank
                conn.executescript(CO.SCHEMA_PATH.read_text())
                # flip the migrated row back to candidate to dry-run the new predicate against its own evidence
                conn.execute("UPDATE candidate SET status='candidate' WHERE candidate_id='CAND_old1'")
                # R2 evidence, content-bound to the migrated row's item_hash (IH_orig) + a cross-family judge
                CO.record_gates(conn, "CAND_old1", [
                    {"gate": "solution_verified", "ok": True, "severity": G.FATAL, "detail": ""},
                    {"gate": "distractor_verified", "ok": True, "severity": G.FATAL, "detail": ""}])
                conn.execute("UPDATE judge_verdict SET judge_family='human-review' WHERE candidate_id='CAND_old1'")
                conn.commit()
                m = CERT.certify_run(conn, "R")
                self.assertEqual(m["certified"], 1, "migrated certified row must still meet the new preconditions")
                self.assertEqual(len(CO.product_inventory(conn, "R")), 1)
            finally:
                conn.close()


if __name__ == "__main__":
    unittest.main()
