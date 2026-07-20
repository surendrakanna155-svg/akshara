# Question Planning Layer — Certification Package (v1)

**Date:** 2026-07-20 · **Branch:** `feature/qie-question-planning-layer` · **Foundation:** NCERT Knowledge
Foundation **v1.4 (frozen, immutable)** · **Tests:** 746 green · **EOS gate: PASS** (one P1 tracked — see §7).

This certifies the **deterministic Question Planning Layer (QPL)** — the layer that fuses the frozen curriculum
with Exam DNA to emit a deterministic, gate-validated `QuestionBlueprint` for JEE Main, JEE Advanced, and NEET.
Certification rests entirely on **deterministic evidence** (tests + adversarial control suites), never on model
agreement.

---

## 1. What the QPL is (and is not)

**Is:** a pure function `plan_blueprints(exam, N) → [QuestionBlueprint]` over frozen inputs (foundation v1.4 +
Exam DNA v1). Every blueprint is a fully-provenanced instruction to generate ONE candidate question; every field
traces to a certified source. It is the certified contract that feeds candidate generation.

**Is not:** a question generator, and not dependent on any model at run time. It carries honest nulls where
certified design DNA does not yet exist (QDI mining is owner-gated — §7).

---

## 2. Build summary (Phases 0–5)

| Phase | Delivered | Evidence |
|---|---|---|
| 0 Preserve | gitignore anchor; committed `factory/`+`knowledge/`; characterization tests | 696 green |
| 1 Repoint | retired the kie.db planning path; certified-only planner on frozen v1.4; enriched specs | 701 green |
| 2 Exam DNA | curated v1 (`examdna.db`): subject/chapter weightage + difficulty/depth/archetype distributions, honest provenance | 709 green |
| 3 Distributor | deterministic Hamilton allocator (no RNG); bounded difficulty driver model; `QuestionBlueprint`; persistence | 723 green |
| 4 QDI infra | scope-linking + certified-pattern attachment (honest-null); deterministic anti-copying/structural/scope floor | 731 green |
| 5 Certify | end-to-end certification suite; multi-agent adversarial verification + hardening | 746 green |

Commits: `02d7e1d0` (P1) · `56f17482` (P2) · `b26339e5` (P3) · `8e798719` (P4) · this package (P5).

---

## 3. Certification claims — each proven by a deterministic check

1. **Determinism (the core law).** `plan_blueprints(exam, N)` is byte-for-byte reproducible — same (frozen index,
   Exam DNA, exam, N) → identical blueprint set. No RNG, no wall-clock in any selecting field; identity is a
   content hash. Verified same-process, **cross-process**, under varying `PYTHONHASHSEED`, and under 200
   input-permutations. Hardened with total `ORDER BY` tie-breaks so it holds under any DB re-import.
   *Test:* `test_qpl_certification.EndToEndCertification.test_deterministic_for_all_exams`.
2. **Gate soundness.** Every issued blueprint passes `planner.check_plan` (out-of-syllabus, subject/name/class/
   chapter mismatch, archetype×depth incoherence, unsupported composition, junk names all refused). Fail-open
   holes found in adversarial review (unknown composition token, name↔id, blank chapter) are **closed and
   regression-locked**. *Tests:* `GateHardening.*`, `ControlFloorsHold.*`.
3. **Distribution fidelity.** Subject weightage matches Exam DNA (NEET 50/25/25, JEE 33/33/33); difficulty match
   is **exact for JEE Main (20/50/30) and JEE Advanced (5/35/60)**; NEET matches easy/moderate with an **honest,
   reported hard shortfall** (hard-Biology is unreachable in v1 without QDI — never faked; realized hard never
   exceeds target). *Test:* `test_distributions_match_or_report_honest_shortfall`.
4. **Provenance completeness.** Every blueprint carries its foundation + Exam-DNA versions, a driver-derived
   difficulty vector (Decision 1), and a content-hash fingerprint. *Test:*
   `test_every_blueprint_passes_gate_and_has_full_contract`.
5. **Honesty (standing law).** No estimate is labelled a measurement (Exam DNA provenance classes:
   published / evidence_proportional / curated_prior / derived_from_profiles; nothing `status='certified'` in v1);
   no fabricated design DNA (honest nulls with 0 certified patterns); no silent difficulty up-relabel; no
   degenerate duplicates presented as distinct (recycles are dropped + reported). *Tests:*
   `test_no_fabricated_design_dna`, `test_no_degenerate_duplicate_blueprints`, Phase-2 provenance tests.
6. **Frozen foundation is read-only.** The planner opens v1.4 (and Exam DNA) `mode=ro`; it never mutates the
   foundation. *Test:* `test_frozen_foundation_is_read_only`.
7. **Persistence.** Blueprints persist by evolving `generation_spec` in place (Decision 3); the factory pipeline
   reads its columns unchanged (backward compatible); 539 blueprints across 3 exams, all fingerprints distinct.

---

## 4. Adversarial verification (Phase 5, independent agents)

Three independent read-only verifiers attacked the QPL; findings fed deterministic fixes (not model votes):

- **Determinism → SOUND.** Could not break it (cross-process + hash-seed + 200 permutations). Flagged latent
  `ORDER BY` gaps → **fixed** (total tie-breaks; read-only Exam DNA contract enforced).
- **Honesty → HONEST.** No violations across 8 modules + live execution. One wording-precision nit → **fixed**.
- **Gates → sound in practice; 4 issues → all fixed + regression-locked:** composition fail-open (HOLE A),
  name↔id (HOLE B), blank-chapter fail-open (HOLE C), 18 certified concepts falsely refused by the OCR filter,
  a heavy-paraphrase bypass of the anti-copying floor, and degenerate duplicates at high N.

---

## 5. Duplication removed / architecture

- **One planner.** The OLD kie.db planning path (`factory/manifest.py`, `factory/trust.py`) is **deleted**; the
  certified-only `knowledge/` stack is the single planner. Duplicated helpers unified.
- **One difficulty model.** The bounded driver model (Decision 1) is the sole planning difficulty model.
- **One spec shape.** `generation_spec` evolved in place (Decision 3) — no second blueprint schema.
- **Naming.** The per-item `QuestionBlueprint` is deliberately distinct from qpgen's paper-level `Blueprint`.

---

## 6. EOS gate verdict — **PASS**

746 tests green; determinism, honesty, and gate coverage adversarially verified and hardened; all adversarial
control floors hold; provenance complete; frozen foundation untouched; no P0 / Constitution automatic-failure
condition. One **P1 tracked** (§7). The deterministic QPL is **complete and certified**; candidate generation
may begin against these certified blueprints.

---

## 7. Tracked (P1) — does not block the deterministic QPL

- **QDI design-pattern certification (Owner Decision 5, PENDING).** Certifying design patterns is model-audited
  (not sympy-verifiable); mining the owned PYQ corpus (327 sources / 20,216 chunks) spends model budget. The
  deterministic infra is built and controlled; blueprints carry **honest-null** `expected_solving_path` /
  `misconceptions_to_evaluate` until an owner-approved, governed analyst→independent-auditor mining pass runs.
  This enrichment layers on additively and changes nothing already certified here.

## 8. Next in the pipeline (post-certification)

Certified QuestionBlueprints → **Candidate Question Generation** → Independent Solution Verification (sympy) →
Independent Judge & Certification → Certified Question Bank → Papers / DPP / Daily / Adaptive. The QPL is the
certified contract at the head of that chain.
