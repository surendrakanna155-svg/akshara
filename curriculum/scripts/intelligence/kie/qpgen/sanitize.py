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

# multiword boilerplate phrases (substring match, apostrophe/space-normalized) — document
# scaffolding that is never a teachable concept even though no single token is boilerplate.
_BOILERPLATE_CONTAINS = (
    "answer sheet", "answer key", "marking scheme", "model paper", "sample paper",
    "question bank", "miscellaneous example", "solved example", "worked example",
    "note to the", "to the teacher", "think, discuss", "discuss and write",
    "time allowed", "general instruction",
)
# discourse/adverb openers that begin an explanatory sentence, never a concept name
_LEAD_DISCOURSE = {
    "obviously", "clearly", "basically", "essentially", "actually", "hence", "therefore",
    "however", "moreover", "furthermore", "thereby", "thus", "note", "notes",
}
# a title ending in a bare connective/article is a truncated heading ("Complex Numbers and")
_TRAILING_STOP = {
    "and", "or", "of", "to", "in", "for", "with", "the", "a", "an", "from", "by", "on", "at",
}
# a title ending in a section-scaffold noun ("Miscellaneous Examples", "Solved Exercises")
_TRAILING_NOISE = {"examples", "example", "exercises", "exercise"}
# a finite verb INTERIOR to a title means an extracted sentence, not a noun-phrase concept
# ("B-Elimination reaction Follows Zaitsev rule"). Closed, high-precision set.
_INTERIOR_VERBS = {
    "follows", "shows", "gives", "uses", "contains", "makes", "causes", "requires", "depends",
    "occurs", "consists", "represents", "describes", "explains", "means", "refers", "states",
    "denotes", "involves", "implies", "yields", "produces", "becomes", "remains",
}
# short science acronyms (>=4 letters) that must survive ALL-CAPS title-casing
_SCIENCE_ACRONYMS = {"IUPAC", "NADPH", "NADH", "LASER", "SONAR", "NCERT"}
# connective/article tokens lowercased when they appear INTERIOR to a title during normalization
# (this/these/those/that are deliberately excluded so _MID_ARTICLES still flags concatenation)
_CONNECTIVES_LOWER = {
    "of", "and", "or", "to", "in", "for", "with", "from", "by", "as", "on", "at", "the", "a", "an",
}

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
    "into", "onto", "upon",   # clause prepositions — mark a sentence fragment, not a concept
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
_DOUBLED_CAP = re.compile(r"\b([A-Z])\1(?=[a-z])")   # FFirst / DDalton — OCR duplicated leading cap
_MERGED_POSSESSIVE = re.compile(r"('s)([A-Za-z]{3,})")  # Newton'sthird — possessive glued to next word
_GLUED_HEADING = re.compile(r"([A-Z]{2,})([A-Z][a-z])")  # MOTIONThe — caps-run glued to a word
_ONLY_LETTERS = re.compile(r"[^A-Za-z]")
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


def _titlecase_caps_word(w: str) -> str:
    """Title-case an ALL-CAPS heading word (OSCILLATIONS → Oscillations); keep short tokens and
    known science acronyms (DNA, IUPAC) untouched. Deterministic."""
    core = _ONLY_LETTERS.sub("", w)
    if len(core) >= 4 and w.isupper() and core not in _SCIENCE_ACRONYMS:
        return w.capitalize()
    return w


def normalize_concept_title(title: Optional[str]) -> str:
    """Deterministically repair common OCR/extraction artifacts in a concept title WITHOUT
    inventing content, so a real concept is cleaned (not discarded) before it reaches a stem.

    Repairs (all conservative, reversible-in-spirit): a caps-run glued to a following word
    ('MOTIONThe' → 'MOTION The'), a doubled leading capital ('FFirst' → 'First'), a merged
    possessive ('Newton''sthird' → 'Newton''s third'), ALL-CAPS heading words title-cased
    ('ACIDS' → 'Acids'), interior connectives lowercased ('AND' → 'and'), and collapsed
    whitespace + stripped edge punctuation. Genuine fragments are left for is_clean_concept to
    reject; this only makes real concepts presentable."""
    if not title:
        return ""
    t = title.strip().replace("’", "'").replace("‘", "'")   # unify curly → straight apostrophe
    t = _GLUED_HEADING.sub(r"\1 \2", t)          # MOTIONThe → MOTION The
    t = _DOUBLED_CAP.sub(r"\1", t)               # FFirst → First
    t = _MERGED_POSSESSIVE.sub(r"\1 \2", t)      # Newton'sthird → Newton's third
    words = [_titlecase_caps_word(w) for w in t.split()]
    for i in range(1, len(words)):               # lowercase INTERIOR connectives/articles
        stripped = _ONLY_LETTERS.sub("", words[i]).lower()
        if stripped in _CONNECTIVES_LOWER and words[i][:1].isupper():
            words[i] = words[i].lower()
    t = " ".join(words)
    t = re.sub(r"\s{2,}", " ", t).strip()
    return t.strip(" .,:;-–—’‘\"")     # strip only EDGE stray punctuation


_STEM_ARTIFACTS = (
    _MERGED_POSSESSIVE,                            # 'sthird residue
    re.compile(r"\b([A-Z])\1[a-z]"),              # FFirst-style doubled leading cap
    _GLUED_HEADING,                               # MOTIONThe-style glued caps-run
    re.compile(r"\s{2,}"),                        # collapsed double space
    re.compile(r"[.,;:]{2,}"),                    # doubled punctuation ("..")
    re.compile(r"\s[.,;:]"),                      # space before punctuation (" .")
)


def stem_quality_ok(stem: Optional[str]) -> bool:
    """Render-time gate: True if a materialized stem is free of the OCR/extraction artifacts the
    normalizer targets. Deterministic + conservative — it flags only the clear artifact
    signatures (so pH/mRNA/units/maths in a legitimate stem are never rejected)."""
    s = (stem or "").strip().replace("’", "'").replace("‘", "'")
    if len(s) < 8:
        return False
    return not any(rx.search(s) for rx in _STEM_ARTIFACTS)


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
    # multiword scaffolding phrases ("answer sheet", "note to the teacher")
    if any(p in low for p in _BOILERPLATE_CONTAINS):
        return False
    # a discourse/adverb opener begins an explanatory sentence, not a concept name
    if lw[0] in _LEAD_DISCOURSE:
        return False
    # a bare trailing connective/article ("... and") or scaffold noun ("... Examples") = fragment
    if lw[-1] in _TRAILING_STOP or lw[-1] in _TRAILING_NOISE:
        return False
    # a finite verb interior to the title ⇒ an extracted sentence, not a concept
    if any(w in _INTERIOR_VERBS for w in lw[1:]):
        return False
    # residual OCR artifacts (defense in depth if the title was not normalized upstream)
    if _MERGED_POSSESSIVE.search(t) or any(re.match(r"^([A-Z])\1[a-z]", w) for w in words):
        return False
    return True
