"""RateLimitedProvider — a throughput governor wrapping any Provider (R4-2 seam, additive).

Enforces a MINIMUM interval between the START of consecutive `complete()` calls, i.e. a maximum request rate
(`requests_per_min`). It is a transparent decorator: `name()` and `family()` delegate to the inner provider, so
wrapping the OpenRouter judge still reports family 'anthropic' and the cross-family gate is unaffected. The clock
and sleep are injectable so the throttle is unit-testable with NO real waiting.

This composes with — and does not replace — the queue's BUDGET (fail-closed hard cap) and bounded concurrency:
budget bounds SPEND, concurrency bounds PARALLELISM, this bounds RATE. Owner-approved for the Program C
controlled run (5 requests/minute).
"""
from __future__ import annotations

import threading
import time
from typing import Callable, Optional

from kie.qie.execution.provider import LLMRequest, LLMResponse, Provider


class RateLimitedProvider(Provider):
    def __init__(self, inner: Provider, *, requests_per_min: Optional[float] = None,
                 min_interval_s: Optional[float] = None,
                 clock: Callable[[], float] = time.monotonic, sleep: Callable[[float], None] = time.sleep):
        if min_interval_s is None:
            min_interval_s = (60.0 / float(requests_per_min)) if requests_per_min else 0.0
        self.inner = inner
        self.min_interval_s = max(0.0, float(min_interval_s))
        self._clock = clock
        self._sleep = sleep
        self._lock = threading.Lock()
        self._last_start: Optional[float] = None

    def name(self) -> str:
        return self.inner.name()

    def family(self) -> str:
        return self.inner.family()

    def _throttle(self) -> None:
        # serialize the gap computation so N concurrent workers still respect one global rate; with the approved
        # concurrency of 1 there is no contention, but this keeps the governor correct if concurrency is raised.
        with self._lock:
            if self.min_interval_s > 0 and self._last_start is not None:
                wait = self.min_interval_s - (self._clock() - self._last_start)
                if wait > 0:
                    self._sleep(wait)
            self._last_start = self._clock()

    def complete(self, req: LLMRequest) -> LLMResponse:
        self._throttle()
        return self.inner.complete(req)
