# Curriculum Intelligence — Module Dependency Graph

**Date:** 2026-07-06 · Wave IDs from [`IMPLEMENTATION_SEQUENCE.md`](IMPLEMENTATION_SEQUENCE.md).

---

## 1. System-level layer graph (target architecture, spec Part 13 reconciled with v3.0)

```
                       DATA LANE                                    CODE LANE (app)
┌──────────────────────────────────────────────┐   ┌─────────────────────────────────────────────┐
│  L1 CURRICULUM REPOSITORY (new, CI-A*)       │   │  Existing certified engine (preserve)        │
│  resources/ metadata/ indexes/ reports/      │   │  edu_question_bank_items  ── solver ──┐      │
│        │                                     │   │  syllabus boundary (422)              │      │
│        ▼                                     │   │  governance draft→…→publish           │      │
│  L2 KNOWLEDGE EXTRACTION (CI-B*)             │   │  AI gap-fill (candidates only)        │      │
│  chapters/topics ─────────┐                  │   └───────────────┬───────────────────────┘      │
│  learning outcomes ────┐  │ feeds            │                   │ extends                      │
│  competencies ──────┐  │  │                  │                   ▼                              │
│  blueprint patterns │  │  ├─▶ subject_templates expansion (CI-C2) ── syllabus wizard/boundary   │
│  PYQ pattern store  │  │  └─▶ edu_blueprint_templates seed (CI-C1) ── template-aware solver     │
│  concept seed ──────┼──┼────▶ outcome/competency schema + tagging (CI-C4)                       │
│                     │  └────▶ AI Validation Engine golden sets (CI-C5)                          │
│                     └───────▶ canonical_concepts (dormant, CI-E1)                               │
└──────────────────────────────────────────────┘                                                  │
                                                    Profile Engine + tier gating (CI-C7)          │
                                                    Multi-set + PDF v2 + exports (CI-C3)          │
                                                    Cold-start ingestion (CI-C6, school-owned)    │
                                                    paper↔exam link + exposure (CI-C8)            │
                                                    continuous sync (CI-C9) ◀── L1 repository     │
                                                    dormant response spine (CI-E1) ─▶ v3.0 Phase 2
```

## 2. Wave dependency graph

```
D-1..D-4 (owner decisions)
   │
   ├────────────── DATA LANE ──────────────┐        ├────────── CODE LANE ─────────┐
   ▼                                       │        ▼                              │
CI-A0 ─▶ CI-A1 ─▶ CI-A2 ─▶ CI-A3 ─▶ CI-A4 ─▶ CI-A5 ─▶ CI-A6
           │        │        │       │                  │
           │ (per-board pipelining)  │                  │
           ├─▶ CI-B1 (chapters/topics, incremental) ────┼─▶ CI-C2 (templates expansion)
           ├─▶ CI-B2 (outcomes/competencies) ───────────┼─▶ CI-C4 (tagging)  [also needs CI-C1]
           ├─▶ CI-B3 (blueprint transcription) ─────────┼─▶ CI-C1 (templates+solver) ─┬─▶ CI-C3 (multi-set/PDF)
           │        (CBSE hand-seed may precede A1)     │                             ├─▶ CI-C5 (AI validation)
           └───────────────▶ CI-B4 (L2 PYQ-intelligence/concept seed) ──┼──────────────┐   └─▶ CI-C7 (profiles+gating)
                                                        │              ▼
                                    CI-A6 (Repository Certified, D-5) ──┴─▶ CI-C9 (continuous sync)
                                                        CI-C5 ─▶ CI-C6 (cold-start; D-6 lifecycle)
                                                                                      CI-C8 (paper↔exam) [independent]
                                                        CI-B4 + CI-C8 ─▶ CI-E1 (dormant Phase-2 seed) ─▶ v3.0 Phase 2
```

## 3. Dependency matrix

| Wave | Hard deps | Soft deps (better-with) | Blocks |
|---|---|---|---|
| CI-A0 | D-1, D-2 | — | all CI-A*, CI-C9 |
| CI-A1 | CI-A0 | D-3 (extraction scope), D-4 (order) | CI-A2, CI-B1/B2/B3 (CBSE increment) |
| CI-A2..A4 | previous board | — | next board; per-board B-increments |
| CI-A5 | CI-A4 | — | CI-A6 |
| CI-A6 | CI-A5 | — | CI-B4, CI-C9 |
| CI-B1 | first completed board | all boards for full dataset | CI-C2 |
| CI-B2 | first completed board | — | CI-C4 |
| CI-B3 | CBSE specimen docs (hand-seed OK pre-A1) | CI-A1 for breadth | CI-C1 |
| CI-B4 | CI-A6, CI-B1 | — | CI-E1 |
| CI-C1 | CI-B3 subset | golden tests first (internal step) | CI-C3, CI-C4, CI-C5, CI-C7 |
| CI-C2 | CI-B1 | — | CI-C9 |
| CI-C3 / C7 | CI-C1 | — | — |
| CI-C5 | CI-C1 | — | **CI-C6** (D-6 lifecycle: AI_VALIDATED precedes TEACHER_VALIDATED) |
| CI-C4 | CI-B2 + CI-C1 | — | — |
| CI-C6 | **CI-C5** (D-6, owner 2026-07-07) | CI-C1 (classification reuse) | — |
| CI-C8 | none | — | CI-E1 |
| CI-C9 | CI-A6 + CI-C2 | — | — |
| CI-E1 | CI-C8 + CI-B4 | — | v3.0 Phase 2 (external) |

## 4. Existing modules consumed (never modified destructively)

| Existing module | Consumed by | Mode |
|---|---|---|
| `education_blueprint_solver.ts` | CI-C1 | extend (template inputs) |
| `education_syllabus_boundary.ts` + `subject_templates` | CI-C2 | widen catalogue |
| `education_ai_question_gapfill.ts` + `_shared/ai/anthropic_client.ts` | CI-C5, CI-C6 | reuse client + candidate contract |
| `education_fingerprint.ts` | CI-C6 | reuse verbatim |
| `edu_question_paper_reviews` governance | CI-C5, CI-C6 | extend states, never bypass |
| `plan_entitlements` / `platform_feature_enablements` | CI-C7 | reuse (B2-certified pattern) |
| `exam_mark_entries` / `exam_sessions` | CI-C8 | read-only link table |
| `intel_exam_intelligence_snapshots` pattern | CI-C9 impact reports | copy pattern |
| Flutter education feature + repository pattern | CI-C3/C4/C6/C7 client work | extend screens/providers |
| XCT-1 shared PDF/grid export pipeline | CI-C3 exports | ride, don't fork |
