# QIE/QDI Remediation — Certification History

Immutable, append-only record of the remediation certification **checkpoints**. Each checkpoint marks a
phase whose items were implemented, independently adversarially verified, tested, EOS-gated, and committed.
Plan = [`QIE_REMEDIATION_ROADMAP.md`](QIE_REMEDIATION_ROADMAP.md); live ledger =
[`QIE_REMEDIATION_EXECUTION_LOG.md`](QIE_REMEDIATION_EXECUTION_LOG.md). Source audit =
`INDEPENDENT_CERTIFICATION_AUDIT_2026-07-21.md` (permanently closed).

**Standing method (every checkpoint):** deterministic checks certify (never model agreement); each item runs
Design → Implementation → **independent adversarial verification** → Tests → EOS gate → Documentation →
Commit; freeze-as-versioning (never mutate a frozen version); honest-null discipline; no gate weakened for
yield. Verifiers that returned REFUTED had their holes fixed + regression-locked before the checkpoint.

---

## Checkpoint — Phase R1 (Certification integrity) · 2026-07-21 · `EOS: CONDITIONAL PASS`

Closes the four P0s (C0 gates verify self-consistency not truth; C1 replay bypass / mutable records; C2 QDI
false provenance; C3 unpinned evidence / substrate re-chunk) and the freeze P0 (C6).

- **R1-1** blocking relation grounding (sympy solve-for equivalence; owner-only waiver) + stem↔structure gate;
  dimensional "not checkable" ⇒ quarantine. Hole found by the adversarial verifier (qualitative-lane bypass)
  fixed: truth gates key on structure presence, not `spec.lane`. — `f6db2803`
- **R1-2** collision-free candidate id; append-only, content-bound, immutable certification records; guarded
  transitions. — `f6db2803`
- **R1-3** QDI provenance invariant (recalls all 7 patterns); fail-closed floor; RCA correction. — `99679f2a`
- **R1-4** content-addressed evidence + substrate fingerprint + deterministic evidence gate. — `842c472d`
- **R1-5** mechanical freeze (guard + `mode=ro` + `chmod a-w`) + fingerprint-recompute test. — `842c472d`

**Live outcome:** knowledge index **v1.4 → v1.5** promoted; certified **2023 → 2009** (14 broken-evidence
concepts quarantined; Chemistry −10, Science −4; Math/Physics/Biology untouched). v1.4 preserved as a
snapshot (never mutated). RI-2 = 0 violations; substrate fingerprint recorded. Invariants held: RI-1, RI-2,
RI-4, RI-5, RI-7, RI-10. Full suite green. The R1 certification halt was lifted at this checkpoint.

---

## Checkpoint — Phase R2 (Trust, independence & provenance) · 2026-07-21 · `EOS: CONDITIONAL PASS`

Closes C4 (independence unenforced), C5 (solution stage skipped), C10 (placeholder provenance), plus the
self-refuted-metadata findings.

- **R2-1** independence: judge blind to the key; `independent` COMPUTED from actor families; same-actor ⇒
  provisional + product-invisible; seeded judge controls. — `04265407` `7fca9c20`
- **R2-2** mandatory solution stage + deterministic distractor verification (each `mis_relation` sympy-
  executed to its option). — `04265407` `7fca9c20`
- **R2-4** step replay: depth EARNED by executing the DAG; `depth_agreement` BLOCKING. — `04265407` `7fca9c20`
- **R2-3** real model/actor provenance + full-stage telemetry (factory-4); fail-closed ingest + placeholder
  ban; computed `payload_sha256`; **per-candidate provenance a certify precondition**; append-only ledger;
  ki_run. — `e03b1471`
- **R2-5** honest difficulty labeling (`predicted_uncalibrated`) + advisory method-leak gate. — `e53b1522`

**Adversarial verification (both passes earned their keep):** the cluster verifier returned **REFUTED** and
found 4 real holes (vacuous all-uncertifiable distractors; NULL judge_family certifying; string-typed depth
skipping the block; dropped-all judge controls) — all fixed + regression-locked. The R2-3 verifier returned
**REFUTED** and confirmed the per-candidate-provenance bypass + an amplifier — fixed + locked.

**Live outcome:** question stores migrated factory-2 → factory-3 → **factory-4** (factory_corpus 15 +
qpl_question_bank 22 certified counts preserved; **product_visible ⇒ 0** — the 22 production questions are
recalled-by-construction until re-certified under the R2 gates; R0-2's status flip is belt-and-suspenders).
**RI-3 + RI-8 now complete.** Full suite **868 green**. Also landed at this checkpoint: **R3-3** (CI for the
kie suite + canonical vacuous-green guard + the missing `sympy` dependency).

**Certification bar after R2 — a row reaches product-certified only with (all bound to its current
item_hash):** zero fatal + zero quarantine gates · independent sympy re-derivation 'agree' · a cross-family
judge 'accept' (`independent=1`) · `solution_verified=1` · `distractor_verified=1` · a self-consistent
EARNED reasoning depth · real per-candidate generation + judge provenance (model + version + prompt sha256 +
actor) · run-level generation + judge telemetry · `evidence_class='sympy_rederived'`.

**Deferred-but-enforced (machinery fail-closed now; the ACTORS need an API layer — roadmap R4-2):** a real
cross-family/human judge yielding `independent=1` (today's single-actor path is provisional-only), an Opus
solution-writer, and a generator emitting `mis_relation` per distractor. Re-certifying the 22 + 15 + 14 + 7
quarantined artifacts is downstream of those actors. R2-5 NCERT-template originality + empirical difficulty
calibration are deferred to R5 (need the PYQ/exercise corpus).

---

## Checkpoint — Phase R3 (Store governance & engineering hygiene) · 2026-07-21 · `EOS: CONDITIONAL PASS`

Closes C8 (bank unowned / stale default), C12 (cross-run duplicates), the AR red-team defect
(#red-team-10), and the store/engine-hygiene reviewer findings. Method: 4 file-disjoint parallel lanes +
a sequential hygiene batch; the certification-affecting lanes got independent adversarial verification.

- **R3-1** one authoritative certified bank (RI-6): `factory_meta.role` stamp; `product_inventory` /
  `certified_bank` refuse un-stamped/trial stores fail-closed; trial certs → `trial_certified`;
  forever-candidates → `expired_unjudged`. — `ca568fab`
- **R3-2** bank-level dedup (RI-9): gate-seed from ALL prior certified + certify duplicate-quarantine +
  partial UNIQUE index over product-visible certified; no spec re-parenting. — `ca568fab`
- **R3-3** CI for the kie suite + canonical vacuous-green guard + missing `sympy` dep. — `66938d41`
- **R3-4** shared `store_open.py` (frozen openers untouched); run_planner fail-loud on a missing store;
  concept_codes_all → ids; JSON-validity test; qp_bridge engine cache. — `e7bb9adb`
- **R3-5** concept-identity ingest safety (refuse-and-log; never demote certified) + alias audit. — `dea15b63`
- **R3-6** guarded, audited, dry-run-default run-scoped excision/recall tooling. — `ca568fab`
- **R3-7** latent gate/leak paths: boundary "checked 0" → advisory + derived tokens; `certified_patterns`
  exam-scoped; anchored section regex. — `baed52fc`
- **R3-8** retire the defective assertion-reason path at the reachability layer (qpgen 0 bytes). — `4c229651`

**Adversarial verification:** verify-R3-A returned **CONFIRMED** (RI-6/RI-9/excision hold; live DBs
byte-identical during probing). verify-R3-C returned **REFUTED** — the R3-7 forbidden-token derivation
crying-wolfed on a concept's own name (411 concepts) and the section regex still matched a parenthesised
subject in prose; BOTH fixed + regression-locked before the checkpoint.

**Live outcome:** question stores migrated factory-4 → **factory-5** (bank `role=production_bank`; trial
corpus `role=trial_corpus` with 15 → `trial_certified` + 456 → `expired_unjudged`); `concept_codes_all`
backfilled live (bank 24 rewritten / 0 unresolved; corpus 1000 / 99 honest-null). Full suite **957 green**.
RI-6 + RI-9 hold. FTS5 + `chunks(doc_id,ordinal)` index deferred (would mutate the frozen v1.5 kie.db).

**Remediation now PAUSES at the owner/external gates** (per the roadmap): R4-1 (adopt/mine/retire the hidden
`qie.db` lane — OWNER decision), R4-2 (automated model-execution layer — needs an API layer, external
dependency), R5-3 (ERP promotion — owner-gated), R6 (owner must unfreeze Tier-1). Re-certifying the 22 + 15
+ 14 + 7 quarantined artifacts is downstream of R4-2's actors.

---

## Action — R0-2 quarantine recall EXECUTED (owner-approved) · 2026-07-21

Owner approved R0-2. Ran `quarantine_audited_estate.py --apply`: the **22** audit-flagged factory questions
(qpl_question_bank.db) + **7** mis-provenanced QDI patterns (qdi.db) were flipped `certified → quarantined`
via guarded transitions (per-row `AND status='certified'`, rowcount==1), each writing a `status_audit` row
(reason='audit-2026-07-21', prior state preserved). Both stores now hold **0 certified** in the recalled
scope. This is the explicit recall the audit verdict required — belt-and-suspenders atop the R2/R3
recall-by-construction (they were already product-invisible). RI-5.6 test updated to the post-recall reality
(no mis-provenanced pattern is certified; the recalled patterns still fail the provenance invariant). Full
suite 957 green.

---

## Checkpoint — Phase R4 (partial: R4-1 + R4-2, owner-approved) · 2026-07-21 · `EOS: CONDITIONAL PASS`

Owner approved R4-1 (adopt, not retire), R4-2 (build the execution layer), R0-2 (execute the recall).

- **R0-2 recall EXECUTED** — 22 questions + 7 QDI patterns `certified → quarantined` (see the action entry above). — `da446fe7`
- **R4-1** adopt qie.db as an EVIDENCE source: ported the 7-method verifier battery + the 5-gate relation
  certifier into a reusable `kie/qie/verifiers/` library (model agreement structurally excluded — reject-only);
  built `unified_inventory.db` (4250 assets, deterministic fingerprint) reconciling qie.db + both factory stores
  + the certified index with dedup + KC_ crosswalk + provenance; registered qie.db `role='evidence_source'`,
  `product_visible='0'`. **Promotion is independent-verification-gated:** 41 governed_relations promotable
  (source_proven), 1434 pilot items practice-tier-eligible, 190 held_qualitative (→ R4-3), 77 KVS eligible;
  **promotable-to-product-bank now = 0** (the honest result — pilot items lack the R2 evidence chain). — `5ff82c37`
- **R4-2** the provider-agnostic model execution layer (`kie/qie/execution/`): queue + retry + crash-resume,
  response cache + family-scoped judge cache, deterministic record→replay, R2-3 provenance bundles, telemetry +
  cost accounting + budget cap, OpenAI adapter (stdlib, injectable transport). Wired into run_generation as the
  canonical generation/judge path; proven to drive `certify_run(require_telemetry=True)` end-to-end with a fake
  provider. — `1a729d6d`

**Adversarial verification:** verify-R4-2 returned **REFUTED** — the item_hash judge cache was content-only,
so a same-family (non-independent) verdict could be laundered into a cross-family certification, and cache hits
left no telemetry. Both fixed + regression-locked (cache keyed by (item_hash, family, model); cache_hit
breadcrumb). R4-1 was reviewed (36 tests; model-agreement structurally cannot certify; 0 forced promotions).

**Live outcome:** `unified_inventory.db` built (evidence manifest, NOT a product bank); qie.db registered
evidence-only; recall applied. Full suite **1022 green**. **RI-6 preserved** (qpl_question_bank remains the sole
product bank; qie.db can never satisfy a product read).

**Open follow-ons surfaced (not owner-gated blocks, but flagged):**
- **qp_bridge RI-6 re-point** — qp_bridge reads governed_fact/relation directly from qie.db (a de-facto 2nd
  product surface); route it through the unified manifest. Tracked by `promote.ri6_followon()`.
- **R4-2 live tail (external):** set `OPENAI_API_KEY`; keep the PRICE_TABLE current. No live model call made yet.
- **Re-certification** of the recalled/held assets now has its execution layer (R4-2) + verifier library (R4-1);
  it needs a live provider key + the qualitative lane (R4-3).

**Still open in the roadmap:** R4-3 (qualitative certification lane — buildable on the qie.db evidence + KVS
substrate now adopted), R4-4 (deferred audit passes), R5-1/R5-2 (prereq edge table + KC_ namespace convergence —
buildable), R5-3 (ERP promotion — owner-gated), R5-4/R5-6 (need PYQ corpus), R6 (Tier-1 freeze — owner unfreeze).

---

## Checkpoint — RI-6 re-point (qp_bridge governed boundary → unified manifest) · 2026-07-21 · `EOS: PASS`

Closes the `promote.ri6_followon()` flag surfaced at the R4-1 checkpoint: qp_bridge's `_governed_concepts` read
governed_fact + governed_relation DIRECTLY from qie.db into paper generation — a de-facto SECOND product surface.

- **Re-point** — `_governed_concepts` now reads governed relations (`promotable`) + facts (`held_qualitative`)
  from the unified manifest via `manifest.governed_scope_rows`, keyed on a new manifest column `compose_concept`
  that is computed with the SAME key functions the generators use (`topics.concept_key` for facts,
  `"{subject} :: {name}"` for relations), so binding is byte-for-byte identical while the SOURCE is now the one
  verified registry. A quarantined / rejected_source / duplicate governed asset can never define an in-scope
  concept — so it can never reach a paper. qie.db is read only by the manifest builder + the generation
  operators, never as a product boundary. Admitted set **identical** (41 promotable relations + 128
  held_qualitative facts); live manifest rebuilt with counts unchanged.
- **Freshness guard (finding #4)** — `governed_scope_freshness` compares a CONTENT fingerprint over the decisive
  governed_relation/governed_fact fields, not COUNT(*), so a count-preserving in-place mutation (status flip,
  equation edit, topic rename) is detected and surfaced (no stale boundary served silently).

**Adversarial verification:** verify-RI-6 returned **CONFIRMED**. It could not construct a case where a
quarantined/rejected/duplicate governed relation or fact reaches a paper: relations are structurally immune
(`_targets` returns `[]` for every `relnum_` frame → the item is dropped, never re-bound); facts have no
quarantine path and generation is lock-stepped to admission; 0 relation/fact items fall through `_bind`. It
found the count-only freshness gap (#4) — fixed + regression-locked before this checkpoint. Papers still
validate (`boundary_ok`, 0 rejects, NEET Biology reached).

**Live outcome:** RI-6 enforced end-to-end — exactly ONE product surface for governed assets. New
`kie/tests/test_ri6_repoint.py` (9 tests). Full suite **1031 green** (skipped=1). `ri6_followon()` → status
`CLOSED`.

**Standing laws honored:** RI-6 (one product-visible surface) strengthened; deterministic-certifies preserved
(relations re-certified by the notation-recovery battery; facts remain honestly `held_qualitative`,
model-verified, non-deterministic — no model agreement certified anything); no gate weakened for yield (identical
admitted set); freeze untouched (the manifest is a derived local store; frozen index + kie.db never opened RW);
honest-null discipline (freshness returns `None` on absence, warns loudly on drift).

---

## Checkpoint — Phase R4-3 (qualitative certification lane + dimensional-gate yield recovery) · 2026-07-21 · `EOS: PASS`

Closes C16 (qualitative uncertifiable in the factory lane) + BS-2 (the qualitative substrate was unexamined).
Two file-disjoint lanes; the certification-affecting Lane B ran **two** independent adversarial rounds.

- **Lane A — dimensional-gate yield recovery.** `factory/gates.py::normalize_unit` now maps the three
  false-reject unit classes the audit named — angle (rad/deg/sr), percentage (%), count (beats/rev/cycles) —
  to dimensionless `1` (all are genuinely dimensionless in SI, so this is correctness, not a weakened gate).
  Every dimension-WRONG relation still fails. Live: of 87 dimensional-reason quarantined candidates with a
  complete structure, **26 now pass** the dimensional gate; 61 correctly still fail.
- **Lane B — qualitative certification lane.** `verifiers/qualitative.py` + `qualitative_lane.py` supply the
  NON-MODEL re-derivation the factory lane lacked: a qualitative governed fact certifies ONLY on **independent
  ≥2-source KVS corroboration** — a `correct_answer_is` assertion attesting the exact answer from ≥2 source
  docs that EXCLUDE the fact's own source, on a fail-closed subject-consistent concept. Model agreement is
  refused; every ambiguity HOLDS. The manifest records `qualitative_grounding` per fact without touching
  promotion_status (RI-6 scope + pinned counts preserved).

**Adversarial verification — two rounds, both REFUTED, both fixed + regression-locked:**
- Round 1: the independence bar counted the fact's own source doc; matching was concept-blind; the model guard
  was a no-op. Fixed (exclude own doc + ≥2 independent; subject-scope; honest guard).
- Round 2: subject was read from the concept_code prefix, which disagrees with the authoritative `subject_term`
  on 44% of live rows; `subject=None`/no-doc failed OPEN. Fixed **fail-closed** (authoritative `subject_term`
  + concept_code cross-check; HOLD on any missing/ambiguous/disagreeing signal or missing source doc).
  Self-verified against the re-verifier's exact live probes (all now HOLD).

**Live outcome (honest):** dimensional recovery landed (26 recoverable structured items); the qualitative lane
yields **0 certifiable / 128 held** — the TRUE state of the owned substrate: the governed-fact and KVS lanes
largely read the same corpus answer keys, so no genuinely-independent corroboration exists yet. This is a
precise measurement of the independent-evidence gap, not a shortfall of the machinery — lifting it needs
acquired independent evidence (R5-4/R5-6 PYQ corpus) or a cross-family judge (R4-2 + a live key). New
`kie/tests/test_r4_3_qualitative_and_dimensional.py` (16 tests). Full suite **1047 green** (skipped=1).

**Standing laws honored:** deterministic/source-grounded checks certify (never model agreement — the examiner
verdict is structurally excluded); honest-null + fail-closed on every ambiguity ("wrong knowledge is worse than
missing" — 0 certifiable is reported, never inflated); no gate weakened for yield (Lane A recovers only
genuinely-dimensionless items; dimension-wrong still fails); freeze untouched; RI-6 preserved.

---

## Checkpoint — Phase R4-4 (deferred audit passes) · 2026-07-21 · `EOS: PASS`

Closes the audit board's own scope debt (BS-3 downstream surfaces unexamined; BS-5 build process unaudited /
ki_run=0; BS-6 no single-lane whole-system claim). Governance/interface tooling — no certification decision.
New `kie/qie/scope_audit.py`:

- **(a) BS-5** `build_process_audit()` — reads the frozen index read-only and reports honestly: build OUTPUTS
  were audited (per-concept `audit_verdict`) and the freeze certified, but the phase-1-7 build PROCESS has no
  per-run trail (`ki_run`=0). Names the gap + the forward requirement. Freeze-safe.
- **(b) BS-3** `downstream_surface_contracts()` + `assert_surface_read()` — the 4 absent downstream surfaces
  get fail-closed read-contracts (product bank / manifest / frozen-index-ro only; a raw store is never
  sanctioned — the RI-6 mistake cannot recur).
- **(c) BS-6** `reconciled_inventory_guard()` — a whole-system claim must span every source lane in the
  manifest (qie.db + qpl_question_bank.db + factory_corpus.db); a single-lane claim is refused.

**Live outcome:** three "we never looked" gaps now examined + guarded. New `kie/tests/test_r4_4_scope_audit.py`
(12 tests). Full suite **1059 green** (skipped=1).

**Standing laws honored:** freeze untouched (frozen index opened mode=ro); fail-closed guards (unsanctioned
reads + single-lane whole-system claims refused); honest reporting (the ki_run=0 gap is surfaced, not hidden).
