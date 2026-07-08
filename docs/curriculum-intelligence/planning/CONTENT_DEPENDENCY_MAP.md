# Curriculum Intelligence — Content-Dependency Map (what's runnable NOW vs blocked)

**Date:** 2026-07-08 · **Purpose:** separate the Curriculum lane into work that **depends on
downloaded curriculum content** (network/licence-gated) vs work that is **content-independent**
(buildable now on code / schema / synthetic fixtures), so the lane keeps progressing in parallel
with the ERP lane instead of idling on CI-A1. **Owner directive (2026-07-08):** "Do NOT let the
entire Curriculum lane wait for CI-A1… identify every task that does NOT depend on downloaded
curriculum content… those become runnable immediately."
**Authorities:** [`MODULE_DEPENDENCY_GRAPH.md`](MODULE_DEPENDENCY_GRAPH.md) §3 dependency matrix ·
[`IMPLEMENTATION_SEQUENCE.md`](IMPLEMENTATION_SEQUENCE.md) waves · [`../INTEGRATION_AND_READINESS_REVIEW.md`](../INTEGRATION_AND_READINESS_REVIEW.md) (Option A + P3-AI-1 rule).

> **Key fact:** the production engine (bank-first deterministic solver · syllabus boundary · governance
> · AI gap-fill) is **already live-certified**. The CI **code** waves *extend* it — they operate on
> schema, engine logic, and fixtures, **not** on the downloaded corpus. Only *acquisition* and
> *content population* need real curriculum data.

---

## 1. The split (headline)

| Bucket | Waves / tasks | Gate |
|---|---|---|
| 🟢 **RUNNABLE NOW** (content-independent, deterministic, additive) | **✅ CI-C1** (`31d22f96`) · **✅ CI-C3** (`fab2807f`) · **✅ CI-C7** (`2379a529` — Exam Profile Engine, dormant) · **CI-C8** (exposure/rotation + selection-reason, zero-dep — NEXT) · **CI-C4-schema** (outcome/competency columns + rule-first classifier) · **B12 family schema** (dormant) · **CI-E1b dormant seed** · **all APIs / DB models / tests / docs**. Option A **superseded** (owner 2026-07-08). |
| 🟡 **RUNNABLE-but-GATED on a NON-content dependency** | **CI-C5** (AI Validation Engine) · **CI-C6** (cold-start ingestion assist) · **CI-C10** (Question Factory *engine*) · **CI-C11** (Diagram Intelligence) | code is content-light, but each is an **AI surface** → must be born inside **P3-AI-1** governed runtime (integration review); C10/C11 also need **concepts** (CI-B4 = content) |
| 🔴 **BLOCKED on downloaded content** (CI-A1 network + licence) | **CI-A1..A6** (acquisition + Repository Certification) · **CI-B1/B2/B4** (knowledge *datasets*) · **CI-B3** (needs a CBSE specimen — *owner can unblock with one doc*) · **CI-C2 data-expansion** · **CI-C4 real tagging** · **CI-C6 real ingestion** · **CI-C9** (continuous sync) | network + licence review (Risk R1), or owner-provided source docs |

**Bottom line:** the entire **deterministic engine + schema + family infrastructure + APIs + tests +
docs** is runnable now. Only **content acquisition + content population + the AI-governance-gated
waves** wait. The lane is **not** blocked by CI-A1.

---

## 2. Dependency review against the owner's 12 categories

| # | Category | Verdict | Evidence / what runs now vs waits |
|---|---|---|---|
| 1 | **Content-acquisition** | 🔴 **Blocked** | CI-A1..A6 = downloading + certifying real curriculum → network + licence (R1). `downloader.py` guarded behind `--allow-network` (default false). **Only this bucket is truly network-gated.** |
| 2 | **Architecture** | 🟢 **Mostly done / runnable** | D-1..D-6 resolved; A1 merged; A2 approved (pending ratification); P1-CI-0 seams landed. Remaining architecture (A2 detailed design, module boundaries for C1/C7/C10) = content-independent. |
| 3 | **Engine development** | 🟢 **Runnable** | **CI-C1** (template-aware solver upgrade: slot groups, choice pools, chapter/cognitive quotas as hard constraints, remove 100-cap) + **CI-C3** (multi-set/export). Deterministic; no content; golden-pin-first (solver already pinned in P1-CI-0). "Template absent ⇒ legacy behaviour" (B1). |
| 4 | **Repository platform** | 🟢 code done / 🔴 data blocked | Verification & recovery engine (V1–V11) already implemented + tested; `curriculum/` workspace scaffolded (CI-A0 ✅). The repository **contents** need acquisition (blocked). Platform code = runnable/complete. |
| 5 | **Question-generation engine** | 🟢 deterministic runnable / 🟡 factory gated | Deterministic assembly (CI-C1/C3) + **A2 deterministic instantiation from certified families** = runnable once C1 + family schema exist. The **CI-C10 factory** (AI-authored families) is gated on CI-C5 + concepts + P3-AI-1. |
| 6 | **Validation / solver engine** | 🟢 solver / 🟡 AI-validation gated | The deterministic **solver** (CI-C1) is runnable. The **AI Validation Engine (CI-C5)** is content-light but an AI surface → P3-AI-1 first. |
| 7 | **Question Family infrastructure** | 🟢 **schema runnable** | The **B12 tables** (`edu_question_templates` Item Models, `edu_question_families`, `edu_distractors`) are greenfield → seed as **dormant additive schema now**. Generation *from* families needs C1 (deterministic) or C5/P3-AI-1 (AI-authored). |
| 8 | **Assessment Intelligence** | 🟢 profiles runnable / Phase-2 analytics | **CI-C7 Exam Profile Engine** (profile config, selection weighting, compatibility validation, tier gating) = deterministic, config-driven, runnable. Response-spine analytics = v3.0 Phase 2 (E1a seed already dormant). |
| 9 | **APIs** | 🟢 **Runnable** | New endpoints (templates, families, profiles, multi-set, exposure) = code + DB-free route-contract tests (established pattern). No content. |
| 10 | **Database models** | 🟢 **Runnable** | All greenfield/additive migrations: `edu_blueprint_templates`, B12 family tables, CI-C8 exposure/rotation columns + selection-reason, CI-E1b dormant canonical-concept tables. Additive-only (invariant I7 RLS shape). |
| 11 | **Testing** | 🟢 **Runnable** | Golden tests (solver pinned), template-compliance, export goldens, route-contract, unit, AT-C1/C3/C7/C8, eval-harness v0 (golden question-set fixture). All on synthetic fixtures. |
| 12 | **Documentation** | 🟢 **Runnable** | API contracts, spec refinement, acceptance-test plans, per-wave docs. |

---

## 3. Wave-by-wave content-dependency (from the frozen dependency matrix §3)

| Wave | Hard dep | Needs downloaded content? | Verdict |
|---|---|---|---|
| **CI-C8** | **none** | **No** | 🟢 **Runnable now** — additive exposure/rotation columns + selection-reason logging (`edu_exam_paper_links` already landed in P1-CI-0). **Zero-dependency ⇒ ideal first parallel wave.** |
| **CI-C1** | CI-B3 *subset* | **No** (representative/synthetic template suffices for the engine; certified CBSE template = later data) | 🟢 **Runnable now** — schema + solver upgrade + golden tests. Keystone (unblocks C3/C4/C5/C7). |
| **CI-C3** | CI-C1 | No | 🟢 Runnable after CI-C1 — multi-set + PDF v2 + JSON on XCT-1. |
| **CI-C7** | CI-C1 | No | 🟢 Runnable after CI-C1 — profile engine + gating. |
| **CI-C4** | CI-B2 + CI-C1 | **Schema: No · real tagging: Yes** | 🟢 schema + rule-first classifier now; 🔴 real outcome tagging waits on CI-B2 (content). |
| **CI-C5** | CI-C1 | No (but AI surface) | 🟡 gated on **P3-AI-1** (governed AI runtime) per integration review. |
| **CI-C6** | CI-C5 | **Engine: No · real ingestion: Yes** | 🟡 engine on synthetic scans + P3-AI-1; 🔴 real school-paper ingestion = content. |
| **CI-C9** | CI-A6 + CI-C2 | **Yes** | 🔴 needs certified repository. |
| **CI-C10** | CI-C5 + CI-E1b | **Schema: No · engine: needs concepts** | 🟢 B12 schema now; 🟡 factory engine needs C5 + concepts (CI-B4) + P3-AI-1. |
| **CI-C11** | CI-C5 + CI-B4 | **Yes** (concept IDs) | 🟡/🔴 needs concepts (content) + C5. |
| **CI-E1b** | CI-C8 + CI-B4 | **Schema: No · population: Yes** | 🟢 dormant schema seed now (like E1a); 🔴 concept population = content. |
| CI-B1/B2/B4 | first board / CI-A6 | **Yes** | 🔴 knowledge datasets from real content. |
| CI-B3 | CBSE specimen | **A single source doc** | 🟠 owner-unblockable by providing one CBSE SQP; or synthetic for engine build. |
| CI-A1..A6 | acquisition | **Yes** | 🔴 network + licence. |

---

## 4. Two decisions this surfaces (owner)

1. **Option A reversal (sequencing).** The frozen integration review (Option A) scheduled the CI
   engine waves **post-pilot**. Running CI-C8/C1/C3/C7 **now, pre-pilot**, reverses that. The
   original caution was red-team timing + engine churn before the red team. **Recommendation:**
   **YES for the deterministic, content-free, additive layer** (CI-C8 → CI-C1 → CI-C3/C7 + family
   schema + E1b dormant) — it is invariant-safe (I1–I8), golden-pinned, and de-risks the eventual
   generation platform; the red team simply tests the newer engine. **HOLD the AI-using waves**
   (CI-C5/C6/C10-engine/C11) until **P3-AI-1** lands, per the integration review's explicit rule
   that CI's new AI surfaces are born inside the governed AI runtime.
2. **CI-B3 specimen (optional unblock).** Providing **one CBSE class-10 SQP source doc** lets CI-C1
   be built against a *real* template (and seeds CI-B3) without full network acquisition. Otherwise
   CI-C1 builds on a representative synthetic template and the certified CBSE template is populated
   later. **No blocker either way** — the engine is content-independent.

**Discipline for any CI code wave:** golden-pin-first (solver golden must update on any solver
edit); additive-only migrations; `template/family absent ⇒ legacy behaviour`; invariants I1–I8
intact; every wave one EOS-gated commit.

---

## 5. Parallel execution structure (file-ownership)

Trees are **disjoint** → true two-lane parallelism:

| Lane | Owns (files/dirs) | Current/next wave |
|---|---|---|
| **ERP** (primary agent) | `lib/theme/**`, `lib/**` (app features), `test/**` (app), goldens | **P2-UX-5** (dark-theme toggle) |
| **Curriculum** (primary agent) | `supabase/functions/_shared/education/**`, `supabase/migrations/**`, `lib/features/education/**`, `curriculum/` | **CI-C8 → CI-C1 → CI-C3 ∥ CI-C7** |
| **Shared docs** (ONE owner = orchestrator) | roadmap pointers, dashboard, journal, ledger, this map, proposals register | updated at each wave boundary only |

**Within the Curriculum lane** the engine waves are largely sequential by data-dependency:
**CI-C8** (zero-dep, additive) can run first or alongside; **CI-C1** is the keystone; then **CI-C3**
(export) ∥ **CI-C7** (profile module) are file-disjoint and parallel-eligible; the **B12 family
schema** + **E1b dormant seed** are additive migrations that can piggyback. Never two implementation
agents in `education/**` at once (standing rule) — so within-lane engine waves serialize on the
solver/assembly; cross-lane ERP∥Curriculum is fully parallel.

---

---

## 6. 🔒 LOCKED infra decision (owner, 2026-07-08, refined same day) — curriculum data stays LOCAL

- **Raw PDFs → local only + gitignored** (under `curriculum/`).
- **Derived / AI-generated knowledge (parsed blueprint JSONs, catalogue, metadata, indexes, license
  report) → LOCAL repository only; do NOT commit to Git yet.** Repository-scale knowledge-commit
  decision comes LATER.
- **Git commit ONLY: schemas · engine · manifests · tests · code.** A *manifest* = a small sha256 +
  source-URL + verification-status provenance record (committable); the bulk parsed knowledge is not.
- **Do NOT import parsed curriculum data into the VPS or production database yet. Do NOT create VPS
  storage dependencies for curriculum data. Do NOT implement production curriculum import yet.**
  **VPS = application server ONLY.** Deploy/import happens later when the final production infra is ready.
- **Consequence for CI-C1 + every curriculum engine wave:** COMMIT = SCHEMA (additive, **dormant**
  migrations) + ENGINE code + a **hand-authored GENERIC representative blueprint test fixture**
  (test code) + tests + a provenance manifest. The **AI-extracted CBSE blueprint dataset stays
  local-only** (validation/reference), NOT committed. **Do NOT seed the production DB** with
  curriculum data and **do NOT wire a production import path.** Matches the additive-only /
  template-absent⇒legacy doctrine.

---

*Content-dependency map · 2026-07-08 · classifies existing frozen waves by content-dependency; does
NOT change wave IDs or invariants. The Option-A reversal (running the deterministic layer pre-pilot)
is an owner decision resolved in §4; the local-storage lock is §6.*
