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

import json
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

SCHEMA_PATH = Path(__file__).resolve().parent / "index_schema.sql"
SCHEMA_VERSION = "2"


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


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


def open_index(db_path: Optional[str] = None) -> sqlite3.Connection:
    """Open (creating if needed) and migrate the knowledge index."""
    from kie import config
    path = db_path or (config.KIE_HOME / "knowledge_index.db")
    if str(path) != ":memory:":
        Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.executescript(SCHEMA_PATH.read_text())
    migrate(conn)
    return conn


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
