"""STAGE 1.5 — CERTIFIED QUESTION DESIGN INTELLIGENCE, learned from owned real-exam evidence.

The curriculum index says WHAT may be asked. This layer says HOW a genuinely good question is BUILT —
the machinery that makes real JEE/NEET items hard, twisted, and genuinely multi-concept. Concept-only
generation cannot reach that quality, and the 1,000-spec trial showed why: the generator produced clean,
correct, class-appropriate items, but nothing in the planner told it what makes an item *good* rather than
merely valid.

SOURCE: ~20k already-chunked chunks of real NEET / JEE Main / JEE Advanced / AIIMS papers we own.
No re-download. No re-OCR. Read-only against kie.db.

THE TWO HARD RULES, ENFORCED IN CODE (not just asked for in a prompt):

1. **NEVER copy source wording.** `assert_no_copying()` compares every stored text field against the source
   chunk it was learned from, at the token-shingle level. A pattern that echoes the source is REJECTED as
   `copies_source_wording`, not stored. Structure is transferable; wording is not ours to reuse.

2. **AI interpretation is never automatic truth.** The analyst PROPOSES; an INDEPENDENT auditor that never
   saw the analyst's reasoning disposes. Only `accept` promotes to `certified`. This mirrors the governance
   already proven in the trial, where a blind judge caught a 25.3% curriculum-tag failure the gates missed.

Provenance (doc_id/chunk_id/exam/year) rides on every pattern so any design claim is traceable to the real
item that evidences it — without that item's words ever being stored.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

from kie import config

QDI_SCHEMA = Path(__file__).resolve().parent / "qdi_schema.sql"

# ── EVIDENCE FLOOR (R1-3) ─────────────────────────────────────────────────────────────────────────
# Ported from the structural miner's rule (kie/qie/mine.py:295 `if n_dna >= 5 and n_res >= 2`) so the two
# lanes stay in lockstep. A certified QDI pattern must rest on >=5 real evidence items drawn from >=2
# distinct source resources. These counts are COMPUTED from evidence_refs at ingest, never analyst-asserted.
QDI_MIN_EVIDENCE_ITEMS = 5
QDI_MIN_EVIDENCE_RESOURCES = 2


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


# columns added after the original qdi_schema.sql shipped; each is nullable/additive so an existing qdi.db
# migrates in place without touching data (R1-3). Kept in sync with qdi_schema.sql's CREATE TABLE.
_QDP_MIGRATIONS = (
    ("evidence_resource_count", "INTEGER"),
    ("floor_passed_at", "TEXT"),
    ("provenance_verified", "INTEGER DEFAULT 0"),
)


def _migrate_qdi_pattern(conn: sqlite3.Connection) -> None:
    """Idempotent, PRAGMA-guarded ALTERs so `open_qdi` upgrades an existing qdi.db in place (additive only)."""
    have = {r[1] for r in conn.execute("PRAGMA table_info(qdi_pattern)")}
    for col, ddl in _QDP_MIGRATIONS:
        if col not in have:
            conn.execute(f"ALTER TABLE qdi_pattern ADD COLUMN {col} {ddl}")


def open_qdi(conn: sqlite3.Connection) -> sqlite3.Connection:
    """QDI tables live alongside the knowledge index but are a DISTINCT namespace (qdi_*), never merged
    into ki_*. Curriculum evidence and design evidence must not contaminate one another."""
    conn.executescript(QDI_SCHEMA.read_text())
    _migrate_qdi_pattern(conn)
    conn.commit()
    return conn


# ── ANTI-COPYING GATE (deterministic; runs before anything is stored) ────────────────────────────────
_WORD = re.compile(r"[a-z0-9]+")


def _shingles(text: str, n: int = 5) -> Set[str]:
    w = _WORD.findall((text or "").lower())
    return {" ".join(w[i:i + n]) for i in range(max(0, len(w) - n + 1))}


def copying_score(candidate_text: str, source_text: str, n: int = 5) -> float:
    """Fraction of the candidate's n-gram shingles that appear verbatim in the source."""
    c = _shingles(candidate_text, n)
    if not c:
        return 0.0
    s = _shingles(source_text, n)
    if not s:
        return 0.0
    return len(c & s) / len(c)


# content-word (unigram) reuse catches a heavy PARAPHRASE that displaces a token every few words so no
# 5-gram survives, yet reuses most of the source's actual vocabulary. The deterministic floor catches
# verbatim + gross paraphrase; subtler semantic copying is the INDEPENDENT MODEL AUDITOR's job.
_STOP = {"the", "a", "an", "of", "to", "in", "on", "at", "is", "are", "be", "and", "or", "for", "with",
         "by", "that", "this", "it", "as", "from", "which", "into", "its", "their", "than", "then", "so",
         "not", "no", "if", "but", "each", "any", "all", "one", "two", "when", "where", "how"}


def _content_words(text: str) -> Set[str]:
    return {w for w in _WORD.findall((text or "").lower()) if w not in _STOP and len(w) > 2}


def word_overlap(candidate_text: str, source_text: str) -> float:
    """Fraction of the candidate's distinct content words that also appear in the source."""
    c = _content_words(candidate_text)
    if not c:
        return 0.0
    return len(c & _content_words(source_text)) / len(c)


def assert_no_copying(pattern: dict, source_text: str, threshold: float = 0.12) -> Optional[str]:
    """-> reason if the pattern echoes source wording, else None.

    Checks every free-text field a pattern stores. Abstract design language ("a state change mid-problem
    forces re-evaluation of the conserved quantity") shares almost no 5-gram shingles with a source stem;
    a copied or lightly-paraphrased stem shares many.
    """
    fields = [pattern.get("design_summary") or "", pattern.get("pattern_name") or ""]
    for key in ("reasoning_chain", "difficulty_mechanism", "transformation", "solution_structure",
                "constraints", "misconceptions"):
        v = pattern.get(key)
        if isinstance(v, list):
            fields += [str(x) for x in v]
    joined = " ".join(fields)
    score = copying_score(joined, source_text)
    if score >= threshold:
        return f"copies_source_wording: {score:.0%} of pattern shingles appear verbatim in the source chunk"
    # heavy paraphrase: few 5-grams survive but most content words are reused from THIS source chunk
    wo = word_overlap(joined, source_text)
    if wo >= 0.65:
        return f"copies_source_wording: {wo:.0%} of the pattern's content words are reused from the source (paraphrase)"
    # a stem-shaped sentence is a tell even when shingles miss (light paraphrase)
    for f in fields:
        if re.search(r"\b(find|calculate|evaluate|determine)\b.{0,80}\?$", f.strip(), re.I) and len(f) > 60:
            return "copies_source_wording: a field is phrased as a question stem rather than as design structure"
    return None


# ── source selection ────────────────────────────────────────────────────────────────────────────────
def exam_sources(kconn: sqlite3.Connection, subject: Optional[str] = None,
                 exams: Tuple[str, ...] = ("JEE_Main", "JEE_Advanced", "NEET", "AIIMS")) -> List[dict]:
    """Owned, already-chunked real exam papers OF THE REQUESTED EXAM(S).

    EXAM is a reliable DOCUMENT property (the `category`/`exam` column) and is matched here. SUBJECT is NOT
    filtered at the document level: NEET/JEE papers are COMBINED multi-subject papers (Physics+Chemistry+
    Biology/Maths in one PDF), so a per-document subject tag is an artifact of a whole-document frequency
    classifier and is unreliable. Subject is a SECTION property, resolved per chunk downstream
    (`resolve_chunk_subjects` / `candidate_chunks(subject=...)`).

    ROOT-CAUSE FIX: the previous query OR'd the exam restriction with `rel_path LIKE '%Previous_Papers%'`,
    which silently BYPASSED the exam filter and returned NEET papers for a JEE request — the proven origin of
    the JEE-Physics -> NEET-Biology leak. Here a doc qualifies only if its own exam identity is one requested.
    The `subject` argument is accepted for call compatibility but intentionally NOT used to filter documents.
    """
    # single canonical exam identity: COALESCE(exam, category). Using ONE column removes the latent
    # broadening of `category IN (...) OR exam IN (...)` (safe only while category==exam) — a doc now
    # qualifies solely on its own exam identity.
    ph = ",".join("?" * len(exams))
    q = ("SELECT doc_id, rel_path, category, exam, subject, year, "
         "(SELECT COUNT(*) FROM chunks c WHERE c.doc_id=sd.doc_id) AS n "
         f"FROM source_documents sd WHERE COALESCE(exam, category) IN ({ph})")
    out = []
    for r in kconn.execute(q, list(exams)):
        if r["n"]:
            out.append({"doc_id": r["doc_id"], "rel_path": r["rel_path"], "exam": r["exam"] or r["category"],
                        "subject": r["subject"], "year": r["year"], "chunks": r["n"]})
    return sorted(out, key=lambda d: -d["chunks"])


def save_source(conn: sqlite3.Connection, s: dict) -> None:
    conn.execute("INSERT OR REPLACE INTO qdi_source (doc_id, rel_path, exam, subject, year, chunks, created_at) "
                 "VALUES (?,?,?,?,?,?,?)",
                 (s["doc_id"], s["rel_path"], s.get("exam"), s.get("subject"), s.get("year"),
                  s.get("chunks"), _now()))
    conn.commit()


# ── PROVENANCE INVARIANT (R1-3) ──────────────────────────────────────────────────────────────────────
def ref_doc_id(kconn: sqlite3.Connection, ref: dict) -> Optional[str]:
    """The canonical doc_id an evidence ref rests on. Prefer an already-backfilled ref['doc_id']; else
    resolve it from the ref's chunk_id via kie.db `chunks.doc_id` (the authoritative identity — never a
    string split of the chunk_id)."""
    if ref.get("doc_id"):
        return ref["doc_id"]
    cid = ref.get("chunk_id")
    if not cid:
        return None
    row = kconn.execute("SELECT doc_id FROM chunks WHERE chunk_id=?", (cid,)).fetchone()
    return row[0] if row else None


def canonical_doc(kconn: sqlite3.Connection, doc_id: str) -> Optional[dict]:
    """The canonical source_documents row for a doc (exam identity is authoritative; the doc-level subject
    tag is NOT trusted for subject — subject is resolved per chunk)."""
    r = kconn.execute("SELECT doc_id, rel_path, category, exam, subject, year, "
                      "(SELECT COUNT(*) FROM chunks c WHERE c.doc_id=sd.doc_id) AS n "
                      "FROM source_documents sd WHERE doc_id=?", (doc_id,)).fetchone()
    if not r:
        return None
    return {"doc_id": r["doc_id"], "rel_path": r["rel_path"], "exam": r["exam"] or r["category"],
            "subject": r["subject"], "year": r["year"], "chunks": r["n"]}


def assert_provenance(kconn: sqlite3.Connection, pattern: dict) -> Optional[str]:
    """-> reason if the pattern's declared (exam, subject) does NOT hold for EVERY evidence doc, else None.

    THE R1-3 PROVENANCE INVARIANT (fail-closed):
      * a pattern's declared `exam` must equal EVERY evidence doc's CANONICAL exam identity
        (COALESCE(exam, category) from kie.db source_documents — the post-8fb31ac7 `exam_sources()` rule);
      * a pattern's declared `subject` must equal EVERY evidence chunk's SECTION-RESOLVED subject
        (`resolve_chunk_subjects`), NOT the unreliable whole-document subject tag — that tag is the exact
        defect that let PHYSICS chunks in a Mathematics-tagged JEE_Advanced paper be certified as JEE_Main
        Mathematics design intelligence.
    An unfetchable chunk, an unknown doc, or a `None` chunk-subject resolution all FAIL CLOSED (a pattern
    whose provenance cannot be verified is not certifiable — wrong knowledge is worse than missing knowledge).
    This single invariant recalls all 7 pre-fix certified patterns (5 on exam Practice_Resources != JEE_Main;
    2 on exam JEE_Advanced != JEE_Main and chunk-subject Physics/None != Mathematics)."""
    refs = pattern.get("evidence_refs")
    if isinstance(refs, str):
        try:
            refs = json.loads(refs or "[]")
        except Exception:
            refs = []
    refs = refs or []
    if not refs:
        return "provenance: pattern has no evidence_refs (unverifiable)"
    p_exam = pattern.get("exam")
    p_subject = pattern.get("subject")
    _subjcache: Dict[str, Dict[str, Optional[str]]] = {}
    for ref in refs:
        cid = ref.get("chunk_id")
        doc_id = ref_doc_id(kconn, ref)
        if not doc_id:
            return f"provenance: evidence chunk {cid!r} not found in kie.db (unverifiable)"
        doc = canonical_doc(kconn, doc_id)
        if not doc:
            return f"provenance: evidence doc {doc_id!r} not found in kie.db (unverifiable)"
        if doc["exam"] != p_exam:
            return (f"provenance: exam mismatch — chunk {cid!r} doc canonical exam {doc['exam']!r} "
                    f"!= pattern exam {p_exam!r}")
        if doc_id not in _subjcache:
            _subjcache[doc_id] = resolve_chunk_subjects(kconn, doc_id)
        chunk_subject = _subjcache[doc_id].get(cid)
        if chunk_subject != p_subject:
            return (f"provenance: subject mismatch — chunk {cid!r} section-resolved subject "
                    f"{chunk_subject!r} != pattern subject {p_subject!r}")
    return None


def save_ref_sources(qconn: sqlite3.Connection, kconn: sqlite3.Connection, refs) -> int:
    """Populate qdi_source (the 'real-exam sources design intelligence was learned FROM' provenance table)
    for every DISTINCT canonical doc an evidence ref list rests on. Returns the number of docs saved."""
    if isinstance(refs, str):
        try:
            refs = json.loads(refs or "[]")
        except Exception:
            refs = []
    seen: Set[str] = set()
    for ref in refs or []:
        doc_id = ref_doc_id(kconn, ref)
        if not doc_id or doc_id in seen:
            continue
        doc = canonical_doc(kconn, doc_id)
        if not doc:
            continue
        save_source(qconn, doc)
        seen.add(doc_id)
    return len(seen)


# ── the analyst brief ───────────────────────────────────────────────────────────────────────────────
ANALYST_BRIEF = """\
You are a QUESTION DESIGN ANALYST. You are reading REAL previous-year exam questions (JEE Main / JEE
Advanced / NEET / AIIMS) that we own. Your job is to extract the ABSTRACT DESIGN MACHINERY that made each
good question work — so that ORIGINAL questions of the same calibre can be constructed later.

## THE TWO ABSOLUTE RULES
1. **NEVER reproduce the source question's wording, numbers, options, or phrasing.** Not in any field.
   You are extracting STRUCTURE, not text. Your output is machine-checked against the source: any field
   that echoes the source is rejected outright. If you find yourself writing "Find the value of x when...",
   stop — that is the question, not its design.
2. **Only claim what the evidence supports.** If a chunk is OCR sludge, or you cannot tell what the item's
   machinery was, do not guess — put it under `rejects`. A fabricated pattern silently corrupts every
   question generated from it.

## WHAT A DESIGN PATTERN IS
Not "a question about capacitors". A pattern is the reusable machinery:
  BAD  (too vague)    : "hard capacitor question"
  BAD  (copies source): "Two capacitors of 2 uF and 3 uF connected across 100 V, find final charge"
  GOOD (structure)    : pattern_name: "switched-state energy redistribution"
                        design_summary: "A system is set in one configuration and allowed to reach a
                        steady state; a switch/connection then changes the configuration. The candidate
                        must recognise that a conserved quantity carries across the change while a
                        non-conserved one does not, and re-derive the post-change state. Difficulty comes
                        from the implicit state change, not from arithmetic."

## FOR EACH PATTERN, EXTRACT WHERE THE EVIDENCE SUPPORTS IT
- `archetype`: from the canonical list you are given. Do not invent one.
- `concept_roles`: the ROLE each concept plays (e.g. {"role":"supplies the constraint","what_it_contributes":
  "fixes one unknown so the second relation becomes solvable"}). Roles, not just concept names.
- `composition_kind`: single | sequential_chain | constraint_coupled | state_change | inverse_construction | ...
- `dependency`: HOW concept B consumes concept A's output. This is what makes an item genuinely
  multi-concept rather than two topics named in one sentence. If there is no real dependency, say
  composition_kind = "single" — do NOT inflate it.
- `reasoning_chain`: the ordered ABSTRACT steps a solver must perform. No numbers, no source wording.
- `operators`: the relations/operations applied between concepts.
- `constraints`: constraint structures that must hold for the item to be well-posed.
- `difficulty_mechanism`: what ACTUALLY makes it hard. Be specific and honest. "ugly arithmetic" is NOT a
  difficulty mechanism — say so if that is all there is. Real ones: a non-obvious intermediate inference,
  an implicit state change, a constraint that must be discovered, a representation change, a trap that
  punishes a common shortcut.
- `transformation`: information transformation / indirect presentation (e.g. the quantity asked for is not
  the quantity given; data supplied in a graph rather than numerically; the unknown is embedded in a ratio).
- `distractor_structure`: for each wrong option that reveals a misconception — {"misconception": "<named
  student error>", "produces": "<what that error yields>"}. NAME the misconception. "other" is not an answer.
- `visual_archetype` + `visual_necessity`: only if a figure is genuinely load-bearing.
- `solution_structure`: the abstract shape of a solution that works for this pattern.
- `difficulty_band`: easy | moderate | hard, as evidenced by the item's role in a real paper.

Merge duplicates: if several real items share one machinery, emit ONE pattern with `evidence_refs` listing
each, and set `evidence_count`. A pattern evidenced by many real items is worth more than a one-off.

## OUTPUT — JSON array, no prose outside the JSON:
{"patterns": [ {..pattern fields.., "evidence_refs": [{"chunk_id":"...","exam":"JEE_Main"}], "evidence_count": 3} ],
 "rejects":  [ {"pattern_name":"...", "reject_class":"ocr_garbage|not_a_pattern|unsupported_by_evidence|relabelled_single_concept", "reason":"..."} ]}

## CANONICAL ARCHETYPES
{archetypes}

## REAL EXAM EVIDENCE
"""


def write_analyst_worksheet(kconn: sqlite3.Connection, chunk_rows: List[sqlite3.Row], path: str,
                            archetypes: Tuple[str, ...]) -> int:
    with open(path, "w") as f:
        f.write(ANALYST_BRIEF.replace("{archetypes}", ", ".join(archetypes)))
        for r in chunk_rows:
            f.write(json.dumps({
                "chunk_id": r["chunk_id"], "exam": r["exam"], "subject": r["subject"],
                "year": r["year"], "text": re.sub(r"\s+", " ", r["text"] or "")[:2600],
            }, ensure_ascii=False) + "\n")
        f.write(f"\nReturn ONLY the JSON object described above, over these {len(chunk_rows)} evidence chunks.\n")
    return len(chunk_rows)


# A combined exam paper carries its subject structure in explicit section headers ("Section - A (Physics)",
# "PART C (Botany)", ...). Subject is resolved from THESE, not from the whole-document frequency tag.
#
# R3-7: the old regex (`section ... (subject)?` with the parens OPTIONAL and the subject allowed within 14
# loose chars) also matched PROSE — "in this section, physics of the problem ..." resolved a whole chunk to
# Physics off a stray sentence. This ANCHORED header regex fires on the real header STRUCTURE only, via two
# branches, neither of which a running-prose sentence satisfies:
#   (p) the section keyword IMMEDIATELY followed (bar an optional "- A" / "C" / ":" label) by a PARENTHESISED
#       subject — "(Physics)". Prose does not parenthesise its subject, so this defeats the stray-sentence
#       match while still catching a header embedded MID-CHUNK across a section boundary.
#   (b) a LINE-ANCHORED bare header "SECTION A : PHYSICS" at the start of a line, with a delimiter before the
#       subject (so a line that merely begins with the word "section" in prose cannot match).
_SECTION_SUBJECT = re.compile(
    r"(?im)"
    r"(?:"
    # (p) section keyword + optional label + a PARENTHESISED subject "(Physics)" that INTRODUCES a section — i.e.
    #     the paren is followed by a question number or the line/chunk end. That trailing signal (adversarial-
    #     verifier fix) is what a genuine header has and running prose does not: "Section - B (Chemistry) 2. …"
    #     matches while "in this part (physics) we analyse …" (paren followed by lowercase prose) does NOT.
    r"\b(?:section|part)\b[ \t]*[-–—:]?[ \t]*[a-z0-9]{0,3}[ \t]*"
    r"\(\s*(?P<p>physics|chemistry|botany|zoology|biology|mathematics|maths)\s*\)(?=\s*(?:\d|$))"
    r"|"
    r"^[ \t]*(?:section|part)\b[ \t]*[-–—:]?[ \t]*[a-z0-9]{0,3}[ \t]*[:\-–—][ \t]*"
    r"(?P<b>physics|chemistry|botany|zoology|biology|mathematics|maths)\b"
    r")")


def _marker_subject(m: "re.Match") -> Optional[str]:
    """Canonical subject for a section-header match, from whichever branch (parenthesised or bare) fired."""
    return _SUBJECT_CANON.get((m.group("p") or m.group("b") or "").lower())
_SUBJECT_CANON = {"physics": "Physics", "chemistry": "Chemistry", "botany": "Biology", "zoology": "Biology",
                  "biology": "Biology", "mathematics": "Mathematics", "maths": "Mathematics"}
# chars of content BEFORE a chunk's first section marker that make it a genuine mixed BOUNDARY chunk
_BOUNDARY_PREFIX = 120


def resolve_chunk_subjects(kconn: sqlite3.Connection, doc_id: str) -> Dict[str, Optional[str]]:
    """{chunk_id: true subject} for a (possibly combined) paper. Walks chunks in `ordinal` order and
    propagates the most-recent in-paper section-subject marker. Chunks before the first marker stay None
    (never guessed). A chunk that carries substantial content BEFORE a subject-changing marker is a mixed
    BOUNDARY chunk — its prefix belongs to the previous subject and its suffix to the new one; rather than
    contaminate either subject with the other's text, it is marked None (excluded from subject-filtered
    reads). This is where SUBJECT correctly lives for combined papers."""
    rows = kconn.execute("SELECT chunk_id, text FROM chunks WHERE doc_id=? ORDER BY ordinal", (doc_id,)).fetchall()
    out: Dict[str, Optional[str]] = {}
    current: Optional[str] = None
    for r in rows:
        markers = list(_SECTION_SUBJECT.finditer(r["text"] or ""))
        if not markers:
            out[r["chunk_id"]] = current
            continue
        subs = [s for s in (_marker_subject(m) for m in markers) if s]
        trailing = subs[-1] if subs else current   # subject in effect at the END of the chunk (for the next one)
        if len(set(subs)) > 1:
            # R3-7: a chunk that itself spans >=2 DISTINCT subject sections cannot be attributed to ONE
            # subject — its earlier section's text would contaminate the later subject. Mark None (excluded
            # from subject-filtered reads); never collapse the whole chunk onto the LAST marker as before.
            out[r["chunk_id"]] = None
        else:
            new_subj = subs[0] if subs else current
            if markers[0].start() > _BOUNDARY_PREFIX and current is not None and current != new_subj:
                out[r["chunk_id"]] = None       # mixed boundary chunk — real content precedes a subject change
            else:
                out[r["chunk_id"]] = new_subj
        if trailing is not None:
            current = trailing
    return out


# page furniture that carries no question: exam instructions, OCR mojibake (bilingual Devanagari sludge),
# and content-free digital-exam HTML scaffolding (digialm dumps: "Question ID / Option ID / Status ...").
_BOILERPLATE = re.compile(r"read carefully|do not open|test booklet|instructions to|rough work|"
                          r"in case of any ambiguity|attempt (?:all|any)|answer sheet|omr", re.I)
_FURNITURE = re.compile(r"question id|option \d+ id|chosen option|status\s*:?\s*(answered|not answered)|"
                        r"response time|section\s*:?\s*answered", re.I)


def _usable_chunk(text: str) -> bool:
    """Reject exam-instruction boilerplate, OCR mojibake, and content-free HTML scaffolding — keep chunks
    with legible question text the analyst can actually mine."""
    t = text or ""
    if len(t) < 200 or _BOILERPLATE.search(t) or _FURNITURE.search(t):
        return False
    ascii_alnum = sum(1 for ch in t if ch.isascii() and ch.isalnum())
    return ascii_alnum >= 0.30 * len(t)  # too few Latin alphanumerics => Devanagari mojibake, skip


def candidate_chunks(kconn: sqlite3.Connection, doc_ids: List[str], subject: Optional[str] = None,
                     limit: int = 60) -> List[sqlite3.Row]:
    """Chunks that plausibly carry a real question + answer. When `subject` is given, keep ONLY chunks whose
    RESOLVED section-subject matches it (combined papers no longer leak other subjects to the analyst).
    Instruction boilerplate and OCR mojibake are dropped so the analyst spends tokens on real questions."""
    if not doc_ids:
        return []
    q = ("SELECT c.chunk_id, c.doc_id, c.text, sd.exam, sd.subject, sd.year FROM chunks c "
         "JOIN source_documents sd ON sd.doc_id = c.doc_id "
         "WHERE c.doc_id IN (%s) AND length(c.text) > 200 "
         "AND (c.text LIKE '%%Ans%%' OR c.text LIKE '%%(1)%%' OR c.text LIKE '%%(A)%%' OR c.text LIKE '%%Sol%%') "
         "ORDER BY length(c.text) DESC" % ",".join("?" * len(doc_ids)))
    rows = [r for r in kconn.execute(q, tuple(doc_ids)).fetchall() if _usable_chunk(r["text"])]
    if not subject:
        return rows[:limit]
    resolved = {d: resolve_chunk_subjects(kconn, d) for d in set(doc_ids)}
    kept = [r for r in rows if resolved.get(r["doc_id"], {}).get(r["chunk_id"]) == subject]
    return kept[:limit]


# ── ingest (analyst proposes) ───────────────────────────────────────────────────────────────────────
def _pid(exam: str, subject: str, name: str) -> str:
    return "QDP_" + hashlib.sha256(f"{exam}|{subject}|{name.strip().lower()}".encode()).hexdigest()[:14]


def ingest_patterns(conn: sqlite3.Connection, kconn: sqlite3.Connection, payload: dict,
                    exam: str, subject: str, model: str) -> Dict[str, int]:
    m = {"proposed": 0, "rejected_copying": 0, "rejected_by_analyst": 0, "malformed": 0,
         "rejected_unfetchable": 0}
    for p in payload.get("patterns") or []:
        name = (p.get("pattern_name") or "").strip()
        if not name:
            m["malformed"] += 1
            continue
        # A pattern IS its structured machinery; the prose summary is the least load-bearing field.
        # Accept a structure-complete pattern that omitted the prose, and compose the summary from the
        # structure rather than discarding real design intelligence over a missing string.
        if not (p.get("design_summary") or "").strip():
            chain = p.get("reasoning_chain") or []
            mech = p.get("difficulty_mechanism") or []
            if not chain and not mech:
                m["malformed"] += 1
                continue
            dep = p.get("dependency")
            p["design_summary"] = (
                f"Machinery: {p.get('composition_kind') or 'single'}. "
                + (f"Dependency: {json.dumps(dep)}. " if dep else "")
                + (f"Reasoning chain: {' -> '.join(str(c) for c in chain)}. " if chain else "")
                + (f"Difficulty arises from: {'; '.join(str(x) for x in mech)}." if mech else "")
            )[:1800]
            p["_summary_composed_from_structure"] = True

        # R1-3: an evidence-less pattern is unverifiable — never store it as `proposed`.
        refs = p.get("evidence_refs") or []
        if not refs:
            _reject_pattern(conn, exam, subject, name, "unsupported_by_evidence",
                            "no evidence_refs — a pattern must rest on real evidence", "[]", "deterministic")
            m["malformed"] += 1
            continue
        # backfill the canonical doc_id onto every ref (authoritative identity from kie.db, resolved once) so
        # downstream evidence/provenance checks never re-query and the stored refs are self-describing.
        for ref in refs:
            if not ref.get("doc_id"):
                did = ref_doc_id(kconn, ref)
                if did:
                    ref["doc_id"] = did

        # ANTI-COPYING GATE — compare against the actual source chunks this pattern claims to rest on.
        # FAIL CLOSED (R1-3): if the cited evidence cannot be fetched, anti-copy/provenance are unverifiable —
        # refuse the pattern rather than silently store it with the gate skipped.
        src = ""
        for ref in refs[:4]:
            row = kconn.execute("SELECT text FROM chunks WHERE chunk_id=?", (ref.get("chunk_id"),)).fetchone()
            if row:
                src += " " + (row[0] or "")
        if not src.strip():
            _reject_pattern(conn, exam, subject, name, "unsupported_by_evidence",
                            "evidence unfetchable — cannot verify anti-copy/provenance (fail-closed)",
                            json.dumps(refs), "deterministic")
            m["rejected_unfetchable"] += 1
            continue
        why = assert_no_copying(p, src)
        if why:
            _reject_pattern(conn, exam, subject, name, "copies_source_wording", why,
                            json.dumps(refs), f"deterministic")
            m["rejected_copying"] += 1
            continue

        # provenance table: record the real docs this design intelligence was learned FROM (never wording).
        save_ref_sources(conn, kconn, refs)
        n_items = len(refs)                                    # COMPUTED, never analyst-asserted
        n_resources = len({r.get("doc_id") for r in refs if r.get("doc_id")})
        pid = _pid(exam, subject, name)
        conn.execute(
            "INSERT OR REPLACE INTO qdi_pattern (pattern_id, exam, subject, archetype, pattern_name, "
            "design_summary, concept_roles, composition_kind, dependency, reasoning_chain, step_depth, "
            "operators, constraints, difficulty_mechanism, transformation, difficulty_band, "
            "distractor_structure, misconceptions, visual_archetype, visual_necessity, solution_structure, "
            "evidence_refs, evidence_count, evidence_resource_count, analyst_model, status, created_at) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (pid, exam, subject, p.get("archetype") or "", name, p.get("design_summary"),
             json.dumps(p.get("concept_roles") or []), p.get("composition_kind"),
             json.dumps(p.get("dependency") or {}), json.dumps(p.get("reasoning_chain") or []),
             len(p.get("reasoning_chain") or []) or None, json.dumps(p.get("operators") or []),
             json.dumps(p.get("constraints") or []), json.dumps(p.get("difficulty_mechanism") or []),
             json.dumps(p.get("transformation") or []), p.get("difficulty_band"),
             json.dumps(p.get("distractor_structure") or []), json.dumps(p.get("misconceptions") or []),
             p.get("visual_archetype"), p.get("visual_necessity"),
             json.dumps(p.get("solution_structure") or []), json.dumps(refs),
             n_items, n_resources, model, "proposed", _now()))
        m["proposed"] += 1

    for r in payload.get("rejects") or []:
        _reject_pattern(conn, exam, subject, r.get("pattern_name") or "?", r.get("reject_class") or "not_a_pattern",
                        r.get("reason"), json.dumps(r.get("evidence_refs") or []), f"analyst({model})")
        m["rejected_by_analyst"] += 1
    conn.commit()
    return m


def _reject_pattern(conn, exam, subject, name, cls, reason, refs, by) -> None:
    rid = "QRJ_" + hashlib.sha256(f"{exam}|{subject}|{name}|{by}".encode()).hexdigest()[:16]
    conn.execute("INSERT OR REPLACE INTO qdi_rejected (reject_id, exam, subject, pattern_name, reject_class, "
                 "reason, evidence_refs, rejected_by, created_at) VALUES (?,?,?,?,?,?,?,?,?)",
                 (rid, exam, subject, name[:200], cls, (reason or "")[:400], refs, by, _now()))


# ── independent audit (disposes) ────────────────────────────────────────────────────────────────────
QDI_AUDIT_BRIEF = """\
You are an INDEPENDENT DESIGN AUDITOR. Another model proposed these question-design patterns from real
exam papers. You did not write them and cannot see its reasoning. Refuse anything that should not become
design intelligence — every future generated question will be built from what you accept.

Reject a pattern if ANY of these hold:
- it reproduces or lightly paraphrases a specific source question instead of abstracting its machinery
  (a pattern should describe MACHINERY; if you can reconstruct the original item from it, reject)
- it is a topic label ("hard capacitor question") rather than a reusable construction mechanism
- `composition_kind` claims a real dependency but `dependency` shows none — a relabelled single-concept item
- `difficulty_mechanism` is empty, vacuous, or amounts to "the arithmetic is messy" (that is not difficulty)
- `distractor_structure` names no real misconception (an unnamed "other" is not a misconception)
- the reasoning_chain is not actually the chain that solves that kind of item
- it is unsupported by the cited evidence, or is a duplicate of another pattern

Accepting a bad pattern is far worse than quarantining a good one. Default to `quarantine` on genuine
uncertainty and `reject` on anything vacuous.

OUTPUT — JSON array, pattern_id copied EXACTLY, no prose outside the JSON:
{"pattern_id":"QDP_...","verdict":"accept|reject|quarantine","reasons":"<one sentence; REQUIRED unless accept>"}

## PATTERNS
"""


def write_qdi_audit_worksheet(conn: sqlite3.Connection, path: str, exam: str, subject: str) -> int:
    rows = conn.execute(
        "SELECT pattern_id, archetype, pattern_name, design_summary, concept_roles, composition_kind, "
        "dependency, reasoning_chain, operators, constraints, difficulty_mechanism, transformation, "
        "difficulty_band, distractor_structure, visual_archetype, visual_necessity, solution_structure, "
        "evidence_count FROM qdi_pattern WHERE exam=? AND subject=? AND status='proposed'", (exam, subject)
    ).fetchall()
    with open(path, "w") as f:
        f.write(QDI_AUDIT_BRIEF)
        for r in rows:
            d = {k: r[k] for k in r.keys()}
            for j in ("concept_roles", "dependency", "reasoning_chain", "operators", "constraints",
                      "difficulty_mechanism", "transformation", "distractor_structure", "solution_structure"):
                try:
                    d[j] = json.loads(d[j] or "[]")
                except Exception:
                    pass
            f.write(json.dumps(d, ensure_ascii=False) + "\n")
        f.write(f"\nReturn ONLY the JSON array of {len(rows)} verdict objects.\n")
    return len(rows)


def ingest_qdi_audit(conn: sqlite3.Connection, payload: List[dict], model: str) -> Dict[str, int]:
    """Dispose the independent auditor's verdicts. An `accept` promotes to `certified` ONLY when the two
    deterministic preconditions ALSO hold (R1-3) — the auditor model can never certify on agreement alone:
      * the MANDATORY deterministic floor ran and passed (`floor_passed_at` stamped) — proves anti-copy AND
        the exam+subject provenance invariant held;
      * the evidence meets QDI's own floor: >=QDI_MIN_EVIDENCE_ITEMS real items from
        >=QDI_MIN_EVIDENCE_RESOURCES distinct resources, COMPUTED from evidence_refs (never analyst-asserted).
    Either precondition failing DOWNGRADES an accept to `quarantined` with an explicit reason — a certified
    pattern is impossible without a clean, provenance-checked floor and sufficient corroborating evidence."""
    m = {"in": 0, "certified": 0, "rejected": 0, "quarantined": 0, "unmatched": 0, "refused_no_floor": 0,
         "refused_low_evidence": 0}
    for v in payload:
        pid = v.get("pattern_id")
        row = conn.execute("SELECT pattern_id, exam, subject, pattern_name, evidence_refs, "
                           "evidence_resource_count, floor_passed_at FROM qdi_pattern WHERE pattern_id=?",
                           (pid,)).fetchone()
        if not row:
            m["unmatched"] += 1
            continue
        m["in"] += 1
        verdict = v.get("verdict") or "quarantine"
        status = {"accept": "certified", "reject": "rejected",
                  "quarantine": "quarantined"}.get(verdict, "quarantined")
        reasons = (v.get("reasons") or "")[:400]
        if verdict == "accept":
            # precondition 1: the deterministic floor must have cleared this pattern
            if not row["floor_passed_at"]:
                status = "quarantined"
                reasons = "floor: deterministic floor never passed this pattern — cannot certify"
                m["refused_no_floor"] += 1
            else:
                # precondition 2: evidence threshold, recomputed from the DB (never trust the analyst)
                try:
                    refs = json.loads(row["evidence_refs"] or "[]")
                except Exception:
                    refs = []
                # BOTH counts recomputed from the evidence refs at cert time — never read from the stored
                # evidence_resource_count column (adversarial-verifier hardening: a hand-crafted INSERT could
                # otherwise fake a high resource count with the refs telling a different story).
                n_items = len(refs)
                n_res = len({r.get("doc_id") for r in refs if r.get("doc_id")})
                if not (n_items >= QDI_MIN_EVIDENCE_ITEMS and n_res >= QDI_MIN_EVIDENCE_RESOURCES):
                    status = "quarantined"
                    reasons = (f"floor: evidence below threshold (items={n_items}, resources={n_res}; "
                               f"need >={QDI_MIN_EVIDENCE_ITEMS} items & >={QDI_MIN_EVIDENCE_RESOURCES} resources)")
                    m["refused_low_evidence"] += 1
        conn.execute("UPDATE qdi_pattern SET audit_verdict=?, audit_reasons=?, audit_model=?, status=? "
                     "WHERE pattern_id=?", (verdict, reasons, model, status, pid))
        if verdict == "reject":
            _reject_pattern(conn, row["exam"], row["subject"], row["pattern_name"], "unsupported_by_evidence",
                            v.get("reasons"), "[]", f"audit({model})")
        m[status] += 1
    conn.commit()
    return m


def certified_patterns(conn: sqlite3.Connection, exam: str, subject: str, archetype: Optional[str] = None,
                       difficulty: Optional[str] = None) -> List[dict]:
    """The ONLY design intelligence a generation brief may use — EXAM-SCOPED (R3-7).

    Requires BOTH `exam` AND `subject`. The former subject-only filter let a JEE pattern attach to a NEET
    request (and vice-versa), because `subject` collides across exams (Physics/Chemistry/Mathematics appear in
    both). Filtering on the pattern's own certified `exam` identity closes that cross-exam leak AT THE
    ACCESSOR, so no caller can widen it back to subject-only. A NEET request can therefore never receive a
    JEE_Main/JEE_Advanced pattern."""
    q = "SELECT * FROM qdi_pattern WHERE exam=? AND subject=? AND status='certified'"
    args: List = [exam, subject]
    if archetype:
        q += " AND archetype=?"
        args.append(archetype)
    if difficulty:
        q += " AND difficulty_band=?"
        args.append(difficulty)
    out = []
    for r in conn.execute(q + " ORDER BY evidence_count DESC", args):
        d = {k: r[k] for k in r.keys()}
        for j in ("concept_roles", "reasoning_chain", "operators", "constraints", "difficulty_mechanism",
                  "transformation", "distractor_structure", "solution_structure", "evidence_refs"):
            try:
                d[j] = json.loads(d[j] or "[]")
            except Exception:
                pass
        out.append(d)
    return out
