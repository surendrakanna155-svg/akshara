# Curriculum Intelligence — Implementation Checklist

**Date:** 2026-07-06 · Working checklist per wave. A wave is DONE only when every box is ticked **and** its gate passed (EOS for code waves; data-quality gates for data waves). Status mirrors [`MILESTONE_TRACKER.md`](MILESTONE_TRACKER.md).

---

## Gate 0 — Program approval
- [x] Owner resolved **D-1..D-6** (2026-07-07): integration approved · `curriculum/` ratified · **three-layer question model** (production = Certified Question Bank only) · board order **CBSE → AP → TS → CISCE** · **Repository Certification stage** mandatory · **Question Trust Lifecycle** `RAW → EXTRACTED → AI_VALIDATED → TEACHER_VALIDATED → CERTIFIED`
- [x] Planning suite approved and frozen as **🔒 Program Baseline v1.0**

## CI-A0 — Scaffolding
- [x] **Download Verification & Recovery Engine** (owner-ordered 2026-07-07): checks V1–V11 · recovery ladder (retry→alternative→missing) · duplicate diversion · `DOWNLOAD_VERIFICATION_REPORT.md` · final repository audit gating `REPOSITORY_READY_FOR_KNOWLEDGE_BASE_GENERATION` — `curriculum/scripts/verification/`, 13/13 tests + CLI smoke green (AT-V1..V10)
- [x] `configs/paths.json` + `configs/verification_rules.json` (location-agnostic; thresholds config-driven)
- [x] `.gitignore` guard for binary trees (verified: dropped PDFs invisible to git)
- [ ] Directory standard created (spec Part 04) at the D-2 location; binary trees gitignored
- [ ] `configs/`: boards, subjects, classes, download_rules, folder_rules, metadata_schema, quality_rules, retry_rules
- [ ] PM files: TODO / PROGRESS / SESSION_LOG / CHECKPOINTS / DOWNLOAD_QUEUE / FAILED_DOWNLOADS / COMPLETED_DOWNLOADS / PROJECT_STATUS
- [ ] Scripts skeleton (download / verification / organization / metadata / reports / utilities / maintenance)
- [ ] One full dry-run: discover → download → validate → organize → metadata → index → report
- [ ] Directory validation passes; docs index updated

## CI-A1..A4 — Per board (repeat per CBSE / AP / TS / CISCE — D-4 order)
- [ ] Discovery complete for every class 6–10 × every official subject × every expected category (checklist per spec Part 07)
- [ ] Priority-A resources downloaded + validated (checksum, type, size, readability)
- [ ] Every resource: metadata file + Resource ID + source URL + license status + index entry
- [ ] Failures in retry queue; missing resources documented with reason + recommendation
- [ ] Duplicates resolved (hash-checked), versions preserved
- [ ] Coverage report regenerated; board exit gate met (Priority-A 100% or documented)
- [ ] D-3 extraction-scope rules respected (no out-of-scope question content stored)

## CI-A5 — Priority-B + foundation corpus
- [ ] Priority-B ≥95% or documented · foundation resources (official/open only) organized under `resources/foundation/`

## CI-A6 — Repository close-out + Repository Certification (D-5)
- [ ] Global dedup + integrity verification green · QUALITY_SCORE / LICENSE_REPORT / MISSING_RESOURCES / SOURCE_LIST final
- [ ] All indexes rebuilt & synchronized
- [ ] `repository_audit.py` PASS → **`CURRICULUM_REPOSITORY_CERTIFICATION.md`** evidence written; certified flag in `PROJECT_STATUS.json` (audit tool extended to emit the certification artifact)
- [ ] Status chain proven: `Downloaded → Verified → Repository Certified` — **no Knowledge-Base work exists before this box is ticked**

## CI-B1..B4 — Knowledge datasets
- [ ] B1: chapter/topic trees per board×class×subject, validated against `subject_templates` seed format; versioning design note
- [ ] B2: outcomes/competencies verbatim + source-traced (resource ID + page); zero invented content (Part 16)
- [ ] B3: blueprint templates cross-checked vs ≥2 official specimen papers each; CBSE + pilot state first
- [ ] B4: Previous Question Paper Intelligence layer (D-3 L2, analysis/reference only, license metadata, zero automatic L2→L3 flow); knowledge objects; **Concept Graph dataset** (A1-1: Concept-ID scheme, parent/child + prerequisite + related relationships, misconceptions/confused-pairs, Bloom/difficulty ranges, foundation boundaries) — seed proposal reviewed
- [ ] Every dataset passed adversarial CI-REVIEW verification

## CI-C1 — Blueprint templates + solver (flagship)
- [ ] Golden tests pin current solver outputs **before** refactor; original live-cert 20 green
- [ ] `edu_blueprint_templates` migration (RLS shape = certified pattern; org NULL = platform rows)
- [ ] Solver: slot groups, internal choice, weightage/cognitive quotas as hard constraints (honest gaps on failure), pagination
- [ ] Template-absent ⇒ byte-identical legacy behaviour (test-proven)
- [ ] Selection inputs logged onto paper blueprint JSON (auditability)
- [ ] Live-cert extended (template-compliant generation case) · EOS FEATURE PASS

## CI-C2 — Catalogue expansion
- [ ] Expansion migration (additive rows, versioning columns) · wizard + boundary regression green · `erp_tenant` grant intact · EOS PASS

## CI-C3 — Multi-set + exports
- [ ] Sets A/B/C from one solved blueprint; per-set answer keys · PDF v2 (sections/instructions/branding, XCT-1 pipeline) · structured JSON export · v1 renderer preserved behind version flag · EOS PASS

## CI-C4 — Outcomes/competencies
- [ ] Schema (nullable FKs) + bank tagging + rule-first/AI-suggest/teacher-confirm assist (D3) · EOS PASS

## CI-C5 — AI Validation Engine (implements AI_VALIDATED, D-6)
- [ ] Blind-solve answer verification (independent call, mismatch → reject) · metadata sanity cross-check · quality/confidence score persisted · revision versions (original preserved) · candidates-only contract intact (I3/I4) · eval-harness v0 · EOS PASS
- [ ] D-6 lifecycle states persisted (`RAW/EXTRACTED|GENERATED/AI_VALIDATED/TEACHER_VALIDATED/CERTIFIED` — A1-6 adds the GENERATED entry state for AI-authored items); existing approved bank rows map to `CERTIFIED`
- [ ] **Metadata-completeness gate** (A1-9): new certifications blocked while the mandatory field set is incomplete; legacy rows grandfathered (TD-CI-17); boundary check on generated content covers Bloom/difficulty dimensions (Boundary Engine v2)

## CI-C6 — Cold-start ingestion (after CI-C5, D-6)
- [ ] OCR-first pipeline (deterministic → AI residue only, bounded) · extracted items enter as `RAW→EXTRACTED` · **AI_VALIDATED via CI-C5 before teacher moderation** · fingerprint dedup reused · moderation UI complete (`TEACHER_VALIDATED`) + certified→bank merge · ≥80% auto-extraction on test corpus · production selection remains CERTIFIED-only by default · EOS PASS

## CI-C7 — Profiles + gating
- [ ] Profile config entity (no hard-coded plan/profile names) · soft weighting + pre-generation compatibility report · capability gating on `plan_entitlements`, default-allow for certified capabilities · EOS PASS
- [ ] A1 extensions: profile config carries time allocation, reasoning depth, diagram requirements, question-family distribution (A1-11) · **foundation depth-not-scope** validation enforced — foundation profiles never widen curriculum scope unless explicitly configured (A1-3)

## CI-C8 — Links + explainability
- [ ] `edu_exam_paper_links` (v3.0 §5.2 shape) · exposure/rotation columns · selection-reason output · EOS PASS

## CI-C9 — Continuous sync v1
- [ ] Change detection (checksum/version/URL) · incremental reprocess queue · impact report · seeded-change proven end-to-end

## CI-E1 — Dormant Phase-2 seed
- [ ] Response-spine + trust-status + item-statistics + canonical-concept migrations applied **dormant** (zero UI); concept tables carry the A1-1 graph columns (relationships, misconceptions, Bloom/difficulty ranges) from the CI-B4 dataset · EOS PASS
- [ ] Handoff note to v3.0 Phase 2 written; program close-out in MILESTONE_TRACKER

## CI-C10 — Question Factory *(Amendment A1; after CI-C5 + CI-E1b — owner-timed A1-O1)*
- [ ] `edu_question_templates` (Item Models: variables, constraints, generation + validation rules, supported profiles) + `edu_question_families` + `edu_distractors` migrations (certified RLS shape, nullable FKs)
- [ ] Offline batch generation per concept: outputs enter as `GENERATED` → CI-C5 `AI_VALIDATED` → moderation `TEACHER_VALIDATED` → `CERTIFIED`; candidates-only contract intact (I3/I4); no state skipped
- [ ] Curriculum Boundary Engine validation at generation time (board/class/subject/chapter/topic/Bloom/difficulty; foundation depth-not-scope) — violations rejected pre-store, never persisted
- [ ] Metadata completeness enforced on every factory output (A1-9 field set incl. concept ID, family, license status, generation method, confidence)
- [ ] Distractors stored in the library with misconception category + concept link; MCQ generation reuses high-quality library distractors with provenance
- [ ] Fingerprint dedup pre-queue · versioning on regeneration (never overwrite) · batch caps per concept (R15)
- [ ] **Zero runtime AI**: factory callable only as offline/batch job — no runtime paper-assembly path invokes it · EOS PASS

## CI-C11 — Diagram Intelligence *(Amendment A1; after CI-C5 + CI-B4 — owner-timed A1-O1)*
- [ ] `edu_diagrams` migration (diagram ID, concept link, type, SVG source, generation method, license status, version, quality score, teacher approval, related questions)
- [ ] Pipeline: requirement detection → diagram specification → **programmatic SVG/vector generation** (no raster, no copied artwork — Rule 14) → AI validation → teacher validation → Certified Diagram Library
- [ ] Reuse proven: multiple questions reference one certified diagram; PDF v2 embeds certified SVGs; diagram-absent papers unchanged (B14)
- [ ] Diagram QA: SVG valid, renders correctly, labels correct, editable, original, concept-linked (AT-C11) · technology choice recorded at design gate (A1-O2) · EOS PASS

## Continuous (every wave)
- [ ] Invariants I1–I8 intact ([`../audits/BACKWARD_COMPATIBILITY_PLAN.md`](../audits/BACKWARD_COMPATIBILITY_PLAN.md))
- [ ] No scope from a later v3.0 phase (D11) · no D2/D8 violations
- [ ] AIMS anti-patterns respected (spec Part 12: no PDF-direct generation, no uncertified production content, no copied diagrams, no runtime AI regeneration, no business rules in UI, no hard-coded educational config)
- [ ] `flutter analyze` 0 · `flutter test` no new failures · `deno test`+`check` green for touched functions
- [ ] Docs: milestone tracker + initiative README refreshed at wave close
