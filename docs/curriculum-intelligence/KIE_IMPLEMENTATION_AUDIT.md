# Knowledge Intelligence Engine (KIE) — Implementation Audit

**Date:** 2026-07-10 · **Scope:** the ONE pre-build reuse audit mandated by the KIE mission. Read-only; synthesizes four parallel domain audits (existing code · DB schema · design docs · repository inputs). Purpose: **reuse aggressively, do not rebuild, do not create a competing architecture.**

---

## 0. Headline

A large, mature substrate already exists and must be reused. But **4 of the 8 mission phases are genuinely green-field** (chunking, "knowledge graph" as a *distinct* structure, vector index, and the 90–95%/5–10% split) — none of these appear in any frozen spec, so designing them re-decides nothing. The concept/question **schema already exists in Postgres, dormant and empty** — I am free to be its first writer. The final objective (AI generation of original JEE/NEET questions) sits behind **two frozen governance gates**, one of which the owner previously locked as "do not build yet."

---

## 1. Reusable components (the mission's 6 categories)

### (1) Reusable CODE
| Component | Path | Verdict |
|---|---|---|
| Phase-1 repository verifier (scan → classify parser-readiness → manifest → report) | `curriculum/scripts/intelligence/repository_verifier.py` (478 lines) | **REUSE-AS-IS** — already run over the 363-file foundation corpus (239 text / 93 OCR / 28 unpack / 2 corrupt) |
| PDF/zip integrity + sha256 primitive | `curriculum/scripts/verification/verification_engine.py::_verify_pdf`, `_sha256` | **REUSE-AS-IS** (already the shared primitive) |
| Repository audit + D-5 certification template | `curriculum/scripts/verification/repository_audit.py::audit/certify` | **REUSE-AS-IS as the D-5 gate template** |
| Workspace/JSON/config idiom | `curriculum/scripts/common/workspace.py` (`Workspace`, `load_json`, `write_json`, `make_sample_pdf`) | **REUSE-AS-IS** |
| Coverage + report rendering | `curriculum/scripts/common/coverage.py`, `curriculum/scripts/reports/*.py` | **EXTEND** for per-concept/per-chapter coverage |
| Legacy ingest stub | `curriculum/scripts/intelligence/run_pipeline.py` (untracked) | **IGNORE** — superseded by `repository_verifier.py` |

### (2) Reusable DATABASE TABLES (all Postgres/Supabase; all dormant → first-writer-friendly)
- **Concept spine (REUSE):** `canonical_concepts` (nodes: `concept_code` e.g. `SCI_G06_PHY_FORCE_001`, definition, `bloom_levels`, `difficulty_range`, `curriculum_boundary`, `foundation_boundary`, `common_misconceptions`, `reference_facts`, `merged_into`), `concept_prerequisites` (edges, single discriminated table: `prerequisite`/`parent_child`/`related`/`confused_with` + `strength`), `concept_board_mappings` (concept ↔ board/chapter/topic, `alignment` exact/partial/extends). — migration `20260859000000`.
- **Question factory (REUSE, 3-tier):** `edu_question_families` → `edu_question_templates` (AIG item models: `stem_template`, `parameter_variables`, `constraints`, `generation_rules`, `validation_rules`, `difficulty_range`, `supported_exam_profiles`) → instances land in the live `edu_question_bank_items`; plus `edu_distractors` (misconception-typed, reuse/quality scores). — migration `20260858000000`.
- **Selection/governance (REUSE):** `edu_exam_profiles`, `edu_blueprint_templates`, `edu_item_rotation_policies`, `edu_exam_paper_links`, `edu_question_paper_reviews`; live: `edu_question_bank_items`/`edu_question_papers`/`edu_question_paper_items`, `subject_templates`, `syllabus_chapters`/`syllabus_topics`.
- **Classification columns already on `edu_question_bank_items` (REUSE):** `difficulty`, `cognitive_level` (Bloom), `program_track`, `jee_question_type`, `competency`, `learning_outcome`, `fingerprint` (dedup), `review_status`, `trust_status` lifecycle, `concept_id`/`question_family_id` FKs.
- **MISSING → need NEW tables:** (a) source-document metadata registry, (b) text-chunk-with-provenance, (g) vector/embedding index. Note `pgvector` is **timing-locked to v3.0 Phase 3** (`TECHNICAL_DEBT_REGISTER.md` TD-CI-12) → the vector index must be **local-only/offline**, not in the production DB.

### (3) Reusable PARSER components
Essentially **none for full extraction** — only page-sample `pypdf` text used for readiness classification/integrity. Full-document text extraction, table extraction (pdfplumber), and OCR (Tesseract) are **all absent** — `pymupdf`/`pdfplumber`/`pytesseract` are staged-but-commented in `curriculum/scripts/intelligence/requirements.txt`. `resources/foundation/knowledge/repository_verification.json` already provides **pre-computed per-file parser routing** (text_extract / ocr / unpack) — reuse it as the parser's work-queue.

### (4) Reusable METADATA components
- Resource-level metadata schema + validator + secondary-index rebuilder: `curriculum/configs/metadata_schema.json`, `curriculum/scripts/metadata/metadata_tools.py`. **REUSE-AS-IS.**
- **The seam:** `metadata_schema.json` has a dormant `knowledge_base_prep` block (`chapters`, `topics`, `learning_outcomes`, `bloom_classification`, `competency_mapping` = `PENDING_EXTRACTION`) — the intended landing spot for the metadata/concept stage. **EXTEND, don't reinvent.**
- 5 hand/AI-built exam blueprints already exist (`curriculum/knowledge/blueprints/*.json`, structural only, no copied content) — reuse their `extraction.method`/`confidence` provenance convention.

### (5) Reusable CURRICULUM-INTELLIGENCE components
- **Frozen invariants I1–I8** (`audits/BACKWARD_COMPATIBILITY_PLAN.md §1`) protect the existing production exam engine — must not be broken.
- **AIMS Golden Rules 1–20** (frozen) govern the question layer — load-bearing: Concept-before-Question, AI-Creates/Engine-Assembles, Certified-Content-Only, Curriculum-Boundary-Absolute, Copyright-Safety (original only), Every-Question-in-a-Family, Every-Question-Traceable.
- **Owner decisions D-1…D-7** (`OPUS_IMPLEMENTATION_HANDOFF.md`): D-1 CI is a parallel platform (never replace the certified exam engine); D-5 **Repository Certification is mandatory before any KB work**; D-6 Trust Lifecycle (only CERTIFIED generates by default); D-7 family-level cert (**pending ratification**).
- Waves already DONE (reuse, don't redo): CI-C1/C3/C7/C8 (solver, multi-set/export, exam profiles, rotation), B12 + E1b + E1a schema seeds.

### (6) Reusable ASSESSMENT-INTELLIGENCE components
- The **3-tier asset model** (Concept → Family → Template/Item-Model → instance) is fully designed (AIMS Part 2/6) and dormant-schema'd (§(2)).
- The **offline-AI / deterministic-runtime split** is frozen (I1/I3/Rule-3/Rule-20): AI builds assets offline in batch; the runtime only *selects/assembles* deterministically, "never invoke AI per paper."
- **Trust Lifecycle** `RAW→…→CERTIFIED→ACTIVE→…→RETIRED` (instance-level today; family-level is the pending A2 proposal).
- Difficulty/Bloom are **metadata fields + config balancing axes**, not a runtime algorithm (no numeric 5-level/6-level model is frozen).

---

## 2. Critical reconciliations (these shape the architecture)

1. **Precedence / no-competing-canon.** Top law = `docs/Vision/design/Assessment-Intelligence-Platform.md` (Master Plan v3.0, D1–D11) → AIMS → MCIP → this program's audits/planning. **Rule 12 / RISK R5: never create a second architecture or roadmap.** → The KIE architecture must be framed as the **deterministic implementation-blueprint that realizes v3.0/AIMS's offline layer and fills the green-field gaps**, explicitly subordinate — not a new canon.
2. **"Knowledge Graph" = "Concept Graph."** MCIP's lone "Knowledge Graph" mention is an empty placeholder; AIMS's **Concept Graph** is the real, dormant-schema'd design. Phase 6 builds *the Concept Graph* (`canonical_concepts`/`concept_prerequisites`), not a second graph.
3. **Local-storage lock.** Derived knowledge is **LOCAL ONLY, not committed**; git carries only schemas/engine/tests/code. → KIE outputs (chunks, concepts, KG, vector index) live in a **local SQLite + files under `curriculum/knowledge/`** whose schemas **mirror** the Postgres `edu_*` tables. Promotion to Postgres happens later via the **Knowledge Intake Center**.
4. **Scope split (needs owner confirm).** The CI program is board curriculum (CBSE/AP/TS/CISCE, Classes 6–10, 14.1%). The mission's objective + the complete 363-file corpus are **JEE/NEET (`resources/foundation/`)**. These are two corpora with two metadata regimes.
5. **The final objective is double-gated (needs owner confirm).** AI generation of new content (CI-C5 validation + CI-C10 engine + C11) **must be born inside `P3-AI-1`**, a *separate* Adaptive-AI governed runtime the owner previously locked **"do not build yet."** Phases 1–4 and the deterministic parts of 5–7 need **no** AI gate; Phase 8 (and any AI concept-tagging in Phase 5) does.
6. **Family-level certification / I9 is direction-approved, not frozen** — design for it, mark pending-ratification.
7. **90–95%/5–10% is a NEW target** (not sourced from AIMS/MCIP; it echoes the Adaptive-AI "≥90% zero-call" goal) — adopt it as a stated KIE target, not as pre-existing law.

---

## 3. Reuse verdict in one line
**Reuse:** the verification/integrity/metadata/indexing/reporting substrate (code) + the entire dormant concept/question/graph Postgres schema + the frozen invariants, rules, and Trust Lifecycle. **Build new (green-field):** full text/table extraction, OCR, chunking, a local knowledge store (SQLite mirroring `edu_*`), the deterministic concept-extraction pipeline, a local vector/search index, and the Knowledge Intake Center bridge — all **local-only, subordinate to v3.0/AIMS.** **Do not activate:** AI generation (Phase 8) until the owner lifts the P3-AI gate.
