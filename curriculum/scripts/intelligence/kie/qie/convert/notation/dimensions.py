"""Unit / dimension engine — the deterministic backbone of relation certification.

Maps a recovered symbol's declared unit string ("C^2 N^-1 m^-2") to a sympy SI quantity, and reduces any
expression to BASE dimensions so two differently-written but physically identical sides compare equal
(`A*ohm` == `V`). This is what independently catches transcription/OCR damage in a recovered equation:
a lost exponent or a misplaced constant changes the base dimensions and is rejected.

Deterministic; sympy-only; no model involvement.
"""
from __future__ import annotations

import re
from typing import Dict, Optional

import sympy as sp
from sympy.physics.units import (ampere, candela, coulomb, farad, henry, hertz, joule, kelvin,
                                 kilogram, meter, mole, newton, ohm, pascal, second, siemens, tesla, volt,
                                 watt, weber)
from sympy.physics.units.systems.si import SI

_DS = SI.get_dimension_system()

# unit token -> sympy quantity. Covers the SI + derived units our STEM sources actually use.
UNITS: Dict[str, object] = {
    "m": meter, "meter": meter, "metre": meter,
    "s": second, "sec": second, "second": second,
    "kg": kilogram, "g": kilogram / 1000, "gram": kilogram / 1000,
    "A": ampere, "ampere": ampere, "amp": ampere,
    "K": kelvin, "kelvin": kelvin,
    "mol": mole, "mole": mole,
    "cd": candela,
    "N": newton, "newton": newton,
    "J": joule, "joule": joule,
    "W": watt, "watt": watt,
    "C": coulomb, "coulomb": coulomb,
    "V": volt, "volt": volt,
    "ohm": ohm, "Ohm": ohm, "Ω": ohm,
    "F": farad, "farad": farad,
    "H": henry, "henry": henry,
    "S": siemens, "siemens": siemens,
    "Hz": hertz, "hertz": hertz,
    "Pa": pascal, "pascal": pascal,
    "T": tesla, "tesla": tesla,
    "Wb": weber, "weber": weber,
    "L": meter ** 3 / 1000, "litre": meter ** 3 / 1000, "liter": meter ** 3 / 1000,
    "1": sp.Integer(1), "": sp.Integer(1), "dimensionless": sp.Integer(1),
}

_TOKEN = re.compile(r"([A-Za-zΩ]+|1)\s*(?:\^|\*\*)?\s*(-?\d+)?")


def parse_unit(unit_str: str) -> Optional[object]:
    """Parse a unit string into a sympy quantity. Accepts "N", "m/s^2", "C^2 N^-1 m^-2", "kg m s^-2"."""
    if unit_str is None:
        return None
    s = unit_str.strip()
    if not s or s in ("1", "dimensionless", "-"):
        return sp.Integer(1)
    # normalize: split a single '/' into negative exponents on the right side
    if "/" in s:
        num, den = s.split("/", 1)
        n, d = parse_unit(num), parse_unit(den)
        if n is None or d is None:
            return None
        return n / d
    expr = sp.Integer(1)
    found = False
    for m in _TOKEN.finditer(s.replace("·", " ").replace("*", " ")):
        tok, exp = m.group(1), m.group(2)
        if tok not in UNITS:
            return None
        found = True
        expr = expr * (UNITS[tok] ** (int(exp) if exp else 1))
    return expr if found else None


def base_dims(expr) -> Optional[Dict]:
    """Reduce an expression carrying units to its BASE dimension exponents, or None if inconsistent
    (e.g. an illegal sum of unlike units — itself a genuine rejection signal)."""
    try:
        _f, d = SI._collect_factor_and_dimension(expr)
        return dict(_DS.get_dimensional_dependencies(d))
    except Exception:
        return None


def dimensionally_equal(lhs, rhs) -> bool:
    a, b = base_dims(lhs), base_dims(rhs)
    return a is not None and b is not None and a == b


# distinct coefficients keep like-unit terms from CANCELLING under substitution: a relation such as
# `W = K_f - K_i` would otherwise become `joule - joule = 0` and lose its dimension (a false rejection).
# A scalar multiplier cannot change a dimension, so this is safe.
_DISTINCT = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37)


def substitute_units(equation_rhs: str, symbol_units: Dict[str, str]):
    """Build the RHS expression with every symbol replaced by its declared unit quantity (scaled by a
    distinct coefficient so like-unit terms cannot cancel). Returns None when a symbol has no
    declared/parseable unit (we never guess a unit)."""
    loc: Dict[str, object] = {"pi": sp.pi, "e": sp.E}
    for i, (sym, u) in enumerate(sorted((symbol_units or {}).items())):
        q = parse_unit(u)
        if q is None:
            return None
        loc[sym] = sp.Rational(_DISTINCT[i % len(_DISTINCT)]) * q
    try:
        return sp.sympify(equation_rhs, locals=loc)
    except Exception:
        return None


def check_relation(lhs_unit: str, rhs_expr: str, symbol_units: Dict[str, str]) -> dict:
    """The dimensional gate: does the recovered RHS carry exactly the LHS's dimensions?"""
    lhs_q = parse_unit(lhs_unit)
    if lhs_q is None:
        return {"ok": False, "reason": f"unparseable LHS unit {lhs_unit!r}"}
    rhs_q = substitute_units(rhs_expr, symbol_units)
    if rhs_q is None:
        return {"ok": False, "reason": "unparseable RHS or an undeclared symbol unit"}
    lb, rb = base_dims(lhs_q), base_dims(rhs_q)
    if lb is None or rb is None:
        return {"ok": False, "reason": "dimensionally inconsistent expression (illegal sum of unlike units)"}
    def _j(d):                                   # json-safe: sympy exponents -> int
        return {str(k): int(v) for k, v in d.items()}
    return {"ok": lb == rb, "lhs_dims": _j(lb), "rhs_dims": _j(rb),
            "reason": "" if lb == rb else "LHS/RHS base dimensions differ"}
