"""R2-3 regression locks — real model/actor provenance + full-stage telemetry (audit [C10], the R2 slice of RI-8).

Permanent invariants, built on the R1/R2 pattern (in-memory / tmp stores, ZERO model calls):

  * Ingest through the model-stage paths REJECTS a payload with no provenance or a BANNED placeholder id
    ('generator-agent'/'judge-agent'/…) — fail-closed, so an anonymous 'agent' can never again be stamped on a
    stored candidate/verdict.
  * Every model-stage row records a REAL model id + version + prompt sha256 + actor; `payload_sha256` is
    COMPUTED inside ingest over the exact stored bytes (never caller-supplied), and CONTRACT_VERSION is persisted.
  * A run cannot be certified (production path) without the mandatory generation + judge telemetry rows.
  * The factory-3 → factory-4 migration is additive + idempotent and never promotes/demotes.
  * The build lane can populate ki_run (the trail the audit found empty), and the stage ledger is append-only
    with a latest-status view.

The real cross-family/human judge + Opus generator remain DEFERRED ACTORS (no API layer — R4-2); the ENFORCEMENT
lands here today, and a legacy row without provenance stays product-invisible.
"""
from __future__ import annotations

import sqlite3
import tempfile
import unittest
from pathlib import Path

from kie import config
from kie.qie.factory import certify as CERT
from kie.qie.factory import corpus as CO
from kie.qie.factory import plan as PLAN
from kie.qie.factory import run_generation as G
from kie.qie.factory import solutions as SOL
from kie.qie.factory import gates as GATES
from kie.qie.knowledge import schema as SC


# ── fixtures ──────────────────────────────────────────────────────────────────────────────────────
def _spec_row(spec_id="S1", run="R"):
    return {"spec_id": spec_id, "run_id": run, "lane": "STRUCTURED_NUMERIC", "board": "CBSE",
            "exam_profile": "NEET", "class_level": 9, "subject": "Physics", "concept_code": "C1",
            "concept_title": "Newton's second law", "composition": "single",
            "archetype": "single_step_numerical", "question_type": "MCQ", "intended_depth": 1,
            "intended_difficulty": "easy", "visual_required": 0, "created_at": "2026-01-01T00:00:00+00:00"}


def _item(spec_id="S1"):
    return {"spec_id": spec_id,
            "stem": "A net force of 12 N acts on a 3 kg block. Find the acceleration.",
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


def _gen_prov(**over):
    # includes contract_version so it works both through G.ingest_candidates (which would default it) and via
    # a direct CO.ingest fixture call (which does not)
    p = {"model": "claude-opus-4-8", "model_version": "claude-opus-4-8[1m]",
         "prompt_sha256": PLAN.brief_sha256("gen brief"), "actor": "orchestrator",
         "contract_version": PLAN.CONTRACT_VERSION}
    p.update(over)
    return p


def _judge_prov(**over):
    p = {"model": "human-examiner", "model_version": "human-examiner-v1",
         "prompt_sha256": PLAN.brief_sha256("judge brief"), "actor": "human:surendra",
         "judge_family": "human-review"}
    p.update(over)
    return p


def _seed_full_chain(conn, run="R", spec="S1", with_telemetry=False):
    """Build a certifiable candidate WITHOUT qie.db: gates + independent + the real solution stage + a
    cross-family judge, all content-bound. Provenance is stamped via the low-level CO.ingest bundle. Optionally
    write the generation+judge telemetry rows (so we can exercise the mandatory-telemetry precondition)."""
    CO.save_specs(conn, [_spec_row(spec, run)])
    CO.ingest(conn, run, [_item(spec)], _gen_prov()["model"], "b1", provenance=_gen_prov())
    cid = CO._cid(run, spec)
    CO.record_gates(conn, cid, [
        {"gate": "schema", "ok": True, "severity": GATES.FATAL, "detail": ""},
        {"gate": "dimensional", "ok": True, "severity": GATES.QUARANTINE, "detail": ""},
        {"gate": "relation_grounded", "ok": True, "severity": GATES.QUARANTINE, "detail": ""}])
    CO.record_independent(conn, cid, "sympy_relation_solve", "4", "4", "agree", "ok")
    SOL.ingest(conn, run, [{"candidate_id": cid, "dispute": False,
                            "solution": {"steps": ["a = F/m = 12/3"], "final": "4"},
                            "distractor_rationale": _DISTRACTORS}])
    CO.record_judge(conn, cid, "human-examiner", True, {"verdict": "accept", "answer_correct": True},
                    judge_family="human-review", provenance=_judge_prov())
    if with_telemetry:
        CO.telemetry(conn, run, "generation", "claude-opus-4-8", actor="orchestrator", items=1, wall_seconds=1.0)
        CO.telemetry(conn, run, "judge", "human-examiner", actor="human:surendra", items=1, wall_seconds=0.5)
    conn.commit()
    return cid


# ── (1)(2) fail-closed ingest ───────────────────────────────────────────────────────────────────
class IngestRejectsUnprovenanced(unittest.TestCase):
    def _prep(self, conn):
        CO.save_specs(conn, [_spec_row()])

    def test_missing_provenance_is_refused_and_names_the_fields(self):
        conn = CO.open_store(":memory:")
        try:
            self._prep(conn)
            with self.assertRaises(CO.CorpusIntegrityError) as ctx:
                G.ingest_candidates(conn, "R", [_item()], {})
            msg = str(ctx.exception)
            for f in ("model", "model_version", "prompt_sha256", "actor"):
                self.assertIn(f, msg, f"the refusal must name the missing field {f!r}")
            self.assertEqual(conn.execute("SELECT COUNT(*) FROM candidate").fetchone()[0], 0)
        finally:
            conn.close()

    def test_placeholder_generator_id_is_banned(self):
        conn = CO.open_store(":memory:")
        try:
            self._prep(conn)
            for bad in ("generator-agent", "generator-model", "agent", "orchestrator-review"):
                with self.assertRaises(CO.CorpusIntegrityError):
                    G.ingest_candidates(conn, "R", [_item()], _gen_prov(model=bad))
            self.assertEqual(conn.execute("SELECT COUNT(*) FROM candidate").fetchone()[0], 0)
        finally:
            conn.close()

    def test_placeholder_judge_id_is_banned(self):
        conn = CO.open_store(":memory:")
        try:
            _seed_full_chain(conn)          # a candidate exists to judge
            for bad in ("judge-agent", "judge-model", "examiner-model"):
                with self.assertRaises(CO.CorpusIntegrityError):
                    G.ingest_judgements(conn, "R", [{"candidate_id": CO._cid("R", "S1"),
                                                     "verdict": "accept", "chosen_label": "b"}],
                                        _judge_prov(model=bad))
        finally:
            conn.close()

    def test_missing_judge_provenance_is_refused(self):
        conn = CO.open_store(":memory:")
        try:
            _seed_full_chain(conn)
            with self.assertRaises(CO.CorpusIntegrityError):
                G.ingest_judgements(conn, "R", [{"candidate_id": CO._cid("R", "S1"),
                                                 "verdict": "accept", "chosen_label": "b"}], {})
        finally:
            conn.close()


# ── (3)(4) provenance persisted + correct ─────────────────────────────────────────────────────────
class ProvenancePersisted(unittest.TestCase):
    def test_generation_provenance_and_computed_payload_sha(self):
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            items = [_item()]
            G.ingest_candidates(conn, "R", items, _gen_prov())
            row = conn.execute("SELECT model_version, prompt_sha256, payload_sha256, generator_actor, "
                               "contract_version FROM candidate WHERE candidate_id=?",
                               (CO._cid("R", "S1"),)).fetchone()
            self.assertEqual(row["model_version"], "claude-opus-4-8[1m]")
            self.assertEqual(row["prompt_sha256"], _gen_prov()["prompt_sha256"])
            self.assertEqual(row["generator_actor"], "orchestrator")
            self.assertEqual(row["contract_version"], PLAN.CONTRACT_VERSION)   # persisted (D2)
            # payload_sha256 is COMPUTED over the exact stored batch, not caller-supplied
            self.assertEqual(row["payload_sha256"], CO.payload_sha256(items))
            self.assertTrue(row["payload_sha256"])
        finally:
            conn.close()

    def test_judge_provenance_persisted_with_computed_payload_sha(self):
        conn = CO.open_store(":memory:")
        try:
            _seed_full_chain(conn)
            payload = [{"candidate_id": CO._cid("R", "S1"), "verdict": "accept", "chosen_label": "b"}]
            G.ingest_judgements(conn, "R", payload, _judge_prov())
            row = conn.execute("SELECT model_version, prompt_sha256, payload_sha256, judge_actor "
                               "FROM judge_verdict_latest WHERE candidate_id=?",
                               (CO._cid("R", "S1"),)).fetchone()
            self.assertEqual(row["model_version"], "human-examiner-v1")
            self.assertEqual(row["prompt_sha256"], _judge_prov()["prompt_sha256"])
            self.assertEqual(row["judge_actor"], "human:surendra")
            self.assertEqual(row["payload_sha256"], CO.payload_sha256(payload))
        finally:
            conn.close()

    def test_legacy_low_level_ingest_leaves_provenance_null(self):
        # a low-level caller that passes no provenance persists NULLs (honest null) — never a fabricated value
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "gen", "b1")      # no provenance bundle
            row = conn.execute("SELECT model_version, generator_actor, payload_sha256 FROM candidate "
                               "WHERE candidate_id=?", (CO._cid("R", "S1"),)).fetchone()
            self.assertIsNone(row["model_version"])
            self.assertIsNone(row["generator_actor"])
            self.assertIsNone(row["payload_sha256"])
        finally:
            conn.close()


# ── (5)(6) mandatory telemetry ────────────────────────────────────────────────────────────────────
class MandatoryTelemetry(unittest.TestCase):
    def test_certify_without_telemetry_is_refused_but_default_path_unaffected(self):
        conn = CO.open_store(":memory:")
        try:
            _seed_full_chain(conn, with_telemetry=False)
            # production path: require_telemetry=True refuses a run with no generation/judge telemetry
            with self.assertRaises(CO.CorpusIntegrityError):
                CERT.certify_run(conn, "R", require_telemetry=True)
            # the precondition fires BEFORE the promotion loop, so the candidate is untouched: the full chain is
            # otherwise complete and certifies under the default (low-level) path
            self.assertEqual(CERT.certify_run(conn, "R")["certified"], 1)
        finally:
            conn.close()

    def test_certify_with_telemetry_certifies(self):
        conn = CO.open_store(":memory:")
        try:
            _seed_full_chain(conn, with_telemetry=True)
            self.assertEqual(CERT.certify_run(conn, "R", require_telemetry=True)["certified"], 1)
            self.assertEqual(len(CO.product_inventory(conn, "R")), 1)
        finally:
            conn.close()

    def test_placeholder_telemetry_is_refused(self):
        conn = CO.open_store(":memory:")
        try:
            _seed_full_chain(conn, with_telemetry=False)
            CO.telemetry(conn, "R", "generation", "generator-agent", actor="agent", items=1)  # placeholder
            CO.telemetry(conn, "R", "judge", "human-examiner", actor="human:surendra", items=1)
            with self.assertRaises(CO.CorpusIntegrityError):
                CERT.certify_run(conn, "R", require_telemetry=True)
        finally:
            conn.close()

    def test_ingest_paths_write_generation_and_judge_telemetry(self):
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            G.ingest_candidates(conn, "R", [_item()], _gen_prov())
            G.ingest_judgements(conn, "R", [{"candidate_id": CO._cid("R", "S1"),
                                             "verdict": "accept", "chosen_label": "b"}], _judge_prov())
            for stage, model, actor in (("generation", "claude-opus-4-8", "orchestrator"),
                                        ("judge", "human-examiner", "human:surendra")):
                row = conn.execute("SELECT model, actor FROM run_telemetry WHERE run_id='R' AND stage=?",
                                   (stage,)).fetchone()
                self.assertIsNotNone(row, f"missing {stage} telemetry row")
                self.assertEqual(row["model"], model)
                self.assertEqual(row["actor"], actor)
            # and require_stage_telemetry is satisfied
            CO.require_stage_telemetry(conn, "R", ("generation", "judge"))
        finally:
            conn.close()


# ── (7) factory-3 → factory-4 migration ─────────────────────────────────────────────────────────
_FACTORY3_NO_R2_3_DDL = """
CREATE TABLE candidate (candidate_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, spec_id TEXT,
  generator_model TEXT NOT NULL, generator_family TEXT, evidence_class TEXT, certification_class TEXT,
  earned_depth INTEGER, computed_archetype TEXT, stem TEXT NOT NULL, options TEXT, answer_label TEXT,
  status TEXT NOT NULL DEFAULT 'candidate', item_hash TEXT, created_at TEXT NOT NULL);
CREATE TABLE judge_verdict (id INTEGER PRIMARY KEY AUTOINCREMENT, candidate_id TEXT NOT NULL, item_hash TEXT,
  judge_model TEXT NOT NULL, judge_family TEXT, independent INTEGER NOT NULL, verdict TEXT NOT NULL,
  checked_at TEXT);
CREATE TABLE gate_result (id INTEGER PRIMARY KEY AUTOINCREMENT, candidate_id TEXT NOT NULL, item_hash TEXT,
  gate TEXT NOT NULL, ok INTEGER NOT NULL, severity TEXT NOT NULL, detail TEXT, checked_at TEXT NOT NULL);
CREATE TABLE independent_answer (id INTEGER PRIMARY KEY AUTOINCREMENT, candidate_id TEXT NOT NULL, item_hash TEXT,
  method TEXT NOT NULL, solver_answer TEXT, generator_answer TEXT, verdict TEXT NOT NULL, detail TEXT,
  checked_at TEXT NOT NULL);
CREATE TABLE run_telemetry (run_id TEXT NOT NULL, stage TEXT NOT NULL, model TEXT, batches INTEGER, items INTEGER,
  input_tokens INTEGER, output_tokens INTEGER, wall_seconds REAL, note TEXT, recorded_at TEXT NOT NULL,
  PRIMARY KEY (run_id, stage, model));
"""


class MigrationFactory3ToFactory4(unittest.TestCase):
    def test_migrate_r2_3_is_additive_idempotent_and_preserves_certified_count(self):
        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        conn.executescript(_FACTORY3_NO_R2_3_DDL)
        conn.execute("INSERT INTO candidate (candidate_id, run_id, spec_id, generator_model, generator_family, "
                     "certification_class, stem, options, answer_label, status, item_hash, created_at) VALUES "
                     "('CAND_x','R','S1','claude-opus-4-8','claude-opus-4-8','certified','A stem','{}','b',"
                     "'certified','IH_x','2026-01-01T00:00:00.000+00:00')")
        conn.commit()
        before = conn.execute("SELECT COUNT(*) FROM candidate WHERE status='certified'").fetchone()[0]
        self.assertFalse(CO._has_col(conn, "candidate", "generator_actor"))
        changed = CO.migrate_r2_3(conn)
        self.assertTrue(changed)
        for c in ("model_version", "prompt_sha256", "payload_sha256", "generator_actor", "contract_version"):
            self.assertTrue(CO._has_col(conn, "candidate", c), f"candidate.{c} not added")
        for c in ("model_version", "prompt_sha256", "payload_sha256", "judge_actor"):
            self.assertTrue(CO._has_col(conn, "judge_verdict", c), f"judge_verdict.{c} not added")
        for t in ("gate_result", "independent_answer", "run_telemetry"):
            self.assertTrue(CO._has_col(conn, t, "actor"), f"{t}.actor not added")
        after = conn.execute("SELECT COUNT(*) FROM candidate WHERE status='certified'").fetchone()[0]
        self.assertEqual(before, after)
        # nothing backfilled — legacy provenance is an honest NULL
        self.assertIsNone(conn.execute("SELECT generator_actor FROM candidate WHERE candidate_id='CAND_x'")
                          .fetchone()[0])
        self.assertFalse(CO.migrate_r2_3(conn), "idempotent")
        conn.close()

    def test_open_store_is_factory5(self):
        conn = CO.open_store(":memory:")
        try:
            self.assertEqual(CO.SCHEMA_VERSION, "factory-5")
            self.assertEqual(conn.execute("SELECT value FROM factory_meta WHERE key='schema_version'")
                             .fetchone()[0], "factory-5")
            for c in ("model_version", "prompt_sha256", "payload_sha256", "generator_actor", "contract_version"):
                self.assertTrue(CO._has_col(conn, "candidate", c))
            # factory-5: the bank-dedup partial UNIQUE indexes exist
            idx = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='index'")}
            self.assertIn("ux_cert_item_hash", idx)
            self.assertIn("ux_cert_norm_hash", idx)
        finally:
            conn.close()


# ── (8) ki_run populated ──────────────────────────────────────────────────────────────────────────
class KiRunTrail(unittest.TestCase):
    def test_record_run_populates_ki_run(self):
        with tempfile.TemporaryDirectory() as d:
            path = str(Path(d) / "index.db")
            conn = SC.open_index(path)                    # fresh (not frozen) index — rides no hatch
            try:
                self.assertEqual(conn.execute("SELECT COUNT(*) FROM ki_run").fetchone()[0], 0)
                SC.record_run(conn, "engineer_MAT_2026", "engineer", "opus-4.8(engineer)", items=42,
                              note='{"concepts": 42}')
                SC.record_run(conn, "audit_2026", "audit", "opus-4.8(independent-audit)", items=42)
                rows = conn.execute("SELECT run_id, stage, model, items FROM ki_run ORDER BY stage").fetchall()
                self.assertEqual(len(rows), 2)
                self.assertEqual(rows[0]["stage"], "audit")
                self.assertEqual(rows[1]["stage"], "engineer")
                self.assertEqual(rows[1]["model"], "opus-4.8(engineer)")
                self.assertEqual(rows[1]["items"], 42)
            finally:
                conn.close()


# ── (9) stage ledger append-only ──────────────────────────────────────────────────────────────────
class StageLedgerAppendOnly(unittest.TestCase):
    def test_reruns_append_and_latest_view_reads_most_recent(self):
        from kie import ledger, store
        conn = store.open_store(":memory:")
        try:
            ledger.record(conn, "D1", "parse", "failed", input_sha256="s1", error="boom")
            ledger.record(conn, "D1", "parse", "done", input_sha256="s2")
            # both attempts retained (append-only), not overwritten
            self.assertEqual(conn.execute("SELECT COUNT(*) FROM stage_ledger WHERE doc_id='D1' AND stage='parse'")
                             .fetchone()[0], 2)
            # readers see the LATEST attempt
            self.assertEqual(ledger.get(conn, "D1", "parse"), ("done", "s2"))
            self.assertFalse(ledger.needs_run(conn, "D1", "parse", "s2"))    # done + same sha -> no rerun
            self.assertTrue(ledger.needs_run(conn, "D1", "parse", "s3"))     # sha changed -> rerun
            # counts() dedups to the latest status per (doc, stage)
            self.assertEqual(ledger.counts(conn, "parse"), {"done": 1})
        finally:
            conn.close()


# ── (10) RI-8 product invariant scan over the live estate (read-only, gated) ───────────────────────
class LiveEstateProvenanceScan(unittest.TestCase):
    """RI-8 (product slice): no PRODUCT-VISIBLE certified row may carry missing/placeholder generation
    provenance. Legacy rows are certification_class NULL (product-invisible) so they are NOT retro-failed;
    this scan is the post-re-certification guard. Skips when the DB is absent or predates factory-4."""

    def _scan(self, path):
        if not path.exists():
            self.skipTest(f"{path.name} not present (local-only, gitignored)")
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        try:
            if not CO._table_exists(conn, "candidate"):
                self.skipTest("unexpected shape")
            if not (CO._has_col(conn, "candidate", "generator_actor")
                    and CO._has_col(conn, "candidate", "certification_class")):
                self.skipTest(f"{path.name} predates factory-4 (run migrate_factory_r2_3 first)")
            bad = conn.execute(
                "SELECT COUNT(*) FROM candidate WHERE status='certified' AND certification_class='certified' "
                "AND (generator_actor IS NULL OR TRIM(generator_actor)='' "
                "     OR prompt_sha256 IS NULL OR TRIM(prompt_sha256)='' "
                "     OR LOWER(generator_model) IN (SELECT LOWER(x) FROM (SELECT 'generator-agent' x "
                "        UNION ALL SELECT 'judge-agent' UNION ALL SELECT 'generator-model')))").fetchone()[0]
            self.assertEqual(bad, 0, f"{path.name}: a product-visible certified row lacks real provenance (RI-8)")
        finally:
            conn.close()

    def test_factory_corpus_product_rows_are_provenanced(self):
        self._scan(config.KIE_HOME / "factory_corpus.db")

    def test_question_bank_product_rows_are_provenanced(self):
        self._scan(config.KIE_HOME / "qpl_question_bank.db")


class RowLevelProvenanceRequiredR2Regression(unittest.TestCase):
    """Adversarial-verifier regression (RI-8): a certified row must carry its OWN generation + judge provenance,
    not merely ride a sibling candidate's run-level telemetry. The verifier certified an un-provenanced row via
    a sibling's telemetry (and via two hand-written non-placeholder telemetry rows). Fixed + pinned here."""

    def _seed_unprovenanced(self, conn, run="R", spec="S1"):
        # a full evidence chain but the candidate + judge carry NO provenance bundle (NULL provenance columns)
        CO.save_specs(conn, [_spec_row(spec, run)])
        CO.ingest(conn, run, [_item(spec)], "claude-opus-4-8", "b1")          # no provenance= bundle
        cid = CO._cid(run, spec)
        CO.record_gates(conn, cid, [
            {"gate": "schema", "ok": True, "severity": GATES.FATAL, "detail": ""},
            {"gate": "dimensional", "ok": True, "severity": GATES.QUARANTINE, "detail": ""},
            {"gate": "relation_grounded", "ok": True, "severity": GATES.QUARANTINE, "detail": ""}])
        CO.record_independent(conn, cid, "sympy_relation_solve", "4", "4", "agree", "ok")
        SOL.ingest(conn, run, [{"candidate_id": cid, "dispute": False,
                                "solution": {"steps": ["a = F/m = 12/3"], "final": "4"},
                                "distractor_rationale": _DISTRACTORS}])
        CO.record_judge(conn, cid, "human-examiner", True, {"verdict": "accept", "answer_correct": True},
                        judge_family="human-review")                          # no judge provenance bundle
        conn.commit()
        return cid

    def test_unprovenanced_row_cannot_certify_via_sibling_telemetry(self):
        conn = CO.open_store(":memory:")
        try:
            _seed_full_chain(conn, spec="S1", with_telemetry=True)            # legit sibling supplies telemetry
            bad = self._seed_unprovenanced(conn, spec="S2")                   # un-provenanced, rides that telemetry
            m = CERT.certify_run(conn, "R", require_telemetry=True)
            self.assertGreaterEqual(m["certified"], 1, "the provenanced sibling certifies")
            self.assertGreaterEqual(m["held_no_provenance"], 1, "the un-provenanced row is held")
            self.assertIsNone(conn.execute("SELECT certification_class FROM candidate WHERE candidate_id=?",
                                           (bad,)).fetchone()[0])
            self.assertNotIn(bad, [r["candidate_id"] for r in CO.product_inventory(conn, "R")])
        finally:
            conn.close()

    def test_faked_nonplaceholder_telemetry_alone_cannot_certify(self):
        # the amplifier: hand-written non-placeholder telemetry + an un-provenanced candidate, no legit sibling
        conn = CO.open_store(":memory:")
        try:
            self._seed_unprovenanced(conn, spec="S1")
            CO.telemetry(conn, "R", "generation", "some-model", actor="some-actor", items=1)
            CO.telemetry(conn, "R", "judge", "some-judge-model", actor="some-judge-actor", items=1)
            conn.commit()
            m = CERT.certify_run(conn, "R", require_telemetry=True)
            self.assertEqual(m["certified"], 0)
            self.assertGreaterEqual(m["held_no_provenance"], 1)
            self.assertEqual(len(CO.product_inventory(conn, "R")), 0)
        finally:
            conn.close()

    def test_fully_provenanced_row_still_certifies(self):    # no over-restriction
        conn = CO.open_store(":memory:")
        try:
            _seed_full_chain(conn, with_telemetry=True)
            self.assertEqual(CERT.certify_run(conn, "R", require_telemetry=True)["certified"], 1)
        finally:
            conn.close()

    def test_placeholder_denylist_hardened(self):
        for bad in ("generator", "judge", "test", "n/a", "-", "."):
            self.assertFalse(CO.provenance_complete(
                {"model": bad, "model_version": "1", "prompt_sha256": "a" * 64, "actor": "real",
                 "contract_version": "c1"}), f"{bad!r} must be a banned placeholder")


if __name__ == "__main__":
    unittest.main()
