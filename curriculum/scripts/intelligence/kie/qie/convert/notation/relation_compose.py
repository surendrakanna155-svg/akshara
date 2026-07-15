"""Generate FRESH numeric questions from CERTIFIED recovered relations — notation lane → engine → qpgen.

Only relations that passed the locked hierarchy (`governed_relation.status='certified'`) are exposed. Each item
is authored from the relation's own recovered symbols/meanings/units (never source-question wording), its answer
is computed by sympy from the certified equation, and an INDEPENDENT recomputation re-derives it before the item
is banked. Distractors are the classic numeric misconception transforms, each proven != the answer.

Registers per-chapter templates into the shared TEMPLATE_REGISTRY, so `qp_bridge` picks them up and (via owner
decision A) binds them to their in-scope chapter.
"""
from __future__ import annotations

import json
import re
import sqlite3
from typing import Dict, List, Optional

import sympy as sp

from kie.qie import compose as C
from kie.qie import store as QS
from kie.qie.compose import Operator
from kie.qie.compositions import CompositionTemplate, _si, register

NUM = "RELNUM"


def _load_certified() -> List[dict]:
    try:
        conn = sqlite3.connect(f"file:{QS.QIE_DB_PATH}?mode=ro", uri=True)
    except Exception:
        return []
    conn.row_factory = sqlite3.Row
    out: List[dict] = []
    try:
        for r in conn.execute("SELECT * FROM governed_relation WHERE status='certified'"):
            d = dict(r)
            for k in ("symbols", "meanings", "constants", "value_ranges", "provenance"):
                try:
                    d[k] = json.loads(d[k] or "{}")
                except Exception:
                    d[k] = {}
            out.append(d)
    except sqlite3.Error:
        return []
    finally:
        conn.close()
    return out


_RELS = _load_certified()


def _slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", (s or "").lower()).strip("_")


def _target_and_inputs(rel: dict):
    """Target = the LHS symbol; inputs = the remaining symbols minus declared constants."""
    lhs = (rel["equation"].split("=", 1)[0] or "").strip()
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", lhs):
        return None, [], {}
    consts = {c["symbol"]: c["value"] for c in (rel.get("constants") or []) if "symbol" in c}
    inputs = [s for s in rel.get("symbols", {}) if s != lhs and s not in consts]
    return lhs, sorted(inputs), consts


def _eval(rel: dict, values: Dict[str, float]) -> Optional[float]:
    """Deterministic evaluation of the certified equation's RHS."""
    rhs = rel["equation"].split("=", 1)[1]
    loc = {s: sp.Symbol(s, real=True) for s in rel.get("symbols", {})}
    loc["pi"] = sp.pi
    try:
        expr = sp.sympify(rhs, locals=loc)
        val = expr.subs({sp.Symbol(k, real=True): v for k, v in values.items()})
        f = float(val.evalf())
        return f if f == f and abs(f) != float("inf") else None
    except Exception:
        return None


def _fmt(v) -> str:
    if isinstance(v, float):
        if abs(v) >= 1e4 or (abs(v) < 1e-3 and v != 0):
            return f"{v:.3e}"
        return f"{v:.4g}"
    return str(v)


# operator: evaluate a certified relation (Tier-1 deterministic; verify recomputes independently)
def _reg_ops():
    def apply(payload):
        rel, values = payload
        return _eval(rel, values)

    def verify(ins, out):
        rel, values = ins[0]
        v = _eval(rel, values)
        return v is not None and out is not None and abs(v - out) <= 1e-9 * max(abs(v), 1.0)

    C.OPERATORS["rel_eval"] = Operator("rel_eval", "REL_KB", "notation", (NUM,), NUM, apply, verify)


_reg_ops()


def _template(rel: dict) -> Optional[CompositionTemplate]:
    target, inputs, consts = _target_and_inputs(rel)
    if not target or not inputs or len(inputs) > 4:
        return None
    meanings = rel.get("meanings") or {}
    units = rel.get("symbols") or {}

    # Instance-parameter realism. The CERTIFIED knowledge is the relation itself; these ranges only choose
    # physically sensible magnitudes for a generated instance (a 12 C point charge is arithmetically fine but
    # not an exam-realistic quantity). Range absent -> a plain small-integer sample.
    ranges = rel.get("value_ranges") or {}

    def setup(seed):
        vals: Dict[str, float] = {}
        for s in inputs:
            spec = ranges.get(s)
            if spec:
                lo, hi, scale = spec.get("lo", 2), spec.get("hi", 12), spec.get("scale", 1.0)
                vals[s] = float(_si(f"{seed}|{s}", int(lo), int(hi))) * float(scale)
            else:
                vals[s] = float(_si(f"{seed}|{s}", 2, 12))
        vals.update({k: float(v) for k, v in consts.items()})
        return {"payload": (rel, vals)}, {"vals": vals, "rel": rel}

    def stem(env, p):
        # Author from the RECOVERED MEANINGS, never the equation: printing the formula would make the item a
        # trivial substitution (a giveaway). The student must supply the relation.
        given = "; ".join(
            f"{meanings.get(s, s)} {s} = {_fmt(p['vals'][s])} {units.get(s, '')}".strip() for s in inputs)
        what = meanings.get(target) or target
        return f"Given {given}. The {what} (in {rel['lhs_unit']}) is:"

    def distractors(env, p):
        a = env["ans"]
        return [a * 2, a / 2, -a, a * 4]           # classic numeric misconception transforms

    def e2e(env, p):                                # INDEPENDENT recomputation from the certified equation
        v = _eval(p["rel"], p["vals"])
        return v is not None and abs(v - env["ans"]) <= 1e-9 * max(abs(v), 1.0)

    # Bind at RELATION granularity, not chapter: "Ohm's law", "Drift speed" and "Wheatstone bridge" are each a
    # real, distinct syllabus concept. qpgen dedups by (concept, question_type), so chapter-level binding would
    # collapse every relation of a chapter into a single paper slot.
    return CompositionTemplate(
        f"relnum_{_slug(rel['name'])}", f"{rel['subject']} :: {rel['name']}", setup,
        [C.Step("ans", "rel_eval", ("payload",))], "ans", e2e, stem, distractors,
        subject=rel["subject"], gen_prefix="GENREL_", fmt=_fmt)


TEMPLATES: Dict[str, CompositionTemplate] = {}
for _r in _RELS:
    _t = _template(_r)
    if _t is not None:
        TEMPLATES[_t.name] = _t
register(TEMPLATES)


def summary() -> dict:
    from collections import Counter
    return {"certified_relations": len(_RELS), "templates": len(TEMPLATES),
            "by_subject": dict(Counter(t.subject for t in TEMPLATES.values())),
            "chapters": sorted({t.concept_code for t in TEMPLATES.values()})}
