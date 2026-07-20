\set ON_ERROR_STOP off
\pset pager off
BEGIN;

-- ═══ PRC-A BATCH 2 — LIVE CERTIFICATION SUITE (real akshara_db) ═══════════════
-- RLS probes SET ROLE erp_tenant + call app.set_request_context(...) — byte-
-- identical to withTenantContext in production — so RLS is genuinely evaluated.
-- Everything inside BEGIN..ROLLBACK. Nothing persists.

CREATE TEMP TABLE r(ord int, probe text, verdict text, evidence text);

CREATE TEMP TABLE f AS
SELECT (SELECT organization_id FROM schools ORDER BY id LIMIT 1) AS orga,
       (SELECT id FROM schools ORDER BY id LIMIT 1)              AS scha,
       (SELECT id FROM users ORDER BY id LIMIT 1)                AS staff,
       gen_random_uuid() AS stua, gen_random_uuid() AS stub,
       gen_random_uuid() AS parenta, gen_random_uuid() AS parentb,
       gen_random_uuid() AS teachert, gen_random_uuid() AS sectionx;

INSERT INTO organizations (id, name, slug)
VALUES (gen_random_uuid(), 'ZZ Probe Org B', 'zz-probe-org-b');
CREATE TEMP TABLE gb AS
SELECT o.id AS orgb, gen_random_uuid() AS schb FROM organizations o WHERE o.slug='zz-probe-org-b';
INSERT INTO schools (id, organization_id, name, code) SELECT schb, orgb, 'ZZ Probe School B', 'ZZPB1' FROM gb;

INSERT INTO students (id, organization_id, school_id, student_code, display_name, status)
SELECT stua, orga, scha, 'ZZ-A-1', 'ZZ Probe StudentA', 'active' FROM f;
INSERT INTO students (id, organization_id, school_id, student_code, display_name, status)
SELECT stub, orga, scha, 'ZZ-B-1', 'ZZ Probe StudentB', 'active' FROM f;

INSERT INTO users (id, phone, display_name) SELECT parenta, '9990000001', 'ZZ ParentA' FROM f;
INSERT INTO users (id, phone, display_name) SELECT parentb, '9990000002', 'ZZ ParentB' FROM f;
INSERT INTO users (id, phone, display_name) SELECT teachert, '9990000003', 'ZZ TeacherT' FROM f;

INSERT INTO student_guardians (organization_id, school_id, student_id, guardian_user_id, relationship, status)
SELECT orga, scha, stua, parenta, 'mother', 'active' FROM f;
INSERT INTO student_guardians (organization_id, school_id, student_id, guardian_user_id, relationship, status)
SELECT orga, scha, stub, parentb, 'father', 'active' FROM f;

INSERT INTO student_care_alerts (organization_id, school_id, student_id, alert_label, action_note, severity, created_by)
SELECT orga, scha, stua, 'ZZ_ALERT_A', 'call infirmary', 'critical', staff FROM f;
INSERT INTO student_care_alerts (organization_id, school_id, student_id, alert_label, action_note, severity, created_by)
SELECT orga, scha, stub, 'ZZ_ALERT_B', 'call infirmary', 'critical', staff FROM f;

INSERT INTO student_health_incidents (organization_id, school_id, student_id, recorded_by, incident_type, outcome, complaint_summary)
SELECT orga, scha, stua, staff, 'illness', 'returned_to_class', 'ZZ_CLINICAL_A' FROM f;

-- Temp fixtures are owned by supabase_admin; erp_tenant must read them after SET ROLE.
GRANT SELECT ON f, gb TO erp_tenant;
GRANT SELECT, INSERT ON r TO erp_tenant;

-- ══ PROBE 1 — RLS TENANT ISOLATION ═══════════════════════════════════════════
SET ROLE erp_tenant;
-- Context = the OTHER tenant (org B). Must see ZERO of org A's health rows.
SELECT app.set_request_context((SELECT orgb FROM gb), 'school', (SELECT staff FROM f), (SELECT schb FROM gb), NULL, NULL, NULL);
INSERT INTO r SELECT 1, 'RLS tenant isolation — org B context reading org A clinical rows',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'student_health_incidents visible to the WRONG tenant = '||count(*)::text||' (expect 0)'
FROM student_health_incidents WHERE complaint_summary='ZZ_CLINICAL_A';
INSERT INTO r SELECT 2, 'RLS tenant isolation — org B context reading org A care alerts',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'student_care_alerts visible to the WRONG tenant = '||count(*)::text||' (expect 0)'
FROM student_care_alerts WHERE alert_label LIKE 'ZZ_ALERT_%';
RESET ROLE;

SET ROLE erp_tenant;
-- Control: the CORRECT tenant must see its own row (proves the probe isn't vacuous).
SELECT app.set_request_context((SELECT orga FROM f), 'school', (SELECT staff FROM f), (SELECT scha FROM f), NULL, NULL, NULL);
INSERT INTO r SELECT 3, 'RLS control — org A context reading its OWN clinical row',
  CASE WHEN count(*)=1 THEN 'PASS' ELSE 'FAIL' END,
  'own-tenant rows visible = '||count(*)::text||' (expect 1 — proves probe 1 is not a false pass)'
FROM student_health_incidents WHERE complaint_summary='ZZ_CLINICAL_A';
RESET ROLE;

-- ══ PROBE 2 — PARENT / GUARDIAN SCOPING ══════════════════════════════════════
SET ROLE erp_tenant;
SELECT app.set_request_context((SELECT orga FROM f), 'parent', (SELECT parenta FROM f), (SELECT scha FROM f), NULL, NULL, (SELECT parenta FROM f));
INSERT INTO r SELECT 4, 'Parent scoping — ParentA sees ONLY their own child''s care alert',
  CASE WHEN count(*) FILTER (WHERE alert_label='ZZ_ALERT_A')=1
        AND count(*) FILTER (WHERE alert_label='ZZ_ALERT_B')=0 THEN 'PASS' ELSE 'FAIL' END,
  'own child alerts='||count(*) FILTER (WHERE alert_label='ZZ_ALERT_A')::text||
  ' (expect 1), OTHER parent''s child alerts='||count(*) FILTER (WHERE alert_label='ZZ_ALERT_B')::text||' (expect 0)'
FROM student_care_alerts WHERE alert_label LIKE 'ZZ_ALERT_%';
RESET ROLE;

-- ══ PROBE 5 — UNIQUE CONSTRAINTS ═════════════════════════════════════════════
SAVEPOINT sp_uq;
INSERT INTO gate_passes (organization_id, school_id, student_id, pass_type, requested_by, scheduled_at, status, reason)
SELECT orga, scha, stua, 'early_pickup', staff, '2026-08-01 10:00:00+00', 'pending', 'first' FROM f;
INSERT INTO gate_passes (organization_id, school_id, student_id, pass_type, requested_by, scheduled_at, status, reason)
SELECT orga, scha, stua, 'early_pickup', staff, '2026-08-01 10:00:00+00', 'pending', 'DUPLICATE' FROM f;
INSERT INTO r VALUES (5, 'Unique constraint — duplicate OPEN gate pass', 'FAIL', 'the duplicate INSERT was ACCEPTED — uq_gate_passes_open_slot did not fire');
ROLLBACK TO SAVEPOINT sp_uq;

SAVEPOINT sp_uq2;
INSERT INTO sis_certificate_requests (organization_id, school_id, student_id, certificate_type, purpose, status, requested_by)
SELECT orga, scha, stua, 'bonafide', 'first', 'pending', staff FROM f;
INSERT INTO sis_certificate_requests (organization_id, school_id, student_id, certificate_type, purpose, status, requested_by)
SELECT orga, scha, stua, 'bonafide', 'DUPLICATE', 'pending', staff FROM f;
INSERT INTO r VALUES (6, 'Unique constraint — duplicate OPEN certificate request', 'FAIL', 'the duplicate INSERT was ACCEPTED — the open-request guard did not fire');
ROLLBACK TO SAVEPOINT sp_uq2;

SELECT ord, probe, verdict, evidence FROM r ORDER BY ord;
ROLLBACK;
