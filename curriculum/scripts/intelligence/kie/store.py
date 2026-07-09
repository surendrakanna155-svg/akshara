"""KIE local SQLite store. Schema in schema.sql (mirrors the Postgres edu_* shapes).

Deterministic + stdlib-only. A file DB uses WAL; an in-memory DB (tests) does not.
"""
from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator, Optional, Union

from kie import config

SCHEMA_PATH = Path(__file__).resolve().parent / "schema.sql"
SCHEMA_VERSION = "1"

PathLike = Union[str, Path, None]


def connect(db_path: PathLike = None) -> sqlite3.Connection:
    path = Path(db_path) if db_path and db_path != ":memory:" else (db_path or config.DB_PATH)
    is_mem = str(path) == ":memory:"
    if not is_mem:
        Path(path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    if not is_mem:
        conn.execute("PRAGMA journal_mode = WAL")
    return conn


def migrate(conn: sqlite3.Connection) -> None:
    conn.executescript(SCHEMA_PATH.read_text())
    conn.execute(
        "INSERT INTO schema_meta(key, value) VALUES ('schema_version', ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        (SCHEMA_VERSION,),
    )
    conn.commit()


def open_store(db_path: PathLike = None) -> sqlite3.Connection:
    """Open (creating/migrating if needed) the KIE store."""
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


def schema_version(conn: sqlite3.Connection) -> Optional[str]:
    row = conn.execute("SELECT value FROM schema_meta WHERE key = 'schema_version'").fetchone()
    return row["value"] if row else None
