"""Depth tier — multi-concept, multi-step questions bound to certified knowledge.

WHY THIS EXISTS. Milestone 2 delivered correct questions, and every one of them was single-concept,
depth 1, difficulty `easy`. That is not the target. A question that applies one formula once tests
recall of that formula; it does not test whether a student can see that the quantity they need is two
or three certified relations away from the quantity they were given. This module generates the latter.

THE CONSTRUCTION. A `Chain` is an ordered DAG of certified relations wired output -> input, exactly the
shape `factory.gates.replay_steps` already executes:

    Q, t  --[Electric Current and Circuit: I = Q/t]-->  I
    I, R  --[Ohm's Law:                    V = I*R]-->  V
    V, I, t --[Joule's Law of Heating:   H = V*I*t]-->  H          (earned depth 3)

Every step names the certified concept that attests ITS relation, and every one of those is resolved and
grounded by `certgen.binding` against the frozen index — so a three-step question is three separately
certified claims, not one big assertion.

TWO INDEPENDENT ROUTES, WHICH MUST AGREE. Each chain also declares a `composed` relation written purely
in the given symbols (here `H = (Q/t)**2 * R * t`). That gives the engine two genuinely different ways to
reach the key:

    route A — execute the DAG step by step        (gates.replay_steps)
    route B — solve the single composed relation  (gates.independent_solve)

Route B never sees the intermediates; route A never sees the composed form. They are derived differently
and must produce the same number, which is a far stronger check than either alone. A chain whose composed
relation is not actually the algebraic composition of its steps is caught here rather than shipped.

WHAT MAKES THE DEPTH HONEST. `replay_steps` counts only steps that sympy actually solved from values
already in the environment, so a flat DAG whose steps all read the givens earns depth 1 no matter how many
steps are listed. Padding the step list cannot inflate depth, and `depth_agreement` (QUARANTINE) refuses
any item whose claimed depth differs from the earned one.

Deterministic, no model calls, read-only against every store.
"""
from __future__ import annotations

import hashlib
import json
import math
import re
import sqlite3
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional, Sequence, Tuple

from kie.qie.certgen import solution as SOL
from kie.qie.certgen.binding import (Given, Misconception, evidence_blob, normalize_evidence)
from kie.qie.factory import gates as G
from kie.qie.knowledge import difficulty as DIFF
from kie.qie.knowledge import planner as P


@dataclass(frozen=True)
class ChainStep:
    """One certified relation in the chain. `concept_name` must name a CERTIFIED concept at
    `taught_at_class` whose own evidence contains every `grounding` string."""
    out: str                         # the symbol this step produces
    relation: str                    # sympy-parseable, solved for `out`
    inputs: Tuple[str, ...]          # symbols consumed (givens or earlier outputs)
    concept_name: str
    discipline: str
    taught_at_class: int
    grounding: Tuple[str, ...]
    narrate: str                     # what this step does, for the worked solution
    out_unit: str = ""               # unit of the INTERMEDIATE this step produces (for the solution)


@dataclass(frozen=True)
class Chain:
    binding_id: str
    discipline: str                  # the question's primary discipline
    taught_at_class: int             # the class the QUESTION is set at
    steps: Tuple[ChainStep, ...]
    givens: Tuple[Given, ...]
    solve_for: str
    composed: str                    # the SAME computation as one relation in the given symbols only
    stems: Tuple[str, ...]
    answer_unit: str
    misconceptions: Tuple[Misconception, ...]
    quantity: str
    archetype: str = "multi_step_numerical"
    round_to: int = 2
    integer_answer: bool = True
    constants: Dict[str, float] = field(default_factory=dict)   # e.g. {"pi": 22/7} declared, never hidden
    accept: Optional[Callable[[Dict[str, float]], bool]] = field(default=None, compare=False)


@dataclass(frozen=True)
class ResolvedChain:
    chain: Chain
    concept_ids: Tuple[str, ...]           # one per step, in step order
    concept_names: Tuple[str, ...]
    chapter_ids: Tuple[str, ...]
    section_headings: Tuple[str, ...]
    subject: str                            # curriculum SOURCE subject of the question's class
    boundary: dict                          # merged out_of_scope evidence across the chain's concepts


# ══ THE CHAINS ════════════════════════════════════════════════════════════════════════════════════════
# Every `grounding` string was read out of the frozen certified index. A chain that stops grounding stops
# generating.

CHAINS: Tuple[Chain, ...] = (

    # ── Class 8 · cross-discipline application: geometry feeds a physical property (depth 2) ──────────
    Chain(
        "CHN_MAT8_PHY8_VOLUME_DENSITY", "Physics", 8,
        (ChainStep("V", "V = l * b * h", ("l", "b", "h"), "Volume of a Cuboid", "Mathematics", 8,
                   ("volume of a cuboid = l x b x h",),
                   "find the volume of the block from its three dimensions", "cm^3"),
         ChainStep("D", "D = m / V", ("m", "V"), "Density (Mass per Unit Volume)", "Physics", 8,
                   ("density = mass / volume",),
                   "use that volume, with the given mass, to find the density", "g/cm^3")),
        (Given("l", "cm", 2, 12), Given("b", "cm", 2, 10), Given("h", "cm", 2, 8),
         Given("m", "g", 100, 4000, step=100)),
        "D", "D = m / (l * b * h)",
        ("A rectangular metal block measures {l} cm by {b} cm by {h} cm and has a mass of {m} g. "
         "What is the density of the metal, in grams per cubic centimetre?",
         "A solid cuboidal brick of mass {m} g has length {l} cm, breadth {b} cm and height {h} cm. "
         "What is its density, in grams per cubic centimetre?",
         "A block of wax is a cuboid {l} cm long, {b} cm broad and {h} cm high, and it weighs {m} g on a "
         "balance. What is the density of the wax, in grams per cubic centimetre?"),
        "g/cm^3",
        (Misconception("divided the mass by only the base area, forgetting the height",
                       "D = m / (l * b)"),
         Misconception("inverted the final step, dividing volume by mass",
                       "D = (l * b * h) / m"),
         Misconception("added the three dimensions instead of multiplying them to get the volume",
                       "D = m / (l + b + h)", "procedural"),
         Misconception("used a height one centimetre short of the one given",
                       "D = m / (l * b * (h - 1))", "procedural")),
        "the density of the block",
    ),

    # ── Class 9 · work-energy theorem: work feeds kinetic energy, then speed (depth 2) ────────────────
    Chain(
        "CHN_PHY9_WORK_TO_SPEED", "Physics", 9,
        (ChainStep("W", "W = F * s", ("F", "s"), "Work Done by a Constant Force", "Physics", 9,
                   ("work done = force applied x displacement in the direction of the force",),
                   "find the work done by the force over the given displacement", "J"),
         # written in the direction it is APPLIED. As `W = m*v**2/2` solved for v, sympy returns BOTH roots
         # (-19 and +19) and `independent_solve` correctly reports `ambiguous` — a question may not have two
         # keys. A speed is the non-negative root, so the applied form is the one stated here.
         ChainStep("v", "v = sqrt(2 * W / m)", ("W", "m"),
                   "Kinetic Energy and the Work-Energy Theorem", "Physics", 9,
                   ("work-energy theorem (work done = change in kinetic energy)",),
                   "the block starts from rest, so by the work-energy theorem all of that work has become "
                   "kinetic energy; set W = (1/2)mv^2 and solve for the speed", "m/s")),
        (Given("F", "N", 4, 60, step=2), Given("s", "m", 2, 25), Given("m", "kg", 2, 20, step=2)),
        "v", "v = sqrt(2 * F * s / m)",
        ("A constant horizontal force of {F} N acts on a block of mass {m} kg, initially at rest on a "
         "frictionless floor, and pushes it {s} m in the direction of the force. What is the speed of the "
         "block, in metres per second, at the end of that displacement?",
         "A trolley of mass {m} kg starts from rest on a smooth level track. A steady force of {F} N acts "
         "on it along the track through a distance of {s} m. What speed, in metres per second, does the "
         "trolley reach?",
         "A block of mass {m} kg rests on a frictionless surface. A constant force of {F} N moves it {s} m "
         "along the direction of the force. What is its final speed, in metres per second?"),
        "m/s",
        (Misconception("stopped at the work done and reported it as the speed", "v = F * s"),
         Misconception("omitted the factor of 2 from the work-energy theorem", "v = sqrt(F * s / m)"),
         Misconception("forgot to take the square root, reporting the square of the speed",
                       "v = 2 * F * s / m", "procedural"),
         Misconception("divided by the mass twice", "v = sqrt(2 * F * s / m ** 2)", "procedural")),
        "the final speed of the block",
    ),

    # ── Class 10 · the depth-3 electricity chain: charge -> current -> p.d. -> heat ───────────────────
    Chain(
        "CHN_PHY10_CHARGE_TO_HEAT", "Physics", 10,
        (ChainStep("I", "I = Q / t", ("Q", "t"), "Electric Current and Circuit", "Physics", 10,
                   ("electric current as rate of flow of charge (i = q/t)",),
                   "find the steady current from the charge that flows and the time it takes", "A"),
         ChainStep("Vp", "Vp = I * R", ("I", "R"), "Ohm's Law", "Physics", 10,
                   ("v = ir",),
                   "apply Ohm's law to that current to find the potential difference across the resistor", "V"),
         ChainStep("H", "H = Vp * I * t", ("Vp", "I", "t"),
                   "Heating Effect of Electric Current (Joule's Law of Heating)", "Physics", 10,
                   ("heat produced h = vit",),
                   "apply Joule's law of heating using the potential difference, the current and the time", "J")),
        (Given("Q", "C", 20, 200, step=10), Given("t", "s", 2, 20, step=2), Given("R", "ohm", 2, 30, step=2)),
        "H", "H = (Q / t) ** 2 * R * t",
        ("A charge of {Q} C flows steadily through a resistor of resistance {R} ohm in {t} s. "
         "How much heat, in joule, is produced in the resistor in that time?",
         "In {t} s, a steady flow of {Q} C of charge passes through a heating element of resistance "
         "{R} ohm. What quantity of heat, in joule, is developed in the element?",
         "A resistor of {R} ohm carries a steady current such that {Q} C of charge passes through it in "
         "{t} s. What is the heat produced, in joule, during this interval?"),
        "J",
        (Misconception("used the charge as though it were the current, skipping I = Q/t",
                       "H = Q ** 2 * R * t"),
         Misconception("forgot to square the current in Joule's law", "H = (Q / t) * R * t"),
         Misconception("omitted the time factor, computing a power rather than a heat",
                       "H = (Q / t) ** 2 * R", "procedural"),
         Misconception("divided by the resistance instead of multiplying by it",
                       "H = (Q / t) ** 2 * t / R", "procedural")),
        "the heat produced in the resistor",
    ),

    # ── Class 10 · arithmetic progression: nth term feeds the sum (depth 2) ───────────────────────────
    Chain(
        "CHN_MAT10_AP_TERM_TO_SUM", "Mathematics", 10,
        (ChainStep("an", "an = a + (n - 1) * d", ("a", "n", "d"), "nth Term of an AP", "Mathematics", 10,
                   ("formula a_n = a + (n - 1)d",),
                   "find the nth term of the progression", "1"),
         ChainStep("S", "S = n * (a + an) / 2", ("n", "a", "an"),
                   "Sum of First n Terms of an AP", "Mathematics", 10,
                   ("formula s_n = (n/2)[2a + (n-1)d]",),
                   "the sum of n terms is n/2 times the sum of the first and last terms; use the nth term "
                   "just found as the last term", "1")),
        (Given("a", "1", 2, 30), Given("d", "1", 2, 12), Given("n", "1", 6, 25)),
        "S", "S = n * (2 * a + (n - 1) * d) / 2",
        ("The first term of an arithmetic progression is {a} and its common difference is {d}. "
         "What is the sum of its first {n} terms?",
         "A stack of logs has {a} logs in the bottom row, and each row above it has {d} more logs than the "
         "row below. What is the total number of logs in the first {n} rows?",
         "A savings plan requires a deposit of Rs {a} in the first month, increasing by a fixed Rs {d} "
         "every month thereafter. What is the total amount, in rupees, deposited over {n} months?"),
        "1",
        (Misconception("reported the nth term instead of the sum of n terms", "S = a + (n - 1) * d"),
         Misconception("used n instead of (n - 1) steps when finding the last term",
                       "S = n * (2 * a + n * d) / 2", "procedural"),
         Misconception("forgot to halve, summing n copies of (first + last)",
                       "S = n * (2 * a + (n - 1) * d)", "procedural"),
         Misconception("multiplied the first term by n, ignoring the common difference entirely",
                       "S = n * a", "procedural")),
        "the sum of the first n terms",
    ),

    # ── Class 11 · kinematics feeds kinetic energy — the classic JEE two-concept item (depth 2) ───────
    Chain(
        "CHN_PHY11_KINEMATICS_TO_KE", "Physics", 11,
        (ChainStep("v", "v = u + a * t", ("u", "a", "t"),
                   "Kinematic Equations for Uniformly Accelerated Motion", "Physics", 11,
                   ("v = v0 + a t",),
                   "use the kinematic equation for uniformly accelerated motion to find the final velocity", "m/s"),
         ChainStep("K", "K = m * v ** 2 / 2", ("m", "v"), "Kinetic Energy", "Physics", 11,
                   ("(1/2) m v^2",),
                   "substitute that velocity into the kinetic-energy expression", "J")),
        (Given("u", "m/s", 0, 12, step=2), Given("a", "m/s^2", 1, 8), Given("t", "s", 2, 10),
         Given("m", "kg", 2, 20, step=2)),
        "K", "K = m * (u + a * t) ** 2 / 2",
        ("A body of mass {m} kg moving at {u} m/s is acted upon by a constant acceleration of {a} m/s^2 "
         "for {t} s. What is its kinetic energy, in joule, at the end of this interval?",
         "A trolley of mass {m} kg has an initial speed of {u} m/s along a straight track and accelerates "
         "uniformly at {a} m/s^2 for {t} s. What is its kinetic energy, in joule, at the end of that time?",
         "A particle of mass {m} kg starts with a velocity of {u} m/s and undergoes a uniform acceleration "
         "of {a} m/s^2 for {t} s. What is its kinetic energy, in joule, at that instant?"),
        "J",
        (Misconception("used the INITIAL velocity instead of the final one", "K = m * u ** 2 / 2"),
         Misconception("omitted the factor of one-half", "K = m * (u + a * t) ** 2"),
         Misconception("forgot to square the final velocity", "K = m * (u + a * t) / 2", "procedural"),
         Misconception("used the acceleration in place of the velocity change, dropping the time",
                       "K = m * (u + a) ** 2 / 2", "procedural")),
        "the kinetic energy at the end of the interval",
    ),

    # ── Class 10 · the DEPTH-4 chain: charge -> current -> p.d. -> power -> energy ────────────────────
    # Authored to reach the `hard` band HONESTLY. No item the engine had ever produced reached it, because
    # `difficulty.predict` needs depth 4+ and the deepest chain was 3. This adds a fourth dependent step
    # rather than re-weighting the difficulty model — the band is earned by execution, and `replay_steps`
    # refuses any padding that does not actually feed the next step.
    Chain(
        "CHN_PHY10_CHARGE_TO_ENERGY", "Physics", 10,
        (ChainStep("I", "I = Q / t", ("Q", "t"), "Electric Current and Circuit", "Physics", 10,
                   ("electric current as rate of flow of charge (i = q/t)",),
                   "find the steady current from the charge that flows and the time it takes", "A"),
         ChainStep("Vp", "Vp = I * R", ("I", "R"), "Ohm's Law", "Physics", 10,
                   ("v = ir",),
                   "apply Ohm's law to that current to find the potential difference across the resistor",
                   "V"),
         ChainStep("Pw", "Pw = Vp * I", ("Vp", "I"), "Electric Power", "Physics", 10,
                   ("p = vi = i^2 r = v^2/r",),
                   "use the potential difference and the current to find the power dissipated", "W"),
         ChainStep("En", "En = Pw * t", ("Pw", "t"), "Electric Power", "Physics", 10,
                   ("commercial unit kilowatt-hour (kw h)",),
                   "multiply that power by the time for which it acts to obtain the energy transferred",
                   "J")),
        (Given("Q", "C", 20, 200, step=10), Given("t", "s", 2, 20, step=2),
         Given("R", "ohm", 2, 30, step=2)),
        "En", "En = Q ** 2 * R / t",
        ("A charge of {Q} C passes steadily through a resistor of resistance {R} ohm in {t} s. "
         "How much electrical energy, in joule, is transferred to the resistor in that time?",
         "In {t} s a steady flow of {Q} C of charge passes through a heating element of resistance "
         "{R} ohm. What quantity of electrical energy, in joule, is converted in the element?",
         "A resistor of {R} ohm carries a steady current such that {Q} C of charge passes through it in "
         "{t} s. What is the total electrical energy, in joule, transferred during this interval?"),
        "J",
        (Misconception("used the charge as though it were the current, skipping I = Q/t",
                       "En = Q ** 2 * R * t"),
         Misconception("stopped at the power and reported it as the energy",
                       "En = Q ** 2 * R / t ** 2"),
         Misconception("omitted the resistance from the energy expression",
                       "En = Q ** 2 / t", "procedural"),
         Misconception("divided by the time twice instead of once",
                       "En = Q ** 2 * R / t ** 3", "procedural")),
        "the electrical energy transferred to the resistor",
    ),
)


# ══ RESOLUTION ════════════════════════════════════════════════════════════════════════════════════════
class ChainRefused(Exception):
    """A chain whose every step cannot be grounded is never issued."""


def _certified(iconn: sqlite3.Connection, discipline: str, cls: int, name: str) -> List[dict]:
    return [c for c in P.certified_universe_by_discipline(iconn, discipline, [cls])
            if c["canonical_name"] == name]


def _strip_parens(s: str) -> str:
    """'uniform (constant) acceleration' -> 'uniform constant acceleration', so an in-scope phrase written
    with a parenthetical gloss still contains the token a reader would extract from it."""
    return re.sub(r"\s+", " ", (s or "").replace("(", " ").replace(")", " ")).strip()


def exclusion_claim(sentence: str) -> str:
    """Delegates to `gates._claim_clause` — ONE implementation, in the gate, so every caller benefits.

    Kept as a named re-export because the depth tier's tests pin this behaviour and because the intent is
    clearer at the call site than a private gate helper would be.

    Original note, retained because it records why the gate needed repairing at all:
    The part of an out-of-scope record that states WHAT is excluded, dropping the rationale that says WHY.

    The certified index writes boundary exclusions as `<claim> - <rationale>`, e.g.

        "non-uniform (variable) acceleration - these equations are derived for uniformly accelerated
         motion only, and the average-velocity form (v0 + v)/2 is flagged in the evidence as holding for
         constant acceleration only"

    `gates._boundary_checks` turns a sentence into sliding bigrams. Fed the whole record above it produces
    eleven of them — including `flagged evidence`, `holding constant`, `evidence holding` and, fatally,
    `constant acceleration`. The gate then quarantined a Class-11 kinematics question for containing the
    phrase "constant acceleration", which the SAME record lists in scope as "rectilinear motion with
    UNIFORM (constant) acceleration".

    The exclusion itself is real and must keep being checked; it is the *rationale clause* that generates
    noise, because it is prose about the exclusion rather than a statement of it. Passing the claim alone
    gives the gate MORE precise evidence, not less: "non-uniform (variable) acceleration" would still fire
    on a stem that actually used variable acceleration. A record with no separator is passed through whole.

    This is a workaround at the caller, not a repair. The underlying defect is W7 — bigram extraction over
    sentence-length curriculum prose — and it lives in `factory/gates.py`, which the factory lane also
    depends on, so fixing it there is a separate, separately-reviewed change.
    """
    return G._claim_clause(sentence)


def chain_boundary_terms(out_of_scope: Sequence[str], chain_concept_names: Sequence[str],
                         in_scope: Sequence[str] = ()) -> List[str]:
    """Merge the chain's out-of-scope evidence WITHOUT flagging the question for its own subject matter.

    The `curriculum_boundary` gate derives short lexical tokens from boundary prose and scans the stem for
    them. That works for a single-concept item, where the gate additionally drops tokens matching the
    spec's own concept title. It breaks for a chain, because a chain has several concepts and the spec can
    only name one.

    Measured: the Class-11 kinematics -> kinetic-energy item was quarantined for
    `above-class terms present: ['constant acceleration', 'kinetic energy']`. Both phrases came from the
    chain's OWN concepts — "…holding for constant acceleration only" (Kinematic Equations) and "treating
    kinetic energy as a vector" (Kinetic Energy). Those sentences describe a narrower sense in which the
    topic is bounded; reduced to tokens they become the topic itself, so the gate flagged a Class-11
    question for the crime of being about kinetic energy.

    So an out-of-scope sentence is dropped when it names a concept that this chain deliberately includes —
    that concept is certified, at or below this class, and in scope by construction. Every other
    out-of-scope sentence is kept and still checked, so the gate loses no genuine above-class coverage.
    """
    names = [normalize_evidence(n) for n in chain_concept_names if n]
    in_scope_blob = normalize_evidence(_strip_parens(" | ".join(str(s) for s in in_scope)))
    kept: List[str] = []
    for sentence in out_of_scope:
        # pass the FULL record through — `gates._boundary_checks` now extracts the claim itself (W7), so
        # truncating here would duplicate work and hide the gate's own behaviour from these items
        claim = str(sentence)
        c = normalize_evidence(exclusion_claim(sentence))
        # (1) the claim names a concept this chain deliberately includes — that concept is certified, at or
        #     below this class, and in scope by construction, so it cannot be an above-class term here
        if any(n and n in c for n in names):
            continue
        # (2) the claim is itself a phrase the certified record declares IN scope (a parenthetical gloss
        #     such as "UNIFORM (constant) acceleration" still counts) — an exclusion cannot contradict the
        #     same record's inclusion
        if c and normalize_evidence(_strip_parens(claim)) in in_scope_blob:
            continue
        kept.append(claim)
    return kept


def resolve_one(iconn: sqlite3.Connection, ch: Chain) -> Tuple[Optional[ResolvedChain], List[str]]:
    v: List[str] = []
    ids: List[str] = []
    names: List[str] = []
    chapters: List[str] = []
    headings: List[str] = []
    oos: List[str] = []
    ins: List[str] = []
    subject = ""

    for i, st in enumerate(ch.steps):
        matches = _certified(iconn, st.discipline, st.taught_at_class, st.concept_name)
        if not matches:
            v.append(f"unresolved_concept[step {i}]: no CERTIFIED {st.discipline} concept named "
                     f"{st.concept_name!r} at class {st.taught_at_class}")
            continue
        if len(matches) > 1:
            v.append(f"ambiguous_concept[step {i}]: {len(matches)} matches for {st.concept_name!r}")
            continue
        kc = matches[0]
        blob = evidence_blob(kc)
        for term in st.grounding:
            if normalize_evidence(term) not in blob:
                v.append(f"ungrounded_relation[step {i}]: {st.relation!r} claims {term!r} but the "
                         f"certified evidence for {kc['concept_id']} does not contain it")
        # BOUNDARY: no step may need a concept taught ABOVE the class the question is set at. This is the
        # same rule planner.check_plan applies to composition partners, enforced here for chains.
        if st.taught_at_class > ch.taught_at_class:
            v.append(f"above_class_step[step {i}]: {st.concept_name!r} is taught at class "
                     f"{st.taught_at_class}, above the question's class {ch.taught_at_class}")
        ids.append(kc["concept_id"])
        names.append(kc["canonical_name"])
        chapters.append(kc["chapter_id"])
        headings.append(kc.get("section_heading") or "")
        oos += [str(t) for t in ((kc.get("boundary") or {}).get("out_of_scope") or [])]
        ins += [str(t) for t in ((kc.get("boundary") or {}).get("in_scope") or [])]
        ins += [str(t) for t in (kc.get("sub_concepts") or [])]
        if st.taught_at_class == ch.taught_at_class and st.discipline == ch.discipline:
            subject = kc["subject"]

    # a CHAIN must be a chain: at least two steps and at least two DISTINCT certified concepts
    if len(ch.steps) < 2:
        v.append("not_a_chain: the depth tier requires at least two steps")
    if len(set(ids)) < 2 and not v:
        v.append("not_multi_concept: the steps resolve to fewer than two distinct certified concepts")

    # the DAG must actually be serial — at least one step must consume another step's OUTPUT, or the
    # 'chain' is really parallel single-step work and replay_steps will (correctly) earn depth 1
    produced = {st.out for st in ch.steps}
    if not any(set(st.inputs) & produced for st in ch.steps):
        v.append("flat_dag: no step consumes another step's output — earned depth would be 1")

    # scenarios must be distinct, and must bind exactly the givens
    declared = {g.symbol for g in ch.givens}
    for i, stem in enumerate(ch.stems):
        ph = set(re.findall(r"\{(\w+)\}", stem))
        if ph - declared:
            v.append(f"stem_unbound_symbol[{i}]: {sorted(ph - declared)}")
        if declared - ph:
            v.append(f"stem_missing_given[{i}]: {sorted(declared - ph)}")
    if len({normalize_evidence(s) for s in ch.stems}) != len(ch.stems):
        v.append("duplicate_scenarios: every authored stem must be a genuinely different scenario")

    if v:
        return None, v
    return ResolvedChain(ch, tuple(ids), tuple(names), tuple(chapters), tuple(headings),
                         subject or "Science",
                         {"out_of_scope": chain_boundary_terms(oos, names, ins),
                          "in_scope": ins}), []


def resolve(iconn: sqlite3.Connection, chains: Sequence[Chain] = CHAINS,
            strict: bool = False) -> Tuple[List[ResolvedChain], Dict[str, List[str]]]:
    ok: List[ResolvedChain] = []
    refusals: Dict[str, List[str]] = {}
    for ch in chains:
        r, why = resolve_one(iconn, ch)
        if r is not None:
            ok.append(r)
        else:
            refusals[ch.binding_id] = why
    if strict and refusals:
        raise ChainRefused(f"{len(refusals)} chain(s) refused: {refusals}")
    return ok, refusals
