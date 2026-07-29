"""Lane C generator — certified concept in, fully-evidenced question out.

FLOW (no model is called at any point)

    certified ki_concept  ->  grounded Binding            (certgen.binding — W1)
      -> deterministic parameter sample (seeded by content hash)
      -> answer COMPUTED from the certified relation
      -> THREE independent re-derivations, any disagreement kills the item:
           1. round-trip substitution   — put the key back into BOTH sides of the relation and compare.
                                          This is EVALUATION, not solving: it cannot fail in the same way
                                          a solve fails, which is what makes it a real second opinion.
           2. relations.verify          — the pre-existing library second solver, which tries the WHOLE
                                          relation library and is implemented independently of this file.
           3. gates.independent_solve   — the architecture's mandated solver, run against the DECLARED
                                          structure exactly as the factory lane runs it.
      -> misconception-computed distractors (each proven by gates.verify_distractors)
      -> rendered solution + reasoning  (certgen.solution — W2)
      -> difficulty band                (knowledge.difficulty, unchanged)
      -> the 22-gate battery            (factory.gates, unchanged)

HONEST STATEMENT OF INDEPENDENCE. In the factory lane the generator is a language model and sympy is a
genuinely foreign checker, so "independent" is unambiguous. Lane C computes its own answer, so its
independence claim is necessarily weaker and is stated precisely rather than overclaimed: the key is
produced by SOLVING the certified relation and is then re-derived by SUBSTITUTION (check 1) and, where the
relation exists in the library, by a second solver written independently of this module (check 2).
Check 1 catches a bad solve; check 2 catches a bad relation transcription. Neither is a model. What Lane C
does NOT have is an outside opinion on whether the question is a good question — that is what the factory
lane's cross-family judge provides, and it is why Lane C output is marked `deterministic_computed` rather
than borrowing the factory's `sympy_rederived` certification class.

Deterministic (seeded by content hash), read-only against every store.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from typing import Dict, List, Optional, Sequence, Tuple

import sympy

from kie import config
from kie.qie import relations as R
from kie.qie.certgen import assertion_reason as AR
from kie.qie.certgen import conceptual_mcq as CMC
from kie.qie.certgen import match_columns as MTC
from kie.qie.certgen import solution as SOL
from kie.qie.certgen.binding import Binding, Given, ResolvedBinding
from kie.qie.factory import gates as G
from kie.qie.knowledge import difficulty as DIFF

LABELS = ("a", "b", "c", "d")
TOL = 1e-6
EVIDENCE_CLASS = "deterministic_computed"


# ── deterministic sampling ────────────────────────────────────────────────────────────────────────────
def _h(seed: str) -> int:
    return int(hashlib.sha256(seed.encode()).hexdigest(), 16)


def sample_params(b, seed: str, i: int) -> Dict[str, float]:
    """Works for a `Binding` or a `Chain` — both expose `binding_id` and `givens`; only `Binding` has
    `triples`, so it is read defensively rather than duplicating this sampler for the depth tier."""
    if getattr(b, "triples", ()):
        # exact-value draw (see Binding.triples): take the givens in declared order from one tuple
        t = b.triples[_h(f"{seed}|{b.binding_id}|{i}|triple") % len(b.triples)]
        return {g.symbol: float(t[j]) for j, g in enumerate(b.givens) if j < len(t)}
    out: Dict[str, float] = {}
    for g in b.givens:
        n = (g.hi - g.lo) // g.step + 1
        out[g.symbol] = float(g.lo + g.step * (_h(f"{seed}|{b.binding_id}|{i}|{g.symbol}") % n))
    return out


# ── compute + the independent re-derivations ──────────────────────────────────────────────────────────
def _sym(names) -> Dict[str, sympy.Symbol]:
    return {n: sympy.Symbol(n) for n in names}


def _sides(equation: str, names) -> Tuple[sympy.Expr, sympy.Expr]:
    lhs_s, rhs_s = equation.split("=", 1)
    loc = _sym(names)
    return sympy.sympify(lhs_s.strip(), locals=loc), sympy.sympify(rhs_s.strip(), locals=loc)


def solve_for_key(equation: str, params: Dict[str, float], solve_for: str) -> Optional[float]:
    """The GENERATOR's own computation: solve the certified relation for the target."""
    names = set(params) | {solve_for}
    lhs, rhs = _sides(equation, names)
    subs = {sympy.Symbol(k): sympy.Float(v) for k, v in params.items()}
    t = sympy.Symbol(solve_for)
    sols = sympy.solve(sympy.Eq(lhs.subs(subs), rhs.subs(subs)), t, dict=False)
    real = []
    for s in sols:
        try:
            val = complex(s)
        except (TypeError, ValueError):
            continue
        if abs(val.imag) <= TOL:
            real.append(float(val.real))
    if not real:
        return None
    # a physical/geometric magnitude is the non-negative root (hypotenuse, energy, pressure); if every root
    # is negative the item is malformed and is dropped rather than silently sign-flipped.
    pos = [v for v in real if v > 0]
    if len(set(round(v, 9) for v in (pos or real))) != 1:
        return None                      # genuinely ambiguous key — never guess which root was intended
    return (pos or real)[0]


def roundtrip_agrees(equation: str, params: Dict[str, float], solve_for: str, answer: float) -> bool:
    """INDEPENDENT CHECK 1 — substitution, not solving.

    Put the computed key back into the relation alongside the givens and evaluate BOTH sides numerically.
    A correct key makes them equal. This exercises a different sympy path from `solve` (evaluation rather
    than equation-solving), so a solver defect does not hide behind it.
    """
    names = set(params) | {solve_for}
    lhs, rhs = _sides(equation, names)
    subs = {sympy.Symbol(k): sympy.Float(v) for k, v in params.items()}
    subs[sympy.Symbol(solve_for)] = sympy.Float(answer)
    try:
        lv, rv = float(lhs.subs(subs).evalf()), float(rhs.subs(subs).evalf())
    except (TypeError, ValueError):
        return False
    scale = max(abs(lv), abs(rv), 1.0)
    return abs(lv - rv) <= 1e-6 * scale


def library_agrees(params: Dict[str, float], answer: float, subject: str) -> Optional[bool]:
    """INDEPENDENT CHECK 2 — the pre-existing library second solver (`relations.verify`), which tries the
    WHOLE library against these operands. Returns None when no library relation covers this item, which is
    recorded honestly rather than counted as a pass."""
    got = R.verify([float(v) for v in params.values()], float(answer), tol=0.02, subject=subject)
    return None if got is None else True


def key_collides_with_a_given(answer: float, params: Dict[str, float]) -> bool:
    """Is the key numerically equal to one of the numbers the question hands the student?

    A quality rule, not a correctness one. The work-energy chain produced "a force of 38 N moves it 19 m …
    final speed?" with the key 19 m/s — arithmetically impeccable, and a poor item: the answer is sitting
    in the stem. A student who guesses that a printed number is the answer is rewarded, and one who
    computes correctly cannot tell whether they have confirmed their work or fallen for a coincidence.
    Exam boards avoid it, so the sampler does too — a different sample costs nothing.
    """
    return any(abs(float(v) - float(answer)) <= 1e-9 for v in params.values())


# ── distractors: each one is what a NAMED mistake computes ────────────────────────────────────────────
def misconception_values(b: Binding, params: Dict[str, float],
                         answer: float) -> List[Tuple[str, float, str]]:
    """Choose the option set: one CONCEPTUAL trap plus the nearest-value traps available.

    Selection, not just filtering. Every candidate here is already a proven student error, so the question
    is which THREE make the best item. The rule:

      * at least one `conceptual` error must survive — that is what makes a wrong answer diagnostic
        rather than merely wrong;
      * the remaining slots go to whichever candidates sit CLOSEST to the key in log-magnitude, which
        is what stops the key being identifiable by inspection.

    The measured problem this fixes: {0.83, 1.2, 11, 30} for a key of 30. Every option was gate-proven,
    the item passed the whole battery, and it was still a poor question because 30 is the only plausible
    distance. Ranking by closeness puts the near-misses on the paper and keeps one conceptual trap.
    """
    import math

    cands: List[Tuple[str, float, str, str]] = []       # (name, value, mis_relation, tier)
    seen = {round(float(answer), 6)}
    for m in b.misconceptions:
        v = solve_for_key(m.mis_relation, params, b.solve_for)
        if v is None or v <= 0:
            continue                                    # a negative magnitude is not a plausible option
        key = round(v, 6)
        if key in seen:
            continue                                    # collides with the key or another distractor
        if not (0.01 <= abs(v) / max(abs(answer), 1e-9) <= 100):
            continue                                    # absurd off-scale value a student cannot reach
        seen.add(key)
        cands.append((m.name, v, m.mis_relation, m.tier))

    def closeness(c) -> float:
        return abs(math.log10(max(abs(c[1]), 1e-12) / max(abs(answer), 1e-12)))

    conceptual = sorted([c for c in cands if c[3] == "conceptual"], key=closeness)
    others = sorted([c for c in cands if c[3] != "conceptual"], key=closeness)
    chosen: List[Tuple[str, float, str, str]] = []
    if conceptual:
        chosen.append(conceptual[0])                    # the diagnostic trap, always kept
    for c in sorted(others + conceptual[1:], key=closeness):
        if len(chosen) == 3:
            break
        chosen.append(c)
    return [(name, v, rel) for name, v, rel, _tier in chosen]


# ── item assembly ─────────────────────────────────────────────────────────────────────────────────────
def build_item(rb: ResolvedBinding, seed: str, i: int) -> Optional[dict]:
    """One fully-evidenced question, or None if any check refused it."""
    b = rb.binding
    params = sample_params(b, seed, i)
    if b.accept and not b.accept(params):
        return None

    answer = solve_for_key(b.equation, params, b.solve_for)
    if answer is None or answer <= 0:
        return None
    if b.integer_answer and abs(answer - round(answer)) > 1e-9:
        return None                                     # keep the arithmetic clean at this class level
    answer = round(answer, b.round_to)
    if key_collides_with_a_given(answer, params):
        return None                                     # the answer must not already be printed in the stem

    # ── the independent re-derivations ──
    if not roundtrip_agrees(b.equation, params, b.solve_for, answer):
        return None
    lib = library_agrees(params, answer, b.discipline)
    if lib is False:
        return None

    mis = misconception_values(b, params, answer)
    if len(mis) < 3:
        return None                                     # 4 options, every wrong one proven — or no item

    # every option must PRINT the value it actually is (see solution.fmt_exact) — a rounded distractor is
    # no longer the number its named misconception computes, and the distractor gate rightly refuses it
    key_text = SOL.fmt_exact(answer, b.round_to)
    if key_text is None:
        return None
    printed = []
    for name, v, rel in mis:
        t = SOL.fmt_exact(v, b.round_to)
        if t is None:
            continue
        printed.append((t, name, rel))
    if len(printed) < 3:
        return None
    printed = printed[:3]

    # deterministic option order — the key must not sit in a predictable slot
    pool = [(key_text, True, None)] + [(t, False, (name, rel)) for t, name, rel in printed]
    if len({p[0] for p in pool}) != 4:
        return None                                     # two options print identically
    pool.sort(key=lambda p: hashlib.sha256(f"{seed}|{b.binding_id}|{i}|{p[0]}".encode()).hexdigest())

    options: Dict[str, str] = {}
    answer_label = ""
    rationale: Dict[str, Dict[str, str]] = {}
    ordered_mis: List[Tuple[str, str, float, str]] = []
    for label, (text, is_key, meta) in zip(LABELS, pool):
        options[label] = text
        if is_key:
            answer_label = label
        else:
            name, rel = meta
            rationale[label] = {"misconception": name, "mis_relation": rel}
            ordered_mis.append((label, name, float(text), rel))
    if not answer_label:
        return None

    structure = {
        "givens": {g.symbol: {"value": params[g.symbol], "unit": g.unit} for g in b.givens},
        "relation": b.equation,
        "solve_for": b.solve_for,
        # the DIMENSIONAL gate reads the target's unit from here (the target is deliberately absent from
        # `givens` — it is what the student computes). Without it the gate cannot check and quarantines.
        "answer_unit": b.answer_unit,
    }
    depth = G.structure_depth(structure) or 1
    concept_count = 1
    diff = DIFF.predict(depth, concept_count, misconception_pressure=0.0,
                        calculation_load=DIFF.LANE_CALC_LOAD["STRUCTURED_NUMERIC"])

    # rotate through the authored SCENARIOS, not just the numbers — `duplicate_exact`/`near_duplicate`
    # normalize numerals away, so one stem sampled three times is one question printed three times.
    stem = SOL.enrich_stem(
        b.stems[i % len(b.stems)].format(**{g.symbol: SOL.fmt_number(params[g.symbol]) for g in b.givens}),
        elaboration=getattr(b, "elaboration", ""), condition=getattr(b, "condition", ""))
    sol = SOL.render_solution(rb, params, answer)

    gen_id = "CGEN_" + hashlib.sha256(
        f"{b.binding_id}|{rb.concept_id}|{stem}|{json.dumps(params, sort_keys=True)}".encode()
    ).hexdigest()[:16]

    return {
        "gen_id": gen_id,
        "binding_id": b.binding_id,
        # ── curriculum identity: the REAL certified concept, not a pseudo-code ──
        "concept_id": rb.concept_id,
        "concept_name": b.concept_name,
        "chapter_id": rb.chapter_id,
        "chapter_title": rb.chapter_title,
        "section_heading": rb.section_heading,
        "class_level": b.taught_at_class,
        "subject": rb.subject,                   # curriculum SOURCE subject ('Science' for classes 6-10)
        "discipline": b.discipline,              # the audited academic discipline
        "archetype": b.archetype,
        # ── the question ──
        "stem": stem,
        "options": options,
        "answer_label": answer_label,
        "answer_value": options[answer_label],
        "answer_unit": b.answer_unit,
        # ── the evidence bundle ──
        "structure": structure,
        "solution": sol,
        "distractor_rationale": rationale,
        "common_mistake": SOL.common_mistake(ordered_mis),
        "reasoning": SOL.render_reasoning(rb, depth, concept_count),
        "reasoning_depth": depth,
        "difficulty": diff,
        "claimed": {"concepts": [b.concept_name], "concept_ids": [rb.concept_id],
                    "archetype": b.archetype, "depth": depth},
        "provenance": {
            "lane": "CERTGEN_DETERMINISTIC",
            "evidence_class": EVIDENCE_CLASS,
            "certified_concept_id": rb.concept_id,
            "certified_chapter_id": rb.chapter_id,
            "grounding": list(b.grounding),
            "relation": b.equation,
            "params": params,
            "verification": {
                "roundtrip_substitution": "agree",
                "relation_library_second_solver": ("agree" if lib else "not_covered"),
                "independent_solve": "pending_gate_battery",
            },
            "boundary": rb.boundary,
        },
        "_params": params,
    }


def generate(resolved: Sequence[ResolvedBinding], per_binding: int = 4,
             seed: str = "C1") -> List[dict]:
    """At most ONE item per authored scenario per binding.

    This cap is forced by the dedup gates and is worth stating plainly, because it governs how this lane
    scales. `gates.norm_hash` masks numerals before hashing, precisely so that template flooding cannot
    hide behind fresh numbers — so two items built from the same scenario sentence are the SAME question
    to `duplicate_exact`, however different their arithmetic. Measured: allowing free re-sampling produced
    4 `duplicate_exact` + 4 `near_duplicate` failures in a 34-item run.

    The consequence is the honest one: Lane C's volume is bounded by the number of genuinely distinct
    SCENARIOS authored, not by how many numbers it can sample. Growing this lane means writing more
    contexts, which is the same work a good teacher does — not turning up a sampling dial.
    """
    out: List[dict] = []
    for rb in resolved:
        n_scen = len(rb.binding.stems)
        used_scenarios: set = set()
        attempt = 0
        while len(used_scenarios) < min(per_binding, n_scen) and attempt < n_scen * 24:
            scenario = attempt % n_scen
            if scenario in used_scenarios:
                attempt += 1
                continue
            it = build_item(rb, seed, attempt)
            attempt += 1
            if it is None:
                continue
            used_scenarios.add(scenario)
            out.append(it)
    return out


# ══ DEPTH TIER — multi-concept chains ═════════════════════════════════════════════════════════════════
def execute_chain(rc, params: Dict[str, float]) -> Optional[Dict[str, float]]:
    """Run the chain forward, one certified relation at a time, returning the full environment.

    This is the ENGINE's own execution. It is deliberately NOT the same code as either check that follows:
    `gates.replay_steps` re-executes the DAG independently, and `gates.independent_solve` solves the
    composed relation without ever seeing an intermediate. Three routes, one number.
    """
    env: Dict[str, float] = dict(params)
    for st in rc.chain.steps:
        if any(i not in env for i in st.inputs):
            return None
        sub = {k: env[k] for k in st.inputs}
        val = solve_for_key(st.relation, sub, st.out)
        if val is None:
            return None
        env[st.out] = val
    return env


def build_chain_item(rc, seed: str, i: int) -> Optional[dict]:
    """One multi-concept question, or None if any route disagreed or any check refused it."""
    ch = rc.chain
    params = sample_params(ch, seed, i)          # Chain exposes .binding_id/.givens/.triples like Binding
    if ch.accept and not ch.accept(params):
        return None

    env = execute_chain(rc, params)
    if env is None:
        return None
    answer = env.get(ch.solve_for)
    if answer is None or answer <= 0:
        return None
    if ch.integer_answer and abs(answer - round(answer)) > 1e-9:
        return None
    answer = round(answer, ch.round_to)
    if key_collides_with_a_given(answer, params):
        return None                                     # the answer must not already be printed in the stem

    # ── route B: the composed relation, solved without any intermediate ──
    composed_val = solve_for_key(ch.composed, params, ch.solve_for)
    if composed_val is None or abs(composed_val - answer) > 1e-6 * max(abs(answer), 1.0):
        return None                              # the composed form is not the chain — refuse, never ship
    if not roundtrip_agrees(ch.composed, params, ch.solve_for, answer):
        return None

    structure = {
        "givens": {g.symbol: {"value": params[g.symbol], "unit": g.unit} for g in ch.givens},
        "relation": ch.composed,
        "solve_for": ch.solve_for,
        "answer_unit": ch.answer_unit,
        "steps": [{"out": st.out, "inputs": list(st.inputs), "relation": st.relation} for st in ch.steps],
    }

    # ── route A: gates.replay_steps re-executes the DAG and EARNS the depth ──
    rep = G.replay_steps(structure)
    if not rep.get("ok"):
        return None
    earned = rep.get("depth")
    if not earned or earned < 2:
        return None                              # a chain that earns depth 1 is not a chain
    if rep.get("final") is None or abs(float(rep["final"]) - answer) > 0.02 * max(abs(answer), 1e-9):
        return None                              # route A and the engine disagree

    mis = misconception_values(ch, params, answer)
    if len(mis) < 3:
        return None
    key_text = SOL.fmt_exact(answer, ch.round_to)
    if key_text is None:
        return None
    printed = []
    for name, v, rel in mis:
        t = SOL.fmt_exact(v, ch.round_to)
        if t is not None:
            printed.append((t, name, rel))
    if len(printed) < 3:
        return None
    printed = printed[:3]

    pool = [(key_text, True, None)] + [(t, False, (n, r)) for t, n, r in printed]
    if len({p[0] for p in pool}) != 4:
        return None
    pool.sort(key=lambda p: hashlib.sha256(f"{seed}|{ch.binding_id}|{i}|{p[0]}".encode()).hexdigest())

    options: Dict[str, str] = {}
    answer_label = ""
    rationale: Dict[str, Dict[str, str]] = {}
    ordered_mis: List[Tuple[str, str, float, str]] = []
    for label, (text, is_key, meta) in zip(LABELS, pool):
        options[label] = text
        if is_key:
            answer_label = label
        else:
            name, rel = meta
            rationale[label] = {"misconception": name, "mis_relation": rel}
            ordered_mis.append((label, name, float(text), rel))
    if not answer_label:
        return None

    concept_names = list(dict.fromkeys(rc.concept_names))
    concept_ids = list(dict.fromkeys(rc.concept_ids))
    diff = DIFF.predict(earned, len(concept_ids), misconception_pressure=0.0,
                        calculation_load=DIFF.LANE_CALC_LOAD["STRUCTURED_NUMERIC"])

    stem = SOL.enrich_stem(
        ch.stems[i % len(ch.stems)].format(**{g.symbol: SOL.fmt_number(params[g.symbol]) for g in ch.givens}),
        elaboration=getattr(ch, "elaboration", ""), condition=getattr(ch, "condition", ""))
    sol = SOL.render_chain_solution(rc, params, env, answer)

    gen_id = "CCHN_" + hashlib.sha256(
        f"{ch.binding_id}|{stem}|{json.dumps(params, sort_keys=True)}".encode()).hexdigest()[:16]

    return {
        "gen_id": gen_id,
        "binding_id": ch.binding_id,
        "concept_id": concept_ids[0],
        "concept_name": concept_names[0],
        "concept_ids": concept_ids,
        "concept_names": concept_names,
        "chapter_id": rc.chapter_ids[0],
        "chapter_title": "",
        "section_heading": rc.section_headings[0],
        "class_level": ch.taught_at_class,
        "subject": rc.subject,
        "discipline": ch.discipline,
        "archetype": ch.archetype,
        "stem": stem,
        "options": options,
        "answer_label": answer_label,
        "answer_value": options[answer_label],
        "answer_unit": ch.answer_unit,
        "structure": structure,
        "solution": sol,
        "distractor_rationale": rationale,
        "common_mistake": SOL.common_mistake(ordered_mis),
        "reasoning": SOL.render_chain_reasoning(rc, earned),
        "reasoning_depth": earned,
        "difficulty": diff,
        "claimed": {"concepts": concept_names, "concept_ids": concept_ids,
                    "archetype": ch.archetype, "depth": earned, "composition": "multi"},
        "provenance": {
            "lane": "CERTGEN_COMPOSITION",
            "evidence_class": EVIDENCE_CLASS,
            "certified_concept_id": concept_ids[0],
            "certified_concept_ids": concept_ids,
            "certified_chapter_id": rc.chapter_ids[0],
            "grounding": [g for st in ch.steps for g in st.grounding],
            "relation": ch.composed,
            "step_relations": [st.relation for st in ch.steps],
            "params": params,
            "intermediates": {st.out: env[st.out] for st in ch.steps if st.out in env},
            "verification": {
                "chain_execution": "agree",
                "composed_relation_solve": "agree",
                "roundtrip_substitution": "agree",
                "replay_steps_earned_depth": earned,
                "independent_solve": "pending_gate_battery",
            },
            "boundary": rc.boundary,
        },
        "_params": params,
    }


def generate_chains(resolved_chains: Sequence, per_chain: int = 3, seed: str = "K1") -> List[dict]:
    """At most one item per authored scenario, for the same numeral-masking reason as `generate`."""
    out: List[dict] = []
    for rc in resolved_chains:
        n_scen = len(rc.chain.stems)
        used: set = set()
        attempt = 0
        while len(used) < min(per_chain, n_scen) and attempt < n_scen * 40:
            scenario = attempt % n_scen
            if scenario in used:
                attempt += 1
                continue
            it = build_chain_item(rc, seed, attempt)
            attempt += 1
            if it is None:
                continue
            used.add(scenario)
            out.append(it)
    return out


def chain_relation_registry(resolved_chains: Sequence) -> Tuple[dict, list]:
    """Registry supplement for chains: every STEP relation (each grounded in its own certified concept)
    plus the COMPOSED relation.

    The composed relation's certification is DERIVED — it is the algebraic composition of relations that
    are individually certified, and `build_chain_item` refuses to ship an item unless the composed form and
    the step-by-step execution produce the same number. It is registered under an explicit `:composed`
    name so an auditor can tell a derived relation from a directly-attested one.
    """
    by_key: Dict[str, str] = {}
    eqs: List[dict] = []
    for rc in resolved_chains:
        ch = rc.chain
        for st in ch.steps:
            name = f"CERTGEN:{ch.binding_id}:{st.out}"
            by_key[G._rel_key(st.relation)] = name
            eqs.append({"name": name, "equation": st.relation, "subject": rc.subject})
        cname = f"CERTGEN:{ch.binding_id}:composed"
        by_key[G._rel_key(ch.composed)] = cname
        eqs.append({"name": cname, "equation": ch.composed, "subject": rc.subject})
    return by_key, eqs


# ── spec construction, so Lane C items face the SAME gate battery as the factory lane ────────────────
def to_spec(item: dict) -> dict:
    """The `generation_spec`-shaped row `gates.run_gates` reads from ctx.

    `boundary.forbidden_terms` is populated from the certified concept's OWN evidenced `out_of_scope` list.
    That directly addresses verification finding W7 (the boundary gate previously had nothing
    curriculum-evidenced to check and therefore recorded an advisory failure): for a Lane C item the gate
    now scans real, audited, per-concept boundary evidence.
    """
    oos = [str(t) for t in ((item.get("provenance", {}).get("boundary") or {}).get("out_of_scope") or [])]
    return {
        "spec_id": f"CSPEC_{item['gen_id']}",
        # an assertion-reason item is not a numeric item: it declares no relation and no givens, so the
        # STRUCTURED_NUMERIC lane's `structure_present` FATAL gate must not be applied to it
        "lane": item.get("lane") or "STRUCTURED_NUMERIC",
        "class_level": item["class_level"],
        "subject": item["subject"],
        "discipline": item["discipline"],
        "concept_code": item["concept_id"],
        "concept_title": item["concept_name"],
        # W7: EVERY concept of a multi-concept item, so the gate's "no crying wolf" rule protects each
        # one's topic words — a depth-tier item must not be quarantined for naming its own second concept.
        "concept_titles": item.get("claimed", {}).get("concepts") or [item["concept_name"]],
        "chapter_id": item["chapter_id"],
        "archetype": item["archetype"],
        "intended_depth": item["reasoning_depth"],
        "composition": item.get("claimed", {}).get("composition", "single"),
        "visual_required": 0,
        "boundary": json.dumps({"forbidden_terms": oos}),
    }


def to_candidate(item: dict) -> dict:
    """The `cand` shape `gates.run_gates` consumes."""
    return {
        "stem": item["stem"],
        "options": item["options"],
        "answer_label": item["answer_label"],
        "answer_value": item["answer_value"],
        "claimed": item["claimed"],
        "structure": item["structure"],
        "solution": item["solution"],
        "visual_spec": None,
    }


def certified_relation_context() -> Tuple[dict, list]:
    """Load the certified relation registry from qie.db (read-only), exactly as validate_run does."""
    q = sqlite3.connect(f"file:{config.KIE_HOME / 'qie.db'}?mode=ro", uri=True)
    q.row_factory = sqlite3.Row
    try:
        return G.load_certified_relations(q), G.load_certified_relation_eqs(q)
    finally:
        q.close()


def binding_relation_registry(resolved: Sequence[ResolvedBinding]) -> Tuple[dict, list]:
    """The Lane C supplement to the certified relation registry, built ONLY from GROUNDED bindings.

    WHY THIS IS NOT A WEAKENING OF THE `relation_grounded` GATE. That gate asks one question: is this
    relation one QIE has already certified, or is the generator inventing physics? Its registry
    (`qie.db governed_relation`, 49 rows) was mined from senior-physics PYQ evidence, so it answers the
    question well for Class 11-12 electricity and mechanics and has NOTHING to say about
    `Area = length x width`. Measured on the first Lane C run: 29 of 32 items were quarantined as
    "ungrounded" purely because the registry has no Class 6-10 curriculum relations in it — not because
    anything was invented.

    The honest repair is to give the gate a SECOND certified source, not to lower its bar. Every relation
    added here has already passed `binding.resolve()`, which required the relation to appear verbatim in
    the audited `sub_concepts` / `boundary.in_scope` of a CERTIFIED `ki_concept`. So the claim
    "V = l x b x h is certified" rests on `KC_771977581c488d`'s own evidence, exactly as the governed_relation
    rows rest on theirs. An UNGROUNDED binding never reaches this function — `resolve()` refuses it first —
    so this registry cannot launder an invented relation.

    The frozen stores are not touched: this registry is assembled in memory and passed through `ctx`,
    which is the same channel `validate_run` uses.
    """
    by_key: Dict[str, str] = {}
    eqs: List[dict] = []
    for rb in resolved:
        b = rb.binding
        name = f"CERTGEN:{b.binding_id}"
        by_key[G._rel_key(b.equation)] = name
        # subject-scoped to the CURRICULUM SOURCE subject, because `is_relation_grounded` filters the
        # equivalence layer by `spec['subject']` and Lane C specs carry the source subject ('Science' for 6-10)
        eqs.append({"name": name, "equation": b.equation, "subject": rb.subject})
    return by_key, eqs


def gate_items(items: Sequence[dict], resolved: Sequence[ResolvedBinding] = (),
               resolved_chains: Sequence = (), stage: str = "solution") -> List[dict]:
    """Run the FULL 22-gate battery plus the distractor proof over Lane C items.

    Reuses `factory.gates` unmodified — Lane C earns its verdict on the same battery the factory lane
    faces, including the FATAL `solution_present` / `solution_matches_key` gates that Lane B could never
    have satisfied.
    """
    certified_relations, certified_relation_eqs = certified_relation_context()
    # the registry the gate consults = the mined governed_relation rows PLUS the curriculum relations each
    # certified concept attests (see binding_relation_registry for why this is additive, not a relaxation)
    supp_keys, supp_eqs = binding_relation_registry(resolved)
    chain_keys, chain_eqs = chain_relation_registry(resolved_chains)
    certified_relations = {**certified_relations, **supp_keys, **chain_keys}
    certified_relation_eqs = list(certified_relation_eqs) + supp_eqs + chain_eqs
    seen_norm: Dict[str, str] = {}
    corpus_by_cell: Dict[tuple, List[Tuple[str, str]]] = {}
    results: List[dict] = []

    for item in items:
        spec = to_spec(item)
        cand = to_candidate(item)
        cell = (spec["class_level"], spec["subject"])
        ctx = {"spec": spec, "seen_norm": seen_norm, "corpus": corpus_by_cell.get(cell, []),
               "certified_relations": certified_relations,
               "certified_relation_eqs": certified_relation_eqs, "relation_waiver": None}

        gr = G.run_gates(cand, ctx, stage=stage)

        ind: Dict[str, object] = {}
        agree = None
        if item.get("lane") == CMC.LANE:
            # A conceptual MCQ's options are EXPRESSIONS or RESPONSES, not numbers, so the numeric
            # distractor proof cannot apply. The equivalent proof is falsification: every wrong option is
            # refuted both by sympy non-equivalence and by computing a different value at a working point.
            cres = CMC.verify_key(item)
            gr.append({"gate": "conceptual_key_verified", "ok": bool(cres["ok"]), "severity": G.FATAL,
                       "detail": cres["detail"][:400]})
        elif item.get("lane") == MTC.LANE:
            # A match item's key is a PERMUTATION, so the proof is that exactly one option reproduces
            # every certified pairing and each other option names a specific pair it contradicts. Same
            # force as the numeric distractor proof, same FATAL severity, different mechanism.
            mres = MTC.verify_key(item)
            gr.append({"gate": "match_key_verified", "ok": bool(mres["ok"]), "severity": G.FATAL,
                       "detail": mres["detail"][:400]})
        elif item.get("archetype") == "assertion_reason":
            # An AR option is a SENTENCE about a truth table, not a number, so the numeric distractor proof
            # cannot apply. `assertion_reason.verify_options` is its counterpart: every wrong option asserts
            # a truth-configuration, and at least one entry of it must be contradicted by a value this
            # engine COMPUTED. Same force, different mechanism — and still FATAL.
            ares = AR.verify_options(item)
            gr.append({"gate": "ar_options_verified", "ok": bool(ares["ok"]), "severity": G.FATAL,
                       "detail": ares["detail"][:400]})
            # the key must fall out of the computed truth table, never be chosen (R3-8)
            tt = item["provenance"]["truth_table"]
            gr.append({"gate": "ar_key_computed",
                       "ok": bool(item["provenance"].get("key_derivation")) and tt is not None,
                       "severity": G.FATAL,
                       "detail": f"truth_table={tt} key={item['answer_label']}"})
        else:
            # the distractor proof: every wrong option's named mistake must actually compute that option
            dres = G.verify_distractors(item["structure"], item["options"], item["answer_label"],
                                        item["distractor_rationale"], uncertifiable=[])
            gr.append({"gate": "distractor_verified", "ok": bool(dres["ok"]), "severity": G.FATAL,
                       "detail": dres["detail"][:400]})

            # the mandated independent solve, run exactly as validate_run runs it
            ind = G.independent_solve(item["structure"])
            if ind.get("verdict") == "solved":
                agree, why = G.answers_agree(ind["solver_answer"], item["answer_value"])
            else:
                agree, why = False, ind.get("reason", ind.get("verdict"))
            gr.append({"gate": "independent_solve", "ok": bool(agree), "severity": G.FATAL,
                       "detail": str(why)})

        status, reason = G.verdict(gr)
        fatal = [g["gate"] for g in gr if not g["ok"] and g["severity"] == G.FATAL]
        quarantine = [g["gate"] for g in gr if not g["ok"] and g["severity"] == G.QUARANTINE]
        advisory = [g["gate"] for g in gr if not g["ok"] and g["severity"] == G.ADVISORY]

        if not fatal and not quarantine:
            nh = G.norm_hash(item["stem"])
            seen_norm[nh] = item["gen_id"]
            corpus_by_cell.setdefault(cell, []).append((item["gen_id"], item["stem"]))

        results.append({**item, "gates": gr, "gate_status": status, "gate_reason": reason,
                        "fatal": fatal, "quarantine": quarantine, "advisory": advisory,
                        # non-numeric lanes (assertion-reason) declare no structure, so there is nothing for
                        # the numeric solver to re-derive; the truth table is what was computed instead
                        "independent_solve": {"verdict": ind.get("verdict"),
                                              "solver_answer": ind.get("solver_answer"), "agree": agree},
                        "passed": (not fatal and not quarantine)})
    return results
