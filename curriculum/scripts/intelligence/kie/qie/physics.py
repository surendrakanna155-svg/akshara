"""Physics on the SAME compositional engine — universal-substrate proof (owner-directed 2026-07-14).

Physics adds NOTHING to the engine (`compose.py`) or the composition machinery (`compositions.py`): it only
REGISTERS physics operators into the shared operator registry and physics templates into the shared template
registry. The identical generate/verify/run path serves it.

Independent verification, physics flavour:
  * per-operator: each relation's `verify` recomputes a DIFFERENT quantity from the output (÷ vs ×, sqrt vs
    square) — a genuine consistency check, not "the same formula twice";
  * end-to-end: each template's answer is recomputed via a genuinely INDEPENDENT PHYSICAL PRINCIPLE
    (work–energy theorem, impulse–momentum theorem, P = V²/R) — a different law, not a rearrangement.
Nothing fabricated; deterministic; no AI per item.
"""
from __future__ import annotations

import math
from typing import Dict

from kie.qie import compose as C
from kie.qie.compose import NUMBER, Operator, Step, close
from kie.qie.compositions import CompositionTemplate, _fmt, _si, register


def _reg(name, concept, n_in, apply, verify):
    C.OPERATORS[name] = Operator(name, concept, "physics", (NUMBER,) * n_in, NUMBER, apply, verify)


# ── physics relation operators (each verified by recomputing a DIFFERENT quantity) ────────────────────
_reg("newton_accel", "NEWTON_2ND", 2, lambda F, m: F / m,
     lambda ins, out: close(out * ins[1], ins[0]))                       # F ≟ a·m
_reg("velocity_from_rest", "KINEMATICS_V", 2, lambda a, t: a * t,
     lambda ins, out: ins[1] != 0 and close(out / ins[1], ins[0]))       # a ≟ v/t
_reg("distance_from_rest", "KINEMATICS_S", 2, lambda a, t: 0.5 * a * t * t,
     lambda ins, out: ins[1] != 0 and close(2 * out / (ins[1] * ins[1]), ins[0]))  # a ≟ 2s/t²
_reg("kinetic_energy", "KINETIC_ENERGY", 2, lambda m, v: 0.5 * m * v * v,
     lambda ins, out: ins[0] > 0 and close(math.sqrt(2 * out / ins[0]), abs(ins[1])))  # v ≟ √(2KE/m)
_reg("momentum", "MOMENTUM", 2, lambda m, v: m * v,
     lambda ins, out: ins[1] != 0 and close(out / ins[1], ins[0]))       # m ≟ p/v
_reg("ohms_current", "OHMS_LAW", 2, lambda V, R: V / R,
     lambda ins, out: close(out * ins[1], ins[0]))                       # V ≟ I·R
_reg("power_vi", "POWER", 2, lambda V, I: V * I,
     lambda ins, out: ins[1] != 0 and close(out / ins[1], ins[0]))       # V ≟ P/I


# ── template PA: force → acceleration → velocity → kinetic energy (cross-checked by work–energy theorem) ─
def _pa_setup(seed):
    m = _si(seed + "m", 1, 5); a0 = _si(seed + "a", 2, 6); t = _si(seed + "t", 2, 5)
    F = m * a0                                                            # so a = F/m is exact
    return {"F": float(F), "m": float(m), "t": float(t)}, {"F": F, "m": m, "t": t, "a0": a0}


_PA = CompositionTemplate(
    "phys_force_to_kinetic_energy", "COMPOSE_PHYS_FORCE_TO_KE", _pa_setup,
    [Step("a", "newton_accel", ("F", "m")), Step("v", "velocity_from_rest", ("a", "t")),
     Step("KE", "kinetic_energy", ("m", "v"))],
    "KE",
    lambda env, p: close(p["F"] * (0.5 * (p["F"] / p["m"]) * p["t"] * p["t"]), env["KE"]),  # work–energy theorem
    lambda env, p: (f"A body of mass {p['m']} kg, initially at rest, is acted upon by a constant force of "
                    f"{p['F']} N for {p['t']} s. Its kinetic energy at the end (in joules) is:"),
    lambda env, p: [env["m"] * env["v"], p["F"] * p["t"], 2 * env["KE"], 0.5 * env["v"] * env["v"]],
    subject="Physics", gen_prefix="GENP_",
)


# ── template PB: force → acceleration → velocity → momentum (cross-checked by impulse–momentum theorem) ─
def _pb_setup(seed):
    m = _si(seed + "m", 1, 5); a0 = _si(seed + "a", 2, 6); t = _si(seed + "t", 2, 5)
    F = m * a0
    return {"F": float(F), "m": float(m), "t": float(t)}, {"F": F, "m": m, "t": t, "a0": a0}


_PB = CompositionTemplate(
    "phys_force_to_momentum", "COMPOSE_PHYS_FORCE_TO_MOMENTUM", _pb_setup,
    [Step("a", "newton_accel", ("F", "m")), Step("v", "velocity_from_rest", ("a", "t")),
     Step("p", "momentum", ("m", "v"))],
    "p",
    lambda env, p: close(p["F"] * p["t"], env["p"]),                     # impulse–momentum theorem: p = F·t
    lambda env, p: (f"A body of mass {p['m']} kg starts from rest under a constant force of {p['F']} N applied "
                    f"for {p['t']} s. The magnitude of its momentum at the end (in kg·m/s) is:"),
    lambda env, p: [0.5 * env["m"] * env["v"] * env["v"], float(p["F"]), 2 * env["p"], env["v"]],
    subject="Physics", gen_prefix="GENP_",
)


# ── template PC: voltage & resistance → current → power (cross-checked by P = V²/R) ───────────────────
def _pc_setup(seed):
    R = _si(seed + "R", 2, 6); I0 = _si(seed + "I", 2, 5); V = R * I0
    return {"V": float(V), "R": float(R)}, {"V": V, "R": R, "I0": I0}


_PC = CompositionTemplate(
    "phys_power_from_v_r", "COMPOSE_PHYS_POWER_FROM_V_R", _pc_setup,
    [Step("I", "ohms_current", ("V", "R")), Step("P", "power_vi", ("V", "I"))],
    "P",
    lambda env, p: close(p["V"] * p["V"] / p["R"], env["P"]),           # independent: P = V²/R
    lambda env, p: (f"A resistor of {p['R']} Ω is connected across a {p['V']} V supply. The power dissipated "
                    f"in the resistor (in watts) is:"),
    lambda env, p: [p["V"] * p["R"], env["I"], 2 * env["P"], p["V"] + p["R"]],
    subject="Physics", gen_prefix="GENP_",
)


TEMPLATES: Dict[str, CompositionTemplate] = {t.name: t for t in (_PA, _PB, _PC)}
register(TEMPLATES)
