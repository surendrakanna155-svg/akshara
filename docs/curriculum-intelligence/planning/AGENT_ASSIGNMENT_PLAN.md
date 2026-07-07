# Curriculum Intelligence — Agent Assignment Plan

**Date:** 2026-07-06 · Operationalizes [`PARALLEL_EXECUTION_PLAN.md`](PARALLEL_EXECUTION_PLAN.md) under the standing owner rule: **never two implementation agents on the same files/module; read-only analysis agents parallelize freely.**

---

## 1. Agent roles

| Agent | Type | Territory (exclusive when implementing) | Assigned waves |
|---|---|---|---|
| **CI-DATA** | implementation (data) | curriculum workspace only (per D-2); its own `scripts/` subfolder | CI-A0..A6, CI-B1..B4 execution |
| **CI-DISCOVER×N** | read-only (web/discovery) | none (produce candidate lists to CI-DATA's queue; single writer = CI-DATA) | inside CI-A waves, one per board/subject slice, freely parallel |
| **CI-DB** | implementation | `supabase/migrations/` (new files) | schema slices of CI-C1/C2/C4/C7/C8/E1 |
| **CI-BE** | implementation | `supabase/functions/_shared/education/**` (+ router registration line) | CI-C1/C3/C4/C5/C6/C7 backend |
| **CI-FE** | implementation | `lib/features/education/**` + education repository files | client halves of CI-C3/C4/C6/C7 |
| **CI-QA** | implementation (tests/evidence) | `scripts/qa/live_cert_question_intelligence.py` extensions, test files of the active wave, `docs/curriculum-intelligence/**` evidence | every code wave |
| **CI-REVIEW×N** | read-only (verify) | none | adversarial verification of extraction outputs (B-waves) and wave diffs |

## 2. Assignment rules

1. **One code wave active at a time** in the `education/**` territory; CI-BE is its single owner for the wave's duration. CI-C6 ∥ CI-C1 is permitted only after the small `education_repository.ts` touch is sequenced (see PARALLEL §2).
2. **CI-DB authors migrations for the active wave only** — no cross-wave batching of migrations (keeps rollback = one wave).
3. **CI-FE and CI-BE overlap within a wave** only after the API contract (paths + mapper DTOs) is committed by CI-BE; contract change mid-wave returns ownership to CI-BE.
4. **CI-DATA never touches app trees** — mechanically enforced by the CI-A0 `.gitignore` guard and review; if a data finding requires an app change, it files a task for a code wave instead.
5. **Extraction verification is adversarial:** every CI-B dataset gets ≥1 CI-REVIEW pass cross-checking against official sources (chapters vs published TOC; blueprint templates vs ≥2 specimen papers) before a code wave may consume it.
6. **EOS gate is run by the wave owner** (CI-BE for code waves, CI-DATA for data-phase exits) before any completion claim — per CLAUDE.md the gate is automatic and mandatory.

## 3. Wave → agent matrix

| Wave | CI-DATA | CI-DISCOVER | CI-DB | CI-BE | CI-FE | CI-QA |
|---|---|---|---|---|---|---|
| CI-A0 | ● lead | — | — | — | — | ○ dry-run check |
| CI-A1..A5 | ● lead | ●×N parallel | — | — | — | ○ integrity spot-checks |
| CI-A6 | ● lead | — | — | — | — | ● quality-score verify |
| CI-B1..B4 | ● lead | ○ source lookups | — | — | — | ● adversarial verify (+CI-REVIEW) |
| CI-C1 | — | — | ● templates schema | ● solver | — | ● golden tests + live-cert |
| CI-C2 | ○ dataset handoff | — | ● expansion migration | ○ boundary regression | — | ● wizard regression |
| CI-C3 | — | — | ○ additive cols | ● sets/export | ● PDF v2 UI | ● export goldens |
| CI-C4 | ○ dataset handoff | — | ● outcome/competency schema | ● tagging assist | ● tagging UI | ● tests |
| CI-C5 | — | — | ○ validation tables | ● validation engine | ○ surfacing | ● eval harness v0 |
| CI-C6 | — | — | ○ ingestion tables | ● OCR-first pipeline | ● moderation UI | ● extraction-rate tests |
| CI-C7 | — | — | ● profile/gating schema | ● profile engine | ● profile picker UI | ● gating tests |
| CI-C8 | — | — | ● link table | ● link handlers | — | ● tests |
| CI-C9 | ● detector over repo | — | — | ○ impact-report surface | — | ● seeded-change proof |
| CI-E1 | ○ concept seed | — | ● dormant migrations | — | — | ● applied-dormant check |
| CI-C10 *(A1)* | ○ concept-graph handoff | — | ● template/family/distractor schema | ● factory pipeline | ○ moderation queue reuse | ● boundary/metadata gates + goldens |
| CI-C11 *(A1)* | — | — | ● diagram schema | ● generation/validation service | ● diagram review UI | ● SVG validity + originality checks |

● = owner/primary · ○ = supporting/handoff · — = not involved

## 4. Session/continuity discipline

- The data lane is resumable by design: CI-DATA reads `PROJECT_STATUS.json` + `CHECKPOINTS.md` at session start and never restarts completed work (spec Part 02).
- Code waves follow the existing autonomous-wave discipline: read `NEXT_ACTIVE_WAVE`-equivalent for this program = [`MILESTONE_TRACKER.md`](MILESTONE_TRACKER.md) + the active wave row of [`IMPLEMENTATION_SEQUENCE.md`](IMPLEMENTATION_SEQUENCE.md).
- Hand-offs between agents happen only at committed artifacts (dataset files, migrations, contracts) — never via shared in-flight edits.
