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
