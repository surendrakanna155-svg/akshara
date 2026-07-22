"""Program B — canonical PYQ taxonomy + deterministic normalizers (shared across B1…B5).

One place for the vocabulary the whole program keys on: canonical exams, exam families, canonical subjects,
and the token/spelling normalizers. Kept pure + side-effect-free so every stage (and every test / adversarial
verifier) resolves identically. NOTHING here reads a store or a folder; callers pass raw strings in.

Standing laws honored: honest-null (a normalizer returns None on no confident match — never a guess);
fail-closed (an ambiguous or unqualified token — e.g. bare "JEE" with no main/advanced qualifier — resolves to
None, never to a default). The FOLDER-TRUST defect (D5) is prevented UPSTREAM by the classifier, but the
allow-lists here are the second line: a dump-folder token like "cursor_downloads" is simply not an exam token.
"""
from __future__ import annotations

import re
from typing import Optional

# ── Canonical exams (matches examdna v1 values for the three planned exams; lineage exams kept distinct) ──
#   examdna.db exam_weight.exam uses: JEE_MAIN | JEE_ADVANCED | NEET.  AIPMT / AIIMS are historical NEET-lineage
#   exams — recorded PRECISELY here (never silently collapsed into NEET); B5 applies the OD-1 lineage rule.
CANONICAL_EXAMS = ("NEET", "JEE_MAIN", "JEE_ADVANCED", "AIPMT", "AIIMS")
EXAM_FAMILY = {"NEET": "NEET", "AIPMT": "NEET", "AIIMS": "NEET", "JEE_MAIN": "JEE", "JEE_ADVANCED": "JEE"}
PLANNED_DNA_EXAMS = ("NEET", "JEE_MAIN", "JEE_ADVANCED")   # the three examdna targets

# ── Canonical subjects (title-cased to match examdna v1 subject values) ──
CANONICAL_SUBJECTS = ("Physics", "Chemistry", "Mathematics", "Biology")


def canonical_exam(token: str) -> Optional[str]:
    """Normalize a single raw token/segment to a canonical exam, or None (honest-null).

    Requires the main/advanced QUALIFIER for JEE — a bare "jee" is ambiguous → None (fail-closed).
    Recognizes the official-archive spellings seen in the corpus (e.g. "jeeadv", "jee_advanced").
    """
    if not token:
        return None
    t = re.sub(r"[^a-z0-9]+", " ", token.lower()).strip()
    if not t:
        return None
    # order matters: advanced before main (so "jee advanced" is not shadowed by a "jee main" test)
    if re.search(r"\bjee\s*adv", t) or "jeeadv" in t.replace(" ", ""):
        return "JEE_ADVANCED"
    if re.search(r"\bjee\s*main", t) or "jeemain" in t.replace(" ", ""):
        return "JEE_MAIN"
    if re.search(r"\baipmt\b", t):
        return "AIPMT"
    if re.search(r"\baiims\b", t):
        return "AIIMS"
    if re.search(r"\bneet\b", t):
        return "NEET"
    return None


# content-signal phrases → exam (used to CORROBORATE a path/category token, never alone unless unambiguous).
_CONTENT_EXAM_PATTERNS = (
    (re.compile(r"national eligibility.{0,20}entrance", re.I), "NEET"),
    (re.compile(r"\bneet\b", re.I), "NEET"),
    (re.compile(r"joint entrance examination.{0,10}advanced", re.I), "JEE_ADVANCED"),
    (re.compile(r"jee\s*\(?\s*advanced", re.I), "JEE_ADVANCED"),
    (re.compile(r"joint entrance examination.{0,10}main", re.I), "JEE_MAIN"),
    (re.compile(r"jee\s*\(?\s*main", re.I), "JEE_MAIN"),
    (re.compile(r"all india pre.?medical", re.I), "AIPMT"),
)


def content_exam_signals(text: str) -> set:
    """Set of canonical exams named in a block of paper text (may be empty). Deterministic."""
    hits = set()
    if not text:
        return hits
    for pat, exam in _CONTENT_EXAM_PATTERNS:
        if pat.search(text):
            hits.add(exam)
    return hits


_SUBJECT_MAP = (
    (re.compile(r"\b(maths?|mathematics)\b", re.I), "Mathematics"),
    (re.compile(r"\bphysics\b", re.I), "Physics"),
    (re.compile(r"\bchemistry\b", re.I), "Chemistry"),
    (re.compile(r"\b(biology|botany|zoology)\b", re.I), "Biology"),
)


def canonical_subject(token: str) -> Optional[str]:
    """Normalize a raw subject token/section-header to a canonical subject, or None (honest-null)."""
    if not token:
        return None
    for pat, subj in _SUBJECT_MAP:
        if pat.search(token):
            return subj
    return None


def subject_signals(text: str) -> set:
    """Canonical subjects named in a block of text (may be empty). Used for multi-subject section detection."""
    hits = set()
    if not text:
        return hits
    for pat, subj in _SUBJECT_MAP:
        if pat.search(text):
            hits.add(subj)
    return hits


# 1990–2029 realistic PYQ range. Digit-boundary lookarounds (NOT \b) so an underscore-delimited year like
# "JEE_Advanced_2010_Paper1" parses — \b treats '_' as a word char and would miss it — while a longer number
# (e.g. "20100") never yields a spurious year.
_YEAR_RE = re.compile(r"(?<!\d)(19[9]\d|20[0-2]\d)(?!\d)")


def parse_year(*tokens: str) -> Optional[int]:
    """First plausible 4-digit exam year found across the tokens, else None (honest-null).

    On MULTIPLE distinct years in one token blob it returns None (ambiguous → honest-null), so a filename that
    smears two years never silently picks one.
    """
    found = set()
    for tok in tokens:
        if not tok:
            continue
        for m in _YEAR_RE.findall(tok):
            found.add(int(m))
    if len(found) == 1:
        return next(iter(found))
    return None   # 0 found (unresolved) OR >1 (ambiguous) → honest-null
