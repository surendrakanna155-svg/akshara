# Controlled NEET Biology Generation Pilot — verified results

**Date:** 2026-07-13 · **Status:** DONE. First controlled pilot of certified-model-driven generation with
automatic in-loop independent verification. **62 verified questions** entered the separate **PILOT VERIFIED
QUESTION BANK** (`qie.db.pilot_verified_item`) — **not** merged into any Certified Bank. Both pre-pilot
blockers closed (in-loop verification + plausible distractors). No corpus, no gate-weakening, no Certified-Bank
change. **490 tests green.** Evidence: `phase0_evidence/pilot_bio_neet/`.

> **Record correction (data-store scope).** To be precise about what was written:
> - **`kie.db` (certified baseline): untouched — read-only.** All modules read it read-only.
> - **`qie.db` (local, gitignored, DERIVED store): WAS written — by design.** It now holds the pilot bank
>   (62 `pilot_verified_item` rows) and the Tier-2 verdicts (454 `tier2_verdict` rows). Per the storage lock,
>   derived knowledge lives locally in `qie.db`; **only the schema + code are committed to git** (the
>   `pilot_verified_item` table definition is in `store_schema.sql`, commit 427e0b21). Earlier B-phase reports
>   that say "`qie.db` untouched" were correct *for those phases* because they operated on scratch copies; the
>   Tier-2 pass and this pilot deliberately persist to the real `qie.db`.
> - **Certified Bank: untouched** — the pilot bank is a **separate** table, never merged.
> - `qpgen`: untouched.

## Pipeline (every generated question ran, automatically, in this order)

certified-model selection → build verified evidence → author new stem → **boundary/concept check** →
**answer = verified fact token** → **distractor validity + plausibility check** → **duplicate/near-copy +
tautology check** → **provenance check** → **governed Tier-2 independent verifier** + **adversarial refuter**
→ PASS / REJECT / QUARANTINE. Only PASS items were written to the pilot bank; REJECT and QUARANTINE never
entered it (hard boundary in `persist_pilot_bank`).

## Metrics

| Metric | Value |
|---|---|
| Total attempted | **97** |
| PASS | **62** |
| REJECT | **34** |
| QUARANTINE | **1** |
| Pilot verified-bank count | **62** |
| Raw correctness before verification (single independent pass) | **66.0%** |
| Final answer-agreement of accepted items | **100%** (PASS requires both judges agree) |
| Inter-judge agreement (verifier vs refuter, all items) | **91.8%** |
| Distractor plausibility tiers | **270 family / 15 neighbour / 6 cross** → **92.8% same biological family** |
| Distractor validity | 100% evidence-backed (verified tokens of other concepts); 0 fabricated |
| Duplicate / near-copy count | **0** (2 tautologies pre-gated deterministically) |
| Concept coverage | **16 / 19** certified concepts have ≥1 verified question |
| Certified-model coverage | **84.2%** |
| Stem / archetype diversity | **36 distinct stems**, 2 authored frames (assoc 54 / belongs 43); archetype = `factual_single_best_answer` (the only certified archetype this slice) |
| Top rejection reasons | ANSWER_DISAGREEMENT 34 · TAUTOLOGY (pre-gate) 2 · UNVERIFIABLE (quarantine) 1 |
| Automatic verification failures / operational issues | **none** — all 6 judge passes returned, 0 missing verdicts, 0 parse errors |

## Reading the result

- **The generation path works and is safe.** 62 genuinely-new, boundary-scoped, verified-answer NEET Biology
  factual questions were produced and banked; the 34 REJECTs were caught by the independent judges (wrong
  domain, tautology, or two-options-equally-associated ambiguity) and never shipped. Inter-judge agreement
  91.8% shows the verification is reliable, not a rubber stamp.
- **Why 62 and not 300 — capacity, not gate-weakening.** 300 was the *aspiration* "subject to available
  certified-model capacity". The honest capacity of ONE archetype (`factual_single_best_answer`) × NEET
  Biology is **97 attempts** (one per exclusive verified fact across 19 certified concepts). Gates were **not
  weakened** to chase 300. Reaching 300+ requires the stated **expansion** — more certified archetypes
  (cause_effect / classification / assertion), more verified facts (further Tier-2 depth), and the other
  profiles (NEET Physics/Chemistry, JEE Physics/Chemistry/Mathematics) — never a lower bar.
- **Blocker-2 trade-off, measured honestly.** Plausible same-family distractors (92.8%) make questions
  harder — and occasionally a family distractor is *genuinely* associated too, producing an ambiguity the
  judges reject. That is correct behaviour: it lowers the raw pass rate but keeps only unambiguous items.

## Next (owner-gated — not started)

Expand the same certified→generation→verify path to NEET Physics/Chemistry and JEE
Physics/Chemistry/Mathematics, closing only measured blockers, and broaden Biology beyond the factual
archetype. Then scale controlled batches toward the large verified Question Bank. The pilot bank stays
separate until owner approval to promote.

**STOP for owner review.**
