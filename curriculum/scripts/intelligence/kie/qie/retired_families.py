"""QIE-side reachability retirement — question families a sanctioned caller must NEVER assemble.

Standing law (QIE remediation **R3-8** / red team 2026-07-11, `#red-team-10`): *a known-defective
question family must be UNREACHABLE, not merely dormant.*

The confirmed defect: the frozen qpgen engine hard-codes the assertion-reason (AR) answer to
`_AR_OPTS[0]` — `kie/qpgen/templates.py::_ar_family.build` returns
`{"answer": _AR_OPTS[0], ...}` for EVERY AR item, so the key is option (a) regardless of whether
the assertion/reason are actually true or whether the reason explains the assertion. It is dormant
in the `qp_bridge` path (the bridge sources items from the qie lane and only serves MCQ/NUMERICAL)
but ALIVE for any direct engine/template caller.

`kie/qpgen/` is a FROZEN engine (reuse-not-edit), so the defect is retired HERE, at the QIE
reachability layer that the sanctioned caller (`kie.qie.qp_bridge`) consults — NEVER by editing the
engine's AR logic. Any QIE-side caller that assembles from the shared registries MUST honor this
denylist. Retirement is at the reachability layer; it is not a claim that assertion-reason is an
inherently invalid form — the family stays quarantined until the frozen engine is re-versioned with
a computed key.
"""
from __future__ import annotations

from kie.qpgen.models import QuestionType

# ── retired qpgen template families (kie/qpgen/templates.py `_ar_family(...)`) ────────────────────
# Enumerated explicitly so the R3-8 regression test can assert this denylist covers EVERY AR family
# the frozen engine still registers — a new AR family added upstream would fail that test loudly
# (fail-closed: an un-retired defective family is a test failure, not a silent leak).
RETIRED_QPGEN_FAMILIES = frozenset({
    "ar_newton_first",
    "ar_ohm",
    "ar_momentum_conservation",
    "ar_archimedes",
})

# ── retired question TYPE ─────────────────────────────────────────────────────────────────────────
# No AR item may be assembled by a sanctioned caller while the frozen builder hard-codes the key.
RETIRED_QUESTION_TYPES = frozenset({QuestionType.ASSERTION_REASON})

# ── retired archetype label (kie.qie.archetypes vocabulary) mapping to the same defective form ─────
RETIRED_ARCHETYPES = frozenset({"assertion_reason"})


def is_retired_question_type(qtype) -> bool:
    """True when a blueprint cell's question type is retired and must never be filled/assembled."""
    return qtype in RETIRED_QUESTION_TYPES


def has_computed_key(item: dict) -> bool:
    """Does this item carry POSITIVE EVIDENCE that its key was computed rather than hard-coded?

    This is the condition R3-8 itself named for lifting the assertion-reason retirement:

        "the family stays quarantined until the frozen engine is re-versioned with a computed key …
         it is not a claim that assertion-reason is an inherently invalid form"

    The evidence required is deliberately specific, so the exemption cannot be claimed by relabelling.
    An item qualifies only if it carries BOTH:

      * a `truth_table` recording the three facts the option set turns on — truth(A), truth(R) and
        whether R explains A; and
      * a `key_derivation` note stating the key was derived from them.

    `kie.qie.certgen.assertion_reason` produces both, and re-derives the truth table with sympy on every
    build; the frozen `kie/qpgen/templates.py::_ar_family.build` produces neither and never can, because
    it returns `_AR_OPTS[0]` without inspecting the statements at all. So the frozen family stays
    unreachable, which is the whole point of the retirement.
    """
    prov = item.get("provenance") or {}
    tt = prov.get("truth_table")
    return bool(prov.get("key_derivation")) and isinstance(tt, dict) and {
        "assertion_true", "reason_true", "reason_explains"} <= set(tt)


def is_retired_item(item: dict) -> bool:
    """True when a candidate item belongs to a retired (known-defective) family/archetype and must be
    dropped from a sanctioned caller's REACHABLE pool before selection.

    Checks every place a retirement marker can surface on a normalized qie item: the frame/template
    id and the archetype label (top-level or under provenance). Belt-and-suspenders so a future qie
    composition/generator that ever emitted a retired form could not enter the reachable set.

    The ONE exemption is the one R3-8 wrote into its own terms (see `has_computed_key`): an item whose
    key demonstrably follows from a computed truth table is not the defect this list exists to contain.
    A retired FAMILY id is never exempt — the frozen builders stay banned no matter what an item claims.
    """
    frame = item.get("frame_id") or ""
    prov = item.get("provenance") or {}
    template = prov.get("template") or ""
    archetype = item.get("archetype") or prov.get("archetype") or ""
    if frame in RETIRED_QPGEN_FAMILIES or template in RETIRED_QPGEN_FAMILIES:
        return True                       # a frozen defective builder — no exemption, ever
    if archetype in RETIRED_ARCHETYPES:
        return not has_computed_key(item)
    return False
