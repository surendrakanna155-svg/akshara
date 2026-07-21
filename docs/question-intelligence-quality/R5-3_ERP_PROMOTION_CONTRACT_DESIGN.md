# R5-3 — ERP Promotion Contract (DESIGN) · [C9] #database-7 #product-7

**Status:** 📐 **DESIGN ONLY — implementation is OWNER-GATED.** Per the QIE remediation roadmap R5-3
("*design now, implement owner-gated*"). This document specifies the contract by which a QIE-certified question
crosses from the intelligence engine into the ERP product; **no migration, exporter, or RLS is created here.**
Date: 2026-07-21.

> ⚠ This spec is authored by the QIE remediation lane. The ERP schema/RLS/migrations are owned by the ERP
> engineering lane; the actual migration + exporter land only after explicit owner authorization, sequenced by
> that lane (migration numbering must not collide — current ERP band is in the `2026085x`/`2026088x` range).

---

## 1. The gap (from the audit, verified against the live schema)

- **No exporter exists.** Zero committed code moves a certified item from `qpl_question_bank.db` (the ONE
  product bank, RI-6) into any ERP table.
- **No platform home.** `edu_question_bank_items` (mig `20260620000000_education_suite_foundation.sql`) has
  `organization_id UUID NOT NULL` + `school_id UUID NOT NULL` and **school-scoped RLS**
  (`organization_id = app_current_tenant_id() AND school_id = app_current_school_id()`). A platform-authored,
  cross-tenant certified item has nowhere to live — it is not owned by any single school.
- **Enum mismatch.** `difficulty CHECK (difficulty IN ('easy','medium','hard'))` — QIE emits `medium`/`hard`
  and the audit noted a `moderate` label; `question_type` is a fixed CHECK set that (per the audit) lacks
  `numerical`. A raw insert of a QIE item fails the CHECK constraints.
- **Vocabulary mismatch.** ERP `concept_id` is a UUID (see `20260857000000_edu_question_classification_columns`);
  QIE concepts are `KC_<sha14>` **text** ids. They cannot join without a map.
- **Notation debt.** QIE math stems are ASCII prose ("sin-squared theta", "integral of x dx"); there is no
  `stem_format` column and no LaTeX. Retrofitting notation onto thousands of prose stems later = re-authoring.

## 2. Design decisions

### D1 — A platform-scoped certified bank table (NEW), distinct from the school-authored bank
Add a platform-home table (e.g. `edu_platform_question_bank`) whose rows are owned by the PLATFORM, not a
school: `organization_id`/`school_id` **nullable** (or a reserved platform sentinel tenant), with RLS that makes
rows **readable by every tenant** but **writable only by the platform service role**. A school *adopts* a
platform item by reference (a thin `edu_school_adopted_items(school_id, platform_item_id)` link) — it never
copies the row, so a re-certification/recall at the platform propagates. The existing school-authored
`edu_question_bank_items` is untouched (teachers still author their own).
*Invariant:* a school surface reads the UNION (adopted platform items ∪ own items) through ONE view; RLS keeps
tenant isolation intact.

### D2 — KC_ ↔ UUID vocabulary map
A dedicated `edu_concept_vocabulary(kc_id TEXT UNIQUE, concept_uuid UUID, subject, canonical_name,
frozen_version)` table, seeded from the frozen index's certified `ki_concept` rows and the R5-2
`concept_namespace` convergence. The export stamps each item's `concept_uuid` via this map; an item whose KC_ id
has no UUID is **not exported** (honest-null — never a guessed UUID). This is the ERP-facing extension of R5-2.

### D3 — Enum alignment (at the boundary, not by weakening a CHECK)
The exporter MAPS QIE labels to the ERP domain: `moderate → medium`; a QIE numeric item → a `question_type`
that the ERP CHECK must be **extended** to include (`numerical`) in the owner-gated migration. Difficulty stays
the ERP set `{easy, medium, hard}`; QIE's `predicted_uncalibrated` (R2-5) rides a separate
`difficulty_calibration` column so a predicted difficulty is never sold as measured.

### D4 — Versioned export manifest, pinned to the freeze fingerprints
Every export batch writes a manifest recording: the source freeze fingerprints (`content_fp`, `substrate_fp`,
`frozen_version` from `ki_meta`), the `qpl_question_bank` certification snapshot, the exporter contract version,
and the per-item content-addressed id. A consumer can verify an exported item against the exact frozen substrate
it was certified on (defends against the C3 drift class at the export boundary).

### D5 — Content-addressed ids survive export
The ERP `id` (or a `source_content_hash` column) carries the QIE `item_hash`, so the same certified content maps
to the same ERP row across re-exports (idempotent; the RI-9 dedup key crosses the boundary). Re-export never
duplicates; a recalled item is tombstoned by hash.

### D6 — LaTeX authoring contract BEFORE the bank grows (the load-bearing sequencing decision)
Add `stem_format TEXT CHECK (stem_format IN ('plain','latex'))` + a dual `stem_plain` / `stem_latex` pair to the
authoring contract **now, before scale**. Every new certified item must carry a LaTeX stem; the ASCII-prose
backlog is migrated by a one-time authoring pass, never by a lossy auto-converter. *Rationale:* retrofitting
notation onto thousands of prose stems after the bank grows is re-authoring the bank — cheaper to gate at
authoring time. Prototype the Flutter/web math-render path (KaTeX/MathJax equivalent) early to de-risk D6.

## 3. What is buildable now vs owner-gated

| Piece | State |
|---|---|
| This contract spec (D1–D6) | ✅ **DONE (this doc)** — design-only |
| R5-2 `concept_namespace` (KC_ resolution that D2 seeds from) | ✅ done (committed) |
| The platform bank migration + RLS (D1) | ⛔ owner-gated (ERP lane, migration numbering) |
| `edu_concept_vocabulary` migration + seed (D2) | ⛔ owner-gated |
| CHECK-set extension for `numerical` (D3) | ⛔ owner-gated (ERP migration) |
| The exporter (`qpl_question_bank` → platform bank) + manifest (D4/D5) | ⛔ owner-gated |
| `stem_format` + LaTeX authoring contract (D6) | ⛔ owner-gated (but should precede any bank-growth program) |
| Flutter/web math-render prototype (D6) | ⛔ owner-gated (UI lane) |

## 4. Standing-law alignment

- **RI-6 preserved:** the ERP platform bank is populated ONLY by the exporter reading `qpl_question_bank`
  (the one product bank); no other QIE store may write to ERP.
- **Freeze discipline:** the export manifest pins the frozen fingerprints; export never mutates the frozen index.
- **Honest-null:** an item whose KC_ id has no UUID (D2) or lacks a certified chain is NOT exported — never a
  guessed mapping.
- **No re-authoring debt:** D6 gates LaTeX at authoring time so the notation contract precedes scale.
- **Owner gate:** nothing in §3's ⛔ rows is implemented until the owner authorizes and the ERP lane sequences it.
