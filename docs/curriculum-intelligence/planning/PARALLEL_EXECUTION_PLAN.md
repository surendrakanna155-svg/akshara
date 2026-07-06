# Curriculum Intelligence — Parallel Execution Plan

**Date:** 2026-07-06 · Governed by the standing **agent file-ownership rule**: never two implementation agents on the same files/module; read-only/analysis/data agents parallelize freely.

---

## 1. Parallelism map

| Track | Can run in parallel with | Why safe |
|---|---|---|
| **Data lane (CI-A*/CI-B*)** | Everything — incl. the frozen master roadmap's own waves | Touches only the curriculum workspace (D-2); zero app files |
| **CI-C6** (cold-start ingestion) | ~~CI-C1~~ — **re-sequenced by owner D-6 (2026-07-07): CI-C6 follows CI-C5** so extracted questions walk `RAW → EXTRACTED → AI_VALIDATED → TEACHER_VALIDATED → CERTIFIED`; C6's UI half may still overlap C5's backend once contracts commit |
| **CI-C8** (paper↔exam link) | CI-C1, CI-C3 | Disjoint: new migration + new handler paths; reads exam tables only |
| **CI-C3** (multi-set/PDF) client half | CI-C3 backend half | Flutter vs Deno trees are disjoint; contract fixed first via mapper types |
| **CI-B1/B2/B3 extraction of board N** | CI-A(N+1) acquisition of the next board | Read-only over completed board's corpus |
| Within CI-A waves: discovery agents per subject | each other | Read-only web discovery; single writer for queue/metadata files |

## 2. Explicitly sequential (never parallelize)

| Sequence | Reason |
|---|---|
| CI-C1 golden-test pinning → solver refactor | Tests must pin certified behaviour before any change (B1 mitigation) |
| CI-C1 → CI-C3 / CI-C5 / CI-C7 | All three modify or consume solver/template contracts |
| CI-C5 → CI-C6 | Owner D-6 lifecycle: AI_VALIDATED must precede TEACHER_VALIDATED for extracted questions |
| CI-C2 migration → CI-C9 sync | Sync targets the versioned catalogue |
| Any two waves touching `education_repository.ts` / `education_handlers.ts` | Shared-file rule — single owner at a time |
| Board acquisition CI-A1→A2→A3→A4 | Spec Part 02 mandate (one board completely before the next) |

## 3. Ownership boundaries (implementation agents)

| Owner slot | File territory | Waves |
|---|---|---|
| **DATA** | curriculum workspace only (`curriculum/` or per D-2); `scripts/` additions under its own subfolder | CI-A*, CI-B* |
| **DB** | `supabase/migrations/*` (new files only) | CI-C1/C2/C4/C7/C8/E1 schema slices |
| **BE** | `supabase/functions/_shared/education/**` | CI-C1/C3/C4/C5/C6/C7 backend |
| **FE** | `lib/features/education/**`, `lib/core/repositories/{interfaces,api/education,mock}/**` education files | client halves of CI-C3/C4/C6/C7 |
| **DOCS/QA** | `docs/curriculum-intelligence/**`, `scripts/qa/live_cert_question_intelligence.py` extensions | all waves' evidence |

Rules: one wave = one BE owner + one FE owner max, migrations authored by the wave's single DB owner; DATA never touches app trees (enforced by the CI-A0 `.gitignore` guard + review); read-only exploration agents unrestricted.

## 4. Recommended concurrency profile

- **Steady state:** 1 data-lane worker (acquisition is I/O-bound and checkpointed) + 1 code-lane wave at a time (EOS discipline) + unlimited read-only discovery/verification agents inside the active wave.
- **Burst opportunities:** CI-C6 ∥ CI-C1 (after the shared-file touch is sequenced); CI-C8 slotted into any idle code-lane gap; B-extraction ∥ next-board acquisition.
- **Anti-pattern to avoid:** parallel solver + validation-engine work (both live in the generation path files); parallel edits to `education_handlers.ts` from two waves.
