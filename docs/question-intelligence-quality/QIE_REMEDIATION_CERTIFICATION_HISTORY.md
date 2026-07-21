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
