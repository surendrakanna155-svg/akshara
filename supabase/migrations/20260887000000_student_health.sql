-- PRC-A Batch 2 (caps 119–127) — Student Health / Infirmary.
--
-- OWNER DECISION #1 (LOCKED 2026-07-15): build the health module NOW with strict
-- need-to-know least-privilege RBAC. No blanket teacher access; appropriate
-- health staff + explicitly authorised leadership only; teachers get the minimum
-- actionable info for a legitimate care workflow. Tenant isolation + audit on
-- sensitive reads/writes. No health detail via generic search / notifications /
-- analytics / logs / broad profile surfaces.
--
-- This is sensitive medical data about CHILDREN. The schema is built so that the
-- least-privilege split is structural, not merely conventional:
--
--   * The CLINICAL tables (incidents / medication authorizations / the
--     administration log) hold diagnoses, observations, treatment and notes.
--     They are readable ONLY through `viewStudentHealthRecord`, granted to
--     health staff + explicitly authorised leadership (principal/vicePrincipal).
--   * `student_care_alerts` is a SEPARATE table holding ONLY the minimum
--     teacher-actionable facts ("severe peanut allergy — epipen in infirmary,
--     call infirmary immediately"). Teachers read THIS table and never the
--     clinical ones. Because it is a different table rather than a filtered view
--     of the same rows, a teacher's read path cannot accidentally widen into
--     clinical detail via a forgotten column or a `SELECT *`.
--   * `student_health_access_log` records every sensitive read AND write.
--
-- ⚠ HONEST SCOPE OF RLS (read this before assuming more than it does):
--   RLS here is the TENANT + SCOPE backstop. It pins every row to
--   (organization_id, school_id) and adds a parent branch limited to that
--   parent's own children. It CANNOT distinguish "teacher" from "health staff":
--   both hold scope='school' with the same school_id, so both satisfy the
--   school-scope predicate. The control that keeps a teacher out of the clinical
--   tables is the PERMISSION LAYER in the handlers
--   (`viewStudentHealthRecord` is not granted to any teaching role). RLS is what
--   stops school A reading school B and stops a parent reading another child.
--   Both layers are real; neither substitutes for the other. Do not describe
--   these policies as enforcing the health-staff/teacher split — they do not.

-- ─── Roles ───────────────────────────────────────────────────────────────────
-- There is no health-staff role in the catalog. Per owner decision #1
-- ("appropriate health staff"), add a dedicated school-scoped role. Reusing
-- `counselor` would over-grant a different job function (counselling is not
-- infirmary care) — a counselor would silently inherit medication authority.
INSERT INTO role_definitions (slug, display_name, scope) VALUES
  ('healthStaff', 'Health / Infirmary Staff', 'school')
ON CONFLICT (slug) DO NOTHING;

-- ─── Care alerts — the TEACHER surface ───────────────────────────────────────
-- The minimum actionable facts to keep a child safe in class. Written by health
-- staff (`manageStudentHealth`), read by teaching roles
-- (`viewStudentCareAlert`). NOT diagnoses, NOT history, NOT clinical notes.
--
-- `alert_label` + `action_note` are deliberately the ONLY free-text columns: the
-- surface is small enough that a health-staff author can see everything a
-- teacher will see. There is no column here a teacher may not read — which is
-- exactly what makes the least-privilege split reviewable.
CREATE TABLE student_care_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  -- e.g. "Severe peanut allergy"
  alert_label TEXT NOT NULL,
  -- e.g. "Epipen in infirmary. Call infirmary immediately, do not move child."
  action_note TEXT NOT NULL DEFAULT '',
  severity TEXT NOT NULL DEFAULT 'important'
    CHECK (severity IN ('info', 'important', 'critical')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT care_alert_label_not_blank CHECK (btrim(alert_label) <> '')
);

-- The teacher read: active alerts for one student, worst-first.
CREATE INDEX idx_care_alerts_student_active
  ON student_care_alerts (organization_id, school_id, student_id, is_active);

CREATE TRIGGER student_care_alerts_updated_at
  BEFORE UPDATE ON student_care_alerts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE student_care_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_care_alerts FORCE ROW LEVEL SECURITY;

-- School staff read within their own school; a guardian reads their OWN child's
-- alerts (they are the ones who told the school about the allergy).
CREATE POLICY care_alerts_read ON student_care_alerts
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND (
      (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
      OR (
        app_current_scope() = 'parent'
        AND school_id = app_current_school_id()
        AND student_id IN (
          SELECT sg.student_id
          FROM student_guardians sg
          WHERE sg.guardian_user_id = app_current_parent_user_id()
            AND sg.status = 'active'
        )
      )
    )
  );
-- Writes are school-scope only — a parent never authors a care alert.
CREATE POLICY care_alerts_school_insert ON student_care_alerts
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY care_alerts_school_update ON student_care_alerts
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
GRANT SELECT, INSERT, UPDATE ON student_care_alerts TO erp_tenant;

-- ─── Clinical: infirmary incidents ───────────────────────────────────────────
CREATE TABLE student_health_incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- Who flagged it (e.g. the class teacher who sent the child down) — may be
  -- absent when the child self-presents at the infirmary.
  reported_by UUID,
  -- The health-staff member who wrote this record (JWT subject, never client-supplied).
  recorded_by UUID NOT NULL,
  incident_type TEXT NOT NULL,
  complaint_summary TEXT NOT NULL DEFAULT '',
  observations TEXT NOT NULL DEFAULT '',
  treatment_given TEXT NOT NULL DEFAULT '',
  outcome TEXT NOT NULL,
  referred_to TEXT,
  -- Set when the guardian dispatch succeeded; `parent_notification_ref` is the
  -- delivery id. The notification itself carries NO clinical detail.
  parent_notified_at TIMESTAMPTZ,
  parent_notification_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT health_incident_type_check CHECK (
    incident_type IN (
      'illness', 'injury', 'allergic_reaction', 'chronic_episode',
      'routine_checkup', 'other'
    )
  ),
  CONSTRAINT health_incident_outcome_check CHECK (
    outcome IN (
      'returned_to_class', 'sent_home', 'referred_hospital',
      'observation', 'other'
    )
  )
);

CREATE INDEX idx_health_incidents_student
  ON student_health_incidents (organization_id, school_id, student_id, occurred_at DESC);

CREATE TRIGGER student_health_incidents_updated_at
  BEFORE UPDATE ON student_health_incidents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE student_health_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_health_incidents FORCE ROW LEVEL SECURITY;

-- School scope (permission layer narrows this to health staff + authorised
-- leadership) OR the child's own guardian. A guardian has a legitimate right to
-- their own child's health record.
CREATE POLICY health_incidents_read ON student_health_incidents
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND (
      (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
      OR (
        app_current_scope() = 'parent'
        AND school_id = app_current_school_id()
        AND student_id IN (
          SELECT sg.student_id
          FROM student_guardians sg
          WHERE sg.guardian_user_id = app_current_parent_user_id()
            AND sg.status = 'active'
        )
      )
    )
  );
CREATE POLICY health_incidents_school_insert ON student_health_incidents
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY health_incidents_school_update ON student_health_incidents
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
GRANT SELECT, INSERT, UPDATE ON student_health_incidents TO erp_tenant;

-- ─── Clinical: medication authorizations (guardian consent) ──────────────────
-- The school may not administer a medicine to a child without the guardian
-- having authorised it. `authorization_source` + `authorization_ref` are the
-- CONSENT PROVENANCE — how the guardian's consent was actually obtained. An
-- authorization with no provenance is not an authorization.
CREATE TABLE student_medication_authorizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  medication_name TEXT NOT NULL,
  dosage TEXT NOT NULL,
  route TEXT NOT NULL DEFAULT 'oral',
  schedule_note TEXT NOT NULL DEFAULT '',
  valid_from DATE NOT NULL,
  valid_until DATE,
  -- The guardian who authorised (users.id, via student_guardians).
  authorized_by_guardian_id UUID,
  authorization_source TEXT NOT NULL,
  authorization_ref TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'expired', 'revoked')),
  revoked_at TIMESTAMPTZ,
  revoked_by UUID,
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT medication_auth_window_check CHECK (
    valid_until IS NULL OR valid_until >= valid_from
  ),
  CONSTRAINT medication_auth_source_check CHECK (
    authorization_source IN (
      'written_form', 'doctor_prescription', 'in_person', 'parent_portal', 'other'
    )
  ),
  CONSTRAINT medication_auth_name_not_blank CHECK (btrim(medication_name) <> ''),
  -- A revoked row must say who revoked it and when: the revocation is itself a
  -- clinical fact ("stop giving my child this").
  CONSTRAINT medication_auth_revocation_complete CHECK (
    status <> 'revoked'
    OR (revoked_at IS NOT NULL AND revoked_by IS NOT NULL)
  )
);

CREATE INDEX idx_medication_auth_student
  ON student_medication_authorizations (organization_id, school_id, student_id, status);

CREATE TRIGGER student_medication_authorizations_updated_at
  BEFORE UPDATE ON student_medication_authorizations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE student_medication_authorizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_medication_authorizations FORCE ROW LEVEL SECURITY;

CREATE POLICY medication_auth_read ON student_medication_authorizations
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND (
      (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
      OR (
        app_current_scope() = 'parent'
        AND school_id = app_current_school_id()
        AND student_id IN (
          SELECT sg.student_id
          FROM student_guardians sg
          WHERE sg.guardian_user_id = app_current_parent_user_id()
            AND sg.status = 'active'
        )
      )
    )
  );
CREATE POLICY medication_auth_school_insert ON student_medication_authorizations
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
CREATE POLICY medication_auth_school_update ON student_medication_authorizations
  FOR UPDATE USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
GRANT SELECT, INSERT, UPDATE ON student_medication_authorizations TO erp_tenant;

-- ─── Clinical: medication administration log — IMMUTABLE ─────────────────────
-- "We gave this child this drug at this time" is a LEGAL record. It is never
-- edited and never deleted: no UPDATE/DELETE grant and no UPDATE/DELETE policy,
-- so `erp_tenant` has no route to mutate a row even with a crafted query. A
-- mistaken entry is corrected by appending a correcting row, not by rewriting
-- history.
CREATE TABLE student_medication_administration_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  authorization_id UUID NOT NULL
    REFERENCES student_medication_authorizations (id),
  administered_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  administered_by UUID NOT NULL,
  dosage_given TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX idx_medication_admin_log_student
  ON student_medication_administration_log
     (organization_id, school_id, student_id, administered_at DESC);
CREATE INDEX idx_medication_admin_log_authorization
  ON student_medication_administration_log (authorization_id, administered_at DESC);

ALTER TABLE student_medication_administration_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_medication_administration_log FORCE ROW LEVEL SECURITY;

CREATE POLICY medication_admin_log_read ON student_medication_administration_log
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND (
      (
        app_current_scope() = 'school'
        AND school_id = app_current_school_id()
      )
      OR (
        app_current_scope() = 'parent'
        AND school_id = app_current_school_id()
        AND student_id IN (
          SELECT sg.student_id
          FROM student_guardians sg
          WHERE sg.guardian_user_id = app_current_parent_user_id()
            AND sg.status = 'active'
        )
      )
    )
  );
CREATE POLICY medication_admin_log_school_insert ON student_medication_administration_log
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
-- NO update/delete policy — by design.
GRANT SELECT, INSERT ON student_medication_administration_log TO erp_tenant;

-- ─── Audit: sensitive-access log — IMMUTABLE ─────────────────────────────────
-- Who looked at which child's health data, when, and why. Written in the SAME
-- transaction as the read/write it records — an audit row that can be rolled
-- back independently of its event is not an audit.
--
-- `purpose` is free text supplied by the caller; it is a STATED purpose, not a
-- verified one. It exists so an after-the-fact review can ask "why were you
-- reading this child's record?" and have an answer on the record.
CREATE TABLE student_health_access_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  actor_id UUID NOT NULL,
  actor_role TEXT NOT NULL DEFAULT '',
  access_kind TEXT NOT NULL,
  route TEXT NOT NULL DEFAULT '',
  purpose TEXT NOT NULL DEFAULT '',
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- `write_care_alert` is an addition to the kinds named in the build spec.
  -- Authoring a care alert is a distinct act from recording an incident, and
  -- folding it into `write_incident` would make the log say something that did
  -- not happen. An audit log that misdescribes the act it records is worse than
  -- no log, so the kind is explicit.
  CONSTRAINT health_access_kind_check CHECK (
    access_kind IN (
      'view_record', 'view_care_alert', 'write_incident', 'write_care_alert',
      'write_authorization', 'administer_medication', 'revoke_authorization'
    )
  )
);

CREATE INDEX idx_health_access_log_student
  ON student_health_access_log (organization_id, school_id, student_id, occurred_at DESC);
CREATE INDEX idx_health_access_log_actor
  ON student_health_access_log (organization_id, school_id, actor_id, occurred_at DESC);

ALTER TABLE student_health_access_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_health_access_log FORCE ROW LEVEL SECURITY;

-- The access log is a STAFF oversight surface (who in the school read this
-- child's record). It is school-scope read only: no parent branch. A parent
-- asking "who read my child's file?" is a real and legitimate question, but it
-- is a data-subject-access request with its own process, not a self-serve API —
-- and the log names staff members, so exposing it to a parent surface would leak
-- staff identities. Left out deliberately; flagged to the owner rather than
-- guessed at.
CREATE POLICY health_access_log_school_read ON student_health_access_log
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );
-- Any authenticated session that performs a sensitive access must be able to
-- WRITE its own audit row, including the parent branch reading their own child.
-- Otherwise the audit would silently fail-open for exactly the paths that matter.
CREATE POLICY health_access_log_insert ON student_health_access_log
  FOR INSERT WITH CHECK (
    organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
    AND actor_id = app_current_user_id()
  );
-- NO update/delete policy — by design.
GRANT SELECT, INSERT ON student_health_access_log TO erp_tenant;

-- ─── RBAC ────────────────────────────────────────────────────────────────────
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('manageStudentHealth', 'StudentHealth', 'manage', 'school',
   'Record infirmary incidents, medication authorizations and care alerts'),
  ('viewStudentHealthRecord', 'StudentHealth', 'view', 'school',
   'Read a student''s full health record (clinical detail) — health staff + authorised leadership only'),
  ('viewStudentCareAlert', 'StudentHealth', 'view', 'school',
   'Read the minimum actionable care alerts for students the caller teaches'),
  ('administerStudentMedication', 'StudentHealth', 'manage', 'school',
   'Administer medication against a guardian authorization (writes the immutable log)')
ON CONFLICT (slug) DO NOTHING;

-- manageStudentHealth → healthStaff ONLY.
--
-- JUDGEMENT CALL — principal deliberately NOT granted. Recording a clinical
-- observation, authoring a care alert, or capturing a guardian's medication
-- consent are CLINICAL acts by the person who performed them; the record's value
-- is that its author was the person in the room. Leadership's role in owner
-- decision #1 is to be "explicitly authorised" to READ, which
-- `viewStudentHealthRecord` gives them in full. Granting principals write access
-- would let a non-clinical role author clinical fact, which is both a data-
-- quality problem and an accountability problem. If a school genuinely has a
-- principal who doubles as the infirmary lead, the answer is to also give that
-- person the `healthStaff` role — an explicit, auditable act — not to widen the
-- permission for every principal in every tenant.
INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'manageStudentHealth'
FROM role_definitions rd
WHERE rd.slug IN ('healthStaff')
ON CONFLICT DO NOTHING;

-- administerStudentMedication → healthStaff ONLY. Giving a drug to a child is
-- the narrowest act in the module.
INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'administerStudentMedication'
FROM role_definitions rd
WHERE rd.slug IN ('healthStaff')
ON CONFLICT DO NOTHING;

-- viewStudentHealthRecord → health staff + the explicitly authorised leadership.
--
-- Deliberately NOT granted: teacher, classTeacher, coordinator (they get care
-- alerts), officeStaff, schoolAdmin, management, superAdmin, organizationOwner,
-- organizationAdmin. Owner decision #1 says "appropriate health staff +
-- explicitly authorised leadership ONLY" — a generic org/platform admin is an
-- infrastructure role, not a care role, and holds no duty of care to the child.
-- No org-level break-glass is granted here; see the module report for the open
-- owner question.
INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'viewStudentHealthRecord'
FROM role_definitions rd
WHERE rd.slug IN ('healthStaff', 'principal', 'vicePrincipal')
ON CONFLICT DO NOTHING;

-- viewStudentCareAlert → the teaching roles that supervise children, plus the
-- health/leadership roles. The permission alone is NOT sufficient: the handler
-- additionally restricts a caller holding ONLY this permission to students they
-- actually teach (teacher_assignments / timetable_slots).
INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'viewStudentCareAlert'
FROM role_definitions rd
WHERE rd.slug IN (
  'classTeacher', 'teacher', 'coordinator',
  'healthStaff', 'principal', 'vicePrincipal'
)
ON CONFLICT DO NOTHING;
