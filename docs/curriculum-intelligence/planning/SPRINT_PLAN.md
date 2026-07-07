# Curriculum Intelligence — Sprint Plan

**Date:** 2026-07-06 · **Status:** ⏸ awaiting owner approval; sprints do not start until D-1..D-4 resolve.

> **⚠ RE-TIMED 2026-07-07** ([`../INTEGRATION_AND_READINESS_REVIEW.md`](../INTEGRATION_AND_READINESS_REVIEW.md) §4, Option A): the **data sprints (S0–S8 data halves) run as planned** in parallel with the master roadmap; the **code halves of S1–S9 re-time** — only P1-CI-0 (golden pinning + `edu_exam_paper_links` + dormant E1a seed, ~2–4d) runs before the P4 Red Team; the substantive code waves (CI-C1/C3/C4/C5/C6/C7/C9, E1b) execute post-pilot as the v3.0 Phase-1 implementation plan, keeping the sprint pairings below as their internal order. Effort totals unchanged.
**Sprint convention:** this project executes in EOS-gated *waves*, not calendar scrum; a "sprint" below = one focused execution block ≈ 1–2 weeks of single-owner effort. Estimates are dev-days (d), deliberately conservative ranges. Data-lane and code-lane sprints may run concurrently (one each).

---

## Sprint S0 — Decisions & Scaffolding *(gate: owner)*
- Owner resolves **D-1..D-4** (batched).
- **CI-A0** (1–2d): curriculum workspace, configs, PM files, scripts skeleton, `.gitignore` guard, dry-run cycle.
- Code-lane pre-work (2d): hand-transcribe CBSE Class-10 Science + Math SQP structures (CI-B3 seed).

## Sprint S1 — CBSE acquisition ∥ solver flagship
- **Data:** CI-A1 part 1 (6d): CBSE/NCERT discovery + Priority-A downloads classes 6–10, metadata as-you-go.
- **Code:** CI-C1 part 1 (4–5d): golden-test pinning of solver behaviour; `edu_blueprint_templates` migration + repository/handler CRUD (platform + school-custom rows).

## Sprint S2 — CBSE close ∥ solver upgrade
- **Data:** CI-A1 part 2 (4–6d): verification, indexes, coverage report, gap documentation → CBSE exit gate.
- **Code:** CI-C1 part 2 (6–8d): template-aware solver (slot groups, internal choice, weightage/quota hard constraints, pagination); template-absent legacy path proven; live-cert extension; **EOS gate**.

## Sprint S3 — AP SCERT ∥ multi-set & PDF v2
- **Data:** CI-A2 (6–10d): AP SCERT full cycle (D-4 order); CI-B1/B3 CBSE increments (3d) pipelined.
- **Code:** CI-C3 (5–7d): multi-set A/B/C + per-set keys; PDF v2 (sections/instructions/branding via XCT-1 pipeline); JSON export; **EOS gate**.

## Sprint S4 — Telangana SCERT ∥ catalogue expansion
- **Data:** CI-A3 (6–10d); CI-B1/B2 AP increments.
- **Code:** CI-C2 (4–6d): `subject_templates` expansion migration (CBSE+AP classes 6–10 from CI-B1) + versioning columns + wizard/boundary regression; **EOS gate**.

## Sprint S5 — CISCE ∥ AI Validation Engine
- **Data:** CI-A4 (5–8d); CI-B1/B2 TS increments.
- **Code:** CI-C5 (5–7d): blind-solve verification, metadata sanity, quality/confidence scoring, revision versioning, eval-harness v0 — implements **AI_VALIDATED** (D-6); **EOS gate**. *(Swapped before ingestion per D-6.)*

## Sprint S6 — Priority-B & foundation corpus ∥ cold-start ingestion
- **Data:** CI-A5 (4–6d): Priority-B + official/open foundation resources (JEE/NEET/NTSE/Olympiad).
- **Code:** CI-C6 (6–8d): school past-paper ingestion (OCR-first, D3) through the full D-6 lifecycle `RAW → EXTRACTED → AI_VALIDATED → TEACHER_VALIDATED → CERTIFIED`; moderation-queue UI completion; certified-candidate→bank merge; **EOS gate**.

## Sprint S7 — Repository Certification ∥ profiles & gating
- **Data:** CI-A6 (3–4d): dedup, quality score, license report, **Repository Certification (D-5)** — audit PASS → `CURRICULUM_REPOSITORY_CERTIFICATION.md` + certified flag; CI-B1/B2 CISCE increments.
- **Code:** CI-C7 (5–7d): Exam Profile Engine (config entity, weighting, compatibility validation) + capability gating on `plan_entitlements`; **EOS gate**.

## Sprint S8 — Knowledge close ∥ links & tagging
- **Data:** CI-B4 (4–6d): PYQ/pattern store, knowledge objects, canonical-concept seed proposal (owner review).
- **Code:** CI-C8 (2–3d): `edu_exam_paper_links`, exposure/rotation, selection-reason logging; then CI-C4 (4–5d): outcome/competency schema + tagging assist; **EOS gates**.

## Sprint S9 — Sync & handoff
- **Code:** CI-C9 (3–4d): continuous-sync v1 + impact report; **CI-E1** (2–3d): dormant Phase-2 schema seed; **EOS gates**.
- Program close (baseline scope): final coverage/quality reports, `MILESTONE_TRACKER` close-out, handoff note to v3.0 Phase 2.

## Sprint S10 — Asset factories *(Amendment A1; owner-timed at the v3.0 Phase-1→2 boundary — A1-O1)*
- **Code:** CI-C10 (6–8d): Item Models + Question Families + Distractor Library + offline batch generation through `GENERATED → AI_VALIDATED → TEACHER_VALIDATED → CERTIFIED`; **EOS gate**.
- **Code:** CI-C11 (6–8d): diagram spec → programmatic SVG generation → Certified Diagram Library; PDF v2 embed; **EOS gate**.
- Scoped red-team playbook re-run over both new AI surfaces (per integration review §5 rule).

---

## Totals (single data owner + single code owner, concurrent)

| Lane | Effort | Elapsed (concurrent) |
|---|---|---|
| Data lane | ~39–61 dev-days | S0–S8 |
| Code lane (baseline) | ~33–45 dev-days | S1–S9 |
| Code lane (A1 factories) | ~12–16 dev-days | S10 (post-E1b window) |
| **Program** | ~84–122 dev-days | ≈ 10–13 execution blocks (data lane is still the long pole to G2 — see [`CRITICAL_PATH_ANALYSIS.md`](CRITICAL_PATH_ANALYSIS.md); S10 runs beyond G2) |

**Standing rules:** every code sprint ends in exactly one EOS-gated commit; a sprint that misses its exit gate does not roll scope forward silently — it re-plans; data sprints checkpoint daily (spec Part 02 resume discipline) so interruption costs nothing.
