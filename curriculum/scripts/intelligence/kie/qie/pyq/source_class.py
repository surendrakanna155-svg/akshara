"""Program B · B1 — corpus role classification (`pyq_source_class`).

Reconstructs the provenance the ingester discarded. The Phase-1 ingest lifted only the TOP path folder into
`source_documents.category`, so 861 docs read `exam='Cursor_Downloads'` (a download-dump folder, not an exam —
defect D5) even though their FULL rel_path carries the real identity, e.g.
    Cursor_Downloads/jeeadv_ac_in_archive/JEE_Advanced/Previous_Papers/2007/JEE_Advanced_2007_Paper1.pdf

This module re-derives, per document, a FAIL-CLOSED classification:
  * source_role  — genuine_pyq | practice_dpp | mock | sample_paper | textbook | solution_key | unknown
                   (OD-1: only genuine_pyq feeds exam DNA; dpp/mock/practice stay separate datasets)
  * exam / year  — from the full rel_path + the doc's OWN content chunks. A folder token NEVER assigns an exam
                   (canonical_exam() has no dump-folder token); a path/content CONFLICT is honest-null (OD-2); a
                   bare unqualified "JEE" is honest-null (fail-closed). Each exam carries an honest `exam_method`:
                   `path_content_corroborated` (path token AND content agree) is strongest; `path_token` means the
                   token came from the doc's own path/filename with content SILENT — a real signal, but NOT
                   content-verified, and never dressed up as if it were.
  * source_authority — official (jeeadv.ac.in archive) | third_party (mirrors/redistributors) | unknown.

DERIVED + read-only over the frozen kie.db (mode=ro). Writes only pyq_corpus.db. Deterministic rebuild.
The classify function is a PURE function of (source_documents row, head_text) so tests + the adversarial verifier
reproduce every decision without a store.
"""
from __future__ import annotations

import json
import re
import sqlite3
from datetime import datetime, timezone
from typing import Dict, List, Optional

from kie import config
from kie.qie.pyq import store as ST
from kie.qie.pyq import taxonomy as TX

# path/archive tokens → role & authority hints (matched case-insensitively against each rel_path segment)
_PRACTICE_RE = re.compile(r"(dpp|chapterwise|daily.?practice|practice.?sheet)", re.I)
_MOCK_RE     = re.compile(r"\bmock\b", re.I)
# STRONG "this IS a past exam paper" signal — the ONLY path token that may promote a doc_type-unknown doc to
# genuine_pyq or rescue a doc from a practice archive. A GENERIC "question bank/paper" token is deliberately
# EXCLUDED (a DPP is routinely named "…question bank"; a coaching topic-set sits in a "Question_Banks" folder).
_STRONG_PYQ_RE = re.compile(r"(previous.?paper|prev.?year|\bpyq\b)", re.I)
_SAMPLE_RE   = re.compile(r"\bsample\b", re.I)
_APTITUDE_RE = re.compile(r"\b(aat|b.?arch|architecture.?aptitude|drawing.?test)\b", re.I)
# a doc that IS a solution / answer-key / marking-scheme (no question stems) — matched on the FILENAME.
# Generalized past the two spellings in the frozen corpus so the RE-MINE (Program B's purpose, OD-8) does not
# leak the many real answer-key spellings: bare `key(s)`, `answer(s)`, `ans_key`, `soln`, `response key`, etc.
# Bare-token alternatives use ALPHANUMERIC boundaries `(?<![a-z0-9])…(?![a-z0-9])` — NOT `\b`, which counts '_'
# as a word char and would miss `NEET_2019_answers.pdf` (the same '_' trap the year parser avoids).
_SOLKEY_RE   = re.compile(r"(answer.?ke?y|ans[-_ ]?ke?y|response.?ke?y|marking.?scheme|paper.?solutions?"
                          r"|(?<![a-z0-9])(?:keys?|answers?|solns?|solutions?|sol)(?![a-z0-9]))", re.I)
# …UNLESS the filename shows it is a PAPER that merely CARRIES answers/solutions (questions present → keep).
_HASQ_RE     = re.compile(r"(with.?sol|qs.?ans|question.?.?answer|paper.?with|q.?and.?a)", re.I)
_OFFICIAL_RE = re.compile(r"(ac.?in|nta.?ac|jeeadv|jeemain|_official)", re.I)
_THIRDP_RE   = re.compile(r"(mirror|embibe|byjus|careers360|aakash|allen|mathongo|physicsaholics|"
                          r"studentbro|jeebooks|vedantu|unacademy|resonance)", re.I)


def _segments(rel_path: str) -> List[str]:
    return [s for s in (rel_path or "").split("/") if s]


def _authority(segs: List[str]) -> str:
    joined = " ".join(segs)
    if _OFFICIAL_RE.search(joined):
        return "official"
    if _THIRDP_RE.search(joined):
        return "third_party"
    return "unknown"


def _role(doc_type: Optional[str], segs: List[str], fname: str, exam_present: bool,
          aptitude: bool) -> tuple:
    """(source_role, role_method). Path archive/filename hints are MORE specific than a stale doc_type and
    override it — so a mislabelled `previous_paper` that is actually a DPP / mock / solution never reaches
    genuine_pyq (the symmetric guards that make the DNA set fail-closed)."""
    joined = " ".join(segs)
    practice = bool(_PRACTICE_RE.search(joined))
    mock = bool(_MOCK_RE.search(joined))
    strong_pyq = bool(_STRONG_PYQ_RE.search(joined))
    sample = bool(_SAMPLE_RE.search(joined))
    dt = (doc_type or "").strip().lower()
    # a PURE solution/answer-key (filename says so, and it is NOT a paper that merely carries answers)
    solkey_path = bool(_SOLKEY_RE.search(fname)) and not bool(_HASQ_RE.search(fname))

    # order matters: every "not a genuine past-exam question paper" signal wins first, so no key/solution/mock/
    # practice doc can fall through to genuine_pyq (whatever its stale doc_type claims).
    if dt in ("solution", "answer_key"):
        return "solution_key", "doc_type"
    if solkey_path:
        return "solution_key", "solution_path"                # overrides doc_type='previous_paper' (defect: answer keys leaked)
    if mock or dt == "mock_test":
        return "mock", "mock_archive" if mock else "doc_type"
    if practice or dt == "dpp":
        # a practice archive overrides even doc_type='previous_paper' UNLESS the path carries a STRONG pyq token
        # (a generic "question bank" token does NOT rescue a practice doc — defect: DPP question-banks leaked)
        if practice and not strong_pyq:
            return "practice_dpp", "practice_archive"
        if dt == "dpp":
            return "practice_dpp", "doc_type"
    if dt == "previous_paper":
        return "genuine_pyq", "doc_type"
    if dt in ("sample_paper",) or sample:
        return "sample_paper", "doc_type" if dt == "sample_paper" else "sample_path"
    if dt == "textbook":
        return "textbook", "doc_type"
    # doc_type unknown/collection/empty → promote to genuine_pyq ONLY on a STRONG pyq signal (never on a bare
    # "question bank" folder — that is how coaching topic-sets leaked in as genuine papers), and NEVER for a doc
    # sitting in a practice/mock archive even if its filename also carries a previous_paper token (P3 escape).
    if strong_pyq and exam_present and not aptitude and not practice and not mock:
        return "genuine_pyq", "path_pyq_signal"
    if practice:
        return "practice_dpp", "practice_archive"
    if mock:
        return "mock", "mock_archive"
    return "unknown", "unresolved"


def _resolve_exam(category: Optional[str], segs: List[str], fname: str,
                  content_exams: set) -> tuple:
    """(exam_resolved, exam_method). FAIL-CLOSED: folder tokens never assign; conflict → honest-null."""
    # tokens DECLARED by path segments + filename + category (canonical_exam() drops dump-folder tokens to None)
    declared = set()
    for tok in segs + [fname, category or ""]:
        e = TX.canonical_exam(tok)
        if e:
            declared.add(e)

    if len(declared) == 1:
        e = next(iter(declared))
        if content_exams and e not in content_exams:
            return None, "ambiguous"                       # content contradicts the path → honest-null
        if e in content_exams:
            return e, "path_content_corroborated"
        return e, "path_token"                             # token from the doc's OWN path/filename naming; content silent
    if len(declared) > 1:
        inter = declared & content_exams
        if len(inter) == 1:
            return next(iter(inter)), "content_disambiguated"
        return None, "ambiguous"                           # multiple path exams, content can't disambiguate
    # nothing declared by path/category
    if len(content_exams) == 1:
        return next(iter(content_exams)), "content_only"
    return None, "honest_null"


def _resolve_subject_hint(role: str, source_subject: Optional[str], segs: List[str],
                          content: str) -> tuple:
    """(subject_hint, subject_method). Full exam papers are multi-subject → defer to per-question (B2/B3)."""
    subs = {TX.canonical_subject(s) for s in segs}
    subs |= TX.subject_signals(content or "")
    ss = TX.canonical_subject(source_subject or "")
    if ss:
        subs.add(ss)
    subs.discard(None)
    if role == "genuine_pyq":
        return None, "multi_subject_defer"                 # never pin a whole paper to one subject
    if len(subs) == 1:
        return next(iter(subs)), "source_doc_single"
    return None, "honest_null"


def classify(row: sqlite3.Row, head_text: str, doc_has_chunks: bool = True) -> dict:
    """Pure classification of one source_documents row + its head content. Deterministic, honest-null.

    `doc_has_chunks` (from build()) gates DNA-eligibility: a doc with no extractable content chunks (e.g. a
    zero-content solution PDF) can never be mined, so it is never DNA-eligible."""
    rel_path = row["rel_path"] or ""
    segs = _segments(rel_path)
    fname = segs[-1] if segs else ""
    aptitude = bool(_APTITUDE_RE.search(" ".join(segs)))
    content_exams = TX.content_exam_signals(head_text)

    exam, exam_method = _resolve_exam(row["category"], segs, fname, content_exams)
    role, role_method = _role(row["doc_type"], segs, fname, exam_present=exam is not None, aptitude=aptitude)
    authority = _authority(segs)
    subject_hint, subject_method = _resolve_subject_hint(role, row["subject"], segs, head_text)

    # year: the source_doc value is authoritative when present; else parse the path/filename (ambiguous→null)
    if row["year"] is not None:
        year, year_method = int(row["year"]), "source_doc"
    else:
        y = TX.parse_year(rel_path, fname)
        year, year_method = (y, "path_or_filename") if y is not None else (None, "honest_null")

    # DNA-eligible: a genuine past exam paper, with a resolved exam, not an aptitude sub-test, WITH content to mine
    eligible = int(role == "genuine_pyq" and exam is not None and not aptitude and doc_has_chunks)

    signals = {
        "path_exams": sorted({e for tok in segs + [fname] if (e := TX.canonical_exam(tok))}),
        "category_token_exam": TX.canonical_exam(row["category"] or ""),
        "content_exams": sorted(content_exams),
        "aptitude_subtest": aptitude,
        "solution_key_path": bool(_SOLKEY_RE.search(fname)) and not bool(_HASQ_RE.search(fname)),
        "strong_pyq_signal": bool(_STRONG_PYQ_RE.search(" ".join(segs))),
        "has_content_chunks": doc_has_chunks,
        "authority_src": authority,
    }
    return {
        "doc_id": row["doc_id"], "rel_path": rel_path, "source_role": role, "role_method": role_method,
        "source_authority": authority, "exam_resolved": exam,
        "exam_family": TX.EXAM_FAMILY.get(exam) if exam else None, "exam_method": exam_method,
        "subject_hint": subject_hint, "subject_method": subject_method,
        "year_resolved": year, "year_method": year_method, "eligible_for_dna": eligible,
        "signals": json.dumps(signals, sort_keys=True),
    }


def _open_kie_ro() -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{config.DB_PATH}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def _head_texts(kie: sqlite3.Connection) -> Dict[str, str]:
    """doc_id -> concatenated head-chunk text (ordinal<=6), for content corroboration. Bounded per chunk."""
    out: Dict[str, str] = {}
    for r in kie.execute(
            "SELECT doc_id, group_concat(head, ' ') AS h FROM "
            "(SELECT doc_id, substr(text,1,400) AS head FROM chunks WHERE ordinal<=6) GROUP BY doc_id"):
        out[r["doc_id"]] = r["h"] or ""
    return out


def build(pyq_db_path=None) -> Dict[str, object]:
    """Classify every source_documents row into pyq_source_class. Idempotent rebuild. READ-ONLY over kie.db;
    writes only pyq_corpus.db. Returns a summary."""
    kie = _open_kie_ro()
    try:
        heads = _head_texts(kie)
        with_chunks = {r[0] for r in kie.execute("SELECT DISTINCT doc_id FROM chunks")}
        rows = list(kie.execute(
            "SELECT doc_id, rel_path, category, exam, subject, doc_type, year FROM source_documents"))
    finally:
        kie.close()

    records = [classify(r, heads.get(r["doc_id"], ""), r["doc_id"] in with_chunks) for r in rows]
    now = datetime.now(timezone.utc).isoformat()

    conn = ST.open_store(pyq_db_path, writable=True)
    try:
        conn.execute("DELETE FROM pyq_source_class")
        conn.executemany(
            "INSERT INTO pyq_source_class (doc_id, rel_path, source_role, role_method, source_authority, "
            "exam_resolved, exam_family, exam_method, subject_hint, subject_method, year_resolved, year_method, "
            "eligible_for_dna, signals, created_at) VALUES "
            "(:doc_id,:rel_path,:source_role,:role_method,:source_authority,:exam_resolved,:exam_family,"
            ":exam_method,:subject_hint,:subject_method,:year_resolved,:year_method,:eligible_for_dna,"
            ":signals,:created_at)",
            [{**rec, "created_at": now} for rec in records])
        meta = {"total_docs": str(len(records)), "built_at": now,
                "stats": json.dumps(_tally(records), sort_keys=True)}
        for k, v in meta.items():
            conn.execute("INSERT INTO pyq_meta(key,value) VALUES (?,?) "
                         "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (k, v))
        conn.commit()
    finally:
        conn.close()
    return {"total_docs": len(records), "stats": _tally(records)}


def _tally(records: List[dict]) -> Dict[str, object]:
    by_role: Dict[str, int] = {}
    by_exam: Dict[str, int] = {}
    eligible = 0
    for rec in records:
        by_role[rec["source_role"]] = by_role.get(rec["source_role"], 0) + 1
        ek = rec["exam_resolved"] or "(honest_null)"
        by_exam[ek] = by_exam.get(ek, 0) + 1
        eligible += rec["eligible_for_dna"]
    return {"by_role": dict(sorted(by_role.items())), "by_exam": dict(sorted(by_exam.items())),
            "eligible_for_dna": eligible}


def report(pyq_db_path=None) -> Dict[str, object]:
    conn = ST.open_store(pyq_db_path, writable=False)
    try:
        total = conn.execute("SELECT COUNT(*) FROM pyq_source_class").fetchone()[0]
        by_role = {r[0]: r[1] for r in conn.execute(
            "SELECT source_role, COUNT(*) FROM pyq_source_class GROUP BY source_role ORDER BY 2 DESC")}
        eligible = conn.execute("SELECT COUNT(*) FROM pyq_source_class WHERE eligible_for_dna=1").fetchone()[0]
        by_exam = {(r[0] or "(honest_null)"): r[1] for r in conn.execute(
            "SELECT exam_resolved, COUNT(*) FROM pyq_source_class WHERE eligible_for_dna=1 "
            "GROUP BY exam_resolved ORDER BY 2 DESC")}
        return {"total_docs": total, "by_role": by_role, "eligible_for_dna": eligible,
                "eligible_by_exam": by_exam,
                "note": "eligible_for_dna=1 iff genuine_pyq AND a content-corroborated exam; folder tokens never "
                        "assign an exam; conflicts/ambiguity are honest-null."}
    finally:
        conn.close()


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
