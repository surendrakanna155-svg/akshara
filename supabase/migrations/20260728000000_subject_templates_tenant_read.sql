-- Question Intelligence — syllabus-boundary fix.
--
-- The hard syllabus boundary (education_syllabus_boundary.ts) falls back to the
-- global `subject_templates` catalogue when a school has not yet materialised its
-- own `syllabus_chapters` for a class + subject. The edge runs as the non-bypass
-- `erp_tenant` role, which had no SELECT grant on `subject_templates`, so that
-- fallback raised "permission denied for table subject_templates" → a 500 instead
-- of the intended 422 OFF_SYLLABUS (or a clean on-catalogue validation).
--
-- `subject_templates` is a global, board-agnostic reference catalogue (no tenant
-- data, RLS off), so a plain read grant is correct and safe — mirrors how other
-- reference catalogues (e.g. widget_registry) are exposed to tenants.

GRANT SELECT ON subject_templates TO erp_tenant;
