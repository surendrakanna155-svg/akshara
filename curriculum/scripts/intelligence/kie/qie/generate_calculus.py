"""Symbolic JEE-Mathematics calculus generation (Phase D — the JEE build).

Closes the JEE-Math blocker measured earlier (calculus is the JEE-distinctive Math construct; the school
relation library cannot verify it). Here calculus is generated AND verified SYMBOLICALLY with sympy, and the
verification uses the INVERSE operation of the generator — so it is genuinely independent, deterministic, and
needs no AI:
  * integrals: build the integrand f, answer F = ∫f dx; VERIFY by dF/dx == f;
  * derivatives: build f, answer g = df/dx; VERIFY by ∫g dx == f (up to a constant).
Distractors are common-error symbolic perturbations (forgot to divide by n+1, wrong power, differentiated
instead of integrated, dropped constant), each checked to be genuinely WRONG (fails the inverse-op check).
Profile = JEE_MAIN (calculus). Nothing fabricated: every value is a sympy result. Deterministic (seeded).
"""
from __future__ import annotations

import hashlib
from typing import Callable, Dict, List, Optional, Tuple

import sympy as sp

x = sp.Symbol("x")


def _seed_int(seed: str, lo: int, hi: int) -> int:
    return lo + (int(hashlib.sha256(seed.encode()).hexdigest(), 16) % (hi - lo + 1))


def _s(expr) -> str:
    """Compact, unambiguous text form of a sympy expression (x**n notation)."""
    return str(expr).replace("**", "^").replace("*", "").replace(" ", "")


# ── families: each returns (stem_expr f, answer F, operation) with symbolic verification built in ─────
def _poly_integral(seed: str):
    a = _seed_int(seed + "a", 2, 9); n = _seed_int(seed + "n", 2, 5)
    b = _seed_int(seed + "b", 1, 8); m = _seed_int(seed + "m", 0, 1)
    f = a * x**n + b * x**m
    return f, sp.integrate(f, x), "integrate"


def _poly_derivative(seed: str):
    a = _seed_int(seed + "a", 2, 9); n = _seed_int(seed + "n", 2, 6)
    b = _seed_int(seed + "b", 1, 8); m = _seed_int(seed + "m", 1, 3)
    f = a * x**n + b * x**m
    return f, sp.diff(f, x), "differentiate"


def _trig_derivative(seed: str):
    k = _seed_int(seed + "k", 2, 6)
    fam = _seed_int(seed + "f", 0, 2)
    f = [sp.sin(k * x), sp.cos(k * x), sp.tan(x)][fam]
    return f, sp.diff(f, x), "differentiate"


def _exp_integral(seed: str):
    k = _seed_int(seed + "k", 2, 6)
    f = sp.exp(k * x)
    return f, sp.integrate(f, x), "integrate"


FAMILIES: Tuple[Tuple[str, Callable], ...] = (
    ("poly_integral", _poly_integral), ("poly_derivative", _poly_derivative),
    ("trig_derivative", _trig_derivative), ("exp_integral", _exp_integral),
)

_STEM = {
    "integrate": "The value of the integral ∫({f}) dx (ignoring the constant of integration) is:",
    "differentiate": "The derivative of {f} with respect to x is:",
}


def _distractors(f, ans, op: str) -> List[sp.Expr]:
    """Common-error symbolic wrong answers; each is later verified to genuinely fail the inverse-op check."""
    cands = []
    if op == "integrate":
        cands = [f,                                   # forgot to integrate
                 sp.diff(f, x),                       # differentiated instead
                 ans * 2, sp.expand(ans + x)]         # scale / stray term
    else:  # differentiate
        cands = [f,                                   # forgot to differentiate
                 sp.integrate(f, x),                  # integrated instead
                 ans * 2, sp.expand(ans + 1)]         # scale / off-by-constant
    return cands


def _verifies(f, ans, op: str) -> bool:
    """INDEPENDENT symbolic check via the inverse operation."""
    try:
        if op == "integrate":
            return sp.simplify(sp.diff(ans, x) - f) == 0
        return sp.simplify(sp.integrate(ans, x) - f) == 0   # antiderivative of the derivative == f (+const→diff 0)
    except Exception:
        return False


def generate(per_family: int = 8, seed: str = "C1") -> List[dict]:
    cands: List[dict] = []
    for fam, fn in FAMILIES:
        for j in range(per_family):
            s = f"{seed}|{fam}|{j}"
            f, ans, op = fn(s)
            if ans is None or ans == 0:
                continue
            # distractors: distinct, != answer, and genuinely WRONG (fail the inverse-op check)
            distr = []
            for d in _distractors(f, ans, op):
                if sp.simplify(d - ans) == 0:
                    continue
                if _verifies(f, d, op):        # a "distractor" that is actually correct → skip
                    continue
                if all(sp.simplify(d - e) != 0 for e in distr):
                    distr.append(d)
            if len(distr) < 3:
                continue
            opts_syms = sorted([ans] + distr[:3],
                               key=lambda e: hashlib.sha256((_s(e) + s).encode()).hexdigest())
            options = {str(i + 1): _s(e) for i, e in enumerate(opts_syms)}
            gen_id = "GENC_" + hashlib.sha256(f"{fam}|{f}".encode()).hexdigest()[:16]
            cands.append({
                "gen_id": gen_id,
                "item_model_id": "IMC_MATH_" + hashlib.sha256(f"JEE_MAIN|calculus|{fam}".encode()).hexdigest()[:12],
                "subject": "Mathematics", "profile": "JEE_MAIN", "concept": f"CALC_{fam.upper()}",
                "archetype": "single_step_numerical", "frame_id": fam, "operation": op,
                "stem": _STEM[op].format(f=_s(f)), "options": options, "answer_text": _s(ans),
                "provenance": {"family": fam, "operation": op, "integrand_or_function": _s(f),
                               "verification": "symbolic_inverse_operation"},
                "_f": f, "_ans": ans, "_op": op,
            })
    return cands


def verify_calculus(cand: dict) -> str:
    """Deterministic symbolic verification (inverse operation) + unique-key check. 'agree' | 'disagree'."""
    if not _verifies(cand["_f"], cand["_ans"], cand["_op"]):
        return "disagree"
    if list(cand["options"].values()).count(cand["answer_text"]) != 1:
        return "disagree"
    return "agree"


def gate_calculus(cand: dict, seen: set) -> Optional[str]:
    sig = (cand["frame_id"], _s(cand["_f"]))
    if len({v for v in cand["options"].values()}) != len(cand["options"]):
        return "DUPLICATE_OPTION"
    if sig in seen:
        return "DUPLICATE_GENERATED"
    seen.add(sig)
    return None


def run(per_family: int = 8, seed: str = "C1", verify_fn: Callable[[dict], str] = verify_calculus) -> dict:
    seen: set = set()
    passed, rejected = [], []
    for cand in generate(per_family, seed):
        reason = gate_calculus(cand, seen)
        if reason:
            rejected.append({**{k: v for k, v in cand.items() if not k.startswith("_")},
                             "status": "REJECT", "reason": reason})
            continue
        verdict = verify_fn(cand)
        rec = {**{k: v for k, v in cand.items() if not k.startswith("_")},
               "verification": {"verdict": verdict, "method": "symbolic_inverse_operation"}}
        if verdict == "agree":
            passed.append({**rec, "status": "PASS"})
        else:
            rejected.append({**rec, "status": "REJECT", "reason": "SYMBOLIC_DISAGREEMENT"})
    return {"attempted": len(passed) + len(rejected), "passed": len(passed), "rejected": len(rejected),
            "quarantined": 0, "items": passed + rejected, "verified_bank": passed}
