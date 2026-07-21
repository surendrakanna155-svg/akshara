"""R2 certification-hardening regression locks (audit P0/P1 · C4 + C5 + #ai-systems-5/6/8, #qa-reliability-6).

Permanent invariants for the R2 cluster, built on the R1 pattern (in-memory / tmp stores, ZERO model calls):

  * RI-3  — the FULL certified-row conjunction. A status='certified' + certification_class='certified' row must
            carry, ALL bound to its CURRENT item_hash: zero fatal gates + independent_answer='agree' + judge
            'accept' with independent=1 (cross-family) + solution_verified=1 + distractor_verified=1 +
            evidence_class set. Positive path certifies; each missing leg lands in its own hold bucket.
  * RI-8 (R2 slice) — judge independence is COMPUTED from actor families at ingest; a same-actor audit can NEVER
            produce a certification_class='certified' row (it is provisional, product-invisible).
  * R2-4  — step replay EARNS depth by executing the DAG; a self-refuted depth is BLOCKING.
  * R2-2  — the deterministic distractor gate proves each wrong option; unverifiable ones are caught.
  * controls — the R2 must-catch controls (distractor gate + seeded judge controls) raise on a hole.

These prove the machinery is fail-closed NOW; the cross-family/human judge + Opus solution-writer are deferred
ACTORS (no API layer — R4-2), but the ENFORCEMENT lands here and today's legacy rows fall product-invisible.
"""
from __future__ import annotations

import sqlite3
import unittest

from kie import config
from kie.qie.factory import certify as CERT
from kie.qie.factory import controls as CTRL
from kie.qie.factory import corpus as CO
from kie.qie.factory import gates as G
from kie.qie.factory import judge as JUDGE
from kie.qie.factory import solutions as SOL


# ── fixtures: a clean structured-numeric item whose distractors are each reachable by a named mistake ──
def _spec_row(spec_id="S1", run="R"):
    return {"spec_id": spec_id, "run_id": run, "lane": "STRUCTURED_NUMERIC", "board": "CBSE",
            "exam_profile": "NEET", "class_level": 9, "subject": "Physics", "concept_code": "C1",
            "concept_title": "Newton's second law", "composition": "single",
            "archetype": "single_step_numerical", "question_type": "MCQ", "intended_depth": 1,
            "intended_difficulty": "easy", "visual_required": 0, "created_at": "2026-01-01T00:00:00+00:00"}


def _item(spec_id="S1", depth=1):
    return {"spec_id": spec_id,
            "stem": "A net force of 12 N acts on a 3 kg block. Find the acceleration.",
            "options": {"a": "36 m/s^2", "b": "4 m/s^2", "c": "0.25 m/s^2", "d": "9 m/s^2"},
            "answer_label": "b", "answer_value": "4",
            "claimed": {"concepts": ["Newton's second law"], "archetype": "single_step_numerical",
                        "depth": depth, "difficulty": "easy", "composition": "single"},
            "structure": {"givens": {"F": {"value": 12, "unit": "N"}, "m": {"value": 3, "unit": "kg"},
                                     "a": {"value": None, "unit": "m/s**2"}},
                          "relation": "a = F/m", "solve_for": "a", "answer_unit": "m/s**2"}}


_DISTRACTORS = {"a": {"misconception": "F*m", "mis_relation": "a = F*m"},
                "c": {"misconception": "m/F", "mis_relation": "a = m/F"},
                "d": {"misconception": "F-m", "mis_relation": "a = F - m"}}


def _seed_pre_solution(conn, cid):
    """A passing deterministic battery + a sympy 'agree' — seeded directly (run_gates needs the certified-
    relation registry, which is gitignored). Content-stamped to the candidate's CURRENT item_hash."""
    CO.record_gates(conn, cid, [{"gate": "schema", "ok": True, "severity": G.FATAL, "detail": ""},
                                {"gate": "dimensional", "ok": True, "severity": G.QUARANTINE, "detail": ""},
                                {"gate": "relation_grounded", "ok": True, "severity": G.QUARANTINE, "detail": ""}])
    CO.record_independent(conn, cid, "sympy_relation_solve", "4", "4", "agree", "ok")


def _prepare(conn, run="R", spec="S1", distractors=None, uncertifiable=None):
    """Ingest one candidate and take it up to (but not through) the judge: gates + independent + the real
    solution stage (which records solution_verified + distractor_verified). Returns the candidate_id."""
    CO.save_specs(conn, [_spec_row(spec, run)])
    CO.ingest(conn, run, [_item(spec)], "generator-agent", "b1")
    cid = CO._cid(run, spec)
    _seed_pre_solution(conn, cid)
    SOL.ingest(conn, run, [{"candidate_id": cid, "dispute": False,
                            "solution": {"steps": ["a = F/m = 12/3"], "final": "4"},
                            "distractor_rationale": _DISTRACTORS if distractors is None else distractors,
                            "distractor_uncertifiable": uncertifiable or []}])
    return cid


def _judge(conn, cid, run="R", verdict="accept", judge_family="human-review", chosen="b"):
    JUDGE.ingest(conn, run, [{"candidate_id": cid, "verdict": verdict, "chosen_label": chosen}],
                 "examiner-model", judge_family=judge_family, require_controls=False)


class RI3FullCertifiedRowInvariant(unittest.TestCase):
    """RI-3: a product-certified row satisfies the entire evidence conjunction bound to its current content."""

    def _assert_ri3_holds(self, conn, run="R"):
        certified = conn.execute(
            "SELECT * FROM candidate WHERE run_id=? AND status='certified' AND certification_class='certified'",
            (run,)).fetchall()
        for c in certified:
            cid, ih = c["candidate_id"], c["item_hash"]
            # (i) zero fatal gates for the CURRENT item_hash
            self.assertEqual(conn.execute(
                "SELECT COUNT(*) FROM gate_result WHERE candidate_id=? AND item_hash=? AND ok=0 AND severity=?",
                (cid, ih, G.FATAL)).fetchone()[0], 0, "certified row has a fatal gate")
            # (ii) independent_answer 'agree' bound to this hash
            ia = conn.execute("SELECT verdict, item_hash FROM independent_answer_latest WHERE candidate_id=?",
                              (cid,)).fetchone()
            self.assertEqual((ia["verdict"], ia["item_hash"]), ("agree", ih))
            # (iii) judge accept + independent=1
            jv = conn.execute("SELECT verdict, independent, judge_family, item_hash "
                              "FROM judge_verdict_latest WHERE candidate_id=?", (cid,)).fetchone()
            self.assertEqual(jv["verdict"], "accept")
            self.assertEqual(jv["independent"], 1)
            self.assertEqual(jv["item_hash"], ih)
            self.assertNotEqual(jv["judge_family"], c["generator_family"], "certified by same actor family")
            # (iv) solution_verified ok + (v) distractor_verified ok, both content-bound
            for gate in ("solution_verified", "distractor_verified"):
                self.assertEqual(conn.execute(
                    "SELECT COUNT(*) FROM gate_result WHERE candidate_id=? AND item_hash=? AND gate=? AND ok=1",
                    (cid, ih, gate)).fetchone()[0], 1, f"missing {gate} bound to current content")
            # (vi) evidence_class stamped + certification_class certified
            self.assertEqual(c["evidence_class"], CO.EVIDENCE_SYMPY)
            self.assertEqual(c["certification_class"], CO.CERT_CERTIFIED)

    def test_full_evidence_cross_family_certifies_and_is_product_visible(self):
        conn = CO.open_store(":memory:")
        try:
            cid = _prepare(conn)
            _judge(conn, cid, judge_family="human-review")
            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 1)
            self.assertEqual(m["provisional_same_actor"], 0)
            self.assertEqual(len(CO.product_inventory(conn, "R")), 1)
            self._assert_ri3_holds(conn)
            # earned depth is stamped (R2-4) and equals the executed replay depth (1 for a single relation)
            row = conn.execute("SELECT earned_depth, computed_archetype FROM candidate WHERE candidate_id=?",
                               (cid,)).fetchone()
            self.assertEqual(row["earned_depth"], 1)
            self.assertTrue(row["computed_archetype"])
        finally:
            conn.close()

    def test_missing_solution_stage_holds_not_certified(self):
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "generator-agent", "b1")
            cid = CO._cid("R", "S1")
            _seed_pre_solution(conn, cid)                     # gates + independent, but NO solution stage ran
            _judge(conn, cid, judge_family="human-review")
            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 0)
            self.assertEqual(m["held_no_solution"], 1)
            self.assertEqual(len(CO.product_inventory(conn, "R")), 0)
        finally:
            conn.close()

    def test_missing_distractor_gate_holds_not_certified(self):
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "generator-agent", "b1")
            cid = CO._cid("R", "S1")
            _seed_pre_solution(conn, cid)
            # seed ONLY solution_verified (no distractor_verified gate at all)
            CO.record_gates(conn, cid, [{"gate": "solution_verified", "ok": True, "severity": G.FATAL,
                                         "detail": ""}])
            _judge(conn, cid, judge_family="human-review")
            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 0)
            self.assertEqual(m["held_no_distractors"], 1)
        finally:
            conn.close()

    def test_unverifiable_distractor_is_quarantined_at_solution_stage(self):
        # a distractor whose mis_relation does NOT compute its option must never reach certification
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "generator-agent", "b1")
            cid = CO._cid("R", "S1")
            _seed_pre_solution(conn, cid)
            bad = dict(_DISTRACTORS); bad["a"] = {"misconception": "guessed", "mis_relation": "a = F + m"}  # 15≠36
            out = SOL.ingest(conn, "R", [{"candidate_id": cid, "dispute": False,
                                          "solution": {"steps": ["a=F/m"], "final": "4"},
                                          "distractor_rationale": bad}])
            self.assertEqual(out["distractor_unverified"], 1)
            self.assertEqual(conn.execute("SELECT status FROM candidate WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], CO.QUARANTINED)
            _judge(conn, cid, judge_family="human-review")
            m = CERT.certify_run(conn, "R")            # already quarantined -> certify does not see it
            self.assertEqual(m["certified"], 0)
        finally:
            conn.close()

    def test_refuted_depth_quarantine_gate_blocks_certification(self):
        # a recorded BLOCKING depth_agreement failure (claimed != earned) can never certify (R2-4)
        conn = CO.open_store(":memory:")
        try:
            cid = _prepare(conn)
            CO.record_gates(conn, cid, [{"gate": "depth_agreement", "ok": False, "severity": G.QUARANTINE,
                                         "detail": "claimed=3 earned_replay_depth=1"}])
            _judge(conn, cid, judge_family="human-review")
            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 0)
            self.assertEqual(m["stale_evidence"], 1, "a self-refuted depth is a blocking quarantine gate")
        finally:
            conn.close()


class RI8SameActorCannotPromote(unittest.TestCase):
    """RI-8 (R2 slice): independence is computed from actor families; a same-actor audit is provisional-only."""

    def test_same_family_judge_yields_provisional_not_certified(self):
        conn = CO.open_store(":memory:")
        try:
            cid = _prepare(conn)
            # judge with NO declared family defaults to the candidate's OWN generator family => same actor
            _judge(conn, cid, judge_family=None)
            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 0)
            self.assertEqual(m["provisional_same_actor"], 1)
            row = conn.execute("SELECT status, certification_class FROM candidate WHERE candidate_id=?",
                               (cid,)).fetchone()
            self.assertEqual(row["status"], CO.CERTIFIED)
            self.assertEqual(row["certification_class"], CO.CERT_PROVISIONAL)
            self.assertEqual(len(CO.product_inventory(conn, "R")), 0, "provisional row must be product-invisible")
        finally:
            conn.close()

    def test_judge_ingest_computes_independent_from_families(self):
        conn = CO.open_store(":memory:")
        try:
            cid = _prepare(conn)
            # explicit same-family judge -> independent stored 0; different family -> 1
            JUDGE.ingest(conn, "R", [{"candidate_id": cid, "verdict": "accept", "chosen_label": "b"}],
                         "generator-agent", judge_family="generator-agent", require_controls=False)
            self.assertEqual(conn.execute("SELECT independent FROM judge_verdict_latest WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], 0)
            JUDGE.ingest(conn, "R", [{"candidate_id": cid, "verdict": "accept", "chosen_label": "b"}],
                         "human-examiner", judge_family="human-review", require_controls=False)
            self.assertEqual(conn.execute("SELECT independent FROM judge_verdict_latest WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], 1)
        finally:
            conn.close()

    def test_answer_correct_is_computed_from_chosen_label_not_self_reported(self):
        conn = CO.open_store(":memory:")
        try:
            cid = _prepare(conn)
            # the judge self-reports answer_correct=True but chose the WRONG label -> stored answer_correct=0
            JUDGE.ingest(conn, "R", [{"candidate_id": cid, "verdict": "accept", "chosen_label": "a",
                                      "answer_correct": True}], "human-examiner", judge_family="human-review",
                         require_controls=False)
            self.assertEqual(conn.execute("SELECT answer_correct FROM judge_verdict_latest WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], 0)
        finally:
            conn.close()

    def test_judge_worksheet_does_not_leak_the_key(self):
        conn = CO.open_store(":memory:")
        try:
            CO.save_specs(conn, [_spec_row()])
            CO.ingest(conn, "R", [_item()], "generator-agent", "b1")
            ws = JUDGE.worksheet(JUDGE.to_judge(conn, "R"))
            self.assertTrue(ws)
            for w in ws:
                self.assertNotIn("proposed_key", w, "the judge worksheet must not leak the answer key (R2-1)")
                self.assertNotIn("answer_label", w)
        finally:
            conn.close()


class StepReplayEarnsDepth(unittest.TestCase):
    """R2-4: depth is EARNED by executing the DAG, never a bare claim over an unexecuted DAG."""

    def test_genuine_three_step_chain_earns_depth_three(self):
        chain = {"givens": {"F": {"value": 12}, "m": {"value": 3}, "t": {"value": 2}, "d": {"value": None}},
                 "solve_for": "d",
                 "steps": [{"out": "a", "inputs": ["F", "m"], "relation": "a = F/m"},
                           {"out": "v", "inputs": ["a", "t"], "relation": "v = a*t"},
                           {"out": "d", "inputs": ["v", "t"], "relation": "d = v*t/2"}]}
        rep = G.replay_steps(chain)
        self.assertTrue(rep["ok"])
        self.assertEqual(rep["depth"], 3)
        self.assertAlmostEqual(rep["final"], 8.0)

    def test_flat_dag_earns_depth_one_and_refutes_a_claimed_three(self):
        # the production case: every step reads only givens, so the answer is reproduced in ONE applied step
        flat = {"givens": {"m": {"value": 2}, "v": {"value": 3}, "K": {"value": None}},
                "relation": "K = m*v**2/2", "solve_for": "K",
                "steps": [{"out": "K", "inputs": ["m", "v"], "relation": "K = m*v**2/2"}]}
        rep = G.replay_steps(flat)
        self.assertEqual(rep["depth"], 1)
        # and the gate refutes a claimed depth of 3
        cand = {"stem": "A body of mass 2 kg moves at 3 m/s. Find its kinetic energy.",
                "options": {"a": "9 J", "b": "18 J", "c": "6 J", "d": "36 J"}, "answer_label": "a",
                "answer_value": "9", "claimed": {"depth": 3}, "structure": flat}
        ctx = {"spec": {"lane": "STRUCTURED_NUMERIC", "subject": "Physics"}, "seen_norm": {}, "corpus": [],
               "certified_relations": {}, "certified_relation_eqs": []}
        by = {g["gate"]: g for g in G.run_gates(cand, ctx)}
        self.assertIn("depth_agreement", by)
        self.assertFalse(by["depth_agreement"]["ok"], "claimed 3 vs earned 1 must FAIL depth_agreement")
        self.assertEqual(by["depth_agreement"]["severity"], G.QUARANTINE, "depth_agreement must be BLOCKING")

    def test_padded_dag_that_never_reaches_the_answer_is_unearned(self):
        bad = {"givens": {"m": {"value": 2}, "K": {"value": None}}, "solve_for": "K",
               "steps": [{"out": "K", "inputs": ["m", "v"], "relation": "K = m*v**2/2"}]}  # v never produced
        rep = G.replay_steps(bad)
        self.assertFalse(rep["ok"])
        self.assertIsNone(rep["depth"])


class DistractorGate(unittest.TestCase):
    """R2-2: a distractor verifies only when its named mistake COMPUTES the option value."""

    _ST = {"givens": {"F": {"value": 12}, "m": {"value": 3}, "a": {"value": None}}, "solve_for": "a"}
    _OPTS = {"a": "36", "b": "4", "c": "0.25", "d": "9"}

    def test_computing_mis_relation_verifies(self):
        res = G.verify_distractors(self._ST, self._OPTS, "b", _DISTRACTORS)
        self.assertTrue(res["ok"])
        self.assertEqual(set(res["verified"]), {"a", "c", "d"})

    def test_non_computing_mis_relation_is_caught(self):
        bad = dict(_DISTRACTORS); bad["a"] = {"mis_relation": "a = F + m"}   # 15, not 36
        res = G.verify_distractors(self._ST, self._OPTS, "b", bad)
        self.assertFalse(res["ok"])
        self.assertTrue(any(u["label"] == "a" for u in res["unverified"]))

    def test_uncertifiable_is_honored(self):
        res = G.verify_distractors(self._ST, self._OPTS, "b",
                                   {"a": _DISTRACTORS["a"], "c": _DISTRACTORS["c"]}, uncertifiable=["d"])
        self.assertTrue(res["ok"])

    def test_missing_rationale_without_uncertifiable_fails(self):
        res = G.verify_distractors(self._ST, self._OPTS, "b", {"a": _DISTRACTORS["a"]})   # c, d undeclared
        self.assertFalse(res["ok"])


class ControlsExtension(unittest.TestCase):
    """The R2 must-catch controls (distractor gate + seeded judge controls) must fail known-bad inputs."""

    def test_distractor_controls_hold(self):
        self.assertTrue(CTRL.check_distractor_controls()["all_ok"])

    def test_judge_controls_hold(self):
        self.assertTrue(CTRL.check_judge_controls()["all_ok"])

    def test_judge_control_breach_on_accepted_plant(self):
        plants = JUDGE.judge_control_items()
        accepted = {c["candidate_id"]: {"candidate_id": c["candidate_id"], "verdict": "accept"} for c in plants}
        with self.assertRaises(JUDGE.JudgeControlBreach):
            JUDGE.check_judge_controls(accepted)

    def test_judge_ingest_aborts_when_a_planted_bad_item_is_accepted(self):
        conn = CO.open_store(":memory:")
        try:
            cid = _prepare(conn)
            payload = [{"candidate_id": cid, "verdict": "accept", "chosen_label": "b"}]
            payload += [{"candidate_id": c["candidate_id"], "verdict": "accept"}     # accepts the plants -> abort
                        for c in JUDGE.judge_control_items()]
            with self.assertRaises(JUDGE.JudgeControlBreach):
                JUDGE.ingest(conn, "R", payload, "examiner", judge_family="human-review")
        finally:
            conn.close()


class MigrationFactory2ToFactory3(unittest.TestCase):
    """migrate_r2 is additive + idempotent and never promotes/demotes; legacy certified rows fall invisible."""

    def test_migrate_r2_is_additive_idempotent_and_preserves_certified_count(self):
        conn = sqlite3.connect(":memory:")
        conn.row_factory = sqlite3.Row
        # build the factory-2 shape (append-only) WITHOUT the R2 columns
        CO.migrate_appendonly(conn)                          # no-op on empty
        conn.executescript(_FACTORY2_NO_R2_DDL)
        conn.execute("INSERT INTO candidate (candidate_id, run_id, spec_id, generator_model, stem, options, "
                     "answer_label, status, item_hash, created_at) VALUES "
                     "('CAND_x','R','S1','gen','A stem','{}','b','certified','IH_x','2026-01-01T00:00:00.000+00:00')")
        conn.commit()
        before = conn.execute("SELECT COUNT(*) FROM candidate WHERE status='certified'").fetchone()[0]
        self.assertFalse(CO._has_col(conn, "candidate", "certification_class"))
        changed = CO.migrate_r2(conn)
        self.assertTrue(changed)
        self.assertTrue(CO._has_col(conn, "candidate", "certification_class"))
        self.assertTrue(CO._has_col(conn, "candidate", "evidence_class"))
        self.assertTrue(CO._has_col(conn, "candidate", "generator_family"))
        self.assertTrue(CO._has_col(conn, "judge_verdict", "judge_family"))
        # count unchanged; generator_family backfilled; certification_class NULL => product-invisible
        after = conn.execute("SELECT COUNT(*) FROM candidate WHERE status='certified'").fetchone()[0]
        self.assertEqual(before, after)
        self.assertEqual(conn.execute("SELECT generator_family FROM candidate WHERE candidate_id='CAND_x'")
                         .fetchone()[0], "gen")
        # stamp this store the production bank (R3-1) so product_inventory's role gate passes and we isolate the
        # R2 assertion: even in the production bank the legacy row is invisible because its cert_class is NULL.
        conn.execute("CREATE TABLE IF NOT EXISTS factory_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        CO._stamp_role(conn, CO.ROLE_PRODUCTION, explicit=True)
        self.assertEqual(len(CO.product_inventory(conn, "R")), 0,
                         "a legacy certified row is invisible until re-certified under the R2 gates")
        self.assertFalse(CO.migrate_r2(conn), "idempotent")
        conn.close()


# a factory-2 candidate/judge shape WITHOUT the factory-3 columns (to exercise migrate_r2 forward)
_FACTORY2_NO_R2_DDL = """
CREATE TABLE candidate (candidate_id TEXT PRIMARY KEY, run_id TEXT NOT NULL, spec_id TEXT,
  generator_model TEXT NOT NULL, stem TEXT NOT NULL, options TEXT, answer_label TEXT, structure TEXT,
  status TEXT NOT NULL DEFAULT 'candidate', reject_reason TEXT, relation_waiver TEXT, item_hash TEXT,
  stem_norm_hash TEXT, created_at TEXT NOT NULL);
CREATE TABLE judge_verdict (id INTEGER PRIMARY KEY AUTOINCREMENT, candidate_id TEXT NOT NULL, item_hash TEXT,
  judge_model TEXT NOT NULL, independent INTEGER NOT NULL, verdict TEXT NOT NULL, checked_at TEXT);
"""


class LiveEstateFailsRI3ReadOnly(unittest.TestCase):
    """Documenting invariant (read-only, non-mutating): today's live certified rows FAIL RI-3 — no cross-family
    judge, no distractor verification — so R2 correctly makes them product-invisible until re-certified. (The
    trial store legitimately carries a few solution_verified gates; the FULL conjunction is what fails.)"""

    def _check(self, path):
        if not path.exists():
            self.skipTest(f"{path.name} not present (local-only, gitignored)")
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        try:
            if not CO._table_exists(conn, "candidate") or not CO._table_exists(conn, "gate_result"):
                self.skipTest("unexpected shape")
            certified = conn.execute("SELECT COUNT(*) FROM candidate WHERE status='certified'").fetchone()[0]
            if certified == 0:
                self.skipTest("no certified rows to check")
            # RI-3 leg (iii): none of the legacy certified rows carry an independent=1 judge (the universal
            # failing leg across BOTH stores — 0/15 trial, 0/22 bank).
            ind = conn.execute("SELECT COUNT(*) FROM candidate c JOIN judge_verdict j "
                               "ON j.candidate_id=c.candidate_id WHERE c.status='certified' AND j.independent=1"
                               ).fetchone()[0]
            self.assertEqual(ind, 0, f"{path.name}: legacy certified rows unexpectedly carry independent judges")
            # the FULL RI-3 conjunction (solution_verified AND distractor_verified AND independent judge) is
            # satisfied by ZERO legacy rows — so none would survive re-certification unchanged.
            full = conn.execute(
                "SELECT COUNT(*) FROM candidate c WHERE c.status='certified' "
                "AND EXISTS (SELECT 1 FROM gate_result g WHERE g.candidate_id=c.candidate_id "
                "            AND g.gate='solution_verified' AND g.ok=1) "
                "AND EXISTS (SELECT 1 FROM gate_result g WHERE g.candidate_id=c.candidate_id "
                "            AND g.gate='distractor_verified' AND g.ok=1) "
                "AND EXISTS (SELECT 1 FROM judge_verdict j WHERE j.candidate_id=c.candidate_id "
                "            AND j.verdict='accept' AND j.independent=1)").fetchone()[0]
            self.assertEqual(full, 0, f"{path.name}: a legacy certified row already satisfies RI-3 — unexpected")
        finally:
            conn.close()

    def test_factory_corpus_legacy_certified_fail_ri3(self):
        self._check(config.KIE_HOME / "factory_corpus.db")

    def test_question_bank_legacy_certified_fail_ri3(self):
        self._check(config.KIE_HOME / "qpl_question_bank.db")


class AdversarialVerifierR2Regression(unittest.TestCase):
    """Locks for the four holes the R2 adversarial verifier found — each was REFUTED, fixed, and pinned here."""

    _ST = {"givens": {"F": {"value": 12}, "m": {"value": 3}, "a": {"value": None}}, "solve_for": "a"}
    _OPTS = {"a": "36", "b": "4", "c": "0.25", "d": "9"}
    _FLAT = {"givens": {"m": {"value": 2}, "v": {"value": 3}, "K": {"value": None}},
             "relation": "K = m*v**2/2", "solve_for": "K",
             "steps": [{"out": "K", "inputs": ["m", "v"], "relation": "K = m*v**2/2"}]}
    _CTX = {"spec": {"lane": "STRUCTURED_NUMERIC", "subject": "Physics"}, "seen_norm": {}, "corpus": [],
            "certified_relations": {}, "certified_relation_eqs": []}

    # ── HOLE 1 (R2-2, production-reachable): all-uncertifiable distractors used to pass with ZERO proven ──
    def test_all_uncertifiable_distractors_do_not_pass(self):
        res = G.verify_distractors(self._ST, self._OPTS, "b", {}, uncertifiable=["a", "c", "d"])
        self.assertFalse(res["ok"], "declaring EVERY wrong option uncertifiable must NOT pass the gate")

    def test_bare_minority_proven_is_refused(self):
        # 1 proven, 2 uncertifiable of 3 wrong — not a proven majority => refused.
        res = G.verify_distractors(self._ST, self._OPTS, "b",
                                   {"a": _DISTRACTORS["a"]}, uncertifiable=["c", "d"])
        self.assertFalse(res["ok"])

    def test_legit_minority_uncertifiable_still_allowed(self):
        # the fix must not over-restrict: 2 proven + 1 uncertifiable stays honest.
        res = G.verify_distractors(self._ST, self._OPTS, "b",
                                   {"a": _DISTRACTORS["a"], "c": _DISTRACTORS["c"]}, uncertifiable=["d"])
        self.assertTrue(res["ok"])

    # ── HOLE 2 (R2-1): a NULL judge_family read as cross-family and certified ──
    def test_null_judge_family_cannot_certify(self):
        conn = CO.open_store(":memory:")
        try:
            cid = _prepare(conn)
            # bypass judge.ingest's same-actor default — write independent=1 with a NULL family directly
            CO.record_judge(conn, cid, "mystery-judge", True, {"verdict": "accept"}, judge_family=None)
            conn.commit()
            m = CERT.certify_run(conn, "R")
            self.assertEqual(m["certified"], 0, "a NULL judge_family must never certify (fail-closed)")
            self.assertEqual(conn.execute("SELECT certification_class FROM candidate WHERE candidate_id=?",
                                          (cid,)).fetchone()[0], CO.CERT_PROVISIONAL)
            self.assertEqual(len(CO.product_inventory(conn, "R")), 0)
        finally:
            conn.close()

    # ── HOLE 3 (R2-4): a claimed depth declared as a STRING skipped the BLOCKING gate ──
    def test_string_claimed_depth_still_blocks(self):
        cand = {"stem": "A body of mass 2 kg moves at 3 m/s. Find its kinetic energy.",
                "options": {"a": "9 J", "b": "18 J"}, "answer_label": "a", "answer_value": "9",
                "claimed": {"depth": "3"}, "structure": self._FLAT}       # earned 1, claimed "3" (string)
        by = {g["gate"]: g for g in G.run_gates(cand, self._CTX)}
        self.assertIn("depth_agreement", by)
        self.assertFalse(by["depth_agreement"]["ok"], "string depth '3' vs earned 1 must still FAIL")

    def test_matching_string_depth_agrees(self):
        cand = {"stem": "A body of mass 2 kg moves at 3 m/s. Find its kinetic energy.",
                "options": {"a": "9 J", "b": "18 J"}, "answer_label": "a", "answer_value": "9",
                "claimed": {"depth": "1"}, "structure": self._FLAT}       # earned 1, claimed "1" (string)
        by = {g["gate"]: g for g in G.run_gates(cand, self._CTX)}
        self.assertTrue(by["depth_agreement"]["ok"], "string depth '1' matching earned 1 must AGREE")

    # ── HOLE 4 (R2-1 gap): a judge that DROPPED all seeded controls escaped the abort ──
    def test_judge_dropping_all_controls_aborts(self):
        conn = CO.open_store(":memory:")
        try:
            cid = _prepare(conn)
            with self.assertRaises(JUDGE.JudgeControlBreach):
                JUDGE.ingest(conn, "R", [{"candidate_id": cid, "verdict": "accept", "chosen_label": "b"}],
                             "human-examiner", judge_family="human-review")   # require_controls defaults True
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
