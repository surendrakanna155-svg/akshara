"""Deterministic, independently-verifiable JEE-Mathematics generation — breadth beyond calculus (Phase D+).

Owner-approved 2026-07-14: continue the unblocked JEE-Math lane with deterministic generation, each item
verified by a GENUINELY INDEPENDENT SECOND METHOD (never sympy checking sympy):

  * definite_integral : symbolic F(b)−F(a)                VERIFIED BY numerical quadrature (mpmath.quad).
  * finite_series     : closed-form AP/GP sum formula      VERIFIED BY brute-force term-by-term summation.
  * limit             : sympy symbolic limit of (xⁿ−cⁿ)/(x−c)  VERIFIED BY numeric evaluation approaching c.
  * determinant       : cofactor expansion along row 0      VERIFIED BY expansion along a DIFFERENT line.
  * vieta             : Vieta sum/product of roots          VERIFIED BY solving the quadratic and combining
                        the actual roots.

Profile = JEE_MAIN, subject = Mathematics. Deterministic (seeded). No AI, no corpus dependence, nothing
fabricated — every value is computed twice by two different routes and must agree.
"""
from __future__ import annotations

import hashlib
from fractions import Fraction
from typing import Callable, Dict, List, Optional, Tuple

import mpmath
import sympy as sp

x = sp.Symbol("x")
_TOL = 1e-7


def _seed_int(seed: str, lo: int, hi: int) -> int:
    return lo + (int(hashlib.sha256(seed.encode()).hexdigest(), 16) % (hi - lo + 1))


def _num(v) -> str:
    """Compact exact text for an integer/Fraction/sympy Rational."""
    f = Fraction(str(v)) if not isinstance(v, Fraction) else v
    return str(f.numerator) if f.denominator == 1 else f"{f.numerator}/{f.denominator}"


# ── generators: each returns (concept, stem, answer_value, distractor_values, provenance, verify_payload) ──
def _definite_integral(seed: str):
    a = _seed_int(seed + "a", 2, 6); n = _seed_int(seed + "n", 1, 4)
    b = _seed_int(seed + "b", 1, 5); m = _seed_int(seed + "m", 0, 2)
    lo = _seed_int(seed + "lo", 0, 2); hi = lo + _seed_int(seed + "hi", 1, 3)
    f = a * x**n + b * x**m
    ans = sp.integrate(f, (x, lo, hi))                       # symbolic definite integral
    F = sp.integrate(f, x)
    distr = [sp.integrate(f, x).subs(x, hi),                 # forgot the lower limit
             ans * 2, -ans, F.subs(x, lo) - F.subs(x, hi)]   # scale / sign / swapped limits
    stem = f"The value of the definite integral ∫ from {lo} to {hi} of ({_s(f)}) dx is:"
    payload = {"kind": "quad", "coef": [(int(a), int(n)), (int(b), int(m))], "lo": lo, "hi": hi}
    return "DEFINITE_INTEGRAL", stem, ans, distr, {"integrand": _s(f), "lo": lo, "hi": hi}, payload


def _finite_series(seed: str):
    gp = _seed_int(seed + "t", 0, 1) == 1
    n = _seed_int(seed + "n", 4, 8)
    if gp:
        a = _seed_int(seed + "a", 1, 4); r = _seed_int(seed + "r", 2, 3)
        ans = a * (r**n - 1) // (r - 1)                      # closed form
        distr = [a * r**n, a * (r**n - 1), a * r ** (n - 1) * n, ans + a]
        stem = (f"The sum of the first {n} terms of the geometric progression with first term {a} "
                f"and common ratio {r} is:")
        payload = {"kind": "gp", "a": a, "r": r, "n": n}
        concept = "GP_SUM"
    else:
        a = _seed_int(seed + "a", 1, 6); d = _seed_int(seed + "d", 2, 6)
        ans = n * (2 * a + (n - 1) * d) // 2                 # closed form
        distr = [n * (a + (n - 1) * d), (n - 1) * (2 * a + (n - 2) * d) // 2, a + (n - 1) * d, ans + d]
        stem = (f"The sum of the first {n} terms of the arithmetic progression with first term {a} "
                f"and common difference {d} is:")
        payload = {"kind": "ap", "a": a, "d": d, "n": n}
        concept = "AP_SUM"
    return concept, stem, ans, distr, {**payload}, payload


def _limit(seed: str):
    c = _seed_int(seed + "c", 1, 4); n = _seed_int(seed + "n", 2, 5)
    f = (x**n - c**n) / (x - c)
    ans = sp.limit(f, x, c)                                  # symbolic limit = n·c^(n-1)
    distr = [c**n, n * c**n, (n - 1) * c ** (n - 1), sp.Integer(0)]
    stem = f"The value of the limit as x approaches {c} of (x^{n} - {c**n})/(x - {c}) is:"
    payload = {"kind": "limit", "c": c, "n": n}
    return "LIMIT", stem, ans, distr, {"c": c, "n": n}, payload


def _minor(M: List[List[int]], i: int, j: int) -> List[List[int]]:
    return [[M[r][k] for k in range(len(M)) if k != j] for r in range(len(M)) if r != i]


def _det_expand(M: List[List[int]], along_row: int = 0) -> int:
    """Independent determinant by Laplace cofactor expansion along a chosen row (pure python)."""
    n = len(M)
    if n == 1:
        return M[0][0]
    if n == 2:
        return M[0][0] * M[1][1] - M[0][1] * M[1][0]
    total = 0
    i = along_row
    for j in range(n):
        total += ((-1) ** (i + j)) * M[i][j] * _det_expand(_minor(M, i, j))
    return total


def _determinant(seed: str):
    # 3×3 only: the independent check expands along a DIFFERENT row (row 2), which is genuinely different
    # arithmetic. A 2×2 determinant has a single ad−bc formula, so it has no honest second method.
    n = 3
    M = [[_seed_int(f"{seed}|{r}|{k}", -4, 6) for k in range(n)] for r in range(n)]
    ans = _det_expand(M, along_row=0)
    diag = 1
    for i in range(n):
        diag *= M[i][i]
    distr = [diag, -ans, ans + 1, sum(M[0])]                 # product-of-diagonal error / sign / off-by-one
    rows = "; ".join("[" + ", ".join(str(v) for v in row) + "]" for row in M)
    stem = f"The determinant of the {n}×{n} matrix with rows {rows} is:"
    payload = {"kind": "det", "M": M}
    return "DETERMINANT", stem, ans, distr, {"matrix": M}, payload


def _vieta(seed: str):
    p = _seed_int(seed + "p", -5, 6); q = _seed_int(seed + "q", -5, 6)
    b = -(p + q); c = p * q
    want_sum = _seed_int(seed + "w", 0, 1) == 1
    ans = (p + q) if want_sum else (p * q)
    distr = [-ans, b, c, (p + q) if not want_sum else (p * q)]  # sign / coefficient confusion / swap
    kind = "sum" if want_sum else "product"
    stem = (f"For the quadratic equation x² + ({b})x + ({c}) = 0, the {kind} of its roots is:")
    payload = {"kind": "vieta", "b": b, "c": c, "want": kind}
    return "VIETA_ROOTS", stem, ans, distr, {"b": b, "c": c, "asks": kind}, payload


def _s(expr) -> str:
    return str(expr).replace("**", "^").replace("*", "").replace(" ", "")


FAMILIES: Tuple[Tuple[str, Callable], ...] = (
    ("definite_integral", _definite_integral), ("finite_series", _finite_series),
    ("limit", _limit), ("determinant", _determinant), ("vieta", _vieta),
)


# ── INDEPENDENT verification (a genuinely different computation per family) ────────────────────────────
def _independent_value(payload: dict):
    k = payload["kind"]
    if k == "quad":
        coef, lo, hi = payload["coef"], payload["lo"], payload["hi"]
        f = lambda t: sum(a * t**n for a, n in coef)
        return float(mpmath.quad(f, [lo, hi]))              # numerical quadrature
    if k == "ap":
        a, d, n = payload["a"], payload["d"], payload["n"]
        return sum(a + i * d for i in range(n))             # brute-force summation
    if k == "gp":
        a, r, n = payload["a"], payload["r"], payload["n"]
        return sum(a * r**i for i in range(n))              # brute-force summation
    if k == "limit":
        c, n = payload["c"], payload["n"]
        h = 1e-6
        vals = [(((c + h) ** n - c**n) / h), ((c**n - (c - h) ** n) / h)]   # finite-difference from both sides
        return sum(vals) / 2.0
    if k == "det":
        M = payload["M"]
        return _det_expand(M, along_row=len(M) - 1)         # expand along a DIFFERENT row (independent)
    if k == "vieta":
        b, c, want = payload["b"], payload["c"], payload["want"]
        mult = sp.roots(x**2 + b * x + c, x)                # {root: multiplicity} — handles repeated roots
        r = []
        for root, m in mult.items():
            r += [complex(sp.N(root))] * int(m)
        if len(r) != 2:                                     # fall back: solve as a degree-2 poly explicitly
            r = [complex(sp.N(t)) for t in sp.Poly(x**2 + b * x + c, x).all_roots()]
        val = (r[0] + r[1]) if want == "sum" else (r[0] * r[1])
        return val.real
    raise ValueError(k)


def _agrees(answer_value, payload: dict) -> bool:
    try:
        indep = _independent_value(payload)
        exact = float(Fraction(str(sp.nsimplify(answer_value)))) if not isinstance(answer_value, (int, float)) \
            else float(answer_value)
        return abs(indep - exact) <= max(_TOL, abs(exact) * 1e-6)
    except Exception:
        return False


def generate(per_family: int = 8, seed: str = "J1") -> List[dict]:
    cands: List[dict] = []
    for fam, fn in FAMILIES:
        for j in range(per_family):
            s = f"{seed}|{fam}|{j}"
            try:
                concept, stem, ans, distr, prov, payload = fn(s)
            except Exception:
                continue
            if ans is None:
                continue
            ans_t = _num(ans)
            opts = [ans]
            for d in distr:
                if d is None:
                    continue
                dt = _num(d)
                if dt == ans_t:
                    continue
                if dt not in {_num(o) for o in opts}:
                    opts.append(d)
                if len(opts) == 4:
                    break
            if len(opts) < 4:
                continue
            opts_sorted = sorted(opts, key=lambda e: hashlib.sha256((_num(e) + s).encode()).hexdigest())
            options = {str(i + 1): _num(e) for i, e in enumerate(opts_sorted)}
            sig = hashlib.sha256(f"{fam}|{stem}".encode()).hexdigest()[:16]
            cands.append({
                "gen_id": "GENJM_" + sig,
                "item_model_id": "IMC_MATH_" + hashlib.sha256(f"JEE_MAIN|{fam}".encode()).hexdigest()[:12],
                "subject": "Mathematics", "profile": "JEE_MAIN", "concept": f"JMATH_{concept}",
                "archetype": "single_step_numerical", "frame_id": fam,
                "stem": stem, "options": options, "answer_text": ans_t,
                "provenance": {"family": fam, **prov, "verification": "independent_second_method"},
                "_ans": ans, "_payload": payload, "_sig": sig,
            })
    return cands


def verify_jee_math(cand: dict) -> str:
    """'agree' iff the independent second method reproduces the answer AND options are well-formed."""
    if not _agrees(cand["_ans"], cand["_payload"]):
        return "disagree"
    if list(cand["options"].values()).count(cand["answer_text"]) != 1:
        return "disagree"
    if len(set(cand["options"].values())) != len(cand["options"]):
        return "disagree"
    return "agree"


def gate(cand: dict, seen: set) -> Optional[str]:
    if len(set(cand["options"].values())) != len(cand["options"]):
        return "DUPLICATE_OPTION"
    if cand["_sig"] in seen:
        return "DUPLICATE_GENERATED"
    seen.add(cand["_sig"])
    return None


def run(per_family: int = 8, seed: str = "J1", verify_fn: Callable[[dict], str] = verify_jee_math) -> dict:
    seen: set = set()
    passed, rejected = [], []
    for cand in generate(per_family, seed):
        reason = gate(cand, seen)
        clean = {k: v for k, v in cand.items() if not k.startswith("_")}
        if reason:
            rejected.append({**clean, "status": "REJECT", "reason": reason})
            continue
        verdict = verify_fn(cand)
        rec = {**clean, "verification": {"verdict": verdict, "method": "independent_second_method"}}
        if verdict == "agree":
            passed.append({**rec, "status": "PASS"})
        else:
            rejected.append({**rec, "status": "REJECT", "reason": "INDEPENDENT_DISAGREEMENT"})
    return {"attempted": len(passed) + len(rejected), "passed": len(passed), "rejected": len(rejected),
            "quarantined": 0, "items": passed + rejected, "verified_bank": passed}
