-- Program D · M1.4 — edu_bank_items_union read model. DORMANT, additive, owner-gated apply.
--
-- Contract-2 §2.3 (docs/roadmap/PROGRAM_D_CONTRACTS.md) is normative. This VIEW UNIONs
--   (a) a school's OWN certified bank (edu_question_bank_items), projected UNCHANGED, and
--   (b) its ADOPTED, ACTIVE platform items (edu_school_adopted_items ⋈ edu_platform_question_bank),
-- into the EXACT QuestionBankItemRow column set (31 columns, in QuestionBankItemRow order —
-- see education_types.ts) so the authoritative deterministic solver's input pool is
-- shape-identical whether an item is school-authored or certified-platform.
--
-- DORMANT: no production code reads this view yet; it is WIRED by a later, flag-gated
-- milestone (certified_pool_enabled — 20260880000000), default OFF = exact current
-- behaviour. No data seed. No wiring. Read model only (SELECT), never written.
--
-- RLS SAFETY (the view has NO RLS of its own — it INHERITS base-table RLS):
--   * WITH (security_invoker = true) — the view executes as the QUERYING role (erp_tenant),
--     NOT the view owner, so base-table RLS policies apply to the caller. Without this a
--     view would run with the owner's rights and BYPASS RLS. (Same pattern as the certified
--     org_school_summary view, 20260609100000.)
--   * Own side: edu_question_bank_items _school_scope restricts to the caller's school.
--   * Platform side: the adoption join (edu_school_adopted_items _school_scope) restricts to
--     the caller's own adoptions, and edu_platform_question_bank _platform_read (org NULL)
--     plus the p.status = 'active' predicate restrict to live platform rows.
--   A school therefore sees ONLY its own items ∪ its adopted-and-still-active platform items.
--   RLS-safe by construction; the view adds no policy of its own.
--
-- Reversibility (additive + dormant ⇒ safe). Owner-gated DOWN:
--   DROP VIEW IF EXISTS edu_bank_items_union;

CREATE OR REPLACE VIEW edu_bank_items_union
WITH (security_invoker = true) AS
-- (a) OWN bank — projected UNCHANGED (its real QuestionBankItemRow columns).
SELECT
  b.id,
  b.organization_id,
  b.school_id,
  b.subject_name,
  b.chapter,
  b.topic,
  b.difficulty,
  b.question_type,
  b.marks,
  b.question_text,
  b.answer_text,
  b.options,
  b.status,
  b.source,
  b.source_reference,
  b.program_track,
  b.jee_question_type,
  b.cognitive_level,
  b.syllabus_chapter_id,
  b.syllabus_topic_id,
  b.learning_outcome,
  b.fingerprint,
  b.review_status,
  b.created_by,
  b.created_at,
  b.updated_at,
  b.times_used,
  b.last_used_at,
  b.competency,
  b.question_family_id,
  b.concept_id
FROM edu_question_bank_items b

UNION ALL

-- (b) ADOPTED, ACTIVE platform items — projected per Contract-2 §2.3 platform-side rules.
SELECT
  p.id,                                       -- id = platform id
  a.organization_id,                          -- adopting org
  a.school_id,                                -- adopting school
  p.subject_name,
  p.chapter,
  p.topic,
  p.difficulty,
  p.question_type,
  p.marks,
  p.question_text,
  p.answer_text,
  p.options,
  'active'::text AS status,                   -- only active platform rows are unioned
  'certified_platform'::text AS source,       -- platform-side source sentinel
  NULL::text AS source_reference,             -- not specified for platform side; honest-null
  p.program_track,
  NULL::text AS jee_question_type,            -- §2.3: null on platform side
  p.cognitive_level,
  NULL::uuid AS syllabus_chapter_id,          -- §2.3: null on platform side
  NULL::uuid AS syllabus_topic_id,            -- §2.3: null on platform side
  NULL::text AS learning_outcome,             -- §2.3: null on platform side
  p.content_hash AS fingerprint,              -- §2.3: fingerprint = content_hash
  'approved'::text AS review_status,          -- §2.3: platform items are approved
  NULL::uuid AS created_by,
  p.created_at,
  p.updated_at,
  0 AS times_used,                            -- §2.3: exposure lives on the own-bank seam
  NULL::timestamptz AS last_used_at,          -- §2.3: exposure lives on the own-bank seam
  NULL::text AS competency,                   -- §2.3: null on platform side
  NULL::uuid AS question_family_id,           -- §2.3: null on platform side
  p.concept_uuid AS concept_id                -- §2.3: concept_id = platform concept_uuid
FROM edu_school_adopted_items a
JOIN edu_platform_question_bank p
  ON p.id = a.platform_item_id
  AND p.status = 'active';                     -- recall (tombstone) drops out automatically

GRANT SELECT ON edu_bank_items_union TO erp_tenant;  -- read model only, never written
