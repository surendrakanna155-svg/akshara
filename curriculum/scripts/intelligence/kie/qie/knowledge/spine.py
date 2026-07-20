"""STAGE 1a — the DETERMINISTIC curriculum spine, extracted from owned OCR chunks.

No re-download. No re-OCR. This reads `kie.db` chunks/source_documents that already exist.

WHY THIS EXISTS: the old extractor promoted any heading-ish string to a concept, which is how
`Gahe tava jaya gatha` (a line of the national anthem) became an active Class-10 Mathematics concept,
and how `Contributors`, `Preamble`, `Pledge`, `Chief Advisor` and OCR sludge like `answeranswer` got in.
It also inherited `subject` and `grade` from the DOCUMENT, which is why Gauss's law exists three times
(Physics, Chemistry, Biology) and why `Class8_hegp1dd` — a Ganita Prakash MATHS book — is tagged Chemistry.

The fix is a process, not a patch-list:

1. SUBJECT comes from the NCERT filename code, never from `source_documents.subject`. This yields the
   CURRICULUM SOURCE subject — which for classes 6-10 is honestly `Science`, because that is the book
   NCERT prints. The ACADEMIC DISCIPLINE (physics/chemistry/biology) is a separate, inferred, audited
   dimension and is NOT decided here (see discipline.py). v1 refused integrated books outright on the
   grounds that a filename cannot tell you the discipline. That is true, and it is the wrong conclusion:
   it cost the index every Science concept in classes 6-10. The filename proves the SOURCE; the chapter
   evidence supports the DISCIPLINE; keeping them apart is what makes both safe.

2. TAUGHT-AT comes from being a NUMBERED SECTION of that class's own textbook ("1.2 Properties of
   Rational Numbers" in the Class-8 maths book). That is a materially stronger claim than "this string
   appeared in a PDF filed under Class 8". Everything else is `mentioned_in`.

3. Headings are recovered from TWO INDEPENDENT CHANNELS, because neither alone covers the corpus:
      section_path — the parser's breadcrumb. Strong on the new junior books (Ganita Prakash,
                     Curiosity), and EMPTY on most senior ones.
      text         — line-anchored numbered headings in the chunk body ("4.3  THE LAW OF INERTIA").
                     Strong on classes 11-12, and empty on the new junior books.
   v1 read only `section_path`, which is why the senior corpus was invisible to it: Class-11 Physics
   part 1 yields 0 headings by breadcrumb and 73 by text; Class-12 Maths yields 0 and 53. The index it
   produced held 175 certified Maths concepts of which 150 were classes 6-7 and exactly 1 was class 9+.
   Each concept records which channel proved it (`extraction_basis`).

4. Everything unnumbered is rejected here, deterministically, before a model is asked anything.

Deterministic, stdlib-only, read-only w.r.t. kie.db.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

# NCERT filename code -> curriculum-source subject. `gp` = Ganita Prakash (maths), `mh` = Mathematics,
# `bo`/`ph`/`ch` = single-subject 11/12. `sc`/`cu` = the INTEGRATED Science book (Curiosity / Science):
# admitted as subject 'Science', with the discipline left to evidence-based inference downstream.
_NCERT = re.compile(r"NCERT_Class(\d+)_([a-z]{2})([a-z]{2})(\d)dd", re.I)
_SUBJECT_CODE = {"gp": "Mathematics", "mh": "Mathematics", "bo": "Biology",
                 "ph": "Physics", "ch": "Chemistry", "sc": "Science", "cu": "Science"}
_INTEGRATED = {"sc", "cu"}

# A numbered curriculum heading, 2- or 3-level: "1.2 Properties of Rational Numbers", "2.2.1 How to
# group plants?". The number is the proof that the book itself treats this as a taught section.
_NUMBERED = re.compile(r"^(\d{1,2})\.(\d{1,2})(?:\.(\d{1,2}))?\.?[ \t]+(.{3,90})$")
# The same, line-anchored inside chunk text. Title must START uppercase — body prose continuing after a
# figure number ("5.13(ii), he walks...") does not.
_NUMBERED_TEXT = re.compile(r"^[ \t]*(\d{1,2})\.(\d{1,2})(?:\.(\d{1,2}))?\.?[ \t]+([A-Z][^\n]{2,88})$", re.M)
# Channel C — INLINE headings glued to the body with no line break. Some OCR'd books (the new NEP Class-9
# Science book most of all) join a heading straight onto its first sentence: "2.1 How to Study Cells?What
# do we call...". The line-anchored channel B cannot see these because there is no line to anchor. This
# matches a section number mid-text, and `_clean_title` cuts the glue back to the real title. The negative
# lookbehind `(?<!\d\.)(?<!\d)` stops it matching a SUB-number of a larger number (so "5.11.1" is not read
# as "11.1"). Precision is guarded downstream by _clean_title + _is_heading_like + a Title-Case ratio.
# Lookbehind admits a section number that starts a line (`\n`), follows a sentence (`[.?!]`), or follows a
# lowercase word — the three places a real heading begins. The `\n` case matters: a heading printed on its
# own line but GLUED to a long first sentence ("4.5  NEWTON'S SECOND LAW OF MOTIONThe first law refers...")
# is too long for the whole-line channel B ($ never reached) and was invisible to both channels without it.
_NUMBERED_INLINE = re.compile(
    r"(?:(?<=[.?!])|(?<=[a-z]\s)|(?<=\n)|^)[ \t]*(?<!\d\.)(?<!\d)(\d{1,2})\.(\d{1,2})(?:\.(\d{1,2}))?\.?\s+([A-Za-z][A-Za-z][^\n]{2,85})")
# a heading title may begin with a lowercase technical token ("nth Term of an AP", "pH Scale", "cis-trans
# Isomerism", "sp3 Hybridisation"). Everything else starting lowercase is a numbered prose/calculation run
# ("1.5 mole Ca2+ ion required = ...") and must be rejected. Whitelist keeps precision.
_LOWER_HEAD_OK = re.compile(r"^(nth|n-?th|pH|pOH|cis|trans|ortho|meta|para|sp\d?|[dfps]-|mRNA|tRNA|rRNA|iff|e/m|m/z)\b")
# a caption/figure/example prefix immediately before the number means it is NOT a section heading
_CAPTION_BEFORE = re.compile(
    r"(fig|figure|table|plate|activity|eq|equation|example|chapter|grade|page|no)\.?\s*$", re.I)

# Deterministic junk classes. These never reach the knowledge engineer.
_ACTIVITY = re.compile(
    r"^(try these|think[, ]|figure it out|exercise|activity|do this|let us|worksheet|"
    r"think and discuss|think, discuss|discuss|reprint|summary|what have we discussed|"
    r"ready to go beyond|threads of curiosity|pause and ponder|think it over|what if|"
    r"meet a scientist|keywords|key ?words|points to remember|fun facts?|did you know)", re.I)
_FRONT_BACK = re.compile(
    r"^(contents?|contributors?|reviewers?|preamble|pledge|fundamental duties|national anthem|"
    r"foreword|preface|acknowledg|bibliograph|bibligraph|artwork|chief advisor|advisor|"
    r"a note (for|to) the teacher|supplementary material|physical constants|answers?|"
    r"appendix|index|glossary|syllabus|rationalis)", re.I)
# Page furniture seen in the new books: "10Exploration|Grade 9", "Curiosity|Textbook of Science|Grade 6"
_FURNITURE = re.compile(r"(\|\s*grade\s*\d+|^\d+\s*exploration|^curiosity\b|textbook of science)", re.I)
# Answer apparatus. NCERT numbers exercises in the same 'N.M' space as sections, so these arrive
# indistinguishable from headings by shape and must be named explicitly.
_EXERCISE = re.compile(
    r"^(fill in the blanks?|true or false|multiple choice|tick (the|against)|choose the correct|"
    r"match the (following|columns?)|state whether|answer the following|very short answer|"
    r"short answer|long answer|objective (type )?questions?|assertion and reason)", re.I)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def classify_book(rel_path: str) -> Tuple[Optional[str], Optional[int], str, bool]:
    """-> (curriculum_subject, class, basis, is_integrated). subject=None means DO NOT ADMIT.

    `subject` here is the CURRICULUM SOURCE subject — the book NCERT actually published. It is never
    the academic discipline for an integrated book; that is inferred per-chapter from evidence.
    """
    m = _NCERT.search(rel_path or "")
    if not m:
        return None, None, f"not an NCERT textbook ({(rel_path or '')[:60]!r})", False
    cls, _prefix, code, _vol = int(m.group(1)), m.group(2), m.group(3).lower(), m.group(4)
    subj = _SUBJECT_CODE.get(code)
    if not subj:
        return None, None, f"unrecognised NCERT subject code {code!r}", False
    if code in _INTEGRATED:
        return subj, cls, (
            f"NCERT code {code!r} => the INTEGRATED Science textbook for class {cls}. The curriculum "
            f"source subject is provably 'Science'; the academic discipline of each chapter is NOT "
            f"decided by the filename and is inferred from chapter evidence, then independently audited"
        ), True
    return subj, cls, (f"NCERT filename code {code!r} => {subj}; single-subject book => both the "
                       f"curriculum subject and the academic discipline are provable"), False


# NCERT numbers its EXERCISES the same way it numbers its sections, so "3.2 Pick out the two scalar
# quantities in the following list" arrives looking exactly like a heading. Exercise stems are imperative
# sentences; section titles are noun phrases. The verb is the tell.
_IMPERATIVE = re.compile(
    r"^(fill|pick|state|give|find|calculate|show|explain|prove|compute|determine|choose|answer|"
    r"describe|define|write|draw|estimate|derive|obtain|verify|solve|discuss|list|name|match|"
    r"identify|compare|suggest|justify|evaluate|read|look|observe|complete|consider|assume|"
    # exercise verbs seen in the OCR'd Class-12 Chemistry Part II (numbered in the same N.M space)
    r"arrange|predict|convert|accomplish|deduce|illustrate|distinguish|account for|comment|"
    r"differentiate|mention|how would|how will|how can|out of the|why does|why do|"
    r"a |an |two |three |what |which |why |how much|how many)\b", re.I)
# "2.16 Figure 2", "3.4 Table 1" — captions, not sections.
_CAPTION = re.compile(r"^(fig(ure)?|table|plate|photo|graph|chart|example|eg\b)\.?\s*\d", re.I)
# a title that stops on a function word never finished — OCR clipped it mid-phrase
_DANGLING = re.compile(r"\b(on|of|in|the|and|with|to|for|a|an|by|is|are|from|that|as|at)$", re.I)


def _clean_title(t: str) -> str:
    """Repair OCR damage without destroying the title.

    Two different OCR faults look alike, and v1 treated both as "cut here", which silently truncated real
    headings ('Checking the DimensionalConsistency of Equations' -> 'Checking the Dimensional'):

      heading ran into BODY TEXT  — 'Laws of ExponentsYou know that,102 = 10 x 10'  -> CUT the body off
      two heading WORDS glued     — 'Checking the DimensionalConsistency of Equations' -> SPLIT them

    The tail tells them apart: body text is long and sentence-like; a glued word is short and continues
    the noun phrase.
    """
    t = re.sub(r"[ \t]+", " ", t or "").strip()
    # OCR running-header stutter: a scanned page prints its section header several times and the OCR joins
    # them ("CHEMICAL PROPERTIES3.2 CHEMICAL PROPERTIES3.2 CHEMICAL PROPERTIES..."). Collapse an immediately
    # repeated unit down to one copy so the real title survives.
    t = re.sub(r"(.{4,60}?)\1{1,}", r"\1", t)
    t = re.sub(r"^(\d{1,2}\.\d{1,2}(?:\.\d{1,2})?\s+)", "", t)  # drop a leading section-number left by the collapse
    # a section number embedded mid-title (glued to a letter) is always a stutter/repeat boundary — cut there
    mcut = re.search(r"[A-Za-z]\d{1,2}\.\d{1,2}", t)
    if mcut and mcut.start() > 3:
        t = t[:mcut.start() + 1]
    # ALL-CAPS heading glued to a Title-Case body: "NEWTON'S SECOND LAW OF MOTIONThe first law refers...".
    # The boundary is uppercase->uppercase (MOTION|The), which the lowercase->uppercase cut below cannot see.
    # Cut after the last uppercase of the heading run, before the first Title-Case body word. Only when the
    # head is genuinely an ALL-CAPS heading (senior-book style), so a normal Title-Case heading is untouched.
    mu = re.search(r"[A-Z](?=[A-Z][a-z]{2,})", t)
    if mu and mu.start() > 4 and t[:mu.start() + 1].isupper():
        t = t[:mu.start() + 1]
    m = re.search(r"[a-z](?=[A-Z][a-z]{2,})", t)
    if m and m.start() > 4:
        head, tail = t[:m.start() + 1], t[m.start() + 1:]
        prose = len(tail) > 45 or re.search(r"[,=]|\b(you|we|this|these|it|they|there)\b\s", tail)
        t = head if prose else f"{head} {tail}"
    t = re.split(r"\s*(?:=|\d{2,}|Reprint)", t)[0]
    return t.strip(" .,:;-—\t")


def _is_heading_like(title: str) -> bool:
    """Reject prose that merely began with a number — exercise items, figure refs, TOC runs.

    "5.10 A body is moving unidirectionally under the influence of a source of constant power" and
    "4.1 Give the magnitude and direction of the net force acting on" are EXERCISES; NCERT numbers them
    in the same 'N.M' space as its sections. Headings are short noun phrases, not sentences.
    """
    t = title.strip()
    if len(t) < 3 or len(t.split()) > 12:
        return False
    # a heading names something, so it contains at least one real word. This is what separates a section
    # title from an answer key mis-parsed onto a fake heading ("5.40  3 m6") or a stray formula fragment.
    if not re.search(r"[A-Za-z]{3,}", t):
        return False
    if _CAPTION.match(t) or _EXERCISE.match(t):
        return False
    if re.match(r"^\(?[ivx]+\)", t, re.I):        # "(ii) ..." — an exercise sub-part
        return False
    if t.isupper():                                # "THE LAW OF INERTIA" — senior-book section style
        return True
    words = t.split()
    # imperative/interrogative openings are exercise stems — but only judge multi-word strings, so a real
    # short heading ('Find the Median', 'Comparing Quantities') survives
    if len(words) > 4 and _IMPERATIVE.match(t):
        return False
    if re.search(r"\b(is|are|was|were|has|have|will|can|should|shows?|gives?|means?)\b", t):
        return False
    if _DANGLING.search(t):
        return False
    # NOTE: do NOT also require Title Case. NCERT prints its SUB-headings in sentence case — "4.2.2
    # Determinant of a matrix of order two", "3.3.1 Equality of matrices" — so a capitalised-word ratio
    # test reads them as prose and deletes them. That silently removed the backbone of the class-12
    # determinants chapter. The imperative and finite-verb tests above already exclude exercise stems,
    # which is what the ratio test was reaching for.
    return True


def _reject_class(seg: str) -> Tuple[str, str]:
    if _ACTIVITY.match(seg):
        return "activity_label", "activity/pedagogy box, not an academic concept"
    if _FRONT_BACK.match(seg):
        return "front_matter", "book front/back matter or answer apparatus"
    if _FURNITURE.search(seg):
        return "page_furniture", "running header / page furniture"
    if seg.isupper() and len(seg) > 3:
        return "page_furniture", "running header / all-caps page furniture"
    return "not_a_concept", "unnumbered heading — the book does not treat it as a taught section"


def _valid_chapter(ch_no: int) -> bool:
    """Textbooks number chapters from 1. A '0.x' heading is OCR damage, not a chapter: in the class-7 maths
    book it produced a phantom 'chapter 0' whose only heading was '0.3 T E' (mangled 'TERMS OF AN
    EXPRESSION') and whose evidence was verbatim chapter 10's section 10.3."""
    return ch_no >= 1


def _admit(chapters: dict, ch_no: int, sec: str, title: str, channel: str,
           chunk_id: str = None, page: int = None) -> None:
    """Record one admitted numbered heading under its chapter, tracking which channel proved it.

    FIRST WINS, in book order. A section number is reused later in the chapter by the exercises that
    drill it, so the earliest occurrence is the section itself. Preferring the LONGER string instead
    let 'Fill in the blanks' overwrite the real '1.1 INTRODUCTION'.

    The chunk the heading was found in is kept: it is what makes a concept traceable to the EXACT owned
    evidence it came from (owner rule 7), rather than merely to its chapter.
    """
    e = chapters[ch_no]
    prev = e["topics"].get(sec)
    if prev:
        prev["channels"].add(channel)
        if prev["title"] != title:
            prev["variants"].add(title)
        if prev.get("chunk_id") is None and chunk_id:   # title seen earlier, anchor only now
            prev["chunk_id"], prev["page"] = chunk_id, page
        return
    e["topics"][sec] = {"title": title, "channels": {channel}, "variants": set(),
                        "chunk_id": chunk_id, "page": page}


def admitted_books(kconn: sqlite3.Connection, subject: str) -> List[dict]:
    """Books whose CURRICULUM SOURCE subject is `subject`, with their PROVEN class.

    `subject='Science'` returns the integrated classes 6-10 books.
    """
    out = []
    for r in kconn.execute("SELECT doc_id, rel_path FROM source_documents"):
        subj, cls, basis, integrated = classify_book(r["rel_path"])
        if subj != subject or cls is None:
            continue
        n = kconn.execute("SELECT COUNT(*) FROM chunks WHERE doc_id=?", (r["doc_id"],)).fetchone()[0]
        if not n:
            continue
        code_m = _NCERT.search(r["rel_path"])
        out.append({"doc_id": r["doc_id"], "rel_path": r["rel_path"], "taught_at_class": cls,
                    "subject": subj, "subject_basis": basis, "is_integrated": integrated, "chunks": n,
                    "book_code": (code_m.group(2) + code_m.group(3) + code_m.group(4) + "dd") if code_m else None})
    return sorted(out, key=lambda d: (d["taught_at_class"], d["rel_path"]))


def extract_spine(kconn: sqlite3.Connection, doc_id: str) -> Tuple[Dict[int, dict], List[dict]]:
    """-> ({chapter_no: {topics, raw, chunk_ids, pages}}, [deterministic rejects])

    Reads BOTH channels (section_path breadcrumb and chunk text) over the same ordinal walk. A heading
    is admitted only if it is a numbered curriculum heading that looks like a heading and is not junk.
    """
    chapters: Dict[int, dict] = defaultdict(
        lambda: {"topics": {}, "raw": set(), "chunk_ids": [], "pages": set()})
    rejects: List[dict] = []
    seen_reject = set()

    rows = kconn.execute(
        "SELECT chunk_id, page_start, section_path, text FROM chunks WHERE doc_id=? ORDER BY ordinal",
        (doc_id,)).fetchall()

    current_ch: Optional[int] = None
    for r in rows:
        chunk_ch: Optional[int] = None

        # ── channel A: the parser's section_path breadcrumb ──
        # The breadcrumb is CUMULATIVE: it replays every heading seen so far, so a chunk deep in chapter 6
        # still carries "1.1 ... > 2.1 ... > 6.3 ...". Only the LAST numbered segment is the section this
        # chunk is actually inside; the earlier ones are history. Treating any mentioned segment as the
        # owner made chapter 1 swallow 307 of 315 chunks and left every later chapter with none, and gave
        # 2.1 and 2.2 byte-identical evidence.
        numbered = []
        for seg in [s.strip() for s in (r["section_path"] or "").split(">") if s.strip()]:
            m_ch = re.match(r"^CHAPTER\s*(\d{1,2})$", seg, re.I)
            if m_ch:
                chunk_ch = int(m_ch.group(1))
                continue
            m = _NUMBERED.match(seg)
            if m:
                ch_no = int(m.group(1))
                if not _valid_chapter(ch_no):
                    continue
                sec = f"{m.group(1)}.{m.group(2)}" + (f".{m.group(3)}" if m.group(3) else "")
                title = _clean_title(m.group(4))
                if title and not _ACTIVITY.match(title) and not _FRONT_BACK.match(title) \
                        and not _FURNITURE.search(title) and _is_heading_like(title):
                    numbered.append((ch_no, sec, title, seg))
                continue
            key = seg.lower()[:60]
            if key in seen_reject:
                continue
            seen_reject.add(key)
            cls_, why = _reject_class(seg)
            rejects.append({"raw_label": seg[:200], "reject_class": cls_, "reason": why,
                            "source_ref": json.dumps({"doc_id": doc_id, "chunk_id": r["chunk_id"],
                                                      "channel": "section_path"}),
                            "rejected_by": "deterministic"})

        for i, (ch_no, sec, title, seg) in enumerate(numbered):
            current = i == len(numbered) - 1        # only the deepest/most recent segment owns this chunk
            _admit(chapters, ch_no, sec, title, "section_path",
                   r["chunk_id"] if current else None, r["page_start"] if current else None)
            chapters[ch_no]["raw"].add(seg[:160])
            if current:
                chunk_ch = ch_no

        # ── channel B: line-anchored numbered headings inside the chunk text ──
        for m in _NUMBERED_TEXT.finditer(r["text"] or ""):
            ch_no = int(m.group(1))
            if not _valid_chapter(ch_no):
                continue
            sec = f"{m.group(1)}.{m.group(2)}" + (f".{m.group(3)}" if m.group(3) else "")
            raw = re.sub(r"\s+", " ", m.group(4)).strip()
            title = _clean_title(raw)
            if not title or _ACTIVITY.match(title) or _FRONT_BACK.match(title) or _FURNITURE.search(title):
                continue
            if not _is_heading_like(title):
                key = f"txt:{sec}:{title.lower()[:40]}"
                if key not in seen_reject:
                    seen_reject.add(key)
                    rejects.append({"raw_label": f"{sec} {raw}"[:200], "reject_class": "not_a_concept",
                                    "reason": "numbered line, but reads as prose/exercise text rather than "
                                              "a section heading",
                                    "source_ref": json.dumps({"doc_id": doc_id, "chunk_id": r["chunk_id"],
                                                              "channel": "text"}),
                                    "rejected_by": "deterministic"})
                continue
            chunk_ch = chunk_ch or ch_no
            _admit(chapters, ch_no, sec, title, "text", r["chunk_id"], r["page_start"])
            chapters[ch_no]["raw"].add(f"{sec} {raw}"[:160])

        # ── channel C: INLINE headings glued to the body (OCR joined heading + first sentence) ──
        text = r["text"] or ""
        for m in _NUMBERED_INLINE.finditer(text):
            ch_no, mi, mk = int(m.group(1)), int(m.group(2)), m.group(3)
            if not _valid_chapter(ch_no) or ch_no > 18 or mi > 20 or (mk and int(mk) > 20):
                continue
            if _CAPTION_BEFORE.search(text[max(0, m.start() - 8):m.start()]):
                continue
            sec = f"{ch_no}.{mi}" + (f".{mk}" if mk else "")
            if sec in chapters.get(ch_no, {}).get("topics", {}):
                _admit(chapters, ch_no, sec, chapters[ch_no]["topics"][sec]["title"], "inline",
                       r["chunk_id"], r["page_start"])
                continue
            title = _clean_title(m.group(4))
            if not title or _ACTIVITY.match(title) or _FRONT_BACK.match(title) or _FURNITURE.search(title):
                continue
            # a lowercase-initial title is admitted ONLY if it opens with a known technical token
            # (nth/pH/cis/sp3/...). Everything else lowercase is a numbered prose/calculation run.
            if title[:1].islower() and not _LOWER_HEAD_OK.match(title):
                continue
            if not _is_heading_like(title):
                continue
            words = title.split()
            capped = sum(1 for w in words if w[:1].isupper() or (w[:1].islower() and _LOWER_HEAD_OK.match(w)))
            if len(words) >= 2 and capped / len(words) < 0.45 and not title.rstrip().endswith("?"):
                continue  # not Title-Case enough to be a heading — likely a numbered prose run
            chunk_ch = chunk_ch or ch_no
            _admit(chapters, ch_no, sec, title, "inline", r["chunk_id"], r["page_start"])
            chapters[ch_no]["raw"].add(f"{sec} {title}"[:160])

        if chunk_ch is not None:
            current_ch = chunk_ch
        if current_ch is not None:
            chapters[current_ch]["chunk_ids"].append(r["chunk_id"])
            if r["page_start"]:
                chapters[current_ch]["pages"].add(r["page_start"])

    # a chapter with no admitted numbered topic carries no curriculum evidence
    for ch in list(chapters):
        if not chapters[ch]["topics"]:
            rejects.append({"raw_label": f"CHAPTER{ch}", "reject_class": "unsupported",
                            "reason": "no numbered curriculum heading found under this chapter",
                            "source_ref": json.dumps({"doc_id": doc_id}), "rejected_by": "deterministic"})
            chapters.pop(ch)
    return dict(chapters), rejects


def topic_list(chapter: dict) -> List[str]:
    """The admitted headings of one chapter, in book order: ['1.2 Properties of ...', ...]."""
    def key(s: str):
        return tuple(int(p) for p in s.split("."))
    return [f"{sec} {chapter['topics'][sec]['title']}" for sec in sorted(chapter["topics"], key=key)]


def extraction_basis(chapter: dict) -> str:
    """Which channel(s) proved this chapter's headings — recorded as evidence, per owner rule 7."""
    ch = set()
    for t in chapter["topics"].values():
        ch |= t["channels"]
    return "both" if len(ch) > 1 else (next(iter(ch)) if ch else "none")


def chapter_id(subject: str, cls: int, ch_no: int, doc_id: str = "") -> str:
    """Chapter identity MUST include the book.

    A class can have several parallel books whose chapter numbering overlaps — Class 7 maths ships
    `gegp1dd`, `gegp2dd` and `gemh1dd`, all with a chapter 1. Keying on (subject, class, chapter_no)
    alone silently collapsed 39 ingested chapters into 22 via INSERT OR REPLACE. Include the doc.
    """
    suffix = f"_{doc_id[:6]}" if doc_id else ""
    return f"CH_{subject[:3].upper()}_{cls}_{ch_no:02d}{suffix}"


def concept_id(subject: str, cls: int, name: str) -> str:
    """PERMANENT, stable concept identity (owner rules 2 and 3).

    Hashes the PROVEN dimension only — curriculum subject, class, canonical name. Deliberately NOT the
    academic discipline: re-auditing a Science concept from Physics to Interdisciplinary must not change
    an id that the question bank, DPP and student analytics already reference. Never derived from OCR
    order, filenames, or database row ids.
    """
    h = hashlib.sha256(f"{subject}|{cls}|{name.strip().lower()}".encode()).hexdigest()[:14]
    return f"KC_{h}"


def section_evidence(kconn: sqlite3.Connection, chapter: dict, per_section: int = 2000) -> Dict[str, dict]:
    """Evidence anchored at EACH numbered section — not the first 5KB of the chapter.

    WHY: a chapter's chunks run to tens of thousands of characters, so a flat chapter-level excerpt shows
    the engineer only the opening. On the class-12 maths book that meant sections 4.3-4.5, 5.4-5.7 and
    6.3-6.4 arrived with their heading but NO text, and the engineer could only record the topic name and
    honestly fence everything else off as uncertified — exactly the `boundary` field the index exists to
    provide. It also left every concept in a chapter sharing one undifferentiated chunk list, so a concept
    traced to its CHAPTER rather than to the evidence it actually came from (owner rule 7).

    So: walk from each heading's own chunk and take the text that FOLLOWS it, which is that section's
    treatment. Same total budget, spread where it is needed.
    """
    out: Dict[str, dict] = {}
    for sec, t in chapter["topics"].items():
        anchor = t.get("chunk_id")
        if not anchor:
            continue
        # Walk forward in DOCUMENT order from the anchor. Deliberately not indexed against the chapter's
        # own chunk list: that list depends on chapter attribution being perfect, and when it was not,
        # a missing anchor silently fell back to index 0 and handed every section the chapter's opening.
        # 6 chunks / 2000 chars: at 4/900 the excerpt cut off mid-sentence and lost exactly the payload
        # the record needs — the formal one-one/onto definitions, the principal-value tables, the
        # first/second derivative tests — leaving the engineer able to name a concept but not bound it.
        rows = kconn.execute(
            "SELECT text FROM chunks WHERE doc_id=(SELECT doc_id FROM chunks WHERE chunk_id=?) "
            "AND ordinal >= (SELECT ordinal FROM chunks WHERE chunk_id=?) ORDER BY ordinal LIMIT 6",
            (anchor, anchor)).fetchall()
        text = " ".join(re.sub(r"\s+", " ", (r[0] or "")).strip() for r in rows).strip()
        # start the excerpt at the heading itself where we can find it, so the model reads the section,
        # not the tail of the previous one
        i = text.find(t["title"][:28])
        if i > 0:
            text = text[i:]
        if not text:
            continue
        out[sec] = {"title": t["title"], "text": text[:per_section],
                    "chunk_id": anchor, "page": t.get("page")}
    return out


def evidence_text(kconn: sqlite3.Connection, chunk_ids: List[str], limit_chars: int = 5200) -> str:
    """Compact evidence for one chapter — context around the chapter opening.

    Retained for the chapter-level view (what is this chapter about?). Per-CONCEPT evidence comes from
    `section_evidence`, which is anchored at each heading.
    """
    if not chunk_ids:
        return ""
    q = "SELECT text FROM chunks WHERE chunk_id IN (%s) ORDER BY ordinal" % ",".join("?" * len(chunk_ids))
    parts, total = [], 0
    for r in kconn.execute(q, chunk_ids):
        t = re.sub(r"\s+", " ", r[0] or "").strip()
        if not t:
            continue
        parts.append(t)
        total += len(t)
        if total >= limit_chars:
            break
    return " ".join(parts)[:limit_chars]
