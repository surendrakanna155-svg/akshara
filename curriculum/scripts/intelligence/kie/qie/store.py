"""QIE local store opener — `qie.db`, SEPARATE from the certified kie.db.

Mirrors the kie.store connection/txn conventions (stdlib sqlite3, WAL for file DBs, in-memory for tests).
The QIE store holds derived quality knowledge (DNA / Item Models / KVS / generated instances); rows are
LOCAL-ONLY (gitignored). Only this code + schema are committed.
"""
from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator, Union

from kie import config

SCHEMA_PATH = Path(__file__).resolve().parent / "store_schema.sql"
SCHEMA_VERSION = "qie-1"
QIE_DB_PATH = config.KIE_HOME / "qie.db"

PathLike = Union[str, Path, None]


def connect(db_path: PathLike = None) -> sqlite3.Connection:
    path = db_path if db_path else QIE_DB_PATH
    is_mem = str(path) == ":memory:"
    if not is_mem:
        Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    if not is_mem:
        conn.execute("PRAGMA journal_mode = WAL")
    return conn


def _add_column_if_missing(conn: sqlite3.Connection, table: str, column: str, decl: str) -> None:
    cols = {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}
    if column not in cols:
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {decl}")


def migrate(conn: sqlite3.Connection) -> None:
    conn.executescript(SCHEMA_PATH.read_text())
    # Phase C additive migration for pre-existing stores (CREATE TABLE IF NOT EXISTS won't add columns).
    _add_column_if_missing(conn, "question_dna", "assessment_profile", "TEXT")
    _add_column_if_missing(conn, "governed_relation", "value_ranges", "TEXT")
    conn.execute(
        "INSERT INTO qie_meta(key, value) VALUES ('schema_version', ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        (SCHEMA_VERSION,),
    )
    conn.commit()


def open_store(db_path: PathLike = None) -> sqlite3.Connection:
    conn = connect(db_path)
    migrate(conn)
    return conn


@contextmanager
def txn(conn: sqlite3.Connection) -> Iterator[sqlite3.Connection]:
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
