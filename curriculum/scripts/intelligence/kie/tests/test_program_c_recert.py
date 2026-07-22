"""Program C — held-estate RE-CERTIFICATION runner: replay/fake validation + red-team.

Everything is DETERMINISTIC: Fake providers, no network, no key, no spend. What is pinned:
  * HAPPY PATH — with a passing deterministic battery, the runner's model stages (solution author + cross-family
    judge) drive a real certification: solution/distractor verification is REAL sympy (only the qie.db-knowledge
    gates are seeded), the judge is cross-family, and certify promotes exactly the product-visible rows.
  * CROSS-FAMILY enforcement — an 'anthropic' judge vs a 'recalled-factory' generator certifies (product-visible);
    a SAME-family judge yields only a provisional (product-invisible) row, never certified (R2-1).
  * REALITY — the actual recalled 22 do NOT survive the current deterministic gates; they quarantine BEFORE the
    judge, so a live judge run over them judges zero items (fail-closed, as designed).
  * RED-TEAM — budget fail-closed, rate governor, judge-control breach abort, unprovable distractor -> held,
    append-only (the source cohort object is never mutated; a fresh run gets fresh ids).
"""
from __future__ import annotations

import json
import unittest

from kie.qie.execution import ModelExecutor
from kie.qie.execution.providers.replay import FakeProvider
from kie.qie.execution.store import open_execution_store
from kie.qie.execution.telemetry import Budget, BudgetExceeded
from kie.qie.execution import recert as RC
from kie.qie.factory import certify as CERT
from kie.qie.factory import corpus as CO
from kie.qie.factory import gates as G
from kie.qie.factory import judge as JUDGE
from kie.qie.factory import run_generation as RG

RUN = "RECERT_TEST"


def _spec(spec_id, subject="Mathematics"):
    return {"spec_id": spec_id, "lane": "STRUCTURED_NUMERIC", "class_level": 11, "subject": subject,
            "archetype": "single_step_numerical", "composition": "single", "question_type": "MCQ",
            "intended_depth": 2, "intended_difficulty": "moderate", "visual_required": 0}


def _cohort():
    return [
        {"source_id": "SRC_arc", "spec": _spec("QBP_arc"),
         "item": {"spec_id": "QBP_arc",
                  "stem": "An arc of length 15 cm subtends an angle theta at the centre of a circle of radius "
                          "5 cm. The radian measure of theta is",
                  "options": {"a": "0.33", "b": "75", "c": "3", "d": "10"},
                  "answer_label": "c", "answer_value": "3", "claimed": {"concepts": ["arc_length_radian"]},
                  "structure": {"givens": {"s": {"value": 15, "unit": ""}, "r": {"value": 5, "unit": ""},
                                           "theta": {"value": None, "unit": ""}},
                                "relation": "theta = s / r", "solve_for": "theta", "answer_unit": "",
                                "steps": [{"out": "theta", "inputs": ["s", "r"], "relation": "theta = s / r"}]}}},
        {"source_id": "SRC_rel", "spec": _spec("QBP_rel"),
         "item": {"spec_id": "QBP_rel",
                  "stem": "Set A has 3 elements and set B has 2 elements. The number of relations from A to B is",
                  "options": {"a": "32", "b": "6", "c": "64", "d": "36"},
                  "answer_label": "c", "answer_value": "64", "claimed": {"concepts": ["relations_count"]},
                  "structure": {"givens": {"m": {"value": 3, "unit": ""}, "n": {"value": 2, "unit": ""},
                                           "Nrel": {"value": None, "unit": ""}},
                                "relation": "Nrel = 2**(m*n)", "solve_for": "Nrel", "answer_unit": "",
                                "steps": [{"out": "Nrel", "inputs": ["m", "n"],
                                           "relation": "Nrel = 2**(m*n)"}]}}},
    ]


def _valid_solutions():
    arc, rel = CO._cid(RUN, "QBP_arc"), CO._cid(RUN, "QBP_rel")
    return {
        arc: {"candidate_id": arc, "dispute": False,
              "solution": {"steps": ["theta = s/r = 15/5 = 3"], "final": "3"},
              "distractor_rationale": {"a": {"misconception": "inverted", "mis_relation": "theta = r / s"},
                                       "b": {"misconception": "multiplied", "mis_relation": "theta = s * r"},
                                       "d": {"misconception": "subtracted", "mis_relation": "theta = s - r"}}},
        rel: {"candidate_id": rel, "dispute": False,
              "solution": {"steps": ["Nrel = 2^(m*n) = 64"], "final": "64"},
              "distractor_rationale": {"a": {"misconception": "sum exp", "mis_relation": "Nrel = 2**(m+n)"},
                                       "b": {"misconception": "product", "mis_relation": "Nrel = m*n"},
                                       "d": {"misconception": "sq product", "mis_relation": "Nrel = (m*n)**2"}}},
    }


def _sol_exec(econn, solutions, *, family="openai", model="gpt-4o-mini"):
    def responder(req):
        out = []
        for line in req.prompt.splitlines():
            line = line.strip()
            if line.startswith("{") and '"candidate_id"' in line:
                try:
                    sol = solutions.get(json.loads(line).get("candidate_id"))
                except ValueError:
                    sol = None
                if sol is not None:
                    out.append(sol)
        return json.dumps(out)
    fp = FakeProvider(responder, name=model, family=family, model_version=model)
    return ModelExecutor(fp, model=model, model_version=model, actor="recert-solution", conn=econn)


def _judge_exec(econn, answer_by_cid, *, family="anthropic", model="anthropic/claude-sonnet-4.5", **kw):
    def responder(req):
        out = []
        for line in req.prompt.splitlines():
            line = line.strip()
            if not (line.startswith("{") and '"candidate_id"' in line):
                continue
            try:
                cid = json.loads(line).get("candidate_id")
            except ValueError:
                continue
            if cid is None:
                continue
            if str(cid).startswith("JUDGE_CTRL_"):
                out.append({"candidate_id": cid, "verdict": "reject", "chosen_label": "a", "reasons": "bad"})
            else:
                out.append({"candidate_id": cid, "verdict": "accept",
                            "chosen_label": answer_by_cid.get(cid, "a")})
        return json.dumps(out)
    fp = FakeProvider(responder, name=model, family=family, model_version=model)
    return ModelExecutor(fp, model=model, model_version=model, actor="recert-judge", conn=econn, **kw)


def _seed_pass_gates(fconn, cohort):
    """Seed a PASSING deterministic battery + a sympy 'agree' for each staged candidate — the qie.db-knowledge
    gates only (relation_grounded/archetype/curriculum), so the happy path exercises the REAL solution/distractor
    verification, judge and certify without depending on frozen qie.db content."""
    for c in cohort:
        cid = CO._cid(RUN, c["item"]["spec_id"])
        CO.record_gates(fconn, cid, [
            {"gate": "schema", "ok": True, "severity": G.FATAL, "detail": ""},
            {"gate": "dimensional", "ok": True, "severity": G.QUARANTINE, "detail": ""},
            {"gate": "relation_grounded", "ok": True, "severity": G.QUARANTINE, "detail": ""}])
        av = c["item"]["answer_value"]
        CO.record_independent(fconn, cid, "sympy_relation_solve", av, av, "agree", "ok")


def _answer_map(cohort):
    return {CO._cid(RUN, c["item"]["spec_id"]): c["item"]["answer_label"] for c in cohort}


class TestHappyPath(unittest.TestCase):
    def test_full_chain_certifies_cross_family(self):
        fconn = CO.open_store(":memory:")
        se, je = open_execution_store(":memory:"), open_execution_store(":memory:")
        try:
            cohort = _cohort()
            RC.stage_cohort(fconn, RUN, cohort)
            _seed_pass_gates(fconn, cohort)
            RC.run_solution_stage(fconn, RUN, _sol_exec(se, _valid_solutions()))
            RG.judge_run(fconn, RUN, _judge_exec(je, _answer_map(cohort)))
            out = CERT.certify_run(fconn, RUN, require_telemetry=True)
            self.assertEqual(out["certified"], 2, out)
            vis = fconn.execute("SELECT COUNT(*) FROM candidate WHERE run_id=? AND status=? AND "
                                "certification_class=?", (RUN, CO.CERTIFIED, CO.CERT_CERTIFIED)).fetchone()[0]
            self.assertEqual(vis, 2)
        finally:
            fconn.close(); se.close(); je.close()

    def test_same_family_judge_is_provisional_not_product_visible(self):
        fconn = CO.open_store(":memory:")
        se, je = open_execution_store(":memory:"), open_execution_store(":memory:")
        try:
            cohort = _cohort()
            RC.stage_cohort(fconn, RUN, cohort)
            _seed_pass_gates(fconn, cohort)
            RC.run_solution_stage(fconn, RUN, _sol_exec(se, _valid_solutions()))
            RG.judge_run(fconn, RUN, _judge_exec(je, _answer_map(cohort), family=RC.GENERATOR_FAMILY))
            out = CERT.certify_run(fconn, RUN, require_telemetry=True)
            self.assertEqual(out["certified"], 0, out)
            self.assertEqual(out["provisional_same_actor"], 2, out)
        finally:
            fconn.close(); se.close(); je.close()


class TestReality(unittest.TestCase):
    def test_recalled_22_quarantine_at_gates_before_judge(self):
        from kie import config
        bank = config.KIE_HOME / "qpl_question_bank.db"
        if not bank.exists():
            self.skipTest("qpl_question_bank.db not present")
        fconn = CO.open_store(":memory:")
        se, je = open_execution_store(":memory:"), open_execution_store(":memory:")
        try:
            cohort = RC.load_recalled_cohort(bank)
            self.assertEqual(len(cohort), 22)
            rep = RC.recertify(fconn, RUN, cohort, _sol_exec(se, {}), _judge_exec(je, {}))
            self.assertEqual(rep["verify"]["survived_gates"], 0, rep["verify"])
            self.assertEqual(rep["judge"]["in"], 0, rep)             # judge never reached
            self.assertEqual(rep["certify"]["certified"], 0, rep)
            self.assertEqual(rep["product_visible_certified"], 0)
        finally:
            fconn.close(); se.close(); je.close()

    def test_replay_is_deterministic(self):
        def run():
            fconn = CO.open_store(":memory:")
            se, je = open_execution_store(":memory:"), open_execution_store(":memory:")
            try:
                cohort = _cohort()
                RC.stage_cohort(fconn, RUN, cohort)
                _seed_pass_gates(fconn, cohort)
                RC.run_solution_stage(fconn, RUN, _sol_exec(se, _valid_solutions()))
                RG.judge_run(fconn, RUN, _judge_exec(je, _answer_map(cohort)))
                return CERT.certify_run(fconn, RUN, require_telemetry=True)
            finally:
                fconn.close(); se.close(); je.close()
        self.assertEqual(run(), run())


class TestRedTeam(unittest.TestCase):
    def _staged_ready(self, fconn, se):
        cohort = _cohort()
        RC.stage_cohort(fconn, RUN, cohort)
        _seed_pass_gates(fconn, cohort)
        RC.run_solution_stage(fconn, RUN, _sol_exec(se, _valid_solutions()))
        return cohort

    def test_budget_fail_closed_blocks_judge(self):
        fconn = CO.open_store(":memory:")
        se, je = open_execution_store(":memory:"), open_execution_store(":memory:")
        try:
            cohort = self._staged_ready(fconn, se)
            je_zero = _judge_exec(je, _answer_map(cohort), budget=Budget(cap_usd=0.0))
            with self.assertRaises(BudgetExceeded):
                RG.judge_run(fconn, RUN, je_zero)
            # a refused judge call leaves NO judge telemetry -> certify refuses fail-closed (RI-8), never certifies
            with self.assertRaises(CO.CorpusIntegrityError):
                CERT.certify_run(fconn, RUN, require_telemetry=True)
        finally:
            fconn.close(); se.close(); je.close()

    def test_judge_control_breach_aborts(self):
        # a judge that ACCEPTS the planted known-bad controls must abort the pass (JudgeControlBreach) — its
        # verdicts are not evidence. The runner cannot certify on a judge that cannot fail a known-bad item.
        fconn = CO.open_store(":memory:")
        se, je = open_execution_store(":memory:"), open_execution_store(":memory:")
        try:
            cohort = self._staged_ready(fconn, se)

            def accept_all(req):
                out = []
                for line in req.prompt.splitlines():
                    line = line.strip()
                    if line.startswith("{") and '"candidate_id"' in line:
                        try:
                            cid = json.loads(line).get("candidate_id")
                        except ValueError:
                            continue
                        if cid:
                            out.append({"candidate_id": cid, "verdict": "accept", "chosen_label": "c"})
                return json.dumps(out)
            bad = ModelExecutor(FakeProvider(accept_all, name="anthropic/claude-sonnet-4.5", family="anthropic",
                                             model_version="anthropic/claude-sonnet-4.5"),
                                model="anthropic/claude-sonnet-4.5", model_version="anthropic/claude-sonnet-4.5",
                                actor="recert-judge", conn=je)
            with self.assertRaises(JUDGE.JudgeControlBreach):
                RG.judge_run(fconn, RUN, bad)
        finally:
            fconn.close(); se.close(); je.close()

    def test_unprovable_distractor_held_never_certified(self):
        fconn = CO.open_store(":memory:")
        se, je = open_execution_store(":memory:"), open_execution_store(":memory:")
        try:
            cohort = _cohort()
            RC.stage_cohort(fconn, RUN, cohort)
            _seed_pass_gates(fconn, cohort)
            bad = _valid_solutions()
            arc = CO._cid(RUN, "QBP_arc")
            bad[arc]["distractor_rationale"] = {L: {"misconception": "x", "mis_relation": "theta = s + r"}
                                                for L in ("a", "b", "d")}   # none compute the option
            RC.run_solution_stage(fconn, RUN, _sol_exec(se, bad))
            # the tampered arc item is quarantined at SOL.ingest (distractor_verification_failed), BEFORE certify.
            arc = CO._cid(RUN, "QBP_arc")
            st = fconn.execute("SELECT status, reject_reason FROM candidate WHERE candidate_id=?",
                               (arc,)).fetchone()
            self.assertEqual(st["status"], CO.QUARANTINED, dict(st))
            self.assertIn("distractor", (st["reject_reason"] or ""))
            RG.judge_run(fconn, RUN, _judge_exec(je, _answer_map(cohort)))
            out = CERT.certify_run(fconn, RUN, require_telemetry=True)
            self.assertEqual(out["certified"], 1, out)                 # only the clean 'rel' item certifies
        finally:
            fconn.close(); se.close(); je.close()

    def test_append_only_source_not_mutated(self):
        fconn = CO.open_store(":memory:")
        try:
            cohort = _cohort()
            before = json.dumps(cohort, sort_keys=True)
            RC.stage_cohort(fconn, RUN, cohort)
            self.assertEqual(json.dumps(cohort, sort_keys=True), before)
            self.assertEqual(fconn.execute("SELECT COUNT(*) FROM candidate WHERE run_id=?", (RUN,)).fetchone()[0],
                             2)
        finally:
            fconn.close()

    def test_reingest_same_run_refused(self):
        # the append-only immutability guard: re-staging the SAME cohort into the SAME run refuses fail-closed
        # (CorpusIntegrityError) rather than silently overwriting — exactly the replay bypass the audit found.
        fconn = CO.open_store(":memory:")
        try:
            cohort = _cohort()
            RC.stage_cohort(fconn, RUN, cohort)
            with self.assertRaises(CO.CorpusIntegrityError):
                RC.stage_cohort(fconn, RUN, cohort)
        finally:
            fconn.close()

    def test_transient_error_on_judge_is_retried_then_succeeds(self):
        from kie.qie.execution.provider import TransientError
        fconn = CO.open_store(":memory:")
        se, je = open_execution_store(":memory:"), open_execution_store(":memory:")
        try:
            cohort = self._staged_ready(fconn, se)
            answer = _answer_map(cohort)

            class _Flaky:
                calls = 0

                def __call__(self, req):
                    _Flaky.calls += 1
                    if _Flaky.calls == 1:
                        raise TransientError("simulated 503 on first judge attempt")
                    out = []
                    for line in req.prompt.splitlines():
                        line = line.strip()
                        if not (line.startswith("{") and '"candidate_id"' in line):
                            continue
                        try:
                            cid = json.loads(line).get("candidate_id")
                        except ValueError:
                            continue
                        if cid is None:
                            continue
                        if str(cid).startswith("JUDGE_CTRL_"):
                            out.append({"candidate_id": cid, "verdict": "reject", "chosen_label": "a"})
                        else:
                            out.append({"candidate_id": cid, "verdict": "accept",
                                        "chosen_label": answer.get(cid, "a")})
                    return json.dumps(out)

            flaky = _Flaky()
            fp = FakeProvider(flaky, name="anthropic/claude-sonnet-4.5", family="anthropic",
                              model_version="anthropic/claude-sonnet-4.5")
            jexec = ModelExecutor(fp, model="anthropic/claude-sonnet-4.5",
                                  model_version="anthropic/claude-sonnet-4.5", actor="recert-judge", conn=je)
            RG.judge_run(fconn, RUN, jexec)
            self.assertEqual(_Flaky.calls, 2)                          # failed once, retried, succeeded
            self.assertEqual(CERT.certify_run(fconn, RUN, require_telemetry=True)["certified"], 2)
        finally:
            fconn.close(); se.close(); je.close()


if __name__ == "__main__":
    unittest.main()
