"""Compositional CHAINS over CERTIFIED relations — the depth-4/5 lane.

Why this exists: `qp_bridge._difficulty` calls depth>=4 HARD, and every exam blueprint reserves its hard cells
for multi-concept work (NEET Section B = 40 slots, JEE Main Section B = 15, JEE Advanced Numerical = 12). A
single certified relation is one operator application (depth 1) and can only ever be MEDIUM, so *more single
relations will never fill a hard cell*. A chain feeds one certified relation's output into the next — which is
exactly what a real JEE/NEET multi-step item asks — and the DAG earns its depth honestly (`compose.reasoning_depth`
measures the longest dependency chain, it is never assigned).

Nothing here asserts NEW knowledge: a chain is a composition RECIPE over relations that already passed the
locked hierarchy. What must be certified is the WIRING, and the load-bearing gate is JUNCTION DIMENSIONAL
COMPATIBILITY: when step A's solved symbol feeds step B's input symbol, their declared units must reduce to the
same base dimensions. Without it a chain silently feeds joules into a joules-per-mole slot and produces
confident nonsense — the exact wrong-knowledge failure the standing law forbids.

Gates (ALL mandatory, deterministic — no model certifies here):
  * STEPS_CERTIFIED — every referenced relation exists in `governed_relation` with status='certified'.
  * SOLVABLE       — each step's equation solves for its target with exactly ONE real branch (an ambiguous
                     ± branch is rejected, never guessed).
  * JUNCTION       — every feed is dimensionally compatible (base-dimension reduction, so `A·ohm == V`).
  * CLOSURE        — every symbol of every step is a given, a feed, a constant, or the target: no free symbol.
  * DEPTH          — the DAG's longest chain; >= 4 is required for a chain to be worth generating (HARD).
"""
from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import sympy as sp

from kie.qie.convert.notation import dimensions as DIM

DEF_DIR = Path(__file__).parent / "batches"
HARD_DEPTH = 4


@dataclass
class ChainStep:
    out: str                       # env name this step's result is bound to
    relation: str                  # governed_relation.name (must be certified)
    solve_for: str                 # symbol this step computes
    feeds: Dict[str, str] = field(default_factory=dict)   # {receiving_symbol: prior step's `out`}


@dataclass
class Chain:
    name: str                      # concept title — must pass qpgen sanitize.is_clean_concept
    subject: str
    concept_candidate: str
    steps: List[ChainStep]
    answer: str                    # the terminal step's `out`
    givens: Dict[str, dict]        # {symbol: {lo, hi, scale}} — instance realism only
    exam: Optional[str] = None
    narrative: str = ""            # authored scene-setting; must NOT reveal the route (lesson: no giveaway)
    # A symbol's ROLE can differ once a relation is composed: `V` in the Wheatstone chain is the drop across
    # the unknown arm, not "across the conductor" as the standalone Ohm's-law record words it. Overrides
    # restate the role for THIS chain's scene; they never change a certified unit or equation.
    meaning_overrides: Dict[str, str] = field(default_factory=dict)


def _mk(d: dict) -> Chain:
    return Chain(name=d["name"], subject=d["subject"], concept_candidate=d["concept_candidate"],
                 steps=[ChainStep(**s) for s in d["steps"]], answer=d["answer"], givens=d["givens"],
                 exam=d.get("exam"), narrative=d.get("narrative", ""),
                 meaning_overrides=d.get("meaning_overrides", {}))


def load(name: str) -> List[Chain]:
    p = DEF_DIR / f"{name}.json"
    if not p.exists():
        raise FileNotFoundError(f"no such chain set {name!r}")
    return [_mk(c) for c in json.loads(p.read_text())["chains"]]


def available() -> List[str]:
    return sorted(p.stem for p in DEF_DIR.glob("*_chains.json"))


# ── solving ───────────────────────────────────────────────────────────────────────────────────────────
def solve_step(rel: dict, target: str) -> Optional[sp.Expr]:
    """Solve a certified relation for `target`. Returns the unique real branch, or None if the equation is not
    solvable for it or the branch is ambiguous (±) — an ambiguous branch is REJECTED, never picked."""
    syms = rel.get("symbols") or {}
    if target not in syms:
        return None
    loc = {s: sp.Symbol(s, real=True) for s in syms}
    loc["pi"] = sp.pi
    try:
        lhs, rhs = rel["equation"].split("=", 1)
        eq = sp.Eq(sp.sympify(lhs, locals=loc), sp.sympify(rhs, locals=loc))
        sols = sp.solve(eq, sp.Symbol(target, real=True), dict=False)
    except Exception:
        return None
    real = [s for s in sols if not s.free_symbols & {sp.I} and s.is_real is not False]
    if len(real) != 1:                      # 0 = unsolvable, >1 = ambiguous branch (e.g. T**2 = ... )
        return None
    return real[0]


def _unit_of(rel: dict, sym: str) -> Optional[str]:
    return (rel.get("symbols") or {}).get(sym)


def _dims(unit: Optional[str]):
    if unit is None:
        return None
    q = DIM.parse_unit(unit)
    return None if q is None else DIM.base_dims(q)


# ── certification ─────────────────────────────────────────────────────────────────────────────────────
def depth_of(chain: Chain) -> int:
    """Longest dependency chain — mirrors `compose.reasoning_depth` over the pipeline this chain compiles to
    (each step's config is a depth-0 base key; a feed carries its producer's depth)."""
    d: Dict[str, int] = {}
    last = 0
    for st in chain.steps:
        last = 1 + max((d.get(v, 0) for v in st.feeds.values()), default=0)
        d[st.out] = last
    return last


def certify(chain: Chain, by_name: Dict[str, dict]) -> dict:
    """Run the mandatory gates over a chain's wiring. `by_name` = certified relations keyed by name."""
    gates: Dict[str, dict] = {}

    missing = [s.relation for s in chain.steps if s.relation not in by_name]
    gates["steps_certified"] = {"ok": not missing,
                                "reason": f"not certified: {missing}" if missing else ""}
    if missing:
        return {"status": "rejected", "gates": gates, "failed_gates": ["steps_certified"], "depth": 0}

    # SOLVABLE
    unsolvable = [f"{s.relation}->{s.solve_for}" for s in chain.steps
                  if solve_step(by_name[s.relation], s.solve_for) is None]
    gates["solvable"] = {"ok": not unsolvable,
                         "reason": f"no unique real branch: {unsolvable}" if unsolvable else ""}

    # JUNCTION — the load-bearing gate
    produced: Dict[str, Tuple[str, str]] = {}          # out -> (relation, solved symbol)
    problems: List[str] = []
    checked: List[dict] = []
    for st in chain.steps:
        for recv_sym, src in st.feeds.items():
            if src not in produced:
                problems.append(f"{st.out}: feed {recv_sym!r} references unknown step {src!r}")
                continue
            src_rel, src_sym = produced[src]
            out_unit = _unit_of(by_name[src_rel], src_sym)
            in_unit = _unit_of(by_name[st.relation], recv_sym)
            a, b = _dims(out_unit), _dims(in_unit)
            ok = a is not None and b is not None and a == b
            checked.append({"junction": f"{src_rel}.{src_sym} ({out_unit}) -> {st.relation}.{recv_sym} "
                                        f"({in_unit})", "ok": ok})
            if not ok:
                problems.append(f"{src_rel}.{src_sym} [{out_unit}] is not dimensionally compatible with "
                                f"{st.relation}.{recv_sym} [{in_unit}]")
        produced[st.out] = (st.relation, st.solve_for)
    gates["junction"] = {"ok": not problems, "reason": "; ".join(problems), "junctions": checked}

    # CLOSURE — every symbol must be resolvable
    free: List[str] = []
    for st in chain.steps:
        rel = by_name[st.relation]
        consts = {c["symbol"] for c in (rel.get("constants") or []) if "symbol" in c}
        for sym in (rel.get("symbols") or {}):
            if sym == st.solve_for or sym in st.feeds or sym in consts or sym in chain.givens:
                continue
            free.append(f"{st.relation}.{sym}")
    gates["closure"] = {"ok": not free, "reason": f"unresolved symbols: {free}" if free else ""}

    # DEPTH
    depth = depth_of(chain)
    gates["depth"] = {"ok": depth >= HARD_DEPTH, "depth": depth,
                      "reason": "" if depth >= HARD_DEPTH else f"depth {depth} < {HARD_DEPTH} (not HARD)"}

    # terminal answer must be the last step's output
    gates["answer"] = {"ok": bool(chain.steps) and chain.steps[-1].out == chain.answer,
                       "reason": "" if chain.steps and chain.steps[-1].out == chain.answer
                                 else "answer is not the terminal step's output"}

    mandatory = ("steps_certified", "solvable", "junction", "closure", "depth", "answer")
    failed = [g for g in mandatory if not gates[g]["ok"]]
    return {"status": "certified" if not failed else "rejected", "gates": gates,
            "failed_gates": failed, "depth": depth}


def certified_relations(qconn: sqlite3.Connection) -> Dict[str, dict]:
    from kie.qie.convert.notation import register as RG
    return {r["name"]: r for r in RG.certified(qconn)}


def certify_set(name: str, by_name: Dict[str, dict]) -> List[dict]:
    return [{"chain": c, **certify(c, by_name)} for c in load(name)]
