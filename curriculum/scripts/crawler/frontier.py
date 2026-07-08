#!/usr/bin/env python3
"""Resumable URL frontier for the continuous acquisition crawler.

Canonical requirement: docs/curriculum-intelligence/planning/CRAWLER_SPEC.md
(§Discovery, §Per-resource pipeline, §Constraints).

Two dedup layers, per spec — "never download the same resource twice ...
dedup by normalized URL AND by sha256 across the archive":

  1. ``normalize_url()`` collapses trivial URL variants (case, default port,
     trailing slash, query-param order, fragment) to one canonical key so the
     same page/asset discovered via two paths (sitemap + link-following) is
     only ever queued once.
  2. ``known_hashes`` is a sha256 -> provenance registry, folded in from the
     existing on-disk archive plus every resource this crawler has ever
     verified. It lets the orchestrator recognise content that is already in
     the repository under a different URL (mirrors, re-published copies)
     without re-downloading it.

State persists to a single JSON file (``crawler_state.json`` by convention)
so a killed/restarted process resumes exactly where it left off: queued
items are not re-seeded, visited items are not re-crawled, known hashes are
not re-verified.

Stdlib-only by design (reproducibility) — mirrors the idiom of
``verification_engine.py`` / ``common/workspace.py``.
"""

from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


def normalize_url(url: str) -> str:
    """Canonical dedup key: lowercase scheme/host, strip default port and
    fragment, drop a single trailing slash, sort query params."""
    parts = urlsplit((url or "").strip())
    scheme = (parts.scheme or "https").lower()
    host = (parts.hostname or "").lower()
    netloc = host
    if parts.port and not ((scheme == "http" and parts.port == 80) or (scheme == "https" and parts.port == 443)):
        netloc = f"{host}:{parts.port}"
    path = parts.path or "/"
    if len(path) > 1 and path.endswith("/"):
        path = path.rstrip("/")
    query = urlencode(sorted(parse_qsl(parts.query, keep_blank_values=True)))
    return urlunsplit((scheme, netloc, path, query, ""))


class Frontier:
    """Queued/visited/known-hash state for one crawl workspace."""

    def __init__(self, state_path: Path | None = None):
        self.state_path = Path(state_path) if state_path else None
        self.queued: dict[str, dict] = {}
        self.visited: dict[str, dict] = {}
        self.known_hashes: dict[str, dict] = {}
        self.seq_counters: dict[str, int] = {}

    # ------------------------------------------------------------ persistence

    @classmethod
    def load(cls, state_path: Path) -> "Frontier":
        """Load prior state if present; otherwise start empty (never raises —
        a missing state file just means this is the first run)."""
        fr = cls(state_path)
        path = Path(state_path)
        if path.exists():
            data = json.loads(path.read_text(encoding="utf-8"))
            fr.queued = data.get("queued", {})
            fr.visited = data.get("visited", {})
            fr.known_hashes = data.get("known_hashes", {})
            fr.seq_counters = data.get("seq_counters", {})
        return fr

    def save(self, state_path: Path | None = None) -> None:
        path = Path(state_path or self.state_path)
        if path is None:
            raise ValueError("no state_path given to Frontier.save()")
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(path.suffix + ".tmp")
        payload = {
            "queued": self.queued,
            "visited": self.visited,
            "known_hashes": self.known_hashes,
            "seq_counters": self.seq_counters,
        }
        with tmp.open("w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2, ensure_ascii=False)
        tmp.replace(path)

    # ---------------------------------------------------------------- queue

    def seen(self, url: str) -> bool:
        n = normalize_url(url)
        return n in self.queued or n in self.visited

    def add(self, url: str, *, depth: int = 0, kind: str = "page",
            discovered_via: str = "", board: str = "", meta: dict | None = None) -> bool:
        """Enqueue ``url`` unless it is already queued or visited.

        Returns True if this call actually added a new frontier entry (useful
        for seeding/discovery stats), False if it was already known.
        """
        n = normalize_url(url)
        if n in self.queued or n in self.visited:
            return False
        self.queued[n] = {
            "url": url,
            "depth": depth,
            "kind": kind,  # "sitemap" | "page" | "resource"
            "discovered_via": discovered_via,
            "board": board,
            "meta": meta or {},
        }
        return True

    def pop(self) -> dict | None:
        """FIFO pop (dict preserves insertion order); None when empty."""
        if not self.queued:
            return None
        key = next(iter(self.queued))
        rec = self.queued.pop(key)
        rec = dict(rec)
        rec["_key"] = key
        return rec

    def requeue(self, rec: dict) -> None:
        """Put a popped record back at the tail (e.g. a retry-pending fetch)."""
        key = rec.get("_key") or normalize_url(rec["url"])
        clean = {k: v for k, v in rec.items() if k != "_key"}
        self.queued[key] = clean

    def mark_visited(self, url: str, status: str, **extra) -> None:
        n = normalize_url(url)
        self.queued.pop(n, None)
        entry = self.visited.get(n, {})
        entry.update({"url": url, "status": status})
        entry.update(extra)
        self.visited[n] = entry

    # ------------------------------------------------------------- sha256

    def has_hash(self, sha256: str) -> bool:
        return bool(sha256) and sha256 in self.known_hashes

    def record_hash(self, sha256: str, **info) -> None:
        if not sha256:
            return
        entry = self.known_hashes.get(sha256, {})
        entry.update(info)
        self.known_hashes[sha256] = entry

    # ------------------------------------------------------------ sequence

    def next_seq(self, key: str) -> int:
        """Persisted per-key counter (board-class-subject-category) so
        resource IDs keep incrementing across a resumed run instead of
        colliding at 1 every restart."""
        self.seq_counters[key] = self.seq_counters.get(key, 0) + 1
        return self.seq_counters[key]

    # ----------------------------------------------------------------- misc

    def stats(self) -> dict:
        return {
            "queued": len(self.queued),
            "visited": len(self.visited),
            "known_hashes": len(self.known_hashes),
        }
