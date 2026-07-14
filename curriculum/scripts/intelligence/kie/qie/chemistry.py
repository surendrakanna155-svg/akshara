"""Chemistry on the SAME compositional engine — universal-substrate proof (owner-directed 2026-07-14).

Like `physics.py`, this adds nothing to the engine: it registers chemistry (mole-concept / stoichiometry /
dilution) operators and templates into the shared registries; the identical generate/verify/run path serves it.

Independent verification, chemistry flavour:
  * per-operator: each relation's `verify` recomputes a DIFFERENT quantity from the output (÷ vs ×);
  * end-to-end: a genuinely independent ROUND-TRIP — reconstruct an original input from the final answer via
    the inverse chain and confirm it matches (e.g. C₁V₁ = C₂V₂ for dilution; mass conservation for
    stoichiometry). A different computational direction, not a rearrangement of the forward formula.
Nothing fabricated; deterministic; no AI per item.
"""
from __future__ import annotations

from typing import Dict

from kie.qie import compose as C
from kie.qie.compose import NUMBER, Operator, Step, close
from kie.qie.compositions import CompositionTemplate, _fmt, _si, register

NA = 6.022e23


def _reg(name, concept, n_in, apply, verify):
    C.OPERATORS[name] = Operator(name, concept, "chemistry", (NUMBER,) * n_in, NUMBER, apply, verify)


_reg("moles_from_mass", "MOLE_CONCEPT", 2, lambda mass, M: mass / M,
     lambda ins, out: close(out * ins[1], ins[0]))                       # mass ≟ n·M
_reg("mass_from_moles", "MOLE_CONCEPT", 2, lambda n, M: n * M,
     lambda ins, out: ins[1] != 0 and close(out / ins[1], ins[0]))       # n ≟ mass/M
_reg("moles_from_molarity", "MOLARITY", 2, lambda Cc, V: Cc * V,
     lambda ins, out: ins[1] != 0 and close(out / ins[1], ins[0]))       # C ≟ n/V
_reg("molarity", "MOLARITY", 2, lambda n, V: n / V,
     lambda ins, out: close(out * ins[1], ins[0]))                       # n ≟ C·V
_reg("stoich_scale", "STOICHIOMETRY", 2, lambda n, ratio: n * ratio,
     lambda ins, out: ins[1] != 0 and close(out / ins[1], ins[0]))       # n ≟ product/ratio
_reg("molecules_from_moles", "AVOGADRO", 1, lambda n: n * NA,
     lambda ins, out: close(out / NA, ins[0]))                           # n ≟ N/Nₐ


def _fmt_sci(v) -> str:
    """Molecule counts shown as coefficient × 10^23 (chemistry-appropriate scientific notation)."""
    return f"{v / 1e23:.3f}×10^23"


# ── template CA: mass → moles → number of molecules (round-trip verified) ─────────────────────────────
def _ca_setup(seed):
    M = [2, 16, 18, 40, 44, 58][_si(seed + "M", 0, 5)]; k = _si(seed + "k", 1, 5)
    mass = k * M                                                          # so n = k is exact
    return {"mass": float(mass), "M": float(M)}, {"mass": mass, "M": M, "k": k}


_CA = CompositionTemplate(
    "chem_mass_to_molecules", "COMPOSE_CHEM_MASS_TO_MOLECULES", _ca_setup,
    [Step("n", "moles_from_mass", ("mass", "M")), Step("N", "molecules_from_moles", ("n",))],
    "N",
    lambda env, p: close((env["N"] / NA) * p["M"], p["mass"]),           # round-trip: reconstruct the input mass
    lambda env, p: (f"The number of molecules present in {p['mass']} g of a substance of molar mass "
                    f"{p['M']} g/mol is (Avogadro's number = 6.022×10²³):"),
    lambda env, p: [2 * env["N"], 0.5 * env["N"], p["mass"] * NA, 3 * env["N"]],
    subject="Chemistry", gen_prefix="GENCH_", fmt=_fmt_sci,
)


# ── template CB: mass of reactant → moles → moles of product → mass of product (mass-conservation check) ─
def _cb_setup(seed):
    Mr = [16, 18, 28, 40, 44][_si(seed + "Mr", 0, 4)]
    Mp = [18, 32, 44, 56, 64][_si(seed + "Mp", 0, 4)]
    ratio = _si(seed + "ratio", 1, 3); k = _si(seed + "k", 1, 4)
    mass = k * Mr                                                         # n_reactant = k exact
    return {"mass": float(mass), "Mr": float(Mr), "Mp": float(Mp), "ratio": float(ratio)}, \
        {"mass": mass, "Mr": Mr, "Mp": Mp, "ratio": ratio, "k": k}


_CB = CompositionTemplate(
    "chem_stoichiometry_mass", "COMPOSE_CHEM_STOICHIOMETRY_MASS", _cb_setup,
    [Step("nr", "moles_from_mass", ("mass", "Mr")), Step("np", "stoich_scale", ("nr", "ratio")),
     Step("massp", "mass_from_moles", ("np", "Mp"))],
    "massp",
    lambda env, p: close(((env["massp"] / p["Mp"]) / p["ratio"]) * p["Mr"], p["mass"]),  # reconstruct reactant mass
    lambda env, p: (f"In a reaction, 1 mol of reactant A (molar mass {p['Mr']} g/mol) produces {p['ratio']} mol "
                    f"of product B (molar mass {p['Mp']} g/mol). The mass of B obtained from {p['mass']} g of A "
                    f"(in grams) is:"),
    lambda env, p: [p["k"] * p["Mp"], p["mass"] * p["ratio"], 2 * env["massp"], float(p["mass"])],
    subject="Chemistry", gen_prefix="GENCH_",
)


# ── template CC: dilution — make a solution, dilute it, find new molarity (C₁V₁ = C₂V₂ check) ──────────
def _cc_setup(seed):
    C1 = _si(seed + "C1", 2, 6); V1 = _si(seed + "V1", 1, 3); V2 = V1 + _si(seed + "V2", 1, 4)
    return {"C1": float(C1), "V1": float(V1), "V2": float(V2)}, {"C1": C1, "V1": V1, "V2": V2}


_CC = CompositionTemplate(
    "chem_dilution_molarity", "COMPOSE_CHEM_DILUTION_MOLARITY", _cc_setup,
    [Step("n", "moles_from_molarity", ("C1", "V1")), Step("C2", "molarity", ("n", "V2"))],
    "C2",
    lambda env, p: close((env["C2"] * p["V2"]) / p["V1"], p["C1"]),     # C₁V₁ = C₂V₂ ⇒ reconstruct C₁ (round-trip)
    lambda env, p: (f"{p['V1']} L of a {p['C1']} mol/L solution is diluted with water to a total volume of "
                    f"{p['V2']} L. The molarity of the diluted solution (in mol/L) is:"),
    lambda env, p: [p["C1"] * p["V1"], float(p["C1"]), p["C1"] * p["V2"] / p["V1"], 2 * env["C2"]],
    subject="Chemistry", gen_prefix="GENCH_",
)


TEMPLATES: Dict[str, CompositionTemplate] = {t.name: t for t in (_CA, _CB, _CC)}
register(TEMPLATES)
