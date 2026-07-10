"""Deterministic parametric-template registry — the FIRST-CHOICE way to materialize objective
items with ZERO AI.

Each template is a certified question family: it binds to concepts by precise topic keywords
(+ subject), instantiates concrete parameters deterministically from (concept_code, seed), and
is SOLVER-VERIFIED (the answer is computed, not asserted). One certified family → unlimited
reproducible, original, solver-checked instances. This is the AIMS "certified family" model and
removes most of the need to ever call AI.

Templates are curated reference data (like presets/chapters) — the set can grow without engine
changes. They are conservative: a template fills a slot only when it clearly matches the topic;
otherwise the slot falls through to a spec (and, if authorized, the gated AI).
"""
from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from typing import Callable, List, Optional

from kie.qpgen.models import QuestionType


def _p(concept_code: str, seed: int, name: str, lo: int, hi: int) -> int:
    """Deterministic integer parameter in [lo, hi] from (concept_code, seed, name)."""
    h = int(hashlib.sha256(f"{concept_code}|{seed}|{name}".encode()).hexdigest()[:8], 16)
    return lo + (h % (hi - lo + 1))


_NUM_IN_STR = re.compile(r"-?\d+\.?\d*")


def _perturb_num(answer_str: str, op) -> Optional[str]:
    """Return `answer_str` with its first numeric token nudged (op=int → add; op=('m',k) → multiply),
    keeping the surrounding unit/symbol text. Deterministic. None if there is no number to nudge."""
    m = _NUM_IN_STR.search(answer_str)
    if not m:
        return None
    base = float(m.group())
    val = base * op[1] if isinstance(op, tuple) else base + op
    return answer_str[:m.start()] + _fmt_num(val) + answer_str[m.end():]


def _fmt_num(x) -> str:
    if isinstance(x, float):
        return str(int(x)) if x.is_integer() else str(round(x, 4))
    return str(x)


def _mcq_options(correct, distractors: List, concept_code: str, seed: int) -> List[str]:
    """Deterministically ordered 4 DISTINCT options (one correct + 3 distractors).

    De-duplicates the provided distractors, then — if a parameter coincidence collapsed them
    below four — pads with deterministic numeric near-misses of the correct answer so every MCQ
    ships exactly four distinct, plausible options (Phase-5 objective validation depends on this)."""
    opts, seen = [], set()
    for v in [correct] + list(distractors):
        s = str(v)
        if s not in seen:
            seen.add(s)
            opts.append(s)
    for op in (1, -1, 2, -2, 3, -3, 5, 10, ("m", 2), ("m", 3), 4, -4, 7, ("m", 4)):
        if len(opts) >= 4:
            break
        cand = _perturb_num(str(correct), op)
        if cand and cand not in seen:
            seen.add(cand)
            opts.append(cand)
    opts = opts[:4]
    # deterministic rotation by seed so the correct option isn't always first
    rot = int(hashlib.sha256(f"{concept_code}|{seed}|rot".encode()).hexdigest()[:4], 16) % max(1, len(opts))
    return opts[rot:] + opts[:rot]


@dataclass
class Template:
    template_id: str
    subject: str
    # concept binds if ANY group matches, where a group matches only when ALL its substrings are
    # present in the (apostrophe-normalized) title. Conjunctive groups avoid false positives such
    # as "Kepler's second law" matching the Newton (net force) template.
    keyword_groups: tuple
    types: tuple                    # question types this template can fill
    build: Callable                 # (concept_code, seed, qtype) -> dict


# ── curated families (universal formulas — no fabricated concept-specific facts) ────
def _newton(cc, seed, qtype):
    m = _p(cc, seed, "m", 2, 20)
    a = _p(cc, seed, "a", 2, 15)
    f = m * a                                            # solver: F = m·a
    d = {"stem": f"A body of mass {m} kg moves with a uniform acceleration of {a} m/s². "
                 f"Calculate the net force acting on it.",
         "answer": f"{f} N",
         "solution": f"By Newton's second law, F = m·a = {m} × {a} = {f} N.", "options": None}
    if qtype == QuestionType.MCQ:
        d["options"] = _mcq_options(f"{f} N", [f"{m + a} N", f"{m * a + m} N", f"{abs(m - a)} N"], cc, seed)
    return d


def _ohm(cc, seed, qtype):
    r = _p(cc, seed, "r", 2, 50)
    i = _p(cc, seed, "i", 1, 10)
    v = r * i                                            # solver: V = I·R
    d = {"stem": f"A resistor of {r} Ω carries a steady current of {i} A. "
                 f"Find the potential difference across it.",
         "answer": f"{v} V",
         "solution": f"By Ohm's law, V = I·R = {i} × {r} = {v} V.", "options": None}
    if qtype == QuestionType.MCQ:
        d["options"] = _mcq_options(f"{v} V", [f"{r + i} V", f"{v + r} V", f"{r - i if r > i else i - r} V"], cc, seed)
    return d


def _speed(cc, seed, qtype):
    t = _p(cc, seed, "t", 2, 20)
    v = _p(cc, seed, "v", 2, 30)
    dist = v * t                                         # solver: d = v·t
    d = {"stem": f"An object moving at a constant speed covers {dist} m in {t} s. "
                 f"Calculate its speed.",
         "answer": f"{v} m/s",
         "solution": f"Speed = distance ÷ time = {dist} ÷ {t} = {v} m/s.", "options": None}
    if qtype == QuestionType.MCQ:
        d["options"] = _mcq_options(f"{v} m/s", [f"{dist} m/s", f"{v + t} m/s", f"{t} m/s"], cc, seed)
    return d


def _mole(cc, seed, qtype):
    n = _p(cc, seed, "n", 2, 8)
    mm = _p(cc, seed, "mm", 10, 60)
    mass = n * mm                                        # solver: n = m / M
    d = {"stem": f"Calculate the number of moles in {mass} g of a substance whose molar mass is "
                 f"{mm} g/mol.",
         "answer": f"{n} mol",
         "solution": f"n = mass ÷ molar mass = {mass} ÷ {mm} = {n} mol.", "options": None}
    if qtype == QuestionType.MCQ:
        d["options"] = _mcq_options(f"{n} mol", [f"{mass} mol", f"{n + 1} mol", f"{mm} mol"], cc, seed)
    return d


def _ap(cc, seed, qtype):
    a = _p(cc, seed, "a", 1, 10)
    diff = _p(cc, seed, "d", 1, 9)
    nth = _p(cc, seed, "n", 5, 20)
    term = a + (nth - 1) * diff                          # solver: aₙ = a + (n-1)d
    d = {"stem": f"Find the {nth}th term of an arithmetic progression whose first term is {a} "
                 f"and whose common difference is {diff}.",
         "answer": f"{term}",
         "solution": f"aₙ = a + (n−1)d = {a} + ({nth}−1)×{diff} = {term}.", "options": None}
    if qtype == QuestionType.MCQ:
        d["options"] = _mcq_options(f"{term}", [f"{term + diff}", f"{a + nth * diff}", f"{term - diff}"], cc, seed)
    return d


_NUM_MCQ = (QuestionType.NUMERICAL, QuestionType.MCQ)
REGISTRY: List[Template] = [
    # Newton's second law ONLY (not Kepler's/Clausius'/Kelvin-Planck's "second law")
    Template("phy_newton_2law", "Physics",
             (("newton", "second law"), ("net force", "mass"), ("f = ma",), ("f=ma",)), _NUM_MCQ, _newton),
    Template("phy_ohms_law", "Physics", (("ohm",), ("resistor",)), _NUM_MCQ, _ohm),
    Template("phy_uniform_speed", "Physics",
             (("uniform", "speed"), ("constant speed",), ("average speed",)), _NUM_MCQ, _speed),
    Template("chem_mole_concept", "Chemistry",
             (("mole concept",), ("molar mass",), ("avogadro",)), _NUM_MCQ, _mole),
    Template("math_ap_nth_term", "Mathematics",
             (("arithmetic progression",), ("arithmetic sequence",)), _NUM_MCQ, _ap),
]


# ════════════════════════════════════════════════════════════════════════════════════════
# Phase 2 — expanded certified template library.
#
# Every family below is SOLVER-VERIFIED (the answer is COMPUTED from the parameters, never
# asserted) and copyright-safe (universal formulas / SI units / named laws — no fabricated
# facts, no copied source text). MCQ distractors are COMPUTED common-misconception near-misses.
# A concept binds a family only via conservative conjunctive keyword groups; when unsure the
# slot stays a spec. Objective types that require domain facts we cannot verify (fact-recall
# MCQs, arbitrary diagrams) are deliberately NOT synthesized here — they remain specs.
# ════════════════════════════════════════════════════════════════════════════════════════

def _n(x):
    """Compact numeric string: 12.0 → '12', 12.5 → '12.5' (deterministic)."""
    if isinstance(x, float):
        return str(int(x)) if x.is_integer() else str(round(x, 4))
    return str(x)


def _num_family(tid, subject, groups, gen, types=_NUM_MCQ):
    """Build a Template from a generator gen(cc, seed) -> {stem, answer, solution, distractors}.
    NUMERICAL uses the computed answer; MCQ adds deterministic options (answer + 3 distractors)."""
    def build(cc, seed, qtype):
        g = gen(cc, seed)
        out = {"stem": g["stem"], "answer": g["answer"], "solution": g["solution"], "options": None}
        if qtype == QuestionType.MCQ:
            out["options"] = _mcq_options(g["answer"], list(g["distractors"]), cc, seed)
        return out
    return Template(tid, subject, groups, types, build)


# ── Physics numeric families ────────────────────────────────────────────────────────────
def _g_kinetic_energy(cc, s):
    m = _p(cc, s, "m", 2, 20); v = _p(cc, s, "v", 2, 12); ke = 0.5 * m * v * v
    return {"stem": f"A body of mass {m} kg moves with a speed of {v} m/s. Calculate its kinetic energy.",
            "answer": f"{_n(ke)} J", "solution": f"KE = ½mv² = ½ × {m} × {v}² = {_n(ke)} J.",
            "distractors": [f"{_n(m*v*v)} J", f"{_n(m*v)} J", f"{_n(0.5*m*v)} J"]}


def _g_potential_energy(cc, s):
    m = _p(cc, s, "m", 2, 20); h = _p(cc, s, "h", 2, 20); pe = m * 10 * h
    return {"stem": f"An object of mass {m} kg is raised to a height of {h} m (take g = 10 m/s²). "
                    f"Calculate its gravitational potential energy.",
            "answer": f"{_n(pe)} J", "solution": f"PE = mgh = {m} × 10 × {h} = {_n(pe)} J.",
            "distractors": [f"{_n(m*h)} J", f"{_n(m*10)} J", f"{_n(10*h)} J"]}


def _g_work_done(cc, s):
    f = _p(cc, s, "f", 2, 50); d = _p(cc, s, "d", 2, 20); w = f * d
    return {"stem": f"A constant force of {f} N acts on a body and displaces it by {d} m in the "
                    f"direction of the force. Calculate the work done.",
            "answer": f"{_n(w)} J", "solution": f"W = F·d = {f} × {d} = {_n(w)} J.",
            "distractors": [f"{_n(f+d)} J", f"{_n(f)} J", f"{_n(d)} J"]}


def _g_power(cc, s):
    t = _p(cc, s, "t", 2, 10); p0 = _p(cc, s, "p", 2, 20); w = p0 * t
    return {"stem": f"A machine does {w} J of work in {t} s. Calculate its power.",
            "answer": f"{_n(p0)} W", "solution": f"P = W ÷ t = {w} ÷ {t} = {_n(p0)} W.",
            "distractors": [f"{_n(w*t)} W", f"{_n(w)} W", f"{_n(w+t)} W"]}


def _g_momentum(cc, s):
    m = _p(cc, s, "m", 2, 20); v = _p(cc, s, "v", 2, 20); p = m * v
    return {"stem": f"A body of mass {m} kg moves with a velocity of {v} m/s. Calculate its linear momentum.",
            "answer": f"{_n(p)} kg·m/s", "solution": f"p = mv = {m} × {v} = {_n(p)} kg·m/s.",
            "distractors": [f"{_n(m+v)} kg·m/s", f"{_n(2*m*v)} kg·m/s", f"{_n(m*v*v)} kg·m/s"]}


def _g_density(cc, s):
    vol = _p(cc, s, "V", 2, 10); d0 = _p(cc, s, "d", 2, 20); mass = d0 * vol
    return {"stem": f"A substance of mass {mass} g occupies a volume of {vol} cm³. Calculate its density.",
            "answer": f"{_n(d0)} g/cm³", "solution": f"ρ = mass ÷ volume = {mass} ÷ {vol} = {_n(d0)} g/cm³.",
            "distractors": [f"{_n(mass*vol)} g/cm³", f"{_n(mass)} g/cm³", f"{_n(mass+vol)} g/cm³"]}


def _g_pressure(cc, s):
    a = _p(cc, s, "A", 2, 10); p0 = _p(cc, s, "p", 2, 20); f = p0 * a
    return {"stem": f"A force of {f} N acts uniformly over an area of {a} m². Calculate the pressure exerted.",
            "answer": f"{_n(p0)} Pa", "solution": f"P = F ÷ A = {f} ÷ {a} = {_n(p0)} Pa.",
            "distractors": [f"{_n(f*a)} Pa", f"{_n(f)} Pa", f"{_n(f+a)} Pa"]}


def _g_final_velocity(cc, s):
    u = _p(cc, s, "u", 0, 20); a = _p(cc, s, "a", 1, 10); t = _p(cc, s, "t", 2, 10); v = u + a * t
    return {"stem": f"A body starts with an initial velocity of {u} m/s and accelerates uniformly at "
                    f"{a} m/s² for {t} s. Calculate its final velocity.",
            "answer": f"{_n(v)} m/s", "solution": f"v = u + at = {u} + {a}×{t} = {_n(v)} m/s.",
            "distractors": [f"{_n(u+a)} m/s", f"{_n(a*t)} m/s", f"{_n(u*a*t if u else a*t+u)} m/s"]}


def _g_weight(cc, s):
    m = _p(cc, s, "m", 2, 50); w = m * 10
    return {"stem": f"Calculate the weight of a body of mass {m} kg on the Earth's surface (take g = 10 m/s²).",
            "answer": f"{_n(w)} N", "solution": f"W = mg = {m} × 10 = {_n(w)} N.",
            "distractors": [f"{_n(m)} N", f"{_n(m*100)} N", f"{_n(m+10)} N"]}


def _g_wave_speed(cc, s):
    f = _p(cc, s, "f", 2, 20); lam = _p(cc, s, "l", 2, 20); v = f * lam
    return {"stem": f"A wave of frequency {f} Hz has a wavelength of {lam} m. Calculate its speed.",
            "answer": f"{_n(v)} m/s", "solution": f"v = fλ = {f} × {lam} = {_n(v)} m/s.",
            "distractors": [f"{_n(f+lam)} m/s", f"{_n(f)} m/s", f"{_n(lam)} m/s"]}


def _g_charge(cc, s):
    i = _p(cc, s, "i", 2, 20); t = _p(cc, s, "t", 2, 20); q = i * t
    return {"stem": f"A steady current of {i} A flows through a conductor for {t} s. Calculate the total "
                    f"charge that passes through it.",
            "answer": f"{_n(q)} C", "solution": f"Q = I·t = {i} × {t} = {_n(q)} C.",
            "distractors": [f"{_n(i+t)} C", f"{_n(i)} C", f"{_n(t)} C"]}


def _g_elec_power(cc, s):
    v = _p(cc, s, "v", 2, 20); i = _p(cc, s, "i", 2, 15); p = v * i
    return {"stem": f"An appliance operates at {v} V and draws a current of {i} A. Calculate its electrical power.",
            "answer": f"{_n(p)} W", "solution": f"P = V·I = {v} × {i} = {_n(p)} W.",
            "distractors": [f"{_n(v+i)} W", f"{_n(v)} W", f"{_n(i)} W"]}


def _g_resistance_series(cc, s):
    a = _p(cc, s, "a", 2, 40); b = _p(cc, s, "b", 2, 40); r = a + b
    return {"stem": f"Two resistors of {a} Ω and {b} Ω are connected in series. Calculate their "
                    f"equivalent resistance.",
            "answer": f"{_n(r)} Ω", "solution": f"In series, R = R₁ + R₂ = {a} + {b} = {_n(r)} Ω.",
            "distractors": [f"{_n(a*b)} Ω", f"{_n(round(a*b/(a+b),2))} Ω", f"{_n(abs(a-b))} Ω"]}


def _g_ohmic_power(cc, s):
    i = _p(cc, s, "i", 1, 10); r = _p(cc, s, "r", 2, 20); p = i * i * r
    return {"stem": f"A current of {i} A flows through a resistor of {r} Ω. Calculate the power dissipated in it.",
            "answer": f"{_n(p)} W", "solution": f"P = I²R = {i}² × {r} = {_n(p)} W.",
            "distractors": [f"{_n(i*r)} W", f"{_n(i*i)} W", f"{_n(i*r*r)} W"]}


def _g_specific_heat(cc, s):
    m = _p(cc, s, "m", 1, 10); c = _p(cc, s, "c", 2, 10); dt = _p(cc, s, "t", 2, 20); q = m * c * dt
    return {"stem": f"Calculate the heat required to raise the temperature of {m} kg of a substance "
                    f"(specific heat {c} J/kg·°C) by {dt} °C.",
            "answer": f"{_n(q)} J", "solution": f"Q = mcΔT = {m} × {c} × {dt} = {_n(q)} J.",
            "distractors": [f"{_n(m*dt)} J", f"{_n(c*dt)} J", f"{_n(m*c)} J"]}


def _g_magnification_phy(cc, s):
    ho = _p(cc, s, "o", 1, 5); m0 = _p(cc, s, "m", 2, 6); hi = m0 * ho
    return {"stem": f"An optical instrument forms an image of height {hi} cm of an object of height "
                    f"{ho} cm. Calculate the magnification produced.",
            "answer": f"{_n(m0)}", "solution": f"m = image height ÷ object height = {hi} ÷ {ho} = {_n(m0)}.",
            "distractors": [f"{_n(hi*ho)}", f"{_n(hi+ho)}", f"{_n(ho)}"]}


# ── Chemistry numeric families ──────────────────────────────────────────────────────────
def _g_molarity(cc, s):
    vol = _p(cc, s, "V", 1, 5); m0 = _p(cc, s, "m", 1, 5); n = m0 * vol
    return {"stem": f"{n} mol of a solute is dissolved to make {vol} L of solution. Calculate its molarity.",
            "answer": f"{_n(m0)} mol/L", "solution": f"M = moles ÷ volume(L) = {n} ÷ {vol} = {_n(m0)} mol/L.",
            "distractors": [f"{_n(n*vol)} mol/L", f"{_n(n)} mol/L", f"{_n(n+vol)} mol/L"]}


def _g_mass_from_moles(cc, s):
    n = _p(cc, s, "n", 2, 8); mm = _p(cc, s, "M", 10, 80); mass = n * mm
    return {"stem": f"Calculate the mass of {n} mol of a substance whose molar mass is {mm} g/mol.",
            "answer": f"{_n(mass)} g", "solution": f"mass = n × M = {n} × {mm} = {_n(mass)} g.",
            "distractors": [f"{_n(n+mm)} g", f"{_n(mm)} g", f"{_n(n)} g"]}


def _g_dilution(cc, s):
    g = _p(cc, s, "g", 1, 5); f = _p(cc, s, "f", 2, 5); v1 = _p(cc, s, "v", 1, 5)
    m1 = f * g; v2 = v1 * f; m2 = g
    return {"stem": f"{v1} L of a {m1} mol/L solution is diluted to a final volume of {v2} L. "
                    f"Calculate the molarity of the diluted solution.",
            "answer": f"{_n(m2)} mol/L", "solution": f"M₁V₁ = M₂V₂ ⇒ M₂ = ({m1}×{v1}) ÷ {v2} = {_n(m2)} mol/L.",
            "distractors": [f"{_n(m1*f)} mol/L", f"{_n(m1)} mol/L", f"{_n(f)} mol/L"]}


def _g_neutrons(cc, s):
    z = _p(cc, s, "z", 3, 30); nn = _p(cc, s, "n", 2, 40); a = z + nn
    return {"stem": f"An atom has mass number {a} and atomic number {z}. Calculate the number of "
                    f"neutrons in its nucleus.",
            "answer": f"{_n(nn)}", "solution": f"neutrons = mass number − atomic number = {a} − {z} = {_n(nn)}.",
            "distractors": [f"{_n(a+z)}", f"{_n(a)}", f"{_n(z)}"]}


def _g_stp_volume(cc, s):
    n = _p(cc, s, "n", 1, 9); v = n * 22.4
    return {"stem": f"Calculate the volume occupied by {n} mol of an ideal gas at STP.",
            "answer": f"{_n(v)} L", "solution": f"V = n × 22.4 = {n} × 22.4 = {_n(v)} L at STP.",
            "distractors": [f"{_n(n*22)} L", f"{_n(n*11.2)} L", "22.4 L"]}


def _g_ph(cc, s):
    nexp = _p(cc, s, "e", 1, 13)
    return {"stem": f"The hydrogen-ion concentration of a solution is 1 × 10^(−{nexp}) mol/L. "
                    f"Calculate its pH.",
            "answer": f"{_n(nexp)}", "solution": f"pH = −log[H⁺] = −log(10^(−{nexp})) = {_n(nexp)}.",
            "distractors": [f"{_n(14-nexp)}", f"{_n(nexp+1)}", f"{_n(nexp-1) if nexp>1 else '0'}"]}


def _g_reaction_rate(cc, s):
    dt = _p(cc, s, "t", 2, 10); r0 = _p(cc, s, "r", 1, 10); dc = r0 * dt
    return {"stem": f"The concentration of a reactant falls by {dc} mol/L over {dt} s. Calculate the "
                    f"average rate of the reaction.",
            "answer": f"{_n(r0)} mol/L·s", "solution": f"rate = Δ[conc] ÷ Δt = {dc} ÷ {dt} = {_n(r0)} mol/L·s.",
            "distractors": [f"{_n(dc*dt)} mol/L·s", f"{_n(dc)} mol/L·s", f"{_n(dt)} mol/L·s"]}


# ── Mathematics numeric families ────────────────────────────────────────────────────────
def _g_ap_sum(cc, s):
    a = _p(cc, s, "a", 1, 10); d = _p(cc, s, "d", 1, 9); n = _p(cc, s, "n", 3, 15)
    sn = n * (2 * a + (n - 1) * d) // 2
    return {"stem": f"Find the sum of the first {n} terms of an arithmetic progression whose first term "
                    f"is {a} and whose common difference is {d}.",
            "answer": f"{_n(sn)}", "solution": f"Sₙ = n/2·[2a+(n−1)d] = {n}/2·[2×{a}+({n}−1)×{d}] = {_n(sn)}.",
            "distractors": [f"{_n(a+(n-1)*d)}", f"{_n(n*a)}", f"{_n(n*(a+(n-1)*d))}"]}


def _g_gp_nth(cc, s):
    a = _p(cc, s, "a", 1, 5); r = _p(cc, s, "r", 2, 3); n = _p(cc, s, "n", 2, 6); term = a * r ** (n - 1)
    return {"stem": f"Find the {n}th term of a geometric progression whose first term is {a} and whose "
                    f"common ratio is {r}.",
            "answer": f"{_n(term)}", "solution": f"aₙ = a·r^(n−1) = {a}×{r}^{n-1} = {_n(term)}.",
            "distractors": [f"{_n(a*r*n)}", f"{_n(a*r**n)}", f"{_n(a+(n-1)*r)}"]}


def _g_simple_interest(cc, s):
    p = _p(cc, s, "p", 1, 20) * 100; r = _p(cc, s, "r", 2, 15); t = _p(cc, s, "t", 1, 10)
    si = p * r * t // 100
    return {"stem": f"Calculate the simple interest on ₹{p} at {r}% per annum for {t} years.",
            "answer": f"₹{_n(si)}", "solution": f"SI = P·R·T/100 = {p}×{r}×{t}/100 = ₹{_n(si)}.",
            "distractors": [f"₹{_n(p*r*t)}", f"₹{_n(p+r+t)}", f"₹{_n(p*r//100)}"]}


def _g_pythagoras(cc, s):
    triples = [(3, 4, 5), (5, 12, 13), (8, 15, 17), (7, 24, 25), (6, 8, 10), (9, 12, 15), (20, 21, 29)]
    a, b, c = triples[_p(cc, s, "t", 0, len(triples) - 1)]
    return {"stem": f"In a right-angled triangle the two legs measure {a} cm and {b} cm. Calculate the "
                    f"length of the hypotenuse.",
            "answer": f"{_n(c)} cm", "solution": f"h = √(a²+b²) = √({a}²+{b}²) = √{a*a+b*b} = {_n(c)} cm.",
            "distractors": [f"{_n(a+b)} cm", f"{_n(c+1)} cm", f"{_n((a+b)//2)} cm"]}


def _g_ncr(cc, s):
    import math as _m
    n = _p(cc, s, "n", 4, 8); r = _p(cc, s, "r", 2, 3); val = _m.comb(n, r)
    return {"stem": f"Evaluate the number of ways of choosing {r} objects from {n} distinct objects, ⁿCᵣ.",
            "answer": f"{_n(val)}", "solution": f"ⁿCᵣ = n!/(r!(n−r)!) = {n}!/({r}!×{n-r}!) = {_n(val)}.",
            "distractors": [f"{_n(_m.perm(n, r))}", f"{_n(n*r)}", f"{_n(_m.comb(n, r)+r)}"]}


def _g_npr(cc, s):
    import math as _m
    n = _p(cc, s, "n", 4, 8); r = _p(cc, s, "r", 2, 3); val = _m.perm(n, r)
    return {"stem": f"Evaluate the number of ways of arranging {r} objects out of {n} distinct objects, ⁿPᵣ.",
            "answer": f"{_n(val)}", "solution": f"ⁿPᵣ = n!/(n−r)! = {n}!/{n-r}! = {_n(val)}.",
            "distractors": [f"{_n(_m.comb(n, r))}", f"{_n(n**r)}", f"{_n(n*r)}"]}


def _g_factorial(cc, s):
    import math as _m
    n = _p(cc, s, "n", 3, 7); val = _m.factorial(n)
    return {"stem": f"Evaluate {n}! (the factorial of {n}).",
            "answer": f"{_n(val)}", "solution": f"{n}! = {'×'.join(str(k) for k in range(n,0,-1))} = {_n(val)}.",
            "distractors": [f"{_n(n*(n-1))}", f"{_n(n*n)}", f"{_n(_m.factorial(n-1))}"]}


def _g_determinant(cc, s):
    a = _p(cc, s, "a", 1, 9); b = _p(cc, s, "b", 1, 9); c = _p(cc, s, "c", 1, 9); d = _p(cc, s, "d", 1, 9)
    det = a * d - b * c
    return {"stem": f"Evaluate the determinant of the 2×2 matrix [[{a}, {b}], [{c}, {d}]].",
            "answer": f"{_n(det)}", "solution": f"det = ad − bc = ({a}×{d}) − ({b}×{c}) = {_n(det)}.",
            "distractors": [f"{_n(a*d+b*c)}", f"{_n(a*d)}", f"{_n(b*c)}"]}


def _g_percentage(cc, s):
    pct = [10, 20, 25, 40, 50, 75][_p(cc, s, "x", 0, 5)]; nn = _p(cc, s, "n", 2, 20) * 10
    val = pct * nn // 100
    return {"stem": f"Calculate {pct}% of {nn}.",
            "answer": f"{_n(val)}", "solution": f"{pct}% of {nn} = {pct}/100 × {nn} = {_n(val)}.",
            "distractors": [f"{_n(pct*nn)}", f"{_n(pct)}", f"{_n(nn)}"]}


def _g_circle_area(cc, s):
    r = _p(cc, s, "r", 2, 14)
    return {"stem": f"Calculate the area of a circle of radius {r} cm (leave your answer in terms of π).",
            "answer": f"{_n(r*r)}π cm²", "solution": f"A = πr² = π×{r}² = {_n(r*r)}π cm².",
            "distractors": [f"{_n(2*r)}π cm²", f"{_n(r*r)} cm²", f"{_n(2*r*r)}π cm²"]}


def _g_cube_volume(cc, s):
    a = _p(cc, s, "a", 2, 12); v = a ** 3
    return {"stem": f"Calculate the volume of a cube whose edge measures {a} cm.",
            "answer": f"{_n(v)} cm³", "solution": f"V = a³ = {a}³ = {_n(v)} cm³.",
            "distractors": [f"{_n(a*a)} cm³", f"{_n(6*a*a)} cm³", f"{_n(3*a)} cm³"]}


def _g_cuboid_volume(cc, s):
    l = _p(cc, s, "l", 2, 10); b = _p(cc, s, "b", 2, 10); h = _p(cc, s, "h", 2, 10); v = l * b * h
    return {"stem": f"Calculate the volume of a cuboid of length {l} cm, breadth {b} cm and height {h} cm.",
            "answer": f"{_n(v)} cm³", "solution": f"V = l×b×h = {l}×{b}×{h} = {_n(v)} cm³.",
            "distractors": [f"{_n(l+b+h)} cm³", f"{_n(2*(l*b+b*h+h*l))} cm³", f"{_n(l*b)} cm³"]}


def _g_cylinder_volume(cc, s):
    r = _p(cc, s, "r", 2, 7); h = _p(cc, s, "h", 2, 10)
    return {"stem": f"Calculate the volume of a cylinder of base radius {r} cm and height {h} cm "
                    f"(leave your answer in terms of π).",
            "answer": f"{_n(r*r*h)}π cm³", "solution": f"V = πr²h = π×{r}²×{h} = {_n(r*r*h)}π cm³.",
            "distractors": [f"{_n(2*r*h)}π cm³", f"{_n(r*r)}π cm³", f"{_n(r*h)}π cm³"]}


def _g_lcm(cc, s):
    import math as _m
    a = _p(cc, s, "a", 2, 20); b = _p(cc, s, "b", 2, 20); lcm = a * b // _m.gcd(a, b)
    return {"stem": f"Find the least common multiple (LCM) of {a} and {b}.",
            "answer": f"{_n(lcm)}", "solution": f"LCM = (a×b)/HCF = ({a}×{b})/{_m.gcd(a,b)} = {_n(lcm)}.",
            "distractors": [f"{_n(a*b)}", f"{_n(_m.gcd(a,b))}", f"{_n(a+b)}"]}


def _g_discriminant(cc, s):
    a = _p(cc, s, "a", 1, 5); b = _p(cc, s, "b", 2, 9); c = _p(cc, s, "c", 1, 5); disc = b * b - 4 * a * c
    return {"stem": f"Calculate the discriminant of the quadratic equation {a}x² + {b}x + {c} = 0.",
            "answer": f"{_n(disc)}", "solution": f"D = b² − 4ac = {b}² − 4×{a}×{c} = {_n(disc)}.",
            "distractors": [f"{_n(b*b+4*a*c)}", f"{_n(b*b)}", f"{_n(4*a*c)}"]}


# ── Biology numeric / universal families (fabrication-safe: computed or universal law) ───
def _g_magnification_bio(cc, s):
    obj = _p(cc, s, "o", 1, 5); m0 = _p(cc, s, "m", 10, 50); img = m0 * obj
    return {"stem": f"Under a microscope, a cell of actual size {obj} µm appears {img} µm across. "
                    f"Calculate the magnification.",
            "answer": f"{_n(m0)}×", "solution": f"magnification = image size ÷ actual size = {img} ÷ {obj} = {_n(m0)}×.",
            "distractors": [f"{_n(img*obj)}×", f"{_n(img+obj)}×", f"{_n(obj)}×"]}


def _g_hardy_weinberg(cc, s):
    k = (1, 2, 3, 4, 6, 7, 8, 9)[_p(cc, s, "k", 0, 7)]; q = k / 10; p = 1 - q   # q != 0.5 (so p != q)
    return {"stem": f"In a population at Hardy–Weinberg equilibrium the recessive allele frequency (q) is "
                    f"{_n(q)}. Calculate the dominant allele frequency (p).",
            "answer": f"{_n(p)}", "solution": f"p + q = 1 ⇒ p = 1 − {_n(q)} = {_n(p)}.",
            "distractors": [f"{_n(q)}", "1", f"{_n(round(q*q,2))}"]}


def _g_cardiac_output(cc, s):
    hr = _p(cc, s, "h", 60, 90); sv = _p(cc, s, "s", 60, 90); co = hr * sv
    return {"stem": f"A person has a heart rate of {hr} beats/min and a stroke volume of {sv} mL. "
                    f"Calculate the cardiac output.",
            "answer": f"{_n(co)} mL/min", "solution": f"CO = heart rate × stroke volume = {hr} × {sv} = {_n(co)} mL/min.",
            "distractors": [f"{_n(hr+sv)} mL/min", f"{_n(hr)} mL/min", f"{_n(sv)} mL/min"]}


def _g_meiosis_chromosomes(cc, s):
    n2 = _p(cc, s, "n", 2, 24) * 2; hap = n2 // 2
    return {"stem": f"A diploid cell of an organism has {n2} chromosomes. Calculate the number of "
                    f"chromosomes in each gamete produced by meiosis.",
            "answer": f"{_n(hap)}", "solution": f"Meiosis halves the chromosome number: {n2} ÷ 2 = {_n(hap)}.",
            "distractors": [f"{_n(n2)}", f"{_n(n2*2)}", f"{_n(n2-1)}"]}


# ── Universal Assertion–Reason families (both statements are the named law itself) ───────
_AR_OPTS = (
    "Both A and R are true and R is the correct explanation of A",
    "Both A and R are true but R is not the correct explanation of A",
    "A is true but R is false",
    "A is false but R is true",
)


def _ar_family(tid, subject, groups, assertion, reason):
    def build(cc, seed, qtype):
        stem = (f"Assertion (A): {assertion}\n"
                f"Reason (R): {reason}\n"
                "Select the correct option:\n"
                + "\n".join(f"({chr(97+i)}) {o}" for i, o in enumerate(_AR_OPTS)))
        return {"stem": stem, "answer": _AR_OPTS[0], "options": list(_AR_OPTS),
                "solution": "Both statements are true and the Reason is the correct explanation "
                            "of the Assertion (option a)."}
    return Template(tid, subject, groups, (QuestionType.ASSERTION_REASON,), build)


# ── Universal Match-the-Column family (SI units — an international standard, not copyrighted) ─
_SI_UNITS = (("Force", "newton"), ("Work", "joule"), ("Power", "watt"), ("Pressure", "pascal"),
             ("Electric charge", "coulomb"), ("Frequency", "hertz"), ("Resistance", "ohm"),
             ("Potential difference", "volt"))


def _seedkey(cc, seed, k):
    return int(hashlib.sha256(f"{cc}|{seed}|{k}".encode()).hexdigest()[:8], 16)


def _match_si(cc, seed, qtype):
    order = sorted(range(len(_SI_UNITS)), key=lambda i: _seedkey(cc, seed, i))[:4]
    colI = [_SI_UNITS[i][0] for i in order]
    perm = sorted(range(4), key=lambda j: _seedkey(cc, seed, 100 + j))
    colII = [_SI_UNITS[order[j]][1] for j in perm]
    rl, cl = ("i", "ii", "iii", "iv"), ("a", "b", "c", "d")
    stem = ("Match the physical quantity in Column I with its SI unit in Column II:\n"
            "Column I:  " + "   ".join(f"({rl[k]}) {colI[k]}" for k in range(4)) + "\n"
            "Column II: " + "   ".join(f"({cl[k]}) {colII[k]}" for k in range(4)))
    ans = ", ".join(f"({rl[k]})-({cl[colII.index(_SI_UNITS[order[k]][1])]})" for k in range(4))
    return {"stem": stem, "answer": ans, "options": None,
            "solution": "Each quantity is paired with its SI unit: " + ans + "."}


REGISTRY += [
    # Physics
    _num_family("phy_kinetic_energy", "Physics", (("kinetic energy",),), _g_kinetic_energy),
    _num_family("phy_potential_energy", "Physics",
                (("potential energy",), ("gravitational potential energy",)), _g_potential_energy),
    _num_family("phy_work_done", "Physics", (("work done",),), _g_work_done),
    _num_family("phy_power_work", "Physics", (("power", "work"), ("mechanical power",)), _g_power),
    _num_family("phy_momentum", "Physics", (("linear momentum",), ("momentum", "velocity")), _g_momentum),
    _num_family("phy_density", "Physics", (("density",),), _g_density),
    _num_family("phy_pressure", "Physics", (("pressure",),), _g_pressure),
    _num_family("phy_equations_motion", "Physics",
                (("equations of motion",), ("uniformly accelerated",), ("final velocity",)), _g_final_velocity),
    _num_family("phy_weight", "Physics", (("weight", "mass"), ("weight of a body",)), _g_weight),
    _num_family("phy_wave_speed", "Physics",
                (("wave", "speed"), ("velocity of a wave",), ("wave equation",)), _g_wave_speed),
    _num_family("phy_charge_current", "Physics",
                (("charge", "current"), ("electric charge",), ("quantity of charge",)), _g_charge),
    _num_family("phy_electric_power", "Physics",
                (("electric power",), ("electrical power",), ("power", "voltage")), _g_elec_power),
    _num_family("phy_series_resistance", "Physics",
                (("resistors in series",), ("series combination",), ("equivalent resistance",)), _g_resistance_series),
    _num_family("phy_ohmic_power", "Physics",
                (("power", "resistor"), ("heating effect",), ("joule heating",)), _g_ohmic_power),
    _num_family("phy_specific_heat", "Physics",
                (("specific heat",), ("calorimetry",), ("heat capacity",)), _g_specific_heat),
    _num_family("phy_magnification", "Physics",
                (("magnification",), ("magnifying power",)), _g_magnification_phy),
    # Chemistry
    _num_family("chem_molarity", "Chemistry", (("molarity",), ("molar concentration",)), _g_molarity),
    _num_family("chem_mass_moles", "Chemistry", (("mass", "mole"),), _g_mass_from_moles),
    _num_family("chem_dilution", "Chemistry", (("dilution",),), _g_dilution),
    _num_family("chem_neutrons", "Chemistry",
                (("number of neutrons",), ("mass number",), ("atomic structure", "neutron")), _g_neutrons),
    _num_family("chem_molar_volume", "Chemistry",
                (("molar volume",), ("volume at stp",), ("gas", "stp")), _g_stp_volume),
    _num_family("chem_ph", "Chemistry",
                (("ph of a solution",), ("ph scale",), ("hydrogen ion concentration",)), _g_ph),
    _num_family("chem_reaction_rate", "Chemistry",
                (("rate of reaction",), ("reaction rate",), ("average rate",)), _g_reaction_rate),
    # Mathematics
    _num_family("math_ap_sum", "Mathematics",
                (("sum of an arithmetic",), ("sum of ap",), ("sum of n terms",)), _g_ap_sum),
    _num_family("math_gp_nth", "Mathematics",
                (("geometric progression",), ("geometric sequence",)), _g_gp_nth),
    _num_family("math_simple_interest", "Mathematics", (("simple interest",),), _g_simple_interest),
    _num_family("math_pythagoras", "Mathematics",
                (("pythagoras",), ("pythagorean",), ("right triangle", "hypotenuse")), _g_pythagoras),
    _num_family("math_combinations", "Mathematics", (("combination",), ("ncr",)), _g_ncr),
    _num_family("math_permutations", "Mathematics", (("permutation",), ("npr",)), _g_npr),
    _num_family("math_factorial", "Mathematics", (("factorial",),), _g_factorial),
    _num_family("math_determinant", "Mathematics", (("determinant",),), _g_determinant),
    _num_family("math_percentage", "Mathematics", (("percentage",), ("percent",)), _g_percentage),
    _num_family("math_circle_area", "Mathematics", (("area of a circle",), ("area", "circle")), _g_circle_area),
    _num_family("math_cube_volume", "Mathematics", (("volume of a cube",), ("volume", "cube")), _g_cube_volume),
    _num_family("math_cuboid_volume", "Mathematics", (("volume of a cuboid",), ("cuboid",)), _g_cuboid_volume),
    _num_family("math_cylinder_volume", "Mathematics", (("volume of a cylinder",), ("cylinder",)), _g_cylinder_volume),
    _num_family("math_lcm", "Mathematics", (("lcm",), ("least common multiple",)), _g_lcm),
    _num_family("math_discriminant", "Mathematics",
                (("discriminant",), ("nature of roots",), ("quadratic equation", "discriminant")), _g_discriminant),
    # Biology
    _num_family("bio_magnification", "Biology", (("magnification",),), _g_magnification_bio),
    _num_family("bio_hardy_weinberg", "Biology",
                (("hardy", "weinberg"), ("allele frequency",), ("genetic equilibrium",)), _g_hardy_weinberg),
    _num_family("bio_cardiac_output", "Biology", (("cardiac output",),), _g_cardiac_output),
    _num_family("bio_meiosis_chromosomes", "Biology",
                (("meiosis",), ("gamete", "chromosome")), _g_meiosis_chromosomes),
    # Universal Assertion–Reason (named laws stated as A + R)
    _ar_family("ar_newton_first", "Physics", (("newton", "first law"), ("law of inertia",)),
               "A body continues in its state of rest or uniform motion unless acted upon by an "
               "external unbalanced force.",
               "By Newton's first law (the law of inertia), a body resists any change in its state of motion."),
    _ar_family("ar_ohm", "Physics", (("ohm", "law"),),
               "For a metallic conductor at constant temperature, the current is directly proportional "
               "to the potential difference across it.",
               "By Ohm's law, V = IR with R constant at constant temperature."),
    _ar_family("ar_momentum_conservation", "Physics", (("conservation of momentum",),),
               "In the absence of an external force, the total momentum of a system remains constant.",
               "By the law of conservation of momentum, momentum is conserved for an isolated system."),
    _ar_family("ar_archimedes", "Physics", (("archimedes",),),
               "A body immersed in a fluid experiences an upward buoyant force.",
               "By Archimedes' principle, the buoyant force equals the weight of the fluid displaced."),
    # Universal Match-the-Column (SI units)
    Template("phy_match_si_units", "Physics",
             (("si units",), ("units and measurement",), ("physical quantities",),
              ("units and dimensions",)), (QuestionType.MATCH,), _match_si),
]


def _norm(title: str) -> str:
    return (title or "").lower().replace("’", "'").replace("‘", "'")


def _group_matches(group: tuple, title: str) -> bool:
    return all(sub in title for sub in group)


def find_template(subject: Optional[str], title: str, qtype: str) -> Optional[Template]:
    """Return a template that clearly matches this concept + question type, else None.

    Conservative: requires ALL substrings of some keyword group to be present, so an unrelated
    topic never gets an off-concept numerical. When unsure, returns None (slot stays a spec)."""
    t = _norm(title)
    for tmpl in REGISTRY:
        if tmpl.subject == subject and qtype in tmpl.types \
                and any(_group_matches(g, t) for g in tmpl.keyword_groups):
            return tmpl
    return None


def instantiate(template: Template, concept_code: str, seed: int, qtype: str) -> dict:
    """Deterministically build one solver-verified instance."""
    out = template.build(concept_code, seed, qtype)
    out["template_id"] = template.template_id
    out["solver_verified"] = True
    return out
