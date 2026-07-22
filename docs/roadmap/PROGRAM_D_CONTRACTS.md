# PROGRAM D — Frozen Cross-Lane Contracts (v1)
## The only coupling surface between parallel workstreams

**Status:** 🔒 **FROZEN at the Phase-1 sync point** (coordination plan §1.3). Any change after freeze requires
Lead-Coordinator sign-off + notification to every dependent lane. · **Baseline:**
`feature/program-d-knowledge-bank-integration` @ `2e16d215`. · **Consumers:** WP-A, WP-B, WP-C, WP-D, WP-E.

These two contracts are the **entire** cross-lane coupling. Build against them; do not invent alternative
shapes. Enum values and column names here are **normative**.

---

## Contract-1 — Export Artifact (QIE offline → ERP importer)

The versioned JSON the QIE exporter (WP-A) emits and the ERP importer (WP-C) ingests. Deterministic +
byte-identical for an identical certified bank. **Producer:** WP-A. **Consumer:** WP-C. **Vector consumer:** WP-D.

### 1.1 Top-level shape

```jsonc
{
  "manifest": {
    "artifact_version": "program-d-export/1",     // this contract version
    "generated_from": "qpl_question_bank",         // or "fixture" for fixture runs
    "frozen_version": "<frozen index version>",    // e.g. "v1.5:ba3f8b7c51fa"; "program-d-fixture" for fixtures
    "content_fp": "<sha256 over the sorted row content_hashes>",   // freeze fingerprint (D4)
    "substrate_fp": "<sha256 of the certified-bank substrate read>",
    "row_count": 12,
    "near_dup_model_version": "hashvec-128-v1",     // §1.3
    "near_dup_threshold_version": "cosine-0.82-v1", // §1.3
    "enum_map_version": "program-d-enum/1"
  },
  "rows": [ /* ExportRow[], sorted by content_hash ascending (determinism) */ ]
}
```

### 1.2 `ExportRow` fields (normative)

| Field | Type | Source / rule |
|---|---|---|
| `content_hash` | string | = QIE `item_hash` (`IH_…`). **The idempotency key** (D5). Unique per row. |
| `stem_norm_hash` | string | = QIE `stem_norm_hash` (`NH_…`). Exact-dup + tombstone aid. |
| `question_text` | string | QIE `stem`. |
| `answer_text` | string | QIE `answer_value` (the correct value). |
| `options` | string[] | QIE `options` dict → **array ordered by label A,B,C,D**. |
| `answer_label` | string | QIE `answer_label`. |
| `question_type` | enum | **enum-mapped**: QIE `MCQ`→`mcq`. (Map table §1.4.) |
| `difficulty` | enum | **enum-mapped**: QIE `intended_difficulty` `easy→easy`, `moderate→medium`, `hard→hard`. |
| `difficulty_calibration` | enum | `predicted_uncalibrated` (M2.1). Certified export is predicted, never measured (R2-5). |
| `cognitive_level` | enum\|null | Bloom (M2.2), mapped to `remember\|understand\|apply\|analyze\|hots`, else null (honest-null; no fabrication). |
| `marks` | int>0 | QIE `marks` (M2.2). |
| `subject_name` | string | QIE `subject`. |
| `chapter` | string | QIE `concept_title` (best available) or "". |
| `topic` | string | "" unless available. |
| `program_track` | enum | default `board` (fixtures/school lane). One of the ERP program_track enum. |
| `kc_id` | string | QIE `concept_code` (`KC_…`). Provenance. |
| `concept_uuid` | uuid | via M0.2 `vocabulary.resolve(kc_id)`. **If null → the row is NOT exported** (honest-null; never guessed). |
| `near_dup_embedding` | number[128] | §1.3 — L2-normalised dense vector, offline-computed. |
| `provenance` | object | `{ generator_model, generator_family, evidence_class, certification_class, run_id, model_version, generator_actor }` from the certified row. |
| `frozen_version` | string | mirrors manifest. |

**Export admission rule (fail-closed):** a row is exported **iff** the source is `status='certified' AND
certification_class='certified'` **and** `vocabulary.resolve(kc_id) is not None`. Provisional / quarantined /
expired / trial_certified / unmapped-KC → **excluded**. Never weaken this WHERE.

### 1.3 Near-dup embedding (deterministic, offline, explainable — NOT a neural black box)

- **`near_dup_embedding`** is a **deterministic text-feature vector**: tokenise the normalised stem
  (`gates._norm_stem` shape — lowercase, numbers→`#`, non-alpha stripped), drop stopwords, hash each token to
  `[0,128)`, accumulate term-frequency weights, **L2-normalise** → `number[128]`. Purely deterministic, no
  model, versioned as `near_dup_model_version = "hashvec-128-v1"`. **Producer: WP-A** (owns the exact recipe).
- **Request-time check (WP-D)** is **cosine similarity of two stored vectors ≥ threshold**
  (`near_dup_threshold_version = "cosine-0.82-v1"` → threshold 0.82). WP-D **never computes an embedding at
  request time** and **never calls a model** — it reads precomputed vectors and does vector math. Items
  without a vector (e.g. a school's own authored items) fall back to **exact fingerprint only** (current
  behaviour). Explanation = the similar pair + the cosine score.

### 1.4 Enum map (normative, applied by WP-A at the boundary — never weakens a QIE gate)

| Axis | QIE value | ERP value |
|---|---|---|
| question_type | `MCQ` | `mcq` |
| difficulty | `easy` / `moderate` / `hard` | `easy` / `medium` / `hard` |
| (numeric-answer types, future) | `NUMERIC`/`INTEGER` | `numerical` (requires the widened CHECK — Contract-2) |

---

## Contract-2 — Platform Bank + Union Read Model (ERP schema → ERP runtime)

**Producer:** WP-B (owns the DDL). **Consumers:** WP-C (writes the platform bank), WP-E (reads the union),
WP-D (reads vectors). The union view's output column set **must equal `QuestionBankItemRow`** so the
authoritative solver's input pool is shape-identical.

### 2.1 `edu_platform_question_bank` (platform-owned certified items)

Normative columns (WP-B finalises defaults/constraints in the migration; these names/types/CHECKs are fixed):

| Column | Type / CHECK | Note |
|---|---|---|
| `id` | UUID PK default gen_random_uuid() | surrogate |
| `organization_id` | UUID null | **NULL = platform** (platform-read sentinel) |
| `school_id` | UUID null | NULL for platform rows |
| `content_hash` | TEXT NOT NULL **UNIQUE** | = Contract-1 `content_hash`; **importer idempotency key** |
| `stem_norm_hash` | TEXT | exact-dup aid |
| `subject_name` | TEXT NOT NULL | |
| `chapter` | TEXT NOT NULL default '' | |
| `topic` | TEXT NOT NULL default '' | |
| `difficulty` | TEXT CHECK `(easy,medium,hard)` | |
| `difficulty_calibration` | TEXT CHECK `(predicted_uncalibrated,measured_pilot)` default `predicted_uncalibrated` | **M2.1**; never blend |
| `question_type` | TEXT CHECK `(mcq,fill_blank,match,short_answer,long_answer,diagram,numerical)` | **widened with `numerical`** (never a weakening) |
| `marks` | INT CHECK (marks>0) | |
| `question_text` | TEXT NOT NULL | |
| `answer_text` | TEXT | |
| `options` | JSONB NOT NULL default '[]' | array |
| `answer_label` | TEXT | |
| `cognitive_level` | TEXT CHECK `(remember,understand,apply,analyze,hots)` null | Bloom |
| `program_track` | TEXT NOT NULL default 'board' | |
| `kc_id` | TEXT | provenance |
| `concept_uuid` | UUID | loose ref (canonical_concepts empty) |
| `near_dup_embedding` | JSONB | `number[128]`, offline |
| `near_dup_model_version` | TEXT | e.g. `hashvec-128-v1` |
| `provenance` | JSONB | Contract-1 `provenance` |
| `frozen_version` | TEXT | |
| `status` | TEXT CHECK `(active,tombstoned)` default 'active' | **recall = tombstone (append-only), never hard-delete** |
| `recalled_at` | TIMESTAMPTZ null | |
| `created_at` / `updated_at` | TIMESTAMPTZ | |

RLS: platform-read catalogue shape (FORCE RLS + `_school_scope` FOR ALL + `_platform_read` FOR SELECT on org
NULL + `GRANT SELECT, INSERT, UPDATE` — no DELETE). Platform rows written only by service role (RLS bypass).

### 2.2 `edu_school_adopted_items` (adoption BY REFERENCE — never a row copy)

| Column | Type | Note |
|---|---|---|
| `id` | UUID PK | |
| `organization_id` | UUID NOT NULL | adopting tenant |
| `school_id` | UUID NOT NULL | adopting school |
| `platform_item_id` | UUID NOT NULL | → `edu_platform_question_bank.id` (reference, not copy) |
| `adopted_at` / `adopted_by` | | |

UNIQUE (organization_id, school_id, platform_item_id). School-scoped RLS (`_school_scope` FOR ALL). Recall
propagates because adoption is by reference: a tombstoned platform item drops out of the union automatically.

### 2.3 `edu_bank_items_union` VIEW — output columns = `QuestionBankItemRow`

The view UNIONs (a) a school's own `edu_question_bank_items` and (b) its **adopted, active** platform items,
projected into the **exact `QuestionBankItemRow` column set** so the solver input pool is shape-identical:

`id, organization_id, school_id, subject_name, chapter, topic, difficulty, question_type, marks,
question_text, answer_text, options, status, source, source_reference, program_track, jee_question_type,
cognitive_level, syllabus_chapter_id, syllabus_topic_id, learning_outcome, fingerprint, review_status,
created_by, created_at, updated_at, times_used, last_used_at, competency, question_family_id, concept_id`.

**Projection rules for the platform (adopted) side:**
- `source` = `'certified_platform'` · `review_status` = `'approved'` · `status` = `'active'` (only active
  platform rows are unioned).
- `concept_id` = platform `concept_uuid` · `id` = platform `id` · `school_id`/`organization_id` = the
  **adopting** school/org (from `edu_school_adopted_items`).
- `fingerprint` = `content_hash` · `jee_question_type`/`syllabus_*`/`learning_outcome`/`competency`/
  `question_family_id` = null · `times_used`/`last_used_at` = 0/null (exposure lives on the own-bank seam).
- Own-bank side is projected **unchanged** (its real columns).

**RLS safety:** own rows via `edu_question_bank_items` school-scope; platform rows via the adoption join
(school-scoped) ∧ platform-read (org NULL, active). A school sees only its own items + its adopted items.

### 2.4 Per-tenant flag store `edu_program_d_settings` (M3.1 / M3.3)

| Column | Type / CHECK | Default | Note |
|---|---|---|---|
| `organization_id` | UUID NOT NULL | | tenant |
| `school_id` | UUID NOT NULL | | |
| `certified_pool_enabled` | BOOLEAN NOT NULL | **false** | M3.1: read the union pool. Default OFF = exact current behaviour. |
| `gap_fill_policy` | TEXT CHECK `(marked_unpublishable,hard_off)` NOT NULL | **`marked_unpublishable`** | M3.3: default = today's behaviour; owner flips to hard_off. |
| `updated_at` | TIMESTAMPTZ | | |

PK/UNIQUE (organization_id, school_id). School-scoped RLS. **Defaults reproduce exact current production
behaviour** — Program D is dark until a per-tenant flag is flipped (owner-gated).

---

## Contract change control

Frozen at `2e16d215` + Phase-1 commit. A lane that needs a change files it with the Coordinator; the
Coordinator versions the contract (`/2`), updates this doc, and notifies dependents. No lane silently
diverges. **Nothing here weakens a certification gate, adds request-path AI, or alters the authoritative
solver** — the enum widening (`numerical`) is an ERP-boundary widening, and the certified-pool/gap-fill flags
default OFF/current-behaviour.
