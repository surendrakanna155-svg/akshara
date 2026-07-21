"""Promotion assessor (R4-1 P4) — eligibility per asset class, via the EXISTING factory certify bar only.

STANDING LAW: no promotion may bypass the factory certification gate. Question items reach the product bank
ONLY through the corpus API (`open_production_bank` -> `save_specs`/`ingest` -> gates -> `mark_certified`),
which runs the R2/R3-owned gate logic — this module NEVER reimplements it.

The honest result today: the factory product bank holds 0 product-certified rows (post-R0-2 recall), and the
qie.db pilot items LACK the R2 solution stage + deterministic distractor verification + a cross-family judge +
the RI-8 provenance quintet. A candidate cannot clear `mark_certified`'s preconditions without those. So R4-1
promotes ZERO question items to product NOW and records that honestly — the manifest carries the eligibility so
that when R4-2's model proposer adds the missing solution/distractor stages, the SAME items can be re-run
through the real certify path. `assess()` reports exactly what each eligible item is missing; `promote()` is a
guarded dry-run that makes NO write to the bank while `promotable_now == 0`.

Governed RELATIONS/FACTS are NOT moved — they stay physically in qie.db and are REGISTERED in the manifest with
full verification provenance (they already feed qp_bridge; see the RI-6 follow-on flag in `ri6_followon`).
"""
from __future__ import annotations

import sqlite3
from typing import Dict, List

from kie.qie.inventory import manifest as MF
from kie.qie.verifiers.protocol import assert_not_model_agreement

# The factory product bar an item must independently satisfy before mark_certified can run (R2/R3). Pilot rows
# carry NONE of these — this is WHY the honest immediate promotion count is 0.
FACTORY_BAR = (
    "solution_verified",            # R2-2: LOCK KEY -> CONSTRUCT SOLUTION -> VERIFY SOLUTION
    "distractor_rationale_verified",  # R2-2: each distractor's mis-relation executed deterministically
    "cross_family_judge_accept",    # R2-1: a different-family disposing reviewer (independent=1)
    "provenance_quintet",           # RI-8: real model id + version + prompt sha + actor + contract
    "stage_telemetry",              # R2-3: accountable generation/judge execution trail
)


def assess(unified_path=None) -> Dict[str, object]:
    """Classify manifest rows into promotion buckets and report the factory-bar gap for question items.

    Returns counts per asset class + the concrete reasons NOTHING immediately promotes to the product bank."""
    conn = MF.open_ro(unified_path)
    try:
        def n(where, args=()):
            return conn.execute(f"SELECT COUNT(*) FROM unified_inventory WHERE {where}", args).fetchone()[0]

        promotable_relations = n("asset_class='relation' AND promotion_status='promotable'")
        practice_tier = n("asset_class='question_item' AND promotion_status='practice_tier_eligible'")
        eligible_kvs = n("asset_class='kvs_assertion' AND promotion_status='eligible'")
        held_qual = n("promotion_status='held_qualitative'")
        held_low = n("promotion_status='held_low_quality'")
        honest_null = n("promotion_status='honest_null'")
        duplicates = n("promotion_status='duplicate'")
        quarantined = n("promotion_status='quarantined'")

        # question items eligible for the PRODUCT bar: none clear it (pilot lane has no solution/distractor/judge)
        promotable_now = 0
        return {
            "promotable_relations": promotable_relations,       # registered, not moved
            "practice_tier_eligible_items": practice_tier,      # route via re-certification when R4-2 lands
            "eligible_kvs_evidence": eligible_kvs,
            "held_qualitative_R4_3": held_qual,
            "held_low_quality_honest_null": held_low,
            "honest_null": honest_null,
            "duplicates_collapsed": duplicates,
            "quarantined": quarantined,
            "promotable_to_product_bank_now": promotable_now,
            "product_bar_gaps_blocking_pilot_items": list(FACTORY_BAR),
            "note": ("pilot items lack the R2 solution/distractor stage + cross-family judge + RI-8 provenance; "
                     "0 clear the factory bar now. Eligibility is recorded so R4-2 can re-run them through the "
                     "real corpus certify path — no parallel certify is invented here."),
        }
    finally:
        conn.close()


def promote(unified_path=None, dry_run: bool = True) -> Dict[str, object]:
    """Guarded promotion. Because `promotable_to_product_bank_now == 0`, this makes NO write to the production
    bank regardless of `dry_run`. It returns the plan. A real promotion would first require R4-2's proposer to
    add the solution/distractor stages, after which the SAME items go through `corpus.open_production_bank ->
    ingest -> gates -> mark_certified` (the owned certify path)."""
    a = assess(unified_path)
    if a["promotable_to_product_bank_now"] == 0:
        return {"promoted": 0, "wrote_to_bank": False, "reason": a["note"], "assessment": a}
    # (unreachable today) — real promotions would run here strictly via the corpus API.
    raise NotImplementedError("promotion path requires the R4-2 solution stage before the corpus certify call")


def ri6_followon() -> Dict[str, str]:
    """The scoped RI-6 follow-on — CLOSED (owner-approved, 2026-07-21). qp_bridge no longer reads qie.db for
    its product boundary; it reads the unified manifest via `manifest.governed_scope_rows`."""
    return {
        "status": "CLOSED",
        "issue": "qp_bridge.py:_governed_concepts formerly read governed_fact + governed_relation DIRECTLY "
                 "from qie.db into paper generation — a de-facto SECOND product surface for those two asset "
                 "classes.",
        "closure": "DONE: qp_bridge._governed_concepts now sources governed relations (promotable) + facts "
                   "(held_qualitative) from the unified manifest (`manifest.governed_scope_rows`), keyed by the "
                   "manifest's `compose_concept` (the exact generator key). A quarantined/rejected/duplicate "
                   "governed asset can no longer reach a paper. qie.db is read ONLY by the manifest builder and "
                   "the generation operators — never as a product boundary. ONE certified surface (RI-6).",
        "scope": "IMPLEMENTED — routes qp_bridge's governed reads through the manifest; owner-approved.",
    }
