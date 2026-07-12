"""Math-appropriate deterministic structure model (Phase B8, Track 2).

The B7/B8 audit found the retained gate's Mathematics count was INFLATED: `guess_subject` mis-attributes
Physics/Chemistry items to Mathematics, and those items carry 4-5 OCR-parsed numbers, so the permutation
search in `relations.verify` finds SOME Math formula that reproduces the answer WITHIN TOLERANCE BY
COINCIDENCE (e.g. a lens/optics item "verifying" area_trap via 0.5*(1+10)*2=11). That is a false relation
match, not a verified Math model.

This module is the Math analogue of the Biology answer-entity resolver — but structure-first, not answer-
entity, because Math answers are numbers, not concept names. It resolves an item's MATHEMATICAL STRUCTURE:

  * a TOPIC SIGNATURE from math objects / operators / vocabulary (geometry-area, sequence-AP, statistics-
    mean, …), with a hard SCIENCE VETO (physics/chem/bio content words) and a section-heading / OCR-noise
    veto, so mis-attributed science and headings resolve to None (unresolved) rather than a spurious topic;
  * a RELATION SCHEMA via the independent relation solver (single-step and a guarded 2-step chain),
    accepted ONLY when the matched relation's FAMILY is consistent with the resolved topic signature —
    this is what kills the coincidental cross-family matches (an optics item cannot count as a trapezium
    area even if the numbers happen to fit);
  * algebraic-equivalence normalisation so relations with the same closed form (a*b for rectangle vs
    parallelogram; a*b*c for cuboid) collapse to ONE schema and are not double counted.

Verification strength is UNCHANGED (same relation library, same 2% tolerance, independent solver); this
module only adds PRECISION (removing false matches) — it never lowers a bar. Deterministic, stdlib-only.
Read-only. Returns None whenever confidence is insufficient.
"""
from __future__ import annotations

import itertools
import re
from typing import Dict, List, Optional, Sequence, Tuple

from kie.qie import relations as R

# ── hard SCIENCE veto: content words that mean the item is physics/chem/bio, not mathematics ──────────
_SCIENCE_VETO = re.compile(
    r"\b(velocity|acceleration|force|newton|newtons|momentum|kinetic|potential energy|circular motion|"
    r"orbit|planet|satellite|bullet|projectile|harmonic|overtone|pipe|wavelength|frequency|amplitude|"
    r"transformer|current|voltage|resistor|resistance|capacitor|inductor|magnetic|electric field|"
    r"photon|electron|proton|neutron|nucleus|isotope|atom|atomic|molecule|molar|mole|valency|"
    r"osmotic|solute|solvent|solution|reaction|enzyme|protein|mrna|\bdna\b|respiratory|photosynthesis|"
    r"soap bubble|surface tension|viscosity|gravitation|escape velocity|refractive|refraction|lens|"
    r"lenses|mirror|convex|concave|prism|thermal|calorie|entropy|enthalpy|gas constant|pressure|"
    r"young.?s modulus|elasticity|density of|rolls on|whirled|roller coaster|weightless|"
    r"crystalline|lattice|fcc|bcc|radioactive|half.?life|emf|ohm|watt|joule|pascal|coulomb|"
    r"tidal volume|blood|cell|tissue|hormone|organ)\b", re.I)

# ── section-heading / OCR-noise veto: the item is not a solvable problem at all ───────────────────────
_NOISE_VETO = re.compile(
    r"^(a note for the teacher|constitution of india|fundamental duties|preface|contents|chapter\b|"
    r"exercise\b|activity\b|introduction\b|summary\b|glossary\b|appendix\b|answers?\b)", re.I)

# ── topic signatures: math objects / operators / vocabulary -> a canonical topic family ───────────────
# each entry: (topic_family, regex). First hit wins; families gate which relation schemas may be accepted.
_TOPIC_SIGNATURES: Tuple[Tuple[str, "re.Pattern[str]"], ...] = (
    ("geometry_area", re.compile(
        r"\b(area of|areas? (?:related to|of)|surface area|find the area|region bounded)\b", re.I)),
    ("geometry_perimeter", re.compile(
        r"\b(perimeter|circumference|boundary length)\b", re.I)),
    ("geometry_volume", re.compile(
        r"\b(volume of|capacity of|cubic (?:cm|m|metre|centimetre)|solid (?:cylinder|sphere|cone|cube|cuboid)|"
        r"clay to make|melted (?:and )?(?:re)?cast)\b", re.I)),
    ("sequence_progression", re.compile(
        r"\b(arithmetic progression|geometric progression|\bA\.?P\.?\b|\bG\.?P\.?\b|nth term|n-?th term|"
        r"common difference|common ratio|sum of (?:the )?(?:first )?\w+ terms|sum of (?:first )?n\b|"
        r"terms? of the (?:sequence|series))\b", re.I)),
    ("statistics_mean", re.compile(
        r"\b(average of|mean of|arithmetic mean|find the mean|combined mean)\b", re.I)),
    ("interest", re.compile(
        r"\b(simple interest|compound interest|principal|rate of interest|per annum|amount after)\b", re.I)),
    ("probability", re.compile(
        r"\b(probability|likely|at random|a (?:die|dice) is (?:thrown|rolled)|drawn at random)\b", re.I)),
    ("algebra_roots", re.compile(
        r"\b(quadratic|roots of|zeroes? of|sum of the roots|product of the roots|discriminant)\b", re.I)),
    ("right_triangle", re.compile(
        r"\b(pythagoras|pythagorean|hypotenuse|right[- ]angled triangle|diagonal of (?:a )?(?:rectangle|square))\b",
        re.I)),
)

# ── relation FAMILIES: a matched relation counts only if its family matches the item's topic signature ─
_RELATION_FAMILY: Dict[str, str] = {
    # geometry_area
    "area_rect": "geometry_area", "area_tri": "geometry_area", "area_circle": "geometry_area",
    "area_para": "geometry_area", "area_trap": "geometry_area", "surface_sphere": "geometry_area",
    "tsa_cylinder": "geometry_area",
    # geometry_perimeter
    "perimeter_rect": "geometry_perimeter", "circumference": "geometry_perimeter",
    # geometry_volume
    "vol_cube": "geometry_volume", "vol_cuboid": "geometry_volume", "vol_cyl": "geometry_volume",
    "vol_sphere": "geometry_volume", "vol_cone": "geometry_volume",
    # sequence_progression
    "ap_nth3": "sequence_progression", "ap_sum": "sequence_progression", "gp_nth": "sequence_progression",
    "gp_sum": "sequence_progression", "sum_n": "sequence_progression", "sum_n2": "sequence_progression",
    # statistics_mean
    "mean2": "statistics_mean", "avg3": "statistics_mean",
    # interest
    "SI": "interest", "CI2": "interest",
    # probability
    "prob": "probability",
    # algebra_roots
    "quadratic_sum_roots": "algebra_roots", "quadratic_prod_roots": "algebra_roots",
    # right_triangle
    "pythag": "right_triangle", "diagonal_rect": "right_triangle",
}

# algebraic-equivalence: relations with the same closed form collapse to one schema (no double count)
_SCHEMA_CANON: Dict[str, str] = {
    "area_rect": "product_ab", "area_para": "product_ab", "vol_cuboid": "product_abc",
    "perimeter_rect": "two_sum_ab", "area_tri": "half_ab",
}


def _science_or_noise(stem: str) -> bool:
    s = (stem or "").strip()
    return bool(_NOISE_VETO.search(s) or _SCIENCE_VETO.search(s))


def math_topic(stem: str) -> Optional[str]:
    """Resolve an item's canonical Math TOPIC SIGNATURE, or None when it is science / heading / noise, or
    carries no confident math-topic signal. Strict — an item with a science veto word is never a Math topic."""
    if _science_or_noise(stem):
        return None
    for family, pat in _TOPIC_SIGNATURES:
        if pat.search(stem or ""):
            return family
    return None


def _match_single(given: Sequence[float], target: float, families_ok: str) -> Optional[str]:
    """Single-step relation match restricted to the topic's family (independent solver, 2% tol unchanged)."""
    tol = 0.02 * max(abs(target), 1e-9)
    for rel in R.LIBRARY:
        if rel.subject != "Mathematics" or _RELATION_FAMILY.get(rel.name) != families_ok:
            continue
        if len(given) < rel.arity:
            continue
        for combo in itertools.permutations(given, rel.arity):
            v = rel.fn(*combo)
            if v is not None and abs(v - target) <= tol:
                return rel.name
    return None


# Only LINEAR / product-form relations may participate in a chain. Nonlinear "curved" formulas (π-based
# surface/volume, powers, compound interest, pythagoras) span a huge output range and would let a 2-step
# search brute-force nearly any target — the exact false-match vector a chain must NOT open. Whitelisted so
# multi-step stays as strict as single-step, never a back door.
_CHAIN_ELIGIBLE = frozenset({
    "area_rect", "area_para", "area_tri", "area_trap", "perimeter_rect", "vol_cuboid",
    "ap_nth3", "ap_sum", "mean2", "avg3", "SI",
})
_CHAIN_TOL = 0.005   # stricter than single-step: the larger 2-step search space demands a tighter match


def _match_two_step(given: Sequence[float], target: float, families_ok: str) -> Optional[Tuple[str, str]]:
    """Guarded 2-step chain: relation1 produces an intermediate that, fed forward with the REMAINING givens,
    relation2 reproduces the target. Both relations must be in the topic's family AND on the linear/product
    chain-allowlist; the chain must consume ALL given numbers (no cherry-picked subset); the final match uses
    a stricter tolerance. Bounded to <=4 givens. Together these keep multi-step from brute-forcing a target."""
    if len(given) > 4 or len(given) < 2:
        return None
    tol = _CHAIN_TOL * max(abs(target), 1e-9)
    fam_rels = [r for r in R.LIBRARY if r.subject == "Mathematics"
                and _RELATION_FAMILY.get(r.name) == families_ok and r.name in _CHAIN_ELIGIBLE]
    n = len(given)
    for r1 in fam_rels:
        if r1.arity >= n:                       # step 1 must leave >=1 number for step 2
            continue
        for combo in itertools.permutations(range(n), r1.arity):
            inter = r1.fn(*(given[i] for i in combo))
            if inter is None:
                continue
            rest = [given[i] for i in range(n) if i not in combo]
            for r2 in fam_rels:
                if r2.arity - 1 != len(rest):    # consume-all: the chain must use every given number
                    continue
                for c2 in itertools.permutations(rest, len(rest)):
                    for pos in range(r2.arity):
                        args = list(c2)
                        args.insert(pos, inter)
                        v = r2.fn(*args)
                        if v is not None and abs(v - target) <= tol:
                            return (r1.name, r2.name)
    return None


def resolve_math_structure(stem: str, given: Sequence[float], target: Optional[float]) -> Optional[dict]:
    """Return a structure record iff the item is a confident Math topic AND an independent relation (single
    or guarded 2-step chain) in that topic's family reproduces the numeric answer. Else None (unresolved).

    record = {topic, schema, relation, steps, multi_step} — `schema` is the algebraic-equivalence-normalised
    cluster key used by the gate (so equivalent forms are one model, and cross-family coincidences never
    appear because the relation family had to match the topic)."""
    topic = math_topic(stem)
    if topic is None or target is None or not given:
        return None
    rel = _match_single(given, target, topic)
    if rel is not None:
        return {"topic": topic, "relation": rel, "schema": _SCHEMA_CANON.get(rel, rel),
                "steps": [rel], "multi_step": False}
    chain = _match_two_step(given, target, topic)
    if chain is not None:
        schema = f"chain:{_SCHEMA_CANON.get(chain[0], chain[0])}->{_SCHEMA_CANON.get(chain[1], chain[1])}"
        return {"topic": topic, "relation": chain[1], "schema": schema,
                "steps": list(chain), "multi_step": True}
    return None
