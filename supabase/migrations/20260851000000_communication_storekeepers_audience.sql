-- INV-7 — `storekeepers` broadcast audience (low-stock alert rides XCT-2).
--
-- (a) AUDIENCE CHECK: widen comm_broadcasts_audience_check to also allow
--     'storekeepers' so the inventory low-stock reminder can target the store
--     staff instead of blasting every staff member. Same drop + re-add pattern
--     as 20260838000000 (COM-2). NOTE: this re-add also RESTORES 'all_staff',
--     which 20260729000000 introduced but 20260838000000's re-add accidentally
--     dropped from the constraint — existing all_staff broadcasts stay valid.
--
-- (b) ROLE SEED: the client has had a Storekeeper ERP role (JWT `role` =
--     'storekeeper') since the role architecture landed, but role_definitions
--     never seeded it, so no school could actually assign the role. Seed the
--     definition + its permission grants (mirrors the client role_permissions
--     set: admin hub + inventory read; plus manageInventory so a storekeeper
--     can post issues/counts through the manageInventory-gated stock module).
--     Idempotent (ON CONFLICT DO NOTHING), forward-only, no tenant data touched.
--
-- The recipient resolver falls back to the all-staff set when a school has no
-- active storekeeper membership, so an alert is never silently dropped.

-- ── (a) widen the audience CHECK ──────────────────────────────────────────────

ALTER TABLE comm_broadcasts DROP CONSTRAINT IF EXISTS comm_broadcasts_audience_check;
ALTER TABLE comm_broadcasts ADD CONSTRAINT comm_broadcasts_audience_check CHECK (
  audience IN (
    'all_parents', 'all_teachers', 'all_students', 'all_staff', 'school_wide',
    'class_parents', 'class_students', 'storekeepers'
  )
);

-- ── (b) seed the storekeeper role + grants ────────────────────────────────────

INSERT INTO role_definitions (slug, display_name, scope) VALUES
  ('storekeeper', 'Storekeeper', 'school')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT 'storekeeper', p.slug
FROM (VALUES ('viewAdminHub'), ('viewInventory'), ('manageInventory')) AS v (slug)
JOIN permission_definitions p ON p.slug = v.slug
ON CONFLICT (role_slug, permission_slug) DO NOTHING;
