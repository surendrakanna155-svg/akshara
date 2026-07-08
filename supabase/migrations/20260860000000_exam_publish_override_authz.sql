-- Gap-sweep wave 2 · step 2 (security hardening, owner-ratified) —
-- exam-publish override permission.
--
-- handlePublishExamResults (exam_administration_handlers.ts) lets a caller
-- skip the verify→approve chain entirely by sending requireApproval: false
-- (or require_approval: false). Before this migration + its handler-side
-- enforcement, ANY publishExamResults holder (superAdmin, schoolAdmin,
-- principal, vicePrincipal, management — see 20260628000000_exam_governance_
-- authz.sql) could publish unverified marks straight to students/parents,
-- because the entire `if (requireApproval) { ... }` approval block was simply
-- skipped when the flag was false — no permission distinguished a normal
-- (approval-gated) publish from an override (ungated) publish.
--
-- This registers a NEW, more-privileged permission — overridePublishApproval —
-- and grants it ONLY to the SENIOR set: superAdmin, schoolAdmin, principal.
-- vicePrincipal and management deliberately do NOT receive it: they may still
-- publish through the normal approval-gated path (they already hold
-- publishExamResults), but bypassing verify→approve is reserved for the more
-- senior roles. The handler enforces this in the same request (requiring
-- BOTH publishExamResults for the route and overridePublishApproval for the
-- skip-approval branch specifically).

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  (
    'overridePublishApproval',
    'Exams',
    'override_publish',
    'school',
    'Publish exam results WITHOUT the verify→approve chain'
  )
ON CONFLICT (slug) DO NOTHING;

-- Senior-only grant — deliberately narrower than publishExamResults.
INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'overridePublishApproval'),
  ('schoolAdmin', 'overridePublishApproval'),
  ('principal', 'overridePublishApproval')
ON CONFLICT DO NOTHING;
