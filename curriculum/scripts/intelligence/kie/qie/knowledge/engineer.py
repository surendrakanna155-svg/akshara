"""STAGE 1b — Opus as CURRICULUM KNOWLEDGE ENGINEER (proposes) + STAGE 1c independent AUDIT (disposes).

Worksheet-in / verdicts-out, mirroring the repo's established Tier-2/3 boundary (`convert/examiner.py`):
the model reads a compact brief and returns structured records; deterministic code decides what is stored.

GOVERNANCE: a knowledge record is NOT certified because the first model wrote it. Every proposed concept
goes to a SECOND, INDEPENDENT pass that never saw the engineer's reasoning, and only `accept` promotes to
`certified`. The engineer proposes; the audit disposes; the deterministic spine bounds them both.

The engineer only ever sees material that already passed the deterministic spine — junk headings, activity
boxes, front matter and page furniture are gone before it is asked anything, so its job is interpretation
(what concept does this taught section actually teach?), not filtering.
"""
from __future__ import annotations

import json
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List

from kie import config
from kie.qie.knowledge import schema as SC
from kie.qie.knowledge import spine as S

SCHEMA_PATH = Path(__file__).resolve().parent / "index_schema.sql"
INDEX_DB_PATH = config.KIE_HOME / "knowledge_index.db"

DISCIPLINES = ("Physics", "Chemistry", "Biology", "Mathematics", "Interdisciplinary")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _section_key(heading: str):
    """'4.5  Adjoint and Inverse of a Matrix' -> '4.5'. None when the engineer named no section."""
    m = re.match(r"^\s*(\d{1,2}\.\d{1,2}(?:\.\d{1,2})?)", heading or "")
    return m.group(1) if m else None


# A record whose own text admits its grounding lives in ANOTHER section is the reliable mis-anchor tell —
# an independent auditor found that 5 of 8 mis-anchored Biology records confessed it in their own boundary,
# and one had reconstructed Meiosis-I crossing-over purely from syllabus memory while its attached evidence
# was the cell-cycle section. Flagging them makes the audit look hardest exactly where fabrication hides.
_CONFESSES_EXTERNAL_GROUNDING = re.compile(
    r"(grounded in (the )?(§|section)?\s*\d|evidence (lies|sits|is) in|recovered from (the )?adjacent|"
    r"its own chunk|bound to the (adjacent|neighbouring|parent)|content (lives|sits) in|"
    r"text (lives|sits) in|from the .{0,20}chunk)", re.I)


def _confesses_external_grounding(*fields) -> bool:
    blob = " ".join(str(f) for f in fields if f)
    return bool(_CONFESSES_EXTERNAL_GROUNDING.search(blob))


def _shingles(text: str, k: int = 5) -> set:
    """Offset-independent word k-grams. A fixed-stride/byte comparison MISSES the duplicate-evidence bug,
    because the heading prefix shifts the body's offset — an auditor proved that the hard way."""
    w = re.sub(r"\s+", " ", (text or "").lower()).split()
    return {tuple(w[i:i + k]) for i in range(max(0, len(w) - k + 1))}


def _dup_ratio(a: str, b: str) -> float:
    sa, sb = _shingles(a), _shingles(b)
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / min(len(sa), len(sb))


def duplicate_evidence_groups(records: list, threshold: float = 0.9) -> dict:
    """-> {index: index_of_the_record it duplicates}. THE mis-anchor signature.

    Two independent audits converged on this: when the extractor prefixes the right heading to the WRONG
    body chunk, a section's evidence comes out (near-)identical to a sibling's / its parent's / the chapter
    preview. The FIRST record in such a collision is genuinely covered; the trailing ones are not, and they
    read as plausible — one had ZIFT/GIFT/ICSI spelled out that appear nowhere in its attached text. Flagging
    the collision tells the auditor exactly where to look.
    """
    dup = {}
    for i in range(len(records)):
        for j in range(i + 1, len(records)):
            if records[j].get("evidence") and records[i].get("evidence"):
                if _dup_ratio(records[i]["evidence"], records[j]["evidence"]) >= threshold:
                    dup.setdefault(j, i)
    return dup


def open_index(db_path=None, *, unfreeze=False) -> sqlite3.Connection:
    """Schema ownership lives in schema.py — this delegates so migrations always run.

    RW opens of a FROZEN index are refused by the schema-layer freeze guard (R1-5) unless a sanctioned
    version bump passes unfreeze=True / sets KIE_ALLOW_FROZEN_WRITE=1. Read-only callers use open_index_ro."""
    return SC.open_index(db_path or INDEX_DB_PATH, unfreeze=unfreeze)


def open_index_ro(db_path=None) -> sqlite3.Connection:
    """Non-migrating READ-ONLY open — never writes, never migrates, cannot breach the freeze (R1-5)."""
    return SC.open_index_ro(db_path or INDEX_DB_PATH)


# ── DETERMINISTIC EVIDENCE GATE (R1-4, C3) ──────────────────────────────────────────────────────────
# The AI auditor's `accept` is NECESSARY but NOT SUFFICIENT. Before a concept may reach status='certified'
# its cited evidence must survive a pure, deterministic gate the auditor cannot waive: at least one cited
# chunk must RESOLVE in the substrate, still MATCH its recorded sha (no drift), and be SUBSTANTIVE after
# boilerplate strip. This is what closes the C3 holes (5 dangling refs; ~garbage OCR-furniture evidence).
#
# CALIBRATION NOTE (measured over all 2,023 live certified rows before shipping): a 4th "shares a token
# with the concept name" OVERLAP check was specified but is NOT gated on — empirically it false-positives
# ~90 CORRECT certified concepts (Gauss's Law, Subsets, Differentiability, Escape Speed…) because OCR
# concatenates the heading into the body ("SubsetsConsider…") and short technical names tokenise away.
# Gating on it would DELETE correct knowledge — the wrong kind of loss. The genuine mis-anchor class
# (right heading on the wrong body) is already caught by the separate, better-calibrated shingle detector
# `duplicate_evidence_groups` / `cmd_dupaudit`. So the fail-closed gate is RESOLVE + sha + SUBSTANCE, which
# reproduces exactly the dangling + non-substantive set the audit identified.
_GATE_STOPWORDS = frozenset({
    "the", "of", "and", "a", "to", "in", "is", "for", "by", "at", "or", "its", "this", "that",
    "with", "as", "an", "are", "be", "on"})
_GATE_SECNUM = re.compile(r"\b\d{1,2}\.\d{1,2}(?:\.\d{1,2})?\b")
_GATE_MIN_CHARS = 40
_GATE_MIN_WORDS = 6


def _boilerplate_strip(text: str) -> str:
    """Deterministic removal of reprint banners, running headers/footers, page numbers, OCR answer-key
    furniture and bare section numbers, then whitespace-collapse. Turns 'Reprint 2026-27\\n3answerS',
    '2024-25\\nMATHEMATICS34', '1.6.2 Elevation ofBoiling Point', 'g', 'n\\ni' into empty/near-empty text
    so they FAIL the substance floor."""
    t = text or ""
    t = re.sub(r"(?i)reprint\s*20\d\d-?\d*", " ", t)          # reprint/edition banners
    t = re.sub(r"\b20\d\d-\d2\b", " ", t)                     # running year headers e.g. 2024-25
    t = re.sub(r"\b\d*answer[sS]?\b", " ", t, flags=re.I)     # OCR answer-key furniture
    t = _GATE_SECNUM.sub(" ", t)                              # bare section numbers 1.6.2
    t = re.sub(r"(?m)^\s*\d{1,3}\s*$", " ", t)                # standalone page numbers
    return re.sub(r"\s+", " ", t).strip()


def _gate_tokens(s: str) -> set:
    """lowercase content tokens (len>=4, non-stopword) — used only for the ADVISORY overlap signal."""
    return {w for w in re.split(r"[^a-z0-9]+", (s or "").lower())
            if len(w) >= 4 and w not in _GATE_STOPWORDS}


def _word_count(t: str) -> int:
    return len(re.findall(r"[A-Za-z]{2,}", t))


def _load_json_list(s) -> list:
    if isinstance(s, list):
        return s
    try:
        v = json.loads(s or "[]")
        return v if isinstance(v, list) else []
    except (ValueError, TypeError):
        return []


def _row_get(row, key):
    """Column access tolerant of sqlite3.Row (no .get) vs dict, and of a missing column."""
    try:
        keys = row.keys()
    except AttributeError:
        return row.get(key) if isinstance(row, dict) else None
    return row[key] if key in keys else None


def evidence_gate(kconn, concept) -> tuple:
    """(ok, reason). A concept PASSES iff at least one cited chunk resolves + sha-matches + is substantive.

    `concept` is a row/dict exposing evidence_chunks (and, when present, evidence_sha256). `kconn` is a
    read-only kie.db handle. Pure and deterministic — reused verbatim by RI-2 and the v1.5 rebuild."""
    chunks = _load_json_list(_row_get(concept, "evidence_chunks"))
    shas = _load_json_list(_row_get(concept, "evidence_sha256"))
    if not chunks:
        return False, "no evidence refs"
    reasons = []
    for i, cid in enumerate(chunks):
        row = kconn.execute("SELECT text, sha256 FROM chunks WHERE chunk_id=?", (cid,)).fetchone()
        if row is None:
            reasons.append(f"dangling {cid}")
            continue
        sha = shas[i] if i < len(shas) else None
        if sha is not None and row[1] != sha:
            reasons.append(f"substrate drift {cid}")
            continue
        stripped = _boilerplate_strip(row[0])
        if len(stripped) < _GATE_MIN_CHARS or _word_count(stripped) < _GATE_MIN_WORDS:
            reasons.append(f"non-substantive {cid}")
            continue
        return True, "ok"
    return False, "; ".join(reasons[:3]) or "no resolvable substantive evidence"


def evidence_sha_for(kconn, ev_chunks) -> list:
    """Resolve each chunk's current sha256 from kie.db (None => dangling AT WRITE time; the gate refuses)."""
    out = []
    for ch_id in ev_chunks:
        row = kconn.execute("SELECT sha256 FROM chunks WHERE chunk_id=?", (ch_id,)).fetchone()
        out.append(row[0] if row else None)
    return out


def backfill_evidence_sha256(conn, kconn) -> int:
    """Populate evidence_sha256 for EVERY row from the live substrate (used once by the v1.5 rebuild before
    the gate runs). Writes only the additive column — evidence_chunks and the content fingerprint are
    untouched. Requires a writable (unfrozen) index handle."""
    n = 0
    for r in conn.execute("SELECT concept_id, evidence_chunks FROM ki_concept").fetchall():
        shas = evidence_sha_for(kconn, _load_json_list(r["evidence_chunks"]))
        conn.execute("UPDATE ki_concept SET evidence_sha256=? WHERE concept_id=?",
                     (json.dumps(shas), r["concept_id"]))
        n += 1
    conn.commit()
    return n


ENGINEER_BRIEF = """\
You are a CURRICULUM KNOWLEDGE ENGINEER building a clean, certified knowledge index for Indian school
science and mathematics (NCERT, classes 6-12). You are NOT writing questions. You are NOT designing
assessments. You are deciding what this chapter actually TEACHES.

Your input is one chapter of a real, owned NCERT textbook. The class is proven (it is that class's own
textbook) and the CURRICULUM SUBJECT is proven (from the NCERT filename code). The section headings shown
are the NUMBERED sections the book itself treats as taught content. Activity boxes, page furniture and
front matter have already been removed deterministically — you will not see them.

## THE TWO DIMENSIONS — both are required, and they are NOT the same thing
- `curriculum subject` — the book NCERT published. Given to you. For classes 6-10 this is often the
  INTEGRATED "Science" book. Never change it.
- `academic_discipline` — Physics | Chemistry | Biology | Mathematics | Interdisciplinary.
  For a single-subject book this is simply the subject. For an INTEGRATED Science book, NCERT prints no
  discipline label, so YOU must infer it FROM THE CHAPTER EVIDENCE and say what in the evidence supports
  it. "Force and Pressure" in Science class 8 is discipline Physics; "Coal and Petroleum" is Chemistry;
  "Cell Structure" is Biology. Both dimensions are kept — the Science textbook is never erased.
  Use `Interdisciplinary` ONLY when the chapter genuinely sits across disciplines on the evidence
  (e.g. photosynthesis treated as light + chemical reaction + plant physiology). It is not a place to
  put chapters you did not think about.

## WHAT YOU MUST PRODUCE
For each chapter: a canonical chapter title, its academic discipline (with the evidence that supports it
and a 0-1 confidence), and the list of CONCEPTS the chapter teaches.

A CONCEPT is something a student learns and can be assessed on — "Properties of Rational Numbers",
"Factorisation by Regrouping", "Surface Area of a Cylinder". It is NOT:
- a section number, a page header, or a running title
- an activity/pedagogy label ("Try These", "Think and Discuss", "Figure it Out")
- book apparatus (contents, contributors, answers, appendix, glossary)
- OCR garbage (`Telateltelt`, `answeranswer`, mangled runs of letters)
- a truncated biography heading ("Gustav Robert Kirchhoff (1824")
- a fragment of a sentence, or a heading merged with body text

If a supplied heading is one of those, do NOT emit it as a concept — emit it under `rejects` with a class.
The OCR is imperfect: headings sometimes ran into body text ("Laws of ExponentsYou know that,102 = 10 x 10").
Recover the real concept name from the evidence; do not copy the corrupted string.

## RULES THAT MATTER
- `canonical_name`: the concept as a teacher would name it. Deduplicate — if two headings teach the same
  concept, emit ONE concept and put the other under `aliases`.
- `sub_concepts`: only where the evidence actually supports them. An empty list is honest and expected.
- `prerequisites`: ONLY where the evidence supports them, and ONLY concepts a student would already have
  met at or below this class. If the chapter does not tell you, emit []. Do not guess a prerequisite chain.
- `boundary.in_scope` / `boundary.out_of_scope`: what this class's treatment does and does NOT cover
  (e.g. Class 8 factorisation covers regrouping and identities but NOT the factor theorem). This is the
  field that stops a Class-8 question reaching for a Class-11 method. Fill it from the evidence.
- Everything must rest on the supplied evidence. If the evidence does not support a concept, do not invent
  it — this index is the curriculum truth everything downstream will trust.

## OUTPUT — JSON array, one object per chapter, no prose outside the JSON:
{
  "chapter_no": 8,
  "canonical_title": "Algebraic Expressions and Identities",
  "academic_discipline": "Mathematics",
  "discipline_basis": "single-subject NCERT maths book; the filename code proves it",
  "discipline_confidence": 1.0,
  "concepts": [
    {
      "canonical_name": "Multiplying a Monomial by a Polynomial",
      "aliases": ["Monomial x Polynomial"],
      "sub_concepts": ["Distributive law over addition"],
      "prerequisites": ["Multiplying a Monomial by a Monomial"],
      "boundary": {"in_scope": ["numeric and single-variable coefficients"],
                   "out_of_scope": ["polynomial division", "factor theorem"]},
      "section_heading": "8.4  Multiplying a Monomial by a Polynomial",
      "academic_discipline": "Mathematics",
      "discipline_basis": "algebraic manipulation of polynomials",
      "discipline_confidence": 1.0
    }
  ],
  "rejects": [
    {"raw_label": "Some Applications", "reject_class": "not_a_concept",
     "reason": "a heading for worked examples; names no assessable concept"}
  ]
}
`academic_discipline` on a concept may differ from its chapter's (a Science chapter on "Coal and
Petroleum" is Chemistry, but a section on the energy released by burning is Physics). Omit the concept-
level discipline fields to inherit the chapter's.
reject_class is one of: front_matter | back_matter | page_furniture | activity_label | ocr_garbage |
answer_apparatus | truncated_heading | not_a_concept | unsupported | duplicate

## CHAPTERS
"""

_INTEGRATED_NOTE = """
!! THIS BOOK IS THE INTEGRATED NCERT SCIENCE TEXTBOOK. Its curriculum subject is provably "Science".
   The academic discipline of each chapter and concept is NOT given and NOT guessable from the filename —
   infer it from the evidence and justify it. Every record keeps BOTH: curriculum source "Science
   class {cls}" AND its academic discipline.
"""


def write_engineer_worksheet(kconn, chapters: List[dict], path: str, book: dict = None) -> int:
    """chapters: [{subject, taught_at_class, chapter_no, topics{}, chunk_ids[], book_code}]"""
    with open(path, "w") as f:
        f.write(ENGINEER_BRIEF)
        if book and book.get("is_integrated"):
            f.write(_INTEGRATED_NOTE.format(cls=book["taught_at_class"]))
        for ch in chapters:
            sev = S.section_evidence(kconn, ch)
            f.write(json.dumps({
                "chapter_no": ch["chapter_no"],
                "curriculum_subject": ch["subject"],
                "taught_at_class": ch["taught_at_class"],
                "book": ch.get("book_code"),
                "is_integrated_science": bool(ch.get("is_integrated")),
                "numbered_headings_observed": S.topic_list(ch),
                "chapter_opening": S.evidence_text(kconn, ch["chunk_ids"], 1200),
                # evidence for EACH section, anchored at its own heading — this is what a concept's
                # boundary/sub-concepts/prerequisites must be read off
                "section_evidence": {k: v["text"] for k, v in sev.items()},
            }, ensure_ascii=False) + "\n")
        f.write(f"\nReturn ONLY the JSON array of {len(chapters)} chapter objects.\n")
    return len(chapters)


def ingest_engineer(conn, kconn, payload: List[dict], book: dict, spine: Dict[int, dict],
                    model: str) -> Dict[str, int]:
    m = {"chapters": 0, "concepts": 0, "rejects": 0, "unmatched": 0, "no_discipline": 0}
    for ch in payload:
        n = ch.get("chapter_no")
        if n not in spine:
            m["unmatched"] += 1
            continue

        # dimension 2. For a single-subject book it is the proven subject and the model cannot move it;
        # for an integrated Science book it is the model's evidence-backed inference, audited separately.
        if book.get("is_integrated"):
            ch_disc = ch.get("academic_discipline")
            ch_basis = (ch.get("discipline_basis") or "")[:400]
            ch_conf = ch.get("discipline_confidence")
        else:
            ch_disc, ch_conf = book["subject"], 1.0
            ch_basis = book["subject_basis"][:400]
        if ch_disc not in DISCIPLINES:
            ch_disc, ch_conf = None, None

        cid = S.chapter_id(book["subject"], book["taught_at_class"], n, book["doc_id"])
        conn.execute(
            "INSERT OR REPLACE INTO ki_chapter (chapter_id, subject, taught_at_class, chapter_no, title, "
            "raw_titles, doc_id, academic_discipline, discipline_basis, discipline_confidence, status, "
            "created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (cid, book["subject"], book["taught_at_class"], n,
             (ch.get("canonical_title") or f"Chapter {n}").strip(),
             json.dumps(sorted(spine[n]["raw"])), book["doc_id"], ch_disc, ch_basis, ch_conf,
             "accepted", _now()))
        m["chapters"] += 1
        basis = S.extraction_basis(spine[n])
        # section key -> the chunk that section's heading was actually found in, so a concept cites the
        # evidence it came from rather than its whole chapter (owner rule 7)
        sec_chunk = {sec: t.get("chunk_id") for sec, t in spine[n]["topics"].items() if t.get("chunk_id")}
        sec_page = {sec: t.get("page") for sec, t in spine[n]["topics"].items() if t.get("page")}

        for c in ch.get("concepts") or []:
            name = (c.get("canonical_name") or "").strip()
            if not name:
                continue
            # A concept may sit in a different discipline from its chapter; absent that it INHERITS the
            # chapter's discipline — and must inherit its basis and confidence with it. Reading only the
            # concept-level field left every inheriting record with a null confidence, i.e. an inferred
            # claim carrying no statement of how sure we are, which the record format requires.
            c_disc = c.get("academic_discipline") if book.get("is_integrated") else ch_disc
            if c_disc not in DISCIPLINES:
                c_disc = ch_disc
            own = book.get("is_integrated") and c.get("academic_discipline") in DISCIPLINES
            c_conf = (c.get("discipline_confidence") if own else None) or ch_conf
            c_basis = ((c.get("discipline_basis") if own else None) or ch_basis or "")[:400]
            if c_disc is None:
                m["no_discipline"] += 1

            # cite THIS concept's section evidence where the engineer named the section it came from;
            # fall back to the chapter only when it did not
            sec_key = _section_key(c.get("section_heading"))
            if sec_key and sec_key in sec_chunk:
                ev_chunks = [sec_chunk[sec_key]]
                ev_pages = [sec_page[sec_key]] if sec_key in sec_page else []
            else:
                ev_chunks = spine[n]["chunk_ids"][:40]
                ev_pages = sorted(spine[n]["pages"])[:20]

            kcid = S.concept_id(book["subject"], book["taught_at_class"], name)
            # content-address each ref to the substrate at propose time (R1-4): store the sha alongside
            # the positional chunk_id so later drift (re-chunk) is detectable and the gate can verify it.
            ev_sha = evidence_sha_for(kconn, ev_chunks)
            conn.execute(
                "INSERT OR REPLACE INTO ki_concept (concept_id, chapter_id, subject, taught_at_class, "
                "canonical_name, aliases, sub_concepts, prerequisites, boundary, evidence_chunks, "
                "evidence_sha256, evidence_pages, section_heading, extraction_basis, academic_discipline, "
                "discipline_basis, discipline_confidence, engineer_model, status, created_at) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (kcid, cid, book["subject"], book["taught_at_class"], name,
                 json.dumps(c.get("aliases") or []), json.dumps(c.get("sub_concepts") or []),
                 json.dumps(c.get("prerequisites") or []), json.dumps(c.get("boundary") or {}),
                 json.dumps(ev_chunks), json.dumps(ev_sha), json.dumps(ev_pages),
                 c.get("section_heading"), basis, c_disc, c_basis, c_conf, model, "proposed", _now()))
            m["concepts"] += 1

        for r in ch.get("rejects") or []:
            _reject(conn, book, r, f"engineer({model})")
            m["rejects"] += 1
    conn.commit()
    return m


def _reject(conn, book, r: dict, by: str) -> None:
    raw = (r.get("raw_label") or "")[:200]
    rid = "RJ_" + __import__("hashlib").sha256(
        f"{book['subject']}|{book['taught_at_class']}|{raw}|{by}".encode()).hexdigest()[:16]
    conn.execute(
        "INSERT OR REPLACE INTO ki_rejected (reject_id, subject, taught_at_class, raw_label, reject_class, "
        "reason, source_ref, rejected_by, created_at) VALUES (?,?,?,?,?,?,?,?,?)",
        (rid, book.get("subject"), book.get("taught_at_class"), raw,
         r.get("reject_class") or "not_a_concept", (r.get("reason") or "")[:400],
         r.get("source_ref") or json.dumps({"doc_id": book.get("doc_id")}), by, _now()))


def save_deterministic_rejects(conn, book: dict, rejects: List[dict]) -> int:
    for r in rejects:
        _reject(conn, book, r, "deterministic")
    conn.commit()
    return len(rejects)


def save_book(conn, book: dict) -> None:
    conn.execute(
        "INSERT OR REPLACE INTO ki_source (doc_id, rel_path, book_code, subject, taught_at_class, "
        "subject_basis, is_integrated, chunks, created_at) VALUES (?,?,?,?,?,?,?,?,?)",
        (book["doc_id"], book["rel_path"], book.get("book_code"), book["subject"],
         book["taught_at_class"], book["subject_basis"], int(bool(book.get("is_integrated"))),
         book.get("chunks"), _now()))
    conn.commit()


# ── STAGE 1c — INDEPENDENT AUDIT ────────────────────────────────────────────────────────────────────
AUDIT_BRIEF = """\
You are an INDEPENDENT CURRICULUM AUDITOR. Another model proposed these knowledge records from an owned
NCERT textbook chapter. You did not write them and you cannot see its reasoning. Your job is to REFUSE
anything that should not become curriculum truth — this index is what every generated question will trust.

A record is only acceptable if ALL of these hold:
- it names a real, assessable ACADEMIC CONCEPT (not a section header, activity label, book apparatus,
  OCR garbage, truncated heading, or a fragment of a sentence)
- it is genuinely TAUGHT at the stated class in the Indian NCERT curriculum (not merely mentioned, and
  not actually a higher-class topic)
- the canonical name is a name a teacher would recognise and use. OCR damage must have been REPAIRED,
  not copied: "DIMENSIONAL FORMULAE ANDDIMENSIONAL EQUATIONS" is not an acceptable canonical name.
- `prerequisites`, where non-empty, are genuinely required AND are at or below this class
- `boundary.out_of_scope` does not exclude something the class actually does cover, and does not permit
  something it does not
- it is not a duplicate of another concept in the same chapter under a different name
- `academic_discipline` is right FOR THE EVIDENCE. This one matters most on the integrated Science books
  (classes 6-10), where nothing in the source states a discipline. Judge it yourself from the concept and
  its chapter: pressure/force/motion/light/electricity => Physics; materials/reactions/acids/metals =>
  Chemistry; cells/organisms/nutrition/ecosystems => Biology. `Interdisciplinary` must be EARNED by the
  evidence, not used as a hedge — if the concept is really just one discipline, say so.
  The CURRICULUM SUBJECT ("Science") is not up for review: it is proven from the book and is a separate
  dimension. You are reviewing only the discipline claim.

Default to `reject` for junk, and `quarantine` for genuine uncertainty. Accepting a bad record is far worse
than quarantining a good one — a bad record silently mis-tags every question generated from it.

OUTPUT — JSON array, concept_id copied EXACTLY, no prose outside the JSON:
{"concept_id":"KC_...","verdict":"accept|reject|quarantine",
 "correct_class": 8,
 "correct_discipline": "Physics",
 "reasons":"<one short sentence; REQUIRED unless verdict is accept>"}
Set `correct_class` only when you believe the stated class is wrong; otherwise omit it.
Set `correct_discipline` only when the stated discipline is wrong; otherwise omit it. Correcting the
discipline does NOT by itself require a reject — use `accept` with `correct_discipline` when the concept
is sound and only its discipline label needs moving.

## RECORDS
"""


def write_audit_worksheet(conn, path: str, subject: str, limit: int = None, cls: int = None,
                          kconn=None) -> int:
    q = ("SELECT c.concept_id, c.canonical_name, c.taught_at_class, c.sub_concepts, c.prerequisites, "
         "c.boundary, c.section_heading, c.academic_discipline, c.discipline_basis, c.evidence_chunks, "
         "ch.title AS chapter_title, s.is_integrated "
         "FROM ki_concept c JOIN ki_chapter ch ON ch.chapter_id=c.chapter_id "
         "JOIN ki_source s ON s.doc_id=ch.doc_id "
         "WHERE c.subject=? AND c.status='proposed'")
    args = [subject]
    if cls is not None:
        q += " AND c.taught_at_class=?"
        args.append(cls)
    q += " ORDER BY c.taught_at_class, ch.chapter_no"
    if limit:
        q += f" LIMIT {int(limit)}"
    rows = conn.execute(q, args).fetchall()
    recs = [{"evidence": _evidence_for(kconn, r["evidence_chunks"], heading=r["section_heading"])}
            for r in rows]
    dups = duplicate_evidence_groups(recs)
    with open(path, "w") as f:
        f.write(AUDIT_BRIEF)
        for idx, r in enumerate(rows):
            f.write(json.dumps({
                "concept_id": r["concept_id"], "curriculum_subject": subject,
                "taught_at_class": r["taught_at_class"], "chapter": r["chapter_title"],
                "canonical_name": r["canonical_name"],
                "sub_concepts": json.loads(r["sub_concepts"] or "[]"),
                "prerequisites": json.loads(r["prerequisites"] or "[]"),
                "boundary": json.loads(r["boundary"] or "{}"),
                "section_heading": r["section_heading"],
                "academic_discipline": r["academic_discipline"],
                "discipline_basis": r["discipline_basis"],
                "discipline_was_inferred": bool(r["is_integrated"]),
                # true => the record itself says its grounding is in a DIFFERENT section. Scrutinise: if its
                # own attached evidence does not teach the concept, quarantine — never certify on a promise.
                "engineer_confesses_external_grounding": _confesses_external_grounding(
                    r["sub_concepts"], r["boundary"], r["discipline_basis"]),
                # true => this record's evidence window is (near-)identical to an EARLIER record's. That is
                # the mis-anchor signature: the right heading prefixed to the WRONG body. The earlier record
                # is usually the genuinely-covered one; THIS one is probably asserting content its evidence
                # never teaches. Scrutinise hard — quarantine unless its own evidence teaches the concept.
                "duplicate_evidence_of_earlier_record": idx in dups,
                # THE EVIDENCE THIS RECORD RESTS ON. Certification requires evidence — model agreement is
                # not certification (owner rule 8). Without this the audit could only check plausibility
                # against its own syllabus memory, which is the exact failure the index exists to prevent.
                "evidence": recs[idx]["evidence"],
            }, ensure_ascii=False) + "\n")
        f.write(f"\nReturn ONLY the JSON array of {len(rows)} verdict objects.\n")
    return len(rows)


def _evidence_for(kconn, evidence_chunks_json: str, heading: str = None, limit: int = 1800) -> str:
    """The owned source text a proposed record cites, so the audit can check it against the book.

    Seeks to the record's OWN heading before excerpting, and reads forward from the cited chunk. A blind
    prefix of the first chunk showed the auditor the PREVIOUS section's exercises instead of the text the
    record rests on — which made honest records look unsupported and pushed real concepts into quarantine
    for a defect in the harness rather than in the record.
    """
    try:
        ids = json.loads(evidence_chunks_json or "[]")
    except (ValueError, TypeError):
        return ""
    if not ids or kconn is None:
        return ""
    rows = kconn.execute(
        "SELECT text FROM chunks WHERE doc_id=(SELECT doc_id FROM chunks WHERE chunk_id=?) "
        "AND ordinal >= (SELECT ordinal FROM chunks WHERE chunk_id=?) ORDER BY ordinal LIMIT 6",
        (ids[0], ids[0])).fetchall()
    txt = " ".join(re.sub(r"\s+", " ", (r[0] or "")).strip() for r in rows).strip()
    title = re.sub(r"^\s*\d{1,2}\.\d{1,2}(?:\.\d{1,2})?\s*", "", heading or "").strip()
    if title:
        # case-insensitive: OCR prints headings ALL-CAPS while the record's title is Title-Case
        i = txt.lower().find(title[:28].lower())
        if i > 0:
            txt = txt[i:]
    return txt[:limit]


def ingest_audit(conn, payload: List[dict], model: str, kconn=None) -> Dict[str, int]:
    """Only `accept` promotes to certified — AND only if the DETERMINISTIC EVIDENCE GATE passes (R1-4).

    The AI auditor's word is necessary but not sufficient: `kconn` (a read-only kie.db handle) is REQUIRED
    so every would-be-certified concept's cited evidence can be resolved + sha-checked + substance-checked.
    A gate failure forces `quarantined` regardless of the AI verdict — the auditor cannot waive it."""
    if kconn is None:
        raise ValueError(
            "ingest_audit requires kconn (kie.db, read-only): the deterministic evidence gate cannot "
            "certify without substrate access (fail-closed, R1-4).")
    m = {"in": 0, "certified": 0, "rejected": 0, "quarantined": 0, "unmatched": 0, "class_corrected": 0,
         "discipline_corrected": 0, "gate_quarantined": 0}
    for v in payload:
        cid = v.get("concept_id")
        row = conn.execute("SELECT concept_id, subject, taught_at_class, canonical_name, "
                           "academic_discipline FROM ki_concept WHERE concept_id=?", (cid,)).fetchone()
        if not row:
            m["unmatched"] += 1
            continue
        m["in"] += 1
        verdict = v.get("verdict") or "quarantine"
        status = {"accept": "certified", "reject": "rejected", "quarantine": "quarantined"}.get(verdict, "quarantined")
        reasons_txt = (v.get("reasons") or "")[:400]
        # DETERMINISTIC EVIDENCE GATE — an `accept` may certify only if its evidence survives. On gate-fail
        # the concept is quarantined (honest-null), not certified, and the reason is recorded verbatim.
        if status == "certified":
            crow = conn.execute(
                "SELECT concept_id, canonical_name, section_heading, evidence_chunks, evidence_sha256 "
                "FROM ki_concept WHERE concept_id=?", (cid,)).fetchone()
            ok, gate_reason = evidence_gate(kconn, crow)
            if not ok:
                status = "quarantined"
                reasons_txt = (f"evidence gate: {gate_reason} | {reasons_txt}")[:400]
                m["gate_quarantined"] += 1
        conn.execute("UPDATE ki_concept SET audit_verdict=?, audit_reasons=?, audit_model=?, status=? "
                     "WHERE concept_id=?",
                     (verdict, reasons_txt, model, status, cid))

        # The auditor may move the INFERRED dimension without touching the proven one. The concept_id is
        # unaffected by design (it hashes curriculum subject, not discipline), so nothing downstream that
        # already references this concept breaks.
        new_disc = v.get("correct_discipline")
        if new_disc in DISCIPLINES and new_disc != row["academic_discipline"]:
            conn.execute("UPDATE ki_concept SET academic_discipline=?, discipline_basis=? "
                         "WHERE concept_id=?",
                         (new_disc, f"discipline corrected by independent audit({model}): "
                                    f"{(v.get('reasons') or '')[:300]}", cid))
            m["discipline_corrected"] += 1
        if verdict == "reject":
            _reject(conn, {"subject": row["subject"], "taught_at_class": row["taught_at_class"],
                           "doc_id": None},
                    {"raw_label": row["canonical_name"], "reject_class": "unsupported",
                     "reason": v.get("reasons")}, f"audit({model})")
        if v.get("correct_class") and v["correct_class"] != row["taught_at_class"]:
            m["class_corrected"] += 1
        # count by the ACTUAL persisted status (the gate may have flipped an `accept` to quarantined)
        m[status] += 1
    conn.commit()
    return m
