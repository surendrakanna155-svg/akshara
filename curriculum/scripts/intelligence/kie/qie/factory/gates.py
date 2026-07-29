"""Deterministic gate battery for AI-generated question candidates.

WHY THIS MODULE EXISTS (read before changing anything):
The QIE engine's strong gates are REGISTRY-BOUND — they validate a construction QIE itself performed from a row
it already certified (`compositions.verify_composition` literally does `TEMPLATE_REGISTRY[cand["frame_id"]]`).
Hand them a free-form item from an outside model and they have no entry point. Only four QIE gates survive
decoupling: the two string sanitizers, the objective-MCQ structure check, and the sympy dimensional check.

The bridge this module tests: **make the generator emit the STRUCTURE, not just the prose.** A claimed depth is
unfalsifiable; a declared `{givens, relation, solve_for}` is not — sympy can re-execute it, independently, and
either reproduce the generator's answer or refute it. Structure converts a claim into evidence.

So gates split into two classes, and the split is the experiment's actual finding:
  - REUSED   — an existing, frozen QIE gate, imported and called (never edited, never weakened).
  - HARNESS  — new, but only ever *measurement* or the structural re-execution the bridge requires. No harness
               gate is more permissive than a QIE gate it stands in for.

Nothing here relaxes a threshold to raise yield. A low yield is a valid, reportable result.

Deterministic, stdlib + sympy only. Read-only w.r.t. kie.db / qie.db.
"""
from __future__ import annotations

import difflib
import hashlib
import json
import re
import signal
from contextlib import contextmanager
from typing import Dict, List, Optional, Tuple

import sympy
from sympy.parsing.sympy_parser import parse_expr, standard_transformations, implicit_multiplication_application

# ── frozen QIE gates, imported not reimplemented ────────────────────────────────────────────────────
from kie.qpgen.sanitize import stem_quality_ok, is_clean_concept          # G2, G1
from kie.qie.archetypes import classify as qie_classify, ARCHETYPES        # domain-general archetype assigner
from kie.qie.convert.notation.dimensions import check_relation             # G4, real sympy dimensional analysis

_TX = standard_transformations + (implicit_multiplication_application,)

SOLVE_TIMEOUT_S = 5


class _Timeout(Exception):
    pass


@contextmanager
def _time_limit(seconds: int):
    """Bound a sympy call. `sympy.solve` can spin indefinitely on transcendental or high-degree input — one
    pathological item would otherwise stall the whole factory (observed: a single candidate pinned a core and
    hung the batch). A timeout is reported honestly as `solver_failed`, never silently as agreement."""
    def _fire(signum, frame):
        raise _Timeout()
    old = signal.signal(signal.SIGALRM, _fire)
    signal.alarm(seconds)
    try:
        yield
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)

FATAL = "fatal"            # cannot be certified under any adjudication
QUARANTINE = "quarantine"  # a certification EVENT — needs review, never silently promoted
ADVISORY = "advisory"      # measured and reported; does not by itself block


def _as_int(x):
    """Coerce a declared integer-ish value (int, '3', 3.0) to int, or None if it cannot be trusted as one.
    `bool` is rejected (True is not a depth). Used so a self-refuted-metadata gate cannot be skipped by
    declaring the value as a string/float instead of an int."""
    if isinstance(x, bool):
        return None
    try:
        return int(x)
    except (TypeError, ValueError):
        return None


# ── identity / dedup ────────────────────────────────────────────────────────────────────────────────
def item_hash(stem: str, options: Dict[str, str], answer: str) -> str:
    opts = "|".join(f"{k}={v}" for k, v in sorted((options or {}).items()))
    return "IH_" + hashlib.sha256(f"{stem}|{opts}|{answer}".encode()).hexdigest()[:20]


_WS = re.compile(r"\s+")
_NUM = re.compile(r"-?\d+(?:\.\d+)?")
_STOP = {"the", "a", "an", "of", "is", "are", "in", "on", "to", "for", "and", "or", "what", "which",
         "if", "then", "with", "at", "by", "be", "will", "does", "do", "given", "find", "calculate"}


def _norm_stem(stem: str) -> str:
    """Normalized stem for near-duplicate detection: numbers collapsed so that a template re-fired with fresh
    numbers ('m=2kg' vs 'm=7kg') normalizes to the SAME string. This is exactly the template-flooding the
    engine cannot currently see — its four dedup mechanisms are all exact-hash (sha256/set-equality)."""
    s = (stem or "").lower()
    s = _NUM.sub("#", s)
    s = re.sub(r"[^a-z#\s]", " ", s)
    return _WS.sub(" ", s).strip()


def norm_hash(stem: str) -> str:
    return "NH_" + hashlib.sha256(_norm_stem(stem).encode()).hexdigest()[:20]


def _tokens(stem: str) -> set:
    return {w for w in _norm_stem(stem).split() if w not in _STOP and len(w) > 2}


def jaccard(a: str, b: str) -> float:
    ta, tb = _tokens(a), _tokens(b)
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)


def seq_ratio(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, _norm_stem(a), _norm_stem(b)).ratio()


# ── structural re-execution: the bridge ─────────────────────────────────────────────────────────────
def _to_expr(text: str, symbols=()):
    """Parse an expression, binding every DECLARED symbol name to a plain Symbol.

    Without the explicit local_dict, sympy resolves bare names against its own namespace: `N` becomes the
    numeric-evaluation function, `S` the sympify singleton, `E` Euler's number, `Q` the assumptions object,
    `I` the imaginary unit. A physics item using N (number of turns) or Q (charge) would then fail to solve
    for reasons that have nothing to do with the item's correctness — inventing solver failures and
    understating yield. The generator declares its symbols in `givens`, so bind exactly those.
    """
    local = {s: sympy.Symbol(s) for s in symbols if s}
    try:
        return parse_expr(text, transformations=_TX, local_dict=local, evaluate=True)
    except Exception:
        return None


def independent_solve(structure: dict) -> dict:
    """INDEPENDENTLY re-derive the answer from the generator's DECLARED structure — never from its prose and
    never from its stated answer.

    Contract: structure = {givens:{sym:{value,unit}}, relation:"LHS = RHS", solve_for:"sym"}.
    We parse the relation with sympy, substitute EVERY given except the target, solve for the target, and
    return the value. The generator's answer is not an input to this function — that is what makes it
    independent. Agreement is then a comparison, not an assumption.

    A generator that emits a relation which does not actually produce its own stated answer is caught here,
    and it cannot talk its way out: sympy does not read the reasoning.
    """
    givens = (structure or {}).get("givens") or {}
    rel = (structure or {}).get("relation") or ""
    target = (structure or {}).get("solve_for") or ""
    if not rel or not target:
        return {"ok": False, "verdict": "not_applicable", "reason": "no relation/solve_for declared"}
    if "=" not in rel:
        return {"ok": False, "verdict": "solver_failed", "reason": "relation is not an equation"}

    names = set(givens) | {target}
    lhs_s, rhs_s = rel.split("=", 1)
    lhs, rhs = _to_expr(lhs_s.strip(), names), _to_expr(rhs_s.strip(), names)
    if lhs is None or rhs is None:
        return {"ok": False, "verdict": "solver_failed", "reason": "unparseable relation"}
    if not (isinstance(lhs, sympy.Basic) and isinstance(rhs, sympy.Basic)):
        return {"ok": False, "verdict": "solver_failed",
                "reason": "relation side did not parse to an expression (undeclared symbol?)"}

    subs = {}
    for sym, spec in givens.items():
        if sym == target:
            continue
        v = spec.get("value") if isinstance(spec, dict) else spec
        try:
            subs[sympy.Symbol(sym)] = sympy.Float(float(v))
        except Exception:
            return {"ok": False, "verdict": "solver_failed", "reason": f"non-numeric given {sym!r}={v!r}"}

    tsym = sympy.Symbol(target)
    eq = sympy.Eq(lhs.subs(subs), rhs.subs(subs))
    free = eq.free_symbols
    if tsym not in free:
        return {"ok": False, "verdict": "solver_failed",
                "reason": f"target {target!r} absent from the substituted relation"}
    if free - {tsym}:
        return {"ok": False, "verdict": "solver_failed",
                "reason": f"undetermined symbols remain: {sorted(str(s) for s in free - {tsym})}"}
    try:
        with _time_limit(SOLVE_TIMEOUT_S):
            sols = sympy.solve(eq, tsym, dict=False)
    except _Timeout:
        return {"ok": False, "verdict": "solver_failed",
                "reason": f"solve exceeded {SOLVE_TIMEOUT_S}s — not verifiable within budget"}
    except Exception as e:
        return {"ok": False, "verdict": "solver_failed", "reason": f"sympy solve failed: {type(e).__name__}: {e}"}

    real = []
    for s in sols:
        try:
            val = complex(s)
            if abs(val.imag) < 1e-9:
                real.append(float(val.real))
        except Exception:
            continue
    if not real:
        return {"ok": False, "verdict": "no_valid_answer", "reason": "no real solution"}
    # Dedup near-identical roots by SIGNIFICANT FIGURES, never by decimal places. round(v, 9) collapses
    # 5.27e-10 to 1e-09 and 6.626e-34 to 0.0 — it would corrupt every small-magnitude answer in atomic
    # physics and chemistry (wavelengths, Planck constants, molar quantities) and blame the generator for it.
    uniq = sorted({float(f"{v:.9g}") for v in real})
    if len(uniq) > 1:
        return {"ok": False, "verdict": "ambiguous", "reason": f"multiple real solutions: {uniq}",
                "solver_answer": uniq}
    return {"ok": True, "verdict": "solved", "solver_answer": uniq[0]}


# Scientific notation, in every form a generator actually emits. This MUST come before the plain-decimal
# fallback: a naive r"\d+(\.\d+)?" scan reads "3e-06" as 3 and "4.0 x 10^-7" as 4, turning a CORRECT answer
# into a fake disagreement off by 10^6. That bug fired on 3 of the first 5 "disagreements" — the generator was
# right and the comparator was wrong. A validator that misreports correct work is worse than no validator.
_SCI_X10 = re.compile(r"([-+]?\d*\.?\d+)\s*(?:[x×*]\s*10\s*(?:\^|\*\*)\s*([-+]?\d+))")
_SCI_E = re.compile(r"([-+]?\d*\.?\d+)[eE]([-+]?\d+)")
_PLAIN = re.compile(r"[-+]?\d*\.?\d+")


def _num(text) -> Optional[float]:
    """Best-effort numeric value of an answer string, scientific notation included."""
    if text is None:
        return None
    if isinstance(text, (int, float)):
        return float(text)
    s = str(text).replace(",", "").strip()
    for pat in (_SCI_X10, _SCI_E):
        m = pat.search(s)
        if m:
            try:
                return float(m.group(1)) * (10.0 ** int(m.group(2)))
            except Exception:
                pass
    m = _PLAIN.search(s)
    return float(m.group()) if m else None


def answers_agree(solver_val: float, generator_answer, rel_tol: float = 0.02) -> Tuple[bool, str]:
    """Compare on VALUE, with a tolerance that accepts honest rounding but not a different answer."""
    g = _num(generator_answer)
    if g is None:
        return False, "generator answer carries no comparable number"
    if solver_val == 0:
        return (abs(g) < 1e-9), f"solver=0 vs generator={g}"
    rel = abs(g - solver_val) / abs(solver_val)
    return rel <= rel_tol, f"solver={solver_val:.6g} generator={g:.6g} rel_err={rel:.4g}"


def structure_depth(structure: dict) -> Optional[int]:
    """Reasoning depth EARNED from the declared step DAG — the longest dependency chain from givens to result.

    Mirrors kie.qie.compose.reasoning_depth (which needs a Step pipeline we cannot build from foreign input).
    Honest only because `independent_solve`/`replay_steps` must ALSO reproduce the answer from this same
    structure — a DAG padded to inflate depth stops computing the right answer and dies at the solve gate.
    Depth from an unexecuted DAG would be just another claim.
    """
    steps = (structure or {}).get("steps")
    if not steps:
        rel = (structure or {}).get("relation")
        return 1 if rel else None
    depth = {k: 0 for k in ((structure or {}).get("givens") or {})}
    last = 0
    for st in steps:
        out = st.get("out")
        ins = st.get("inputs") or []
        if not out:
            return None
        d = 1 + max((depth.get(i, 0) for i in ins), default=0)
        depth[out] = d
        last = max(last, d)
    return last


def replay_steps(structure: dict) -> dict:
    """EXECUTE the declared step DAG forward with sympy and EARN the reasoning depth (R2-4).

    Returns {"ok": bool, "depth": int|None, "final": float|None, "reason": str}. This is the multi-step
    counterpart to `independent_solve` (which checks a single relation): it topologically executes each step,
    feeding one step's output into the next, and the depth it reports is the length of the longest chain that
    ACTUALLY RAN — not a walk over an unexecuted DAG (that is `structure_depth`, which a padded DAG can inflate).

    The rule that makes the number honest: a step is only counted if sympy solves it from inputs already in the
    environment; a flat DAG whose steps all read givens reproduces the answer in ONE applied step (earned
    depth 1) — which is exactly why the production run's claimed 2–5 was refuted. A step that cannot be solved,
    an unresolvable/cyclic dependency, or a chain that fails to terminate ⇒ ok=False (fail-safe, like
    compose.run_pipeline), depth unearned. The caller (run_gates) additionally checks that `final` reproduces
    the item's keyed answer — replay and independent_solve cannot disagree without one failing.
    """
    structure = structure or {}
    steps = structure.get("steps") or []
    givens = structure.get("givens") or {}
    target = structure.get("solve_for") or ""

    # seed the environment with every NUMERIC given (the unknown/target is excluded — it is what we compute)
    env: Dict[str, float] = {}
    for sym, spec in givens.items():
        if sym == target:
            continue
        val = spec.get("value") if isinstance(spec, dict) else spec
        if val is None:
            continue
        try:
            env[sym] = float(val)
        except Exception:
            continue

    if not steps:
        # no DAG: a single-relation item is one applied step. Depth is 1 iff the relation actually solves.
        rel = structure.get("relation") or ""
        if not rel:
            return {"ok": False, "depth": None, "final": None, "reason": "no steps and no relation to execute"}
        res = independent_solve(structure)
        if res.get("verdict") != "solved":
            return {"ok": False, "depth": None, "final": None,
                    "reason": f"single relation did not solve: {res.get('reason', res.get('verdict'))}"}
        return {"ok": True, "depth": 1, "final": res.get("solver_answer"), "reason": "single applied relation"}

    depth = {k: 0 for k in env}                 # every seeded given sits at depth 0
    pending = list(steps)
    max_passes = len(steps) + 1                 # each pass must resolve >=1 step or we are stuck (cycle)
    for _ in range(max_passes):
        if not pending:
            break
        still, progressed = [], False
        for st in pending:
            out = st.get("out")
            ins = st.get("inputs") or []
            if not out:
                return {"ok": False, "depth": None, "final": None, "reason": "a step is missing its 'out'"}
            if any(i not in env for i in ins):
                still.append(st)                # inputs not ready yet — defer to a later pass
                continue
            rel = st.get("relation") or ""
            solve_for = st.get("solve_for") or out
            probe = {"givens": {i: {"value": env[i]} for i in ins}, "relation": rel, "solve_for": solve_for}
            res = independent_solve(probe)
            if res.get("verdict") != "solved":
                return {"ok": False, "depth": None, "final": None,
                        "reason": f"step out={out!r} did not solve: {res.get('reason', res.get('verdict'))}"}
            env[out] = res["solver_answer"]
            depth[out] = 1 + max((depth.get(i, 0) for i in ins), default=0)
            progressed = True
        pending = still
        if not progressed and pending:
            return {"ok": False, "depth": None, "final": None,
                    "reason": f"unresolvable steps (inputs never produced): {[s.get('out') for s in pending]}"}
    if pending:
        return {"ok": False, "depth": None, "final": None, "reason": "cyclic step dependencies"}

    # terminal = the step producing the declared target; else the deepest produced output
    if target and target in env:
        term = target
    elif depth:
        term = max((k for k in depth if k not in givens or k in env), key=lambda k: depth[k], default=None)
    else:
        term = None
    if term is None or term not in env:
        return {"ok": False, "depth": None, "final": None, "reason": "DAG produced no terminal value"}
    return {"ok": True, "depth": depth.get(term, 0), "final": env[term], "reason": "executed DAG forward"}


def verify_distractors(structure: dict, options: dict, answer_label: str, distractor_rationale: dict,
                       uncertifiable=None) -> dict:
    """Deterministically PROVE each wrong option is what a specific student MISTAKE actually computes (R2-2).

    Contract: for every wrong label L, `distractor_rationale[L]` declares a `mis_relation` — the wrong equation a
    misconception produces (e.g. 'a = m/F' instead of 'a = F/m'). We build a probe from the item's givens + that
    mis_relation, solve it with `independent_solve`, and require the computed value to EQUAL the option (value
    compare, sci-notation aware). A distractor is verified ONLY when the named error reproduces that exact
    number — proof it is a real trap, not a plausible-looking decoy. An option may instead be listed in
    `uncertifiable` (the honest escape: no nameable mechanical error) and is then not required to compute.

    Returns {"ok", "verified":[...], "unverified":[{label, reason}], "uncertifiable":[...], "detail"}. ok is
    True only when EVERY wrong option is either verified or explicitly uncertifiable — no silent gaps.
    """
    options = options or {}
    distractor_rationale = distractor_rationale or {}
    uncert = set(uncertifiable or [])
    givens = (structure or {}).get("givens") or {}
    solve_for = (structure or {}).get("solve_for") or ""
    wrong = [L for L in options if L != answer_label]

    verified, unverified = [], []
    for L in wrong:
        if L in uncert:
            continue
        spec = distractor_rationale.get(L)
        mis_rel = (spec or {}).get("mis_relation") if isinstance(spec, dict) else None
        if not mis_rel:
            unverified.append({"label": L, "reason": "no mis_relation declared and not listed uncertifiable"})
            continue
        # probe = item givens (target excluded) + the misconception's wrong relation, solved for the same target
        probe_givens = {s: v for s, v in givens.items() if s != solve_for}
        probe = {"givens": probe_givens, "relation": mis_rel, "solve_for": solve_for}
        res = independent_solve(probe)
        if res.get("verdict") != "solved":
            unverified.append({"label": L, "reason": f"mis_relation did not solve: "
                                                     f"{res.get('reason', res.get('verdict'))}"})
            continue
        agree, why = answers_agree(res["solver_answer"], options.get(L))
        if agree:
            verified.append(L)
        else:
            unverified.append({"label": L, "reason": f"mis_relation computes {res['solver_answer']!r}, "
                                                     f"not the option: {why}"})
    ok = not unverified
    if wrong:
        # 'uncertifiable' is an escape for a distractor with no nameable mechanical error — but it must stay a
        # MINORITY. If every wrong option hides behind it (or fewer than half are positively proven), the gate
        # is vacuous: zero traps proven yet ok=True. (adversarial-verifier fix — all-uncertifiable must NOT pass.)
        ok = ok and len(verified) >= 1 and (len(verified) * 2 >= len(wrong))
    return {"ok": ok, "verified": verified, "unverified": unverified, "uncertifiable": sorted(uncert),
            "detail": (f"verified={verified} uncertifiable={sorted(uncert)} unverified={unverified} "
                       f"(need >=1 proven and a proven majority of {len(wrong)} wrong options)")}


# ── unit normalization for the DIMENSIONAL gate ─────────────────────────────────────────────────────
# The frozen QIE gate `notation.dimensions.parse_unit` cannot parse ANY SI-prefixed unit — cm, mm, km,
# nm, kPa, mL, min, h, deg all return None ("unparseable"). That never mattered for the 41 certified
# relations, which were transcribed from NCERT summary pages in base units (J, kg, m, N). Real school
# questions use cm and kPa constantly, so the gate false-quarantined 107 items whose answers sympy had
# already independently CONFIRMED.
#
# This maps a prefixed unit to its base unit FOR THE DIMENSIONAL CHECK ONLY. That is not a weakened
# gate: a dimensional check asks "is this a length?", and cm and m are both lengths — the magnitude is
# irrelevant to it and is never touched here. The numeric solve always uses the raw declared values.
# The underlying engine defect is reported, not patched around silently.
_UNIT_BASE = {
    "cm": "m", "mm": "m", "km": "m", "nm": "m", "um": "m", "µm": "m", "pm": "m",
    "g": "g", "mg": "g", "kg": "kg", "t": "kg",
    "ms": "s", "min": "s", "h": "s", "hr": "s", "day": "s",
    "kpa": "Pa", "mpa": "Pa", "hpa": "Pa", "bar": "Pa", "atm": "Pa",
    "ml": "L", "cl": "L", "dl": "L", "cc": "L",
    "kj": "J", "mj": "J", "ev": "J", "cal": "J", "kcal": "J",
    "mn": "N", "kn": "N",
    "mv": "V", "kv": "V", "mA": "A", "ma": "A", "ka": "A",
    "uf": "F", "nf": "F", "pf": "F", "mf": "F",
    "kohm": "ohm", "mohm": "ohm",
    "kmol": "mol", "mmol": "mol",
    "kw": "W", "mw": "W",
    # R4-3 dimensional-gate yield recovery — the three false-reject classes the audit named. All three are
    # genuinely DIMENSIONLESS in SI, so mapping them to "1" is dimensionally CORRECT (not a weakened gate — a
    # count/ratio/angle has no base dimension); the raw magnitude is untouched and the numeric solve is unaffected.
    #  * ANGLE: radian & degree are dimensionless (a ratio of arc/radius). The frozen gate cannot parse "rad"
    #    at all (deg->rad still hit an unparseable "rad" -> false quarantine), so angle items were killed outright.
    "rad": "1", "radian": "1", "radians": "1", "deg": "1", "degree": "1", "degrees": "1",
    "sr": "1", "steradian": "1",
    #  * PERCENTAGE / ratio: a percentage is a pure dimensionless ratio ("20% of 1600 L").
    "%": "1", "percent": "1", "pct": "1", "ratio": "1", "fraction": "1",
    #  * COUNT: beats, revolutions, cycles, moles-as-count are pure counts (e.g. "72 beats/min -> per day" is a
    #    dimensionless count per time). Frequency stays consistent: cycles/s reduces to 1/s == Hz.
    "beat": "1", "beats": "1", "count": "1", "counts": "1", "rev": "1", "revolution": "1", "revolutions": "1",
    "cycle": "1", "cycles": "1", "turn": "1", "turns": "1", "rpm_count": "1",
    #  * CURRENCY (W10 repair, 2026-07-29): money carries no SI base dimension, so it reduces to "1" exactly
    #    as a count or a ratio does. Before this, `normalize_unit("Rs")` returned "Rs", `parse_unit` could
    #    not read it, and `check_relation` reported "unparseable LHS unit" -> QUARANTINE. The effect was that
    #    COMMERCIAL MATHEMATICS — simple interest (Class 7) and compound interest (Class 8), both core
    #    syllabus — could not be certified by any lane at all: 6 of 42 Lane C items were blocked solely here.
    #
    #    What this DOES check, and what it does not, stated plainly. It verifies that the two sides of a
    #    money relation reduce to the same dimension, so `A = P*(1+R/100)**n` (money = money x dimensionless)
    #    passes while `I = P * s` with s in metres now FAILS as money-vs-length, which it could not do before
    #    (an unparseable unit was never compared to anything). What it cannot do is distinguish rupees from a
    #    bare ratio, because neither has an SI dimension — the same limitation the already-ratified "%",
    #    "ratio" and "count" mappings above carry. This is a strictly larger set of checks than the status
    #    quo of refusing to check at all.
    "rs": "1", "inr": "1", "rupee": "1", "rupees": "1", "₹": "1", "usd": "1", "paise": "1",
}


def normalize_unit(u: str) -> str:
    """Map an SI-prefixed unit to a base unit the frozen dimensional gate can actually parse."""
    if not u:
        return u
    s = str(u).strip()
    base = _UNIT_BASE.get(s.lower())
    if base:
        return base
    # compound units: normalize each alphabetic run, leave operators/exponents intact
    def _tok(m):
        return _UNIT_BASE.get(m.group(0).lower(), m.group(0))
    return re.sub(r"[A-Za-zµ]+", _tok, s)


# ── curriculum-boundary token derivation (R3-7a) ──────────────────────────────────────────────────────
# The certified generation_spec's forbidden_terms fold in each concept's evidenced boundary.out_of_scope,
# which is frequently SENTENCE-LENGTH ("this class does not treat the derivation of ...") and so can NEVER
# word-boundary-match a stem — the old gate "checked" a term it could not possibly hit, then passed the item
# as if the boundary held (15/22 certified items had EMPTY forbidden_terms => "checked 0" => a vacuous pass).
# R3-7(a): derive SHORT lexical technique tokens (lone tokens + short verbatim phrases + tight adjacent
# content bigrams) from that evidence, augment with a small list of techniques above the whole school/
# competitive ceiling, and — per the standing law — treat a boundary gate that had NOTHING curriculum-
# evidenced to check as an ADVISORY FAILURE (surfaced, non-blocking), never a silent pass. A real above-class
# hit stays BLOCKING (QUARANTINE), exactly as before.

# Genuinely above the NCERT 6-12 + JEE/NEET ceiling: undergraduate+ techniques that are out of scope for ANY
# school/competitive item regardless of class, so they are safe to scan unconditionally (they can never false-
# hit a legitimate class-11/12 stem). Distinctive tokens only — no everyday English word that could cry wolf.
_ABOVE_CEILING_TECHNIQUES = (
    "contour integration", "residue theorem", "residue calculus", "cauchy's theorem",
    "fourier transform", "fourier series", "laplace transform", "z-transform",
    "eigenvalue", "eigenvector", "eigenfunction", "tensor", "jacobian", "wronskian",
    "lagrangian", "hamiltonian", "schrodinger equation", "partial differential equation",
    "navier-stokes", "green's function", "gamma function", "beta function", "taylor series expansion",
)

# stopwords + generic academic filler stripped before deriving technique tokens from a boundary sentence, so
# a distinctive bigram like "polynomial division" survives but "these applications" / "the concept" do not.
_BND_STOP = {
    "the", "a", "an", "of", "to", "in", "on", "at", "is", "are", "be", "and", "or", "for", "with", "by",
    "that", "this", "it", "as", "from", "its", "their", "than", "not", "no", "if", "but", "any", "all",
    "which", "into", "such", "does", "do", "only", "also", "level", "class", "here", "these", "those",
    "covered", "cover", "include", "included", "including", "involving", "involve", "beyond", "using", "use",
    "used", "application", "applications", "concept", "concepts", "topic", "topics", "problem", "problems",
    "general", "simple", "complex", "basic", "advanced", "standard", "detailed", "detail", "student",
    "students", "require", "requires", "required", "treatment", "derivation", "study", "studied", "example",
    "examples", "case", "cases", "form", "forms", "type", "types", "given", "value", "values", "out", "scope",
}


def _claim_clause(term: str) -> str:
    """The part of a boundary record that states WHAT is excluded, dropping the rationale saying WHY.

    W7 REPAIR (2026-07-29). The certified index writes exclusions as `<claim> - <rationale>`:

        "non-uniform (variable) acceleration - these equations are derived for uniformly accelerated
         motion only, and the average-velocity form (v0 + v)/2 is flagged in the evidence as holding
         for constant acceleration only"

    Deriving adjacent-content bigrams from the WHOLE record yields eleven labels, most of them fragments
    of the explanation — `flagged evidence`, `evidence holding`, `holding constant`, `confines itself` —
    and, fatally, `constant acceleration`, which the SAME certified record lists IN scope as "rectilinear
    motion with UNIFORM (constant) acceleration". A Class-11 kinematics item was quarantined for containing
    the phrase its own concept record declares in scope.

    This makes the gate STRICTLY MORE PRECISE, never more permissive: an above-class technique is named in
    the claim ("non-uniform (variable) acceleration", "motion in two or three dimensions"), which is still
    derived and still checked. Only the prose ABOUT the exclusion stops generating tokens. A record with no
    separator is returned unchanged, so single-phrase boundaries behave exactly as before.
    """
    s = re.sub(r"\s+", " ", str(term or "").strip())
    for sep in (" - ", " — ", " – ", ": "):
        if sep in s:
            head = s.split(sep, 1)[0].strip()
            if len(head) >= 8:              # a real claim, not a stray fragment or a numbered prefix
                return head
    return s


def _boundary_checks(banned: List[str], concept_name="") -> Tuple[List[tuple], List[tuple]]:
    """(evidenced, baseline) -> two lists of (compiled_regex, label).

    `evidenced` are checks derived from THIS spec's own curriculum-boundary evidence (forbidden_terms /
    out_of_scope); `baseline` are the unconditional above-ceiling technique checks. A hit on EITHER is an
    above-class breach. An EMPTY `evidenced` list is the "checked 0" case — the boundary rests on nothing
    concept-specific — which the gate surfaces as an advisory failure.

    NO CRYING WOLF (adversarial-verifier fix): a concept's own `out_of_scope` sentence usually restates the
    concept's name (e.g. "advanced properties of inverse trigonometric functions are out of scope"), so a
    naive bigram derives `inverse trigonometric` — the concept's OWN in-scope topic — and would then quarantine
    a legitimate in-scope item. A derived token whose EVERY content word is part of `concept_name` is the topic
    itself, not a boundary; it is dropped. (An above-class TERM can never consist solely of the concept's own
    words, so this cannot open a leak.)"""
    # `concept_name` accepts a single title OR an iterable of titles. A MULTI-CONCEPT item (the depth tier)
    # combines several certified concepts, and each one's topic words must be protected from the
    # "no crying wolf" rule below — otherwise a two-concept item is quarantined for naming its own second
    # concept, which is what happened to the Class-11 kinematics -> kinetic-energy chain.
    _titles = [concept_name] if isinstance(concept_name, str) else list(concept_name or [])
    concept_words = {w for t in _titles
                     for w in re.findall(r"[a-z][a-z\-]*", (t or "").lower())
                     if len(w) >= 4 and w not in _BND_STOP}

    def _is_concept_self(label: str) -> bool:
        toks = [w for w in re.findall(r"[a-z][a-z\-]*", label.lower()) if len(w) >= 4 and w not in _BND_STOP]
        return bool(toks) and all(w in concept_words for w in toks)

    def _mk(label: str):
        label = re.sub(r"\s+", " ", (label or "").strip().lower())
        if len(label) < 4:
            return None
        return (re.compile(rf"\b{re.escape(label)}\b", re.I), label)

    baseline: List[tuple] = []
    seen: set = set()
    for tech in _ABOVE_CEILING_TECHNIQUES:
        c = _mk(tech)
        if c and c[1] not in seen:
            seen.add(c[1])
            baseline.append(c)

    evidenced: List[tuple] = []
    seen_e: set = set()

    def _add_ev(label: str):
        c = _mk(label)
        if c and c[1] not in seen and c[1] not in seen_e and not _is_concept_self(c[1]):
            seen_e.add(c[1])
            evidenced.append(c)

    for term in banned or []:
        # W7: derive from the EXCLUSION CLAIM, not from the prose explaining it (see _claim_clause)
        t = _claim_clause(term)
        if not t:
            continue
        words = re.findall(r"[a-z][a-z\-]*", t.lower())
        if not words:
            continue
        if len(words) == 1:
            _add_ev(words[0])                       # a lone technique token authored as out-of-scope ("calculus")
            continue
        if len(words) <= 4:
            _add_ev(t)                              # a short technique phrase, matched verbatim as before
        # distinctive adjacent-content bigrams recovered from a long sentence (low false-positive: two
        # adjacent domain words). Generic single words are NOT derived — they would cry wolf on in-scope stems.
        content = [w for w in words if w not in _BND_STOP and len(w) >= 4]
        for a, b in zip(content, content[1:]):
            _add_ev(f"{a} {b}")
    return evidenced, baseline


# ── the gate battery ────────────────────────────────────────────────────────────────────────────────
# ANSWER FORMATS. Until now every item was a 4-option single-correct MCQ, and both the schema gate and
# `option_structure` hard-coded that shape. Two examined formats do not fit it, and neither could be
# generated at all:
#
#   integer        JEE Main sets 5 of 25 questions per subject as numerical-entry: the candidate types a
#                  value and there are NO options. `option_structure` FATAL-failed such an item for having
#                  zero options, which is the correct behaviour for an MCQ and wrong for this format.
#   multi_correct  JEE Advanced's core format: four options of which TWO OR MORE are correct. A single
#                  `answer_label` cannot express the key.
#
# The format is declared per item and each gate branches on it. `single_correct` is the default, so every
# existing caller and every existing item behaves exactly as before.
SINGLE_CORRECT = "single_correct"
INTEGER_ENTRY = "integer"
MULTI_CORRECT = "multi_correct"
ANSWER_FORMATS = (SINGLE_CORRECT, INTEGER_ENTRY, MULTI_CORRECT)

_REQUIRED_BY_FORMAT = {
    SINGLE_CORRECT: ("stem", "options", "answer_label", "claimed"),
    # an integer item carries a numeric key and a declared tolerance instead of options
    INTEGER_ENTRY: ("stem", "answer_value", "claimed"),
    # a multi-correct item carries a SET of correct labels
    MULTI_CORRECT: ("stem", "options", "answer_labels", "claimed"),
}
_REQUIRED = _REQUIRED_BY_FORMAT[SINGLE_CORRECT]      # retained: existing callers import this name


def answer_format_of(cand: dict) -> str:
    fmt = (cand or {}).get("answer_format") or SINGLE_CORRECT
    return fmt if fmt in ANSWER_FORMATS else SINGLE_CORRECT


def run_gates(cand: dict, ctx: dict, stage: str = "candidate") -> List[dict]:
    """Run every applicable gate. Returns [{gate, ok, severity, detail}].

    `stage` controls which gates apply, because the pipeline is two-phase by design:
      "candidate" — compact items (no solution yet). Solution gates are NOT run: an item cannot fail for
                    lacking a thing it was never asked to produce. Everything else applies, so the expensive
                    solution stage is only ever spent on items that already survived.
      "solution"  — the same item once a solution has been constructed; adds the solution gates.

    ctx supplies corpus-level and evidence-level context:
      seen_norm: {norm_hash: candidate_id}     — exact template-collision
      corpus:    [(candidate_id, stem)]        — for near-duplicate scan (scoped by caller)
      certified_relations: {normalized_eq: name}
      spec:      the generation_spec row this candidate was supposed to satisfy
    """
    out: List[dict] = []

    def add(gate, ok, severity, detail=""):
        out.append({"gate": gate, "ok": bool(ok), "severity": severity,
                    "detail": detail if isinstance(detail, str) else json.dumps(detail, default=str)})

    spec = ctx.get("spec") or {}
    claimed = cand.get("claimed") or {}

    # ── 1. SCHEMA (HARNESS, domain-general) — required fields depend on the ANSWER FORMAT ──
    fmt = answer_format_of(cand)
    required = _REQUIRED_BY_FORMAT[fmt]
    missing = [f for f in required if cand.get(f) in (None, "", {}, [])]
    add("schema", not missing, FATAL,
        f"format={fmt} missing: {missing}" if missing else f"format={fmt}: all required fields present")
    if missing:
        return out                                    # nothing downstream is meaningful

    stem = cand["stem"]
    options = cand.get("options") or {}
    ans_label = cand.get("answer_label")

    # ── 2. OPTION STRUCTURE — branches on the declared answer format ──
    viol = []
    if fmt == INTEGER_ENTRY:
        # A numerical-entry item must offer NO options (offering them makes it an MCQ), must carry a
        # comparable numeric key, and must declare the tolerance a marker will apply. An undeclared
        # tolerance is not a detail: it decides whether a candidate's 8.33 scores against a key of 8.333.
        if options:
            viol.append(f"an integer-entry item must have no options, got {len(options)}")
        if _num(cand.get("answer_value")) is None:
            viol.append(f"answer_value {cand.get('answer_value')!r} is not numeric")
        tol = cand.get("answer_tolerance")
        if tol is None or _num(tol) is None or float(tol) < 0:
            viol.append("a numeric answer_tolerance must be declared")
        add("option_structure", not viol, FATAL,
            "; ".join(viol) or f"integer entry, key={cand.get('answer_value')!r} tol={cand.get('answer_tolerance')!r}")
    elif fmt == MULTI_CORRECT:
        labels = cand.get("answer_labels") or []
        if len(options) != 4:
            viol.append(f"expected 4 options, got {len(options)}")
        if any(not str(v).strip() for v in options.values()):
            viol.append("blank option")
        vals = [str(v).strip().lower() for v in options.values()]
        if len(set(vals)) != len(vals):
            viol.append("duplicate options")
        if not isinstance(labels, (list, tuple)) or len(set(labels)) != len(labels):
            viol.append(f"answer_labels must be a set of distinct labels, got {labels!r}")
        elif not (2 <= len(labels) <= 3):
            # 1 correct is a single-correct item wearing the wrong format; 4 correct makes every option
            # right and tests nothing. JEE Advanced uses two or three.
            viol.append(f"a multi-correct item needs 2 or 3 correct options, got {len(labels)}")
        elif any(l not in options for l in labels):
            viol.append(f"answer_labels {sorted(labels)} not all among options {sorted(options)}")
        add("option_structure", not viol, FATAL,
            "; ".join(viol) or f"4 distinct options, {len(labels)} correct")
    else:
        if len(options) != 4:
            viol.append(f"expected 4 options, got {len(options)}")
        if any(not str(v).strip() for v in options.values()):
            viol.append("blank option")
        vals = [str(v).strip().lower() for v in options.values()]
        if len(set(vals)) != len(vals):
            viol.append("duplicate options")
        if ans_label not in options:
            viol.append(f"answer_label {ans_label!r} not among options {sorted(options)}")
        add("option_structure", not viol, FATAL, "; ".join(viol) or "4 distinct options, answer resolves")

    # ── 3. STEM PROSE QUALITY (REUSED — kie.qpgen.sanitize.stem_quality_ok) ──
    add("stem_quality", stem_quality_ok(stem), FATAL, "qpgen.sanitize.stem_quality_ok")

    # ── 4. CONCEPT TITLE CLEANLINESS (REUSED — G1; applied to the CONCEPT, never to prose) ──
    # NOTE: is_clean_concept is the TITLE sanitizer. Applying it to stems/options rejects real science
    # (Acetyl CoA, mRNA, pH) — a known, previously-fixed defect. Titles only.
    for c in (claimed.get("concepts") or [])[:4]:
        add(f"concept_title_clean", is_clean_concept(c), ADVISORY, f"concept={c!r}")
        break

    # ── 5. ARCHETYPE AGREEMENT (REUSED — kie.qie.archetypes.classify) ──
    # The classifier ASSIGNS from surface markers; it cannot refute a claim outright. Treat a mismatch as
    # ADVISORY signal, not a fatal verdict — its default (factual_single_best_answer) is a catch-all.
    claimed_arch = claimed.get("archetype")
    is_numeric = bool((cand.get("structure") or {}).get("relation"))
    detected = qie_classify(stem, is_numeric=is_numeric, relation_verified=False)
    add("archetype_known", claimed_arch in ARCHETYPES, FATAL, f"claimed={claimed_arch!r}")
    add("archetype_agreement", claimed_arch == detected, ADVISORY,
        f"claimed={claimed_arch!r} qie_detected={detected!r}")

    # ── 6. DUPLICATE / NEAR-DUPLICATE (HARNESS — the engine has NO near-dup detection; all four of its
    #      mechanisms are exact-hash, so template flooding is currently invisible to it) ──
    nh = norm_hash(stem)
    dup_of = (ctx.get("seen_norm") or {}).get(nh)
    add("duplicate_exact", dup_of is None, FATAL, f"template-identical to {dup_of}" if dup_of else "unique")

    worst, worst_id = 0.0, None
    for cid, other in (ctx.get("corpus") or []):
        j = jaccard(stem, other)
        if j > worst:
            worst, worst_id = j, cid
    near = worst >= 0.85 and seq_ratio(stem, dict(ctx.get("corpus") or {}).get(worst_id, "")) >= 0.85 \
        if worst_id else False
    add("near_duplicate", not near, QUARANTINE,
        f"max_jaccard={worst:.3f} vs {worst_id}" if worst_id else "no corpus neighbour")

    # ── 7. CURRICULUM BOUNDARY (HARNESS; R3-7a — the vacuous-gate + un-matchable-sentence fix) ──
    # Derive short lexical technique tokens from the spec's own out-of-scope evidence (so a sentence-length
    # boundary term still yields matchable tokens) and scan a small above-ceiling technique list. A real
    # above-class hit is BLOCKING (QUARANTINE) as before; a boundary that had NOTHING curriculum-evidenced to
    # check is an ADVISORY FAILURE (a gate that checked nothing is not a pass), never a silent clearance.
    banned = ((spec.get("boundary") and json.loads(spec["boundary"])) or {}).get("forbidden_terms") or []
    # The spec's authoritative in-scope concept(s) — used to drop derived tokens that are a concept's own
    # topic. `concept_titles` (W7) carries EVERY concept of a multi-concept item; without it a depth-tier
    # question is quarantined for naming its own second concept. Falls back to the single title.
    _concept_names = spec.get("concept_titles") or [spec.get("concept_title") or spec.get("concept_code") or ""]
    if isinstance(_concept_names, str):
        _concept_names = json.loads(_concept_names) if _concept_names.startswith("[") else [_concept_names]
    ev_checks, base_checks = _boundary_checks(banned, _concept_names)
    hits = sorted({lbl for rx, lbl in (ev_checks + base_checks) if rx.search(stem)})
    if hits:
        add("curriculum_boundary", False, QUARANTINE, f"above-class terms present: {hits}")
    elif not ev_checks:
        add("curriculum_boundary", False, ADVISORY,
            f"checked 0 curriculum-evidenced forbidden terms — boundary NOT verified for this concept "
            f"(only {len(base_checks)} above-ceiling techniques scanned)")
    else:
        add("curriculum_boundary", True, QUARANTINE,
            f"no above-class term (checked {len(ev_checks)} evidenced + {len(base_checks)} baseline)")

    # ── 8..10 the bridge that makes numeric claims falsifiable ──
    # SECURITY (R1-1 hardening — closes the qualitative-lane bypass the adversarial verifier found):
    # the truth gates key on the PRESENCE OF A CHECKABLE STRUCTURE, NOT on spec.lane. independent_solve
    # (which yields the 'agree' that enables certification) is lane-agnostic, so ANY item it can 'agree' on
    # MUST also be grounded here — otherwise a wrong-but-consistent numeric item (e.g. K=m*v**2) routed
    # under a QUALITATIVE spec would certify unchecked. Only `structure_present` stays lane-specific: a
    # genuine qualitative item legitimately declares no structure and must not be FATAL-failed for it.
    structure = cand.get("structure") or {}
    rel = structure.get("relation") or ""
    if spec.get("lane") == "STRUCTURED_NUMERIC":
        add("structure_present", bool(rel and structure.get("solve_for") and structure.get("givens")),
            FATAL, "declared {givens, relation, solve_for} required for the structured lane")

    if rel and structure.get("givens"):
        # 8. DIMENSIONAL (REUSED — kie...notation.dimensions.check_relation, real sympy SI analysis)
        units = {s: normalize_unit(v.get("unit") or "") for s, v in (structure.get("givens") or {}).items()
                 if isinstance(v, dict)}
        tgt = structure.get("solve_for")
        tgt_unit = normalize_unit((structure.get("givens", {}).get(tgt) or {}).get("unit")
                                  or structure.get("answer_unit") or "")
        if tgt_unit and "=" in rel and all(units.get(s) for s in units):
            rhs = rel.split("=", 1)[1].strip()
            try:
                dim = check_relation(tgt_unit, rhs, {k: v for k, v in units.items() if k != tgt})
                add("dimensional", dim.get("ok"), QUARANTINE, dim.get("reason") or dim)
            except Exception as e:
                # a dimensional check that ERRORED is not a pass. Unverifiable => quarantine, never advisory.
                add("dimensional", False, QUARANTINE, f"dimensional check errored: {e}")
        else:
            # "not checkable" is no longer a free pass (R1-1). A numeric item must declare complete units;
            # an unverifiable dimension is a quarantine event, not a silent advisory.
            add("dimensional", False, QUARANTINE,
                "not checkable: incomplete/missing unit declaration — a numeric item must declare units")

        # 9. RELATION GROUNDING — BLOCKING (R1-1). Is this relation one QIE already CERTIFIED (order-swaps
        #    and algebraic rearrangements allowed via sympy equivalence), or is the model inventing physics?
        #    An ungrounded relation CANNOT certify; the ONLY escape is an explicit, owner-recorded waiver on
        #    the row. "advisory" is not a valid severity for factual grounding.
        certified = ctx.get("certified_relations") or {}
        cert_eqs = ctx.get("certified_relation_eqs") or []
        grounded, match = is_relation_grounded(rel, structure, spec, certified, cert_eqs)
        waiver = ctx.get("relation_waiver")
        if grounded:
            add("relation_grounded", True, QUARANTINE, f"matches certified {match!r}")
        elif waiver and _valid_waiver(waiver):
            add("relation_grounded", True, QUARANTINE,
                f"UNGROUNDED relation WAIVED by {waiver.get('waived_by')!r}: "
                f"{str(waiver.get('reason', ''))[:120]}")
        else:
            add("relation_grounded", False, QUARANTINE,
                f"relation not in governed_relation registry ({_relation_count(certified)} certified)")

        # 9b. STEM ↔ STRUCTURE BINDING — bind the prose a student reads to what sympy solved (R1-1):
        #     every declared given value must appear in the stem, and every stem quantity must be a
        #     declared given (constants + grammatical counts allowlisted so it does not cry wolf).
        _stem_binding_gate(add, stem, structure)

        # 9c. EXAM-NOVELTY (R2-5, ADVISORY): a stem that PRINTS its own method — the declared formula, or a
        #     "using the formula…" lead-in — is a solved example / plug-in drill, not an exam-novel item. It can
        #     still be a correct PRACTICE item, so this never blocks certification; it labels the item
        #     practice-tier (not exam-novel) so difficulty/novelty are surfaced honestly.
        _method_leak_gate(add, stem, structure)

    # 10. DEPTH EARNED BY EXECUTING THE DAG (R2-4) — no longer a walk over an unexecuted DAG. replay_steps runs
    #     each step through sympy and reports the length of the longest chain that ACTUALLY ran; run_gates then
    #     checks the executed chain reproduces the keyed answer. depth_agreement is now BLOCKING (QUARANTINE):
    #     a self-refuted depth (claimed != earned, or the replay did not reproduce the answer) may not ship.
    if rel or structure.get("steps"):
        rep = replay_steps(structure)
        earned = rep.get("depth")
        claimed_d = claimed.get("depth")
        keyed = options.get(ans_label) if ans_label in options else cand.get("answer_value")
        ans_num = _num(keyed)
        if rep["ok"] and rep.get("final") is not None and ans_num is not None:
            reproduced, why = answers_agree(rep["final"], keyed)
        elif rep["ok"] and rep.get("final") is not None:
            reproduced, why = True, "executed but no comparable keyed number"
        else:
            reproduced, why = False, rep.get("reason", "replay did not execute")
        add("depth_computable", rep["ok"], ADVISORY,
            f"earned_depth={earned} replay_ok={rep['ok']} reproduced_answer={reproduced} :: {rep.get('reason')}")
        # A claimed depth is checked regardless of its declared TYPE (adversarial-verifier fix — a string "1"
        # or float must not skip the BLOCKING gate). A present-but-uncoercible claim (garbage) fails closed.
        if claimed_d is not None:
            claimed_i = _as_int(claimed_d)
            add("depth_agreement",
                bool(rep["ok"] and reproduced and claimed_i is not None and earned == claimed_i), QUARANTINE,
                f"claimed={claimed_d!r} coerced={claimed_i} earned_replay_depth={earned} replay_ok={rep['ok']} "
                f"reproduced_answer={reproduced} ({why})")

    # ── 11. COMPOSITION HONESTY (HARNESS) — a 'multi' claim must be backed by MORE THAN two terms
    #      appearing in the text. We test the structure, not the vocabulary.
    if claimed.get("composition") == "multi":
        concepts = claimed.get("concepts") or []
        steps = structure.get("steps") or []
        distinct_rel = {s.get("relation") for s in steps if s.get("relation")}
        # a 'multi' claim is backed only by STRUCTURE: >=2 distinct relations actually applied, or a DAG deep
        # enough that a second concept had to feed it. Two concept NAMES in a list is not composition.
        numeric_backed = len(distinct_rel) >= 2 or (structure_depth(structure) or 0) >= 2
        # NON-NUMERIC BACKING (2026-07-29). A match-the-columns item composes several concepts without any
        # arithmetic DAG: each of its four pairings is grounded in a DIFFERENT certified concept and the key
        # is the permutation reproducing all of them, so a wrong pairing anywhere changes the answer. That is
        # structural composition, and refusing it would have quarantined the single most common composite
        # form in the measured PYQ corpus (match = 11.0% of NEET) for lacking arithmetic it never has.
        # The claim is CHECKED, not accepted: the declared components must be >=2 DISTINCT concept ids that
        # actually appear in the item's own concept_ids. It is not a bypass — the lane that uses it also
        # faces a FATAL gate proving the key derives from those very pairings (`match_key_verified`).
        comps = claimed.get("composition_components") or []
        ids = set(claimed.get("concept_ids") or [])
        nonnumeric_backed = (isinstance(comps, list) and len(set(comps)) >= 2
                             and set(comps) <= ids and len(ids) >= 2)
        backed = len(concepts) >= 2 and (numeric_backed or nonnumeric_backed)
        add("composition_backed", backed, QUARANTINE,
            f"concepts={len(concepts)} distinct_relations={len(distinct_rel)} "
            f"depth={structure_depth(structure)} nonnumeric_components={len(set(comps))}")

    # ── 12. VISUAL SPEC (HARNESS) — a visual claim must carry a STRUCTURED spec, never a prose promise ──
    if spec.get("visual_required"):
        vs = cand.get("visual_spec") or {}
        add("visual_spec_present", bool(vs and vs.get("kind") and vs.get("elements")), QUARANTINE,
            f"kind={vs.get('kind')!r} elements={len(vs.get('elements') or [])}")
    elif cand.get("visual_spec"):
        add("visual_unnecessary", False, ADVISORY, "supplied a visual where the spec required none")

    # ── 13. SOLUTION GATES — only at the solution stage (compact candidates carry no solution yet) ──
    if stage != "solution":
        return out
    sol = cand.get("solution") or {}
    steps_ok = bool(sol.get("steps"))
    final = sol.get("final")
    add("solution_present", steps_ok and final is not None, FATAL,
        f"steps={len(sol.get('steps') or [])} final={final!r}")
    # The solution must terminate on THE KEY, whatever shape the key takes for this answer format.
    if final is not None:
        if fmt == INTEGER_ENTRY:
            # compare against the numeric key using the item's OWN declared tolerance — the same tolerance
            # a marker would apply, so the gate cannot be stricter or laxer than the paper it models
            fn, kn = _num(final), _num(cand.get("answer_value"))
            tol = _num(cand.get("answer_tolerance")) or 0.0
            consistent = fn is not None and kn is not None and abs(fn - kn) <= max(tol, 1e-9)
            add("solution_matches_key", consistent, FATAL,
                f"solution_final={final!r} key={cand.get('answer_value')!r} tol={tol!r}")
        elif fmt == MULTI_CORRECT:
            # the solution must name EVERY correct option and no incorrect one — a solution that justifies
            # two of three correct answers has not solved a multi-correct item
            labels = list(cand.get("answer_labels") or [])
            keyed = {l: str(options.get(l, "")).strip().lower() for l in labels}
            body = str(final).strip().lower()
            names_all = all(v and v in body for v in keyed.values())
            wrong = [l for l in options if l not in labels]
            names_none_wrong = not any(str(options[l]).strip().lower() in body
                                       and str(options[l]).strip().lower() not in keyed.values()
                                       for l in wrong)
            add("solution_matches_key", bool(names_all and names_none_wrong), FATAL,
                f"solution_final={final!r} keys={sorted(labels)} all_named={names_all} "
                f"no_wrong_named={names_none_wrong}")
        elif ans_label in options:
            fn, on = _num(final), _num(options.get(ans_label))
            consistent = (fn is not None and on is not None and abs(fn - on) <= max(1e-9, 0.02 * abs(on))) \
                if (fn is not None and on is not None) \
                else (str(final).strip().lower() in str(options.get(ans_label)).strip().lower()
                      or str(options.get(ans_label)).strip().lower() in str(final).strip().lower())
            add("solution_matches_key", consistent, FATAL,
                f"solution_final={final!r} keyed_option={options.get(ans_label)!r}")

    return out


def _rel_key(rel: str) -> str:
    """Normalize an equation for registry lookup: whitespace/case/'*' insensitive, symbol order preserved."""
    s = (rel or "").lower().replace(" ", "").replace("*", "").replace("_", "")
    return s


# ── R1-1: blocking relation grounding (sympy solve-for-target equivalence) ───────────────────────────
_IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_MATH_NAMES = {"sqrt", "sin", "cos", "tan", "cot", "sec", "csc", "log", "ln", "exp", "abs", "Abs"}


def _symbols_of(rel: str) -> set:
    """Identifier names in an equation string, minus math-function names — the symbol set to bind before
    re-solving a certified relation for equivalence testing."""
    return {t for t in _IDENT.findall(rel or "") if t not in _MATH_NAMES}


def _solve_for_target(rel: str, target: str, symbols):
    """Solve an 'LHS = RHS' string for `target`, returning the simplified solution expression (or None).

    Order-insensitive by construction: `a = F/m` and `F = m*a` both solve for a to the same expression, so an
    algebraic rearrangement of a certified relation still grounds; but `K = m*v**2` and `K = m*v**2/2` solve to
    DIFFERENT expressions, so the wrong KE relation does not."""
    if not rel or "=" not in rel or not target:
        return None
    lhs_s, rhs_s = rel.split("=", 1)
    lhs, rhs = _to_expr(lhs_s.strip(), symbols), _to_expr(rhs_s.strip(), symbols)
    if lhs is None or rhs is None:
        return None
    if not (isinstance(lhs, sympy.Basic) and isinstance(rhs, sympy.Basic)):
        return None
    tsym = sympy.Symbol(target)
    try:
        with _time_limit(SOLVE_TIMEOUT_S):
            sols = sympy.solve(sympy.Eq(lhs, rhs), tsym, dict=False)
    except Exception:
        return None
    if not sols:
        return None
    try:
        return sympy.simplify(sols[0])
    except Exception:
        return sols[0]


def is_relation_grounded(rel, structure, spec, certified, cert_eqs=None) -> Tuple[bool, Optional[str]]:
    """Is `rel` one QIE already certified — allowing order-swaps and algebraic rearrangements (R1-1)?

    1. fast path: exact normalized-string match against the certified index (cheap, common case).
    2. sympy solve-for-target equivalence against SUBJECT-matched certified equations: solve both the candidate
       relation and each certified relation for the SAME target and compare symbolically. Grounds a=F/m against
       F=m*a; still refuses K=m*v**2 against the certified K=m*v**2/2 (KE vs ½mv²).

    Symbol-name based: a generator emitting E_k for the registry's K will not auto-match — that mismatch is the
    waiver's job, not meaning/unit alignment here (deliberately out of scope for R1-1)."""
    certified = certified or {}
    m = certified.get(_rel_key(rel))
    if m:
        return True, m
    target = (structure or {}).get("solve_for")
    if not target or "=" not in (rel or ""):
        return False, None
    cand_f = _solve_for_target(rel, target, _symbols_of(rel) | {target})
    if cand_f is None:
        return False, None
    subj = (spec or {}).get("subject")
    for row in (cert_eqs or []):
        if subj and row.get("subject") and row["subject"] != subj:
            continue
        cert_eq = row.get("equation")
        if not cert_eq:
            continue
        cert_syms = _symbols_of(cert_eq)
        if target not in cert_syms:
            continue
        cert_f = _solve_for_target(cert_eq, target, cert_syms)
        if cert_f is None:
            continue
        try:
            if sympy.simplify(cand_f - cert_f) == 0:
                return True, row.get("name")
        except Exception:
            continue
    return False, None


def _valid_waiver(w) -> bool:
    """A waiver is an explicit, owner-visible record — not a bare truthy flag. Require a non-empty `waived_by`
    AND a non-empty `reason`. It is the ONLY escape from blocking grounding and is logged in the gate detail
    (and thus into the gate_result audit trail)."""
    return bool(isinstance(w, dict) and str(w.get("waived_by") or "").strip()
                and str(w.get("reason") or "").strip())


def _relation_count(certified: dict) -> int:
    """Distinct certified relation NAMES behind the index (which keys BOTH equation and display forms, so
    len(certified) roughly doubles the true count — report relations, not keys)."""
    return len(set(certified.values())) if certified else 0


# ── R1-1: stem ↔ structure binding gate ──────────────────────────────────────────────────────────────
# Physical constants excluded from the "must appear in the stem" rule: a stem rarely restates g=9.8 or
# c=3e8. Curated conservatively — a value only skips the stem-presence check when it MATCHES the constant.
_KNOWN_CONSTANTS = {
    "g": 9.8, "G": 6.674e-11, "c": 3e8, "pi": 3.14159, "e": 2.71828, "R": 8.314,
    "N_A": 6.022e23, "h": 6.626e-34, "hbar": 1.055e-34, "eps0": 8.854e-12, "mu0": 1.2566e-6,
    "k_B": 1.381e-23, "q_e": 1.602e-19, "m_e": 9.109e-31, "F_faraday": 96485.0,
}
_SAFE_STEM_NUMS = {0.0, 1.0, 2.0}   # grammatical counts ("a body", "two blocks")


def _all_nums(text) -> List[float]:
    """Every numeric literal in a prose string, scientific-notation aware — so '6.6 x 10^-7 m and mass 2 kg'
    yields [6.6e-7, 2.0], never [6.6, 10, -7, 2]. Sci-notation matches are consumed first, then plain decimals
    over the residue (same ordering as _num)."""
    if not text:
        return []
    s = str(text).replace(",", "")
    out: List[float] = []
    for pat in (_SCI_X10, _SCI_E):
        for mo in pat.finditer(s):
            try:
                out.append(float(mo.group(1)) * (10.0 ** int(mo.group(2))))
            except Exception:
                pass
        s = pat.sub(" ", s)          # remove consumed sci-notation so its digits are not re-read as decimals
    for mo in _PLAIN.finditer(s):
        try:
            out.append(float(mo.group()))
        except Exception:
            pass
    return out


def _close(a, b, rel: float = 1e-3) -> bool:
    """Relative-tolerance compare (handles 2 vs 2.0 and 6.626e-34)."""
    try:
        a, b = float(a), float(b)
    except Exception:
        return False
    if b == 0:
        return abs(a) < 1e-9
    return abs(a - b) / abs(b) <= rel


_METHOD_LEAD = re.compile(
    r"\b(using|apply|applying|substitut\w*|plug\w*\s+in(to)?|by the (formula|equation|relation)|"
    r"from the (formula|equation|relation))\b", re.I)


def _method_leak_gate(add, stem: str, structure: dict) -> None:
    """R2-5 exam-novelty (ADVISORY): flag a stem that telegraphs its own method — either the declared relation's
    formula printed in the prose, or an explicit 'using the formula…' lead-in. Such an item is a solved
    example / plug-in drill (practice-tier), not exam-novel. Never blocks certification (a practice item can be
    perfectly correct); it exists so downstream can label novelty honestly and never sell a drill as exam-grade.
    """
    rel = (structure or {}).get("relation") or ""
    s_compact = re.sub(r"\s+", "", (stem or ""))
    leaked = []
    rhs = rel.split("=", 1)[1].strip() if "=" in rel else ""
    rhs_compact = re.sub(r"\s+", "", rhs)
    if len(rhs_compact) >= 3 and rhs_compact in s_compact:      # the formula RHS printed verbatim in the prose
        leaked.append(f"formula {rel!r} printed in the stem")
    mo = _METHOD_LEAD.search(stem or "")
    if mo:
        leaked.append(f"method lead-in {mo.group(0)!r}")
    add("method_leak", not leaked, ADVISORY,
        f"stem telegraphs the method (practice-tier, not exam-novel): {leaked}" if leaked
        else "stem does not print its method")


def _stem_binding_gate(add, stem: str, structure: dict) -> None:
    """Bind the prose a student reads to the numbers sympy solved (R1-1). Two BLOCKING directions:
      1. every declared GIVEN value appears in the stem (constants exempt);
      2. every stem quantity is a declared given (known constants + grammatical counts allowlisted)."""
    givens = (structure or {}).get("givens") or {}
    target = (structure or {}).get("solve_for")
    stem_nums = _all_nums(stem)

    missing = []
    for sym, g in givens.items():
        if sym == target:
            continue                                        # the unknown is not "given"
        val = g.get("value") if isinstance(g, dict) else g
        if val is None:
            continue                                        # target/derived slot
        try:
            fval = float(val)
        except Exception:
            continue
        if sym in _KNOWN_CONSTANTS and _close(fval, _KNOWN_CONSTANTS[sym]):
            continue                                        # g, c, R… are knowledge, not stated givens
        if not any(_close(fval, s) for s in stem_nums):
            missing.append(f"{sym}={val}")
    add("stem_binding_givens", not missing, QUARANTINE,
        f"givens absent from stem: {missing}" if missing else "every given value appears in the stem")

    given_vals = [float(g["value"]) for g in givens.values()
                  if isinstance(g, dict) and g.get("value") is not None]
    unbound = [n for n in stem_nums
               if not any(_close(n, gv) for gv in given_vals)
               and not any(_close(n, cv) for cv in _KNOWN_CONSTANTS.values())
               and n not in _SAFE_STEM_NUMS]
    add("stem_binding_stem", not unbound, QUARANTINE,
        f"stem numbers not in givens: {unbound}" if unbound else "every stem quantity is a declared given")


def load_certified_relations(qconn) -> Dict[str, str]:
    out = {}
    for r in qconn.execute("SELECT name, equation, display FROM governed_relation WHERE status='certified'"):
        for form in (r["equation"], r["display"]):
            if form:
                out[_rel_key(form)] = r["name"]
    return out


def load_certified_relation_eqs(qconn) -> List[dict]:
    """Certified relation equations, subject-scoped — the input to is_relation_grounded's sympy equivalence
    layer. Kept separate from load_certified_relations (which is a normalized-string index) so grounding stays
    connection-free: callers stash this in ctx['certified_relation_eqs']."""
    return [{"name": r["name"], "equation": r["equation"], "subject": r["subject"]}
            for r in qconn.execute(
                "SELECT name, equation, subject FROM governed_relation WHERE status='certified'")]


def verdict(gate_results: List[dict]) -> Tuple[str, str]:
    """Lifecycle decision. FATAL -> rejected. QUARANTINE -> quarantined (a certification EVENT requiring
    adjudication — never auto-promoted, never auto-fixed). Otherwise it survives the deterministic battery
    and proceeds to independent validation + the judge. Surviving here is NOT certification."""
    fatal = [g["gate"] for g in gate_results if not g["ok"] and g["severity"] == FATAL]
    if fatal:
        return "rejected", "FATAL: " + ", ".join(fatal)
    quar = [g["gate"] for g in gate_results if not g["ok"] and g["severity"] == QUARANTINE]
    if quar:
        return "quarantined", "QUARANTINE: " + ", ".join(quar)
    return "candidate", "passed deterministic battery"
