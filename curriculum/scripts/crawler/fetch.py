#!/usr/bin/env python3
"""Polite per-host downloader for the continuous acquisition crawler.

Canonical requirement: docs/curriculum-intelligence/planning/CRAWLER_SPEC.md
(§Constraints — "Per-domain rate limits (polite delay per host; parallelize
ACROSS domains, not within)"; §Per-resource pipeline — "auto-retry failures
(backoff)").

This module only gets bytes onto disk and reports the HTTP outcome; it never
re-implements verification (that is exactly ``verify.py`` + the shared
``verification_engine``'s job — the spec forbids duplicating V1-V11 logic).

Stdlib-only (urllib). Defaults mirror ``curriculum/configs/download_rules.json``
/ ``retry_rules.json`` so the crawler's networking policy stays consistent with
the existing catalogue-driven download lane (same user-agent, same politeness,
same retryable HTTP statuses) — see those configs for the source of truth.
"""

from __future__ import annotations

import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import quote, urlsplit, urlunsplit

DEFAULT_USER_AGENT = "AksharaCurriculumBot/1.0 (+education-repository; contact: akshara-erp)"
DEFAULT_RETRY_STATUS = frozenset({408, 425, 429, 500, 502, 503, 504})


def normalize_url(url: str) -> str:
    """Percent-encode a real-world URL so ``urllib`` accepts it.

    Official sites (e.g. CBSE) publish links with UNENCODED spaces / control
    chars in the path — valid resources, invalid HTTP request-lines. Quote the
    path + query (idempotent: ``%`` is left safe so already-encoded URLs aren't
    double-encoded). Malformed-but-fixable → fetchable; genuinely broken → the
    caller's broad guard records it as a failure rather than crashing the crawl.
    """
    parts = urlsplit(url)
    safe_path = quote(parts.path, safe="/%:@&=+$,;~()*!'")
    safe_query = quote(parts.query, safe="/%:@&=+$,;~()*!'?")
    return urlunsplit((parts.scheme, parts.netloc, safe_path, safe_query, parts.fragment))


@dataclass
class FetchResult:
    ok: bool
    url: str
    status: int | None = None
    reason: str = ""
    headers: dict = field(default_factory=dict)
    body: bytes | None = None
    path: Path | None = None
    attempts: int = 0


class Fetcher:
    """One instance per crawl run; tracks last-request time per host so
    consecutive requests to the same host are always >= ``polite_delay_seconds``
    apart, however interleaved the frontier's URL order is."""

    def __init__(self, *, user_agent: str = DEFAULT_USER_AGENT,
                 polite_delay_seconds: float = 2.0, connect_timeout: float = 30.0,
                 max_attempts: int = 3, backoff_seconds: tuple[float, ...] = (2.0, 8.0, 30.0),
                 retry_status: frozenset[int] = DEFAULT_RETRY_STATUS,
                 chunk_bytes: int = 1 << 20):
        self.user_agent = user_agent
        self.polite_delay_seconds = polite_delay_seconds
        self.connect_timeout = connect_timeout
        self.max_attempts = max_attempts
        self.backoff_seconds = backoff_seconds
        self.retry_status = retry_status
        self.chunk_bytes = chunk_bytes
        self._last_request_at: dict[str, float] = {}

    @staticmethod
    def _host(url: str) -> str:
        return (urlsplit(url).hostname or "").lower()

    def _wait_polite(self, url: str) -> None:
        host = self._host(url)
        last = self._last_request_at.get(host)
        if last is not None:
            remaining = self.polite_delay_seconds - (time.monotonic() - last)
            if remaining > 0:
                time.sleep(remaining)
        self._last_request_at[host] = time.monotonic()

    def _open(self, url: str, method: str) -> FetchResult:
        try:
            safe = normalize_url(url)
            req = urllib.request.Request(safe, method=method, headers={"User-Agent": self.user_agent})
            with urllib.request.urlopen(req, timeout=self.connect_timeout) as resp:
                body = resp.read() if method == "GET" else b""
                return FetchResult(ok=True, url=url, status=resp.status,
                                    headers=dict(resp.headers), body=body)
        except urllib.error.HTTPError as exc:
            return FetchResult(ok=False, url=url, status=exc.code, reason=str(exc),
                                headers=dict(exc.headers or {}))
        except urllib.error.URLError as exc:
            return FetchResult(ok=False, url=url, status=None, reason=str(exc.reason))
        except (TimeoutError, OSError) as exc:
            return FetchResult(ok=False, url=url, status=None, reason=str(exc))
        except Exception as exc:  # noqa: BLE001 — a single bad URL must NEVER kill the crawl
            return FetchResult(ok=False, url=url, status=None,
                                reason=f"unfetchable ({type(exc).__name__}): {exc}")

    def _with_retry(self, url: str, method: str) -> FetchResult:
        result = FetchResult(ok=False, url=url, reason="not attempted")
        for attempt in range(self.max_attempts):
            self._wait_polite(url)
            result = self._open(url, method)
            result.attempts = attempt + 1
            if result.ok:
                return result
            if result.status is not None and result.status not in self.retry_status:
                break  # non-retryable outcome (404, 403, ...) — no point burning attempts
            if attempt < self.max_attempts - 1:
                time.sleep(self.backoff_seconds[min(attempt, len(self.backoff_seconds) - 1)])
        return result

    def head(self, url: str) -> FetchResult:
        """HEAD-before-GET probe (spec §Discovery.3 direct-PDF probing)."""
        return self._with_retry(url, "HEAD")

    def get(self, url: str) -> FetchResult:
        return self._with_retry(url, "GET")

    def get_to_file(self, url: str, dest: Path) -> FetchResult:
        result = self.get(url)
        if result.ok and result.body is not None:
            dest = Path(dest)
            dest.parent.mkdir(parents=True, exist_ok=True)
            with dest.open("wb") as fh:
                for i in range(0, len(result.body), self.chunk_bytes):
                    fh.write(result.body[i:i + self.chunk_bytes])
            result.path = dest
        return result

    def text(self, url: str) -> str | None:
        result = self.get(url)
        if result.ok and result.body is not None:
            return result.body.decode("utf-8", "replace")
        return None
