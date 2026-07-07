# Curriculum Intelligence — Acceptance Test Plan

**Date:** 2026-07-06 · Defines what "proven" means per wave. Code waves additionally pass the standard regression bar (`flutter analyze` 0 · `flutter test` no new failures · `deno test`+`deno check` green for touched functions) and the EOS gate; the certification SSOT remains the extended live-cert script.

---

## 0. Download Verification & Recovery Engine (AT-V) — ✅ implemented & green 2026-07-07

Spec: [`../spec/DOWNLOAD_VERIFICATION_AND_RECOVERY_ENGINE.md`](../spec/DOWNLOAD_VERIFICATION_AND_RECOVERY_ENGINE.md) · code: `curriculum/scripts/verification/` · suite: 13/13 (`python3 -m unittest discover -s curriculum/scripts/verification/tests`).

- **AT-V1** Valid PDF passes V1–V11, moves into `resources/`, metadata + master/download/checksum indexes written, COMPLETED_DOWNLOADS recorded. ✅
- **AT-V2** Empty file → `EMPTY_FILE`; sub-floor file → `TOO_SMALL`. ✅
- **AT-V3** HTML error page saved as `.pdf` → `CONTENT_TYPE_MISMATCH` (magic-byte sniff). ✅
- **AT-V4** Truncated PDF (no `%%EOF`/xref tail) → `PDF_TRUNCATED`; zero-page PDF → `PDF_NO_PAGES`. ✅
- **AT-V5** Filename mismatch vs queue expectation → `NAME_MISMATCH`. ✅
- **AT-V6** Every failure appends a `FAILED_DOWNLOADS.json` entry (reason, retry count, backoff `next_retry`, status) and preserves the bad artifact in `downloads/failed/`. ✅
- **AT-V7** Recovery ladder: retries on primary until `max_retries_per_source` → `TRY_ALTERNATIVE` per recorded candidate → `RECORD_MISSING` on exhaustion, appending to `MISSING_RESOURCES.md`; a later success clears the failure entry. ✅
- **AT-V8** Identical content (checksum match) → `DUPLICATE`, diverted to `downloads/duplicates/` with mapping in `duplicate_map.json`; never re-indexed. ✅
- **AT-V9** `DOWNLOAD_VERIFICATION_REPORT.md` regenerated on every run with all nine required counters + weighted health score. ✅
- **AT-V10** Final repository audit (`repository_audit.py`): PASS writes `REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION` to `PROJECT_STATUS.json`; a corrupted stored file flips it to `NOT_READY` (exit 1) with the A-problem named in `REPOSITORY_AUDIT_REPORT.md`. Knowledge-Base phase is blocked on this gate. ✅

## 1. Data lane acceptance (spec Parts 03–08)

### Repository integrity (run at every board exit + CI-A6)
- **AT-D1 Completeness:** every expected Board×Class×Subject×Category cell has a terminal state (VERIFIED / NOT_PUBLICLY_AVAILABLE / RESTRICTED / …) — UNKNOWN count = 0.
- **AT-D2 File integrity:** 100% of downloaded files re-verify against stored SHA-256; no zero-byte/corrupt PDFs (open + page-count probe).
- **AT-D3 Metadata:** one metadata record per resource, all mandatory fields non-empty (or documented); metadata↔file bijection (no orphans either way).
- **AT-D4 Indexes:** every resource appears exactly once in `master_index.json`; secondary indexes consistent (cross-count check).
- **AT-D5 Naming/layout:** directory validation passes; zero files outside the standard tree; zero spaces in filenames.
- **AT-D6 Provenance/licensing:** every resource has source URL + license status; **zero** resources violating the D-3 scope ruling (spot-audit sample ≥10% + full scan for flagged publishers).
- **AT-D7 Coverage targets:** Priority-A = 100% (or documented) per board; Priority-B ≥95% at CI-A5; quality score generated.
- **AT-D8 Resumability:** kill the pipeline mid-board; restart resumes from checkpoint with zero re-downloads of verified files and zero data loss.
- **AT-D9 Repository Certification (D-5):** `repository_audit.py` PASS produces the `CURRICULUM_REPOSITORY_CERTIFICATION.md` artifact + certified status in `PROJECT_STATUS.json`; any knowledge-base tooling refuses to run against an uncertified repository; a post-certification corruption revokes the status on re-audit.

### Knowledge datasets (CI-B*)
- **AT-K1 Structure fidelity:** per board×class×subject, extracted chapter list matches the official TOC (adversarial CI-REVIEW pass; 100% of subjects sampled ≥1 chapter deep).
- **AT-K2 No invention:** random-sample outcomes/competencies trace to resource ID + page and match verbatim (sample ≥20 per board).
- **AT-K3 Blueprint fidelity:** each transcribed template reproduces ≥2 official specimen papers' structure (sections, marks, choices) exactly; totals reconcile.
- **AT-K4 Format:** all datasets validate against their JSON schemas (template-seed format = existing Grade-10 seed shape).

## 2. Code lane acceptance (per wave)

### CI-C1 — Templates + solver
- **AT-C1.1 Golden compatibility:** with no template supplied, solver outputs are unchanged vs pinned goldens (exact slot plans + marks distribution).
- **AT-C1.2 Template compliance:** given the CBSE seed template, generated paper satisfies every section count, marks-per-question, internal-choice pool, chapter weightage, and cognitive quota — or reports honest gaps (never silent violation).
- **AT-C1.3 Marks exactness:** item marks sum exactly to template totalMarks incl. choice groups (pool scored as answer×marks).
- **AT-C1.4 Determinism:** identical inputs ⇒ identical paper (two runs byte-equal).
- **AT-C1.5 Live-cert:** original 20 cases green + new template case green against the VPS when the live lane is available (staged locally until then).

### CI-C2 — Catalogue expansion
- **AT-C2.1** Syllabus wizard generates chapters for a class 6 CBSE subject and an ICSE subject (previously impossible).
- **AT-C2.2** Boundary still 422s an off-syllabus chapter for both old and new boards; `subject_templates` fallback works for a fresh school.
- **AT-C2.3** Versioning columns populated; unique key unchanged; existing Grade-10 rows untouched (diff-proof).

### CI-C3 — Multi-set + exports
- **AT-C3.1** Sets A/B/C: same solved blueprint, different orders, per-set answer keys correct (key follows the shuffle).
- **AT-C3.2** PDF v2 renders sections/instructions/branding; answer key separated; v1 still available behind flag.
- **AT-C3.3** JSON export round-trips (export → parse → equals paper object).

### CI-C4 — Outcomes/competencies
- **AT-C4.1** Tagging assist proposes outcome/competency for a bank item (rule-first); teacher confirm persists; unconfirmed suggestions never affect generation.

### CI-C5 — AI Validation Engine
- **AT-C5.1** Blind-solve: a deliberately mis-keyed MCQ is rejected (mismatch detection).
- **AT-C5.2** Every validated question gets a persisted quality/confidence score + issue classification; below-threshold auto-routes to manual review (Part 16 confidence policy).
- **AT-C5.3** Revision creates a new version; original preserved; history complete.
- **AT-C5.4** No key configured ⇒ engine degrades to "manual review required", zero fabrication (I4).
- **AT-C5.5** Eval-harness v0: golden question set scores stable across two runs.

### CI-C6 — Cold-start ingestion
- **AT-C6.1** Test corpus (≥3 real school papers: digital PDF, scanned, Word) → ≥80% of questions auto-extracted with correct type/marks.
- **AT-C6.2** 100% of extracted items walk the D-6 lifecycle in order — persisted states `RAW → EXTRACTED → AI_VALIDATED → TEACHER_VALIDATED → CERTIFIED`; no state skipped; nothing reaches the active bank below CERTIFIED; the generator's selection pool contains only CERTIFIED items by default; fingerprint dedup fires on a duplicate.
- **AT-C6.3** Token discipline: deterministic-parseable pages consume zero LLM tokens (call log audit); AI sees only flagged residue.

### CI-C7 — Profiles + gating
- **AT-C7.1** Same request, profile=board vs profile=jee_foundation ⇒ measurably different selection (type/cognitive mix) within the same syllabus boundary.
- **AT-C7.2** Incompatible profile (e.g., NEET on an English subject) ⇒ pre-generation compatibility report, not a silent downgrade.
- **AT-C7.3** Entitlement off ⇒ 403-style capability denial for the gated capability; certified capabilities unaffected (default-allow).

### CI-C8 — Links + explainability
- **AT-C8.1** Paper linked to an exam session; uniqueness `(org, school, exam_id, set_code)` enforced; exam marks flow untouched (regression).
- **AT-C8.2** Every generated paper item carries a selection reason; exposure counter increments on publish.

### CI-C9 — Continuous sync
- **AT-C9.1** Seeded change (replace one resource with a new edition) → detected, queued, reprocessed incrementally, impact report names affected chapters/templates; unchanged resources untouched.

### CI-E1 — Dormant seed
- **AT-E1.1** Migrations apply cleanly; tables empty + RLS-correct; zero UI/API surface; existing suites all green (dormancy proof).

### CI-C10 — Question Factory *(Amendment A1)*
- **AT-C10.1** An Item Model with numeric/context variables generates N distinct candidates — all boundary-clean, metadata-complete, concept-linked, family-assigned; every one enters at `GENERATED` and routes through CI-C5.
- **AT-C10.2** An out-of-boundary generation attempt (higher-grade concept, or Bloom above the concept's allowed range) is rejected **before persistence** — nothing stored (AIMS: never store boundary violations).
- **AT-C10.3** MCQ generation reuses a library distractor with matching concept + misconception category; provenance recorded on the item.
- **AT-C10.4** A candidate with incomplete mandatory metadata cannot be promoted past `AI_VALIDATED` (completeness gate proof).
- **AT-C10.5** No runtime path invokes the factory: route/static audit proves paper assembly never calls generation (offline-AI pattern).
- **AT-C10.6** Foundation-profile generation raises Bloom/reasoning only — chapter/topic scope identical to the base profile (depth-not-scope proof).

### CI-C11 — Diagram Intelligence *(Amendment A1)*
- **AT-C11.1** A concept-linked diagram generates as valid SVG (parses, renders, labels present), stored with full metadata (type, method, license, version).
- **AT-C11.2** Teacher rejection keeps the diagram out of the library; approval certifies + versions it; revision creates a new version (original preserved).
- **AT-C11.3** Two questions reference the same certified diagram (reuse proof); the paper PDF embeds it; a diagram-absent paper renders byte-identical to today (B14).
- **AT-C11.4** Raster upload / copied-image ingestion paths are rejected — vector-only + originality gate (Rule 14).

## 3. Program-level acceptance (bootstrap Step 7 / spec Part 15 / AIMS Part 4 safeguards + Part 9 gates)

- All wave gates passed; invariants I1–I8 verified in the final EOS run.
- Owner-decision conformance (Baseline v1.0): Repository Certification precedes all KB work (D-5); production generation draws exclusively from the Certified Question Bank by default (D-3/D-6); L2 PYQ-intelligence content never appears in L3.
- **AIMS production safeguard gate (A1-12)** — once the corresponding wave is live, every production question satisfies all of: repository-certified source trace · curriculum boundary verified · concept verified (post-E1b) · metadata complete · answer verified · diagram verified where applicable · AI validated · teacher approved · trust status CERTIFIED · copyright safe · quality score above threshold. Any safeguard failure ⇒ the question never enters production. (Subordinate to EOS — this is a content gate, not a second engineering gate.)
- v3.0 §18 Phase-1 KPIs: 100% template-conformant papers · past-paper ingestion <1 day, ≥80% auto-extracted.
- Final reports: coverage, quality, license, missing-resources, program summary — complete and honest about limitations (Part 15 final-handoff rule).

## 4. Standing metrics (AIMS Part 9 — reported with wave evidence, dashboarded when the ops lane opens)

Repository health · knowledge/concept coverage · question/diagram coverage · teacher approval rate · question/diagram quality scores · curriculum coverage · duplicate rate · validation failure rate · runtime performance (paper generation latency, zero runtime-AI calls) · certified-asset reuse rate.
