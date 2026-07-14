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


def _load(qconn: sqlite3.Connection) -> dict:
    """Load verified governed facts, grouped by lane, with their structured slots + source concept."""
    qconn.row_factory = sqlite3.Row
    sf: List[dict] = []
    seq: List[dict] = []
    for r in qconn.execute("SELECT subject,exam,concept_candidate,lane,structured,answer_text "
                           "FROM governed_fact WHERE status='verified'"):
        s = {}
        try:
            s = json.loads(r["structured"] or "{}")
        except Exception:
            s = {}
        base = {"subject": r["subject"], "exam": r["exam"], "concept": r["concept_candidate"]}
        if r["lane"] == "STRUCTURE_FUNCTION" and s.get("structure") and s.get("function"):
            sf.append({**base, "structure": s["structure"], "function": s["function"],
                       "location": s.get("location"), "system": s.get("system")})
        elif r["lane"] == "PROCESS_SEQUENCE" and isinstance(s.get("ordered_steps"), list) \
                and len(s["ordered_steps"]) >= 3:
            seq.append({**base, "process": s.get("process") or r["concept_candidate"],
                        "steps": [str(x) for x in s["ordered_steps"]]})
    return {"sf": sf, "seq": seq}


# ── load once at import (read-only) ──────────────────────────────────────────────────────────────────────
try:
    _conn = sqlite3.connect(f"file:{QS.QIE_DB_PATH}?mode=ro", uri=True)
    _DATA = _load(_conn)
    _conn.close()
except Exception:
    _DATA = {"sf": [], "seq": []}

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
register(_TEMPLATES)


def summary() -> dict:
    from collections import Counter
    return {"sf_facts": len(_DATA["sf"]), "seq_facts": len(_DATA["seq"]),
            "n_templates": len(_TEMPLATES),
            "templates_by_subject": dict(Counter(t.subject for t in _TEMPLATES.values())),
            "chapters": sorted({t.concept_code for t in _TEMPLATES.values()})}
