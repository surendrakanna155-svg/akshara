import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { listEnvelope } from "../finance/finance_mapper.ts";
import type { StudentScopedEntityReadStore } from "./student_scoped_entity_read_store.ts";

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

async function runTenant<T>(
  config: AppConfig,
  claims: AccessTokenClaims,
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function requireParentScope(claims: AccessTokenClaims): Response | null {
  if (claims.scope !== "parent" || !claims.school_id) {
    return errorEnvelope("FORBIDDEN", "Parent data requires parent scope", 403);
  }
  return null;
}

function requireStudentScope(claims: AccessTokenClaims): Response | null {
  if (claims.scope !== "student" || !claims.school_id || !claims.student_id) {
    return errorEnvelope("FORBIDDEN", "Student data requires student scope", 403);
  }
  return null;
}

function resolveParentStudentId(
  claims: AccessTokenClaims,
  url: URL,
): string | Response {
  const activeChildId = url.searchParams.get("activeChildId");
  if (activeChildId) {
    if (!claims.child_ids.includes(activeChildId)) {
      return errorEnvelope(
        "FORBIDDEN",
        "Active child not linked to parent account",
        403,
      );
    }
    return activeChildId;
  }
  if (claims.child_ids.length === 0) {
    return errorEnvelope("FORBIDDEN", "No linked children on parent account", 403);
  }
  return claims.child_ids[0];
}

export function createParentScopedReadHandlers(
  store: StudentScopedEntityReadStore,
) {
  function requireRead(claims: AccessTokenClaims): Response | null {
    return requireParentScope(claims);
  }

  async function resolveParentSnapshot(
    db: Parameters<StudentScopedEntityReadStore["getSnapshot"]>[0],
    orgId: string,
    schoolId: string,
    studentId: string,
    entityType: string,
  ): Promise<Record<string, unknown>> {
    try {
      return await store.getSnapshot(db, orgId, schoolId, studentId, entityType);
    } catch (error) {
      if (!(error instanceof store.SnapshotNotFoundError)) {
        throw error;
      }
      const {
        buildDefaultParentSnapshot,
        loadStudentParentSnapshotContext,
      } = await import("../pilot/pilot_operations_repository.ts");
      const context = await loadStudentParentSnapshotContext(
        db,
        orgId,
        schoolId,
        studentId,
      );
      return buildDefaultParentSnapshot(entityType, context);
    }
  }

  async function handleSnapshot(
    req: Request,
    config: AppConfig,
    entityType: string,
    notFoundMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const studentIdResult = resolveParentStudentId(auth.claims, url);
    if (studentIdResult instanceof Response) return studentIdResult;

    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const snapshot = await runTenant(config, auth.claims, async (db) => {
        const resolved = await resolveParentSnapshot(
          db,
          orgId,
          schoolId,
          studentIdResult,
          entityType,
        );
        if (entityType === "snapshot_fees") {
          const { overlayFeesSnapshotFromFinance } = await import(
            "../pilot/pilot_operations_repository.ts"
          );
          return await overlayFeesSnapshotFromFinance(
            db,
            orgId,
            schoolId,
            studentIdResult,
            resolved,
          );
        }
        if (entityType === "snapshot_exams") {
          const { overlayExamsSnapshotFromResults } = await import(
            "../pilot/pilot_operations_repository.ts"
          );
          return await overlayExamsSnapshotFromResults(
            db,
            orgId,
            schoolId,
            studentIdResult,
            resolved,
          );
        }
        return resolved;
      });
      return jsonResponse(envelope(snapshot));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.SnapshotNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error(`parent snapshot(${entityType}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  async function handleAttendanceSnapshot(
    req: Request,
    config: AppConfig,
    notFoundMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const studentIdResult = resolveParentStudentId(auth.claims, url);
    if (studentIdResult instanceof Response) return studentIdResult;

    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);
    const month = url.searchParams.get("month");

    try {
      const payload = await runTenant(config, auth.claims, async (db) => {
        const snapshot = await resolveParentSnapshot(
          db,
          orgId,
          schoolId,
          studentIdResult,
          "snapshot_attendance",
        );
        const { overlayAttendanceSnapshotFromRecords } = await import(
          "../pilot/pilot_operations_repository.ts"
        );
        const merged = await overlayAttendanceSnapshotFromRecords(
          db,
          orgId,
          schoolId,
          studentIdResult,
          snapshot,
        );
        return month ? { ...merged, month } : merged;
      });
      return jsonResponse(envelope(payload));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.SnapshotNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error("parent attendance snapshot error:", error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  async function handleTimetableSnapshot(
    req: Request,
    config: AppConfig,
    notFoundMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const studentIdResult = resolveParentStudentId(auth.claims, url);
    if (studentIdResult instanceof Response) return studentIdResult;

    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const payload = await runTenant(config, auth.claims, async (db) => {
        const snapshot = await resolveParentSnapshot(
          db,
          orgId,
          schoolId,
          studentIdResult,
          "snapshot_timetable",
        );
        const { overlayTimetableSnapshotFromSlots } = await import(
          "../pilot/pilot_operations_repository.ts"
        );
        return await overlayTimetableSnapshotFromSlots(
          db,
          orgId,
          schoolId,
          snapshot,
          {
            view: "parent",
            classLabel: String(snapshot.childClass ?? ""),
          },
        );
      });
      return jsonResponse(envelope(payload));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.SnapshotNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error("parent timetable snapshot error:", error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  async function handleList(
    req: Request,
    config: AppConfig,
    entityType: string,
    errorMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const studentIdResult = resolveParentStudentId(auth.claims, url);
    if (studentIdResult instanceof Response) return studentIdResult;

    const pagination = parsePagination(url);
    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const result = await runTenant(config, auth.claims, async (db) =>
        await store.listEntities(
          db,
          orgId,
          schoolId,
          studentIdResult,
          entityType,
          pagination,
        )
      );
      return jsonResponse(
        envelope(
          listEnvelope(result.items, {
            page: result.page,
            pageSize: result.pageSize,
            total: result.total,
            hasMore: result.hasMore,
          }),
        ),
      );
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      console.error(`parent list(${entityType}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
    }
  }

  async function handleDetail(
    req: Request,
    config: AppConfig,
    entityType: string,
    entityId: string,
    notFoundMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const studentIdResult = resolveParentStudentId(auth.claims, url);
    if (studentIdResult instanceof Response) return studentIdResult;

    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const entity = await runTenant(config, auth.claims, async (db) =>
        await store.getEntity(
          db,
          orgId,
          schoolId,
          studentIdResult,
          entityType,
          entityId,
        )
      );
      return jsonResponse(envelope(entity));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.EntityNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error(`parent detail(${entityType}/${entityId}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  async function handleFinanceReceipts(
    req: Request,
    config: AppConfig,
    errorMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const studentIdResult = resolveParentStudentId(auth.claims, url);
    if (studentIdResult instanceof Response) return studentIdResult;

    const pagination = parsePagination(url);
    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const result = await runTenant(config, auth.claims, async (db) => {
        const { overlayReceiptsFromFinance } = await import(
          "../pilot/pilot_operations_repository.ts"
        );
        return await overlayReceiptsFromFinance(
          db,
          orgId,
          schoolId,
          studentIdResult,
          pagination,
        );
      });
      return jsonResponse(
        envelope(
          listEnvelope(result.items, {
            page: result.page,
            pageSize: result.pageSize,
            total: result.total,
            hasMore: result.hasMore,
          }),
        ),
      );
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      console.error("parent finance receipts error:", error);
      return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
    }
  }

  return {
    handleSnapshot,
    handleAttendanceSnapshot,
    handleTimetableSnapshot,
    handleList,
    handleDetail,
    handleFinanceReceipts,
  };
}

export function createStudentScopedReadHandlers(
  store: StudentScopedEntityReadStore,
) {
  function requireRead(claims: AccessTokenClaims): Response | null {
    return requireStudentScope(claims);
  }

  function studentIdFromClaims(claims: AccessTokenClaims): string {
    if (!claims.student_id) {
      throw new Error("student_id missing from JWT claims");
    }
    return claims.student_id;
  }

  async function handleSnapshot(
    req: Request,
    config: AppConfig,
    entityType: string,
    notFoundMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);
    const studentId = studentIdFromClaims(auth.claims);

    try {
      const snapshot = await runTenant(config, auth.claims, async (db) => {
        const resolved = await store.getSnapshot(db, orgId, schoolId, studentId, entityType);
        if (entityType === "snapshot_exams") {
          const { overlayExamsSnapshotFromResults } = await import(
            "../pilot/pilot_operations_repository.ts"
          );
          return await overlayExamsSnapshotFromResults(
            db,
            orgId,
            schoolId,
            studentId,
            resolved as Record<string, unknown>,
          );
        }
        return resolved;
      });
      return jsonResponse(envelope(snapshot));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.SnapshotNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error(`student snapshot(${entityType}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  async function handleAttendanceSnapshot(
    req: Request,
    config: AppConfig,
    notFoundMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const month = url.searchParams.get("month");
    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);
    const studentId = studentIdFromClaims(auth.claims);

    try {
      const payload = await runTenant(config, auth.claims, async (db) => {
        const snapshot = await store.getSnapshot(
          db,
          orgId,
          schoolId,
          studentId,
          "snapshot_attendance",
        );
        const { overlayAttendanceSnapshotFromRecords } = await import(
          "../pilot/pilot_operations_repository.ts"
        );
        const merged = await overlayAttendanceSnapshotFromRecords(
          db,
          orgId,
          schoolId,
          studentId,
          snapshot as Record<string, unknown>,
        );
        return month ? { ...merged, month } : merged;
      });
      return jsonResponse(envelope(payload));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.SnapshotNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error("student attendance snapshot error:", error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  async function handleTimetableSnapshot(
    req: Request,
    config: AppConfig,
    notFoundMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);
    const studentId = studentIdFromClaims(auth.claims);

    try {
      const payload = await runTenant(config, auth.claims, async (db) => {
        const snapshot = await store.getSnapshot(
          db,
          orgId,
          schoolId,
          studentId,
          "snapshot_timetable",
        );
        const { overlayTimetableSnapshotFromSlots } = await import(
          "../pilot/pilot_operations_repository.ts"
        );
        return await overlayTimetableSnapshotFromSlots(
          db,
          orgId,
          schoolId,
          snapshot as Record<string, unknown>,
          {
            view: "student",
            classLabel: String(
              (snapshot as Record<string, unknown>).classLabel ?? "",
            ),
          },
        );
      });
      return jsonResponse(envelope(payload));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.SnapshotNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error("student timetable snapshot error:", error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  async function handleList(
    req: Request,
    config: AppConfig,
    entityType: string,
    errorMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const pagination = parsePagination(url);
    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);
    const studentId = studentIdFromClaims(auth.claims);

    try {
      const result = await runTenant(config, auth.claims, async (db) => {
        const listed = await store.listEntities(
          db,
          orgId,
          schoolId,
          studentId,
          entityType,
          pagination,
        );
        // MJ-H7 (belt-and-suspenders): overlay the student's homework items with
        // their own homework_submissions so a graded item reflects 'reviewed'
        // (+ grade/comment) even if the review write-back to student_entities
        // was missed. Keeps the student list authoritative against real data.
        if (entityType === "homework_item") {
          const { overlayStudentHomeworkFromSubmissions } = await import(
            "../pilot/pilot_operations_repository.ts"
          );
          const items = await overlayStudentHomeworkFromSubmissions(
            db,
            orgId,
            schoolId,
            studentId,
            listed.items,
          );
          return { ...listed, items };
        }
        return listed;
      });
      return jsonResponse(
        envelope(
          listEnvelope(result.items, {
            page: result.page,
            pageSize: result.pageSize,
            total: result.total,
            hasMore: result.hasMore,
          }),
        ),
      );
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      console.error(`student list(${entityType}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
    }
  }

  return {
    handleSnapshot,
    handleAttendanceSnapshot,
    handleTimetableSnapshot,
    handleList,
  };
}

import type { EntityReadStore } from "./entity_read_store.ts";

export function createTeacherMobileReadHandlers(
  store: EntityReadStore,
) {
  function requireRead(claims: AccessTokenClaims): Response | null {
    return requirePermission(claims, "viewAdminHub") ??
      requireSchoolOperationalScope(claims);
  }

  async function handleSnapshot(
    req: Request,
    config: AppConfig,
    entityType: string,
    notFoundMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const snapshot = await runTenant(config, auth.claims, async (db) =>
        await store.getSnapshot(db, orgId, schoolId, entityType)
      );
      return jsonResponse(envelope(snapshot));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.SnapshotNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error(`teacher snapshot(${entityType}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  async function handleTimetableSnapshot(
    req: Request,
    config: AppConfig,
    notFoundMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const payload = await runTenant(config, auth.claims, async (db) => {
        const snapshot = await store.getSnapshot(db, orgId, schoolId, "snapshot_timetable");
        const { overlayTimetableSnapshotFromSlots } = await import(
          "../pilot/pilot_operations_repository.ts"
        );
        return await overlayTimetableSnapshotFromSlots(
          db,
          orgId,
          schoolId,
          snapshot as Record<string, unknown>,
          { view: "teacher", teacherUserId: auth.claims.sub },
        );
      });
      return jsonResponse(envelope(payload));
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      if (error instanceof store.SnapshotNotFoundError) {
        return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
      }
      console.error("teacher timetable snapshot error:", error);
      return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
    }
  }

  async function handleList(
    req: Request,
    config: AppConfig,
    entityType: string,
    errorMessage: string,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const pagination = parsePagination(url);
    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const result = await runTenant(config, auth.claims, async (db) =>
        await store.listEntities(db, orgId, schoolId, entityType, pagination)
      );
      return jsonResponse(
        envelope(
          listEnvelope(result.items, {
            page: result.page,
            pageSize: result.pageSize,
            total: result.total,
            hasMore: result.hasMore,
          }),
        ),
      );
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      console.error(`teacher list(${entityType}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
    }
  }

  // Like handleList, but runs an overlay over the listed items (within the same
  // tenant context / RLS) before shaping the envelope. Used by teacher homework
  // (MJ-C2) to attach a real submissions[] array per assignment. RBAC is
  // identical to handleList (requireRead).
  async function handleListWithOverlay(
    req: Request,
    config: AppConfig,
    entityType: string,
    errorMessage: string,
    overlay: (
      db: Parameters<EntityReadStore["listEntities"]>[0],
      orgId: string,
      schoolId: string,
      items: Record<string, unknown>[],
    ) => Promise<Record<string, unknown>[]>,
  ): Promise<Response> {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;

    const denied = requireRead(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const pagination = parsePagination(url);
    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims);

    try {
      const result = await runTenant(config, auth.claims, async (db) => {
        const listed = await store.listEntities(db, orgId, schoolId, entityType, pagination);
        const items = await overlay(db, orgId, schoolId, listed.items);
        return { ...listed, items };
      });
      return jsonResponse(
        envelope(
          listEnvelope(result.items, {
            page: result.page,
            pageSize: result.pageSize,
            total: result.total,
            hasMore: result.hasMore,
          }),
        ),
      );
    } catch (error) {
      if (error instanceof TenantDbNotConfiguredError) {
        return tenantDbNotConfiguredResponse(error);
      }
      console.error(`teacher list+overlay(${entityType}) error:`, error);
      return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
    }
  }

  return { handleSnapshot, handleTimetableSnapshot, handleList, handleListWithOverlay };
}
