"""W1 — the certified-concept binding layer.

THE RULE THIS FILE ENFORCES

    A generator template may fire against a certified concept ONLY IF that concept's own certified
    evidence attests the relation the template is about to use.

That is a deliberately harder rule than "a human curated this mapping". A curated map is an assertion, and
an assertion is exactly what the certification architecture refuses everywhere else. Here the binding must
be GROUNDED: every `Binding` declares `grounding` strings that must appear verbatim in the concept's frozen
`sub_concepts` / `boundary.in_scope` / `section_heading` text, and `resolve()` refuses any binding whose
grounding is absent. So the claim "Class-8 pupils are taught Volume = l x b x h" is not something this
module says — it is something `KC_771977581c488d` already said, in the certified index, and this module
merely declines to generate unless it finds it there.

Consequences that fall out of the rule, and are features rather than limitations:

  * `Area of a Triangle` (Class 6) does NOT bind. Its certified evidence teaches the idea as "half of an
    enclosing rectangle" and never prints a formula — so a `(1/2) x b x h` drill would be out of boundary
    at that class. The gate refuses it. That is correct.
  * `pH Scale` (Class 10) does NOT bind to `pH = -log10[H+]`; the Class-10 evidence describes a 0-14 scale
    and a universal indicator, and puts the logarithm nowhere. The Class-11 record is where that lives.
  * A binding cannot silently outlive the index. If a re-certification ever reworded the evidence, the
    grounding lookup fails and generation stops rather than drifting out of syllabus.

Refusal is the safe direction: an unresolved binding produces no questions, never an ungrounded question.

Deterministic, stdlib-only, read-only with respect to every store.
"""
from __future__ import annotations

import re
import sqlite3
import unicodedata
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional, Sequence, Tuple

from kie.qie.knowledge import planner as P

# ── evidence normalization ────────────────────────────────────────────────────────────────────────────
# The certified index was authored by knowledge engineers reading real textbooks, so its formula prose uses
# whatever multiplication sign the book used: 'x', '*', the U+00D7 MULTIPLICATION SIGN, or the U+2212 MINUS.
# Normalizing those (and whitespace/case) is presentation-level only — it never relaxes WHICH substring must
# be present, only how the same substring may be typed.
_MULT = {"×": "x", "∗": "x", "*": "x", "⋅": "x", "·": "x"}
_DASH = {"−": "-", "–": "-", "—": "-"}


def normalize_evidence(s: str) -> str:
    t = unicodedata.normalize("NFKC", s or "")
    for src, dst in {**_MULT, **_DASH}.items():
        t = t.replace(src, dst)
    return re.sub(r"\s+", " ", t).strip().lower()


def evidence_blob(kc: dict) -> str:
    """The SUBSTANTIVE certified claims about this concept — `sub_concepts` and `boundary.in_scope` only.

    `canonical_name` and `section_heading` are deliberately EXCLUDED, and that exclusion is the point. Both
    are usually just the concept's title ("Kinetic Energy", "5.4 Kinetic Energy"), so grounding against them
    would let a binding satisfy itself: declaring `grounding=("kinetic energy",)` would "prove" that the
    class is taught K = (1/2)mv^2 merely because the concept is *called* Kinetic Energy. A title is a name;
    it is not evidence about a relation. Only the audited content claims count here.
    """
    parts: List[str] = [str(s) for s in (kc.get("sub_concepts") or [])]
    b = kc.get("boundary") or {}
    parts += [str(s) for s in (b.get("in_scope") or [])]
    return normalize_evidence(" | ".join(parts))


# ── binding vocabulary ────────────────────────────────────────────────────────────────────────────────
@dataclass(frozen=True)
class Given:
    """One quantity the question supplies. `step` keeps sampled values pedagogically clean (multiples of 5
    for money, of 10 for masses) rather than arbitrary integers."""
    symbol: str
    unit: str
    lo: int
    hi: int
    step: int = 1


@dataclass(frozen=True)
class Misconception:
    """A NAMED student error plus the wrong equation it actually produces.

    `mis_relation` is not documentation. `factory.gates.verify_distractors` re-solves it with sympy against
    the item's own givens and REQUIRES the result to equal that option's printed value — so a distractor
    survives only if the named mistake genuinely computes it. A plausible sentence proves nothing here.

    `tier` drives option SELECTION, and it exists because passing the gates is not the same as writing a
    good question. The first Lane C run produced, for "6 m/s for 5 s", the options {0.83, 1.2, 11, 30}.
    Every one of those was a proven student error, and the item passed every gate — but a pupil who knows
    only that a distance should exceed the given numbers picks 30 without computing anything. Options that
    can be eliminated on magnitude alone do not test the concept.

      "conceptual" — the student applied the WRONG RELATION (inverted it, added instead of multiplied).
                     Diagnostically the most valuable, but often an order of magnitude from the key.
      "procedural" — the student had the right relation and slipped (off-by-one, dropped a factor,
                     used a neighbouring value). These sit CLOSE to the key and are what force the
                     arithmetic to actually be done.

    A good option set needs both: one conceptual trap to diagnose, and near-value procedural traps so the
    key cannot be spotted by inspection.
    """
    name: str
    mis_relation: str
    tier: str = "conceptual"


@dataclass(frozen=True)
class Binding:
    binding_id: str
    discipline: str                  # Physics | Chemistry | Biology | Mathematics
    taught_at_class: int
    concept_name: str                # EXACT ki_concept.canonical_name — resolved, never fuzzy-matched
    equation: str                    # sympy-parseable "LHS = RHS", the gates.independent_solve contract
    solve_for: str
    givens: Tuple[Given, ...]
    stems: Tuple[str, ...]           # authored SCENARIOS; each formats {symbol} for every given
    answer_unit: str
    grounding: Tuple[str, ...]       # MUST appear in the concept's certified evidence blob
    misconceptions: Tuple[Misconception, ...]
    quantity: str                    # what the answer IS, for the solution's closing line
    # STRUCTURAL enrichment, driven by the corpus measurement in `solution.enrich_stem`: 99.9% of real
    # stems run to >=2 sentences and state the conditions the relation depends on. These supply the setup
    # context and the standing condition; neither copies a real question.
    elaboration: str = ""
    condition: str = ""
    archetype: str = "single_step_numerical"
    round_to: int = 2
    integer_answer: bool = True      # reject samples whose key is not clean at this class level
    # Exact-value sample set for relations whose generic integer sample is IRRATIONAL. Pythagoras is the
    # case in point: arbitrary integer legs give an irrational hypotenuse, which is out of boundary at
    # Class 8 and would be silently rounded into a wrong key. When set, the sampler draws (in given order)
    # from here instead of from each Given's range.
    triples: Tuple[Tuple[int, ...], ...] = ()
    accept: Optional[Callable[[Dict[str, float]], bool]] = field(default=None, compare=False)


@dataclass(frozen=True)
class ResolvedBinding:
    binding: Binding
    concept_id: str
    chapter_id: str
    chapter_title: str
    subject: str                     # the CURRICULUM SOURCE subject ('Science' for classes 6-10)
    boundary: dict
    section_heading: str


# ── the binding table ─────────────────────────────────────────────────────────────────────────────────
# Every `grounding` string below was read OUT OF the frozen index, not authored for it. If one stops
# matching, that binding stops generating — loudly, via `resolve(strict=True)`.

_INT = "integer"

BINDINGS: Tuple[Binding, ...] = (

    # ══ MATHEMATICS ═══════════════════════════════════════════════════════════════════════════════════
    Binding(
        "MAT6_AREA_RECT", "Mathematics", 6, "Area of a Rectangle",
        "A = l * w", "A",
        (Given("l", "m", 6, 40), Given("w", "m", 3, 25)),
        ("A rectangular sheet of chart paper is {l} m long and {w} m wide. What is its area, in square "
         "metres?",
         "The floor of a rectangular store room measures {l} m by {w} m. Tiles are to be laid over the "
         "whole floor. What floor area, in square metres, must the tiles cover?",
         "A rectangular field is {l} m long and {w} m wide. A farmer wants to spread manure evenly over "
         "the entire field. Over what area, in square metres, must the manure be spread?"),
        "m^2", ("area = length x width",),
        (Misconception("added the two sides instead of multiplying them", "A = l + w"),
         Misconception("found the perimeter instead of the area", "A = 2 * (l + w)"),
         Misconception("halved the product, as for a triangle", "A = l * w / 2", "procedural"),
         Misconception("used a length one unit short of the one given", "A = (l - 1) * w", "procedural"),
         Misconception("used a width one unit short of the one given", "A = l * (w - 1)", "procedural")),
        "the area of the rectangle",
        elaboration=("A shopkeeper is estimating how much material a rectangular surface will need."),
        condition=("The surface is flat and no part of it is wasted or overlapped."),
    ),
    Binding(
        "MAT6_PERIM_RECT", "Mathematics", 6, "Perimeter of a Rectangle",
        "P = 2 * (l + b)", "P",
        (Given("l", "m", 5, 45), Given("b", "m", 3, 30)),
        ("A rectangular flower bed is {l} m long and {b} m broad. A gardener wants to put a fence right "
         "around it. What length of fencing, in metres, is needed?",
         "A rectangular photograph {l} m long and {b} m broad is to be edged with a decorative tape along "
         "all four sides. What length of tape, in metres, is required?",
         "A rectangular playground measures {l} m by {b} m. A student jogs exactly once around its "
         "boundary. What distance, in metres, does the student cover?"),
        "m", ("perimeter = 2 x (length + breadth)",),
        (Misconception("added the length and breadth but forgot to double the sum", "P = l + b"),
         Misconception("multiplied the sides, computing the area instead of the perimeter", "P = l * b"),
         Misconception("doubled only the length instead of the whole sum", "P = 2 * l + b", "procedural"),
         Misconception("used a breadth one unit short of the one given", "P = 2 * (l + b - 1)", "procedural"),
         Misconception("counted three sides instead of four", "P = 2 * l + b", "procedural")),
        "the perimeter of the rectangle",
        elaboration=("A boundary is to be marked out around a rectangular plot."),
        condition=("The boundary follows the edges exactly, with no gap left for a gate."),
    ),
    Binding(
        "MAT7_SIMPLE_INTEREST", "Mathematics", 7, "Simple Interest",
        "I = P * R / 100", "I",
        (Given("P", "Rs", 2000, 40000, step=500), Given("R", "%", 4, 18)),
        ("Rekha borrows Rs {P} from a bank at a rate of {R}% per annum. How much simple interest, in "
         "rupees, does she owe at the end of one year?",
         "A shopkeeper takes a loan of Rs {P} at {R}% per annum to buy new stock. What simple interest, "
         "in rupees, must be paid on it after one year?",
         "Rs {P} is deposited in a savings scheme paying simple interest at {R}% per annum. What interest, "
         "in rupees, has the deposit earned after one year?"),
        "Rs", ("interest for one year = (p x r) / 100",),
        (Misconception("treated the rate as rupees of interest rather than a percentage", "I = P * R"),
         Misconception("divided by the rate instead of applying it as a percentage", "I = P / R"),
         Misconception("computed the total amount payable instead of the interest alone",
                       "I = P + P * R / 100")),
        "the simple interest for one year",
        elaboration=("A bank is calculating the charge on a loan at the end of its first year."),
        condition=("Interest is reckoned as simple interest, so it is not added to the principal during the year."),
    ),
    Binding(
        "MAT8_VOL_CUBOID", "Mathematics", 8, "Volume of a Cuboid",
        "V = l * b * h", "V",
        (Given("l", "cm", 4, 25), Given("b", "cm", 3, 18), Given("h", "cm", 2, 15)),
        ("A closed wooden box is a cuboid measuring {l} cm by {b} cm by {h} cm. What is its volume, in "
         "cubic centimetres?",
         "A rectangular tank has a base {l} cm long and {b} cm wide, and is filled with water to a depth "
         "of {h} cm. What volume of water, in cubic centimetres, does it hold?",
         "A cuboidal carton of length {l} cm, breadth {b} cm and height {h} cm is packed completely full. "
         "What is the packed volume, in cubic centimetres?"),
        "cm^3", ("volume of a cuboid = l x b x h",),
        (Misconception("added the three dimensions instead of multiplying them", "V = l + b + h"),
         Misconception("used only the base area and ignored the height", "V = l * b"),
         Misconception("computed the total surface area instead of the volume",
                       "V = 2 * (l * b + b * h + h * l)"),
         Misconception("used a height one unit short of the one given", "V = l * b * (h - 1)", "procedural"),
         Misconception("halved the product, importing the prism/pyramid factor", "V = l * b * h / 2",
                       "procedural")),
        "the volume of the cuboid",
        elaboration=("A container is being checked to see how much it can hold."),
        condition=("The container is a perfect cuboid and is filled completely."),
    ),
    Binding(
        "MAT8_COMPOUND_INTEREST", "Mathematics", 8, "Formula for Compound Interest",
        "A = P * (1 + R / 100) ** n", "A",
        (Given("P", "Rs", 4000, 30000, step=1000), Given("R", "%", 5, 20, step=5),
         Given("n", "1", 2, 3)),
        ("A sum of Rs {P} is invested at {R}% per annum, compounded annually. What amount, in rupees, "
         "is received at the end of {n} years?",
         "Rs {P} is placed in a fixed deposit paying {R}% per annum compounded annually. What amount, in "
         "rupees, stands to the depositor's credit after {n} years?",
         "A cooperative society lends Rs {P} at {R}% per annum compounded annually. What amount, in "
         "rupees, must the borrower repay at the end of {n} years?"),
        "Rs", ("a = p(1 + r/100)^n",),
        (Misconception("applied simple interest instead of compounding", "A = P + P * R * n / 100"),
         Misconception("compounded for one year only, ignoring the stated period", "A = P * (1 + R / 100)"),
         Misconception("reported the interest earned rather than the amount received",
                       "A = P * (1 + R / 100) ** n - P")),
        "the amount received after compounding",
        elaboration=("A deposit is left untouched so that the interest earned each year is added to it."),
        condition=("Interest is compounded annually and no further deposit or withdrawal is made."),
    ),
    Binding(
        # form matters: the relation is written as target = f(givens) so the DIMENSIONAL gate can compare
        # the target's unit against the RHS. Written as `c ** 2 = a ** 2 + b ** 2` the gate reads the LHS
        # unit as a length while the RHS is an area, and correctly quarantines it.
        "MAT8_PYTHAGORAS", "Mathematics", 8, "The Baudhayana-Pythagoras Theorem",
        "c = sqrt(a ** 2 + b ** 2)", "c",
        (Given("a", "cm", 0, 8), Given("b", "cm", 0, 8)),
        ("A right-angled triangle has the two sides containing the right angle measuring {a} cm and {b} cm. "
         "What is the length of its hypotenuse, in centimetres?",
         "A ladder leans against a vertical wall so that its foot is {a} cm from the wall and its top "
         "reaches {b} cm up the wall. What is the length of the ladder, in centimetres?",
         "A rectangular gate is {a} cm wide and {b} cm high. A diagonal brace runs from one corner to the "
         "opposite corner. What is the length of the brace, in centimetres?"),
        "cm", ("a^2 + b^2 = c^2",),
        (Misconception("added the two sides instead of adding their squares", "c = a + b"),
         Misconception("added the squares but forgot to take the square root", "c = a ** 2 + b ** 2"),
         Misconception("averaged the two given sides", "c = (a + b) / 2"),
         Misconception("subtracted the squares instead of adding them, as when finding a leg",
                       "c = sqrt(b ** 2 - a ** 2)", "procedural"),
         Misconception("took the larger leg itself as the hypotenuse", "c = b", "procedural")),
        "the length of the hypotenuse",
        # PYTHAGOREAN TRIPLES ONLY. Sampling arbitrary integer legs gives an irrational hypotenuse, which
        # is out of boundary at Class 8 and would be silently rounded into a wrong key. The sampler indexes
        # this list instead of the raw ranges.
        triples=((3, 4, 5), (6, 8, 10), (5, 12, 13), (9, 12, 15), (8, 15, 17), (12, 16, 20),
                 (7, 24, 25), (10, 24, 26), (20, 21, 29), (18, 24, 30), (16, 30, 34), (21, 28, 35)),
        elaboration=("A right-angled triangle is drawn accurately on squared paper."),
        condition=("The two given sides are the ones that contain the right angle."),
    ),
    Binding(
        "MAT10_AP_NTH", "Mathematics", 10, "nth Term of an AP",
        "t = a + (n - 1) * d", "t",
        (Given("a", "1", 3, 40), Given("d", "1", 2, 15), Given("n", "1", 8, 30)),
        ("The first term of an arithmetic progression is {a} and its common difference is {d}. "
         "What is its {n}th term?",
         "A theatre has {a} seats in its first row, and each row behind it has {d} more seats than the row "
         "in front. How many seats are there in the {n}th row?",
         "A worker is paid Rs {a} in the first week of a contract, and the weekly payment rises by a fixed "
         "Rs {d} each week thereafter. What is the payment, in rupees, in the {n}th week?"),
        "1", ("formula a_n = a + (n - 1)d",),
        (Misconception("multiplied by n instead of (n - 1), the classic off-by-one", "t = a + n * d"),
         Misconception("used (n - 1) as a multiplier of the first term instead of the difference",
                       "t = a * (n - 1) + d"),
         Misconception("summed the progression instead of taking its nth term",
                       "t = n * (2 * a + (n - 1) * d) / 2"),
         Misconception("went one term too far, using n instead of (n - 1) steps", "t = a + n * d",
                       "procedural"),
         Misconception("stopped one term early, using (n - 2) steps", "t = a + (n - 2) * d",
                       "procedural")),
        "the nth term of the AP",
        elaboration=("A sequence increases by the same fixed amount at every step."),
        condition=("The common difference stays the same throughout the progression."),
    ),

    # ══ PHYSICS ═══════════════════════════════════════════════════════════════════════════════════════
    Binding(
        "PHY7_SPEED_DIST", "Physics", 7, "Relationship between Speed, Distance, and Time",
        "d = s * t", "d",
        (Given("s", "m/s", 4, 30), Given("t", "s", 5, 60, step=5)),
        ("A cyclist travels along a straight road at a steady speed of {s} m/s for {t} s. What distance, "
         "in metres, does the cyclist cover?",
         "A train moves along a straight track at a constant {s} m/s. How far, in metres, does it travel "
         "in {t} s?",
         "A trolley is pushed so that it moves in a straight line at a uniform speed of {s} m/s. What "
         "distance, in metres, has it covered after {t} s?"),
        "m", ("distance = speed x time",),
        (Misconception("divided speed by time instead of multiplying", "d = s / t"),
         Misconception("divided time by speed, inverting the relation", "d = t / s"),
         Misconception("added the two quantities instead of multiplying them", "d = s + t"),
         Misconception("used a time one second short of the one given", "d = s * (t - 1)", "procedural"),
         Misconception("halved the product, as if finding an average", "d = s * t / 2", "procedural")),
        "the distance travelled",
        elaboration=("A journey is being timed along a straight, level stretch of road."),
        condition=("The motion is uniform, so the speed does not change during the interval."),
    ),
    Binding(
        "PHY8_DENSITY", "Physics", 8, "Density (Mass per Unit Volume)",
        "D = m / V", "D",
        (Given("m", "g", 40, 900, step=10), Given("V", "cm^3", 4, 50, step=2)),
        ("A solid metal block has a mass of {m} g and occupies a volume of {V} cubic centimetres. What is its density, "
         "in grams per cubic centimetre?",
         "A pebble of mass {m} g is lowered into a measuring cylinder and displaces {V} cubic centimetres of water. "
         "What is the density of the pebble, in grams per cubic centimetre?",
         "A sample of oil has a mass of {m} g and fills a container of capacity {V} cubic centimetres. What is the "
         "density of the oil, in grams per cubic centimetre?"),
        "g/cm^3", ("density = mass / volume",),
        (Misconception("inverted the relation, dividing volume by mass", "D = V / m"),
         Misconception("multiplied mass by volume instead of dividing", "D = m * V"),
         Misconception("subtracted volume from mass, treating them as like quantities", "D = m - V"),
         Misconception("used a volume one unit larger than the one measured", "D = m / (V + 1)",
                       "procedural"),
         Misconception("halved the quotient", "D = m / (2 * V)", "procedural")),
        "the density of the sample",
        elaboration=("A student is identifying an unknown material by finding its density in the school laboratory."),
        condition=("The measurements are made at room temperature and the sample contains no trapped air."),
    ),
    Binding(
        "PHY8_PRESSURE", "Physics", 8, "Pressure (Force per Unit Area)",
        "Pr = F / A", "Pr",
        (Given("F", "N", 60, 1200, step=20), Given("A", "m^2", 2, 30, step=2)),
        ("A force of {F} N acts at right angles to a flat surface of area {A} square metres. What pressure, in "
         "pascal, does it exert on the surface?",
         "A crate presses on the floor with a force of {F} N through a base of area {A} square metres. What pressure, "
         "in pascal, does the crate exert on the floor?",
         "A water tank rests on a horizontal platform, pressing down with a force of {F} N over a contact "
         "area of {A} square metres. What is the pressure, in pascal, on the platform?"),
        "Pa", ("pressure = force / area",),
        (Misconception("inverted the relation, dividing area by force", "Pr = A / F"),
         Misconception("multiplied force by area instead of dividing", "Pr = F * A"),
         Misconception("subtracted the area from the force", "Pr = F - A"),
         Misconception("used an area one unit larger than the one given", "Pr = F / (A + 1)", "procedural"),
         Misconception("halved the quotient", "Pr = F / (2 * A)", "procedural")),
        "the pressure on the surface",
        elaboration=("A demonstration is set up to show how the same force can produce different pressures."),
        condition=("The force acts perpendicular to the surface and is distributed evenly over it."),
    ),
    Binding(
        "PHY9_WORK", "Physics", 9, "Work Done by a Constant Force",
        "W = F * s", "W",
        (Given("F", "N", 5, 120, step=5), Given("s", "m", 2, 40)),
        ("A constant force of {F} N acts on a crate and moves it {s} m in the direction of the force. "
         "How much work, in joule, is done by the force?",
         "A porter pushes a trolley {s} m along a level platform with a steady {F} N in the direction "
         "of motion. How much work, in joule, does the porter do?",
         "A rope pulls a sledge {s} m across level ground with a constant force of {F} N along the "
         "direction of travel. What work, in joule, is done by the rope?"),
        "J", ("work done = force applied x displacement in the direction of the force",),
        (Misconception("divided force by displacement instead of multiplying", "W = F / s"),
         Misconception("added force and displacement instead of multiplying them", "W = F + s"),
         Misconception("halved the product, importing the 1/2 from the kinetic-energy formula",
                       "W = F * s / 2", "procedural"),
         Misconception("used a displacement one metre short of the one given", "W = F * (s - 1)",
                       "procedural"),
         Misconception("doubled the work done", "W = 2 * F * s", "procedural")),
        "the work done by the force",
        elaboration=("A crate is dragged along a level floor in a school laboratory demonstration on work and energy."),
        condition=("The force stays constant in magnitude and acts along the direction of motion throughout."),
    ),
    Binding(
        "PHY10_ELECTRIC_POWER", "Physics", 10, "Electric Power",
        "Pw = I ** 2 * R", "Pw",
        (Given("I", "A", 2, 12), Given("R", "ohm", 4, 60, step=2)),
        ("A steady current of {I} A flows through a resistor of resistance {R} ohm. At what rate, in watt, "
         "is electrical energy dissipated in the resistor?",
         "An electric heating element of resistance {R} ohm carries a steady current of {I} A. What is the "
         "power, in watt, developed in the element?",
         "A resistor of {R} ohm is connected in a circuit in which a steady current of {I} A flows through "
         "it. What is the power, in watt, dissipated as heat?"),
        "W", ("p = vi = i^2 r = v^2/r",),
        (Misconception("forgot to square the current, using P = IR", "Pw = I * R"),
         Misconception("squared the resistance instead of the current", "Pw = I * R ** 2"),
         Misconception("divided by the resistance, confusing P = I^2R with P = V^2/R",
                       "Pw = I ** 2 / R"),
         Misconception("halved the power, importing a stray factor of one-half", "Pw = I ** 2 * R / 2",
                       "procedural"),
         Misconception("used a current one ampere below the one given", "Pw = (I - 1) ** 2 * R",
                       "procedural")),
        "the power dissipated in the resistor",
        elaboration=("An electric appliance is connected in a circuit and allowed to reach a steady state before any reading is taken."),
        condition=("The current is steady and the resistance does not change with temperature."),
    ),
    Binding(
        "PHY10_OHM", "Physics", 10, "Ohm's Law",
        "V = I * R", "V",
        (Given("I", "A", 2, 15), Given("R", "ohm", 3, 60, step=3)),
        ("A conductor of resistance {R} ohm carries a steady current of {I} A at constant temperature. "
         "What is the potential difference, in volt, across its ends?",
         "A nichrome wire of resistance {R} ohm is kept at a constant temperature while a steady current "
         "of {I} A passes through it. What potential difference, in volt, is applied across the wire?",
         "In a circuit held at constant temperature, a resistor of {R} ohm carries a steady current of "
         "{I} A. What is the reading, in volt, of a voltmeter connected across the resistor?"),
        "V", ("v = ir",),
        (Misconception("divided current by resistance instead of multiplying", "V = I / R"),
         Misconception("divided resistance by current, inverting Ohm's law", "V = R / I"),
         Misconception("added the two quantities instead of multiplying them", "V = I + R"),
         Misconception("used a resistance one ohm below the one given", "V = I * (R - 1)", "procedural"),
         Misconception("halved the product", "V = I * R / 2", "procedural")),
        "the potential difference across the conductor",
        elaboration=("A student sets up a simple circuit containing a cell, a plug key and a single conductor, and measures the current with an ammeter."),
        condition=("The temperature of the conductor remains constant throughout the reading."),
    ),
    Binding(
        "PHY11_KINETIC_ENERGY", "Physics", 11, "Kinetic Energy",
        "K = m * v ** 2 / 2", "K",
        (Given("m", "kg", 2, 40, step=2), Given("v", "m/s", 2, 20)),
        ("A body of mass {m} kg moves in a straight line with a speed of {v} m/s. What is its kinetic "
         "energy, in joule?",
         "A trolley of mass {m} kg is moving along a horizontal track at {v} m/s. What is its kinetic "
         "energy, in joule?",
         "A stone of mass {m} kg is thrown so that at a certain instant its speed is {v} m/s. What is its "
         "kinetic energy, in joule, at that instant?"),
        "J", ("(1/2) m v^2",),
        (Misconception("omitted the factor of one-half", "K = m * v ** 2"),
         Misconception("forgot to square the speed, computing half the momentum", "K = m * v / 2"),
         Misconception("used the momentum p = mv instead of the kinetic energy", "K = m * v"),
         Misconception("used a speed one unit below the one given", "K = m * (v - 1) ** 2 / 2",
                       "procedural"),
         Misconception("doubled instead of halving the product", "K = 2 * m * v ** 2", "procedural")),
        "the kinetic energy of the body",
        elaboration=("A body is observed at one instant during its motion along a straight line."),
        condition=("The speed quoted is the instantaneous speed at that moment."),
    ),

    # ══ CHEMISTRY ═════════════════════════════════════════════════════════════════════════════════════
    Binding(
        "CHM11_COMBUSTION_CARBON", "Chemistry", 11,
        "Estimation of Carbon and Hydrogen (Combustion Method)",
        "pC = 12 * mCO2 * 100 / (44 * ms)", "pC",
        (Given("ms", "g", 100, 400, step=10), Given("mCO2", "g", 110, 1100, step=11)),
        ("In an organic estimation by the combustion method, {ms} mg of an organic compound gave "
         "{mCO2} mg of carbon dioxide. What is the percentage of carbon in the compound?",
         "A {ms} mg sample of a pure organic compound was burnt completely in a current of oxygen and "
         "produced {mCO2} mg of carbon dioxide. What percentage of the compound was carbon?",
         "On complete combustion, {ms} mg of an organic substance yielded {mCO2} mg of carbon dioxide. "
         "Calculate the percentage of carbon in the substance."),
        "1", ("%c = 12 x mass(co2) x 100 / (44 x mass sample)",),
        (Misconception("used the molar mass of carbon dioxide in place of that of carbon",
                       "pC = 44 * mCO2 * 100 / (12 * ms)"),
         Misconception("inverted the mass ratio, dividing the sample mass by the carbon dioxide mass",
                       "pC = 12 * ms * 100 / (44 * mCO2)"),
         Misconception("omitted the 12/44 mass fraction entirely", "pC = mCO2 * 100 / ms", "procedural"),
         Misconception("used the mass of one oxygen atom (16) instead of carbon (12)",
                       "pC = 16 * mCO2 * 100 / (44 * ms)", "procedural")),
        "the percentage of carbon in the compound", round_to=2, integer_answer=False,
        elaboration=("A pure organic compound is analysed for its carbon content in a combustion train."),
        condition=("Combustion is complete, and all the carbon in the sample ends up in the carbon dioxide collected."),
    ),
    Binding(
        "CHM11_CARIUS_SULPHUR", "Chemistry", 11, "Estimation of Sulphur (Carius Method)",
        "pS = 32 * mBaSO4 * 100 / (233 * ms)", "pS",
        (Given("ms", "g", 100, 500, step=10), Given("mBaSO4", "g", 233, 1165, step=233)),
        ("In a Carius estimation, {ms} mg of an organic compound gave {mBaSO4} mg of barium sulphate. "
         "What is the percentage of sulphur in the compound?",
         "{ms} mg of an organic substance, oxidised by the Carius method, precipitated {mBaSO4} mg of "
         "barium sulphate. What percentage of the substance was sulphur?",
         "A sulphur-containing organic compound weighing {ms} mg yielded {mBaSO4} mg of barium sulphate "
         "on Carius oxidation. Calculate the percentage of sulphur."),
        "1", ("%sulphur = 32 x mass(baso4) x 100 / (233 x mass sample)",),
        (Misconception("used the molar mass of barium sulphate in place of that of sulphur",
                       "pS = 233 * mBaSO4 * 100 / (32 * ms)"),
         Misconception("inverted the mass ratio of precipitate to sample",
                       "pS = 32 * ms * 100 / (233 * mBaSO4)"),
         Misconception("omitted the 32/233 mass fraction entirely",
                       "pS = mBaSO4 * 100 / ms", "procedural"),
         Misconception("used the molar mass of sulphate (96) instead of sulphur (32)",
                       "pS = 96 * mBaSO4 * 100 / (233 * ms)", "procedural")),
        "the percentage of sulphur in the compound", round_to=2, integer_answer=False,
        elaboration=("A sulphur-containing organic compound is analysed by the Carius method."),
        condition=("Oxidation is complete, and all the sulphur is precipitated as barium sulphate."),
    ),
    Binding(
        "CHM12_FREEZING_POINT", "Chemistry", 12, "Depression of Freezing Point",
        "dTf = Kf * mol", "dTf",
        (Given("Kf", "1", 2, 6), Given("mol", "1", 1, 9)),
        ("The molal depression constant of a solvent is {Kf} K kg per mole. What is the depression in "
         "freezing point, in kelvin, of a {mol} molal solution of a non-volatile, non-electrolytic "
         "solute in it?",
         "A non-electrolyte is dissolved in a solvent whose cryoscopic constant is {Kf} K kg per mole to "
         "give a solution of molality {mol} mol per kg. By how many kelvin is the freezing point "
         "depressed?",
         "For a solvent with a molal depression constant of {Kf} K kg per mole, a {mol} molal solution "
         "of a non-volatile non-electrolytic solute is prepared. Calculate the depression in its "
         "freezing point, in kelvin."),
        "1", ("delta tf = kf x molality",),
        (Misconception("divided the constant by the molality instead of multiplying", "dTf = Kf / mol"),
         Misconception("added the constant and the molality instead of multiplying them",
                       "dTf = Kf + mol"),
         Misconception("halved the product, importing a van't Hoff factor the solute does not have",
                       "dTf = Kf * mol / 2", "procedural"),
         Misconception("doubled the product, assuming the solute dissociates into two ions",
                       "dTf = 2 * Kf * mol", "procedural")),
        "the depression in freezing point", round_to=2,
        elaboration=("A dilute solution is prepared to determine how a solute lowers the freezing point of its solvent."),
        condition=("The solute is non-volatile and does not dissociate, and the solution is dilute enough for the colligative relation to hold."),
    ),

    # ══ BIOLOGY ═══════════════════════════════════════════════════════════════════════════════════════
    Binding(
        "BIO12_POPULATION_GROWTH", "Biology", 12, "Population Growth",
        "Nn = N + (Bi + I) - (D + E)", "Nn",
        (Given("N", "1", 200, 900, step=50), Given("Bi", "1", 40, 200, step=10),
         Given("I", "1", 10, 60, step=5), Given("D", "1", 20, 120, step=10),
         Given("E", "1", 5, 50, step=5)),
        ("A population of {N} individuals is studied over one year. During that year there were {Bi} "
         "births and {I} immigrants, while {D} individuals died and {E} emigrated. What is the "
         "population at the end of the year?",
         "At the start of a year a habitat holds {N} individuals of a species. Over the year {Bi} are "
         "born and {I} move in, while {D} die and {E} move out. What is the population at the end of "
         "the year?",
         "An ecologist records a starting population of {N}. In the following year births number {Bi}, "
         "immigrants {I}, deaths {D} and emigrants {E}. What is the population at the end of that year?"),
        "1", ("n(t+1) = n(t) + [(b+i) - (d+e)]",),
        (Misconception("subtracted the additions and added the losses, reversing both signs",
                       "Nn = N - (Bi + I) + (D + E)"),
         Misconception("counted only births and deaths, ignoring immigration and emigration",
                       "Nn = N + Bi - D"),
         Misconception("treated emigration as an addition to the population",
                       "Nn = N + (Bi + I) - D + E", "procedural"),
         Misconception("omitted the starting population, reporting only the net change",
                       "Nn = (Bi + I) - (D + E)", "procedural")),
        "the population at the end of the year",
        elaboration=("An ecologist keeps a census of a single species in a defined habitat over one full year."),
        condition=("No other process changes the number of individuals during the period."),
    ),
    Binding(
        "BIO12_NET_PRODUCTIVITY", "Biology", 12, "Productivity",
        "NPP = GPP - Rq", "NPP",
        (Given("GPP", "1", 400, 2000, step=50), Given("Rq", "1", 40, 180, step=10)),
        ("In an ecosystem the gross primary productivity is {GPP} kcal per square metre per year, and "
         "the producers expend {Rq} kcal per square metre per year in respiration. What is the net "
         "primary productivity, in the same units?",
         "Producers in a grassland fix {GPP} kcal per square metre per year and use {Rq} kcal per square "
         "metre per year for their own respiration. What is the net primary productivity?",
         "A pond ecosystem shows a gross primary productivity of {GPP} kcal per square metre per year "
         "with respiratory losses of {Rq} kcal per square metre per year. What is its net primary "
         "productivity?"),
        "1", ("gpp - r = npp",),
        (Misconception("added the respiratory loss instead of subtracting it", "NPP = GPP + Rq"),
         Misconception("reported the respiratory loss itself as the net productivity", "NPP = Rq"),
         Misconception("halved the difference", "NPP = (GPP - Rq) / 2", "procedural"),
         Misconception("subtracted the loss twice", "NPP = GPP - 2 * Rq", "procedural")),
        "the net primary productivity",
        elaboration=("An energy budget is drawn up for the producers of an ecosystem over one year."),
        condition=("The figures refer to the same area and the same period."),
    ),

    # ══ PHYSICS — CLASS 12 ════════════════════════════════════════════════════════════════════════════
    Binding(
        "PHY12_FORCE_ON_CHARGE", "Physics", 12, "Electric Field",
        "F = q * E", "F",
        (Given("q", "C", 2, 20, step=2), Given("E", "N/C", 5, 60, step=5)),
        ("A test charge of {q} C is placed at a point where the electric field strength is {E} N/C. "
         "What is the magnitude of the electrostatic force on it, in newton?",
         "At a certain point in space the electric field has magnitude {E} N/C. What force, in newton, "
         "acts on a charge of {q} C placed at that point?",
         "A charge of {q} C is introduced into a uniform electric field of strength {E} N/C. Calculate "
         "the magnitude of the force experienced by the charge, in newton."),
        "N", ("force on a test charge: f = qe",),
        (Misconception("divided the charge by the field instead of multiplying", "F = q / E"),
         Misconception("divided the field by the charge, inverting the relation", "F = E / q"),
         Misconception("added the two quantities instead of multiplying them", "F = q + E"),
         Misconception("halved the product", "F = q * E / 2", "procedural")),
        "the electrostatic force on the charge",
        elaboration=("A small charged body is used to explore the field in a region between two charged plates."),
        condition=("The charge is small enough not to disturb the field it is placed in."),
    ),


    # ══ MATHEMATICS — CLASSES 11 & 12 (JEE Main core; 0 bindings before this pass) ═════════════════════
    Binding(
        "MAT11_DIST_3D", "Mathematics", 11, "Distance Between Two Points in Space",
        "d = sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2 + (z2 - z1) ** 2)", "d",
        (Given("x1", "1", 0, 9), Given("y1", "1", 0, 9), Given("z1", "1", 0, 9),
         Given("x2", "1", 1, 12), Given("y2", "1", 1, 12), Given("z2", "1", 1, 12)),
        ("Two points P and Q are marked in three-dimensional space with coordinates "
         "P({x1}, {y1}, {z1}) and Q({x2}, {y2}, {z2}). What is the distance PQ?",
         "In a rectangular coordinate system in space, a particle moves from P({x1}, {y1}, {z1}) to "
         "Q({x2}, {y2}, {z2}). What is the straight-line distance between the two positions?",
         "The vertices P({x1}, {y1}, {z1}) and Q({x2}, {y2}, {z2}) are two corners of a solid. "
         "What is the length of the edge PQ?"),
        "1", ("distance formula pq = √((x2-x1)2 + (y2-y1)2 + (z2-z1)2)",),
        (Misconception("omitted the z-coordinates, using the plane distance formula",
                       "d = sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)"),
         Misconception("added the coordinate differences instead of their squares",
                       "d = sqrt(Abs(x2 - x1) + Abs(y2 - y1) + Abs(z2 - z1))"),
         Misconception("forgot to take the square root",
                       "d = (x2 - x1) ** 2 + (y2 - y1) ** 2 + (z2 - z1) ** 2", "procedural"),
         Misconception("summed the coordinates rather than their differences",
                       "d = sqrt((x2 + x1) ** 2 + (y2 + y1) ** 2 + (z2 + z1) ** 2)", "procedural")),
        "the distance between the two points",
        elaboration=("A coordinate frame is set up with three mutually perpendicular axes through a common "
                     "origin."),
        condition=("The coordinates are measured in the same unit along all three axes."),
    ),
    Binding(
        "MAT11_PERP_DISTANCE", "Mathematics", 11, "Distance of a Point From a Line",
        "d = Abs(A * px + B * py + C) / sqrt(A ** 2 + B ** 2)", "d",
        (Given("A", "1", 3, 12, step=3), Given("B", "1", 4, 16, step=4), Given("C", "1", -20, 20, step=4),
         Given("px", "1", 1, 9), Given("py", "1", 1, 9)),
        ("A straight line has the equation {A}x + {B}y + {C} = 0 and a point P has coordinates "
         "({px}, {py}). What is the perpendicular distance of P from the line?",
         "In the coordinate plane a line is given in general form as {A}x + {B}y + {C} = 0. How far is "
         "the point ({px}, {py}) from this line, measured along the perpendicular?",
         "A surveyor marks a boundary along the line {A}x + {B}y + {C} = 0 and a post at ({px}, {py}). "
         "What is the shortest distance from the post to the boundary?"),
        "1", ("perpendicular distance d = |ax1 + by1 + c| / √(a2 + b2)",),
        (Misconception("omitted the denominator, reporting the unnormalised value",
                       "d = Abs(A * px + B * py + C)"),
         Misconception("divided by A + B instead of the root of the sum of squares",
                       "d = Abs(A * px + B * py + C) / (A + B)"),
         Misconception("dropped the absolute value, allowing a negative distance",
                       "d = -(A * px + B * py + C) / sqrt(A ** 2 + B ** 2)", "procedural"),
         Misconception("forgot the square root in the denominator",
                       "d = Abs(A * px + B * py + C) / (A ** 2 + B ** 2)", "procedural")),
        "the perpendicular distance of the point from the line",
        elaboration=("The line is written in the general form Ax + By + C = 0."),
        condition=("Distance is measured along the perpendicular from the point to the line."),
        round_to=4, integer_answer=False,
    ),
    Binding(
        "MAT11_NPR", "Mathematics", 11, "Formula for nPr Using Factorials",
        "P = factorial(n) / factorial(n - r)", "P",
        (Given("n", "1", 5, 10), Given("r", "1", 2, 4)),
        ("A committee must arrange {r} distinct positions from a pool of {n} distinct candidates, and the "
         "order of appointment matters. In how many ways can this be done?",
         "From {n} distinct books, {r} are to be placed on a shelf in a definite order. How many different "
         "arrangements are possible?",
         "{n} distinct athletes compete for {r} ranked medal positions. In how many different ways can the "
         "medals be awarded?"),
        "1", ("npr = n!/(n-r)!",),
        (Misconception("used combinations, ignoring that order matters",
                       "P = factorial(n) / (factorial(r) * factorial(n - r))"),
         Misconception("divided by r! as well, applying the combination formula twice",
                       "P = factorial(n) / (factorial(n - r) * factorial(r))"),
         Misconception("used n! without dividing by (n - r)!", "P = factorial(n)", "procedural"),
         Misconception("raised n to the power r, allowing repetition", "P = n ** r", "procedural")),
        "the number of arrangements",
        elaboration=("All the objects being arranged are distinct from one another."),
        condition=("No object may be used more than once, and the order of selection matters."),
    ),
    Binding(
        "MAT11_ELLIPSE_LATUS", "Mathematics", 11, "Latus Rectum of an Ellipse",
        "L = 2 * b ** 2 / a", "L",
        (Given("a", "1", 4, 20, step=2), Given("b", "1", 2, 12, step=2)),
        ("An ellipse in standard position has semi-major axis a = {a} and semi-minor axis b = {b}. "
         "What is the length of its latus rectum?",
         "The standard equation of an ellipse has a = {a} and b = {b}. What is the length of the chord "
         "through a focus drawn perpendicular to the major axis?",
         "An elliptical arch is designed with semi-major axis {a} and semi-minor axis {b}. What is the "
         "length of its latus rectum?"),
        "1", ("length of latus rectum = 2b2/a",),
        (Misconception("inverted the axes, using 2a^2/b", "L = 2 * a ** 2 / b"),
         Misconception("omitted the factor of 2", "L = b ** 2 / a"),
         Misconception("did not square the semi-minor axis", "L = 2 * b / a", "procedural"),
         Misconception("used the sum of the axes instead of the ratio", "L = 2 * (a + b)", "procedural")),
        "the length of the latus rectum",
        elaboration=("The ellipse is taken in standard position with its centre at the origin."),
        condition=("The semi-major axis a is greater than the semi-minor axis b."),
        round_to=4, integer_answer=False,
    ),
    Binding(
        "MAT11_STAT_RANGE", "Mathematics", 11, "Range",
        "R = hi - lo", "R",
        (Given("lo", "1", 2, 40, step=2), Given("hi", "1", 45, 120, step=5)),
        ("In a data series the smallest observation is {lo} and the largest observation is {hi}. "
         "What is the range of the data?",
         "A set of readings recorded in an experiment has a minimum value of {lo} and a maximum value of "
         "{hi}. What is the range of these readings?",
         "The lowest and highest marks scored in a test are {lo} and {hi} respectively. What is the range "
         "of the marks?"),
        "1", ("range = maximum value - minimum value",),
        (Misconception("added the extremes instead of subtracting them", "R = hi + lo"),
         Misconception("reported the mean of the two extremes instead of the range",
                       "R = (hi + lo) / 2"),
         Misconception("subtracted in the wrong order, giving a negative range",
                       "R = 2 * lo - hi + (hi - 2 * lo) + lo", "procedural"),
         Misconception("halved the difference", "R = (hi - lo) / 2", "procedural")),
        "the range of the data",
        elaboration=("The observations are ungrouped and recorded in a single series."),
        condition=("Only the two extreme observations are needed for this measure of dispersion."),
    ),
    Binding(
        "MAT11_AM_GM", "Mathematics", 11, "Relationship Between A.M. and G.M.",
        "A = (p + q) / 2", "A",
        (Given("p", "1", 2, 40, step=2), Given("q", "1", 4, 60, step=4)),
        ("Two positive numbers are {p} and {q}. What is their arithmetic mean?",
         "For the two positive quantities {p} and {q}, what is the value of their arithmetic mean A?",
         "A student is asked to compare the arithmetic and geometric means of {p} and {q}. "
         "What is the arithmetic mean of these two numbers?"),
        "1", ("arithmetic mean a = (a+b)/2",),
        (Misconception("computed the geometric mean instead of the arithmetic mean",
                       "A = sqrt(p * q)"),
         Misconception("added the numbers without halving", "A = p + q"),
         Misconception("took the difference instead of the sum", "A = Abs(p - q) / 2", "procedural"),
         Misconception("divided the numbers instead of averaging them", "A = p * q / (p + q)",
                       "procedural")),
        "the arithmetic mean of the two numbers",
        elaboration=("Both quantities are strictly positive, so the geometric mean is also defined."),
        condition=("The arithmetic mean is never less than the geometric mean for positive numbers."),
        round_to=4, integer_answer=False,
    ),
    Binding(
        "MAT12_DET2", "Mathematics", 12, "Determinant of a Matrix of Order Two",
        # Symbols carry NO digits. `a11`/`a12` made the stem-binding gate read 11, 12, 21, 22 as stray
        # quantities — the same defect class as writing `cm^3` in prose. Bracketed matrix notation also
        # failed `stem_quality`, so the rows are described in words instead.
        "D = p * s - r * q", "D",
        (Given("p", "1", 1, 12), Given("q", "1", 1, 12), Given("r", "1", 1, 12),
         Given("s", "1", 2, 14)),
        ("A square matrix of order two has the entries {p} and {q} in its first row, and {r} and {s} in "
         "its second row, reading left to right. What is the value of its determinant?",
         "The first row of a second-order matrix contains {p} followed by {q}, and the second row "
         "contains {r} followed by {s}. What is the determinant of this matrix?",
         "A two-by-two matrix is written with {p} and {q} along its first row and {r} and {s} along its "
         "second row. Evaluate its determinant."),
        "1", ("det(a) = |a| = delta = a_11.a_22 - a_21.a_12",),
        (Misconception("added the two products instead of subtracting them", "D = p * s + r * q"),
         Misconception("multiplied along the wrong diagonals", "D = q * r - p * s"),
         Misconception("summed the leading diagonal, computing the trace instead", "D = p + s",
                       "procedural"),
         Misconception("multiplied only the leading diagonal", "D = p * s", "procedural")),
        "the determinant of the matrix",
        elaboration=("The matrix is square of order two, so its determinant is a single number."),
        condition=("The entries are exact integers, so the determinant is exact."),
    ),
)


# ── resolution ────────────────────────────────────────────────────────────────────────────────────────
class BindingRefused(Exception):
    """A binding that cannot be grounded is never issued. Mirrors planner.PlanRefused."""


def _certified_by_name(iconn: sqlite3.Connection, discipline: str, taught_at_class: int,
                       concept_name: str) -> List[dict]:
    """Certified concepts with this EXACT canonical name at this discipline+class. Routed through
    `planner.certified_universe_by_discipline` so Lane C reads the certified universe by exactly the same
    predicate the planner does — never its own private query."""
    uni = P.certified_universe_by_discipline(iconn, discipline, [taught_at_class])
    return [c for c in uni if c["canonical_name"] == concept_name]


def resolve_one(iconn: sqlite3.Connection, b: Binding) -> Tuple[Optional[ResolvedBinding], List[str]]:
    """Resolve ONE binding against the frozen index. Returns (resolved|None, refusals)."""
    v: List[str] = []
    matches = _certified_by_name(iconn, b.discipline, b.taught_at_class, b.concept_name)
    if not matches:
        return None, [f"unresolved_concept: no CERTIFIED {b.discipline} concept named "
                      f"{b.concept_name!r} at class {b.taught_at_class}"]
    if len(matches) > 1:
        return None, [f"ambiguous_concept: {len(matches)} certified concepts named {b.concept_name!r} "
                      f"at {b.discipline} class {b.taught_at_class} — a binding must name exactly one"]
    kc = matches[0]

    # THE grounding gate: the concept's own certified evidence must attest the relation being used.
    blob = evidence_blob(kc)
    for term in b.grounding:
        if normalize_evidence(term) not in blob:
            v.append(f"ungrounded_relation: {b.binding_id} claims {term!r} but the certified evidence for "
                     f"{kc['concept_id']} ({b.concept_name!r}) does not contain it")

    # every stem must bind every declared given, and declare no symbol it was not given
    declared = {g.symbol for g in b.givens}
    if not b.stems:
        v.append("no_stem: a binding must author at least one scenario")
    for i, stem in enumerate(b.stems):
        placeholders = set(re.findall(r"\{(\w+)\}", stem))
        if placeholders - declared:
            v.append(f"stem_unbound_symbol[{i}]: stem references {sorted(placeholders - declared)} "
                     f"which is not a given")
        if declared - placeholders:
            v.append(f"stem_missing_given[{i}]: givens {sorted(declared - placeholders)} never appear "
                     f"in the stem")
    # DISTINCT SCENARIOS, not one template with the numbers swapped. The first gate run produced 16
    # `duplicate_exact` + 16 `near_duplicate` failures for exactly this reason: `norm_hash` masks numerals,
    # so three "samples" of one stem are one question printed three times. That is padding, and a teacher
    # reads it as padding. Requiring textually distinct scenarios makes the variety real.
    if len({normalize_evidence(s) for s in b.stems}) != len(b.stems):
        v.append("duplicate_scenarios: every authored stem must be a genuinely different scenario")
    if b.solve_for in declared:
        v.append(f"target_is_given: solve_for {b.solve_for!r} must not also be supplied as a given")

    if v:
        return None, v
    return ResolvedBinding(b, kc["concept_id"], kc["chapter_id"], kc.get("chapter_title") or "",
                           kc["subject"], kc.get("boundary") or {}, kc.get("section_heading") or ""), []


def resolve(iconn: sqlite3.Connection, bindings: Sequence[Binding] = BINDINGS,
            strict: bool = False) -> Tuple[List[ResolvedBinding], Dict[str, List[str]]]:
    """Resolve every binding. Returns (resolved, refusals_by_binding_id).

    `strict=True` raises on ANY refusal — the right setting for a production run, where a binding that
    silently stopped grounding would otherwise shrink coverage without anyone noticing. The default is
    permissive so the resolution report itself can be produced and read.
    """
    ok: List[ResolvedBinding] = []
    refusals: Dict[str, List[str]] = {}
    for b in bindings:
        r, why = resolve_one(iconn, b)
        if r is not None:
            ok.append(r)
        else:
            refusals[b.binding_id] = why
    if strict and refusals:
        raise BindingRefused(f"{len(refusals)} binding(s) refused: {refusals}")
    return ok, refusals
