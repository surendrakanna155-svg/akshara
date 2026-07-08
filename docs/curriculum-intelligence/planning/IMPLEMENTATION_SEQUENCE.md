# Curriculum Intelligence — Implementation Sequence

**Date:** 2026-07-06 · **Status:** 🔒 **PROGRAM BASELINE v1.0 + Amendment A1 (AIMS sync 2026-07-07)** — owner-approved 2026-07-07 (decisions D-1..D-6, see [`../audits/GAP_ANALYSIS.md`](../audits/GAP_ANALYSIS.md) §3; A1 delta record §6). Implementation authorized per [`../OPUS_IMPLEMENTATION_HANDOFF.md`](../OPUS_IMPLEMENTATION_HANDOFF.md); wave timing per the integration review §4 (data lane now · P1-CI-0 pre-red-team · engine waves = v3.0 Phase 1 · A1 factories at the Phase-1→2 boundary)
**Derived from:** [`../audits/GAP_ANALYSIS.md`](../audits/GAP_ANALYSIS.md) (verdicts + owner decisions D-1..D-4) · 🔒 v3.0 D1–D11 · [`../spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`](../spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md) (AIMS, Amendment A1) · the certified as-built engine.
**This is the master ordering document.** All other planning docs reference the wave IDs defined here.

> 🟡 **Pending planning proposal (does NOT change this sequence):** Amendment **A2** — *Deterministic
> Per-Student Practice & DPP Generation Engine* ([`../proposals/AMENDMENT_A2_PER_STUDENT_PRACTICE_GENERATION.md`](../proposals/AMENDMENT_A2_PER_STUDENT_PRACTICE_GENERATION.md);
> direction + D-7 + I9 owner-approved 2026-07-08, ratification pending). On ratification it would
> **extend** — never reorder — waves **CI-C10** (family-level certification), **CI-C1** (deterministic
> runtime instantiation), **CI-C3** (generation modes), **CI-C8** (per-student non-repetition), and
> the v3.0 §13 DPP scheduler. Until ratified, all wave IDs, order, dependencies, and goal lines below
> are unchanged. Proposals register: [`../proposals/README.md`](../proposals/README.md).

---

## 1. Two-lane model (the core sequencing decision)

| Lane | Content | Touches app code? | Gate | Can start |
|---|---|---|---|---|
| **Data lane** (waves `CI-A*`, `CI-B*`) | Curriculum acquisition, repository, metadata, knowledge extraction datasets (spec Parts 02–08 + data half of 09–10) | **No** — lives in the curriculum workspace (owner decision D-2) | Data-quality gates (spec Part 07 coverage + integrity), not EOS code gates | Immediately on owner approval (D-1) — long lead time, zero live-path risk |
| **Code lane** (waves `CI-C*`, `CI-E*`) | Engine extension: blueprint templates, solver upgrade, profiles, validation layers, ingestion, links, schema seeds (spec Parts 09–14 code half) | **Yes** — EOS-gated waves, one commit unit each | `/eos` FEATURE PASS per wave (Constitution) | Per owner sequencing (D-1); aligns with v3.0 Phase-1 scope |

Rationale: acquisition is externally-bounded (government portals, discovery churn) and produces the datasets the code lane consumes; the code lane must not regress a live-certified engine and therefore rides the standard EOS wave machinery. The data lane never blocks the frozen FINAL_EXECUTION_MASTER_ROADMAP.

## 2. Wave sequence

### Data lane — acquisition (spec Parts 02–08; boards strictly sequential per spec Part 02)

| Wave | Scope | Depends on | Exit gate |
|---|---|---|---|
| **CI-A0** | Curriculum workspace scaffolding: directory standard (Part 04), `configs/` (boards/subjects/classes/download/metadata-schema/quality/retry rules), PM files (TODO/PROGRESS/SESSION_LOG/CHECKPOINTS/queues/PROJECT_STATUS), `scripts/` skeleton (download/verify/organize/metadata/reports), `.gitignore` guard for binary trees. **⚙ Partially delivered 2026-07-07 under direct owner instruction:** the [Download Verification & Recovery Engine](../spec/DOWNLOAD_VERIFICATION_AND_RECOVERY_ENGINE.md) (checks V1–V11, recovery queue, health report, final repository audit) is implemented + tested at `curriculum/scripts/verification/` with `configs/` + guard in place; remaining CI-A0 scope = discovery/download scripts + full PM-file set | Owner D-1 + D-2 | Directory validation passes; PM files synchronized; dry-run of one download→verify→organize→metadata→index cycle |
| **CI-A1** | **CBSE + NCERT**, Classes 6–10, English medium: discovery → Priority-A acquisition (curriculum, syllabus, textbooks, teacher guides, learning outcomes, blueprints, assessment guidelines, question banks*, model papers*) → metadata → indexes → coverage report (*subject to D-3 scope) | CI-A0 | Priority-A coverage 100% or every gap documented `NOT_PUBLICLY_AVAILABLE`; integrity verification green |
| **CI-A2** | **AP SCERT** — same cycle | CI-A1 | same |
| **CI-A3** | **Telangana SCERT** — same cycle | CI-A2 | same |
| **CI-A4** | **CISCE/ICSE** — same cycle | CI-A3 | same |
| **CI-A5** | Priority-B sweep (worksheets, activity books, lab manuals, competency docs) + foundation corpus (official/open JEE/NEET/NTSE/Olympiad per v2.0 §4 source table) | CI-A4 | Priority-B ≥95% or documented |
| **CI-A6** | Repository close-out + **Repository Certification (D-5)**: dedup pass, quality score, MISSING_RESOURCES, LICENSE_REPORT, full index rebuild, `repository_audit.py` PASS → `CURRICULUM_REPOSITORY_CERTIFICATION.md` evidence + certified flag in `PROJECT_STATUS.json`. Status chain: `Downloaded → Verified → Repository Certified → Knowledge Base` — **KB work may never start before certification** | CI-A5 | Spec Part 07/08 completion criteria + certification granted |

*(Board order fixed by owner D-4: **CBSE → AP → Telangana → CISCE**.)*

### Data lane — knowledge engineering (spec Part 09 + data half of 10; per-board increments may begin as each board's acquisition completes)

| Wave | Scope | Depends on | Exit gate |
|---|---|---|---|
| **CI-B1** | Structure extraction: chapters/topics for classes 6–10 per board → **`subject_templates` expansion dataset** (JSON, matching the existing Grade-10 seed format) + curriculum-versioning design | CI-A1 (then per board) | Dataset validates against template schema; spot-check vs official TOCs |
| **CI-B2** | Learning-outcome + competency extraction (official documents only, verbatim, source-traced — spec Part 09 "do not invent") → structured datasets | CI-A1+ | Every outcome carries resource ID + page; zero invented content |
| **CI-B3** | **Blueprint-template transcription** (D5/v3.0 §9.3): official board paper structures (sections, marks, internal choice, chapter weightage, competency quotas) from specimen/sample papers → versioned template seed data. CBSE + pilot state board first | CI-A1 (CBSE specimen docs); hand-transcription of CBSE SQP may start day 1 | Template JSON validates against §9.1 structure schema; cross-checked against ≥2 official specimen papers per template |
| **CI-B4** | **Previous Question Paper Intelligence layer** (D-3 L2 — analysis/reference only, never school-facing bank content) + knowledge objects (definitions/formulae/events) + **Concept Graph dataset** *(scope extended by AIMS A1-1)*: canonical-concept seed per v3.0 §8.3 staging **plus** permanent Concept-ID scheme (`SUBJ_G##_…` pattern), parent/child + prerequisite + related-concept relationships, common misconceptions / frequently-confused pairs, Bloom-level + difficulty ranges, foundation-boundary attributes | CI-A6 (**Repository Certified**), CI-B1 | Concept seed reviewed; graph relationships spot-verified by CI-REVIEW; L2 store carries license metadata; zero L2→L3 automatic flow |

### Code lane — engine completion (EOS-gated app waves; scope = v3.0 Phase 1 ∩ spec Parts 12–14)

| Wave | Scope | Depends on | Exit gate |
|---|---|---|---|
| **CI-C1** | **Golden-test pinning of current solver behaviour** → `edu_blueprint_templates` schema (v3.0 §9.1) → solver template-aware upgrade: slot groups/sections, internal choice pools, chapter-weightage + cognitive quotas as hard constraints, full-bank pagination (remove 100-cap). Template absent ⇒ legacy behaviour (B1 mitigation) | CI-B3 (or hand-seed subset) | EOS PASS; golden tests green; template-compliance tests; live-cert original 20 green |
| **CI-C2** | `subject_templates` expansion migration (CI-B1 datasets) + versioning columns; syllabus wizard + boundary regression | CI-B1 (per board) | EOS PASS; boundary/wizard regression green |
| **CI-C3** | Multi-set papers (A/B/C, per-set keys) + PDF v2 (sections, instructions, branding, key separation) + structured JSON export | CI-C1 | EOS PASS; export goldens |
| **CI-C4** | Learning-outcome/competency schema + bank tagging + Tier-1 classification assist (rule-first, AI-suggest, teacher-confirm — D3 doctrine) *(A1-2/A1-5: adds question-family + concept-ID nullable columns and the outcome/competency dimensions of Curriculum Boundary Engine v2 — extending `education_syllabus_boundary.ts`, never forking it)* | CI-B2, CI-C1 | EOS PASS |
| **CI-C5** | **AI Validation Engine** (spec Part 11 = v3.0 §11 layers 4–6): independent blind-solve answer verification, metadata sanity cross-check, quality/confidence scoring + revision versioning (original never overwritten). Implements the **AI_VALIDATED** state of the D-6 lifecycle `RAW → EXTRACTED → AI_VALIDATED → TEACHER_VALIDATED → CERTIFIED` *(A1-9: adds the metadata-completeness certification gate — new certifications only, legacy rows grandfathered per TD-CI-17; A1-2: boundary check on generated content incl. Bloom/difficulty)* | CI-C1 | EOS PASS; eval-harness v0 (golden question set) |
| **CI-C6** | **Bank cold-start ingestion** (v3.0 §7/1.8): school-owned past papers → OCR-first (D3) → `RAW → EXTRACTED` Question Objects → **AI_VALIDATED via CI-C5** → teacher moderation (`TEACHER_VALIDATED`) → `CERTIFIED` bank merge. Only CERTIFIED items become selectable for production generation (D-6 default = existing engine behaviour: `active ∧ approved`) | **CI-C5** (D-6: AI validation precedes teacher validation) | EOS PASS; ≥80% auto-extraction on test corpus; zero LLM tokens on deterministic residue; lifecycle states persisted per item |
| **CI-C7** | **Exam Profile Engine** (spec Parts 13–14): profile config entity over `program_track`, profile-driven selection weighting + pre-generation compatibility validation ("never silently downgrade") + capability gating on `plan_entitlements` *(A1-11: profile config also carries time allocation, reasoning depth, diagram requirements, question-family distribution; A1-3: **foundation depth-not-scope** validation — foundation profiles may raise Bloom/reasoning, never curriculum scope, unless explicitly configured)* | CI-C1 | EOS PASS; profile validation tests; gating default-allow verified (B7) |
| **CI-C8** | `edu_exam_paper_links` (paper↔exam) + exposure/rotation columns + selection-reason logging (explainability) | none (small; parallel-eligible) | EOS PASS |
| **CI-C9** | Continuous-sync v1 (spec Part 15): checksum/version change detection over the repository, incremental reprocess queue, `CURRICULUM_CHANGE_IMPACT_REPORT` | CI-A6 + CI-C2 | Detection catches a seeded change end-to-end |
| **CI-E1** | **Dormant Phase-2 schema seed** (v3.0 §5.3): response spine, trust-status columns, item-statistics, canonical-concept tables (from the CI-B4 Concept Graph dataset, incl. A1-1 relationship/misconception columns) — migrations only, zero UI. Split per the integration review: **E1a** (response spine/trust/exposure — lands early in P1-CI-0) / **E1b** (canonical concepts — after CI-B4) | CI-C8, CI-B4 | EOS PASS; migrations applied dormant |

### Code lane — asset factories (Amendment A1; owner-timed at the v3.0 Phase-1→2 boundary — A1-O1)

| Wave | Scope | Depends on | Exit gate |
|---|---|---|---|
| **CI-C10** | **Question Factory (AIMS A1-4/5/8 — Pipeline 4):** `edu_question_templates` (Item Models with controlled parameter variation), `edu_question_families`, `edu_distractors` (Distractor Library, misconception-categorised, concept-linked) + **offline batch generation** per concept: every output enters the lifecycle as `GENERATED → AI_VALIDATED (CI-C5) → TEACHER_VALIDATED → CERTIFIED`; Curriculum-Boundary-validated + metadata-complete at generation time; fingerprint dedup pre-queue; candidates only (I3/I4) — **zero runtime AI** | **CI-C5** + **CI-E1b** (concept read-path live from the B4 seed); soft: CI-C4 (family/tag columns) | EOS PASS; AT-C10; factory output 100% boundary-clean + metadata-complete; nothing certifies below TEACHER_VALIDATED |
| **CI-C11** | **Diagram Intelligence (AIMS A1-10 — Pipeline 5):** diagram requirement detection → diagram specification → programmatic SVG/vector generation (**no raster, no copied artwork — Rule 14**) → AI validation → teacher validation → **Certified Diagram Library** (`edu_diagrams`: concept-linked, versioned, license-tracked, reusable across questions); PDF v2 embeds certified SVGs | **CI-C5** + **CI-B4** (concept IDs); soft: CI-C3 (PDF v2 embed point) | EOS PASS; AT-C11; vector-only + originality gate proven; diagram-absent papers byte-identical (B14) |

## 3. Ordering rationale (why this and not the spec's literal order)

- The spec's literal order (acquire everything → KB → questions → validation → generation) would delay all engine value by months. The certified engine already exists, so **CI-C1 (blueprint templates + solver) is pulled forward** — it is the highest-leverage item, needs only one transcribed template to start, and every later wave (profiles, multi-set, validation) builds on it.
- **CI-C8 has zero dependencies** — ideal parallel work whenever code-lane bandwidth exists. CI-C6 has no *data-lane* dependency but (per D-6) follows **CI-C5** so extracted questions walk the full `RAW → … → CERTIFIED` lifecycle.
- Board-sequential acquisition is kept (spec Part 02 mandate), but knowledge extraction (B-waves) pipelines behind each completed board rather than waiting for all four.
- CI-E1 lands last of the baseline waves but **must land** (v3.0 §5.3: data cannot be backfilled) — it is the handoff line to v3.0 Phase 2.
- **A1 factories sit after the baseline goal lines**, not inside them: CI-C10 needs the validation engine (C5) and a live concept read-path (E1b, per AIMS Rule 2 "never generate isolated questions without Concept mapping"); CI-C11 needs C5 + the B4 concept IDs. Placing them at the Phase-1→2 boundary preserves the approved roadmap, G1/G2 and the red-team position — when they ship, the AI-abuse/isolation playbooks re-run scoped to them (same rule as C5/C6/C7).

## 4. First three actionable steps on approval

1. Owner resolves D-1..D-4 (batched — see [`../audits/GAP_ANALYSIS.md`](../audits/GAP_ANALYSIS.md) §3).
2. Execute **CI-A0** (scaffolding; ~1 day) and start **CI-A1** discovery.
3. In parallel (if code-lane bandwidth approved): hand-transcribe the CBSE Class-10 Science SQP structure and begin **CI-C1** golden-test pinning.
