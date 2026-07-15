"""Generate FRESH depth-4/5 items from CERTIFIED chains — the HARD lane into qpgen.

Parallel to `relation_compose` (which serves the MEDIUM lane at depth 1). Only chains whose WIRING passed
`chains.certify` are compiled, so no item can be built on a dimensionally-incompatible junction.

Each chain compiles to a pipeline of one step per link, so `compose.reasoning_depth` measures the real
dependency chain and `qp_bridge._difficulty` reads depth>=4 as HARD — the depth is earned by the DAG, never
asserted. Every step is independently verified (equation-satisfaction, not the solve path it came from) and an
independent end-to-end check re-tests EVERY link's original equation against the final env before an item banks.

Stems state the givens and ask for the target. They never print a formula or name the route — the student must
supply the chain (the same no-giveaway rule `relation_compose` follows).
"""
from __future__ import annotations

import re
import sqlite3
from typing import Dict, List, Optional

import sympy as sp

from kie.qie import compose as C
from kie.qie import store as QS
from kie.qie.compose import Operator
from kie.qie.compositions import CompositionTemplate, _si, register
from kie.qie.convert.notation import chains as CH

NUM = "RELNUM"
CFG = "CHAINCFG"
CHAIN_SETS = ("depth4_chains",)
MAX_FEEDS = 3


def _fmt(v) -> str:
    if isinstance(v, float):
        if abs(v) >= 1e4 or (abs(v) < 1e-3 and v != 0):
            return f"{v:.3e}"
        return f"{v:.4g}"
    return str(v)


def _slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", (s or "").lower()).strip("_")


def _subs(expr, values: Dict[str, float]):
    return expr.subs({sp.Symbol(k, real=True): v for k, v in values.items()})


def _residual_ok(rel: dict, values: Dict[str, float]) -> bool:
    """INDEPENDENT check: the ORIGINAL equation must be satisfied by these values. This is a different route
    from the algebraic solve that produced them, so it genuinely cross-checks the step."""
    loc = {s: sp.Symbol(s, real=True) for s in (rel.get("symbols") or {})}
    loc["pi"] = sp.pi
    try:
        lhs, rhs = rel["equation"].split("=", 1)
        resid = _subs(sp.sympify(lhs, locals=loc) - sp.sympify(rhs, locals=loc), values)
        r = float(sp.N(resid))
    except Exception:
        return False
    scale = max(abs(float(sp.N(_subs(sp.sympify(rhs, locals=loc), values)))), 1.0)
    return r == r and abs(r) <= 1e-6 * scale


def _apply(cfg: dict, *feeds) -> Optional[float]:
    values = dict(cfg["values"])
    values.update(dict(zip(cfg["feed_syms"], feeds)))
    try:
        v = float(sp.N(_subs(cfg["expr"], values)))
    except Exception:
        return None
    return v if v == v and abs(v) != float("inf") else None


def _verify(ins, out) -> bool:
    cfg, feeds = ins[0], ins[1:]
    if out is None:
        return False
    values = dict(cfg["values"])
    values.update(dict(zip(cfg["feed_syms"], feeds)))
    values[cfg["target"]] = out
    return _residual_ok(cfg["rel"], values)


def _reg_ops():
    for k in range(MAX_FEEDS + 1):
        C.OPERATORS[f"chain_step{k}"] = Operator(
            f"chain_step{k}", "CHAIN_KB", "notation", (CFG,) + (NUM,) * k, NUM, _apply, _verify)


_reg_ops()


def _load_certified_chains() -> List[CH.Chain]:
    try:
        conn = sqlite3.connect(f"file:{QS.QIE_DB_PATH}?mode=ro", uri=True)
    except Exception:
        return []
    try:
        by = CH.certified_relations(conn)
    except sqlite3.Error:
        return []
    finally:
        conn.close()
    out: List[CH.Chain] = []
    for s in CHAIN_SETS:
        try:
            for ch in CH.load(s):
                v = CH.certify(ch, by)
                if v["status"] == "certified":
                    ch._rels = {st.relation: by[st.relation] for st in ch.steps}   # type: ignore[attr-defined]
                    out.append(ch)
        except FileNotFoundError:
            continue
    return out


def _template(chain: CH.Chain) -> Optional[CompositionTemplate]:
    rels: Dict[str, dict] = chain._rels                       # type: ignore[attr-defined]
    exprs = {st.out: CH.solve_step(rels[st.relation], st.solve_for) for st in chain.steps}
    if any(e is None for e in exprs.values()):
        return None

    consts: Dict[str, float] = {}
    meanings: Dict[str, str] = {}
    units: Dict[str, str] = {}
    for st in chain.steps:
        rel = rels[st.relation]
        for c in rel.get("constants") or []:
            if "symbol" in c:
                consts[c["symbol"]] = float(c["value"])
        for s, m in (rel.get("meanings") or {}).items():
            meanings.setdefault(s, m)
        for s, u in (rel.get("symbols") or {}).items():
            units.setdefault(s, u)
    meanings.update(chain.meaning_overrides)      # a symbol's ROLE can differ once composed (units unchanged)

    given_syms = sorted(chain.givens)
    last = chain.steps[-1]
    target_sym, target_unit = last.solve_for, units.get(last.solve_for, "")

    def setup(seed):
        vals: Dict[str, float] = {}
        for s in given_syms:
            spec = chain.givens[s]
            vals[s] = float(_si(f"{seed}|{s}", int(spec.get("lo", 2)), int(spec.get("hi", 9)))) \
                * float(spec.get("scale", 1.0))
        env0: Dict[str, object] = {}
        for i, st in enumerate(chain.steps):
            rel = rels[st.relation]
            syms = set(rel.get("symbols") or {})
            step_vals = {k: v for k, v in vals.items() if k in syms}
            step_vals.update({k: v for k, v in consts.items() if k in syms})
            env0[f"c{i}"] = {"expr": exprs[st.out], "rel": rel, "target": st.solve_for,
                             "values": step_vals, "feed_syms": list(st.feeds)}
        return env0, {"vals": vals, "chain": chain, "rels": rels}

    pipeline = [C.Step(st.out, f"chain_step{len(st.feeds)}",
                       (f"c{i}",) + tuple(st.feeds.values()))
                for i, st in enumerate(chain.steps)]

    def stem(env, p):
        given = "; ".join(f"{meanings.get(s, s)} {s} = {_fmt(p['vals'][s])} {units.get(s, '')}".strip()
                          for s in given_syms)
        what = meanings.get(target_sym, target_sym)
        lead = (chain.narrative + " ") if chain.narrative else ""
        return f"{lead}Given {given}. The {what} (in {target_unit}) is:"

    def distractors(env, p):
        a = env[chain.answer]
        # stopping one link short is THE authentic multi-step misconception; then classic numeric transforms
        penult = env.get(chain.steps[-2].out) if len(chain.steps) > 1 else None
        out = [penult] if isinstance(penult, float) else []
        return out + [a * 2, a / 2, -a, a * 4]

    def e2e(env, p):
        """INDEPENDENT end-to-end: every link's ORIGINAL equation must hold in the final env."""
        for st in chain.steps:
            rel = rels[st.relation]
            syms = set(rel.get("symbols") or {})
            values = {k: v for k, v in p["vals"].items() if k in syms}
            values.update({k: v for k, v in consts.items() if k in syms})
            for recv, src in st.feeds.items():
                values[recv] = env[src]
            values[st.solve_for] = env[st.out]
            if not _residual_ok(rel, values):
                return False
        return True

    return CompositionTemplate(
        f"chain_{_slug(chain.name)}", f"{chain.subject} :: {chain.name}", setup, pipeline,
        chain.answer, e2e, stem, distractors,
        subject=chain.subject, gen_prefix="GENCHAIN_", fmt=_fmt)


CHAINS = _load_certified_chains()
TEMPLATES: Dict[str, CompositionTemplate] = {}
for _c in CHAINS:
    _t = _template(_c)
    if _t is not None:
        TEMPLATES[_t.name] = _t
register(TEMPLATES)


def summary() -> dict:
    from collections import Counter
    from kie.qie.compose import reasoning_depth
    depths = {}
    for c in CHAINS:
        depths[c.name] = CH.depth_of(c)
    return {"certified_chains": len(CHAINS), "templates": len(TEMPLATES),
            "by_subject": dict(Counter(t.subject for t in TEMPLATES.values())),
            "depths": depths}
