import type { AppConfig } from "../config.ts";
import {
  boolOr,
  createModuleWriteHandlers,
  requireStr,
  str,
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { resolveStudentId } from "./sis_student_resolver.ts";
import {
  addGuardianLink,
  deactivateGuardianLink,
  type GuardianLinkRow,
  GuardianLinkNotFoundError,
  LastGuardianError,
  listGuardianLinks,
} from "./sis_guardians_repository.ts";

/**
 * PRA-P1-01 / PRA-P1-02 (S2) — guardian link management endpoints.
 *
 * Managing a student's guardians is registrar-level authority — the SAME
 * authority as editing the student record — so both endpoints gate on the SIS
 * student-master write permission `manageSis` (via the shared write harness),
 * exactly like `handleCreateStudent` / `handleUpdateStudent`.
 */
const { runWrite } = createModuleWriteHandlers("manageSis");

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Map a guardian-link row to the camelCase API shape used elsewhere in SIS. */
function guardianLinkToApi(row: GuardianLinkRow): Record<string, unknown> {
  return {
    id: row.id,
    guardianUserId: row.guardian_user_id,
    relationship: row.relationship,
    isPrimary: row.is_primary,
    status: row.status,
  };
}

/**
 * PRA-P1-01 (S2) — POST /sis/students/{studentId}/guardians
 * Body: `{ guardianUserId, relationship?, isPrimary? }`.
 *
 * Adds (or re-activates) a guardian link for the student. The path id may be a
 * UUID, student_code, or admission number (resolved to the canonical id, and
 * out-of-scope / unknown → 404, never leaking another school's roster).
 */
export async function handleAddGuardian(
  req: Request,
  config: AppConfig,
  studentIdOrCode: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;

    const guardianUserId = requireStr(body, "guardianUserId", "guardian_user_id");
    if (!UUID_SEGMENT.test(guardianUserId)) {
      throw new WriteValidationError("guardianUserId must be a valid user id");
    }
    const relationship = str(body, "relationship") ?? "guardian";
    // A second guardian is NOT primary by default — primacy must be explicit.
    const isPrimary = boolOr(body, false, "isPrimary", "is_primary");

    const studentId = await resolveStudentId(db, organizationId, schoolId, studentIdOrCode);
    if (!studentId) {
      throw new WriteNotFoundError(`Student not found: ${studentIdOrCode}`);
    }

    const link = await addGuardianLink(
      db,
      organizationId,
      schoolId,
      studentId,
      guardianUserId,
      { relationship, isPrimary },
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("sis.guardian.linked", "student_guardian", link.id, {
        studentId,
        guardianUserId,
        relationship: link.relationship,
        isPrimary: link.is_primary,
      }),
      request,
    );

    const guardians = await listGuardianLinks(db, organizationId, schoolId, studentId);
    return {
      payload: {
        studentId,
        guardian: guardianLinkToApi(link),
        guardians: guardians.map(guardianLinkToApi),
      },
      status: 201,
    };
  });
}

/**
 * PRA-P1-02 (S2) — DELETE /sis/students/{studentId}/guardians/{guardianUserId}
 *
 * Unlinks a guardian by setting the link `status='inactive'` (soft — the row is
 * retained for history). Refuses to unlink a guardian that is already inactive /
 * never linked (404) or the student's LAST active guardian (409).
 */
export async function handleRemoveGuardian(
  req: Request,
  config: AppConfig,
  studentIdOrCode: string,
  guardianUserId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;

    const studentId = await resolveStudentId(db, organizationId, schoolId, studentIdOrCode);
    if (!studentId) {
      throw new WriteNotFoundError(`Student not found: ${studentIdOrCode}`);
    }

    let linkId: string;
    try {
      linkId = await deactivateGuardianLink(
        db,
        organizationId,
        schoolId,
        studentId,
        guardianUserId,
      );
    } catch (error) {
      // Translate the repository's typed errors into the harness's HTTP-mapped
      // errors: not-found → 404, last-guardian → 409.
      if (error instanceof GuardianLinkNotFoundError) {
        throw new WriteNotFoundError(error.message);
      }
      if (error instanceof LastGuardianError) {
        throw new WriteValidationError(error.message, 409, "LAST_GUARDIAN");
      }
      throw error;
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("sis.guardian.unlinked", "student_guardian", linkId, {
        studentId,
        guardianUserId,
      }),
      request,
    );

    return {
      payload: { studentId, guardianUserId, linkId, status: "inactive" },
      status: 200,
    };
  });
}
