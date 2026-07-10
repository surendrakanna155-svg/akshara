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
from dataclasses import dataclass
from typing import Callable, List, Optional

from kie.qpgen.models import QuestionType


def _p(concept_code: str, seed: int, name: str, lo: int, hi: int) -> int:
    """Deterministic integer parameter in [lo, hi] from (concept_code, seed, name)."""
    h = int(hashlib.sha256(f"{concept_code}|{seed}|{name}".encode()).hexdigest()[:8], 16)
    return lo + (h % (hi - lo + 1))


def _mcq_options(correct, distractors: List, concept_code: str, seed: int) -> List[str]:
    """Deterministically ordered 4 options (one correct + 3 distractors), de-duplicated."""
    opts, seen = [], set()
    for v in [correct] + distractors:
        s = str(v)
        if s not in seen:
            seen.add(s)
            opts.append(s)
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
