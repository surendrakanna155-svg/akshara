"""Deterministic OCR quality metric — a pure function `score(text) -> float in [0,1]`.

WHY a metric at all: OCR failure is not random noise; it has a signature — symbol soup (`~|{}` runs),
fragmented single letters (`a b c d`), glued-together nonsense, and — critically for this bilingual
corpus — ROMANIZED GARBAGE (a Devanagari page OCR'd under `-l eng` yields alpha-looking non-words like
"forgtea aigated sravaa"). A robust score must catch ALL of these, so it combines four orthogonal terms.
It is a PURE function: no network, no clock, no randomness, no external dict file — fully reproducible, so
the same text always yields the same score (the keep/reject gate downstream depends on that determinism).

The four terms (each in 0..1, higher = cleaner), and why each is necessary:

  1. alpha_ratio  — (letters + digits + spaces + sane punctuation) / len(text). Catches symbol-soup OCR
     (`§¥~|`). NECESSARY but NOT SUFFICIENT: romanized garbage is ~all letters and passes this term.

  2. word_hit_ratio  — fraction of alpha tokens that are real words. This is the term that catches romanized
     garbage. A token scores 1.0 if it is in a built-in common-English + STEM/exam wordlist, a small 0.25 if it
     is merely PRONOUNCEABLE (vowel present, no long consonant run, no triple repeats — a defensible dict-free
     English-shape heuristic, kept small because romanized transliteration is ALSO pronounceable-shaped), else
     0.0. Pure digits are legitimate in exam papers (q-numbers, marks) and score 1.0. Real prose is dominated by
     1.0 dictionary hits; romanized garbage — which has almost no true dictionary words — is dominated by 0.25s
     and 0.0s, so its word term collapses even though its alpha_ratio is a perfect 1.0.

  3. token_len_sanity  — mean alpha-token length. English averages ~4-5; OCR fragmentation drives it toward 1
     ("a b c"), and glued garbage drives it up ("thequickbrownfox…"). A plateau on [3,9] with linear falloff.

  4. clean_run  — 1 minus a garbage-run penalty: the fraction of characters inside a run of >=3 consecutive
     symbols, PLUS the fraction of tokens that are isolated single letters other than a/i (fragmentation).

score = 0.25*alpha + 0.40*word + 0.15*token_len + 0.20*clean_run, clamped to [0,1]. The word term carries
the most weight because it is the one that separates real language from alpha-looking garbage. Empty/near-empty
text scores 0.0 (honest — there is no content to judge as good).
"""
from __future__ import annotations

import re
from typing import Dict

# ── built-in wordlist: high-frequency English function/common words + STEM/exam domain terms ────────────────
# Deliberately compact (no external dependency): enough to give the word-hit term real discriminative power on
# this corpus (physics/chem/bio/math exam papers) without pretending to be a full dictionary. Tokens NOT in
# here can still earn partial credit via the pronounceability heuristic, so the list need not be exhaustive.
_COMMON = """
the of and a to in is was he for it with as his on be at by i this had not are but from or have an they
which one you were her all she there would their we him been has when who will more no if out so said what
its about into than them can only other new some could time these two may then do first any my now such like
our over man me even most made after also did many before must through back years where much your way well
down should because each just those people how too little state good very make world still see own men work
long here between both life being under never day same another know while last might us great old year off
come since against go came right used take three states himself few house use during without again place
american around however home small found thought went say part once general high upon school every don does
got united left number course war until always away something fact water though less public put think almost
hand enough far took head yet government system better set told nothing night end why called didnt eyes find
going look asked later knew point next city
question questions answer answers option options correct incorrect solution solutions section paper marks mark
exam test previous year national testing agency booklet code candidate physics chemistry biology botany zoology
mathematics maths math figure diagram given following equation value values reaction energy force velocity mass
acceleration momentum electric magnetic field current charge resistance voltage circuit atom atomic molecule
molecular electron proton neutron nucleus bond acid base salt cell dna rna protein enzyme organism species
plant animal blood heart function tissue vector matrix function derivative integral angle triangle circle radius
theorem proof ratio probability speed distance temperature pressure volume density number units total sum
increases decreases constant maximum minimum respectively hence therefore assertion reason statement true false
""".split()
_WORDS = frozenset(_COMMON)

_VOWELS = set("aeiouy")
_TOKEN_RE = re.compile(r"[A-Za-z]+|[0-9]+(?:\.[0-9]+)?")
_ALPHA_TOKEN_RE = re.compile(r"[A-Za-z]{1,}")
# "sane" characters: letters, digits, whitespace, and the punctuation that legitimately appears in exam prose.
_SANE_PUNCT = set(" .,:;!?()[]{}-+=/%°'\"$&@#*\n\t")
_SYMBOL_RE = re.compile(r"[^0-9A-Za-z\s]")


def _clamp01(x: float) -> float:
    return 0.0 if x < 0.0 else (1.0 if x > 1.0 else x)


def _alpha_ratio(text: str) -> float:
    """Fraction of characters that are letters/digits/whitespace/sane-punct. Symbol soup drives this down."""
    good = sum(1 for ch in text if ch.isalnum() or ch in _SANE_PUNCT)
    return good / len(text)


def _is_pronounceable(tok: str) -> bool:
    """Dict-free 'looks like an English word' heuristic: at least one vowel, no run of >=4 consonants, no
    triple-repeated character, and a not-absurd vowel fraction. Rejects the shape of romanized OCR garbage
    ("frae", "saRada" → mixed case handled by lowering) while accepting genuine words absent from the wordlist."""
    t = tok.lower()
    if len(t) < 2:
        return False
    if not any(c in _VOWELS for c in t):
        return False
    if re.search(r"(.)\1\1", t):  # triple repeat (e.g. "aaa", "wwww") — OCR artifact
        return False
    run = 0
    for c in t:
        if c in _VOWELS:
            run = 0
        else:
            run += 1
            if run >= 4:  # 4+ consonants in a row is un-English
                return False
    vowels = sum(1 for c in t if c in _VOWELS)
    frac = vowels / len(t)
    return 0.15 <= frac <= 0.80


def _word_hit_ratio(text: str) -> float:
    """Mean per-token credit: 1.0 dictionary/pure-number, 0.5 pronounceable, 0.0 garbage. The term that
    separates real language from alpha-looking (romanized) garbage that alpha_ratio cannot catch."""
    toks = _TOKEN_RE.findall(text)
    if not toks:
        return 0.0
    credit = 0.0
    for t in toks:
        if t[0].isdigit():          # pure number — legitimate in exam docs (q-numbers, marks, values)
            credit += 1.0
        elif t.lower() in _WORDS:
            credit += 1.0
        elif _is_pronounceable(t):
            credit += 0.25
    return credit / len(toks)


def _token_len_sanity(text: str) -> float:
    """Mean alpha-token length; plateau on [3,9], linear falloff outside. Catches fragmentation (mean→1) and
    glued garbage (mean→large)."""
    lens = [len(t) for t in _ALPHA_TOKEN_RE.findall(text)]
    if not lens:
        return 0.0
    m = sum(lens) / len(lens)
    if 3.0 <= m <= 9.0:
        return 1.0
    if m < 3.0:
        return _clamp01((m - 1.0) / 2.0)      # m=1 → 0, m=3 → 1
    return _clamp01((15.0 - m) / 6.0)         # m=9 → 1, m=15 → 0


def _clean_run(text: str) -> float:
    """1 - garbage penalty. Penalty = share of chars inside a run of >=3 consecutive symbols (soup) PLUS share
    of tokens that are isolated single letters other than 'a'/'i' (fragmentation like 'w a fae art')."""
    n = len(text)
    soup = 0
    for m in re.finditer(r"[^0-9A-Za-z\s]{3,}", text):
        soup += m.end() - m.start()
    soup_frac = soup / n

    toks = _ALPHA_TOKEN_RE.findall(text)
    frag_frac = 0.0
    if toks:
        singles = sum(1 for t in toks if len(t) == 1 and t.lower() not in ("a", "i"))
        frag_frac = singles / len(toks)
    return _clamp01(1.0 - (soup_frac + 0.5 * frag_frac))


# Weights (sum = 1.0). word_hit carries the most weight — it is the one term that catches romanized garbage,
# which alpha_ratio (term 1) demonstrably cannot. Documented in the module header.
_W_ALPHA, _W_WORD, _W_TOKLEN, _W_CLEAN = 0.25, 0.40, 0.15, 0.20


def components(text: str) -> Dict[str, float]:
    """Return the individual terms — for auditability of any score (why a page scored what it did)."""
    if not text or not text.strip():
        return {"alpha_ratio": 0.0, "word_hit_ratio": 0.0, "token_len_sanity": 0.0, "clean_run": 0.0}
    return {
        "alpha_ratio": _alpha_ratio(text),
        "word_hit_ratio": _word_hit_ratio(text),
        "token_len_sanity": _token_len_sanity(text),
        "clean_run": _clean_run(text),
    }


def score(text: str) -> float:
    """Deterministic OCR-quality score in [0,1]. Empty/near-empty text → 0.0 (honest: no content to judge good).
    Pure function of `text` only — same input always yields the same output."""
    if not text or not text.strip():
        return 0.0
    c = components(text)
    s = (_W_ALPHA * c["alpha_ratio"] + _W_WORD * c["word_hit_ratio"]
         + _W_TOKLEN * c["token_len_sanity"] + _W_CLEAN * c["clean_run"])
    return round(_clamp01(s), 6)
