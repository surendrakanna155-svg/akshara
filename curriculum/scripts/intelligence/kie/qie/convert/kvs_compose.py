"""Generate FRESH, verified questions from the governed KVS knowledge (Phase-6 → engine).

Closes the loop: the governed conversion admitted verified, concept-bound structured facts into the KVS
(structure_function / sequence / comparison / assertion). This module exposes ONLY those verified facts to the
SAME unified compositional engine (compose.py / compositions.py) — new stems authored from the fact (never the
source-question wording), distractors kept in-category and proven ≠ the answer, and every item re-verified by
deterministic re-derivation against the KVS fact (the locked Tier-1 check). It registers templates into the
shared TEMPLATE_REGISTRY, so the qp_bridge picks them up with zero bespoke wiring.

Data is loaded READ-ONLY from qie.db at import; if the KVS is empty the templates simply produce nothing.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from typing import Dict, List, Optional, Tuple

from kie.qie import store as QS
from kie.qie import compose as C
from kie.qie.compose import Operator
from kie.qie.compositions import CompositionTemplate, _si, register

STR = "KVS"


def _norm(s: str) -> str:
    import re as _re
    return _re.sub(r"[^a-z0-9 ]", "", (s or "").lower()).strip()


_ARTICLE = __import__("re").compile(r"\b(?:a|an|the)\b")


def _corresponds(answer: str, term: str) -> bool:
    """Does `answer` name the same thing as `term`?

    Articles are noise here: the examiner writes the object_term as prose ("the sodium salt of a carboxylic
    acid") while the source's option is bare ("sodium salt of carboxylic acid"). The substring test is done
    article-blind so identical content matches.

    The first-word test is deliberately NOT article-blind. It is a loose heuristic, and widening it produces
    false matches: "Sol A is negatively charged and sol B is positively charged" would match the subject term
    "A sol coagulated more effectively by a divalent cation" on the shared first word "sol" alone, and author
    an incoherent item. Missing a fact is cheaper than authoring a wrong one.
    """
    a, t = _norm(answer), _norm(term)
    if not a or not t:
        return False
    ab = _ARTICLE.sub(" ", a).split()
    tb = _ARTICLE.sub(" ", t).split()
    if not ab or not tb:
        return False
    a_bare, t_bare = " ".join(ab), " ".join(tb)
    return a_bare in t_bare or t_bare in a_bare or a.split()[0] == t.split()[0]


# An option is printed VERBATIM to a student. The source's real distractors are authentic misconception
# evidence, but they are OCR text — so a string can be damaged even when the fact behind it is sound
# ("_!_ increases linearly with t", "C decreases with ķ I", "the momentum of `S`"). Damaged strings are
# dropped; if a fact then has too few clean distractors it is skipped — an honest shortfall, never junk in
# a paper. Conservative + dictionary-free, matching the qpgen sanitizer's own philosophy: this catches the
# clear artifact signatures, and a pronounceable typo ("tmpredictable") is left for the evidence filter.
_OPT_NOISE = __import__("re").compile(
    r"[`_~\\{}<>|]"          # stray OCR marks — never present in a real option
    r"|!"                     # a bare '!' inside an option is OCR noise
    r"|[Ā-ɏ]"      # Latin-Extended (ķ, Ï …) — OCR confusion, never real English science
    # A run of 3+ lowercase letters glued to a capital is a lost space ("Zr andY have..."). The 3+ bound is
    # what keeps real chemistry safe: NaOH, MgCl2, CoA, mRNA, tRNA and pH all carry at most TWO lowercase
    # letters before a capital, so none of them match.
    r"|[a-z]{3,}[A-Z]"
    r"|'[a-z]+[A-Z]"          # an apostrophe swallowed mid-token ("a ketone RESPO'iSE")
)
# A sanity bound, not a quality proxy. Real NEET options genuinely run long ("A major advantage is that the
# offspring are protected from predators and there is a great chance of their survival upto adulthood." = 129
# chars), so a tight cap would reject truth for being verbose. Length is bounded only to catch runaway OCR;
# whether an option is JUNK is decided by the artifact detectors below. (Entity-vs-prose is a separate
# question and stays where it belongs: on the ANSWER in the per-direction gates.)
MAX_OPTION_LEN = 130
_ARTIFACT_MIN_LEN = 8          # sanitize.stem_quality_ok requires >= 8 chars, so short options skip it

# ── lost-space / mangled-word detection the regex above cannot see ──────────────────────────────────────
# The _OPT_NOISE regex catches a lost space at a CASE boundary ("andY"), but not a lost space between two
# lowercase words ("greaterthan", "dicotstem") or a word with a garbled short affix ("tmpredictable" =
# "tm"+"predictable"). These slip verbatim into a student's paper. Detection is measured false-positive-free
# on the NEET pool: it never fires on a dictionary word or a simple inflection of one (absorbs, molecules,
# reptiles, isocitrate, eutrophication all survive) — only on a clear concatenation or a mangled affix.
try:
    _DICT = frozenset(w.strip().lower() for w in open("/usr/share/dict/words") if w.strip().isalpha())
except OSError:                                     # graceful degradation if the OS wordlist is absent
    _DICT = frozenset()
_VOWELS = frozenset("aeiouy")
_INFLECT = (("s", ""), ("es", ""), ("ies", "y"), ("ing", ""), ("ing", "e"), ("ed", ""), ("ed", "e"),
            ("d", ""), ("ly", ""), ("ation", "ate"), ("tion", "te"), ("ted", "t"))


def _base_in_dict(w: str) -> bool:
    """True if w, or a simple morphological base of it, is a dictionary word (so inflections stay clean)."""
    if w in _DICT:
        return True
    return any(w.endswith(suf) and len(w) - len(suf) + len(repl) >= 3 and (w[:len(w) - len(suf)] + repl) in _DICT
               for suf, repl in _INFLECT)


def _garbled_word(w: str, siblings: frozenset = frozenset()) -> bool:
    """True if a lowercase token looks like an OCR artifact. Conservative: never fires on a dictionary word or
    a simple inflection; only on (1) two glued dictionary words, (2) two glued SIBLING-option words, or (3) a
    valid word with a short vowel-free garbled affix."""
    if len(w) < 8 or not w.isalpha() or _base_in_dict(w):
        return False
    for i in range(4, len(w) - 3):                  # (1) "greater"+"than"
        if w[:i] in _DICT and w[i:] in _DICT:
            return True
    for i in range(3, len(w) - 2):                  # (2) "dicot"+"stem" (both appear as separate sibling words)
        if w[:i] in siblings and w[i:] in siblings:
            return True
    for k in (2, 3):                                # (3) "tm"+"predictable": vowel-free affix on a real word
        if len(w) > k + 5:
            if not (set(w[:k]) & _VOWELS) and _base_in_dict(w[k:]):
                return True
            if not (set(w[-k:]) & _VOWELS) and _base_in_dict(w[:-k]):
                return True
    return False


def _sibling_words(options) -> frozenset:
    """Lowercase words (len >= 3) appearing across an item's option strings — the vocabulary a lost-space
    concatenation is reassembled from."""
    return frozenset(t for o in options for t in re.findall(r"[a-z]+", (o or "").lower()) if len(t) >= 3)


def _option_clean(s: str, siblings: frozenset = frozenset()) -> bool:
    """True if an option string is fit to print VERBATIM to a student."""
    from kie.qpgen import sanitize
    t = (s or "").strip()
    if not t or len(t) > MAX_OPTION_LEN:
        return False
    if not any(c.isalpha() for c in t):
        return False
    if _OPT_NOISE.search(t):
        return False
    if any(_garbled_word(tok, siblings) for tok in re.findall(r"[a-z]+", t.lower())):
        return False                                # lost-space / mangled OCR word (greaterthan, dicotstem, …)
    # `stem_quality_ok` — NOT `_looks_like_ocr_garbage`. An option is PROSE, like a stem; the garbage detector
    # is the CONCEPT-TITLE gate and its internal-case rule ([a-z][A-Z]) rejects real biochemistry — Acetyl CoA,
    # mRNA, tRNA, NaOH, pH. sanitize says so itself: stem_quality_ok exists "so pH/mRNA/units/maths in a
    # legitimate stem are never rejected". It also catches the prose damage a word-level check cannot
    # ("... one real and two . . c 1magmary roots" -> space before punctuation).
    return len(t) < _ARTIFACT_MIN_LEN or sanitize.stem_quality_ok(t)


def _clean_distractors(distractors: List[str], answer: str) -> List[str]:
    """Real distractors, minus the answer, minus OCR-damaged strings, de-duplicated (order preserved)."""
    out: List[str] = []
    seen = set()
    a = _norm(answer)
    sib = _sibling_words([answer] + list(distractors or []))
    for d in distractors or []:
        n = _norm(d)
        if not n or n == a or n in seen or not _option_clean(d, sib):
            continue
        seen.add(n)
        out.append(d)
    return out


def _assert_usable(answer: str, subject_term: str, predicate: str, object_term: str,
                   distractors: List[str]) -> bool:
    """Quality gate for authoring an assertion item that reuses the source's REAL distractors.

    Usable only when the source asked "what is X?" (so answer_text is the entity named by subject_term and the
    real distractors are parallel alternatives) AND the item will be a clean, non-giveaway question:
      * answer must be a clean short entity — matching-pair / list answers ("Aschelminthes : Ancylostoma, ...")
        are rejected (they produce incoherent stems);
      * no GIVEAWAY — no significant answer word may already appear in the authored stem;
      * >= 3 distinct real distractors, none equal to the answer.
    """
    a, st = _norm(answer), _norm(subject_term)
    if not a or not st:
        return False
    if ":" in (answer or "") or " - " in (answer or "") or len(answer) > 60:
        return False                                   # matching-pair / list-style option, not an entity
    if not _option_clean(answer, _sibling_words(distractors)):
        return False        # the ANSWER is an option too: it prints verbatim, so it must be clean as well
        # (regression: an OCR-damaged answer — "real depth of  pond", double space — shipped because only the
        #  distractors were being quality-gated; also a lost-space answer like "KP is greaterthan Kc")
    if not _corresponds(answer, subject_term):
        return False                                   # answer does not correspond to the subject term
    stem_words = set(_norm(f"{predicate} {object_term}").split())
    if any(w for w in a.split() if len(w) > 3 and w in stem_words):
        return False                                   # giveaway: answer word appears in the stem
    # Count CLEAN distractors, exactly as `_load` does. Counting raw ones would pass a fact whose damaged
    # strings are then dropped, leaving <3 options — the gate would say yes and the item would silently
    # never appear.
    return len(_clean_distractors(distractors, answer)) >= 3


def _assert_object_usable(answer: str, subject_term: str, predicate: str, object_term: str,
                          distractors: List[str]) -> bool:
    """Quality gate for the OBJECT direction — the direction most real source questions actually use.

    `_assert_usable` above serves "what is X?", where the answer names the subject_term. But the majority of
    admitted facts were asked the other way — "given X, what is its Y?" — so the answer corresponds to the
    OBJECT_TERM and the real distractors are parallel to the object, not the subject. Inverting such a fact
    into a subject-direction stem is what left those facts unusable: the stored distractors were not parallel
    to the authored question. Here the stem is authored in the SOURCE's own direction
    ("{subject_term} {predicate}:"), so the real distractors line up exactly.

    Usable only when the item will be clean and non-giveaway:
      * answer must be a clean short entity (no matching-pair/list options, no OCR-damaged string);
      * answer must correspond to the object_term (not the subject_term — that is the other template);
      * no GIVEAWAY — no significant answer word may already appear in the authored stem, which here is the
        subject_term + predicate (so a stem restating its own answer is rejected);
      * >= 3 distinct, clean, real distractors, none equal to the answer.
    """
    a, ot, st = _norm(answer), _norm(object_term), _norm(subject_term)
    if not a or not ot or not st:
        return False
    # No 60-char entity cap here: unlike "what is X?" (whose answer NAMES an entity), the object direction's
    # answer is legitimately a descriptive phrase ("Analogous organs that have evolved due to convergent
    # evolution." = 61 chars). Matching-pair/list markers are still refused — those make an incoherent stem.
    if ":" in (answer or "") or " - " in (answer or "") or not _option_clean(answer, _sibling_words(distractors)):
        return False
    if not _corresponds(answer, object_term):
        return False                                   # answer does not correspond to the object term
    stem_words = set(_norm(f"{subject_term} {predicate}").split())
    if any(w for w in a.split() if len(w) > 3 and w in stem_words):
        return False                                   # giveaway: answer word already in the stem
    return len(_clean_distractors(distractors, answer)) >= 3


def _load(qconn: sqlite3.Connection) -> dict:
    """Load verified governed facts, grouped by generatable shape, with their structured slots + concept."""
    qconn.row_factory = sqlite3.Row
    sf: List[dict] = []
    seq: List[dict] = []
    asrt: List[dict] = []
    asrt_obj: List[dict] = []
    from kie.qie.convert import topics as TP
    for r in qconn.execute("SELECT subject,exam,concept_candidate,topic,lane,structured,answer_text,"
                           "distractors FROM governed_fact WHERE status='verified'"):
        try:
            s = json.loads(r["structured"] or "{}")
        except Exception:
            s = {}
        # owner decision B: bind at the fact's certified TOPIC ("Biology :: Uricotelism"), falling back to its
        # chapter when no topic was certified. qpgen dedups by (concept, question_type) GLOBALLY per paper, so
        # chapter binding collapsed every fact of a chapter into ONE question.
        base = {"subject": r["subject"], "exam": r["exam"], "concept": TP.concept_key(dict(r))}
        if r["lane"] == "STRUCTURE_FUNCTION" and s.get("structure") and s.get("function"):
            sf.append({**base, "structure": s["structure"], "function": s["function"],
                       "location": s.get("location"), "system": s.get("system")})
            continue
        if r["lane"] == "PROCESS_SEQUENCE" and isinstance(s.get("ordered_steps"), list) \
                and len(s["ordered_steps"]) >= 3:
            seq.append({**base, "process": s.get("process") or r["concept_candidate"],
                        "steps": [str(x) for x in s["ordered_steps"]]})
            continue
        # assertion shape: author a fresh stem and reuse the source's REAL distractors (authentic
        # misconception evidence — learned, never cloned wording).
        if s.get("subject_term") and s.get("object_term"):
            try:
                dis = json.loads(r["distractors"] or "[]")
            except Exception:
                dis = []
            pred = s.get("predicate") or "is"
            if _assert_usable(r["answer_text"], s["subject_term"], pred, s["object_term"], dis):
                asrt.append({**base, "answer": r["answer_text"], "predicate": pred,
                             "object_term": s["object_term"],
                             "distractors": _clean_distractors(dis, r["answer_text"])[:3]})
            elif _assert_object_usable(r["answer_text"], s["subject_term"], pred, s["object_term"], dis):
                # the SOURCE's own direction: "given X, what is its Y?" — the real distractors are parallel
                # to the object, so the fact is usable as-asked without inverting it
                asrt_obj.append({**base, "answer": r["answer_text"], "predicate": pred,
                                 "subject_term": s["subject_term"],
                                 "distractors": _clean_distractors(dis, r["answer_text"])[:3]})
    return {"sf": sf, "seq": seq, "assert": asrt, "assert_obj": asrt_obj}


# ── load once at import (read-only) ──────────────────────────────────────────────────────────────────────
try:
    _conn = sqlite3.connect(f"file:{QS.QIE_DB_PATH}?mode=ro", uri=True)
    _DATA = _load(_conn)
    _conn.close()
except Exception:
    _DATA = {"sf": [], "seq": [], "assert": [], "assert_obj": []}
_DATA.setdefault("assert", [])
_DATA.setdefault("assert_obj", [])

# structure -> function map (per subject, for the same-subject distractor pool)
_SF_FUNC: Dict[str, str] = {f["structure"]: f["function"] for f in _DATA["sf"]}
_SF_BY_SUBJECT: Dict[str, List[dict]] = {}
for _f in _DATA["sf"]:
    _SF_BY_SUBJECT.setdefault(_f["subject"], []).append(_f)


def _reg_op(name, apply, verify, n_in):
    C.OPERATORS[name] = Operator(name, "KVS_KB", "kvs", (STR,) * n_in, STR, apply, verify)


# lookup operators (Tier-1 deterministic verify re-checks the KVS map)
_reg_op("kvs_function_of", lambda st: _SF_FUNC.get(st),
        lambda ins, out: out is not None and _SF_FUNC.get(ins[0]) == out, 1)
_reg_op("kvs_next_in", lambda proc_steps, step: (
    proc_steps[proc_steps.index(step) + 1]
    if step in proc_steps and proc_steps.index(step) + 1 < len(proc_steps) else None),
        lambda ins, out: ins[1] in ins[0] and ins[0].index(ins[1]) + 1 < len(ins[0])
        and ins[0][ins[0].index(ins[1]) + 1] == out, 2)

# verified-assertion lookup: fact key -> the verified answer entity (Tier-1 re-derivation against the KVS)
_ASSERT_ANS: Dict[str, str] = {}
for _a in _DATA["assert"]:
    _ASSERT_ANS[f"{_a['concept']}|{_a['object_term']}"] = _a["answer"]
_reg_op("kvs_assert_of", lambda k: _ASSERT_ANS.get(k),
        lambda ins, out: out is not None and _ASSERT_ANS.get(ins[0]) == out, 1)

# object-direction lookup: keyed by the SUBJECT term (the thing the stem gives), answering the object
_ASSERT_OBJ_ANS: Dict[str, str] = {}
for _a in _DATA["assert_obj"]:
    _ASSERT_OBJ_ANS[f"{_a['concept']}|{_a['subject_term']}"] = _a["answer"]
_reg_op("kvs_assert_obj_of", lambda k: _ASSERT_OBJ_ANS.get(k),
        lambda ins, out: out is not None and _ASSERT_OBJ_ANS.get(ins[0]) == out, 1)


def _slug(concept: str) -> str:
    import re
    return re.sub(r"[^a-z0-9]+", "_", concept.lower()).strip("_")


# Templates are keyed per SOURCE CHAPTER (concept_candidate) so each generated item carries its own in-scope
# chapter for honest qp_bridge binding. Distractors are still drawn from the SAME-SUBJECT verified pool
# (real, in-category, proven != the answer) so a single-fact chapter still yields 4 clean options.
def _sf_template(concept: str, facts: List[dict], subject: str) -> Optional[CompositionTemplate]:
    pool = _SF_BY_SUBJECT.get(subject, [])
    all_funcs = [f["function"] for f in pool]
    if len(set(all_funcs)) < 4:           # need >=4 distinct functions subject-wide for 4 options
        return None

    def setup(seed):
        f = facts[_si(seed + "s", 0, len(facts) - 1)]
        return {"structure": f["structure"]}, f

    def distractors(env, p):
        # P1.1 CONCEPT-AWARE distractors: a good wrong option is the function of a DIFFERENT structure the
        # student might confuse with this one — i.e. from the SAME body system, else the same chapter/concept —
        # not an unrelated function from across the whole subject ("anchor AV valves" for a pollen grain). We
        # order the pool by relatedness (same system → same concept → subject-wide) and let the composition
        # engine take the first distinct ones; the subject-wide tail only fills a gap when a system/chapter has
        # too few functions, so it never STARVES an item, but related options are always preferred.
        ans = p["function"]

        def funcs(pred):
            return [f["function"] for f in pool if f["function"] != ans and pred(f)]

        sys_ = p.get("system")
        # the subject-wide fallback tail is VARIED per structure so a thin-data item does not reuse the same
        # two functions on every question (the "germ cells + AV valves on everything" repetition) — each
        # structure hashes the fallback pool into its own order, giving diverse options across the paper.
        salt = str(p.get("structure"))
        wide = sorted(funcs(lambda f: True),
                      key=lambda fn: hashlib.sha256((salt + "|" + fn).encode()).hexdigest())
        tiers = [funcs(lambda f: sys_ and f.get("system") == sys_),      # same body system (closest)
                 funcs(lambda f: f.get("concept") == p.get("concept")),  # same chapter/concept
                 wide]                                                   # varied subject-wide fallback (last)
        out, seen = [], set()
        for tier in tiers:
            for fn in tier:
                if fn not in seen:
                    seen.add(fn)
                    out.append(fn)
        return out

    return CompositionTemplate(
        f"kvs_sf_{_slug(concept)}", concept, setup,
        [C.Step("ans", "kvs_function_of", ("structure",))], "ans",
        lambda env, p: _SF_FUNC.get(p["structure"]) == env["ans"],       # independent re-derivation
        lambda env, p: f"What is the principal function of {p['structure']}?",
        distractors,
        subject=subject, gen_prefix="GENKVS_", fmt=str)


def _seq_next_template(concept: str, facts: List[dict], subject: str) -> Optional[CompositionTemplate]:
    def setup(seed):
        f = facts[_si(seed + "p", 0, len(facts) - 1)]
        i = _si(seed + "i", 0, len(f["steps"]) - 2)                      # never the last step
        return {"proc": tuple(f["steps"]), "step": f["steps"][i]}, {"process": f["process"],
                                                                     "steps": f["steps"], "step": f["steps"][i]}

    return CompositionTemplate(
        f"kvs_seq_{_slug(concept)}", concept, setup,
        [C.Step("ans", "kvs_next_in", ("proc", "step"))], "ans",
        lambda env, p: p["steps"][p["steps"].index(p["step"]) + 1] == env["ans"],
        lambda env, p: (f"In the correct order of '{p['process']}', what comes immediately after "
                        f"'{p['step']}'?"),
        lambda env, p: [s for s in p["steps"] if s != p["step"] and s != env["ans"]],
        subject=subject, gen_prefix="GENKVS_", fmt=str)


def _assert_template(concept: str, facts: List[dict], subject: str) -> Optional[CompositionTemplate]:
    """Author a FRESH stem from the verified assertion and reuse the source's REAL wrong options as
    distractors (authentic exam misconception evidence — never the source wording)."""
    def setup(seed):
        f = facts[_si(seed + "a", 0, len(facts) - 1)]
        return {"key": f"{f['concept']}|{f['object_term']}"}, f

    return CompositionTemplate(
        f"kvs_fact_{_slug(concept)}", concept, setup,
        [C.Step("ans", "kvs_assert_of", ("key",))], "ans",
        lambda env, p: _ASSERT_ANS.get(f"{p['concept']}|{p['object_term']}") == env["ans"],
        lambda env, p: f"Which of the following {p['predicate']} {p['object_term']}?",
        lambda env, p: list(p["distractors"]),
        subject=subject, gen_prefix="GENKVS_", fmt=str)


def _assert_object_template(concept: str, facts: List[dict], subject: str) -> Optional[CompositionTemplate]:
    """Author the stem in the SOURCE's own direction — "{subject_term} {predicate}:" — so the fact's REAL
    distractors (parallel to the object) line up with the question actually asked."""
    def setup(seed):
        f = facts[_si(seed + "ao", 0, len(facts) - 1)]
        return {"key": f"{f['concept']}|{f['subject_term']}"}, f

    def stem(env, p):
        s = f"{p['subject_term']} {p['predicate']}".strip()
        return s.rstrip(":.") + ":"

    return CompositionTemplate(
        f"kvs_factobj_{_slug(concept)}", concept, setup,
        [C.Step("ans", "kvs_assert_obj_of", ("key",))], "ans",
        lambda env, p: _ASSERT_OBJ_ANS.get(f"{p['concept']}|{p['subject_term']}") == env["ans"],
        stem, lambda env, p: list(p["distractors"]),
        subject=subject, gen_prefix="GENKVS_", fmt=str)


def _group(facts: List[dict]) -> Dict[str, List[dict]]:
    g: Dict[str, List[dict]] = {}
    for f in facts:
        g.setdefault(f["concept"], []).append(f)
    return g


_TEMPLATES: Dict[str, CompositionTemplate] = {}
for _concept, _facts in _group(_DATA["sf"]).items():
    _t = _sf_template(_concept, _facts, _facts[0]["subject"])
    if _t is not None:
        _TEMPLATES[_t.name] = _t
for _concept, _facts in _group(_DATA["seq"]).items():
    _t = _seq_next_template(_concept, _facts, _facts[0]["subject"])
    if _t is not None:
        _TEMPLATES[_t.name] = _t
for _concept, _facts in _group(_DATA["assert"]).items():
    _t = _assert_template(_concept, _facts, _facts[0]["subject"])
    if _t is not None:
        _TEMPLATES[_t.name] = _t
for _concept, _facts in _group(_DATA["assert_obj"]).items():
    _t = _assert_object_template(_concept, _facts, _facts[0]["subject"])
    if _t is not None:
        _TEMPLATES[_t.name] = _t
register(_TEMPLATES)


def summary() -> dict:
    from collections import Counter
    return {"sf_facts": len(_DATA["sf"]), "seq_facts": len(_DATA["seq"]),
            "n_templates": len(_TEMPLATES),
            "templates_by_subject": dict(Counter(t.subject for t in _TEMPLATES.values())),
            "chapters": sorted({t.concept_code for t in _TEMPLATES.values()})}
