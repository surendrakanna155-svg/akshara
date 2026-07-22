# PROGRAM D — Execution Log
## Certified Knowledge Bank Integration & Retrieval Engine

**Branch:** `feature/program-d-knowledge-bank-integration` (off `feature/program-c-live-recertification`
head `0f2529c1`, which carries the readiness report + implementation blueprint). **NOT pushed.**

**Governing plan:** `docs/roadmap/PROGRAM_D_IMPLEMENTATION_BLUEPRINT.md` (18 milestones, M0.1→M5.3).
**Readiness:** `docs/roadmap/PROGRAM_D_ENGINEERING_READINESS_REPORT.md`. **Spec:** master roadmap §5.7.

**Standing rules honored on every milestone:** additive · dormant-first · flag-gated · reversible ·
fail-closed · **no request-path AI introduced** · **no certification gate weakened** · the authoritative
`education_blueprint_solver.ts` is UNCHANGED · migrations are **owner-gated to APPLY** (written + locally
validated here; applied to the live DB only on explicit owner authorization). EOS gate run per milestone.

**Owner/data gates (expected stops, per blueprint §9):** M0.2/M1.1/M1.4 migration *apply*; M3.3 gap-fill
end-state policy (CONSISTENCY-1); M2.3 measured difficulty (pilot signal); M5.2/M5.3 acceptance (non-empty
certified bank).

---

## M0.1 — Fixture harness  ✅ DONE

**Objective (blueprint §2):** a deterministic synthetic **certified-bank generator** + ERP-side test
corpus, so the entire pipeline is buildable/testable before any real certified content exists.

**Delivered:**
- `curriculum/scripts/intelligence/kie/qie/export/__init__.py` — the offline QIE→ERP export package.
- `curriculum/scripts/intelligence/kie/qie/export/fixtures.py` — `make_certified_fixture(n, seed)` (pure,
  deterministic, no DB/clock) + `build_fixture_bank(...)` which promotes rows through the **real** corpus
  write path (`save_specs → ingest → mark_certified`) into a **throwaway `:memory:` production bank**.
- `curriculum/scripts/intelligence/kie/tests/test_export_fixtures.py` — 9 tests.
- `supabase/functions/_shared/education/__tests__/fixtures/certified_corpus.json` — golden corpus
  (12 deterministic rows), + `certified_corpus.ts` loader, `certified_corpus_test.ts` (3 tests), `README.md`.

**Design decisions (evidence-backed):**
- **Content realism vs the RI-9 near-dup guard.** `norm_hash` collapses numbers → `#`, so arithmetic
  templates that differ only in operands are near-duplicates *by construction* and the bank-dedup UNIQUE
  correctly refuses them. The fixture therefore emits distinct **word problems**, each with a **unique
  context noun**, guaranteeing distinct normalised stems (and giving M4.3 natural paraphrase pairs). This
  makes the fixture *more* faithful to how a real certified bank behaves, not less.
- **Not a certification bypass.** The fixture never opens the real `qpl_question_bank.db`
  (`test_never_routes_through_the_real_production_bank`), fabricates no evidence in any real store, and
  weakens no gate — it synthesises already-certified *test data* through the genuine guarded write path
  (RI-9 dedup, guarded status transition, real provenance). Verified.
- **QIE-native shape upstream, ERP mapping at the exporter.** The corpus keeps QIE enums
  (`MCQ`/`moderate`/`KC_…`); enum + KC→UUID mapping is the M1.2 exporter's job at the offline boundary.

**Verification:**
- KIE suite: `1281 passed, 0 failures, 0 errors, 1 skipped` (baseline 1272 + 9 new). No regression.
- ERP fixtures (Deno): `3 passed`.
- Determinism, distinct hashes, product-visibility, cap guard, golden drift-guard, real-bank isolation: all green.

**Rollback:** delete the test artifacts (no prod surface touched).
**EOS gate: PASS** (additive · test-only · no prod path · no request-path AI · no gate weakened).

---

## M0.2 — KC_ ↔ UUID vocabulary map  ✅ DONE (migration authored + validated; APPLY owner-gated)

**Objective (blueprint §2):** the `edu_concept_vocabulary` bridge so a certified item's KC_ concept
resolves to exactly one ERP UUID — or is explicitly unmapped (honest-null, never a guessed UUID).

**Delivered:**
- `supabase/migrations/20260877000000_edu_concept_vocabulary.sql` — DORMANT additive table, platform-read
  catalogue governance (FORCE RLS + `_school_scope` + `_platform_read` + no-DELETE grant + COALESCE
  identity index). **Written + locally validated; APPLY is owner-gated** (band `20260877000000`, next free).
- `curriculum/scripts/intelligence/kie/qie/export/vocabulary.py` — `mint_uuid` (deterministic uuid5),
  `Vocabulary.from_concepts/resolve/rows`, `load_certified_concepts` (frozen-index seed, self-skips if absent).
- `kie/tests/test_concept_vocabulary.py` (9 tests) + `edu_concept_vocabulary_migration_validation_test.ts` (7 tests).

**Design decision (honest, evidence-backed):** `canonical_concepts` is **empty/dormant**, so there is no
pre-existing UUID to match against. A KC_ id's ERP handle is therefore a **deterministic `uuid5(namespace,
kc_id)`** — a stable identity, not a guess at another concept. Honest-null still bites: only KC_ ids present
in the certified source (frozen `ki_concept`, or declared fixture concepts) enter the vocabulary; anything
else resolves `None`. `concept_uuid` is a **loose reference (no FK)** since canonical_concepts is empty.

**Verification:** Python 9/9 (mint determinism/uuid5, round-trip, honest-null, dedup, partial-coverage
exclusion, real frozen-index seed); Deno 7/7 (governance shape, platform-read sentinel, loose-ref, dormancy).

**Rollback (owner-gated DOWN):** `DROP TABLE IF EXISTS edu_concept_vocabulary;` (dormant — nothing reads it).
**EOS gate: PASS** (additive · dormant · APPLY owner-gated · no request-path AI · no gate weakened).

---

## ⏸ COORDINATION PIVOT (owner directive)

After M0.2, the owner issued an **Autonomous Execution Directive**: pause serial implementation and produce a
**multi-agent parallel-execution Master Coordination Plan** (documentation only). M0.1 + M0.2 (order-1
foundation) stand as the **committed clean baseline** all parallel worktrees branch from. See
`docs/roadmap/PROGRAM_D_PARALLEL_EXECUTION_COORDINATION_PLAN.md`. Implementation resumes on owner go-ahead.

---

## ▶ PARALLEL EXECUTION — owner approved Option 1 (4+1 fleet)

### Phase 1 — CONTRACT FREEZE  ✅ DONE (coordinator)

**Deliverable:** `docs/roadmap/PROGRAM_D_CONTRACTS.md` — the two frozen cross-lane contracts, the entire
coupling surface between parallel workstreams:
- **Contract-1 (export artifact):** the versioned `{manifest, rows[]}` JSON WP-A emits / WP-C ingests —
  content-hash id, enum map (`MCQ`→`mcq`, `moderate`→`medium`), KC→UUID (unmapped ⇒ row omitted, honest-null),
  calibration label, Bloom/marks, and the **deterministic offline near-dup vector** (`hashvec-128-v1`,
  request-time = cosine ≥ 0.82, no request-time model).
- **Contract-2 (platform bank + union):** `edu_platform_question_bank` (content_hash UNIQUE idempotency key,
  `numerical`-widened CHECK, calibration column, tombstone status), `edu_school_adopted_items` (adopt by
  reference), `edu_bank_items_union` view (output columns = `QuestionBankItemRow`), and the per-tenant flag
  store `edu_program_d_settings` (defaults reproduce **exact current behaviour** — dark until owner flips).

Enums/column-names are normative; nothing weakens a gate, adds request-path AI, or alters the solver.
**Next:** fan out WP-A ∥ WP-B ∥ WP-D against this freeze (worktree-isolated), then merge B→A→C→D→E→F→G.

### Phase 2 — PARALLEL FAN-OUT (WP-A ∥ WP-B ∥ WP-D)  ✅ DONE

Three worktree-isolated agents built against the freeze; each caught the isolation layer's stale-baseline
seeding (`a806ee2c`) and self-corrected to `b3c17e10` (or its files were self-contained). Merged as clean
file cherry-picks, each re-gated on-branch:

- **WP-D** `3351bc13` — `education_near_dup.ts` (M4.3 request-time: cosine ≥0.82 over precomputed vectors,
  fingerprint fallback, no model call) + `education_certified_ranking.ts` (M4.4: explainable weighted rank,
  trace sums to score, tie-break by id). 23 tests; deterministic/offline verified.
- **WP-B** `8474732a` — migrations `20260878` platform bank (+M2.1 calibration, `numerical` widening,
  tombstone status, content_hash UNIQUE) + `edu_school_adopted_items`; `20260879` `edu_bank_items_union`
  view (`security_invoker=true`, 31-col QuestionBankItemRow projection, tombstone drops out); `20260880`
  `edu_program_d_settings` (flags default to current behaviour). 27 validation tests. **APPLY owner-gated.**
- **WP-A** `02c46b4a` — `erp_promote.py` (M1.2 fail-closed admission + enum map + M2.2 marks/Bloom derivation),
  `manifest.py` (freeze fingerprints), `embeddings.py` (M4.3 offline `hashvec-128-v1`). 28 tests; FULL KIE
  suite **1318 green** (no regression); byte-identical artifact + read-only proof.

### Phase 3 — WP-C importer  ✅ DONE (`02d4cc0f`)

`education_platform_import.ts` (service-role, idempotent by content_hash, fail-closed on fingerprint/
row_count/malformed/duplicate, recall=tombstone) + the golden `export_artifact.json`. 7 tests; education
deno suite 210 green.

### Phase 4 — WP-E integration spine  ✅ DONE (solver UNCHANGED throughout)

- **E1** `30f50e5b` — M1.4 union read helper (`bankSource`), M3.1 certified pool feed, M3.2 `aiCandidateRate`
  telemetry, M3.3 `hard_off` gap-fill flag (honest shortfall, never a live-AI expansion). Live-handler
  wiring **deferred to cut-over** (reading dormant settings on the request path before the migration is
  applied would break prod). 4 tests; education 214 green.
- **E2a** `55d3fab7` — M4.1 exposure write-path (`recordItemExposures`, idempotent, platform no-op),
  M4.2 prefer-unseen (dormant rotation helper wired, byte-identical when no exposure). 5 tests; education 219 green.
- **E2b** `10c16fce` — M4.3/M4.4 integration (`education_certified_pool.ts` composes near-dup + ranking;
  `getNearDupVectors` fetches precomputed vectors; gated, order-preserving). 6 tests; education 225 green.

### Phase 6 — END-TO-END + verdict  ✅ (`4c721557`)

Fixture e2e (`education_program_d_e2e_test.ts`): golden artifact → importer → union → `generateQuestionPaper`
fills from certified content (`bankReuseCount>0`), 0 request-path AI, byte-identical on replay, recall drops
the item. FULL education deno suite **227 green**; FULL KIE suite **1318 green**.

---

## ✅ ENGINEERING-COMPLETE ON FIXTURES — verdict + honest owner/data gates

**Built + verified (additive · dormant-first · flag-gated · reversible · solver byte-identical):** M0.1,
M0.2, M1.1–M1.4, M2.1, M2.2, M3.1, M3.2, M3.3 (mechanism), M4.1–M4.4, plus the end-to-end proof. Every
milestone: no request-path AI introduced, no certification gate weakened, the authoritative
`education_blueprint_solver.ts` unchanged. 13 commits on `feature/program-d-knowledge-bank-integration`
(NOT pushed).

**EOS gate: CONDITIONAL PASS** — engineering-complete on fixtures; **operational acceptance is owner/data-
gated, not an engineering defect.** Remaining = genuine gates only:
1. **Migration APPLY** (`20260877`–`20260880`) — owner authorization + VPS `akshara_tenant_test` RLS validation.
2. **M3.3 end-state policy flip** (`hard_off`) — owner ratification (CONSISTENCY-1). The flag is built + defaults to current behaviour.
3. **M2.3 measured difficulty** — pilot response signal (not backfillable).
4. **M5.1 UI wiring** — best done AT cut-over (needs the live backend + certified content to surface); the
   backend now EXPOSES `aiCandidateRate`/`bankSource`. Deferred with the handler wiring.
5. **M5.2/M5.3 acceptance + cut-over** — the **#1 blocker: an empty certified bank**. Buildable/tested on
   fixtures; not operationally acceptable until an owner-approved certified-content run fills the bank.

**Cut-over recipe (all owner-gated, config-not-code where possible):** apply `20260877`–`20260880` → run the
QIE exporter → invoke the importer (service role) → wire the handler to `getProgramDSettings` + pass
`programD` → flip `edu_program_d_settings.certified_pool_enabled` per pilot tenant → measure `aiCandidateRate`
→ flip `gap_fill_policy=hard_off` when coverage suffices. Cut-back = flip the flags off (config, no redeploy).
