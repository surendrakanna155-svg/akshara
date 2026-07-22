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
