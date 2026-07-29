"""W2 — deterministic solution construction.

In the factory lane a solution is written by a language model that is told the locked key and must derive
it (`factory/solutions.py`). That is the right design when the item came from a model in the first place:
the item's reasoning is not otherwise recoverable.

Lane C is in a different position. Here the engine KNOWS the derivation, because it performed it — the
certified relation, the substitution, the arithmetic and the unit are all in hand before the question is
printed. So the solution is not authored, and it is certainly not "explained": it is RENDERED from the
computation that actually produced the key. There is no step in the output that the engine did not execute,
which is why no model is needed and why the solution cannot drift from the answer.

The same applies to the distractor rationales. A wrong option here is never decoration: it is the value that
a NAMED mistake computes, and `factory.gates.verify_distractors` re-executes that named mistake with sympy
and refuses the item unless the mistake reproduces that option exactly. This module's job is only to render
the sentence; the proof is the gate's.

Deterministic, stdlib + sympy, writes nothing.
"""
from __future__ import annotations

import re
from typing import Dict, List, Optional, Sequence, Tuple

from kie.qie.certgen.binding import Binding, ResolvedBinding


def fmt_number(v: float, round_to: int = 2) -> str:
    """Human display for a computed quantity: integers stay integers, decimals are trimmed of trailing
    zeros. A key printed as '18.00' where the book would print '18' reads as machine output to a teacher."""
    f = float(v)
    if abs(f - round(f)) < 1e-9:
        return str(int(round(f)))
    s = f"{f:.{round_to}f}".rstrip("0").rstrip(".")
    return s or "0"


def fmt_exact(v: float, round_to: int = 2, max_dp: int = 6, tol: float = 0.005) -> Optional[str]:
    """Display a value at whatever precision makes the PRINTED text still equal to the value.

    This exists because of a real defect the distractor gate caught. The density item computed a
    "inverted the relation" distractor of 0.125, printed it at the binding's 2 dp as '0.12', and then
    `gates.verify_distractors` re-solved the named mistake, got 0.125, and refused the item — correctly,
    because the option a student reads was NOT what the named misconception produces. Rounding an option
    is not a display choice; it silently changes what the option claims.

    So: start at the binding's preferred precision and add decimals until the printed text round-trips to
    within `tol` (tighter than the gate's 2% so we never sit on its boundary). Return None if even
    `max_dp` cannot represent it honestly — the caller then drops that option rather than printing a
    number that is almost, but not, the answer.
    """
    f = float(v)
    for dp in range(round_to, max_dp + 1):
        s = f"{f:.{dp}f}".rstrip("0").rstrip(".") or "0"
        try:
            back = float(s)
        except ValueError:
            return None
        # A nonzero quantity printed as "0" is not a rounding choice, it is a different claim — and the
        # RELATIVE tolerance below would wave it through for any small enough value. Refuse outright.
        if back == 0.0 and f != 0.0:
            continue
        if abs(back - f) <= tol * max(abs(f), 1e-9):
            return str(int(round(back))) if abs(back - round(back)) < 1e-9 else s
    return None


# "1" is the DIMENSIONLESS marker the dimensional gate needs (a count, a ratio, a percentage). It is a
# unit for sympy's benefit, not for a reader's, and printing it produces "the population is 1005 1" —
# machine output, in a solution a teacher is meant to hand to a class.
_UNPRINTABLE_UNITS = {"", "1"}


def _with_unit(value_text: str, unit: str) -> str:
    u = (unit or "").strip()
    return value_text if u in _UNPRINTABLE_UNITS else f"{value_text} {u}"


def pretty_equation(eq: str) -> str:
    """Render a sympy-parseable relation the way a textbook prints it. The stored form must stay
    sympy-parseable (the gates re-solve it), so the prettifying happens only at display time."""
    return (eq.replace("**", "^").replace("*", " x ")
              .replace("  ", " ").replace("( ", "(").replace(" )", ")").strip())


def givens_sentence(b: Binding, params: Dict[str, float]) -> str:
    bits = []
    for g in b.givens:
        bits.append(f"{g.symbol} = {_with_unit(fmt_number(params[g.symbol]), g.unit)}")
    return ", ".join(bits)


def substitution_text(b: Binding, params: Dict[str, float]) -> str:
    """The relation with every given replaced by its number — the line a marker looks for."""
    rhs = b.equation.split("=", 1)[1].strip()
    for g in sorted(b.givens, key=lambda g: -len(g.symbol)):   # longest symbol first: 'Pr' before 'P'
        rhs = rhs.replace(g.symbol, fmt_number(params[g.symbol]))
    return pretty_equation(rhs)


def render_solution(rb: ResolvedBinding, params: Dict[str, float], answer: float) -> Dict[str, object]:
    """The worked solution, as executed. Returns the `{steps:[...], final:...}` shape that
    `factory.solutions.ingest` and the FATAL `solution_present` / `solution_matches_key` gates expect."""
    b = rb.binding
    ans_text = fmt_number(answer, b.round_to)
    steps = [
        f"Step 1 — List what is given and what is required. Given: {givens_sentence(b, params)}. "
        f"Required: {b.quantity}.",
        f"Step 2 — Recall the relation taught in this chapter ({rb.section_heading}): "
        f"{pretty_equation(b.equation)}.",
        f"Step 3 — Substitute the given values: {b.solve_for} = {substitution_text(b, params)}.",
        f"Step 4 — Compute: {b.solve_for} = {_with_unit(ans_text, b.answer_unit)}.",
        f"Step 5 — State the result: {b.quantity} is {_with_unit(ans_text, b.answer_unit)}.",
    ]
    return {"steps": steps, "final": ans_text}


def enrich_stem(scenario: str, elaboration: str = "", condition: str = "") -> str:
    """Compose a stem with the SETUP -> CONDITION -> ASK structure real papers use.

    Measured over 5,786 recovered PYQ stems:

        sentences per stem     1: 0.1%   2: 56.0%   3: 21.3%   4: 11.0%   5+: 11.6%
        explicit condition present   uniform/constant 4.1%   assume/take 2.2%   if..then 8.0%

    **99.9% of real stems run to two sentences or more.** Lane C's were single scenarios, which is why its
    numerical stems measured 150 characters against the corpus median of 318 — a 0.47x information-density
    gap. The fix is not padding: it is supplying the setup and the standing conditions that a real setter
    states and we were leaving implicit.

    Nothing here copies a real question. The corpus supplied the STRUCTURE (how many sentences, whether a
    condition is stated, where the ask sits); every sentence is authored against the binding's own
    certified concept.

    `elaboration` prefaces the scenario with context; `condition` states the assumption the certified
    relation depends on, and is placed immediately before the ask, where a setter puts it.
    """
    parts = [p.strip() for p in re.split(r"(?<=[.?])\s+", scenario.strip()) if p.strip()]
    if not parts:
        return scenario
    body, ask = parts[:-1], parts[-1]
    out: List[str] = []
    if elaboration:
        out.append(elaboration.strip())
    out += body
    if condition:
        out.append(condition.strip())
    out.append(ask)
    return " ".join(out)


def render_chain_solution(rc, params: Dict[str, float], env: Dict[str, float],
                          answer: float) -> Dict[str, object]:
    """The worked solution for a multi-step chain, rendered from the DAG that was actually executed.

    Each certified relation gets its own numbered step, and — this is the part that matters pedagogically —
    every INTERMEDIATE value is printed. A student who reaches the wrong final answer can then see exactly
    which link broke, and a teacher marking the paper can award method marks per step. A solution that
    jumped from the givens to the key would hide the very reasoning the question was built to test.
    """
    ch = rc.chain
    steps: List[str] = [
        f"Step 1 — List what is given and what is required. Given: "
        f"{', '.join(f'{g.symbol} = ' + _with_unit(fmt_number(params[g.symbol]), g.unit) for g in ch.givens)}. "
        f"Required: {ch.quantity}."
    ]
    for i, st in enumerate(ch.steps):
        rhs = st.relation.split("=", 1)[1].strip()
        for sym in sorted(set(st.inputs), key=len, reverse=True):
            if sym in env:
                rhs = rhs.replace(sym, fmt_number(env[sym]))
        val = env.get(st.out)
        concept = rc.concept_names[i] if i < len(rc.concept_names) else st.concept_name
        heading = rc.section_headings[i] if i < len(rc.section_headings) else ""
        where = f" ({heading})" if heading else ""
        steps.append(
            f"Step {i + 2} — Now {st.narrate}. This is the certified concept "
            f"'{concept}'{where}: {pretty_equation(st.relation)}. "
            f"Substituting, {st.out} = {pretty_equation(rhs)}, so "
            f"{st.out} = {_with_unit(fmt_number(val) if val is not None else '?', st.out_unit)}."
        )
    ans_text = fmt_number(answer, ch.round_to)
    steps.append(f"Step {len(ch.steps) + 2} — State the result: {ch.quantity} is "
                 f"{_with_unit(ans_text, ch.answer_unit)}.")
    return {"steps": steps, "final": ans_text}


def render_chain_reasoning(rc, depth: int) -> str:
    """Why the chain is the route — the bridging insight, named explicitly."""
    ch = rc.chain
    names = list(dict.fromkeys(rc.concept_names))
    bridge = " then ".join(st.out for st in ch.steps)
    return (f"The question gives {len(ch.givens)} quantities and asks for {ch.quantity}, but no single "
            f"certified relation connects them: the required quantity is {depth} relations away from what "
            f"is supplied. The route is to obtain {bridge} in turn, so the student must recognise that "
            f"{', '.join(names[:-1])} and {names[-1]} have to be combined rather than applied in isolation. "
            f"That recognition — not the arithmetic — is what this item tests, which is why every wrong "
            f"option corresponds to a specific break in the chain (stopping early, skipping a link, or "
            f"applying one of the relations in the wrong direction) rather than to a slip in computation.")


def render_reasoning(rb: ResolvedBinding, depth: int, concept_count: int) -> str:
    """The one-paragraph reasoning trace: WHY this is the route, not merely what the route was."""
    b = rb.binding
    return (f"The question supplies {len(b.givens)} measured quantities and asks for {b.quantity}, which the "
            f"certified Class-{b.taught_at_class} concept '{b.concept_name}' relates to them directly by "
            f"{pretty_equation(b.equation)}. No quantity outside that relation is needed and none is supplied, "
            f"so the solution is a single application of the relation followed by arithmetic "
            f"({depth} dependent step(s), {concept_count} concept(s)). The distractors are the values produced "
            f"by the specific errors a student makes on this relation, so selecting one identifies the "
            f"misconception rather than merely marking the attempt wrong.")


def render_distractor_rationale(
        misconception_values: Sequence[Tuple[str, str, float, str]]) -> Dict[str, Dict[str, str]]:
    """Build the `{label: {misconception, mis_relation}}` map the distractor gate re-executes.

    `misconception_values` items are (option_label, misconception_name, value, mis_relation).
    """
    out: Dict[str, Dict[str, str]] = {}
    for label, name, _value, mis_relation in misconception_values:
        out[label] = {"misconception": name, "mis_relation": mis_relation}
    return out


def common_mistake(misconception_values: Sequence[Tuple[str, str, float, str]]) -> str:
    """The single most likely error — by construction the FIRST misconception a binding declares, which is
    authored strongest-first (the wrong-operation errors ahead of the weaker coefficient slips)."""
    return misconception_values[0][1] if misconception_values else ""
