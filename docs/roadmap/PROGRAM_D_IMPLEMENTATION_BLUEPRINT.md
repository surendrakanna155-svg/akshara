# PROGRAM D — Implementation Blueprint (planning only)
## Certified Knowledge Bank Integration & Retrieval Engine

**Date:** 2026-07-22 · **Status:** 📐 **Implementation planning — documentation only.** No code, no migration, no
schema change, no live API call, no frozen-program change. · **Predecessors:** readiness report
`docs/roadmap/PROGRAM_D_ENGINEERING_READINESS_REPORT.md`; spec §5.7; contract R5-3 (D1–D6).

**Locked decisions (owner, 2026-07-22) this plan is built to honor:**
1. Program D is **integration/wiring**, not greenfield.
2. The **existing ERP deterministic blueprint engine** (`education_blueprint_solver.ts`) remains the **request-time
   execution engine** — authoritative and behaviourally unchanged.
3. The **Certified Knowledge Bank** becomes the long-term **source of truth**.
4. **AI is offline-only** — factory / expansion / certification. Never the request path.
5. **No request-path live-AI generation** shall ever be introduced because the bank is temporarily empty.
6. The **empty certified bank is the primary operational blocker**, not engineering.

Deliverables in this document: §1 Implementation Blueprint · §2 Milestone Breakdown · §3 File Impact Matrix ·
§4 Test Strategy · §5 Migration Strategy · §6 Rollback Strategy · §7 Cut-over Strategy · §8 Architecture
Consistency Report · §9 Final GO/NO-GO.

---

## 1. Implementation Blueprint (backlog + dependency ordering)

**Boundary model (the load-bearing design).** QIE is offline Python/SQLite; the ERP is Supabase/Postgres+RLS.
They are bridged by a **versioned, freeze-pinned export artifact**, never a direct cross-process DB write:

```
 [OFFLINE / AI-allowed]                         [ONLINE / deterministic, AI-free request path]
 qpl_question_bank.db (certified/certified)     edu_platform_question_bank  ─┐
   │  QIE exporter (deterministic, read-only)      ▲  ERP platform importer   │  union view
   │  → export artifact (JSON manifest + rows,      │  (edge fn, service role)  │ (adopted ∪ own)
   │    content-hash ids, freeze fingerprints)  ────┘  idempotent, recall=tomb  │      │
   └── offline embeddings for near-dup ─────────► near_dup vectors (precomputed)│      ▼
                                                                    education_blueprint_solver.ts (UNCHANGED)
                                                                       ▲ input pool = certified/adopted ∪ own
                                                                       │ exposure prefer-unseen · det. ranking
                                                            Teacher request (deterministic, ≈0% live-AI)
```

**Dependency-ordered backlog (epics → the milestones of §2):**

| Order | Epic | Milestones | Gate |
|---|---|---|---|
| 1 | **Fixtures & vocabulary** (buildable now) | M0.1 fixture harness · M0.2 KC_↔UUID map | none (fixtures) / owner (map migration) |
| 2 | **Promotion pipeline** (R5-3 D1–D5) | M1.1 platform schema · M1.2 exporter · M1.3 importer · M1.4 adoption/union | owner (migrations) |
| 3 | **Metadata** | M2.1 difficulty calibration · M2.2 Bloom/marks map · M2.3 measured difficulty | pilot signal (M2.3) |
| 4 | **QRE feed** | M3.1 certified pool into solver · M3.2 ai-gap-fill telemetry · M3.3 gap-fill policy flag | owner (M3.3 policy) |
| 5 | **Exposure / near-dup / ranking** | M4.1 exposure write · M4.2 prefer-unseen read · M4.3 semantic near-dup (offline) · M4.4 ranking | none (fixtures) |
| 6 | **ERP integration & acceptance** | M5.1 UI wiring · M5.2 acceptance · M5.3 cut-over | **non-empty certified bank** |

**Everything in orders 1–5 is buildable and fully testable against fixtures BEFORE a non-empty bank exists.**
Only order 6 (M5.2/M5.3 operational acceptance) is data-gated.

---

## 2. Milestone Breakdown (independently shippable; each with DoD + rollback)

Each milestone is **additive, dormant-first, feature-flagged, independently shippable, and EOS-gated.** "DoD" =
Definition of Done. Every milestone's DoD includes, in addition to its specifics: *additive-only; existing golden
solver tests unchanged & green; RLS/tenant-isolation tests green; rollback rehearsed; docs updated; EOS gate PASS;
no request-path AI introduced.*

### Order 1 — Fixtures & vocabulary

**M0.1 — Fixture harness (test-only; no prod path).**
- **Objective:** a deterministic synthetic **certified-bank generator** (emits N rows in the `qpl_question_bank`
  certified shape — STRUCTURED_NUMERIC, structure/solution/distractors/provenance, `certified/certified`) + an
  **ERP test-tenant seeder** (isolated tenant, cf. `akshara_tenant_test`) so the entire pipeline is testable with
  no real certified content.
- **Deps:** none. **Files:** new `curriculum/scripts/intelligence/kie/qie/export/fixtures.py` (Python, test);
  new `supabase/functions/_shared/education/__tests__/fixtures/` seed data + a test-tenant seeder script.
- **Interfaces:** `make_certified_fixture(n, seed) -> rows`; `seed_platform_bank(tenant, rows)`.
- **Tests:** fixture determinism (same seed → same rows); shape conformance to the certified schema.
- **DoD:** any later milestone can run end-to-end on fixtures; fixtures are clearly test-only and never reachable
  from a prod code path.
- **Rollback:** delete test artifacts (no prod surface touched).

**M0.2 — KC_↔UUID vocabulary map (R5-3 D2).**
- **Objective:** the bridge table `edu_concept_vocabulary(kc_id TEXT UNIQUE, concept_uuid UUID, subject,
  canonical_name, frozen_version)` seeded from R5-2 `concept_namespace` + `canonical_concepts`.
- **Deps:** M0.1. **Owner-gated migration.** **Files:** new migration `20260877000000_edu_concept_vocabulary.sql`
  (dormant); seed job (offline, deterministic).
- **Interfaces:** `resolve_kc(kc_id) -> uuid | None` (honest-null on unmapped — never a guess).
- **Tests:** round-trip KC_↔UUID; honest-null on unmapped; freeze-fingerprint pin; 0 guessed UUIDs.
- **DoD:** every certified KC_ concept resolves to exactly one UUID **or** is explicitly unmapped; coverage
  measured, not forced.
- **Rollback:** drop table (nothing reads it yet).

### Order 2 — Promotion pipeline (R5-3 D1/D3/D4/D5)

**M1.1 — Platform bank schema + RLS (owner-gated migration).**
- **Objective:** `edu_platform_question_bank` (platform-owned; `organization_id/school_id` nullable/sentinel) +
  `edu_school_adopted_items(school_id, platform_item_id)` + RLS **reusing the existing `_platform_read` catalogue
  pattern** (all-tenant read, platform-service-role write) as on `edu_question_templates`/`canonical_concepts`.
  Extend `question_type` CHECK to include `numerical` (a widening, never a weakening).
- **Deps:** M0.2. **Files:** migration `20260878000000_edu_platform_question_bank.sql`.
- **Tests:** RLS "school cannot write platform rows"; "every tenant can read platform rows"; adopted-items scope;
  CHECK accepts `numerical`; a school's own bank untouched.
- **DoD:** platform bank exists, all-tenant-readable, platform-write-only; migration validation (§5) green.
- **Rollback:** down-migration drops the new tables + reverts the CHECK extension (safe — nothing populated/read).

**M1.2 — QIE exporter (offline, deterministic, read-only on the certified bank).**
- **Objective:** read `corpus.certified_bank()` (`certified/certified` only) → a **versioned export artifact**:
  per-item content-hash id (D5 = QIE `item_hash`), enum map (`moderate→medium`), KC→UUID stamp (M0.2; unmapped =
  not exported, honest-null), and a **manifest pinning the freeze fingerprints** (`content_fp`/`substrate_fp`/
  `frozen_version`, D4).
- **Deps:** M0.2. **Files:** new `curriculum/scripts/intelligence/kie/qie/export/erp_promote.py`,
  `qie/export/manifest.py`; test `kie/tests/test_erp_promote.py`.
- **Interfaces:** `export_certified(bank_conn, out_dir) -> manifest`; **never writes the certified bank.**
- **Tests:** only `certified/certified` exported (seed provisional/quarantined/expired → 0 exported); idempotent
  (same bank → byte-identical artifact); content-hash stable; unmapped-KC excluded; frozen substrate byte-identical
  after export (read-only proof).
- **DoD:** a fixture certified bank yields a deterministic, freeze-pinned artifact carrying only certified items.
- **Rollback:** delete the artifact (offline; no prod state).

**M1.3 — ERP platform importer (edge function, service role).**
- **Objective:** ingest the export artifact into `edu_platform_question_bank`; **idempotent by content-hash**;
  a recalled/absent item is **tombstoned** (append-only status), never hard-deleted.
- **Deps:** M1.1, M1.2. **Files:** new `supabase/functions/_shared/education/education_platform_import.ts` +
  an admin/owner-gated invoke path; tests `education_platform_import_test.ts`.
- **Interfaces:** `importPlatformBatch(manifest, rows)` → {inserted, updated, tombstoned, skipped}.
- **Tests:** re-import = no-op (idempotent); recall→tombstone propagation; manifest-fingerprint mismatch **refuses**
  fail-closed; malformed row rejected (never partial-write); tenant-isolation preserved.
- **DoD:** the fixture artifact lands once, re-import is a no-op, a recall tombstones — all owner-gated invoke.
- **Rollback:** truncate `edu_platform_question_bank` (platform-only data; no school data touched) + disable the
  invoke path.

**M1.4 — Adoption + union read model.**
- **Objective:** a school reads the **union (adopted platform items ∪ own items)** through ONE RLS-safe view;
  adoption is **by reference** (never a row copy), so recall/re-cert at the platform propagates.
- **Deps:** M1.1. **Files:** migration `20260879000000_edu_bank_union_view.sql` (view + RLS); repo read helper in
  `education_repository.ts` (additive query).
- **Tests:** union returns adopted ∪ own; a non-adopted platform item is invisible to a school; recall removes an
  adopted item from the union; RLS isolation across two tenants.
- **DoD:** a school surface can read a certified item only via adoption; isolation intact.
- **Rollback:** drop the view; repo helper falls back to own-bank query (current behavior).

### Order 3 — Metadata completion

**M2.1 — Difficulty calibration separation (predicted vs measured; never blend).**
- **Objective:** `difficulty_calibration` on the platform bank (`predicted_uncalibrated | measured_pilot`); the ERP
  `difficulty {easy,medium,hard}` stays; predicted is never sold as measured (R2-5).
- **Deps:** M1.1. **Files:** column in the M1.1 migration; exporter stamps it (M1.2).
- **Tests:** predicted↔measured never conflated; a predicted item is labelled predicted end-to-end.
- **DoD:** every promoted item carries an explicit calibration label. **Rollback:** column drop (additive).

**M2.2 — Bloom + marks mapping at export.**
- **Objective:** map QIE metadata → ERP `cognitive_level` (Bloom axis) + `marks`; link `concept_uuid`.
- **Deps:** M1.2, M0.2. **Files:** exporter mapping; no new schema (columns exist).
- **Tests:** Bloom/marks/concept present on every exported item **or** honest-null; no fabricated Bloom.
- **DoD:** promoted items carry Bloom+marks+concept UUID or an explicit null. **Rollback:** n/a (data-only).

**M2.3 — Measured difficulty from the response spine (PILOT-GATED).**
- **Objective:** compute measured difficulty (p-value) from `edu_student_item_responses`; **honest-null until
  real pilot signal exists** (not backfillable).
- **Deps:** M1.4; a populated response spine (pilot). **Files:** an offline/edge item-analysis job (additive).
- **Tests:** measured only from real responses; 0 signal → null (never proxy sold as measured); recompute is
  deterministic.
- **DoD:** measured difficulty appears **only** where pilot responses exist. **Rollback:** disable the job.

### Order 4 — QRE feed (reuse the authoritative solver)

**M3.1 — Certified pool into the existing solver (input change only).**
- **Objective:** extend the paper service's bank source to the **certified/adopted ∪ own** union; the **pure
  `education_blueprint_solver.ts` is not touched** — only its input pool grows.
- **Deps:** M1.4. **Files:** `education_question_paper_service.ts` (`generateQuestionPaper` bank-source query);
  read model via M1.4.
- **Tests:** solver golden tests **unchanged & green**; deterministic (same request→same paper); certified items
  eligible for selection; isolation intact.
- **DoD:** a fixture teacher request fills from certified content deterministically; solver behaviour unchanged.
- **Rollback:** flag reverts the bank source to own-bank-only (exact current production behavior).

**M3.2 — AI-gap-fill telemetry (the "≈0% live-AI" metric).**
- **Objective:** measure and expose the **`ai_candidate` rate per paper** (the existing gap-fill), so "≈0% live-AI
  at request time" is a **measured production gate**, not an assertion.
- **Deps:** M3.1. **Files:** telemetry in `education_question_paper_service.ts`; a dashboard/report field.
- **Tests:** ai_candidate rate computed correctly; alerting threshold; historical trend.
- **DoD:** ai_candidate rate is observable per tenant and trending down as coverage grows.
- **Rollback:** remove telemetry (no behaviour change).

**M3.3 — Request-path gap-fill policy flag (OWNER-DECISION-DEPENDENT — see §8).**
- **Objective:** a per-tenant flag governing the **existing** request-path AI gap-fill: `marked_unpublishable`
  (today's behavior) → `hard_off` (once certified coverage is sufficient). **Program D adds no new AI path; it
  gates the pre-existing one toward off.**
- **Deps:** M3.1, M3.2; **owner ratification of the end-state policy (§8 CONSISTENCY-1).**
- **Files:** a config flag read by `education_question_paper_service.ts` (no solver change).
- **Tests:** `hard_off` → under-fill returns an **honest shortfall** (never a live-AI expansion); `marked_unpub`
  → today's behavior; flag is per-tenant, defaults to current behavior until owner flips it.
- **DoD:** the request-path AI gap-fill is owner-controllable and can be driven to hard-off without weakening the
  deterministic path. **Rollback:** flag default = current behavior.

### Order 5 — Exposure / near-dup / ranking (all fixture-testable)

**M4.1 — Exposure write-path.**
- **Objective:** wire the **dormant** exposure seam — on paper generate/publish, log `edu_item_exposures` and
  increment `times_used`/`last_used_at`.
- **Deps:** M3.1. **Files:** write in `education_question_paper_service.ts` / `education_repository.ts`.
- **Tests:** an exposure row per placed item; counters increment; idempotent on re-publish; isolation.
- **DoD:** exposures are captured for every generated/published paper. **Rollback:** flag off → no writes (dormant
  seam returns to unused; no data loss).

**M4.2 — Exposure read-path (prefer-unseen).**
- **Objective:** feed exposure + `edu_item_rotation_policies` into the solver's **pool ordering** via the existing
  (dormant) `education_item_rotation.ts` helper — prefer unseen items while honoring blueprint constraints.
- **Deps:** M4.1. **Files:** wire `education_item_rotation.ts` into the pool builder feeding the solver.
- **Tests:** two papers to one class share fewer/no repeats; cooldown honored; still deterministic; graceful when
  the pool is thin (honest, not AI).
- **DoD:** selection prefers unseen deterministically. **Rollback:** flag off → canonical order (current behavior).

**M4.3 — Semantic near-duplicate (the one net-new capability — kept OFFLINE + deterministic).**
- **Objective:** prevent paraphrase/semantic clones in one paper. **Embeddings are computed OFFLINE** (at
  promotion/export time, in the AI-allowed factory) and **stored as vectors**; the **request-time check is a
  deterministic nearest-neighbor + fixed, versioned threshold** — no AI at request time, fully explainable
  (the similar pair + score).
- **Deps:** M1.2 (export), M3.1. **Files:** offline embedding step in `qie/export/erp_promote.py`; a
  `near_dup_vectors` store (platform); a deterministic request-time similarity filter in the pool builder.
- **Tests:** deterministic (same inputs → same verdict); a known paraphrase pair is caught; a genuine distinct pair
  is not; threshold is versioned; **no request-time model call** (assert offline-only).
- **DoD:** near-dups are filtered within a paper deterministically and explainably, with the model strictly offline.
- **Rollback:** flag off → exact-fingerprint dedup only (current behavior).

**M4.4 — Deterministic explainable ranking engine.**
- **Objective:** rank certified items for selection over {exposure, calibrated difficulty, rotation, importance}
  — **deterministic + explainable** (a scored trace), reusing the QIE `importance_score` shape where applicable.
- **Deps:** M2.x, M4.1–M4.3. **Files:** a ranking module feeding the solver's pool order (no solver change).
- **Tests:** reproducible ranking; an explainable per-item score trace; tie-break is seeded/stable.
- **DoD:** selection order is deterministic and every choice is explainable. **Rollback:** flag off → prior order.

### Order 6 — ERP integration & acceptance (BANK-GATED)

**M5.1 — Flutter/web wiring (surface certified source; keep manual authoring).**
- **Objective:** the paper-builder UI reflects the certified/adopted source and the ai_candidate rate; manual
  authoring (`education_bank_item_form.dart`, `promotePaperItemToBank`) is untouched and optional.
- **Deps:** M3.1. **Files:** `lib/features/education/education_question_paper_detail_screen.dart`,
  `education_paper_item_edit_sheet.dart`, `education_provider.dart`, `education_models.dart`, web equivalents.
- **Tests:** widget/golden tests; manual authoring still works; certified provenance shown.
- **DoD:** teachers see certified provenance; manual path intact. **Rollback:** UI flag off → current screens.

**M5.2 — End-to-end operational acceptance (requires a NON-EMPTY certified bank).**
- **Objective:** a real teacher request served from real certified content; ai_candidate rate measured ≈0 as
  coverage grows; EOS FEATURE+AI PASS.
- **Deps:** ALL prior; **a non-empty certified bank (the blocker).**
- **Tests:** end-to-end on the pilot tenant; ai_candidate rate reported; multi-tenant isolation; performance (§4).
- **DoD:** ERP serves certified papers deterministically; measured live-AI request-path rate published; EOS PASS.
- **Rollback:** cut-back (§7) → school-bank-only.

**M5.3 — Production cut-over + cut-back.** See §7.

---

## 3. File Impact Matrix

**Legend:** NEW · EXTEND (additive) · WIRE (activate dormant) · UNCHANGED (must stay green) · MIGRATION (owner-gated).

| Area | Path | Change | Milestone |
|---|---|---|---|
| QIE exporter | `curriculum/.../kie/qie/export/erp_promote.py`, `manifest.py`, `fixtures.py` | NEW (offline) | M0.1,M1.2,M4.3 |
| QIE exporter test | `curriculum/.../kie/tests/test_erp_promote.py` | NEW | M1.2 |
| QIE certified bank | `curriculum/.../kie/qie/factory/corpus.py` (`certified_bank`) | UNCHANGED (read-only consumer) | — |
| ERP migration — vocab | `supabase/migrations/20260877000000_edu_concept_vocabulary.sql` | MIGRATION (dormant) | M0.2 |
| ERP migration — platform bank | `20260878000000_edu_platform_question_bank.sql` (+ CHECK extend `numerical`, `difficulty_calibration`) | MIGRATION | M1.1,M2.1 |
| ERP migration — union view | `20260879000000_edu_bank_union_view.sql` | MIGRATION | M1.4 |
| ERP importer | `supabase/functions/_shared/education/education_platform_import.ts` (+ test) | NEW (edge, service role) | M1.3 |
| ERP paper service | `.../education/education_question_paper_service.ts` (`generateQuestionPaper` pool source; telemetry; gap-fill flag) | EXTEND | M3.1,M3.2,M3.3,M4.1 |
| ERP solver | `.../education/education_blueprint_solver.ts` (+ golden test) | **UNCHANGED** (authoritative) | — |
| ERP rotation | `.../education/education_item_rotation.ts` | WIRE (dormant→active) | M4.2 |
| ERP near-dup | `.../education/education_near_dup.ts` + `near_dup_vectors` read | NEW (det. request-time) | M4.3 |
| ERP ranking | `.../education/education_certified_ranking.ts` | NEW | M4.4 |
| ERP repository | `.../education/education_repository.ts` (union read; exposure write; manual path) | EXTEND | M1.4,M4.1 |
| ERP fingerprint | `.../education/education_fingerprint.ts` | UNCHANGED | — |
| Flutter UI | `lib/features/education/education_question_paper_detail_screen.dart`, `education_paper_item_edit_sheet.dart`, `education_provider.dart`, `education_models.dart` | EXTEND | M5.1 |
| Web UI | `web/` education paper builder equivalents | EXTEND | M5.1 |
| Docs | this blueprint; per-milestone cert reports; R5-3 status update | DOC | all |

**Explicitly UNCHANGED / frozen (must not be touched):** `education_blueprint_solver.ts` (+ its golden tests);
Program B (`feature/program-b-pyq-remining`); the frozen KIE index (v1.4/v1.5); the QIE certified store schema
(read-only); `qie/execution/recert.py` (Program C, replay-certified).

---

## 4. Test Strategy

**Fixture strategy (enables full build+test BEFORE a non-empty bank — a first-class deliverable):**
- **Certified-bank fixture** (M0.1): deterministic synthetic `certified/certified` rows in the QIE shape; drives
  the exporter → importer → union → solver end-to-end with zero real certified content.
- **Isolated ERP test tenant** (cf. `akshara_tenant_test`): all promotion/QRE/exposure tests run in a throwaway
  tenant; prod tenants untouched; teardown scripted.
- **Golden artifacts:** exporter manifest golden; solver golden (unchanged); QRE selection-trace golden; near-dup
  verdict golden. All seeded/deterministic.
- Fixtures are **test-only** and unreachable from any prod code path (asserted).

**Integration tests (end-to-end on fixtures):**
1. Exporter → importer → `edu_platform_question_bank` → adoption → union → `generateQuestionPaper` → deterministic
   certified paper. 2. Recall at source → re-export → importer tombstone → item drops from a school's union.
3. Two tenants: tenant A's adoption/exposure invisible to tenant B (isolation). 4. Manual authoring still writes
   the own-bank and appears in the union alongside adopted items.

**Performance / load tests:**
- Import throughput at target bank scale (e.g., 10²–10⁶ certified items): batch import time, idempotent re-import.
- QRE selection latency at scale (union pool 10⁴–10⁶): p50/p95 for a typical blueprint; **request path stays
  deterministic and AI-free** under load. Near-dup nearest-neighbor lookup latency (precomputed vectors).
- Exposure write amplification on high-volume paper generation.
- Acceptance thresholds set with the ERP lane; regressions fail the gate.

**Failure-mode tests (fail-closed):**
- Manifest fingerprint mismatch → importer refuses. · Unmapped KC_ → not exported (honest-null). · Malformed
  export row → rejected, no partial write. · Empty/thin bank → honest shortfall, **never** a request-path live-AI
  expansion (assert `hard_off` yields shortfall). · Provisional/quarantined/expired seeded at source → **0
  promoted**. · Service-role import invoked without authorization → refused. · Near-dup model unavailable at
  request time → **request path does not call it** (offline-only; deterministic filter degrades to fingerprint,
  never to a live model).

**Migration validation tests (§5):** schema-diff vs expected; RLS policy assertions (platform-write/all-read;
adopted scope; tenant isolation); CHECK accepts `numerical` + rejects junk; idempotent re-run; **down-migration
restores the prior schema**; dormant migration changes **zero** production behavior (golden solver + paper tests
identical before/after).

**Determinism / replay tests:** same request + same bank → byte-identical paper; same certified bank → identical
export artifact; near-dup + ranking reproducible; seeds fixed.

---

## 5. Migration Strategy

- **Additive, dormant-first, expand→migrate→contract.** Every migration CREATES new objects or WIDENS a CHECK;
  no column is dropped/narrowed on a live table. New tables ship **dormant** (no reader/writer) and are WIRED in a
  later, separately-shippable milestone behind a flag.
- **Band & numbering:** ERP band, monotonic; start at **`20260877000000`** (current head `20260876000000`),
  sequential thereafter; **owned and sequenced by the ERP lane**; must avoid the ASIP `2026092x` band. No
  interleave below the head.
- **RLS:** `ENABLE` + `FORCE` on every new table; platform rows use the established `_platform_read` catalogue
  policy (all-tenant read, platform-service-role write); adopted-items school-scoped.
- **Reversibility:** every migration ships a tested **down** path. Because objects are additive + dormant, a
  down-migration is safe (nothing depends until a wiring milestone flips a flag).
- **Data migrations** (import, measured-difficulty) are **idempotent** (content-hash / natural keys) and re-runnable.
- **Owner gate:** no migration is applied without explicit owner authorization; each is validated (§4) in the test
  tenant first.

---

## 6. Rollback Strategy (per milestone)

**Principle:** every milestone is **flag-gated** and **additive**, so rollback is *flip the flag off* (instant,
lossless — reverts to exact current production behavior) and, where a schema object was added, *run the tested
down-migration* (safe because additive/dormant). No milestone mutates school data or the frozen certified bank, so
no rollback can lose customer data.

| Milestone | Rollback |
|---|---|
| M0.1/M0.2 | drop fixtures / drop `edu_concept_vocabulary` (unread) |
| M1.1 | down-migration drops platform bank + reverts CHECK widen (unpopulated) |
| M1.2 | delete offline artifact (no prod state) |
| M1.3 | truncate `edu_platform_question_bank` (platform-only) + disable invoke |
| M1.4 | drop union view; repo helper → own-bank query (current) |
| M2.x | drop calibration column / stop item-analysis job (data-only) |
| M3.1 | flag → own-bank pool (exact current behavior) |
| M3.2 | remove telemetry (no behavior change) |
| M3.3 | flag default = current gap-fill behavior |
| M4.1–M4.4 | flag off → exposure unused / canonical order / fingerprint-only dedup / prior ranking |
| M5.1 | UI flag off → current screens |
| M5.2/M5.3 | cut-back (§7) |

---

## 7. Cut-over & Cut-back Strategy

**Cut-over (staged, reversible, coverage-driven):**
1. **Deploy dormant schema** (M0.2/M1.1/M1.4 migrations) — **zero behavior change** (validated: golden tests
   identical before/after).
2. **Populate the platform bank** (M1.2 exporter → M1.3 importer) — data present, **not yet read** by any request
   path.
3. **Canary read** — enable the certified/adopted union pool (M3.1) for **one pilot tenant** behind a flag; measure
   the `ai_candidate` rate (M3.2) and paper quality.
4. **Progressive rollout** — expand tenant-by-tenant as certified coverage grows and the ai_candidate rate falls;
   enable exposure/near-dup/ranking (M4.x) per tenant.
5. **Steady state** — once coverage is sufficient per subject/grade, flip the gap-fill policy (M3.3) toward
   `hard_off` **per tenant, owner-approved**; publish the measured live-AI request-path rate (target ≈0%).

**Cut-back (instant, lossless):** flip the per-tenant flag(s) **off** → `generateQuestionPaper` reverts to the
**school-authored bank only** (today's exact production behavior). No school data touched; the platform bank simply
goes unread. If needed, run the additive down-migrations. Cut-back is a config change, not a redeploy.

**Gate:** no tenant is cut over until (a) the certified bank is non-empty **for that tenant's subjects/grades** and
(b) the ai_candidate rate under the certified pool is at/below the owner-ratified threshold.

---

## 8. Architecture Consistency Report

Each locked decision checked against **every proposed milestone**. **Result: no proposed implementation violates a
locked decision.** One pre-existing tension is flagged as an owner decision (not a violation of any proposal).

| Locked decision | Preserved by the plan? | Mechanism |
|---|---|---|
| **Knowledge-Bank-First** | ✅ | QRE feeds the solver from the certified/adopted bank; AI is not on the request path (M3.1). |
| **Deterministic request path** | ✅ | The pure solver is UNCHANGED; only its input pool grows; near-dup/ranking/exposure are all deterministic at request time. |
| **Offline AI only** | ✅ | Embeddings for near-dup are computed **offline** at export (M4.3); request-time is a deterministic NN lookup; no request-time model call (asserted). |
| **Generator ≠ Judge** | ✅ | Program D never generates or judges; it **consumes** already-certified output. Untouched. |
| **Append-only certification** | ✅ | The exporter is **read-only** on the certified bank; the platform bank is populated additively; recall = **tombstone** (append-only status), never a mutation of certified evidence. |
| **Fail-closed** | ✅ | Unmapped-KC not exported; fingerprint mismatch refuses; only `certified/certified` promoted; under-fill → honest shortfall (M3.3 `hard_off`), never a silent expansion. |
| **Replay determinism** | ✅ | Deterministic exporter (content-hash, byte-identical artifact); deterministic QRE/near-dup/ranking; fixtures reproducible. |
| **No weakening of certification gates** | ✅ | Program D adds **no** certification path; promotion reads only fully-certified rows; the `numerical` CHECK is **widened at the ERP boundary**, never a QIE gate weakened. |
| **No runtime dependency on AI** | ✅ (with CONSISTENCY-1 below) | The request path added by Program D is deterministic; the **pre-existing** ERP gap-fill is measured (M3.2) and gated toward off (M3.3). |
| **Multi-school isolation** | ✅ | Platform rows are all-tenant **read**, platform-service-role **write**; adoption-by-reference; union view is RLS-scoped; isolation tests per milestone. |
| **Existing ERP deterministic paper generator remains authoritative** | ✅ | `education_blueprint_solver.ts` is UNCHANGED; its golden tests must stay green; Program D only changes the **input pool** feeding it. |

**★ CONSISTENCY-1 (flagged owner decision — NOT a blocking conflict).** The ERP paper generator **already** sends
unfillable blueprint slots to a **constrained request-path AI gap-fill** today (`education_question_paper_service.ts`
→ `source='ai_candidate'`, `review_status='pending'`, **cannot publish**). This is **pre-existing** behavior;
Program D does not introduce it, measures it (M3.2), and gates it toward `hard_off` (M3.3). It sits in mild tension
with "deterministic request path / no runtime AI dependency," reconciled because AI candidates are unpublishable and
clearly marked and the plan drives the rate to ≈0. **Owner decision needed:** the end-state policy — keep the
marked-unpublishable fallback, or hard-off once coverage is sufficient (per tenant/subject). The plan supports
either via M3.3; it does **not** decide it. *(Per the directive, this is surfaced rather than silently implemented;
it is not a conflict caused by a proposed implementation, so planning continues.)*

**No other conflict found.** No proposed milestone weakens a gate, adds a new request-path AI dependency, mutates
certified evidence, breaks isolation, or alters the authoritative solver.

---

## 9. Final GO / NO-GO — implementation readiness

- 🟢 **GO — implement M0–M4 against fixtures** under normal owner sequencing. The plan is additive, flag-gated,
  reversible, and consistent with every locked decision; the authoritative solver is untouched; the whole pipeline
  is fully testable before a non-empty bank via the fixture strategy (§4).
- 🟡 **HOLD (owner-gated, not engineering-gated):**
  1. **Migrations** (M0.2/M1.1/M1.4) — owner authorization + ERP-lane band numbering.
  2. **CONSISTENCY-1 end-state policy** (M3.3) — owner ratifies keep-marked vs hard-off.
  3. **M2.3 measured difficulty** — pilot response signal (not backfillable).
  4. **M5.2/M5.3 operational acceptance & cut-over** — a **non-empty certified bank** (the primary blocker,
     locked decision #6).
- 🔴 **NO-GO** on anything that would weaken a gate, add a new request-path live-AI path, mutate the certified
  bank, or change the authoritative solver — none of which this plan proposes.

**Recommendation:** approve the blueprint as **implementation-ready**; authorize **M0.1 (fixtures)** immediately
(fully additive, no prod path); sequence **M0.2→M1→M4** against fixtures under owner-gated migrations; keep
**M3.3 policy, M2.3, and M5** gated on the owner decision, the pilot signal, and a non-empty bank respectively.

**No code, migration, schema change, live API call, roadmap rewrite, or frozen-program modification was produced by
this planning package.**
