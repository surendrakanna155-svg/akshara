"""Shared SQLite opener for QIE's WRITABLE derived stores (R3-4 · #database-9 / #perf-scale-7).

Consolidates the connection boilerplate every derived-store opener used to repeat by hand:
  * row_factory = sqlite3.Row
  * PRAGMA foreign_keys = ON
  * PRAGMA journal_mode  — STANDARDIZED to WAL for writable file DBs. The certification audit found
    the derived stores split between WAL (factory_corpus / qpl_question_bank) and the sqlite default
    `delete` (qdi.db, examdna.db); routing them through here removes that drift.
  * mode=ro by DEFAULT (fail-safe: a consumer that forgets `read_only=False` cannot mutate a store).
  * the R0-4 path guard (`config.assert_under_kie_home`) — no stray zero-byte DBs from a wrong cwd,
    relaxed to also permit the OS temp dir so test/scratch fixtures keep working.

SCOPE — DERIVED stores ONLY (factory_corpus.db, qpl_question_bank.db, qdi.db, examdna.db, and their
read-only consumers). The FROZEN knowledge_index.db and the frozen kie.db substrate are opened by
their OWN freeze-critical openers (knowledge.schema.open_index / open_index_ro, run_qdi.open_index_ro /
open_kie_ro, examdna.open_frozen_index) and are deliberately NOT routed here: the freeze hatch
(KIE_ALLOW_FROZEN_WRITE) and the chmod-a-w guard live in those openers, and this helper must never
become a second, guard-free way to open the immutable substrate. See R1-5.

DEFERRED (needs a SANCTIONED kie.db rebuild under the freeze hatch — NOT done in R3-4): an FTS5 index
over kie.db chunks + a `chunks(doc_id, ordinal)` index (#database-9, #perf-scale-9). Adding either
mutates the frozen v1.5 substrate (kie.db is chmod a-w), i.e. a version bump under the freeze hatch.
Do it at the next kie.db version; tracked in the R3-4 report.
"""
from __future__ import annotations

import sqlite3
import tempfile
from pathlib import Path
from typing import Union

from kie import config

PathLike = Union[str, Path]

_MEMORY = ":memory:"


def _assert_safe_path(path: PathLike) -> Path:
    """R0-4 guard, consolidated. Permits a store path under KIE_HOME (via config.assert_under_kie_home)
    OR under the OS temp dir (where tests / scratch fixtures legitimately live), and refuses anything
    else — catching the wrong-cwd stray-DB class R0-4 named (repo-root / curriculum/ zero-byte qie.db)
    without breaking temp-dir fixtures. Delegates the KIE_HOME check to config so its semantics stay
    the single source of truth."""
    p = Path(path).resolve()
    tmp = Path(tempfile.gettempdir()).resolve()
    if p == tmp or tmp in p.parents:
        return p
    return config.assert_under_kie_home(p)


def open_store(
    path: PathLike,
    *,
    read_only: bool = True,
    foreign_keys: bool = True,
    journal_mode: str = "WAL",
    create_parent: bool = True,
) -> sqlite3.Connection:
    """Open a DERIVED store with the standardized pragmas + the R0-4 path guard.

    read_only (DEFAULT True)  -> `file:<path>?mode=ro`; a MISSING file fails loud (OperationalError),
                                 which is the honest outcome — no silent stray-DB creation on a read.
    read_only=False           -> writable open; creates the parent dir and the DB if absent, and (for a
                                 file DB) standardizes journal_mode to WAL.
    `:memory:` is always allowed (skips the guard, the parent mkdir, and journal_mode)."""
    is_mem = str(path) == _MEMORY
    if not is_mem:
        path = _assert_safe_path(path)

    if read_only and not is_mem:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    else:
        if not is_mem and create_parent:
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(str(path))

    conn.row_factory = sqlite3.Row
    if foreign_keys:
        conn.execute("PRAGMA foreign_keys = ON")
    # journal_mode is a persistent, file-level setting; only meaningful for a WRITABLE file DB.
    if journal_mode and not is_mem and not read_only:
        conn.execute(f"PRAGMA journal_mode = {journal_mode}")
    return conn
