"""Concept quality sanitizer — the deterministic linchpin for boundary safety.

The certified KIE concept layer is noisy (OCR garbage, textbook boilerplate, section-heading
fragments). Generating from arbitrary concepts would emit junk and risk out-of-syllabus items.
This module deterministically rejects unusable concept titles so only real, teachable concepts
reach a paper. It pairs with an EVIDENCE requirement in scope.py (a concept must also appear in
Question Intelligence / be a named law / have a definition).
"""
from __future__ import annotations

import re
from typing import Optional

# textbook / paper boilerplate that is never a real concept
_BOILERPLATE = {
    "summary", "preface", "contents", "content", "index", "chapter", "unit", "exercise",
    "exercises", "answer", "answers", "solution", "solutions", "appendix", "glossary",
    "introduction", "acknowledgement", "acknowledgements", "figure", "fig", "table", "example",
    "activity", "activities", "note", "notes", "recap", "revision", "reference", "references",
    "objective", "objectives", "keywords", "let us explore", "let us investigate", "let us do",
    "pause and ponder", "a step further", "threads of curiosity", "probe and ponder",
    "be a scientist", "happy investigating", "our scientific heritage", "bridging science and society",
    "questions", "test yourself", "did you know", "points to remember", "summary and review",
    "examples", "solved examples", "try these", "think about it", "case study",
}
# whole-word tokens that mark a sentence fragment, not a concept name
_SENTENCE_WORDS = {
    "while", "they", "we", "it", "its", "this", "that", "these", "those", "can", "cannot",
    "do", "does", "did", "not", "is", "are", "was", "were", "has", "have", "had", "when",
    "which", "who", "whom", "whose", "if", "then", "than", "because", "however", "therefore",
    "one", "you", "your", "their", "them", "none", "been", "being", "will", "would", "should",
    "could", "may", "might", "he", "she", "but", "so", "also", "here", "there", "let",
}
_MID_ARTICLES = {"The", "A", "An", "This", "These"}
MAX_WORDS = 5
# generic section words that are not a teachable concept when they stand ALONE
# (multi-word titles that merely contain them — "Properties of Gases" — are fine)
_GENERIC_ALONE = {
    "applications", "application", "characteristics", "characteristic", "functions", "function",
    "properties", "property", "types", "type", "uses", "importance", "introduction", "overview",
    "general", "basics", "methods", "method", "process", "processes", "features", "feature",
    "terminology", "definition", "definitions", "structure", "classification", "components",
}
_BOILERPLATE_PREFIX = ("activity ", "chapter ", "unit ", "exercise ", "fig", "figure ",
                       "table ", "example ", "section ", "part ", "q.", "question ")

_ALPHA = re.compile(r"[A-Za-z]")
_VOWEL = re.compile(r"[AEIOUaeiou]")           # y excluded on purpose (semivowel)
_WORD = re.compile(r"[A-Za-z][A-Za-z'\-]*")
_ACTIVITY_NUM = re.compile(r"\b\d+\.\d+\b")            # "10.1" style section numbering
_INTERNAL_CASE = re.compile(r"[a-z][A-Z]")            # doJmZo / wBOTANY style OCR noise
# y excluded (real words: rhythm, synthesis); threshold 6 leaves 'strength' etc. alone
_CONSONANT_RUN = re.compile(r"[bcdfghjklmnpqrstvwxzBCDFGHJKLMNPQRSTVWXZ]{6,}")

MIN_LEN, MAX_LEN = 3, 60


def _looks_like_ocr_garbage(title: str) -> bool:
    """Reliable, dictionary-free noise signals only. (Pronounceable-but-invalid tokens are
    left to the evidence filter — a garbage concept rarely has patterns/definitions/laws.)"""
    words = _WORD.findall(title)
    if not words:
        return True
    if _CONSONANT_RUN.search(title):
        return True
    for w in words:
        if _INTERNAL_CASE.search(w):                    # lower→upper inside a token
            return True
        if len(w) >= 4 and not _VOWEL.search(w):        # a real 4+ letter word has a vowel
            return True
        if len(w) >= 5:                                 # anagram scrambles repeat one letter
            wl = w.lower()
            top = max(wl.count(c) for c in set(wl))
            if top / len(wl) >= 0.45:                    # e.g. GAJAHA → 'a' = 3/6
                return True
    return False


def is_clean_concept(title: Optional[str]) -> bool:
    """True if `title` is a usable concept name (deterministic, conservative)."""
    if not title:
        return False
    t = title.strip()
    low = t.lower()
    if not (MIN_LEN <= len(t) <= MAX_LEN):
        return False
    if not _ALPHA.search(t):
        return False
    if low in _BOILERPLATE:
        return False
    if any(low.startswith(p) for p in _BOILERPLATE_PREFIX):
        return False
    if any(b in low for b in ("let us ", "pause and ponder", "step further", "threads of curiosity",
                              "probe and ponder", "be a scientist", "scientific heritage",
                              "bridging science")):
        return False
    if _ACTIVITY_NUM.search(t):                          # "Activity 10.1", "3.2 ..." fragments
        return False
    # must be mostly letters (reject "wBOTANY"-style and number-heavy fragments)
    alpha = sum(c.isalpha() for c in t)
    if alpha < 0.6 * len(t):
        return False
    if _looks_like_ocr_garbage(t):
        return False
    words = _WORD.findall(t)
    # at least one real word of length >= 3
    if not any(len(w) >= 3 for w in words):
        return False
    # sentence-fragment guards (phase-5 sometimes captures a clause, not a concept name)
    if len(words) > MAX_WORDS:
        return False
    lw = [w.lower() for w in words]
    if any(w in _SENTENCE_WORDS for w in lw):
        return False
    # a capitalized article/determiner in a non-initial position ⇒ concatenated clauses
    if any(w in _MID_ARTICLES for w in words[1:]):
        return False
    # a single generic section word alone ("Applications", "Characteristics") is not a concept
    if len(words) == 1 and low in _GENERIC_ALONE:
        return False
    return True
