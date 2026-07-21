"""R5-6 [#data-integrity-2] — deterministic evidence-substrate cleaning.

54.3% of certified concepts ground on chunks carrying reprint/footer/running-head boilerplate; some math
evidence is OCR-mangled ("P(BGG)+P(GBG)+P(GGB) = 83818181=++"). This produces a CLEANED evidence_text BESIDE
the raw chunk pointer (the frozen kie.db chunk is NEVER mutated — freeze discipline) and FLAGS chunks whose
non-linguistic character ratio is too high, so mangled math can never silently ground a generated numeric item.

Scope: the chunks that actually GROUND certified concepts (ki_concept.evidence_chunks, `doc_id#ordinal` refs).
Deterministic, offline, no model. Reads knowledge_index.db + kie.db mode=ro; writes only graph_edges.db.
"""
from __future__ import annotations

import json
import re
import sqlite3
from typing import Dict, List, Set, Tuple

from kie import config
from kie.qie.graph import store as ST
from kie.qie.inventory import crosswalk as XW

INDEX_DB_PATH = config.KIE_HOME / "knowledge_index.db"
KIE_DB_PATH = config.KIE_HOME / "kie.db"

# advisory flags for a chunk that is NOT usable prose evidence for a generated numeric item (adversarial-
# verifier Findings 2/3): either it is OCR-garble (high non-(letter/space) ratio) OR it is near prose-free
# number/symbol soup (almost no letters). NOT a deletion — a flag beside the raw pointer.
MANGLED_RATIO = 0.5          # 1 - (letters+spaces)/len
MIN_PROSE_ALPHA = 0.15       # letters/len below this => a number/symbol dump, not prose

# whole-LINE boilerplate that is UNAMBIGUOUS TEXT — safe to strip anywhere in the chunk (a real sentence never
# looks like these). Each must match the ENTIRE stripped line.
_TEXT_BOILERPLATE = [
    re.compile(r"^reprint\s+\d{4}[-–]\d{2,4}$", re.IGNORECASE),
    re.compile(r"^rationalised\s+\d{4}[-–]\d{2,4}.*$", re.IGNORECASE),
    re.compile(r"^.{0,60}—\s*textbook of .+for (grade|class)\s+\w+$", re.IGNORECASE),  # running head
    re.compile(r"^©.*$"),                                          # copyright line
]
# a standalone NUMBER line is a PAGE NUMBER only when it is SPARSE. A chunk full of standalone numbers is a
# figure/table/measurement DUMP — those digits are real content and must NEVER be deleted (adversarial-verifier
# Finding 1: `^\d{1,4}$` was deleting 5–93 real data numbers from 92 live chunks). So standalone-number lines are
# stripped only when there are at most this many in the whole chunk (genuine page-header/footer numerals).
_STANDALONE_NUM = re.compile(r"^\d{1,4}$")
_YEAR_RANGE = re.compile(r"^\d{4}[-–]\d{2,4}$")
_MAX_PAGE_NUMBERS = 2


def clean_text(text: str) -> Tuple[str, bool]:
    """Strip whole-line boilerplate. Returns (cleaned_text, removed_anything). Never removes in-line content, and
    never deletes standalone numbers from a numeric-dense chunk (they are data, not page numbers)."""
    if not text:
        return "", False
    lines = text.split("\n")
    numeric_lines = sum(1 for ln in lines if _STANDALONE_NUM.match(ln.strip()) or _YEAR_RANGE.match(ln.strip()))
    strip_numbers = numeric_lines <= _MAX_PAGE_NUMBERS      # sparse => page numbers; dense => real data, KEEP
    kept: List[str] = []
    removed = False
    for line in lines:
        s = line.strip()
        if not s:
            kept.append(line)
            continue
        if any(p.match(s) for p in _TEXT_BOILERPLATE):
            removed = True
            continue
        if strip_numbers and (_STANDALONE_NUM.match(s) or _YEAR_RANGE.match(s)):
            removed = True
            continue
        kept.append(line)
    cleaned = "\n".join(kept).strip()
    return cleaned, removed


def non_linguistic_ratio(text: str) -> float:
    """1 - (letters+spaces)/len — high for OCR-mangled math/table soup, low for prose."""
    if not text:
        return 0.0
    linguistic = sum(1 for ch in text if ch.isalpha() or ch.isspace())
    return round(1 - linguistic / len(text), 4)


def _alpha_ratio(text: str) -> float:
    """letters/len — near 0 for a pure number/symbol dump (no prose)."""
    if not text:
        return 1.0
    return sum(1 for ch in text if ch.isalpha()) / len(text)


def is_flagged_mangled(text: str) -> bool:
    """Advisory: too garbled OR too prose-free to ground a generated numeric item (Findings 2/3)."""
    if not text:
        return False
    return non_linguistic_ratio(text) > MANGLED_RATIO or _alpha_ratio(text) < MIN_PROSE_ALPHA


def _certified_evidence_refs(index: sqlite3.Connection) -> Set[str]:
    refs: Set[str] = set()
    for r in index.execute("SELECT evidence_chunks FROM ki_concept WHERE status='certified' "
                          "AND evidence_chunks IS NOT NULL"):
        try:
            for x in json.loads(r[0] or "[]"):
                if x:
                    refs.add(str(x))
        except (json.JSONDecodeError, TypeError):
            continue
    return refs


def build(graph_path=None, index_path=INDEX_DB_PATH, kie_path=KIE_DB_PATH) -> Dict[str, object]:
    """Clean every chunk that grounds a certified concept. READ-ONLY over the frozen index + kie.db; writes only
    graph_edges.db. Idempotent."""
    idx = sqlite3.connect(f"file:{index_path}?mode=ro", uri=True)
    try:
        refs = _certified_evidence_refs(idx)
    finally:
        idx.close()

    rows: List[tuple] = []
    kie = sqlite3.connect(f"file:{kie_path}?mode=ro", uri=True)
    kie.row_factory = sqlite3.Row
    try:
        for chunk_id in sorted(refs):                              # deterministic order
            r = kie.execute("SELECT chunk_id, doc_id, text FROM chunks WHERE chunk_id=?", (chunk_id,)).fetchone()
            if r is None:
                continue                                          # a dangling ref (R1-4 territory) — skip
            raw = r["text"] or ""
            cleaned, removed = clean_text(raw)
            ratio = non_linguistic_ratio(cleaned)
            rows.append((r["chunk_id"], r["doc_id"], len(raw), len(cleaned), cleaned,
                         1 if removed else 0, ratio, 1 if is_flagged_mangled(cleaned) else 0))
    finally:
        kie.close()

    conn = ST.open_store(graph_path, writable=True)
    try:
        conn.execute("DELETE FROM cleaned_evidence")
        conn.executemany(
            "INSERT OR REPLACE INTO cleaned_evidence (chunk_id, doc_id, raw_len, cleaned_len, cleaned_text, "
            "boilerplate_removed, non_linguistic_ratio, flagged_mangled) VALUES (?,?,?,?,?,?,?,?)", rows)
        conn.execute("INSERT INTO prereq_meta(key, value) VALUES ('evidence_clean_index_version', ?) "
                     "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                     (XW.build(index_path).version,))
        conn.commit()
    finally:
        conn.close()
    return _summary(rows)


def _summary(rows: List[tuple]) -> Dict[str, object]:
    total = len(rows)
    boiler = sum(1 for r in rows if r[5])
    mangled = sum(1 for r in rows if r[7])
    return {"chunks_processed": total, "boilerplate_removed": boiler, "flagged_mangled": mangled,
            "boilerplate_pct": round(100 * boiler / total, 1) if total else 0.0,
            "note": ("raw chunks are never mutated (freeze); cleaned_text is stored BESIDE the pointer; "
                     "flagged_mangled is an advisory so garbled math never grounds a numeric item.")}


# ── query helpers ─────────────────────────────────────────────────────────────────────────────────────
def cleaned_evidence(chunk_id: str, graph_path=None):
    conn = ST.open_store(graph_path, writable=False)
    try:
        return conn.execute("SELECT cleaned_text, flagged_mangled, non_linguistic_ratio FROM cleaned_evidence "
                            "WHERE chunk_id=?", (chunk_id,)).fetchone()
    finally:
        conn.close()


def clean_report(graph_path=None) -> Dict[str, object]:
    conn = ST.open_store(graph_path, writable=False)
    try:
        total = conn.execute("SELECT COUNT(*) FROM cleaned_evidence").fetchone()[0]
        boiler = conn.execute("SELECT COUNT(*) FROM cleaned_evidence WHERE boilerplate_removed=1").fetchone()[0]
        mangled = conn.execute("SELECT COUNT(*) FROM cleaned_evidence WHERE flagged_mangled=1").fetchone()[0]
        return {"chunks_processed": total, "boilerplate_removed": boiler, "flagged_mangled": mangled,
                "boilerplate_pct": round(100 * boiler / total, 1) if total else 0.0}
    finally:
        conn.close()


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
