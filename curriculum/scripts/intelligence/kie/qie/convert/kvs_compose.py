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

import json
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
)
MAX_OPTION_LEN = 60


def _option_clean(s: str) -> bool:
    """True if an option string is fit to print to a student."""
    from kie.qpgen import sanitize
    t = (s or "").strip()
    if not t or len(t) > MAX_OPTION_LEN:
        return False
    if not any(c.isalpha() for c in t):
        return False
    if _OPT_NOISE.search(t):
        return False
    return not sanitize._looks_like_ocr_garbage(t)


def _clean_distractors(distractors: List[str], answer: str) -> List[str]:
    """Real distractors, minus the answer, minus OCR-damaged strings, de-duplicated (order preserved)."""
    out: List[str] = []
    seen = set()
    a = _norm(answer)
    for d in distractors or []:
        n = _norm(d)
        if not n or n == a or n in seen or not _option_clean(d):
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
    if not (a in st or st in a or a.split()[0] == st.split()[0]):
        return False                                   # answer does not correspond to the subject term
    stem_words = set(_norm(f"{predicate} {object_term}").split())
    if any(w for w in a.split() if len(w) > 3 and w in stem_words):
        return False                                   # giveaway: answer word appears in the stem
    clean = [d for d in distractors if d and _norm(d) != a]
    if len({_norm(d) for d in clean}) < 3:
        return False
    return True


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
    if ":" in (answer or "") or " - " in (answer or "") or not _option_clean(answer):
        return False
    if not (a in ot or ot in a or a.split()[0] == ot.split()[0]):
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
    for r in qconn.execute("SELECT subject,exam,concept_candidate,lane,structured,answer_text,distractors "
                           "FROM governed_fact WHERE status='verified'"):
        try:
            s = json.loads(r["structured"] or "{}")
        except Exception:
            s = {}
        base = {"subject": r["subject"], "exam": r["exam"], "concept": r["concept_candidate"]}
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
    if len(all_funcs) < 4:                # need >=4 distinct functions subject-wide for 4 options
        return None

    def setup(seed):
        f = facts[_si(seed + "s", 0, len(facts) - 1)]
        return {"structure": f["structure"]}, f

    return CompositionTemplate(
        f"kvs_sf_{_slug(concept)}", concept, setup,
        [C.Step("ans", "kvs_function_of", ("structure",))], "ans",
        lambda env, p: _SF_FUNC.get(p["structure"]) == env["ans"],       # independent re-derivation
        lambda env, p: f"What is the principal function of {p['structure']}?",
        lambda env, p: [fn for fn in all_funcs if fn != p["function"]],
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
        lambda env, p: (f"In the correct order for '{p['process']}', which immediately follows "
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
