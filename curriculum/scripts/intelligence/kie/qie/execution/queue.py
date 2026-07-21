"""The execution queue (R4-2): bounded concurrency + retry/backoff + persistence + crash-resume + budget.

WHAT IT GUARANTEES
  * BOUNDED CONCURRENCY — at most `max_concurrency` model calls run at once (a sliding window of worker threads).
  * RETRY — a TransientError (timeout / 5xx / 429) is retried up to `max_retries` times with EXPONENTIAL backoff
    + optional JITTER; a PermanentError is never retried (fail-closed, surfaced to the caller).
  * IDEMPOTENCE + RESUME — every request is persisted to exec_queue keyed by request_sha256, and its response to
    the ResponseCache. A completed request is NEVER re-sent: on any run (including after a crash) a cached/done
    request is served from the cache, so only work that never completed is re-issued. That is the whole
    failure-recovery story — resume is just "run the same batch again".
  * BUDGET — before STARTING each new call the queue checks the budget; once the cap is hit it starts no more
    calls and raises BudgetExceeded (completed calls are already cached, so a re-run resumes for free).

THREADING DISCIPLINE — sqlite/budget bookkeeping happens ONLY on the calling thread. Worker threads run just the
pure provider-call-with-retry (network I/O); the main thread does cache/queue/telemetry writes and budget
accrual as each future completes. So there is exactly one writer to execution.db — no cross-thread sqlite use.
"""
from __future__ import annotations

import random
import sqlite3
import time
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
from datetime import datetime, timezone
from typing import Callable, List, Optional

from kie.qie.execution.cache import ResponseCache
from kie.qie.execution.provider import (
    LLMRequest, LLMResponse, PermanentError, Provider, TransientError, request_sha256,
)
from kie.qie.execution.telemetry import Budget, BudgetExceeded, Telemetry

QUEUED, IN_FLIGHT, DONE, FAILED = "queued", "in_flight", "done", "failed"


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


class ExecutionQueue:
    def __init__(self, provider: Provider, conn: sqlite3.Connection, *,
                 cache: Optional[ResponseCache] = None, telemetry: Optional[Telemetry] = None,
                 budget: Optional[Budget] = None, max_concurrency: int = 4, max_retries: int = 4,
                 base_delay: float = 0.05, max_delay: float = 8.0, jitter: bool = True,
                 sleep: Callable[[float], None] = time.sleep, rng: Optional[random.Random] = None):
        self.provider = provider
        self.conn = conn
        self.cache = cache if cache is not None else ResponseCache(conn)
        self.telemetry = telemetry if telemetry is not None else Telemetry(conn)
        self.budget = budget
        self.max_concurrency = max(1, int(max_concurrency))
        self.max_retries = max(0, int(max_retries))
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.jitter = jitter
        self._sleep = sleep
        self._rng = rng or random.Random(0)   # seeded -> deterministic jitter for tests

    # ── persistence ────────────────────────────────────────────────────────────────────────────────
    def _mark(self, key: str, status: str, req: LLMRequest, *, attempts: int = None, error: str = None) -> None:
        self.conn.execute(
            "INSERT INTO exec_queue (request_sha256, run_id, stage, status, attempts, request_json, error, "
            "updated_at) VALUES (?,?,?,?,?,?,?,?) "
            "ON CONFLICT(request_sha256) DO UPDATE SET status=excluded.status, "
            "attempts=COALESCE(excluded.attempts, exec_queue.attempts), error=excluded.error, "
            "updated_at=excluded.updated_at",
            (key, req.meta.get("run_id"), req.stage, status, attempts, req.to_json(), error, _now()))
        self.conn.commit()

    def pending(self) -> List[str]:
        """request_sha256s that were started but never reached a terminal state (a crash signature). Purely
        diagnostic — recovery does not need it, because re-running the batch reconciles against the cache."""
        return [r[0] for r in self.conn.execute(
            "SELECT request_sha256 FROM exec_queue WHERE status IN (?,?)", (QUEUED, IN_FLIGHT))]

    # ── the pure, thread-safe call (NO DB, NO budget) ────────────────────────────────────────────────
    def _call_with_retry(self, req: LLMRequest) -> LLMResponse:
        attempt = 0
        while True:
            attempt += 1
            try:
                resp = self.provider.complete(req)
                resp.attempt = attempt
                return resp
            except TransientError:
                if attempt > self.max_retries:
                    raise
                delay = min(self.max_delay, self.base_delay * (2 ** (attempt - 1)))
                if self.jitter:
                    delay += self._rng.random() * self.base_delay
                self._sleep(delay)
            # PermanentError (and anything not TransientError) propagates immediately — never retried.

    # ── single-request convenience (cache + budget + persist, main thread) ───────────────────────────
    def execute(self, req: LLMRequest) -> LLMResponse:
        key = request_sha256(req)
        cached = self.cache.get(key)
        if cached is not None:
            self.telemetry.record(req, cached, request_sha256=key, run_id=req.meta.get("run_id"), cache_hit=True)
            self._mark(key, DONE, req)
            return cached
        if self.budget is not None:
            self.budget.check()                         # fail-closed BEFORE starting the call
        self._mark(key, IN_FLIGHT, req)
        try:
            resp = self._call_with_retry(req)
        except (TransientError, PermanentError) as e:
            self._mark(key, FAILED, req, error=str(e)[:400])
            raise
        if self.budget is not None:
            self.budget.add(resp.cost_usd)
        self.cache.put(key, resp, stage=req.stage)
        self.telemetry.record(req, resp, request_sha256=key, run_id=req.meta.get("run_id"))
        self._mark(key, DONE, req, attempts=resp.attempt)
        return resp

    # ── the batch API ────────────────────────────────────────────────────────────────────────────────
    def run_batch(self, reqs: List[LLMRequest]) -> List[LLMResponse]:
        """Execute a batch with bounded concurrency; return responses in INPUT order. Cached/completed requests
        are reused (idempotent); only never-completed work is sent. Raises BudgetExceeded if the cap blocks
        pending work (completed work is cached — re-run to resume)."""
        results = {}
        to_run = []
        for req in reqs:
            key = request_sha256(req)
            cached = self.cache.get(key)
            if cached is not None:
                self.telemetry.record(req, cached, request_sha256=key, run_id=req.meta.get("run_id"),
                                      cache_hit=True)
                self._mark(key, DONE, req)
                results[key] = cached
            else:
                self._mark(key, QUEUED, req)
                to_run.append((key, req))

        pending = list(to_run)
        in_flight = {}                                  # future -> (key, req)
        refused = 0
        with ThreadPoolExecutor(max_workers=self.max_concurrency) as ex:
            def _fill():
                nonlocal refused
                while pending and len(in_flight) < self.max_concurrency:
                    if self.budget is not None and self.budget.exceeded():
                        break                           # fail-closed: start no more calls
                    key, req = pending.pop(0)
                    self._mark(key, IN_FLIGHT, req)
                    in_flight[ex.submit(self._call_with_retry, req)] = (key, req)

            _fill()
            while in_flight:
                done, _ = wait(list(in_flight.keys()), return_when=FIRST_COMPLETED)
                for fut in done:
                    key, req = in_flight.pop(fut)
                    try:
                        resp = fut.result()
                    except (TransientError, PermanentError) as e:
                        self._mark(key, FAILED, req, error=str(e)[:400])
                        raise
                    if self.budget is not None:
                        self.budget.add(resp.cost_usd)
                    self.cache.put(key, resp, stage=req.stage)
                    self.telemetry.record(req, resp, request_sha256=key, run_id=req.meta.get("run_id"))
                    self._mark(key, DONE, req, attempts=resp.attempt)
                    results[key] = resp
                _fill()

        if pending:                                     # budget stopped us before finishing
            refused = len(pending)
            raise BudgetExceeded(
                f"budget cap reached with {refused} request(s) unstarted — refused fail-closed. Completed calls "
                f"are cached; raise the cap and re-run to resume.")
        return [results[request_sha256(req)] for req in reqs]
