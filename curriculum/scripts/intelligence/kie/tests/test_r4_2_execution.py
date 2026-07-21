"""R4-2 regression locks — the provider-agnostic model-execution layer.

Everything here is DETERMINISTIC: Fake/Replay providers + a mock urllib transport, NO network, NO API key. The
invariants pinned:

  * request_sha256 is a pure, PROVIDER-INDEPENDENT key over (model, params, system, prompt) — the cache / replay
    / idempotency key. It excludes the actor and meta.
  * OpenAIProvider builds a correct Chat Completions request and maps usage->tokens->cost; it fails CLOSED on a
    missing key (PermanentError), maps 429/5xx->TransientError and other 4xx / malformed->PermanentError.
  * ResponseCache (request_sha256) + JudgeCache (item_hash) round-trip and short-circuit a re-send.
  * the queue retries transient failures with backoff, never retries permanent ones, is idempotent by
    request_sha256 (a completed request is never re-sent -> crash-resume), and refuses fail-closed on a budget
    cap.
  * deterministic replay: record once, replay identically; a miss raises ReplayMiss.
  * provenance bundles satisfy corpus._require_provenance for both stages; prompt_sha256 == plan.brief_sha256.
  * telemetry + cost accounting persist per call; a cache hit costs $0; Budget reloads spend from the ledger.
  * END-TO-END: a fake-provider generation + judge run through run_generation produces candidates + provenance +
    telemetry such that certify_run(require_telemetry=True) runs — and a full chain certifies 1 item.
"""
from __future__ import annotations

import json
import unittest

from kie.qie.execution import (
    Budget, BudgetExceeded, FakeProvider, JudgeCache, LLMRequest, LLMResponse, ModelExecutor,
    OpenAIProvider, PermanentError, RecordingProvider, ReplayLog, ReplayMiss, ReplayProvider,
    ResponseCache, Telemetry, TransientError, cost_usd, generation_provenance, judge_provenance,
    open_execution_store, request_sha256,
)
from kie.qie.execution.queue import ExecutionQueue
from kie.qie.factory import certify as CERT
from kie.qie.factory import corpus as CO
from kie.qie.factory import gates as GATES
from kie.qie.factory import judge as JUDGE
from kie.qie.factory import plan as PLAN
from kie.qie.factory import run_generation as RG
from kie.qie.factory import solutions as SOL


def _noop_sleep(_):
    pass


def _mem_store():
    return open_execution_store(":memory:")


# ── canonical factory fixtures (mirrors test_qpl_provenance_telemetry) ──────────────────────────────
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


def _openai_body(prompt_tokens=100, completion_tokens=50, content="hello", model="gpt-4o-mini",
                 finish="stop"):
    return json.dumps({
        "model": model,
        "choices": [{"message": {"role": "assistant", "content": content}, "finish_reason": finish}],
        "usage": {"prompt_tokens": prompt_tokens, "completion_tokens": completion_tokens},
    }).encode("utf-8")


# ══════════════════════════════════════════════════════════════════════════════════════════════════
class RequestKey(unittest.TestCase):
    def test_pure_and_provider_independent(self):
        a = LLMRequest(stage="generation", model="gpt-4o", prompt="brief X", params={"temperature": 0.2})
        b = LLMRequest(stage="generation", model="gpt-4o", prompt="brief X", params={"temperature": 0.2},
                       actor="someone-else", meta={"run_id": "R9"})
        # actor + meta do NOT change the key (they don't change the model output)
        self.assertEqual(request_sha256(a), request_sha256(b))

    def test_key_changes_on_model_params_prompt_system(self):
        base = LLMRequest(stage="generation", model="gpt-4o", prompt="p", system="s", params={"seed": 1})
        k = request_sha256(base)
        self.assertNotEqual(k, request_sha256(LLMRequest(stage="generation", model="gpt-4o-mini",
                                                         prompt="p", system="s", params={"seed": 1})))
        self.assertNotEqual(k, request_sha256(LLMRequest(stage="generation", model="gpt-4o",
                                                         prompt="p2", system="s", params={"seed": 1})))
        self.assertNotEqual(k, request_sha256(LLMRequest(stage="generation", model="gpt-4o",
                                                         prompt="p", system="s2", params={"seed": 1})))
        self.assertNotEqual(k, request_sha256(LLMRequest(stage="generation", model="gpt-4o",
                                                         prompt="p", system="s", params={"seed": 2})))

    def test_empty_prompt_refused(self):
        with self.assertRaises(ValueError):
            LLMRequest(stage="generation", model="m", prompt="   ")

    def test_unknown_stage_refused(self):
        with self.assertRaises(ValueError):
            LLMRequest(stage="wat", model="m", prompt="p")


# ══════════════════════════════════════════════════════════════════════════════════════════════════
class OpenAIAdapter(unittest.TestCase):
    def _provider(self, transport, **kw):
        return OpenAIProvider("gpt-4o-mini", api_key="test-key", transport=transport, **kw)

    def test_success_maps_usage_and_cost_and_sends_correct_payload(self):
        captured = {}

        def transport(url, headers, body):
            captured["url"] = url
            captured["headers"] = headers
            captured["body"] = json.loads(body)
            return 200, _openai_body(100, 50, "the answer")

        p = self._provider(transport)
        req = LLMRequest(stage="generation", model="gpt-4o-mini", prompt="a brief",
                         params={"temperature": 0.3, "max_tokens": 256, "seed": 7})
        resp = p.complete(req)
        # request built correctly
        self.assertEqual(captured["body"]["model"], "gpt-4o-mini")
        self.assertEqual(captured["body"]["messages"], [{"role": "user", "content": "a brief"}])
        self.assertEqual(captured["body"]["temperature"], 0.3)
        self.assertEqual(captured["body"]["max_tokens"], 256)
        self.assertEqual(captured["body"]["seed"], 7)
        self.assertIn("Bearer test-key", captured["headers"]["Authorization"])
        # response mapped
        self.assertEqual(resp.text, "the answer")
        self.assertEqual(resp.input_tokens, 100)
        self.assertEqual(resp.output_tokens, 50)
        self.assertEqual(resp.finish_reason, "stop")
        self.assertAlmostEqual(resp.cost_usd, cost_usd("gpt-4o-mini", 100, 50))
        self.assertGreater(resp.cost_usd, 0)

    def test_missing_key_fails_closed(self):
        import os
        saved = os.environ.pop("OPENAI_API_KEY", None)
        try:
            p = OpenAIProvider("gpt-4o-mini", transport=lambda *a: (200, _openai_body()))
            with self.assertRaises(PermanentError):
                p.complete(LLMRequest(stage="generation", model="gpt-4o-mini", prompt="x"))
        finally:
            if saved is not None:
                os.environ["OPENAI_API_KEY"] = saved

    def test_429_and_5xx_are_transient(self):
        for status in (429, 500, 503):
            p = self._provider(lambda *a, s=status: (s, b'{"error":"x"}'))
            with self.assertRaises(TransientError):
                p.complete(LLMRequest(stage="generation", model="gpt-4o-mini", prompt="x"))

    def test_4xx_is_permanent(self):
        p = self._provider(lambda *a: (400, b'{"error":"bad"}'))
        with self.assertRaises(PermanentError):
            p.complete(LLMRequest(stage="generation", model="gpt-4o-mini", prompt="x"))

    def test_malformed_body_is_permanent(self):
        p = self._provider(lambda *a: (200, b"not json"))
        with self.assertRaises(PermanentError):
            p.complete(LLMRequest(stage="generation", model="gpt-4o-mini", prompt="x"))


# ══════════════════════════════════════════════════════════════════════════════════════════════════
class Caches(unittest.TestCase):
    def test_response_cache_roundtrip_sets_hit(self):
        conn = _mem_store()
        try:
            c = ResponseCache(conn)
            resp = LLMResponse(text="t", model="m", input_tokens=3, output_tokens=4, cost_usd=0.5)
            self.assertIsNone(c.get("k1"))
            c.put("k1", resp)
            got = c.get("k1")
            self.assertEqual(got.text, "t")
            self.assertTrue(got.cache_hit)          # read-time flag
            self.assertIn("k1", c)
        finally:
            conn.close()

    def test_judge_cache_is_family_scoped_no_cross_family_laundering(self):
        # adversarial-verifier fix (R2-1): a verdict is keyed by (item_hash, family, model) and is NEVER served
        # to a DIFFERENT judge family — so a same-actor (non-independent) verdict can't be laundered into a
        # cross-family certification via the cache.
        conn = _mem_store()
        try:
            jc = JudgeCache(conn)
            self.assertIsNone(jc.get("IH1", "openai", "gpt-4o"))
            jc.put("IH1", {"verdict": "accept", "chosen_label": "b"}, family="openai", model="gpt-4o")
            # served for the SAME family+model...
            self.assertEqual(jc.get("IH1", "openai", "gpt-4o")["verdict"], "accept")
            # ...but NEVER for a different family (the laundering path the verifier found)
            self.assertIsNone(jc.get("IH1", "human-review", "human"),
                              "a verdict must never be served across judge families (R2-1)")
            self.assertIsNone(jc.get("IH1", "anthropic", "claude"))
            jc.put("", {"v": 1}, family="openai")       # empty item_hash never caches
            self.assertIsNone(jc.get("", "openai"))
        finally:
            conn.close()


# ══════════════════════════════════════════════════════════════════════════════════════════════════
class _FlakyTransport:
    """A transport that fails `fail_times` with `status` then returns 200. Counts calls."""
    def __init__(self, fail_times, status=503):
        self.fail_times = fail_times
        self.status = status
        self.calls = 0

    def __call__(self, url, headers, body):
        self.calls += 1
        if self.calls <= self.fail_times:
            return self.status, b'{"error":"transient"}'
        return 200, _openai_body(10, 5, "ok")


class QueueRetryAndRecovery(unittest.TestCase):
    def _queue(self, provider, conn, **kw):
        return ExecutionQueue(provider, conn, sleep=_noop_sleep, base_delay=0.0, max_concurrency=1, **kw)

    def test_transient_retried_then_succeeds(self):
        conn = _mem_store()
        try:
            t = _FlakyTransport(fail_times=2)
            p = OpenAIProvider("gpt-4o-mini", api_key="k", transport=t)
            q = self._queue(p, conn, max_retries=3)
            resp = q.execute(LLMRequest(stage="generation", model="gpt-4o-mini", prompt="x"))
            self.assertEqual(resp.text, "ok")
            self.assertEqual(resp.attempt, 3)
            self.assertEqual(t.calls, 3)
        finally:
            conn.close()

    def test_transient_exhausts_retries_and_raises(self):
        conn = _mem_store()
        try:
            t = _FlakyTransport(fail_times=99)
            p = OpenAIProvider("gpt-4o-mini", api_key="k", transport=t)
            q = self._queue(p, conn, max_retries=2)
            with self.assertRaises(TransientError):
                q.execute(LLMRequest(stage="generation", model="gpt-4o-mini", prompt="x"))
            self.assertEqual(t.calls, 3)            # 1 + 2 retries
        finally:
            conn.close()

    def test_permanent_not_retried(self):
        conn = _mem_store()
        try:
            calls = {"n": 0}

            def transport(*a):
                calls["n"] += 1
                return 400, b'{"error":"bad"}'

            p = OpenAIProvider("gpt-4o-mini", api_key="k", transport=transport)
            q = self._queue(p, conn, max_retries=5)
            with self.assertRaises(PermanentError):
                q.execute(LLMRequest(stage="generation", model="gpt-4o-mini", prompt="x"))
            self.assertEqual(calls["n"], 1)
        finally:
            conn.close()

    def test_idempotent_completed_request_never_resent(self):
        conn = _mem_store()
        try:
            fp = FakeProvider("[]")
            q = self._queue(fp, conn)
            reqs = [LLMRequest(stage="generation", model="fake-model", prompt=f"b{i}") for i in range(3)]
            q.run_batch(reqs)
            self.assertEqual(fp.calls, 3)
            # re-run the SAME batch -> all served from cache, provider NOT called again
            q.run_batch(reqs)
            self.assertEqual(fp.calls, 3)
            self.assertEqual(q.pending(), [])       # clean run leaves nothing in-flight
        finally:
            conn.close()

    def test_crash_resume_reads_cache_not_provider(self):
        conn = _mem_store()
        try:
            req = LLMRequest(stage="generation", model="fake-model", prompt="brief")
            key = request_sha256(req)
            # simulate a crash: the response is already cached but exec_queue says 'in_flight'
            ResponseCache(conn).put(key, LLMResponse(text="[]", model="fake-model"))
            conn.execute("INSERT INTO exec_queue (request_sha256, status, updated_at) VALUES (?, 'in_flight', '')",
                         (key,))
            conn.commit()
            self.assertIn(key, ExecutionQueue(FakeProvider("[]"), conn, sleep=_noop_sleep).pending())
            fp = FakeProvider("SHOULD-NOT-BE-CALLED")
            out = self._queue(fp, conn).run_batch([req])
            self.assertEqual(fp.calls, 0)           # resumed from cache, never re-sent
            self.assertEqual(out[0].text, "[]")
            self.assertEqual(conn.execute("SELECT status FROM exec_queue WHERE request_sha256=?",
                                          (key,)).fetchone()[0], "done")
        finally:
            conn.close()

    def test_partial_batch_failure_caches_completed_then_resumes(self):
        conn = _mem_store()
        try:
            ok = LLMRequest(stage="generation", model="fake-model", prompt="ok")
            bad = LLMRequest(stage="generation", model="fake-model", prompt="bad")

            def responder(req):
                if req.prompt == "bad":
                    raise PermanentError("boom")
                return "[]"

            p1 = FakeProvider(responder)
            with self.assertRaises(PermanentError):
                self._queue(p1, conn).run_batch([ok, bad])
            # the good one is cached; a fresh provider re-runs only the failed one
            p2 = FakeProvider("[]")
            self._queue(p2, conn).run_batch([ok, bad])
            self.assertEqual(p2.calls, 1)           # only the previously-failed request
        finally:
            conn.close()


# ══════════════════════════════════════════════════════════════════════════════════════════════════
class BudgetAndCost(unittest.TestCase):
    def test_cost_usd_computed_and_unknown_model_is_zero(self):
        self.assertAlmostEqual(cost_usd("gpt-4o-mini", 1000, 1000), 0.00015 + 0.0006)
        self.assertEqual(cost_usd("no-such-model", 1000, 1000), 0.0)

    def test_budget_cap_refuses_fail_closed_and_caches_completed(self):
        conn = _mem_store()
        try:
            def responder(req):
                return LLMResponse(text="[]", model="fake-model", input_tokens=1, output_tokens=1, cost_usd=1.0)

            fp = FakeProvider(responder)
            budget = Budget(cap_usd=1.5)            # allows exactly 2 calls, refuses the 3rd
            q = ExecutionQueue(fp, conn, budget=budget, sleep=_noop_sleep, max_concurrency=1)
            reqs = [LLMRequest(stage="generation", model="fake-model", prompt=f"b{i}") for i in range(3)]
            with self.assertRaises(BudgetExceeded):
                q.run_batch(reqs)
            self.assertEqual(fp.calls, 2)           # third never started (fail-closed)
            self.assertEqual(conn.execute("SELECT COUNT(*) FROM response_cache").fetchone()[0], 2)
        finally:
            conn.close()

    def test_telemetry_records_and_cache_hit_is_free(self):
        conn = _mem_store()
        try:
            fp = FakeProvider(lambda r: LLMResponse(text="[]", model="fake-model", input_tokens=10,
                                                    output_tokens=5, cost_usd=0.25))
            q = ExecutionQueue(fp, conn, sleep=_noop_sleep, max_concurrency=1)
            req = LLMRequest(stage="generation", model="fake-model", prompt="b", actor="orchestrator",
                             meta={"run_id": "RUN"})
            q.execute(req)                          # live call
            q.execute(req)                          # cache hit
            s = Telemetry(conn).summary("RUN")
            self.assertEqual(s["calls"], 2)
            self.assertEqual(s["cache_hits"], 1)
            self.assertAlmostEqual(s["cost_usd"], 0.25)   # the hit added $0
            # budget can be reloaded from the ledger (crash-resume keeps the running total)
            self.assertAlmostEqual(Budget.from_telemetry(conn, "RUN").spent_usd, 0.25)
        finally:
            conn.close()


# ══════════════════════════════════════════════════════════════════════════════════════════════════
class DeterministicReplay(unittest.TestCase):
    def test_record_then_replay_is_identical(self):
        log = ReplayLog()
        live = FakeProvider(lambda r: LLMResponse(text=f"ans::{r.prompt}", model="gpt-4o", input_tokens=7,
                                                  output_tokens=3, cost_usd=0.02))
        rec = RecordingProvider(live, log)
        req = LLMRequest(stage="generation", model="gpt-4o", prompt="brief-1")
        first = rec.complete(req)
        replay = ReplayProvider(log, name="replay", family="openai")
        second = replay.complete(req)
        self.assertEqual(first.text, second.text)
        self.assertEqual((first.input_tokens, first.output_tokens, first.cost_usd),
                         (second.input_tokens, second.output_tokens, second.cost_usd))

    def test_replay_miss_raises(self):
        log = ReplayLog()
        replay = ReplayProvider(log)
        with self.assertRaises(ReplayMiss):
            replay.complete(LLMRequest(stage="generation", model="gpt-4o", prompt="never recorded"))

    def test_replay_log_persists_to_file(self):
        import tempfile, os
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "replay.jsonl")
            log = ReplayLog(path)
            live = FakeProvider(lambda r: LLMResponse(text="X", model="gpt-4o", input_tokens=1, output_tokens=1))
            RecordingProvider(live, log).complete(LLMRequest(stage="generation", model="gpt-4o", prompt="p"))
            # a brand-new log over the same file reloads the recording
            reloaded = ReplayLog(path)
            self.assertEqual(len(reloaded), 1)
            self.assertEqual(reloaded.get(request_sha256(LLMRequest(stage="generation", model="gpt-4o",
                                                                    prompt="p"))).text, "X")


# ══════════════════════════════════════════════════════════════════════════════════════════════════
class ProvenanceBundles(unittest.TestCase):
    def test_generation_bundle_satisfies_corpus_and_binds_prompt(self):
        req = LLMRequest(stage="generation", model="gpt-4o", prompt="a real brief", actor="orchestrator")
        resp = LLMResponse(text="[]", model="gpt-4o", model_version="gpt-4o", input_tokens=9, output_tokens=4,
                           cost_usd=0.01, latency_ms=1200)
        prov = generation_provenance(req, resp, family="openai")
        CO._require_provenance(prov, kind="generation")          # does not raise
        self.assertTrue(CO.provenance_complete(prov))
        self.assertEqual(prov["prompt_sha256"], PLAN.brief_sha256("a real brief"))
        self.assertEqual(prov["generator_family"], "openai")
        self.assertEqual(prov["contract_version"], PLAN.CONTRACT_VERSION)
        self.assertEqual(prov["input_tokens"], 9)
        self.assertEqual(prov["wall_seconds"], 1.2)

    def test_judge_bundle_satisfies_corpus(self):
        req = LLMRequest(stage="judge", model="human-examiner", prompt="worksheet", actor="human:s")
        resp = LLMResponse(text="[]", model="human-examiner", model_version="v1")
        prov = judge_provenance(req, resp, family="human-review")
        CO._require_provenance(prov, fields=CO._JUDGE_PROVENANCE_FIELDS, kind="judge")   # does not raise
        self.assertEqual(prov["judge_family"], "human-review")
        self.assertEqual(prov["prompt_sha256"], PLAN.brief_sha256("worksheet"))


# ══════════════════════════════════════════════════════════════════════════════════════════════════
def _gen_executor(conn, family="fake-openai"):
    fp = FakeProvider(lambda r: json.dumps([_item("S1")]), name="fake-generator", family=family,
                      model_version="fake-generator-v1")
    return ModelExecutor(fp, model="fake-generator", model_version="fake-generator-v1", actor="orchestrator",
                         conn=conn)


def _judge_responder(req):
    """Return a verdict per candidate_id in the worksheet: accept real items, reject the planted controls
    (so check_judge_controls passes)."""
    out = []
    for line in req.prompt.splitlines():
        line = line.strip()
        if not (line.startswith("{") and '"candidate_id"' in line):
            continue
        try:
            row = json.loads(line)
        except ValueError:
            continue
        cid = row.get("candidate_id")
        if cid is None:
            continue
        if str(cid).startswith("JUDGE_CTRL_"):
            out.append({"candidate_id": cid, "verdict": "reject", "chosen_label": "a",
                        "reasons": "planted bad item caught"})
        else:
            out.append({"candidate_id": cid, "verdict": "accept", "chosen_label": "b"})
    return json.dumps(out)


def _judge_executor(conn):
    fp = FakeProvider(_judge_responder, name="human-examiner", family="human-review",
                      model_version="human-examiner-v1")
    return ModelExecutor(fp, model="human-examiner", model_version="human-examiner-v1", actor="human:surendra",
                         conn=conn)


def _seed_deterministic_evidence(conn, cid):
    """The deterministic CERTIFY layer (no model): a passing gate battery + a sympy 'agree' + the real solution
    stage (solution_verified + distractor_verified). Seeded directly, exactly as the R2 cert test does."""
    CO.record_gates(conn, cid, [
        {"gate": "schema", "ok": True, "severity": GATES.FATAL, "detail": ""},
        {"gate": "dimensional", "ok": True, "severity": GATES.QUARANTINE, "detail": ""},
        {"gate": "relation_grounded", "ok": True, "severity": GATES.QUARANTINE, "detail": ""}])
    CO.record_independent(conn, cid, "sympy_relation_solve", "4", "4", "agree", "ok")
    SOL.ingest(conn, "R", [{"candidate_id": cid, "dispute": False,
                            "solution": {"steps": ["a = F/m = 12/3"], "final": "4"},
                            "distractor_rationale": _DISTRACTORS}])


class EndToEndExecutorIntoFactory(unittest.TestCase):
    def test_generation_path_writes_provenance_and_telemetry(self):
        fconn = CO.open_store(":memory:")
        econn = _mem_store()
        try:
            CO.save_specs(fconn, [_spec_row()])
            m = RG.generate_candidates(fconn, "R", _gen_executor(econn), [_spec_row()], brief="a brief")
            self.assertEqual(m["ingested"], 1)
            cid = CO._cid("R", "S1")
            row = fconn.execute("SELECT model_version, prompt_sha256, payload_sha256, generator_actor, "
                                "contract_version, generator_family FROM candidate WHERE candidate_id=?",
                                (cid,)).fetchone()
            self.assertEqual(row["generator_actor"], "orchestrator")
            self.assertEqual(row["model_version"], "fake-generator-v1")
            self.assertEqual(row["prompt_sha256"], PLAN.brief_sha256("a brief"))
            self.assertEqual(row["generator_family"], "fake-openai")   # from the provider, not the model string
            self.assertTrue(row["payload_sha256"])
            # generation telemetry row exists with a real model + actor
            tel = fconn.execute("SELECT model, actor FROM run_telemetry WHERE run_id='R' AND stage='generation'"
                                ).fetchone()
            self.assertEqual((tel["model"], tel["actor"]), ("fake-generator", "orchestrator"))
        finally:
            fconn.close(); econn.close()

    def test_full_chain_certifies_and_satisfies_require_telemetry(self):
        fconn = CO.open_store(":memory:")
        econn = _mem_store()
        try:
            CO.save_specs(fconn, [_spec_row()])
            # 1) generation stage via the executor
            RG.generate_candidates(fconn, "R", _gen_executor(econn), [_spec_row()], brief="a brief")
            cid = CO._cid("R", "S1")
            # 2) deterministic CERTIFY evidence (gates + sympy + solution) — no model
            _seed_deterministic_evidence(fconn, cid)
            # 3) judge stage via a CROSS-FAMILY executor
            jm = RG.judge_run(fconn, "R", _judge_executor(econn))
            self.assertEqual(jm["in"], 1)
            self.assertEqual(jm["independent"], 1)      # cross-family, computed
            # judge telemetry row exists
            self.assertIsNotNone(fconn.execute(
                "SELECT 1 FROM run_telemetry WHERE run_id='R' AND stage='judge'").fetchone())
            # 4) the PRODUCTION certify entrypoint runs (require_telemetry=True) and certifies the item
            out = CERT.certify_run(fconn, "R", require_telemetry=True)
            self.assertEqual(out["certified"], 1)
            self.assertEqual(len(CO.product_inventory(fconn, "R")), 1)
        finally:
            fconn.close(); econn.close()

    def test_require_telemetry_precondition_is_satisfiable_by_a_real_run(self):
        # even without the deterministic evidence (item won't certify), the model-stage telemetry the executor
        # writes means certify_run(require_telemetry=True) RUNS rather than refusing for missing telemetry.
        fconn = CO.open_store(":memory:")
        econn = _mem_store()
        try:
            CO.save_specs(fconn, [_spec_row()])
            RG.generate_candidates(fconn, "R", _gen_executor(econn), [_spec_row()], brief="a brief")
            RG.judge_run(fconn, "R", _judge_executor(econn))
            CO.require_stage_telemetry(fconn, "R", ("generation", "judge"))   # does not raise
            out = CERT.certify_run(fconn, "R", require_telemetry=True)        # runs; item held (no evidence)
            self.assertEqual(out["certified"], 0)
        finally:
            fconn.close(); econn.close()


class JudgeCacheShortCircuit(unittest.TestCase):
    def test_cached_item_hash_is_not_resent(self):
        econn = _mem_store()
        try:
            ex = _judge_executor(econn)
            # pre-seed the judge cache with a verdict for the real item's content hash, under the SAME judge
            # family+model this executor uses (the cache is family-scoped now — R2-1 laundering fix)
            ex.judge_cache.put("IH_REAL", {"verdict": "accept", "chosen_label": "b"},
                               family=ex.provider.family(), model=ex.model)
            rows = [{"candidate_id": "CAND_real", "stem": "s", "options": {}, "claims": {}}]
            controls = [{k: c[k] for k in ("candidate_id", "class", "subject", "stem", "options", "claims")}
                        for c in JUDGE.judge_control_items()]
            payload, prov = ex.judge(rows, item_hashes={"CAND_real": "IH_REAL"}, brief=JUDGE.JUDGE_BRIEF,
                                     controls=controls)
            # the real item's verdict came from cache; the model saw ONLY the controls
            sent = ex.provider.calls
            self.assertEqual(sent, 1)
            real = [v for v in payload if v["candidate_id"] == "CAND_real"]
            self.assertEqual(real[0]["verdict"], "accept")
            # provenance still well-formed for the judge stage
            CO._require_provenance(prov, fields=CO._JUDGE_PROVENANCE_FIELDS, kind="judge")
        finally:
            econn.close()


if __name__ == "__main__":
    unittest.main()
