// P1-PROD-22 SLICE 1 — Staff Face ID enrollment handlers.
//
// docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §7: a staff member enrols their OWN
// reference face by default; this slice additionally allows an HR-managed
// enrollment/revocation of ANOTHER user's reference face (body.targetUserId),
// gated by the `manageHr` permission — the identity decision (self vs. other)
// is an application-layer check, RLS only enforces the org+school wall (see
// migration 20260877's header comment). The embedding vector is NEVER returned
// to the client. The check-in verification chain (geofence -> anti-mock ->
// liveness -> match -> check-in) is SLICE 2 and is NOT built here —
// face_match.ts is exported for it.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
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
import { recordMutationAudit } from "../audit/audit_repository.ts";
import { attendanceAuthAudit } from "../audit/mutation_audit_catalog.ts";
import {
  type AttendanceAuthScope,
  enrollFace,
  FaceEnrollmentValidationError,
  getActiveEnrollment,
  revokeEnrollment,
} from "./face_enrollment_repository.ts";

function scopeOf(claims: AccessTokenClaims): AttendanceAuthScope {
  return {
    organizationId: organizationIdFromClaims(claims),
    schoolId: schoolIdFromClaims(claims),
  };
}

function validationResponse(e: FaceEnrollmentValidationError): Response {
  // ENROLLMENT_CONFLICT is a lost race with a concurrent enrol, not a bad
  // payload — 409 tells the client to simply retry.
  const status = e.code === "ENROLLMENT_CONFLICT" ? 409 : 422;
  return errorEnvelope(`ATTENDANCE_AUTH_${e.code}`, e.message, status);
}

/**
 * A caller always acts on their OWN enrollment unless the body names a
 * DIFFERENT targetUserId — that HR-managed path requires `manageHr`. Returns
 * the resolved userId to act on, or a denial Response to return as-is.
 */
function resolveTarget(
  claims: AccessTokenClaims,
  body: Record<string, unknown> | null,
): { userId: string } | Response {
  const raw = body?.targetUserId ?? body?.target_user_id;
  // Only a plain string is a candidate target; an object/array coerced via
  // String() would flow a non-UUID into the query and surface as a raw 500
  // (audit R3 P3) — reject the shape as a typed 422 instead. resolveTarget is
  // called before the handlers' try blocks, so this returns a Response (the
  // function's existing denial pattern) rather than throwing.
  if (raw != null && typeof raw !== "string") {
    return errorEnvelope(
      "ATTENDANCE_AUTH_TARGET_INVALID",
      "targetUserId must be a string user id",
      422,
    );
  }
  const targetUserId = raw != null ? raw.trim() : "";
  const selfId = claims.sub;
  if (!targetUserId || targetUserId === selfId) {
    return { userId: selfId };
  }
  const denied = requirePermission(claims, "manageHr");
  if (denied) return denied;
  return { userId: targetUserId };
}

// ── POST /attendance-auth/face/enroll ────────────────────────────────────────
export async function handleEnrollFace(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const claims = auth.claims;
  const scopeDenied = requireSchoolOperationalScope(claims);
  if (scopeDenied) return scopeDenied;

  const body = await readJson<Record<string, unknown>>(req);
  const target = resolveTarget(claims, body);
  if (target instanceof Response) return target;

  const modelTagRaw = body?.modelTag ?? body?.model_tag;
  const modelTag = typeof modelTagRaw === "string" ? modelTagRaw : "";

  try {
    const result = await withTenantContext(config, claims, async (db) => {
      const enrollment = await enrollFace(db, scopeOf(claims), {
        userId: target.userId,
        embedding: body?.embedding,
        modelTag,
        enrolledBy: claims.sub,
      });
      const spec = attendanceAuthAudit.faceEnrolled(enrollment.id, target.userId, claims.sub);
      await recordMutationAudit(db, claims, spec.audit, spec.domain, req);
      return enrollment;
    });

    return jsonResponse(
      envelope({
        id: result.id,
        embeddingDims: result.embeddingDims,
        modelTag: result.modelTag,
        enrolledAt: result.createdAt,
      }),
      { status: 201 },
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse();
    if (error instanceof FaceEnrollmentValidationError) return validationResponse(error);
    throw error;
  }
}

// ── GET /attendance-auth/face/enrollment ─────────────────────────────────────
// Self status only — NEVER returns the embedding vector to the client.
export async function handleGetEnrollmentStatus(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const claims = auth.claims;
  const scopeDenied = requireSchoolOperationalScope(claims);
  if (scopeDenied) return scopeDenied;

  try {
    const enrollment = await withTenantContext(
      config,
      claims,
      (db) => getActiveEnrollment(db, scopeOf(claims), claims.sub),
    );
    if (!enrollment) {
      return jsonResponse(envelope({ enrolled: false, modelTag: null, enrolledAt: null }));
    }
    return jsonResponse(envelope({
      enrolled: true,
      modelTag: enrollment.modelTag,
      enrolledAt: enrollment.createdAt,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse();
    throw error;
  }
}

// ── POST /attendance-auth/face/revoke ────────────────────────────────────────
export async function handleRevokeFaceEnrollment(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const claims = auth.claims;
  const scopeDenied = requireSchoolOperationalScope(claims);
  if (scopeDenied) return scopeDenied;

  const body = await readJson<Record<string, unknown>>(req);
  const target = resolveTarget(claims, body);
  if (target instanceof Response) return target;

  try {
    const revoked = await withTenantContext(config, claims, async (db) => {
      const result = await revokeEnrollment(db, scopeOf(claims), target.userId, claims.sub);
      if (result) {
        const spec = attendanceAuthAudit.faceRevoked(result.id, target.userId, claims.sub);
        await recordMutationAudit(db, claims, spec.audit, spec.domain, req);
      }
      return result;
    });

    if (!revoked) {
      return errorEnvelope(
        "ATTENDANCE_AUTH_NOT_ENROLLED",
        "No active face enrollment to revoke",
        404,
      );
    }
    return jsonResponse(envelope({ revoked: true }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse();
    throw error;
  }
}
