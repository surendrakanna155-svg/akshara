-- Phase 5 probe seed (v9.8–v10.3)

INSERT INTO school_memory_events (
  id, organization_id, school_id, title, category, event_date, status, visibility
)
SELECT
  '00000000-0000-4000-a000-000000000501'::uuid,
  o.id,
  s.id,
  'Annual Day 2026',
  'annual_day',
  '2026-03-15',
  'published',
  'parents'
FROM organizations o
JOIN schools s ON s.organization_id = o.id
WHERE o.slug = 'demo-org'
ON CONFLICT (id) DO NOTHING;

INSERT INTO achievement_promotions (
  id, organization_id, school_id, achievement_type, title, status, assets, analytics
)
SELECT
  '00000000-0000-4000-a000-000000000502'::uuid,
  o.id,
  s.id,
  'gold_medal',
  'Science Olympiad Gold Medal',
  'published',
  '{"poster":"Demo poster"}'::jsonb,
  '{"views":10,"shares":2,"downloads":1}'::jsonb
FROM organizations o
JOIN schools s ON s.organization_id = o.id
WHERE o.slug = 'demo-org'
ON CONFLICT (id) DO NOTHING;
