"""Knowledge Index schema ownership — open, migrate, and record progress.

Single place that knows how to bring a knowledge_index.db up to the current schema. `index_schema.sql`
describes a FRESH database; this module carries the ALTERs that move an EXISTING one forward without
losing rows. Owner rule 9: the index must stay stable as new editions, books and boards arrive, so
schema movement is a first-class, tested operation — not a hand-run one-off.

v1 -> v2 adds the second dimension (academic_discipline) alongside the proven one (subject), plus the
mention/gap/progress tables. v1 rows are Mathematics from single-subject books, where the curriculum
subject and the academic discipline are the same thing and provable from the filename code — so the
back-fill below is a statement of fact, not an inference.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

SCHEMA_PATH = Path(__file__).resolve().parent / "index_schema.sql"
SCHEMA_VERSION = "2"

# ── Freeze / integrity constants (R1-4 / R1-5) ──────────────────────────────────────────────────────
# The unfreeze hatch: a frozen (immutable=='true') index may only be opened for WRITING when a sanctioned
# versioned rebuild sets this env var (or passes unfreeze=True). Every ordinary read path uses open_index_ro.
_UNFREEZE_ENV = "KIE_ALLOW_FROZEN_WRITE"

# The certified-knowledge fingerprint — a pure function of the CERTIFIED records' 7 identity fields.
# This is the recorded freeze anchor (certified_knowledge_fingerprint_vX); recomputing it and comparing
# to the newest versioned key is what makes a silent content mutation detectable (R1-5, RI-1). The field
# set is FROZEN across versions so RI-1 stays valid after a version bump (substrate drift is caught by the
# SEPARATE substrate fingerprint below, not by mutating this tuple).
CONTENT_FP_COLS = ("concept_id", "canonical_name", "subject", "taught_at_class",
                   "academic_discipline", "section_heading", "evidence_chunks")
CONTENT_FP_METHOD = ("sha256 of newline-joined sorted 'concept_id|canonical_name|subject|taught_at_class|"
                     "academic_discipline|section_heading|evidence_chunks' over certified rows")

# The substrate fingerprint — a content-address of kie.db's chunks (chunk_id + sha256). It changes iff a
# chunk is added, removed, or its text changes (the Jul-18 re-chunk event), so certification/planning can
# REFUSE when the live substrate no longer matches what a version froze against (R1-4, C3).
SUBSTRATE_FP_METHOD = "sha256 of newline-joined sorted 'chunk_id|sha256' over all kie.db chunks"

# Legacy artefacts a sanctioned version bump removes: the 12 'proposed' qdi_* rows that live INSIDE the
# index (contradicted by, and a re-seed hazard for, the real writable qdi.db) and the stale UNVERSIONED
# fingerprint key (held a 3-version-old v1.2 hash) + the superseded certified_at_freeze legacy count.
_LEGACY_QDI_TABLES = ("qdi_scope_link", "qdi_rejected", "qdi_pattern", "qdi_source", "qdi_meta")
_LEGACY_META_KEYS = ("certified_knowledge_fingerprint", "certified_at_freeze")


class FrozenIndexError(RuntimeError):
    """Raised when code tries to open a frozen (immutable) knowledge index for WRITING outside a
    sanctioned versioned rebuild. The freeze is mechanical, not advisory (R1-5, C6)."""


class SubstrateDriftError(RuntimeError):
    """Raised (fail-closed) when the live kie.db substrate no longer matches the fingerprint a knowledge
    version froze against — a cited chunk was added/removed/changed since certification (R1-4, C3)."""


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def is_immutable(conn: sqlite3.Connection) -> bool:
    """True iff ki_meta records immutable='true'. Safe on a fresh db (ki_meta may not exist yet)."""
    try:
        r = conn.execute("SELECT value FROM ki_meta WHERE key='immutable'").fetchone()
    except sqlite3.OperationalError:
        return False
    return bool(r and str(r[0]).lower() == "true")


def frozen_version(conn: sqlite3.Connection) -> str:
    """The recorded frozen version tag (e.g. 'v1.4'), or 'unknown'. Shared so every consumer resolves the
    versioned ki_meta keys the same way (RI-1, substrate check)."""
    try:
        r = conn.execute("SELECT value FROM ki_meta WHERE key='frozen_version'").fetchone()
    except sqlite3.OperationalError:
        return "unknown"
    return r[0] if r else "unknown"


def certified_content_fingerprint(conn: sqlite3.Connection) -> str:
    """Recompute the certified-knowledge fingerprint (CONTENT_FP_METHOD). Positional field read so it is
    independent of row_factory. Reproduces v1.4's e3a146f3… over the 2023 live certified rows."""
    cur = conn.execute(
        f"SELECT {','.join(CONTENT_FP_COLS)} FROM ki_concept WHERE status='certified'")
    lines = ["|".join("" if v is None else str(v) for v in row) for row in cur]
    return hashlib.sha256("\n".join(sorted(lines)).encode("utf-8")).hexdigest()


def compute_substrate_fingerprint(kconn: sqlite3.Connection) -> str:
    """Content-address the substrate: sha256 over sorted 'chunk_id|sha256' pairs of every kie.db chunk.
    Immune to VACUUM/reindex; changes only on a real chunk add/remove/text-change."""
    cur = kconn.execute("SELECT chunk_id, sha256 FROM chunks")
    lines = [f"{cid}|{sha}" for cid, sha in cur]
    return hashlib.sha256("\n".join(sorted(lines)).encode("utf-8")).hexdigest()


def assert_substrate_matches_freeze(iconn: sqlite3.Connection, kie_path: Optional[str] = None) -> str:
    """Fail-closed guard for certification/planning: refuse when the live substrate no longer matches the
    fingerprint the index froze against. Absence of a recorded substrate fingerprint (a pre-R1-4 index)
    is itself a refusal — never 'assume fine'. Returns the verified fingerprint on success."""
    from kie import config
    ver = frozen_version(iconn)
    row = iconn.execute("SELECT value FROM ki_meta WHERE key=?",
                        (f"substrate_fingerprint_{ver}",)).fetchone()
    if row is None:
        raise SubstrateDriftError(
            f"index has no recorded substrate fingerprint for {ver} (predates substrate fingerprinting / "
            f"v1.5) — refusing to certify or plan against an unverified substrate (fail-closed)")
    kp = str(kie_path or config.DB_PATH)
    kconn = sqlite3.connect(f"file:{kp}?mode=ro", uri=True)
    try:
        have = compute_substrate_fingerprint(kconn)
    finally:
        kconn.close()
    if have != row[0]:
        raise SubstrateDriftError(
            f"kie.db substrate drifted since the {ver} freeze: live {have[:12]}… != recorded {row[0][:12]}…")
    return have


def legacy_qdi_proposed_from_index(index_conn: sqlite3.Connection) -> list:
    """SAFE reader for the legacy analyst-seed patterns that USED to live inside knowledge_index.db.

    A sanctioned version bump DROPs those qdi_* tables (the writable qdi.db is the real design-intelligence
    lane). This accessor returns [] when they are absent so a caller can never crash on the missing table.
    NOTE (cross-lane, R1-5): run_qdi.import_proposed_from_index still runs a RAW
    `SELECT * FROM qdi_pattern WHERE status='proposed'` on the index — it must be routed through this
    accessor (or wrapped in try/except sqlite3.OperationalError) before the v1.5 drop lands."""
    try:
        return index_conn.execute("SELECT * FROM qdi_pattern WHERE status='proposed'").fetchall()
    except sqlite3.OperationalError:
        return []


def sanitize_legacy(conn: sqlite3.Connection) -> dict:
    """Remove stale artefacts during a sanctioned version bump (idempotent). DROPs the index-resident qdi_*
    tables and DELETEs the unversioned fingerprint + legacy count keys. FK checks are disabled for the drop
    (children are dropped before parents anyway) so it is safe regardless of qdi_* relationships."""
    conn.execute("PRAGMA foreign_keys = OFF")
    dropped = []
    for t in _LEGACY_QDI_TABLES:
        conn.execute(f"DROP TABLE IF EXISTS {t}")
        dropped.append(t)
    conn.execute("PRAGMA foreign_keys = ON")
    q = ",".join("?" * len(_LEGACY_META_KEYS))
    removed = conn.execute(f"DELETE FROM ki_meta WHERE key IN ({q})", _LEGACY_META_KEYS).rowcount
    return {"dropped_tables": dropped, "meta_keys_removed": removed}


def _columns(conn: sqlite3.Connection, table: str) -> set:
    try:
        return {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}
    except sqlite3.Error:
        return set()


def _add_column(conn: sqlite3.Connection, table: str, column: str, decl: str) -> bool:
    """Idempotent ALTER. Returns True if the column was actually added."""
    if not _columns(conn, table) or column in _columns(conn, table):
        return False
    conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {decl}")
    return True


def migrate(conn: sqlite3.Connection) -> dict:
    """Bring an existing index up to SCHEMA_VERSION. Safe to run on a fresh or already-current db."""
    changed = {"columns_added": [], "backfilled": 0}

    for table, column, decl in (
        ("ki_source", "is_integrated", "INTEGER NOT NULL DEFAULT 0"),
        ("ki_chapter", "academic_discipline", "TEXT"),
        ("ki_chapter", "discipline_basis", "TEXT"),
        ("ki_chapter", "discipline_confidence", "REAL"),
        ("ki_chapter", "discipline_audit_verdict", "TEXT"),
        ("ki_chapter", "discipline_audit_model", "TEXT"),
        ("ki_concept", "extraction_basis", "TEXT"),
        ("ki_concept", "academic_discipline", "TEXT"),
        ("ki_concept", "discipline_basis", "TEXT"),
        ("ki_concept", "discipline_confidence", "REAL"),
        # v3 — evidence_gap is NOT out_of_scope. Engineers wrote "X is not printed in this evidence" into
        # boundary.out_of_scope, which INVERTS that field's meaning: out_of_scope tells a generator the class
        # does not cover X, so a consumer reading it literally refuses topics that ARE in the syllabus
        # (Henry's law, Faraday's laws, reducing a fraction by HCF). Evidence gaps get their own field so
        # out_of_scope stays a pure curriculum boundary and nothing is lost.
        ("ki_concept", "evidence_gap", "TEXT"),
        # R1-4 — content-addressed evidence. json[] of hex sha256, INDEX-ALIGNED to evidence_chunks: element
        # i is the chunks.sha256 of evidence_chunks[i] at promotion time. Additive, so v1.4's evidence_chunks
        # bytes and certified_knowledge_fingerprint are untouched; it makes substrate drift detectable that
        # the bare positional doc_id#ordinal ref could not.
        ("ki_concept", "evidence_sha256", "TEXT"),
    ):
        if _add_column(conn, table, column, decl):
            changed["columns_added"].append(f"{table}.{column}")

    # v1 back-fill: every v1 row came from a single-subject book admitted ONLY because its filename
    # code proved the subject. For those, discipline == subject by proof, at full confidence.
    for table in ("ki_chapter", "ki_concept"):
        if "academic_discipline" not in _columns(conn, table):
            continue
        cur = conn.execute(
            f"UPDATE {table} SET academic_discipline = subject, "
            f"discipline_basis = 'single-subject NCERT book: the filename code proves the subject, so the "
            f"academic discipline is the same claim (no inference)', "
            f"discipline_confidence = 1.0 "
            f"WHERE academic_discipline IS NULL "
            f"AND subject IN ('Mathematics','Physics','Chemistry','Biology')")
        changed["backfilled"] += cur.rowcount

    changed["evidence_gaps_split"] = split_evidence_gaps(conn)

    # indexes on v2 columns — only creatable once the ALTERs above have run
    conn.execute("CREATE INDEX IF NOT EXISTS idx_ki_ch_disc ON ki_chapter(academic_discipline, taught_at_class)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_ki_c_disc "
                 "ON ki_concept(academic_discipline, taught_at_class, status)")

    conn.execute("INSERT OR REPLACE INTO ki_meta (key, value) VALUES ('schema_version', ?)",
                 (SCHEMA_VERSION,))
    conn.execute("INSERT OR REPLACE INTO ki_meta (key, value) VALUES ('schema_migrated_at', ?)", (now(),))
    conn.commit()
    return changed


# "X is not printed in this evidence" is an EVIDENCE GAP (the class still teaches X, our OCR just missed
# the detail). It is NOT a curriculum out_of_scope ruling ("the class does not cover X"). The two mean
# opposite things to a question generator, so they must not share a field.
_EVIDENCE_GAP_PHRASE = re.compile(
    r"(not (printed|present|covered|stated|given|shown|quoted|supplied|captured|included) in (the |this )?"
    r"(supplied )?(evidence|chunk|excerpt|text)|evidence (does not|doesn'?t|did not) (cover|print|state|show|"
    r"include|extend)|not in (this |the )?(supplied )?evidence|evidence gap|the (supplied )?evidence "
    r"(stops|truncat|cuts)|absent from (the |this )?(supplied )?(evidence|chunk)|"
    r"is not evidenced|no .{0,30}in (the |this )?(supplied )?evidence)", re.I)


def split_evidence_gaps(conn: sqlite3.Connection) -> int:
    """Move evidence-gap notes OUT of boundary.out_of_scope into their own `evidence_gap` field.

    Nothing is discarded — the note is preserved verbatim, just filed under the field that means what it
    says. Idempotent: a note already moved is not in out_of_scope any more, so a re-run is a no-op.
    """
    if "evidence_gap" not in _columns(conn, "ki_concept"):
        return 0
    moved = 0
    for r in conn.execute("SELECT concept_id, boundary, evidence_gap FROM ki_concept "
                          "WHERE boundary IS NOT NULL AND boundary != ''").fetchall():
        try:
            b = json.loads(r[1] or "{}")
        except (ValueError, TypeError):
            continue
        oos = b.get("out_of_scope")
        if not isinstance(oos, list):
            continue
        gaps = [x for x in oos if isinstance(x, str) and _EVIDENCE_GAP_PHRASE.search(x)]
        if not gaps:
            continue
        b["out_of_scope"] = [x for x in oos if x not in gaps]
        existing = []
        if r[2]:
            try:
                existing = json.loads(r[2])
            except (ValueError, TypeError):
                existing = []
        conn.execute("UPDATE ki_concept SET boundary=?, evidence_gap=? WHERE concept_id=?",
                     (json.dumps(b), json.dumps(existing + gaps), r[0]))
        moved += 1
    conn.commit()
    return moved


def open_index(db_path: Optional[str] = None, *, unfreeze: bool = False) -> sqlite3.Connection:
    """Open (creating if needed) and migrate the knowledge index for WRITING.

    FREEZE GUARD (R1-5, C6): this is the sole RW opener — it runs executescript + migrate on EVERY open
    (migrate writes schema_migrated_at), and every ingest/verdict/retire writes certified rows through it.
    So a frozen (immutable=='true') index is REFUSED here unless a sanctioned versioned rebuild explicitly
    unfreezes it (unfreeze=True, or env KIE_ALLOW_FROZEN_WRITE=1). Read-only consumers must use
    open_index_ro(), which never writes. The check runs BEFORE any write so nothing touches a frozen db."""
    from kie import config
    path = db_path or (config.KIE_HOME / "knowledge_index.db")
    if str(path) != ":memory:":
        Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    if is_immutable(conn) and not (unfreeze or os.environ.get(_UNFREEZE_ENV) == "1"):
        conn.close()
        raise FrozenIndexError(
            f"refusing RW open of frozen index {path}: it is immutable (ki_meta.immutable='true'). "
            f"Use open_index_ro() for reads; a sanctioned version bump must pass unfreeze=True or set "
            f"{_UNFREEZE_ENV}=1.")
    conn.executescript(SCHEMA_PATH.read_text())
    migrate(conn)
    return conn


def open_index_ro(db_path: Optional[str] = None) -> sqlite3.Connection:
    """NON-MIGRATING read-only open of the (possibly frozen) index. Opens ?mode=ro and runs NO
    executescript / NO migrate, so it never bumps schema_migrated_at, never creates a -wal, and cannot
    breach the freeze. This is the correct opener for every read-only consumer (report/audit/reconcile)."""
    from kie import config
    path = db_path or (config.KIE_HOME / "knowledge_index.db")
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


# ── build-run telemetry (R2-3, BS-5) ──────────────────────────────────────────────────────────────
def record_run(conn: sqlite3.Connection, run_id: str, stage: str, model: str, items: Optional[int] = None,
               tokens: Optional[int] = None, wall_seconds: Optional[float] = None,
               note: Optional[str] = None) -> None:
    """Record one model/build stage into ki_run — the per-run audit trail the audit found EMPTY across every
    index version (D4/BS-5: ki_run = 0 rows, so the index build had no model/telemetry trail).

    Called from build.py's model stages (engineer ingest, independent audit, freeze) via the R1-5 unfreeze
    hatch — SC.open_index refuses a frozen index for writing, so record_run naturally fires ONLY during a
    sanctioned versioned rebuild and can never breach the freeze. The frozen v1.4 index keeps ki_run=0 (an
    honest null); population begins at the next sanctioned build (v1.5). Callers embed a timestamp in `run_id`
    for a distinct row per build; INSERT OR REPLACE keeps it crash-free on a re-run of the same run_id/stage."""
    conn.execute(
        "INSERT OR REPLACE INTO ki_run (run_id, stage, model, items, tokens, wall_seconds, note, recorded_at) "
        "VALUES (?,?,?,?,?,?,?,?)",
        (run_id, stage, model, items, tokens, wall_seconds, (note or "")[:1000], now()))
    conn.commit()


# ── resumability ────────────────────────────────────────────────────────────────────────────────
def mark(conn: sqlite3.Connection, scope: str, stage: str, status: str, detail: str = "") -> None:
    conn.execute(
        "INSERT OR REPLACE INTO ki_progress (scope, stage, status, detail, updated_at) VALUES (?,?,?,?,?)",
        (scope, stage, status, detail[:500], now()))
    conn.commit()


def is_done(conn: sqlite3.Connection, scope: str, stage: str) -> bool:
    r = conn.execute("SELECT status FROM ki_progress WHERE scope=? AND stage=?", (scope, stage)).fetchone()
    return bool(r and r["status"] == "done")


def record_gap(conn: sqlite3.Connection, scope: str, kind: str, detail: str, blocks: str = "") -> None:
    """A corpus hole, recorded permanently. Coverage maths must subtract these, not hide them."""
    import hashlib
    gid = "GAP_" + hashlib.sha256(f"{scope}|{kind}".encode()).hexdigest()[:14]
    conn.execute(
        "INSERT OR REPLACE INTO ki_gap (gap_id, scope, kind, detail, blocks, created_at) VALUES (?,?,?,?,?,?)",
        (gid, scope, kind, detail[:500], blocks[:300], now()))
    conn.commit()
