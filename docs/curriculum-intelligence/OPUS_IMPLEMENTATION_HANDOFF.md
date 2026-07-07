# Curriculum Intelligence — Implementation Handoff (Claude Opus 4.8)

**Date:** 2026-07-07 · **Status:** 🟢 **APPROVED — 🔒 Program Baseline v1.0 + Amendment A1 (AIMS sync 2026-07-07). D-1..D-6 resolved; implementation authorized starting at §8 row 1.** A1 = the canonical [`spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`](spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md) merged into this package (delta record: [`audits/GAP_ANALYSIS.md`](audits/GAP_ANALYSIS.md) §6) — scope extensions to CI-B4/C4/C5/C7 + new post-E1b waves **CI-C10** (Question Factory) / **CI-C11** (Diagram Intelligence); nothing pre-P4 changed.
**Purpose:** everything an implementing agent needs to build without repeating architectural analysis. Read order: this file → [`README.md`](README.md) decision record → [`INTEGRATION_AND_READINESS_REVIEW.md`](INTEGRATION_AND_READINESS_REVIEW.md) → the doc named by the wave you're executing.

> **Owner decisions binding every wave (full record: [`audits/GAP_ANALYSIS.md`](audits/GAP_ANALYSIS.md) §3):**
> **D-1** certified engine stays the production engine — extend, never replace/redesign · **D-2** `curriculum/` workspace, binaries gitignored · **D-3** three-layer model — L1 official corpus / L2 PYQ Intelligence (analysis only) / **L3 Certified Question Bank = the only default production source** · **D-4** boards CBSE → AP → TS → CISCE · **D-5** `Downloaded → Verified → Repository Certified → Knowledge Base` (KB never before certification) · **D-6** question lifecycle `RAW → EXTRACTED → AI_VALIDATED → TEACHER_VALIDATED → CERTIFIED`; only CERTIFIED generates by default.

---

## 1. Project summary (60 seconds)

Akshara ERP (Flutter + Supabase/Postgres edge functions, multi-tenant school ERP, VPS pilot) already runs a **live-certified Question Intelligence engine**: bank-first deterministic blueprint solver, hard syllabus boundary (422 OFF_SYLLABUS), constrained Claude gap-fill emitting moderation candidates only, draft→submit→review→approve→publish governance (submitter ≠ approver), fingerprint dedup, Bloom + program-track metadata. The Curriculum Intelligence program adds: **(a)** a verified official-curriculum repository (CBSE/TS/AP/CISCE, Classes 6–10, English) with knowledge extraction, and **(b)** engine completion — governed blueprint templates, profile engine, AI validation layers, cold-start ingestion — executed as v3.0 Phase 1. A Download Verification & Recovery Engine (checks V1–V11) is **already implemented and tested**; every acquisition download must pass through it.

## 2. Architecture summary & governing law (in precedence order)

1. **Engineering Constitution + EOS gate** — every code wave = one EOS-gated commit. Never create a competing readiness standard.
2. **🔒 Assessment-Intelligence-Platform v3.0** (`docs/Vision/design/Assessment-Intelligence-Platform.md`, locked D1–D11) — governs on any conflict with the MCIP spec. Non-negotiables: D2 no per-student answer-sheet OCR/OMR · D7 AI never auto-trusted · D8 original-content-first (no publisher dependency; PYQs = pattern analysis, never bulk republishing).
3. **AIMS** (`spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`, Parts 1–12, owner drop 2026-07-07) — canonical assessment-intelligence layer spec; by its own Part 1 it **extends** the Program Baseline and is subordinate to v3.0 on conflict. Its golden rules (Part 5) and anti-patterns (Part 12) bind every wave.
4. **MCIP spec** (`spec/MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md`, Parts 01–16) + **engine addendum** (`spec/DOWNLOAD_VERIFICATION_AND_RECOVERY_ENGINE.md`).
5. This program's audits + planning suite (conflict resolutions in `audits/GAP_ANALYSIS.md` §2 are settled — do not relitigate; AIMS deltas recorded in §6).

**Certified invariants I1–I8** (`audits/BACKWARD_COMPATIBILITY_PLAN.md` §1) are inviolable: bank-first determinism · syllabus boundary · AI-candidates-only + publish gate · safe-by-default no-key · governance chain · exam-results integrity · RLS shape · zero finance surface.

## 3. Current implementation status (verified 2026-07-07)

| Area | Status |
|---|---|
| Planning/audit doc suite (21 docs, `docs/curriculum-intelligence/`) | ✅ complete, repository-verified |
| Download Verification & Recovery Engine (`curriculum/scripts/verification/`) | ✅ implemented; **13/13 tests green**; config-external; audit gate proven both directions |
| Curriculum workspace remainder (PM files, downloader, discovery) | ⚪ not started (CI-A0 remainder) |
| Curriculum content (resources) | ⚪ zero acquired |
| Engine code waves (templates/solver/profiles/validation/ingestion) | ⚪ not started, scheduled post-pilot as v3.0 Phase 1 |
| App code (`lib/`, `supabase/`) | **untouched by this program** — keep it that way until the wave that says otherwise |

## 4. Implementation order (approved shape — see review §4)

1. **CI-DATA track (start now, parallel to everything):** CI-A0 remainder → CI-A1(CBSE) → A2(**AP**) → A3(**TS**) → A4(CISCE) → A5 → A6 ending in **Repository Certification (D-5)**; knowledge waves CI-B1/B2/B3 pipelined per completed board; CI-B4 (L2 PYQ Intelligence — analysis only) after certification. Boards strictly sequential; every download through the verification engine; board exit = Priority-A 100%-or-documented.
2. **P1-CI-0 (one small EOS wave, before P4 red team):** golden-test pinning of `education_blueprint_solver.ts` current behaviour (no behaviour change) + `edu_exam_paper_links` (v3.0 §5.2 shape, TEXT exam_id ↔ UUID paper_id, unique org/school/exam/set) + **dormant** response-spine/trust/exposure migrations (E1a). Optional rider: CI-C2 catalogue expansion if CI-B1(CBSE) is ready and the pilot needs it.
3. **v3.0 Phase 1 window (post-pilot):** CI-C1 (blueprint templates + constraint solver — flagship) → CI-C3 (multi-set + PDF v2 + JSON export) → **CI-C5 (AI Validation Engine) → CI-C6 (cold-start ingestion — D-6: AI_VALIDATED precedes TEACHER_VALIDATED)** → C4/C7 per the dependency graph; CI-C9 sync after certification+C2; E1b (canonical concepts) after B4.
4. **A1 asset factories (Phase-1→2 boundary, owner-timed A1-O1):** **CI-C10** Question Factory (Item Models + families + Distractor Library + offline batch generation, `GENERATED → AI_VALIDATED → … → CERTIFIED`) after CI-C5 + E1b · **CI-C11** Diagram Intelligence (spec-driven SVG generation → Certified Diagram Library, vector-only/original-only) after CI-C5 + B4. Scoped red-team playbook re-run when they ship.

**Critical dependencies:** CI-B3 transcriptions gate CI-C1 (a hand-transcribed CBSE SQP subset suffices to start) · CI-B1 gates CI-C2 · CI-B2 gates CI-C4 · **CI-C5 gates CI-C6 (D-6)** · Repository Certification gates B4/C9 and ALL knowledge-base work (D-5) · golden tests gate ANY solver edit · E1a gates v3.0 Phase-2 data capture (cannot be backfilled — do not let it slip) · *(A1)* CI-C5 + E1b gate CI-C10, CI-C5 + B4 gate CI-C11 (AIMS Rule 2: no generation without concept mapping).

**Parallel opportunities:** CI-DATA ∥ all app waves (disjoint trees) · CI-C8 has no deps · B-extraction(board N) ∥ acquisition(board N+1) · FE/BE halves of a wave overlap only after the API contract commits. **Never** two implementation agents in `supabase/functions/_shared/education/**` at once; DATA agents never touch app trees (standing owner rule).

## 5. Verified deliverables to build on (don't rebuild)

- `curriculum/scripts/verification/verification_engine.py` — V1–V11, recovery ladder (`next_recovery_action`), duplicate diversion, report generator. CLIs: `verify_downloads.py` (batch/single/report-only), `repository_audit.py` (sole authority for `REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION`).
- `curriculum/configs/{paths,verification_rules}.json` — all layout + thresholds; change config, not code. Install `pypdf` to upgrade PDF page-parsing (zero code change).
- Reuse matrix (`planning/MODULE_DEPENDENCY_GRAPH.md` §4): solver, boundary, AI client, fingerprint, review governance, `plan_entitlements`, `intel_*` snapshot pattern, XCT-1 export pipeline, education repository pattern (`repository_providers.dart:436` reference wiring).

## 6. Owner decisions — ✅ ALL RESOLVED (Baseline v1.0, 2026-07-07)

D-1..D-6 are law (header box above + [`audits/GAP_ANALYSIS.md`](audits/GAP_ANALYSIS.md) §3). Nothing blocks implementation. Surface any *new* decisions in batches at natural boundaries; never pause unrelated work on one.

## 7. Standards the implementer must follow

- **Coding:** match module idiom exactly — Deno/TS `education_*` file pattern (router→handlers→repository→service), pure/deterministic solver (templates are inputs, never side effects), Flutter interface→mock→api→hybrid repository pattern with per-module flag, additive-nullable migrations on the `202608xx+` ledger, RLS = certified `_school_scope` shape + `FORCE`, narrow `erp_tenant` grants. Python data-lane: stdlib-first, config-driven, checkpoint-resumable.
- **EOS:** run the gate before ANY completion claim; wave = one commit; regression bar per wave: `flutter analyze` 0 · `flutter test` no new failures · `deno test`+`check` green for touched functions · original live-cert 20 stays green (extensions staged locally while the live lane is owner-deferred).
- **Golden tests (hard rule):** pin current solver outputs (slot plans + marks distribution, byte-stable) **before** the first solver edit; template-absent requests must remain golden-identical forever (B1 mitigation). Rollback drill: generate-with-template → flip flag → verify legacy golden same-session.
- **Backward compatibility:** invariants I1–I8; risk mitigations B1–B10; additive-only; no destructive down-migrations on the pilot; new AI surfaces emit candidates/flags only, never auto-approved content.
- **Acceptance:** every wave's proof obligations are pre-written — `planning/ACCEPTANCE_TEST_PLAN.md` (AT-V ✅ done; AT-D data lane; AT-K datasets; AT-C1..C9/E1 code waves). A wave without its AT evidence is not done.
- **Risk watch:** top items R1 legal/copyright (never store out-of-scope question content; license status mandatory), R3 solver regression, R7 dataset poisoning (adversarial verify before any code wave consumes a dataset), R10 binaries-in-git (guard exists — keep it), *(A1)* R15 AIG variation flooding + R16 diagram originality. Full register: `planning/RISK_REGISTER.md`.
- **AIMS standards (A1, binding):** design patterns P1–P18 + anti-pattern catalogue (AIMS Parts 11–12) — concept-first (once the graph is live), generate→validate→certify with no shortcut, offline-AI / deterministic-runtime split (never invoke AI per paper), metadata-first business logic, complete-metadata gate at certification (new items only, TD-CI-17), question versioning (never overwrite), vector-only original diagrams, no business rules in UI, no derived-value duplication, config-over-hardcode. The D-6 lifecycle gains the `GENERATED` entry state for AI-authored items; post-CERTIFIED states map to the v3.0 §10.2 pipeline (Phase 2) — see `audits/GAP_ANALYSIS.md` §6 A1-6.

## 8. Final recommendations (Step 9)

| Topic | Recommendation |
|---|---|
| **Immediate next milestone** | M1: CI-A0 remainder (PM files, downloader skeleton obeying `next_recovery_action`, discovery configs, extend `repository_audit.py` to emit the D-5 certification artifact) + CI-A1 CBSE acquisition — **authorized now** |
| **First implementation wave (code)** | **P1-CI-0** (golden pinning + `edu_exam_paper_links` + dormant E1a seed) — ~2–4 dev-days, additive-only, must land before P4-RT-0 |
| **Highest-risk modules** | CI-C1 solver upgrade (touches the certified path — golden-first, template-absent-legacy) · CI-C6 ingestion (OCR quality + token discipline) · anything near D-3 legal scope · *(A1)* CI-C11 diagram originality (R16) |
| **Lowest-risk modules** | Entire CI-DATA track (zero app surface) · CI-C8 link table · E1a dormant seed · CI-C3 exports (rides XCT-1) |
| **Parallel implementation** | 1 data-lane owner + 1 code-lane wave at a time; unlimited read-only discovery/verification agents; per §4 constraints |
| **Repository preparation** | Ratify D-2 → finish CI-A0 (PM files, `DOWNLOAD_QUEUE.json` JSON-schema, `logs/` wiring, `pip install pypdf`) → dry-run cycle → begin CBSE discovery |
| **Knowledge-Base preparation** | None until **Repository Certification (D-5)** is granted — the audit gate is implemented; respect it. Pre-work allowed: CI-B3 hand-transcription of CBSE SQP structures (feeds CI-C1 whenever its window opens) |
| **Expected timeline** | Data lane ~39–61 dev-days elapsed (external-bounded; checkpointed) · P1-CI-0 ~2–4 days · v3.0 Phase-1 code waves ~30–40 days post-pilot · program G2 ≈ data-lane length since code fits inside it · *(A1)* factories CI-C10/C11 ~12–16 days beyond G2 at the Phase-1→2 boundary |
| **Testing strategy** | unit (engine 13/13 + per-wave suites) → golden (solver pinning) → contract (mapper/route tests, DB-free 503-pattern) → live-cert extensions (staged until live lane) → data gates (AT-D/AT-K adversarial verification) → scoped red-team playbook re-run on new AI surfaces when Phase 1 ships |

---

**START LINE (replaces the former stop line):** Baseline v1.0 is owner-approved (2026-07-07). Implementation begins exactly at §8 row 1 (M1 data lane) and schedules P1-CI-0 before P4-RT-0. The baseline is frozen — deviations from D-1..D-6 or the planning suite require owner approval; per D-6, production paper generation must never select below CERTIFIED by default.
