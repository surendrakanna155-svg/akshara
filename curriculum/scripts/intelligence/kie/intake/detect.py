"""Integrity Verification → Duplicate Detection → Version Detection for one file.

Reuses repository_verifier.RepositoryVerifier.verify_file (which reuses
verification_engine._verify_pdf/_sha256) — integrity + hashing are NEVER reimplemented.
Duplicate + version detection query the production KB so the immutable baseline is
never reprocessed: identical content (sha256) already present ⇒ skip; a newer content
for a known logical document ⇒ new version (history preserved, nothing overwritten).
"""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from dataclasses import asdict
from pathlib import Path
from typing import Optional

from kie import config, phase1_verify
from kie.intake.models import Disposition
from kie.intake.store_ext import now_iso

# Reuse the certified verifier (which wraps the certified verification-engine primitives).
sys.path.insert(0, str(config.WORKSPACE / "scripts" / "intelligence"))
from repository_verifier import RepositoryVerifier  # noqa: E402

# year detection is underscore-safe (\b fails around "_2024_" since _ is a word char)
_YEAR_SEARCH = re.compile(r"(?<![0-9])(19|20)\d{2}(?![0-9])")
_YEAR_TOKEN = re.compile(r"^(19|20)\d{2}$")
# marker words that identify a paper variant, not a topic (dropped when grouping versions)
_SESSION_WORDS = ("set", "shift", "paper", "session", "slot", "morning",
                  "evening", "forenoon", "afternoon", "day")


def doc_id_for(sha256: str) -> str:
    return sha256[:16]


def year_from(name: str) -> Optional[int]:
    m = _YEAR_SEARCH.search(name)
    return int(m.group(0)) if m else None


def _drop_token(t: str) -> bool:
    """True for tokens that identify a variant, not the document's topic: years, single
    stray identifiers (Set A → 'a'), and session/shift/paper markers."""
    if _YEAR_TOKEN.match(t):
        return True
    if len(t) == 1:                       # stray set/shift identifiers: a, b, 1, 2
        return True
    return any(t.startswith(w) for w in _SESSION_WORDS)


def lineage_key(category: Optional[str], name: str, explicit: Optional[str] = None) -> str:
    """Deterministic logical-document identity used to chain versions.

    Groups yearly re-releases of the same titled document by tokenizing the basename and
    dropping year + session/shift/set variant markers, then slugging the remainder under the
    coarse category. Heuristic but stable and underscore-safe; callers may pass `explicit` to
    override (e.g. a UI that lets a curator link a file to an existing document lineage).
    Every version decision is human-reviewed, so an occasional mis-group is caught at review.
    """
    if explicit:
        return explicit.strip().lower()
    stem = Path(name).stem.lower()
    tokens = [t for t in re.split(r"[^a-z0-9]+", stem) if t]
    kept = [t for t in tokens if not _drop_token(t)]
    slug = "_".join(kept) or "doc"
    return f"{(category or 'intake').lower()}/{slug}"


# ── verification (reused, per file) ────────────────────────────────────────────────
class IntakeVerifier:
    """Thin adapter over RepositoryVerifier so one loaded engine verifies many files.

    verify_file() only needs `.source` for the relative-path calc, so we point it at each
    file's own parent per call and read the filename back — the integrity/readiness verdict
    is 100% the certified engine's.
    """

    def __init__(self, workspace: Optional[Path] = None):
        self._rv = RepositoryVerifier(workspace or config.WORKSPACE, source_rel="resources/foundation")

    def verify(self, abs_path: Path) -> dict:
        abs_path = Path(abs_path).resolve()
        self._rv.source = abs_path.parent
        return asdict(self._rv.verify_file(abs_path))


_verifier: Optional[IntakeVerifier] = None


def verify_file(abs_path: Path) -> dict:
    """Integrity + parser-readiness verdict for one local file (reused engine)."""
    global _verifier
    if _verifier is None:
        _verifier = IntakeVerifier()
    return _verifier.verify(abs_path)


# ── duplicate + version detection (against the production KB) ───────────────────────
def _version_head(conn, lineage: str) -> Optional[dict]:
    row = conn.execute(
        "SELECT doc_id, version_no, sha256 FROM document_versions "
        "WHERE lineage_key = ? ORDER BY version_no DESC LIMIT 1",
        (lineage,),
    ).fetchone()
    return dict(row) if row else None


def classify_source(prod_conn, verdict: dict, category: str, name: str,
                    explicit_lineage: Optional[str] = None) -> dict:
    """Verify → dedup → version. Returns a detection record for one file.

    Keys: disposition, verify_status, certify_status, certify_reason, lineage_key,
    version_of, version_no, existing_doc_id, doc_id, year.
    """
    sha = verdict["sha256"]
    did = doc_id_for(sha)
    lk = lineage_key(category, name, explicit_lineage)
    verify_status, certify_status, certify_reason = phase1_verify.classify(verdict)

    base = {
        "doc_id": did, "verify_status": verify_status, "certify_status": certify_status,
        "certify_reason": certify_reason, "lineage_key": lk, "year": year_from(name),
        "version_of": None, "version_no": None, "existing_doc_id": None,
    }

    # 1) Integrity gate — corrupt/encrypted never enter the pipeline (D-5 quarantine).
    if certify_status == "quarantined":
        base["disposition"] = Disposition.QUARANTINED
        return base

    # 2) Exact duplicate — identical content already certified in the production KB.
    row = prod_conn.execute(
        "SELECT doc_id FROM source_documents WHERE sha256 = ?", (sha,)
    ).fetchone()
    if row:
        base["disposition"] = Disposition.EXACT_DUPLICATE
        base["existing_doc_id"] = row["doc_id"]
        return base

    # 3) Version detection — newer content for a known logical document lineage.
    head = _version_head(prod_conn, lk)
    if head and head["sha256"] != sha:
        base["disposition"] = Disposition.NEW_VERSION
        base["version_of"] = head["doc_id"]
        base["version_no"] = head["version_no"] + 1
        return base

    base["disposition"] = Disposition.NEW
    base["version_no"] = 1
    return base


# ── one-time baseline enablement (optional; additive control-table writes only) ─────
def register_baseline_lineage(conn) -> int:
    """Register every certified production document into document_versions so later yearly
    updates are detected as new versions of the PRE-EXISTING corpus.

    Idempotent + additive: writes only the control table, never content. Within a lineage,
    docs are ordered by (year, doc_id) and chained old→new (superseded_by). Returns rows added.
    """
    already = {r[0] for r in conn.execute("SELECT doc_id FROM document_versions").fetchall()}
    groups: dict[str, list] = defaultdict(list)
    for r in conn.execute(
        "SELECT doc_id, rel_path, category, sha256, year FROM source_documents "
        "WHERE certify_status = 'certified' ORDER BY doc_id"
    ).fetchall():
        if r["doc_id"] in already:
            continue
        lk = lineage_key(r["category"], Path(r["rel_path"]).name)
        groups[lk].append(dict(r))

    added = 0
    for lk, docs in sorted(groups.items()):
        # continue numbering after any versions already registered for this lineage
        head = _version_head(conn, lk)
        start = (head["version_no"] + 1) if head else 1
        docs.sort(key=lambda d: (d["year"] or 0, d["doc_id"]))
        for i, d in enumerate(docs):
            vno = start + i
            nxt = docs[i + 1]["doc_id"] if i + 1 < len(docs) else None
            conn.execute(
                "INSERT OR IGNORE INTO document_versions"
                "(version_id, lineage_key, doc_id, version_no, sha256, year, source_item, superseded_by, created_at)"
                " VALUES (?,?,?,?,?,?,?,?,?)",
                (f"{lk}@v{vno}", lk, d["doc_id"], vno, d["sha256"], d["year"], None, nxt, now_iso()),
            )
            added += 1
    conn.commit()
    return added
