"""Compositional Question Generation (CQG) — the composition layer (curated templates).

Built on the operator engine in `compose.py`. Each CompositionTemplate is an ordered operator pipeline wired
output→input, plus a curated high-quality natural-language stem and an INDEPENDENT end-to-end check. A
generated item is banked ONLY if (a) every operator step verifies independently AND (b) an independent
end-to-end recomputation of the final answer agrees. Reasoning DEPTH is computed from the pipeline structure
(compose.reasoning_depth). Deterministic (seeded), no AI per item, nothing fabricated.

These are genuine multi-concept JEE problems (area between roots, minimum value via calculus, tangent slope at
a derived point, FTC), not single-skill drills. Adding a template is declarative — the reusable substrate is
the operator registry, so this scales without per-family bespoke code (the debt the owner asked us to avoid).
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass
from fractions import Fraction
from typing import Callable, Dict, List, Optional

import mpmath
import sympy as sp

from kie.qie.compose import (OPERATORS, Step, close, depth_band, pipeline_concepts, pipeline_domains,
                             reasoning_depth, run_pipeline, to_float, x, _poly_fn)


def _si(seed: str, lo: int, hi: int) -> int:
    return lo + (int(hashlib.sha256(seed.encode()).hexdigest(), 16) % (hi - lo + 1))


def _fmt(v) -> str:
    f = v if isinstance(v, Fraction) else Fraction(str(v))
    return str(f.numerator) if f.denominator == 1 else f"{f.numerator}/{f.denominator}"


def _poly_text(f) -> str:
    return str(sp.expand(f)).replace("**", "^").replace("*", "")


@dataclass
class CompositionTemplate:
    name: str
    concept_code: str
    setup: Callable          # params(seed) already applied → returns (env0, params)
    pipeline: List[Step]
    answer_key: str
    end_to_end: Callable     # (env, params) -> independent value (a genuinely different route)
    stem: Callable           # (env, params) -> str
    distractors: Callable     # (env, params) -> list of candidate wrong values


# ── T1: area between a parabola and the x-axis, between its roots (algebra + calculus) ─────────────────
def _t1_setup(seed):
    p = _si(seed + "p", -3, 1); q = p + _si(seed + "q", 2, 4); a = _si(seed + "a", 1, 3)
    f = sp.expand(a * (x - p) * (x - q))
    return {"f": f, "a": a, "p": p, "q": q}, {"p": p, "q": q, "a": a}


_T1 = CompositionTemplate(
    "area_between_roots", "COMPOSE_AREA_BETWEEN_ROOTS", _t1_setup,
    [Step("roots", "real_roots", ("f",)), Step("lo", "min_root", ("roots",)),
     Step("hi", "max_root", ("roots",)), Step("signed", "integrate_def", ("f", "lo", "hi")),
     Step("area", "absval", ("signed",))],
    "area",
    lambda env, p: abs(float(mpmath.quad(_poly_fn(env["f"]), [p["p"], p["q"]]))),
    lambda env, p: (f"The area (in square units) of the finite region enclosed between the curve "
                    f"y = {_poly_text(env['f'])} and the x-axis is:"),
    lambda env, p: [env["signed"], 2 * env["area"], env["area"] + abs(p["q"] - p["p"])],
)


# ── T2: minimum value of a quadratic, found via differentiation (calculus + algebra) ──────────────────
def _t2_setup(seed):
    a = _si(seed + "a", 1, 3); h = _si(seed + "h", -3, 3); k = _si(seed + "k", -5, 5)
    f = sp.expand(a * (x - h) ** 2 + k)
    return {"f": f, "a": a, "h": h, "k": k}, {"a": a, "h": h, "k": k}


def _t2_e2e(env, p):
    a2, b1, c0 = [Fraction(str(c)) for c in sp.Poly(env["f"], x).all_coeffs()]   # closed-form vertex formula
    return c0 - b1 * b1 / (4 * a2)


_T2 = CompositionTemplate(
    "min_value_quadratic", "COMPOSE_MIN_VALUE_QUADRATIC", _t2_setup,
    [Step("fp", "differentiate", ("f",)), Step("crootset", "real_roots", ("fp",)),
     Step("crit", "unique_root", ("crootset",)), Step("minval", "evaluate", ("f", "crit"))],
    "minval", _t2_e2e,
    lambda env, p: f"The minimum value of the function f(x) = {_poly_text(env['f'])} is:",
    lambda env, p: [p["h"], -env["minval"], env["f"].subs(x, 0), env["minval"] + p["a"]],
)


# ── T3: slope of the tangent to f at the larger root of g (algebra + calculus, cross-concept) ─────────
def _t3_setup(seed):
    a = _si(seed + "a", 1, 3); b = _si(seed + "b", -4, 4); c = _si(seed + "c", -3, 3)
    r1 = _si(seed + "r1", -3, 1); r2 = r1 + _si(seed + "r2", 1, 4)
    f = sp.expand(a * x ** 2 + b * x + c); g = sp.expand((x - r1) * (x - r2))
    return {"f": f, "g": g, "a": a, "b": b, "r1": r1, "r2": r2}, {"a": a, "b": b, "r1": r1, "r2": r2}


def _t3_e2e(env, p):
    g = _poly_fn(env["f"]); r2 = p["r2"]; h = 1e-6
    return (g(r2 + h) - g(r2 - h)) / (2 * h)                       # numeric derivative of f at r2


_T3 = CompositionTemplate(
    "tangent_slope_at_root", "COMPOSE_TANGENT_SLOPE_AT_ROOT", _t3_setup,
    [Step("groots", "real_roots", ("g",)), Step("pt", "max_root", ("groots",)),
     Step("fp", "differentiate", ("f",)), Step("slope", "evaluate", ("fp", "pt"))],
    "slope", _t3_e2e,
    lambda env, p: (f"For f(x) = {_poly_text(env['f'])}, the slope of the tangent to the curve y = f(x) at "
                    f"the larger value of x satisfying {_poly_text(env['g'])} = 0 is:"),
    lambda env, p: [env["f"].subs(x, p["r2"]), 2 * p["a"] * p["r1"] + p["b"], sp.Integer(0)],
)


# ── T4: definite integral of a derivative — the Fundamental Theorem of Calculus (calculus) ────────────
def _t4_setup(seed):
    a = _si(seed + "a", 1, 3); b = _si(seed + "b", -4, 4); c = _si(seed + "c", -3, 3)
    lo = _si(seed + "lo", 0, 2); hi = lo + _si(seed + "hi", 1, 3)
    f = sp.expand(a * x ** 2 + b * x + c)
    return {"f": f, "lo": lo, "hi": hi}, {"lo": lo, "hi": hi}


def _t4_e2e(env, p):
    g = _poly_fn(env["f"])
    return g(p["hi"]) - g(p["lo"])                                 # FTC identity via direct evaluation


def _t4_distr(env, p):
    g = _poly_fn(env["f"])
    return [_round(g(p["lo"]) - g(p["hi"])),                       # swapped limits (sign error)
            _round(g(p["hi"]) + g(p["lo"])),                       # summed instead of differenced
            sp.diff(env["f"], x).subs(x, p["hi"])]                 # evaluated f'(hi) instead of integrating


_T4 = CompositionTemplate(
    "ftc_integral_of_derivative", "COMPOSE_FTC_INTEGRAL_OF_DERIVATIVE", _t4_setup,
    [Step("fp", "differentiate", ("f",)), Step("val", "integrate_def", ("fp", "lo", "hi"))],
    "val", _t4_e2e,
    lambda env, p: (f"If f(x) = {_poly_text(env['f'])}, the value of the definite integral "
                    f"∫ from {p['lo']} to {p['hi']} of f '(x) dx is:"),
    _t4_distr,
)


TEMPLATES: Dict[str, CompositionTemplate] = {t.name: t for t in (_T1, _T2, _T3, _T4)}


def _round(v):
    """Snap a float independent-value / answer to an exact rational for clean comparison and display."""
    if isinstance(v, float):
        return Fraction(v).limit_denominator(10**6)
    return Fraction(str(v))


def generate(per_template: int = 8, seed: str = "K1") -> List[dict]:
    cands: List[dict] = []
    for name, tmpl in TEMPLATES.items():
        for j in range(per_template):
            s = f"{seed}|{name}|{j}"
            env0, params = tmpl.setup(s)
            env, ok = run_pipeline(env0, tmpl.pipeline)
            if not ok:                                             # a per-step independent check failed
                continue
            answer = env[tmpl.answer_key]
            indep = tmpl.end_to_end(env, params)
            if indep is None or not close(indep, answer):          # end-to-end independent check failed
                continue
            ans_t = _fmt(answer)
            opts = [answer]
            for d in tmpl.distractors(env, params):
                dt = _fmt(d)
                if dt == ans_t:
                    continue
                if dt not in {_fmt(o) for o in opts}:
                    opts.append(d)
                if len(opts) == 4:
                    break
            if len(opts) < 4:
                continue
            opts_sorted = sorted(opts, key=lambda e: hashlib.sha256((_fmt(e) + s).encode()).hexdigest())
            options = {str(i + 1): _fmt(e) for i, e in enumerate(opts_sorted)}
            depth = reasoning_depth(tmpl.pipeline, env0.keys())
            sig = hashlib.sha256(f"{name}|{tmpl.stem(env, params)}".encode()).hexdigest()[:16]
            cands.append({
                "gen_id": "GENK_" + sig,
                "item_model_id": "IMK_" + hashlib.sha256(f"{tmpl.concept_code}".encode()).hexdigest()[:12],
                "subject": "Mathematics", "profile": "JEE_MAIN", "concept": tmpl.concept_code,
                "archetype": "multi_step_numerical", "frame_id": name,
                "stem": tmpl.stem(env, params), "options": options, "answer_text": ans_t,
                "reasoning_depth": depth, "depth_band": depth_band(depth),
                "provenance": {"template": name, "concepts": pipeline_concepts(tmpl.pipeline),
                               "domains": pipeline_domains(tmpl.pipeline), "reasoning_depth": depth,
                               "depth_band": depth_band(depth), "verification": "per_step + independent_end_to_end"},
                "_env0": env0, "_params": params, "_answer": answer, "_sig": sig,
            })
    return cands


def verify_composition(cand: dict) -> str:
    """Authoritative re-verification from scratch: re-run the pipeline (per-step independent checks) + the
    independent end-to-end recomputation, and confirm the recorded answer/options are untampered."""
    tmpl = TEMPLATES[cand["frame_id"]]
    env, ok = run_pipeline(cand["_env0"], tmpl.pipeline)
    if not ok:
        return "disagree"
    true_ans = env[tmpl.answer_key]
    indep = tmpl.end_to_end(env, cand["_params"])
    if indep is None or not close(indep, true_ans):
        return "disagree"
    if not close(true_ans, cand["_answer"]):
        return "disagree"
    if cand["answer_text"] != _fmt(true_ans):
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


def run(per_template: int = 8, seed: str = "K1", verify_fn: Callable[[dict], str] = verify_composition) -> dict:
    seen: set = set()
    passed, rejected = [], []
    for cand in generate(per_template, seed):
        reason = gate(cand, seen)
        clean = {k: v for k, v in cand.items() if not k.startswith("_")}
        if reason:
            rejected.append({**clean, "status": "REJECT", "reason": reason})
            continue
        verdict = verify_fn(cand)
        rec = {**clean, "verification": {"verdict": verdict, "method": "per_step + independent_end_to_end"}}
        if verdict == "agree":
            passed.append({**rec, "status": "PASS"})
        else:
            rejected.append({**rec, "status": "REJECT", "reason": "VERIFICATION_DISAGREEMENT"})
    return {"attempted": len(passed) + len(rejected), "passed": len(passed), "rejected": len(rejected),
            "quarantined": 0, "items": passed + rejected, "verified_bank": passed}
