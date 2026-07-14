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
from kie.qie.chem_data import COMPOUNDS, REACTIONS, SOLUTES
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
    comp = COMPOUNDS[_si(seed + "c", 0, len(COMPOUNDS) - 1)]; k = _si(seed + "k", 1, 5)
    mass = k * comp.molar_mass                                            # so n = k is exact
    return {"mass": float(mass), "M": float(comp.molar_mass)}, \
        {"mass": mass, "M": comp.molar_mass, "k": k, "name": comp.name}


_CA = CompositionTemplate(
    "chem_mass_to_molecules", "COMPOSE_CHEM_MASS_TO_MOLECULES", _ca_setup,
    [Step("n", "moles_from_mass", ("mass", "M")), Step("N", "molecules_from_moles", ("n",))],
    "N",
    lambda env, p: close((env["N"] / NA) * p["M"], p["mass"]),           # round-trip: reconstruct the input mass
    lambda env, p: (f"The number of molecules present in {p['mass']:g} g of {p['name']} "
                    f"(molar mass {p['M']:g} g/mol) is (Avogadro's number = 6.022×10²³):"),
    lambda env, p: [2 * env["N"], 0.5 * env["N"], p["mass"] * NA, 3 * env["N"]],
    subject="Chemistry", gen_prefix="GENCH_", fmt=_fmt_sci,
)


# ── template CB: mass of reactant → moles → moles of product → mass of product (mass-conservation check) ─
def _cb_setup(seed):
    rxn = REACTIONS[_si(seed + "r", 0, len(REACTIONS) - 1)]; k = _si(seed + "k", 1, 4)
    mass = k * rxn.Mr                                                     # n_reactant = k exact
    return {"mass": float(mass), "Mr": float(rxn.Mr), "Mp": float(rxn.Mp), "ratio": float(rxn.ratio)}, \
        {"mass": mass, "Mr": rxn.Mr, "Mp": rxn.Mp, "ratio": rxn.ratio, "k": k,
         "eq": rxn.equation, "reactant": rxn.reactant, "product": rxn.product}


_CB = CompositionTemplate(
    "chem_stoichiometry_mass", "COMPOSE_CHEM_STOICHIOMETRY_MASS", _cb_setup,
    [Step("nr", "moles_from_mass", ("mass", "Mr")), Step("np", "stoich_scale", ("nr", "ratio")),
     Step("massp", "mass_from_moles", ("np", "Mp"))],
    "massp",
    lambda env, p: close(((env["massp"] / p["Mp"]) / p["ratio"]) * p["Mr"], p["mass"]),  # reconstruct reactant mass
    lambda env, p: (f"For the reaction {p['eq']} (molar masses: {p['reactant']} = {p['Mr']:g} g/mol, "
                    f"{p['product']} = {p['Mp']:g} g/mol), the mass of {p['product']} obtained from "
                    f"{p['mass']:g} g of {p['reactant']} (in grams) is:"),
    # robust for any ratio (incl. 1): reactant mass, double, off-by-one-product, scaled-reactant, ratio-ignored
    lambda env, p: [float(p["mass"]), 2 * env["massp"], env["massp"] + p["Mp"],
                    p["mass"] * p["ratio"], p["k"] * p["Mp"]],
    subject="Chemistry", gen_prefix="GENCH_",
)


# ── template CC: dilution — make a solution, dilute it, find new molarity (C₁V₁ = C₂V₂ check) ──────────
def _cc_setup(seed):
    solute = SOLUTES[_si(seed + "s", 0, len(SOLUTES) - 1)]
    C1 = _si(seed + "C1", 2, 6); V1 = _si(seed + "V1", 1, 3); V2 = V1 + _si(seed + "V2", 1, 4)
    return {"C1": float(C1), "V1": float(V1), "V2": float(V2)}, {"C1": C1, "V1": V1, "V2": V2, "solute": solute}


_CC = CompositionTemplate(
    "chem_dilution_molarity", "COMPOSE_CHEM_DILUTION_MOLARITY", _cc_setup,
    [Step("n", "moles_from_molarity", ("C1", "V1")), Step("C2", "molarity", ("n", "V2"))],
    "C2",
    lambda env, p: close((env["C2"] * p["V2"]) / p["V1"], p["C1"]),     # C₁V₁ = C₂V₂ ⇒ reconstruct C₁ (round-trip)
    lambda env, p: (f"{p['V1']:g} L of a {p['C1']:g} mol/L {p['solute']} solution is diluted with water to a "
                    f"total volume of {p['V2']:g} L. The molarity of the diluted solution (in mol/L) is:"),
    lambda env, p: [p["C1"] * p["V1"], float(p["C1"]), p["C1"] * p["V2"] / p["V1"], 2 * env["C2"]],
    subject="Chemistry", gen_prefix="GENCH_",
)


# ── deeper/broader operators + templates (Slice 3) ───────────────────────────────────────────────────
_reg("gas_volume_stp", "MOLAR_VOLUME", 1, lambda n: n * 22.4,
     lambda ins, out: close(out / 22.4, ins[0]))                         # n ≟ V/22.4

GAS_RXN = [r for r in REACTIONS if r.product == "carbon dioxide"]        # reactions evolving CO₂ gas


def _cd_setup(seed):
    rxn = GAS_RXN[_si(seed + "r", 0, len(GAS_RXN) - 1)]; k = _si(seed + "k", 1, 4)
    mass = k * rxn.Mr
    return {"mass": float(mass), "Mr": float(rxn.Mr), "ratio": float(rxn.ratio)}, \
        {"mass": mass, "Mr": rxn.Mr, "ratio": rxn.ratio, "k": k, "eq": rxn.equation, "reactant": rxn.reactant}


_CD = CompositionTemplate(
    "chem_gas_stoichiometry_volume", "COMPOSE_CHEM_GAS_STOICH_VOLUME", _cd_setup,
    [Step("nr", "moles_from_mass", ("mass", "Mr")), Step("np", "stoich_scale", ("nr", "ratio")),
     Step("V", "gas_volume_stp", ("np",))],
    "V",
    lambda env, p: close(((env["V"] / 22.4) / p["ratio"]) * p["Mr"], p["mass"]),   # round-trip: reconstruct mass
    lambda env, p: (f"For the reaction {p['eq']}, the volume of CO₂ gas measured at STP (molar volume = "
                    f"22.4 L/mol) produced from {p['mass']:g} g of {p['reactant']} (molar mass {p['Mr']:g} g/mol) "
                    f"is (in litres):"),
    lambda env, p: [p["mass"] * 22.4, env["np"], 2 * env["V"], p["k"] * 22.4],
    subject="Chemistry", gen_prefix="GENCH_",
)


# only realistic aqueous solutes (avoid gases/insolubles as "dissolved solute", an examiner note)
_SOLUBLE = [c for c in COMPOUNDS if c.name in ("glucose", "sodium hydroxide", "sulfuric acid")]


def _ce_setup(seed):
    comp = _SOLUBLE[_si(seed + "c", 0, len(_SOLUBLE) - 1)]
    Cc = _si(seed + "C", 1, 4); V = _si(seed + "V", 1, 3)
    return {"C": float(Cc), "V": float(V), "M": float(comp.molar_mass)}, \
        {"C": Cc, "V": V, "M": comp.molar_mass, "name": comp.name}


_CE = CompositionTemplate(
    "chem_molarity_to_mass", "COMPOSE_CHEM_MOLARITY_TO_MASS", _ce_setup,
    [Step("n", "moles_from_molarity", ("C", "V")), Step("mass", "mass_from_moles", ("n", "M"))],
    "mass",
    lambda env, p: close((env["mass"] / p["M"]) / p["V"], p["C"]),      # round-trip: reconstruct molarity
    lambda env, p: (f"{p['V']:g} L of a {p['C']:g} mol/L solution of {p['name']} (molar mass {p['M']:g} g/mol) "
                    f"contains what mass of dissolved solute (in grams)?"),
    lambda env, p: [p["C"] * p["V"], p["M"], 2 * env["mass"], p["C"] * p["M"]],
    subject="Chemistry", gen_prefix="GENCH_",
)


TEMPLATES: Dict[str, CompositionTemplate] = {t.name: t for t in (_CA, _CB, _CC, _CD, _CE)}
register(TEMPLATES)
