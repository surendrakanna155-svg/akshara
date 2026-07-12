"""Relation library v0 — the backbone of NUMERIC_RELATIONAL independent verification (GATE 4/5).

This is the deterministic "second solver": given the numeric quantities in an item and its stated answer,
`verify()` asks whether ANY library relation, fed those quantities, reproduces the answer within tolerance.
It is implemented INDEPENDENTLY of any generator — the same code must never both generate and verify an item
(that self-consistency was the old `solver_verified=True` defect). Promoted and hardened from the Phase-0b
mining spike (which reached 60% numeric verification aggregate on real corpus MCQs).

Each relation declares its arity and a dimension tag so a later dimensional gate can reason about units.
stdlib-only, deterministic.
"""
from __future__ import annotations

import itertools
import math
import re
from dataclasses import dataclass
from typing import Callable, List, Optional, Sequence, Tuple


@dataclass(frozen=True)
class Relation:
    name: str
    arity: int                       # number of input quantities
    fn: Callable[..., Optional[float]]
    subject: str                     # Physics | Chemistry | Mathematics
    dim: str = ""                    # informal result dimension tag (for the future dimensional gate)


def _safe(fn):
    def wrapped(*a):
        try:
            v = fn(*a)
            if v is None or isinstance(v, complex):
                return None
            if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
                return None
            return float(v)
        except (ZeroDivisionError, ValueError, OverflowError, TypeError):
            return None
    return wrapped


def _R(name, arity, fn, subject, dim=""):
    return Relation(name, arity, _safe(fn), subject, dim)


# ── library v0 (authored from standard curriculum; NOT reverse-engineered from any sample) ──────────
LIBRARY: Tuple[Relation, ...] = (
    # Physics
    _R("V=IR", 2, lambda a, b: a * b, "Physics", "V"),
    _R("R=V/I", 2, lambda a, b: a / b, "Physics", "ohm"),
    _R("I=V/R", 2, lambda a, b: a / b, "Physics", "A"),
    _R("F=ma", 2, lambda a, b: a * b, "Physics", "N"),
    _R("a=F/m", 2, lambda a, b: a / b, "Physics", "m/s2"),
    _R("Q=It", 2, lambda a, b: a * b, "Physics", "C"),
    _R("I=Q/t", 2, lambda a, b: a / b, "Physics", "A"),
    _R("P=VI", 2, lambda a, b: a * b, "Physics", "W"),
    _R("P=I2R", 2, lambda a, b: a * a * b, "Physics", "W"),
    _R("P=V2/R", 2, lambda a, b: a * a / b, "Physics", "W"),
    _R("W=Fd", 2, lambda a, b: a * b, "Physics", "J"),
    _R("KE=.5mv2", 2, lambda a, b: 0.5 * a * b * b, "Physics", "J"),
    _R("PE_g10", 2, lambda a, b: a * 10 * b, "Physics", "J"),
    _R("PE_g98", 2, lambda a, b: a * 9.8 * b, "Physics", "J"),
    _R("rho=m/V", 2, lambda a, b: a / b, "Physics", "kg/m3"),
    _R("P=F/A", 2, lambda a, b: a / b, "Physics", "Pa"),
    _R("v=d/t", 2, lambda a, b: a / b, "Physics", "m/s"),
    _R("p=mv", 2, lambda a, b: a * b, "Physics", "kg.m/s"),
    _R("W=mg10", 1, lambda a: a * 10, "Physics", "N"),
    _R("W=mg98", 1, lambda a: a * 9.8, "Physics", "N"),
    _R("v=fL", 2, lambda a, b: a * b, "Physics", "m/s"),
    _R("f=1/T", 1, lambda a: 1 / a, "Physics", "Hz"),
    _R("v=u+at", 3, lambda a, b, c: a + b * c, "Physics", "m/s"),
    _R("a=(v-u)/t", 3, lambda a, b, c: (a - b) / c, "Physics", "m/s2"),
    _R("impulse=Ft", 2, lambda a, b: a * b, "Physics", "N.s"),
    _R("Rseries", 2, lambda a, b: a + b, "Physics", "ohm"),
    _R("Rparallel", 2, lambda a, b: a * b / (a + b), "Physics", "ohm"),
    _R("heat=mcT", 3, lambda a, b, c: a * b * c, "Physics", "J"),
    # Chemistry
    _R("n=m/M", 2, lambda a, b: a / b, "Chemistry", "mol"),
    _R("m=nM", 2, lambda a, b: a * b, "Chemistry", "g"),
    _R("M1V1=M2V2", 3, lambda a, b, c: a * b / c, "Chemistry", "conc"),
    _R("molarity=n/V", 2, lambda a, b: a / b, "Chemistry", "mol/L"),
    _R("V_STP=n*22.4", 1, lambda a: a * 22.4, "Chemistry", "L"),
    _R("n=V/22.4", 1, lambda a: a / 22.4, "Chemistry", "mol"),
    _R("pH=-log", 1, lambda a: -math.log10(a) if a > 0 else None, "Chemistry", "pH"),
    # Mathematics
    _R("area_rect", 2, lambda a, b: a * b, "Mathematics", "area"),
    _R("area_tri", 2, lambda a, b: 0.5 * a * b, "Mathematics", "area"),
    _R("area_circle", 1, lambda a: math.pi * a * a, "Mathematics", "area"),
    _R("area_para", 2, lambda a, b: a * b, "Mathematics", "area"),
    _R("area_trap", 3, lambda a, b, c: 0.5 * (a + b) * c, "Mathematics", "area"),
    _R("perimeter_rect", 2, lambda a, b: 2 * (a + b), "Mathematics", "len"),
    _R("circumference", 1, lambda a: 2 * math.pi * a, "Mathematics", "len"),
    _R("vol_cube", 1, lambda a: a ** 3, "Mathematics", "vol"),
    _R("vol_cuboid", 3, lambda a, b, c: a * b * c, "Mathematics", "vol"),
    _R("vol_cyl", 2, lambda a, b: math.pi * a * a * b, "Mathematics", "vol"),
    _R("vol_sphere", 1, lambda a: 4 / 3 * math.pi * a ** 3, "Mathematics", "vol"),
    _R("vol_cone", 2, lambda a, b: 1 / 3 * math.pi * a * a * b, "Mathematics", "vol"),
    _R("ap_nth3", 3, lambda a, b, c: a + (b - 1) * c, "Mathematics", "num"),
    _R("ap_sum", 3, lambda a, b, c: b / 2 * (2 * a + (b - 1) * c), "Mathematics", "num"),
    _R("mean2", 2, lambda a, b: (a + b) / 2, "Mathematics", "num"),
    _R("SI", 3, lambda a, b, c: a * b * c / 100, "Mathematics", "money"),
    _R("CI2", 3, lambda a, b, c: a * (1 + b / 100) ** c - a, "Mathematics", "money"),
    _R("percent", 2, lambda a, b: a * b / 100, "Mathematics", "num"),
    _R("pythag", 2, lambda a, b: math.sqrt(a * a + b * b), "Mathematics", "len"),
    _R("prob", 2, lambda a, b: a / b, "Mathematics", "prob"),
    _R("ratio", 2, lambda a, b: a / b, "Mathematics", "ratio"),
)


def parse_numbers(text: str) -> List[float]:
    """Extract numeric quantities, best-effort reconstructing OCR-flattened scientific notation.

    Handles en/em-dash minus, thousands commas, and `a x 10 b` (superscript lost) forms. Sign of a lost
    exponent is genuinely unrecoverable from flattened text, so magnitude is taken as written.
    """
    s = text.replace("–", "-").replace("—", "-").replace("−", "-").replace(",", "")
    out: List[float] = []
    for m in re.finditer(r"(-?\d+(?:\.\d+)?)\s*[x×*]\s*10\s*(-?\d+)", s):
        exp = int(m.group(2))
        if abs(exp) > 100:         # implausible exponent from OCR garble (real physics <= ~35) — skip
            continue
        try:
            out.append(float(m.group(1)) * (10.0 ** exp))
        except (OverflowError, ValueError):
            continue
    tmp = re.sub(r"(-?\d+(?:\.\d+)?)\s*[x×*]\s*10\s*(-?\d+)", "", s)
    for m in re.finditer(r"-?\d+(?:\.\d+)?", tmp):
        try:
            out.append(float(m.group(0)))
        except ValueError:
            pass
    return out


def first_number(text: str) -> Optional[float]:
    ns = parse_numbers(text)
    return ns[0] if ns else None


def verify(given: Sequence[float], target: float, tol: float = 0.02,
           subject: Optional[str] = None) -> Optional[str]:
    """Return the name of a library relation that reproduces `target` from some ordered subset of `given`
    quantities within relative tolerance `tol`, else None. Independent of any generator.

    `subject` (optional) restricts the search to that subject's relations — faster and fewer false matches.
    """
    if target is None or not given:
        return None
    pool = [r for r in LIBRARY if subject is None or r.subject == subject]
    thresh = tol * max(abs(target), 1e-9)
    for r in pool:
        if len(given) < r.arity:
            continue
        for combo in itertools.permutations(given, r.arity):
            val = r.fn(*combo)
            if val is not None and abs(val - target) <= thresh:
                return r.name
    return None


def library_size() -> int:
    return len(LIBRARY)
