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
                                                        CI-C5 + CI-E1b ─▶ CI-C10 (question factory, A1)
                                                        CI-C5 + CI-B4  ─▶ CI-C11 (diagram intelligence, A1)
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
| CI-E1 | CI-C8 + CI-B4 | — | v3.0 Phase 2 (external) · CI-C10 (E1b concept read-path) |
| CI-C10 *(A1)* | **CI-C5 + CI-E1b** (concept seed live — AIMS Rule 2) | CI-C4 (family/tag columns) | — |
| CI-C11 *(A1)* | **CI-C5 + CI-B4** (concept IDs) | CI-C3 (PDF v2 embed point) | — |

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
| `education_ai_question_gapfill.ts` candidate contract + moderation queue | CI-C10 factory outputs *(A1)* | reuse contract verbatim (GENERATED → candidates) |
| `education_syllabus_boundary.ts` | Boundary Engine v2 (CI-C4/C5/C10) *(A1)* | extend in place with new dimensions — never fork |

## 5. AIMS pipeline → wave mapping (Amendment A1-13; spec Part 7)

The AIMS canonical pipelines P1–P12 do **not** create new workstreams — they map onto the program as follows. Every pipeline inherits the AIMS pipeline standards (versioning, checkpoint recovery, logging, metrics, audit trail, validation gates) which the data lane already implements and code waves implement via the EOS evidence bar.

| AIMS pipeline | Maps to | Status |
|---|---|---|
| P1 Curriculum Acquisition | CI-A0..A6 + Download Verification Engine (V1–V11) + Repository Certification (D-5) | Engine ✅; waves planned |
| P2 Knowledge Extraction | CI-B1 (structure) + CI-B2 (outcomes/competencies) | Planned |
| P3 Concept Graph | CI-B4 Concept Graph dataset → CI-E1b seed | Planned (A1-extended scope) |
| P4 Question Generation | Today: constrained gap-fill (certified) · At scale: **CI-C10 Question Factory** | New wave (A1) |
| P5 Diagram Generation | **CI-C11 Diagram Intelligence** | New wave (A1) |
| P6 Quality & Certification | CI-C5 (AI_VALIDATED) + moderation (TEACHER_VALIDATED) + D-6 gate | Planned |
| P7 Paper Assembly (runtime) | Certified engine + CI-C1/C3/C7 — deterministic, certified-assets-only | Core live-certified |
| P8 Teacher Feedback | Review governance today; feedback-intelligence aggregation = v3.0 Phase 2 | Phase 2 |
| P9 Student Analytics | Response spine (E1a dormant seed) → v3.0 Phase 2 | Phase 2 |
| P10 Continuous Knowledge Evolution | CI-C9 continuous-sync v1 + incremental reprocess queue | Planned |
| P11 Foundation Profile Generation | CI-C7 foundation rules (depth-not-scope) + CI-C10 under those rules | Planned |
| P12 Copyright Compliance | Data-lane license discipline (AT-D6, LICENSE_REPORT) + D-3/D8 guardrails + R1 mitigations | Standing |

## 6. AIMS service → module mapping (Amendment A1-14; spec Part 8)

AIMS Part 8 is a **logical** service architecture; per its own implementation guideline, no new services are created now — the modular monolith stays and each responsibility maps to an existing or planned module:

| AIMS logical service | Existing/planned home |
|---|---|
| Curriculum Service | `subject_templates` + `syllabus_*` tables + syllabus wizard; widened by CI-C2 |
| Repository Service | `curriculum/` workspace: verification engine, `repository_audit.py`, indexes, configs |
| Knowledge Service | CI-B* datasets + CI-C9 sync/delta detection |
| Concept Service | Canonical-concept tables (CI-E1b seed; feature activation v3.0 Phase 2) |
| Question Service | `education_repository.ts` bank + CI-C1 templates + CI-C10 item models/families |
| Answer Service | `answer_key` JSONB + CI-C5 blind-solve verification + CI-C10 answer generation |
| Diagram Service | **CI-C11** `edu_diagrams` + generation/validation pipeline |
| Blueprint Service | `edu_blueprint_templates` + `education_blueprint_solver.ts` (CI-C1) |
| Validation Service | `education_syllabus_boundary.ts` (Boundary v2) + `education_fingerprint.ts` + CI-C5 engine |
| Assessment Service | `education_question_paper_service.ts` + solver + CI-C3/C7 runtime assembly |
| Analytics Service | `intel_*` snapshot pattern; response-spine analytics = v3.0 Phase 2 |
| Teacher Intelligence Service | `edu_question_paper_reviews` governance; aggregation = v3.0 Phase 2 |
| AI Intelligence Service | `_shared/ai/anthropic_client.ts` + gap-fill + CI-C5/C10 offline batch callers |
| Configuration Service | `plan_entitlements` / `platform_feature_enablements` + CI-C7 profile config + `curriculum/configs/` |
