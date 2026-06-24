-- Onboarding rollback — SECURITY DEFINER student deletion (Track A follow-up).
--
-- The edge runs tenant operations as the non-bypass `erp_tenant` role, which is
-- intentionally non-destructive: it holds INSERT/SELECT/UPDATE but NOT DELETE on
-- student tables. Import rollback is the one onboarding path that must hard-delete
-- the exact student rows it created, so it failed with "permission denied" under
-- erp_tenant. Mirror the existing onboarding_upsert_user_by_phone pattern: a
-- SECURITY DEFINER function (owned by the privileged migration role) that performs
-- the scoped deletes, with EXECUTE granted to erp_tenant. The tenant role keeps
-- zero direct DELETE rights; only this audited, org+school-scoped path can remove
-- an onboarding-created student.
--
-- Additive + idempotent (CREATE OR REPLACE). Caller (rollbackImportJob) already
-- validates the job's org/school and only passes student ids it created.

CREATE OR REPLACE FUNCTION onboarding_rollback_student(
  p_student_id uuid,
  p_organization_id uuid,
  p_school_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM student_guardians
   WHERE student_id = p_student_id
     AND organization_id = p_organization_id
     AND school_id = p_school_id;
  DELETE FROM sis_student_enrollments
   WHERE student_id = p_student_id
     AND organization_id = p_organization_id
     AND school_id = p_school_id;
  DELETE FROM student_profiles
   WHERE student_id = p_student_id
     AND organization_id = p_organization_id
     AND school_id = p_school_id;
  DELETE FROM students
   WHERE id = p_student_id
     AND organization_id = p_organization_id
     AND school_id = p_school_id;
END;
$$;

REVOKE ALL ON FUNCTION onboarding_rollback_student(uuid, uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION onboarding_rollback_student(uuid, uuid, uuid) TO erp_tenant;
