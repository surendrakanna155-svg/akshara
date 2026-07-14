"""Evidence-grounded qualitative Biology on the SAME compositional engine — Slice 2.

Non-quantitative NEET reasoning (structure-function, process/pathway order, cause-effect chains) generated FROM
and verified AGAINST the curated canonical KB (`bio_data.py`) by deterministic lookup/traversal. Multi-hop
templates chain relations for genuine reasoning depth. Verification hierarchy (locked):
  * Tier-1 deterministic — every operator's `verify` re-checks the canonical KB relation; the pipeline re-run in
    verify_composition re-derives the answer; distractors are other REAL entities proven ≠ the answer.
  * Tier-2 evidence — the KB is corroborated by the 411 Tier-2-verified Biology facts where they overlap.
  * Tier-3 LLM — quality examiner only (ambiguity / single-answer), never the truth source.
The engine (compose.py) is unchanged; Biology only registers operators + templates.
"""
from __future__ import annotations

from typing import Dict, List

from kie.qie import bio_data as BD
from kie.qie import compose as C
from kie.qie.compose import Operator, Step
from kie.qie.compositions import CompositionTemplate, _si, register

STR = "BIO"          # loose string-entity type (arity-checked by the engine; semantics documented here)


def _reg(name, apply, verify, n_in, out=STR):
    C.OPERATORS[name] = Operator(name, "BIO_KB", "biology", (STR,) * n_in, out, apply, verify)


_reg("next_step",
     lambda proc, step: proc[proc.index(step) + 1] if step in proc and proc.index(step) + 1 < len(proc) else None,
     lambda ins, out: ins[1] in ins[0] and ins[0].index(ins[1]) + 1 < len(ins[0])
     and ins[0][ins[0].index(ins[1]) + 1] == out, 2)
_reg("structure_for", lambda fn: BD.FUNC_TO_STRUCT.get(fn),
     lambda ins, out: out is not None and BD.FUNC_TO_STRUCT.get(ins[0]) == out, 1)
_reg("system_of", lambda st: BD.STRUCT_TO_SYSTEM.get(st),
     lambda ins, out: out is not None and BD.STRUCT_TO_SYSTEM.get(ins[0]) == out, 1)
_reg("hormone_of", lambda g: BD.GLAND_TO_HORMONE.get(g),
     lambda ins, out: out is not None and BD.GLAND_TO_HORMONE.get(ins[0]) == out, 1)
_reg("effect_of", lambda h: BD.HORMONE_TO_EFFECT.get(h),
     lambda ins, out: out is not None and BD.HORMONE_TO_EFFECT.get(ins[0]) == out, 1)


# ── BIO-A: next step in a canonical process/pathway (sequence reasoning) ───────────────────────────────
def _seq_setup(seed):
    name, steps = BD.PROCESSES[_si(seed + "p", 0, len(BD.PROCESSES) - 1)]
    i = _si(seed + "i", 0, len(steps) - 2)                       # not the last step
    return {"process": tuple(steps), "step": steps[i]}, {"name": name, "steps": steps, "step": steps[i]}


_BIO_SEQ = CompositionTemplate(
    "bio_process_next_step", "COMPOSE_BIO_PROCESS_NEXT_STEP", _seq_setup,
    [Step("ans", "next_step", ("process", "step"))],
    "ans",
    lambda env, p: p["steps"][p["steps"].index(p["step"]) + 1] == env["ans"],   # deterministic re-derivation
    lambda env, p: (f"In {p['name']}, which of the following immediately follows the "
                    f"'{p['step']}' stage?"),
    lambda env, p: [s for s in p["steps"] if s != p["step"] and s != env["ans"]],
    subject="Biology", gen_prefix="GENBK_", fmt=str,
)


# ── BIO-B: structure → system, via its function (multi-hop, depth 2) ──────────────────────────────────
def _sf_setup(seed):
    st, fn, sy = BD.HUMAN_SF[_si(seed + "s", 0, len(BD.HUMAN_SF) - 1)]      # human organ systems only
    return {"function": fn}, {"structure": st, "function": fn, "system": sy}


_BIO_SF = CompositionTemplate(
    "bio_structure_to_system", "COMPOSE_BIO_STRUCTURE_TO_SYSTEM", _sf_setup,
    [Step("st", "structure_for", ("function",)), Step("ans", "system_of", ("st",))],
    "ans",
    lambda env, p: BD.STRUCT_TO_SYSTEM[BD.FUNC_TO_STRUCT[p["function"]]] == env["ans"],
    lambda env, p: (f"The organ / structure responsible for the {p['function']} is part of which organ system "
                    f"of the human body?"),
    lambda env, p: [sy for sy in BD.HUMAN_SYSTEMS if sy != p["system"]],    # distractors: other human systems
    subject="Biology", gen_prefix="GENBK_", fmt=str,
)


# ── BIO-C: gland → hormone → effect (cause-effect chain, depth 2) ─────────────────────────────────────
def _ghe_setup(seed):
    g, h, e = BD.GLAND_HORMONE_EFFECT[_si(seed + "g", 0, len(BD.GLAND_HORMONE_EFFECT) - 1)]
    return {"gland": g}, {"gland": g, "hormone": h, "effect": e}


_BIO_GHE = CompositionTemplate(
    "bio_gland_hormone_effect", "COMPOSE_BIO_GLAND_HORMONE_EFFECT", _ghe_setup,
    [Step("h", "hormone_of", ("gland",)), Step("ans", "effect_of", ("h",))],
    "ans",
    lambda env, p: BD.HORMONE_TO_EFFECT[BD.GLAND_TO_HORMONE[p["gland"]]] == env["ans"],
    lambda env, p: (f"The principal hormone secreted by the {p['gland']} is chiefly responsible for which of "
                    f"the following?"),
    lambda env, p: [e for g, h, e in BD.GLAND_HORMONE_EFFECT if e != p["effect"]],
    subject="Biology", gen_prefix="GENBK_", fmt=str,
)


TEMPLATES: Dict[str, CompositionTemplate] = {t.name: t for t in (_BIO_SEQ, _BIO_SF, _BIO_GHE)}
register(TEMPLATES)
