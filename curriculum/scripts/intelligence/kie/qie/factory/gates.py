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
    "deg": "rad", "degree": "rad", "degrees": "rad",   # both are angle
    "kmol": "mol", "mmol": "mol",
    "kw": "W", "mw": "W",
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


# ── the gate battery ────────────────────────────────────────────────────────────────────────────────
_REQUIRED = ("stem", "options", "answer_label", "claimed")


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

    # ── 1. SCHEMA (HARNESS, domain-general) ──
    missing = [f for f in _REQUIRED if not cand.get(f)]
    add("schema", not missing, FATAL, f"missing: {missing}" if missing else "all required fields present")
    if missing:
        return out                                    # nothing downstream is meaningful

    stem = cand["stem"]
    options = cand.get("options") or {}
    ans_label = cand.get("answer_label")

    # ── 2. OPTION STRUCTURE (HARNESS mirror of qpgen.validate._objective_violations, same rules) ──
    viol = []
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

    # ── 7. CURRICULUM BOUNDARY (HARNESS; only as strong as the evidence — see the audit) ──
    banned = ((spec.get("boundary") and json.loads(spec["boundary"])) or {}).get("forbidden_terms") or []
    hits = [t for t in banned if re.search(rf"\b{re.escape(t)}\b", stem, re.I)]
    add("curriculum_boundary", not hits, QUARANTINE,
        f"above-class terms present: {hits}" if hits else f"no forbidden term (checked {len(banned)})")

    # ── 8..10 STRUCTURED lane only: the bridge that makes claims falsifiable ──
    structure = cand.get("structure") or {}
    if spec.get("lane") == "STRUCTURED_NUMERIC":
        rel = structure.get("relation") or ""
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
                    add("dimensional", False, ADVISORY, f"dimensional check errored: {e}")
            else:
                add("dimensional", True, ADVISORY, "not checkable: incomplete unit declaration")

            # 9. RELATION GROUNDING — is this relation one QIE already CERTIFIED, or is the model
            #    inventing physics? An ungrounded relation is a quarantine EVENT, not a rejection:
            #    it may be legitimate and simply absent from our 41-relation registry.
            certified = ctx.get("certified_relations") or {}
            key = _rel_key(rel)
            match = certified.get(key)
            add("relation_grounded", match is not None, ADVISORY,
                f"matches certified {match!r}" if match else f"relation not in governed_relation ({len(certified)} certified)")

        # 10. DEPTH EARNED FROM THE DAG (HARNESS mirror of compose.reasoning_depth)
        d = structure_depth(structure)
        claimed_d = claimed.get("depth")
        add("depth_computable", d is not None, ADVISORY, f"structure_depth={d}")
        if d is not None and isinstance(claimed_d, int):
            add("depth_agreement", d == claimed_d, ADVISORY, f"claimed={claimed_d} computed_from_dag={d}")

    # ── 11. COMPOSITION HONESTY (HARNESS) — a 'multi' claim must be backed by MORE THAN two terms
    #      appearing in the text. We test the structure, not the vocabulary.
    if claimed.get("composition") == "multi":
        concepts = claimed.get("concepts") or []
        steps = structure.get("steps") or []
        distinct_rel = {s.get("relation") for s in steps if s.get("relation")}
        # a 'multi' claim is backed only by STRUCTURE: >=2 distinct relations actually applied, or a DAG deep
        # enough that a second concept had to feed it. Two concept NAMES in a list is not composition.
        backed = len(concepts) >= 2 and (len(distinct_rel) >= 2 or (structure_depth(structure) or 0) >= 2)
        add("composition_backed", backed, QUARANTINE,
            f"concepts={len(concepts)} distinct_relations={len(distinct_rel)} depth={structure_depth(structure)}")

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
    if final is not None and ans_label in options:
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


def load_certified_relations(qconn) -> Dict[str, str]:
    out = {}
    for r in qconn.execute("SELECT name, equation, display FROM governed_relation WHERE status='certified'"):
        for form in (r["equation"], r["display"]):
            if form:
                out[_rel_key(form)] = r["name"]
    return out


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
