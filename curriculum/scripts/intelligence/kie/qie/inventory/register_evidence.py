"""Register qie.db as an EVIDENCE-ONLY store (R4-1(c) / RI-6).

The ONLY write R4-1 makes to qie.db: two additive `qie_meta` k/v rows — `role='evidence_source'` and
`product_visible='0'`. After this stamp, a product read of qie.db question content is a governance violation BY
CONSTRUCTION: `assert_not_product_surface()` fails closed on any store carrying this role, mirroring the factory
`role` stamp (`corpus.store_role`). qie.db is a WRITABLE derived store (correct target for the marker) — NOT the
frozen index (that is knowledge_index.db, opened mode=ro elsewhere). Idempotent.
"""
from __future__ import annotations

import sqlite3
import tempfile
from pathlib import Path

from kie import config

QIE_DB_PATH = config.KIE_HOME / "qie.db"
ROLE_KEY, ROLE_VALUE = "role", "evidence_source"
PRODUCT_VISIBLE_KEY, PRODUCT_VISIBLE_VALUE = "product_visible", "0"


class EvidenceOnlyViolation(Exception):
    """Raised when code tries to treat an evidence-only store as a product question surface (RI-6)."""


def _assert_safe(path) -> None:
    """Permit a path under KIE_HOME (the real qie.db) OR under the OS temp dir (test fixtures) — mirrors the
    store_open guard. The real evidence stamp always targets KIE_HOME/qie.db; the temp allowance only lets a
    fixture exercise the idempotent stamp without touching the live estate."""
    p = Path(path).resolve()
    tmp = Path(tempfile.gettempdir()).resolve()
    if p == tmp or tmp in p.parents:
        return
    config.assert_under_kie_home(p)


def _connect_rw(path=QIE_DB_PATH) -> sqlite3.Connection:
    _assert_safe(path)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    return conn


def store_role(conn: sqlite3.Connection) -> str:
    """The role qie.db carries in qie_meta, or None. Analogous to corpus.store_role."""
    try:
        r = conn.execute("SELECT value FROM qie_meta WHERE key=?", (ROLE_KEY,)).fetchone()
        return r[0] if r else None
    except sqlite3.OperationalError:
        return None


def product_visible(conn: sqlite3.Connection) -> bool:
    r = conn.execute("SELECT value FROM qie_meta WHERE key=?", (PRODUCT_VISIBLE_KEY,)).fetchone()
    return bool(r and str(r[0]) == "1")


def assert_not_product_surface(conn: sqlite3.Connection) -> None:
    """Fail-closed RI-6 guard: refuse to serve qie.db as a product question bank once it is evidence-stamped."""
    if store_role(conn) == ROLE_VALUE and not product_visible(conn):
        raise EvidenceOnlyViolation(
            "qie.db is stamped role='evidence_source' (product_visible=0) — it is an EVIDENCE source, not a "
            "product question bank (RI-6). Product surfaces read questions only from qpl_question_bank.db.")


def register(path=QIE_DB_PATH) -> dict:
    """Stamp qie.db evidence-only. Idempotent (ON CONFLICT). Returns the resulting meta."""
    conn = _connect_rw(path)
    try:
        # qie_meta exists on any real qie.db; guard for a fresh/empty fixture.
        conn.execute("CREATE TABLE IF NOT EXISTS qie_meta (key TEXT PRIMARY KEY, value TEXT)")
        for k, v in ((ROLE_KEY, ROLE_VALUE), (PRODUCT_VISIBLE_KEY, PRODUCT_VISIBLE_VALUE)):
            conn.execute("INSERT INTO qie_meta(key,value) VALUES (?,?) "
                         "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (k, v))
        conn.commit()
        return {"role": store_role(conn), "product_visible": "1" if product_visible(conn) else "0"}
    finally:
        conn.close()


def is_registered(path=QIE_DB_PATH) -> bool:
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        return store_role(conn) == ROLE_VALUE
    finally:
        conn.close()
