"""Type-directed auto-composition — Option 1 (owner-selected 2026-07-14): curated phrasing-schema per shape.

Auto-composition ENUMERATES type-valid operator pipelines automatically (scale), while PHRASING stays CURATED
per shape-schema (quality). Concretely: a ShapeSchema has operator SLOTS; each slot offers several
type-compatible operator sequences (e.g. TRANSFORM ∈ {f′, f″}, REDUCE ∈ {smaller-root, larger-root}). The
auto-composer:
  1. enumerates every combination of slot fillings,
  2. TYPE-CHECKS each filling against the operator registry's declared types (drops type-invalid ones),
  3. builds the concrete pipeline and runs it through the engine — where EVERY operator step is independently
     verified — so any surviving item is correct by construction (no separate end-to-end needed: soundness of a
     composition follows from soundness of each verified step),
  4. phrases it with the schema's curated, high-quality template filled by the chosen slots' phrases.

Scale = (schemas) × (slot fillings) × (parameters); quality = curated per shape. Deterministic, no AI per item,
nothing fabricated.
"""
from __future__ import annotations

import hashlib
import itertools
from dataclasses import dataclass
from typing import Callable, Dict, List, Optional, Tuple

import sympy as sp

from kie.qie.compose import OPERATORS, Step, depth_band, reasoning_depth, run_pipeline, x
from kie.qie.compositions import _fmt, _poly_text, _si


def chain_out_type(op_names: Tuple[str, ...], in_type: str) -> Optional[str]:
    """Thread a type through a single-input operator chain; None if any link is type-incompatible.
    This is the 'type-directed' guard — a slot filling is admitted only if the registry's types line up."""
    t = in_type
    for n in op_names:
        op = OPERATORS.get(n)
        if op is None or op.in_types != (t,):
            return None
        t = op.out_type
    return t


def chain_steps(out_name: str, op_names: Tuple[str, ...], input_key: str) -> Tuple[List[Step], str]:
    """Expand an operator sequence into chained Steps feeding output→input; returns (steps, final_key)."""
    steps: List[Step] = []
    prev = input_key
    for i, op in enumerate(op_names):
        nm = out_name if i == len(op_names) - 1 else f"{out_name}__{i}"
        steps.append(Step(nm, op, (prev,)))
        prev = nm
    return steps, prev


@dataclass
class ShapeSchema:
    name: str
    concept_code: str
    slots: Dict[str, Dict[str, Tuple[Tuple[str, ...], str]]]   # slot -> {label: (op_names, phrase)}
    slot_input_types: Dict[str, str]                            # slot -> input type (for the type check)
    setup: Callable                                            # seed -> (env0, params)
    build: Callable                                            # (fill) -> (steps, answer_key)
    stem: Callable                                            # (env, params, phrases) -> str
    distractors: Callable                                     # (env, params, fill) -> list


# ── shape A: value of the k-th derivative of f at the smaller/larger root of g ────────────────────────
_A_SLOTS = {
    "TRANSFORM": {"d1": (("differentiate",), "the first derivative f'(x)"),
                  "d2": (("differentiate", "differentiate"), "the second derivative f''(x)")},
    "REDUCE": {"min": (("min_root",), "smaller"), "max": (("max_root",), "larger")},
}


def _A_setup(seed):
    a = _si(seed + "a", 1, 3); b = _si(seed + "b", -3, 3); c = _si(seed + "c", -4, 4); d = _si(seed + "d", -3, 3)
    r1 = _si(seed + "r1", -3, 1); r2 = r1 + _si(seed + "r2", 1, 4)
    f = sp.expand(a * x ** 3 + b * x ** 2 + c * x + d)
    g = sp.expand((x - r1) * (x - r2))
    return {"f": f, "g": g, "a": a, "b": b, "c": c, "d": d, "r1": r1, "r2": r2}, \
        {"a": a, "b": b, "c": c, "d": d, "r1": r1, "r2": r2}


def _A_build(fill):
    steps = [Step("gr", "real_roots", ("g",))]
    s, pt = chain_steps("pt", _A_SLOTS["REDUCE"][fill["REDUCE"]][0], "gr"); steps += s
    s, ft = chain_steps("ft", _A_SLOTS["TRANSFORM"][fill["TRANSFORM"]][0], "f"); steps += s
    steps.append(Step("ans", "evaluate", (ft, pt)))
    return steps, "ans"


def _A_distr(env, params, fill):
    r1, r2 = params["r1"], params["r2"]
    other = r1 if fill["REDUCE"] == "max" else r2                      # value at the OTHER root
    pt = env["pt"]
    return [env["f"].subs(x, pt),                                      # evaluated f instead of its derivative
            env["ft"].subs(x, other),                                  # right derivative, wrong root
            sp.Integer(0)]


_SCHEMA_A = ShapeSchema(
    "deriv_at_reduced_root", "AUTO_DERIV_AT_REDUCED_ROOT", _A_SLOTS,
    {"TRANSFORM": "POLY", "REDUCE": "ROOTSET"}, _A_setup, _A_build,
    lambda env, p, ph: (f"For f(x) = {_poly_text(env['f'])}, the value of {ph['TRANSFORM']} at the "
                        f"{ph['REDUCE']} root of {_poly_text(env['g'])} = 0 is:"),
    _A_distr,
)


# ── shape B: definite integral of the k-th derivative of f, between the roots of g ────────────────────
_B_SLOTS = {
    "TRANSFORM": {"d1": (("differentiate",), "f'(x)"),
                  "d2": (("differentiate", "differentiate"), "f''(x)")},
}


def _B_setup(seed):
    a = _si(seed + "a", 1, 3); b = _si(seed + "b", -3, 3); c = _si(seed + "c", -4, 4); d = _si(seed + "d", -3, 3)
    r1 = _si(seed + "r1", -3, 1); r2 = r1 + _si(seed + "r2", 1, 4)
    f = sp.expand(a * x ** 3 + b * x ** 2 + c * x + d)
    g = sp.expand((x - r1) * (x - r2))
    return {"f": f, "g": g, "a": a, "b": b, "c": c, "d": d, "r1": r1, "r2": r2}, \
        {"a": a, "b": b, "c": c, "d": d, "r1": r1, "r2": r2}


def _B_build(fill):
    steps = [Step("gr", "real_roots", ("g",)), Step("lo", "min_root", ("gr",)), Step("hi", "max_root", ("gr",))]
    s, ft = chain_steps("ft", _B_SLOTS["TRANSFORM"][fill["TRANSFORM"]][0], "f"); steps += s
    steps.append(Step("val", "integrate_def", (ft, "lo", "hi")))
    return steps, "val"


def _B_distr(env, params, fill):
    r1, r2 = params["r1"], params["r2"]
    ft = env["ft"]
    # fill-agnostic wrong answers (none equals ∫ft, incl. for d1 where ∫f' = f(r2)-f(r1)):
    return [ft.subs(x, r2) - ft.subs(x, r1),                          # evaluated the integrand, didn't integrate
            -env["val"],                                              # sign error / swapped limits
            2 * env["val"],                                           # arithmetic slip
            env["val"] + abs(r2 - r1)]                                # stray additive term


_SCHEMA_B = ShapeSchema(
    "integral_of_deriv_over_roots", "AUTO_INTEGRAL_OF_DERIV_OVER_ROOTS", _B_SLOTS,
    {"TRANSFORM": "POLY"}, _B_setup, _B_build,
    lambda env, p, ph: (f"If f(x) = {_poly_text(env['f'])}, the value of the definite integral of {ph['TRANSFORM']} "
                        f"from the smaller to the larger root of {_poly_text(env['g'])} = 0 is:"),
    _B_distr,
)


SCHEMAS: Dict[str, ShapeSchema] = {s.name: s for s in (_SCHEMA_A, _SCHEMA_B)}


def _valid_fills(schema: ShapeSchema) -> List[dict]:
    """All slot-fill combinations that pass the type check (type-directed admission)."""
    labels = {sl: list(ch.keys()) for sl, ch in schema.slots.items()}
    out = []
    for combo in itertools.product(*labels.values()):
        fill = dict(zip(labels.keys(), combo))
        if all(chain_out_type(schema.slots[sl][fill[sl]][0], schema.slot_input_types[sl]) is not None
               for sl in schema.slots):
            out.append(fill)
    return out


def generate(per_fill: int = 6, seed: str = "AC1") -> List[dict]:
    cands: List[dict] = []
    for name, schema in SCHEMAS.items():
        for fill in _valid_fills(schema):
            steps, answer_key = schema.build(fill)
            for j in range(per_fill):
                s = f"{seed}|{name}|{'|'.join(f'{k}={v}' for k, v in fill.items())}|{j}"
                env0, params = schema.setup(s)
                env, ok = run_pipeline(env0, steps)
                if not ok:                                            # a per-step independent check failed
                    continue
                answer = env[answer_key]
                phrases = {sl: schema.slots[sl][fill[sl]][1] for sl in schema.slots}
                ans_t = _fmt(answer)
                opts = [answer]
                for dval in schema.distractors(env, params, fill):
                    dt = _fmt(dval)
                    if dt == ans_t or dt in {_fmt(o) for o in opts}:
                        continue
                    opts.append(dval)
                    if len(opts) == 4:
                        break
                if len(opts) < 4:
                    continue
                opts_sorted = sorted(opts, key=lambda e: hashlib.sha256((_fmt(e) + s).encode()).hexdigest())
                options = {str(i + 1): _fmt(e) for i, e in enumerate(opts_sorted)}
                depth = reasoning_depth(steps, env0.keys())
                stem = schema.stem(env, params, phrases)
                sig = hashlib.sha256(f"{name}|{stem}".encode()).hexdigest()[:16]
                cands.append({
                    "gen_id": "GENAC_" + sig,
                    "item_model_id": "IMAC_" + hashlib.sha256(f"{schema.concept_code}|{'|'.join(sorted(fill.values()))}".encode()).hexdigest()[:12],
                    "subject": "Mathematics", "profile": "JEE_MAIN", "concept": schema.concept_code,
                    "archetype": "multi_step_numerical", "frame_id": name,
                    "stem": stem, "options": options, "answer_text": ans_t,
                    "reasoning_depth": depth, "depth_band": depth_band(depth),
                    "provenance": {"schema": name, "fill": fill, "reasoning_depth": depth,
                                   "depth_band": depth_band(depth),
                                   "verification": "type_directed + per_step_independent"},
                    "_env0": env0, "_steps": steps, "_answer_key": answer_key, "_answer": answer, "_sig": sig,
                })
    return cands


def verify_auto(cand: dict) -> str:
    """Authoritative re-verification: re-run the pipeline (every step independently checked) and confirm the
    recorded answer/options are untampered. Soundness = all steps verified ⇒ composition correct."""
    env, ok = run_pipeline(cand["_env0"], cand["_steps"])
    if not ok:
        return "disagree"
    true_ans = env[cand["_answer_key"]]
    if _fmt(true_ans) != cand["answer_text"]:
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


def run(per_fill: int = 6, seed: str = "AC1", verify_fn: Callable[[dict], str] = verify_auto) -> dict:
    seen: set = set()
    passed, rejected = [], []
    for cand in generate(per_fill, seed):
        reason = gate(cand, seen)
        clean = {k: v for k, v in cand.items() if not k.startswith("_")}
        if reason:
            rejected.append({**clean, "status": "REJECT", "reason": reason})
            continue
        verdict = verify_fn(cand)
        rec = {**clean, "verification": {"verdict": verdict, "method": "type_directed + per_step_independent"}}
        if verdict == "agree":
            passed.append({**rec, "status": "PASS"})
        else:
            rejected.append({**rec, "status": "REJECT", "reason": "VERIFICATION_DISAGREEMENT"})
    return {"attempted": len(passed) + len(rejected), "passed": len(passed), "rejected": len(rejected),
            "quarantined": 0, "items": passed + rejected, "verified_bank": passed,
            "shapes": sum(len(_valid_fills(s)) for s in SCHEMAS.values())}
