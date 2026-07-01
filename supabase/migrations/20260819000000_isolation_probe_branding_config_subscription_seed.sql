-- Isolation-probe fixture seed — branding row for the synthetic probe SCHOOL_A.
--
-- The live /health/tenant-access self-check probe `school_a_sees_own_branding`
-- asserts the school-scope RLS lets SCHOOL_A read its OWN school_branding row
-- (keyed on school_id, not a synthetic fixture id). The probe SCHOOL_A
-- (a2000000-…-0001) is a synthetic isolation-probe entity seeded by
-- 20260614810000_pilot_probe_seeds.sql — it already has a school_configuration
-- row and an organization_subscriptions row, but NO school_branding row, so the
-- probe read returned 0. This seeds exactly that one branding row.
--
-- Safety: idempotent (guarded by NOT EXISTS on the natural key
-- (organization_id, school_id)); non-destructive (re-keys nothing, inserts a
-- brand-new row); touches no real customer school (SCHOOL_A is a probe entity).
-- school_configuration + organization_subscriptions already exist for the probe
-- school/org and are asserted by natural key, so they are NOT seeded here.

INSERT INTO school_branding (id, organization_id, school_id, display_name)
SELECT
  'e1000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'Isolation Probe School A'
WHERE NOT EXISTS (
  SELECT 1 FROM school_branding
  WHERE organization_id = 'a1000000-0000-4000-8000-000000000001'
    AND school_id = 'a2000000-0000-4000-8000-000000000001'
);
