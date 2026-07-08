#!/usr/bin/env python3
"""The crawler's own resumable ledger.

Canonical requirement: docs/curriculum-intelligence/planning/CRAWLER_SPEC.md
(§Manifest) — ``curriculum/acquisition/crawler_manifest.json``, one record per
discovered resource, columns:

    Resource · Board · Class · Subject · URL · Status · Verification ·
    Last-checked · Retry-count

(+ sha256, bytes, local_path, discovered_via, evidence).

This is separate from — but fed by — the existing pipeline's
``indexes/master_index.json`` (owned by ``verification_engine.py``): this file
is the crawler's single source of truth for "what have we ever discovered,
and what happened to it", so a resumed run never re-enqueues or re-downloads
a resource it already knows about. Per spec: "Dashboard reports Downloaded
AND Verified separately; only Verified counts %" — see ``summary()``.
"""

from __future__ import annotations

import json
from pathlib import Path

COLUMNS = [
    "Resource", "Board", "Class", "Subject", "URL", "Status",
    "Verification", "Last-checked", "Retry-count",
]


def load(path: Path) -> dict:
    path = Path(path)
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {}


def save(path: Path, records: dict) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as fh:
        json.dump(records, fh, indent=2, ensure_ascii=False, sort_keys=True)
    tmp.replace(path)


def upsert(records: dict, resource_id: str, *, board: str, class_label: str, subject: str,
           url: str, status: str, verification: str, last_checked: str, retry_count: int = 0,
           sha256: str | None = None, bytes_: int | None = None, local_path: str | None = None,
           discovered_via: str = "", evidence: str = "") -> dict:
    """Create-or-update one manifest row, keyed by ``resource_id``.

    Fields that aren't provided on an update (sha256/bytes/local_path) keep
    their previous value rather than being blanked out, so a RETRY_PENDING ->
    FAILED transition doesn't erase provenance recorded on an earlier attempt.
    """
    rec = records.get(resource_id, {})
    rec.update({
        "Resource": resource_id,
        "Board": board,
        "Class": class_label,
        "Subject": subject,
        "URL": url,
        "Status": status,
        "Verification": verification,
        "Last-checked": last_checked,
        "Retry-count": retry_count,
        "sha256": sha256 if sha256 is not None else rec.get("sha256"),
        "bytes": bytes_ if bytes_ is not None else rec.get("bytes"),
        "local_path": local_path if local_path is not None else rec.get("local_path"),
        "discovered_via": discovered_via or rec.get("discovered_via", ""),
        "evidence": evidence or rec.get("evidence", ""),
    })
    records[resource_id] = rec
    return rec


def summary(records: dict) -> dict:
    """Downloaded and Verified are reported SEPARATELY; only Verified counts
    toward ``verified_pct_of_discovered`` (spec §Verification gate)."""
    total = len(records)
    downloaded = sum(1 for r in records.values() if r.get("Status") in ("DOWNLOADED", "VERIFIED"))
    verified = sum(1 for r in records.values() if r.get("Verification") == "VERIFIED")
    failed = sum(1 for r in records.values() if r.get("Status") == "FAILED")
    retry_pending = sum(1 for r in records.values() if r.get("Status") == "RETRY_PENDING")
    missing = sum(1 for r in records.values() if r.get("Status") == "NOT_PUBLICLY_AVAILABLE")

    by_board: dict[str, int] = {}
    for r in records.values():
        if r.get("Verification") == "VERIFIED":
            board = r.get("Board", "?")
            by_board[board] = by_board.get(board, 0) + 1

    return {
        "total_discovered": total,
        "downloaded": downloaded,
        "verified": verified,
        "failed": failed,
        "retry_pending": retry_pending,
        "not_publicly_available": missing,
        "verified_pct_of_discovered": round(100.0 * verified / total, 1) if total else 0.0,
        "verified_by_board": by_board,
    }
