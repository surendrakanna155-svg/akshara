# Program C — Re-certification Runner: Replay Certification Report

**Date:** 2026-07-22 · **Branch:** `feature/program-c-live-recertification` · **Status:** 🟢 **REPLAY-CERTIFIED
— OWNER-ACCEPTED (Option 3) — PAUSED (engineering-complete).** No live OpenAI/OpenRouter request has been
made; no spend has occurred.

> ## ✅ OWNER DECISION (2026-07-22) — Option 3 accepted
> The owner **accepts the replay findings** and selects **Option 3**:
> - The **22 recalled factory questions shall remain permanently quarantined.** They are correctly rejected by the
>   current deterministic gates; there is **no live run** against this cohort (it deterministically fails before
>   the judge — $0, 0 requests, 0 certifications).
> - **No certification gate may be weakened or bypassed to exercise a live API call.** Ever.
> - **Program C replay certification is accepted as successful.**
> - **Recorded as evidence:** the hardened certification pipeline (post-R1/R2) **correctly rejects content that was
>   previously admitted under historical bypasses.** The recalled 22 passing the *old* bypassable guards and
>   failing the *current* gates is positive proof the remediation closed the hole — not a defect in Program C.
> - **Program C is paused and considered engineering-complete + replay-certified.** The first live execution will be
>   scheduled later against a **newly approved gate-passing cohort**, under explicit owner approval.

This report certifies the Program C held-estate **re-certification runner** against Fake/Replay providers only,
per the owner's autonomous directive (Phases 1–4). It records an **important honest finding** about the recalled
cohort that reshapes the first live run.

---

## 1. What was built (Phase 1 — additive)

`kie/qie/execution/recert.py` — the append-only re-certification runner. It NEVER mutates the recalled originals
or the product bank; it re-mines their content **verbatim** into a fresh run in a caller-supplied store and drives
the real certification chain:

```
deterministic re-mine → gates + sympy (independent answer) → solution stage (model)
    → deterministic solution + distractor verification → cross-family JUDGE (model) → certify
```

**Provenance / independence model (documented; an integrity choice — confirm before live):**
- **Generation = a deterministic re-mine** of the recalled content (no model, no drift, exact content preserved).
  Generator actor family is `recalled-factory` (the honest origin — the originals' own `generator-agent` family is
  a BANNED placeholder), with a per-row provenance link to the source recalled `candidate_id`.
- **Solution = a model** (OpenAI live) authors steps + distractor `mis_relation`s, which a **deterministic sympy
  gate** then proves — the model proposes, the gate certifies.
- **Judge = a genuinely different family** (Anthropic-via-OpenRouter, family `anthropic`). `cross_family` holds
  because `anthropic` ≠ `recalled-factory` (and ≠ the solution author) — the judge is independent of both the
  content origin and the solution author.

Every model stage is driven by an injected `ModelExecutor`, so the whole runner runs on Fake/Replay providers
with no network and no key. Live providers slot into the identical seam.

---

## 2. Phase 2 — Replay validation (Fake/Replay only)

`kie/tests/test_program_c_recert.py` (10 tests) + the full Program C suite (34 tests) — **all green**; full kie
suite **1272 passed, 0 failed, 0 errors, 1 skipped**.

| Check | Result |
|---|---|
| Full chain certifies (seeded gates + real sympy solution/distractor verify + cross-family judge + certify) | ✅ 2/2 certified, product-visible |
| Cross-family enforcement (same-family judge) | ✅ 0 certified, 2 provisional (product-invisible) |
| Deterministic replay (run1 == run2) | ✅ identical dispositions |
| Loads the real recalled 22 read-only | ✅ 22 loaded, all STRUCTURED_NUMERIC |

---

## 3. Phase 3 — Red-team (all green)

| Adversarial case | Enforced behavior |
|---|---|
| **Budget** cap $0.00 on the judge | `BudgetExceeded` fail-closed; no judge telemetry → certify **refuses** (RI-8), 0 certified |
| **Judge-control breach** (judge accepts planted known-bad items) | `JudgeControlBreach` — the whole pass aborts; a judge that can't fail a known-bad item can't certify a good one |
| **Cross-family** (judge family == generator family) | provisional only, never product-visible |
| **Unprovable distractor** (`mis_relation` doesn't compute the option) | quarantined at `SOL.ingest` (distractor_verification_failed); never certified |
| **Transient error** on the judge call | retried with backoff (queue), then succeeds — 2/2 certified |
| **Append-only immutability** (re-ingest same run) | `CorpusIntegrityError` — no silent overwrite (the audit's replay bypass) |
| **Rate governor** (5 req/min) + **soft alert** ($0.10) | enforced (`test_program_c_provisioning.py`), advisory alert never blocks |
| **Source not mutated** | the recalled originals / cohort object are never written |

---

## 4. ★ Critical honest finding — the recalled 22 do NOT survive the current gates

A deterministic replay dry-run of the runner over the **real 22 recalled factory questions** (Fake providers, no
spend) shows **0 of 22 survive the current deterministic gate battery**. They quarantine **before** the judge:

```
survived_gates: 0 / 22
gate fails: archetype_agreement 22 · relation_grounded 22 · depth_agreement 22 ·
            curriculum_boundary 17 · dimensional 13 · concept_title_clean 6 · method_leak 4 · …
independent (sympy): agree 22   ← sympy re-derives the answer, but the GATES reject the items
```

This is **fail-closed working exactly as designed.** The R0-2 audit recalled these items precisely because they
were promoted by **bypassable guards**; under the honest, post-remediation R1/R2 gates they do not pass. sympy
agreeing on the arithmetic does not rescue an item that fails `relation_grounded` / `archetype_agreement` /
`curriculum_boundary`.

**Consequence for the first live run:** a cross-family judge pass over the recalled 22 would judge **zero items**
(they are all quarantined at the gate stage first) → **0 live API requests, $0.00 spend, 0 certifications.** The
live judge is never reached for this cohort.

---

## 5. Controlled execution plan & GO/NO-GO

**Owner decision required before any live run (this is a real decision, not a default):** the approved first
cohort — the 22 recalled factory questions — **cannot exercise the live judge**, because it is rejected by the
deterministic gates first. Options:

1. **Run it live anyway** to confirm end-to-end wiring: result is deterministic — **0 judge requests, $0.00**, all
   22 quarantined at gates. Proves the pipeline but spends nothing and certifies nothing.
2. **Choose a cohort that passes the current gates** to actually exercise the live cross-family judge (e.g., the
   15 `certified` rows still in `factory_corpus.db`, or freshly-generated STRUCTURED_NUMERIC candidates). This is
   a scope change from the approved cohort and needs owner approval.
3. **Accept the finding** that the recalled 22 are correctly un-certifiable under the honest gates and keep them
   quarantined — no live run needed for this cohort.

**Estimated cost of the approved (option 1) first live run:** **$0.00** (0 judge requests — all items quarantine at
the deterministic gates before the judge). Hard cap $0.25 / soft $0.10 remain in force regardless.

**GO/NO-GO:** 🟢 **GO for replay certification (this report).** 🟡 **NO-GO for a value-producing live run on the
approved cohort** until the owner resolves §5 — running the recalled 22 live is safe but spends $0 and certifies 0.

**No live OpenAI/OpenRouter call has been made. Awaiting explicit owner approval.**
