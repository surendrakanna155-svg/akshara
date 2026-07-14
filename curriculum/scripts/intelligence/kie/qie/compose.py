"""Compositional Question Generation (CQG) — the engine layer.

Owner mandate (2026-07-14): a foundation capable of producing *lakhs* of genuinely high-quality questions
across multiple reasoning-DEPTH levels, without architectural debt to undo later. Not single-concept breadth.

This module is the debt-free core: a **typed operator layer**. Each Operator is a small, composable compute
unit that declares its input/output TYPES, a deterministic forward `apply`, and an INDEPENDENT `verify`
(a genuinely different second method — never "the same computation twice"). Because operators declare types,
their outputs wire into other operators' inputs — the basis for both curated compositions (see
`compositions.py`) and future *automatic* composition (type-directed chaining).

A composition is executed by `run_pipeline`, which verifies EVERY step independently and fails safe: if any
step's independent check disagrees, the item is rejected and never banked. Reasoning depth is COMPUTED from the
composition's structure (distinct concepts + domains), not hand-labelled — so depth differentiation is
principled and scales.

Types (the values that flow between operators): POLY (sympy expr in x) · NUMBER (exact number) ·
POINT (an x-value) · ROOTSET (sorted list of numbers).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from fractions import Fraction
from typing import Callable, Dict, List, Tuple

import mpmath
import sympy as sp

x = sp.Symbol("x")
_TOL = 1e-7

POLY, NUMBER, POINT, ROOTSET = "POLY", "NUMBER", "POINT", "ROOTSET"


def to_float(v) -> float:
    """int / Fraction / sympy number / python number → float (single, safe conversion point)."""
    return float(v)


def close(a, b) -> bool:
    fa, fb = to_float(a), to_float(b)
    return abs(fa - fb) <= max(_TOL, abs(fb) * 1e-6)


def _poly_fn(f):
    """Pure-python callable for a sympy polynomial, via its coefficients (independent of sympy evaluation)."""
    coeffs = [float(c) for c in sp.Poly(f, x).all_coeffs()]      # highest degree first

    def g(t: float) -> float:
        acc = 0.0
        for c in coeffs:
            acc = acc * t + c                                    # Horner
        return acc
    return g


@dataclass
class Operator:
    name: str
    concept_code: str
    domain: str
    in_types: Tuple[str, ...]
    out_type: str
    apply: Callable          # (*inputs) -> output   (deterministic forward)
    verify: Callable         # (inputs_list, output) -> bool   (INDEPENDENT second method)


OPERATORS: Dict[str, Operator] = {}


def _register(op: Operator) -> Operator:
    OPERATORS[op.name] = op
    return op


# ── operator: differentiate (POLY -> POLY); verified by the inverse operation (integration) ───────────
def _d_apply(f):
    return sp.diff(f, x)


def _d_verify(ins, out):
    f = ins[0]
    return sp.simplify(sp.diff(sp.integrate(out, x) - f, x)) == 0    # ∫out − f is constant ⇔ out = f'


_register(Operator("differentiate", "DIFFERENTIATE", "calculus", (POLY,), POLY, _d_apply, _d_verify))


# ── operator: definite integral ((POLY,NUMBER,NUMBER) -> NUMBER); verified by numerical quadrature ────
def _idef_apply(f, a, b):
    return sp.integrate(f, (x, a, b))


def _idef_verify(ins, out):
    f, a, b = ins
    try:
        val = float(mpmath.quad(_poly_fn(f), [to_float(a), to_float(b)]))
        return close(val, out)
    except Exception:
        return False


_register(Operator("integrate_def", "INTEGRATE_DEF", "calculus", (POLY, NUMBER, NUMBER), NUMBER,
                   _idef_apply, _idef_verify))


# ── operator: evaluate (POLY,POINT -> NUMBER); verified by independent Horner evaluation ──────────────
def _eval_apply(f, x0):
    return sp.nsimplify(f.subs(x, x0))


def _eval_verify(ins, out):
    f, x0 = ins
    try:
        return close(_poly_fn(f)(to_float(x0)), out)
    except Exception:
        return False


_register(Operator("evaluate", "EVALUATE", "algebra", (POLY, POINT), NUMBER, _eval_apply, _eval_verify))


# ── operator: real roots (POLY -> ROOTSET); verified by substitution (each root ≈ 0) ─────────────────
def _roots_apply(f):
    rs = []
    for r, m in sp.roots(f, x).items():
        if sp.im(r) == 0:
            rs += [sp.nsimplify(r)] * int(m)
    return sorted(set(rs), key=lambda z: float(z))


def _roots_verify(ins, out):
    f = ins[0]
    g = _poly_fn(f)
    return len(out) > 0 and all(abs(g(to_float(r))) <= 1e-6 for r in out)


_register(Operator("real_roots", "REAL_ROOTS", "algebra", (POLY,), ROOTSET, _roots_apply, _roots_verify))


# ── set reductions (ROOTSET -> NUMBER/POINT) ─────────────────────────────────────────────────────────
def _min_verify(ins, out):
    s = ins[0]
    return out in s and all(to_float(out) <= to_float(v) for v in s)


def _max_verify(ins, out):
    s = ins[0]
    return out in s and all(to_float(out) >= to_float(v) for v in s)


_register(Operator("min_root", "MIN_ROOT", "algebra", (ROOTSET,), NUMBER, lambda s: min(s, key=lambda z: float(z)),
                   _min_verify))
_register(Operator("max_root", "MAX_ROOT", "algebra", (ROOTSET,), POINT, lambda s: max(s, key=lambda z: float(z)),
                   _max_verify))


def _unique_verify(ins, out):
    s = ins[0]
    return len(s) == 1 and out == s[0]


_register(Operator("unique_root", "UNIQUE_ROOT", "algebra", (ROOTSET,), POINT, lambda s: s[0], _unique_verify))


# ── operator: subtract polynomials (POLY,POLY -> POLY); verified by numeric agreement at sample points ─
def _sub_apply(f, g):
    return sp.expand(f - g)


def _sub_verify(ins, out):
    f, g = ins
    gf, gg, go = _poly_fn(f), _poly_fn(g), _poly_fn(out)
    return all(close(go(t), gf(t) - gg(t)) for t in (0.3, 1.7, -2.1))    # independent numeric identity


_register(Operator("subtract_poly", "SUBTRACT_POLY", "algebra", (POLY, POLY), POLY, _sub_apply, _sub_verify))


# ── operator: absolute value (NUMBER -> NUMBER) ──────────────────────────────────────────────────────
def _abs_verify(ins, out):
    v = ins[0]
    return to_float(out) >= 0 and (close(out, v) or close(out, -v))


_register(Operator("absval", "ABS", "algebra", (NUMBER,), NUMBER, lambda v: abs(v), _abs_verify))


# ── executor ─────────────────────────────────────────────────────────────────────────────────────────
@dataclass
class Step:
    out_name: str
    op: str
    inputs: Tuple[str, ...]          # env keys


def run_pipeline(env0: dict, pipeline: List[Step]) -> Tuple[dict, bool]:
    """Execute a pipeline over an initial env. Returns (env, ok). Every step is INDEPENDENTLY verified;
    ok=False (fail-safe) the moment any step's independent check disagrees — the item must then be rejected."""
    env = dict(env0)
    for st in pipeline:
        op = OPERATORS[st.op]
        try:
            ins = [env[k] for k in st.inputs]
        except KeyError:
            return env, False
        if len(ins) != len(op.in_types):
            return env, False
        try:
            out = op.apply(*ins)
        except Exception:
            return env, False
        if not op.verify(ins, out):
            return env, False
        env[st.out_name] = out
    return env, True


def pipeline_concepts(pipeline: List[Step]) -> List[str]:
    seen, order = set(), []
    for st in pipeline:
        c = OPERATORS[st.op].concept_code
        if c not in seen:
            seen.add(c)
            order.append(c)
    return order


def pipeline_domains(pipeline: List[Step]) -> List[str]:
    return sorted({OPERATORS[st.op].domain for st in pipeline})


def reasoning_depth(pipeline: List[Step], base_keys) -> int:
    """Depth = length of the LONGEST dependency chain from the given (setup) values to the terminal result —
    i.e. how many dependent operator-applications the solver must perform in sequence. Computed from the DAG
    structure, not assigned; this is the principled basis for depth-level differentiation."""
    depth = {k: 0 for k in base_keys}
    last = 0
    for st in pipeline:
        d = 1 + max((depth.get(k, 0) for k in st.inputs), default=0)
        depth[st.out_name] = d
        last = d
    return last


def depth_band(depth: int) -> str:
    return "FOUNDATIONAL" if depth <= 1 else "INTERMEDIATE" if depth <= 3 else "ADVANCED"
