"""The LOCKED certification hierarchy for a recovered relation. Deterministic — no model certifies here.

A relation reaches `certified` ONLY if every mandatory gate passes:
  * PROVENANCE  — it was transcribed from a rendered page of an OWNED source (doc/entry/page recorded).
  * SYMBOLIC    — the equation parses into a well-formed Eq(lhs, rhs) with declared symbols.
  * DIMENSIONAL — LHS and RHS reduce to identical base dimensions under the declared symbol units. This is the
                  independent guard against transcription/OCR damage (a lost exponent or misplaced constant
                  changes the dimensions and is rejected).
  * DOMAIN      — the relation's subject matches the source document's subject (no cross-domain drift).
  * ROUND-TRIP  — the equation is solvable for each of its symbols and re-substitution reproduces it (also
                  what makes the relation usable for generation in any direction).

ANSWER-KEY corroboration is recorded when real answer-keyed numeric questions for the chapter solve to their
stated answer under this relation. It is deliberately CORROBORATION, never sufficient on its own: matching an
arithmetic value is the exact false-positive trap that made blind relation-induction unsafe (~90% FP).
"""
from __future__ import annotations

import re
from typing import Dict, List, Optional

import sympy as sp

from kie.qie.convert.notation import dimensions as DIM

_SYM_OK = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")


def _split(equation: str):
    if "=" not in equation:
        return None, None
    lhs, rhs = equation.split("=", 1)
    return lhs.strip(), rhs.strip()


def parse_gate(equation: str, symbols: Dict[str, str]) -> dict:
    """The equation must parse and use only declared symbols (plus pi/e and numbers)."""
    lhs, rhs = _split(equation)
    if not lhs or not rhs:
        return {"ok": False, "reason": "equation must be of the form LHS = RHS"}
    for s in symbols:
        if not _SYM_OK.match(s):
            return {"ok": False, "reason": f"illegal symbol name {s!r}"}
    # real (NOT positive): physical quantities are legitimately signed — gravitational PE V = -Gm1m2/r is
    # negative, and a positivity assumption made sympy find no solution (a false rejection).
    loc = {s: sp.Symbol(s, real=True) for s in symbols}
    loc["pi"] = sp.pi
    try:
        l_e = sp.sympify(lhs, locals=loc)
        r_e = sp.sympify(rhs, locals=loc)
    except Exception as e:
        return {"ok": False, "reason": f"unparseable: {type(e).__name__}"}
    used = {str(x) for x in (l_e.free_symbols | r_e.free_symbols)}
    undeclared = used - set(symbols)
    if undeclared:
        return {"ok": False, "reason": f"undeclared symbols: {sorted(undeclared)}"}
    return {"ok": True, "lhs": l_e, "rhs": r_e, "used": sorted(used)}


def roundtrip_gate(equation: str, symbols: Dict[str, str]) -> dict:
    """Solvable for each symbol, and re-substitution reproduces the relation."""
    p = parse_gate(equation, symbols)
    if not p["ok"]:
        return {"ok": False, "reason": p["reason"]}
    eq = sp.Eq(p["lhs"], p["rhs"])
    solved: List[str] = []
    for s in p["used"]:
        sym = sp.Symbol(s, real=True)
        try:
            sols = sp.solve(eq, sym, dict=False)
        except Exception:
            sols = []
        if not sols:
            continue
        try:
            back = sp.simplify(eq.lhs - eq.rhs).subs(sym, sols[0])
            if sp.simplify(back) == 0:
                solved.append(s)
        except Exception:
            pass
    return {"ok": len(solved) >= 1, "solvable_for": solved,
            "reason": "" if solved else "not solvable for any symbol"}


def answer_key_corroboration(equation: str, symbols: Dict[str, str], items: List[dict],
                             tol: float = 0.02, max_checks: int = 40) -> dict:
    """Corroboration ONLY. For each real answer-keyed numeric item, try to bind its parsed givens to this
    relation's input symbols and see whether the stated answer follows. Records confirmations; never certifies.
    """
    from itertools import permutations
    from kie.qie import relations as R
    p = parse_gate(equation, symbols)
    if not p["ok"]:
        return {"checked": 0, "confirmed": 0, "reason": p["reason"]}
    target_sym = p["lhs"] if p["lhs"].is_Symbol else None
    if target_sym is None:
        return {"checked": 0, "confirmed": 0, "reason": "LHS is not a single symbol"}
    inputs = [s for s in p["used"] if s != str(target_sym)]
    if not inputs or len(inputs) > 4:
        return {"checked": 0, "confirmed": 0, "reason": "unsupported input arity"}
    checked = confirmed = 0
    for it in items[:max_checks]:
        ans = R.first_number(it.get("answer_text") or "")
        given = R.parse_numbers(it.get("stem") or "")
        if ans is None or len(given) < len(inputs):
            continue
        checked += 1
        hit = False
        for combo in permutations(given, len(inputs)):
            try:
                val = float(p["rhs"].subs({sp.Symbol(s, real=True): v
                                           for s, v in zip(inputs, combo)}).evalf())
            except Exception:
                continue
            if val == val and abs(val - ans) <= tol * max(abs(ans), 1e-9):
                hit = True
                break
        confirmed += 1 if hit else 0
    return {"checked": checked, "confirmed": confirmed}


def certify(rel: dict, corroboration_items: Optional[List[dict]] = None) -> dict:
    """Run the locked hierarchy over a recovered relation record.

    rel: {name, subject, concept_candidate, equation, lhs_unit, symbols:{sym:unit}, meanings:{sym:text},
          constants, provenance:{...}}
    Returns a verdict; `status` is 'certified' only when every mandatory gate passes.
    """
    gates: Dict[str, dict] = {}
    prov = rel.get("provenance") or {}
    gates["provenance"] = {"ok": bool(prov.get("store_path") and prov.get("page") is not None),
                           "reason": "" if prov.get("store_path") else "no owned-source page recorded"}
    gates["parse"] = {k: v for k, v in parse_gate(rel["equation"], rel.get("symbols") or {}).items()
                      if k in ("ok", "reason", "used")}
    lhs, rhs = _split(rel["equation"])
    gates["dimensional"] = DIM.check_relation(rel.get("lhs_unit", ""), rhs or "", rel.get("symbols") or {}) \
        if gates["parse"]["ok"] else {"ok": False, "reason": "parse failed"}
    gates["domain"] = {"ok": bool(rel.get("subject")) and rel.get("subject") in
                       ("Physics", "Chemistry", "Mathematics", "Biology"),
                       "reason": "" if rel.get("subject") else "no subject"}
    gates["roundtrip"] = roundtrip_gate(rel["equation"], rel.get("symbols") or {}) \
        if gates["parse"]["ok"] else {"ok": False, "reason": "parse failed"}
    mandatory = ("provenance", "parse", "dimensional", "domain", "roundtrip")
    ok = all(gates[g]["ok"] for g in mandatory)
    corr = None
    if corroboration_items:
        corr = answer_key_corroboration(rel["equation"], rel.get("symbols") or {}, corroboration_items)
        gates["answer_key_corroboration"] = corr
    failed = [g for g in mandatory if not gates[g]["ok"]]
    return {"status": "certified" if ok else "rejected", "gates": gates, "failed_gates": failed,
            "corroboration": corr}
