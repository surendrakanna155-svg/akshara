// PRC-A Batch 2 — Gate Pass / Early Pickup HTTP handlers.
//
//   POST /gate-passes                requestGatePass  (parent or staff) — raise
//   GET  /gate-passes                requestGatePass | approveGatePass | verifyGatePass — the queue
//   GET  /gate-passes/:id            same as above — detail
//   POST /gate-passes/:id/verify     verifyGatePass   (office staff) — the gate check
//   POST /gate-passes/:id/cancel     requester (staff) or approveGatePass — withdraw
//
// Deciding (approve/reject) is NOT here — it goes through the existing generic
// F2 approval endpoints (orchestrateApprovalDecision -> applyApprovalTypeHandler
// -> applyGatePassDecision in gate_pass_repository.ts).

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { submitApproval } from "../approval/approval_repository.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  cancelGatePass,
  createGatePass,
  GATE_PASS_TYPES,
  type GatePassRow,
  GatePassError,
  gatePassToApi,
  getGatePassForParent,
  getGatePassForStaff,
  linkApprovalRequest,
  listGatePassesForParent,
  listGatePassesForSchool,
  parentOwnsStudent,
  studentExistsInSchool,
  verifyGatePassCredential,
  GatePassVerificationFailedError,
} from "./gate_pass_repository.ts";

type Claims = AccessTokenClaims;

function requireRaiseScope(claims: Claims): Response | null {
  if (claims.scope === "school" && claims.school_id) return null;
  if (claims.scope === "parent" && claims.school_id) return null;
  return errorEnvelope("FORBIDDEN", "Gate pass requires a school or parent session", 403);
}

function requireQueueAccess(claims: Claims): Response | null {
  return requireAnyPermission(claims, ["requestGatePass", "approveGatePass", "verifyGatePass"]) ??
    requireRaiseScope(claims);
}

function str(body: Record<string, unknown>, snake: string, camel: string, fallback = ""): string {
  if (snake in body && body[snake] != null) return String(body[snake]).trim();
  if (camel in body && body[camel] != null) return String(body[camel]).trim();
  return fallback;
}

function gatePassErrorResponse(e: GatePassError): Response {
  return errorEnvelope(`GATE_PASS_${e.code}`, e.message, e.status);
}

// ── POST /gate-passes ────────────────────────────────────────────────────────
export async function handleCreateGatePass(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "requestGatePass") ?? requireRaiseScope(auth.claims);
  if (denied) return denied;

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const studentId = str(body, "student_id", "studentId");
  if (!studentId) {
    return errorEnvelope("VALIDATION_ERROR", "studentId is required", 422);
  }
  const passType = str(body, "pass_type", "passType");
  if (!(GATE_PASS_TYPES as readonly string[]).includes(passType)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `passType must be one of ${GATE_PASS_TYPES.join(", ")}`,
      422,
    );
  }
  const scheduledAtRaw = str(body, "scheduled_at", "scheduledAt");
  const scheduledAtDate = new Date(scheduledAtRaw);
  if (!scheduledAtRaw || Number.isNaN(scheduledAtDate.getTime())) {
    return errorEnvelope("VALIDATION_ERROR", "scheduledAt must be a valid timestamp", 422);
  }
  const reason = str(body, "reason", "reason");
  const pickupPersonName = str(body, "pickup_person_name", "pickupPersonName");
  const pickupPersonRelation = str(body, "pickup_person_relation", "pickupPersonRelation");
  const pickupPersonPhone = str(body, "pickup_person_phone", "pickupPersonPhone");
  const requesterName = str(body, "requester_name", "requesterName") ||
    (auth.claims.scope === "parent" ? "Parent" : "Staff");

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const requestedBy = auth.claims.sub;

  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const exists = await studentExistsInSchool(db, orgId, schoolId, studentId);
      if (!exists) {
        throw new GatePassError("STUDENT_NOT_FOUND", "Student not found in your school", 404);
      }
      if (auth.claims.scope === "parent") {
        const owns = await parentOwnsStudent(db, orgId, schoolId, requestedBy, studentId);
        if (!owns) {
          throw new GatePassError(
            "NOT_YOUR_CHILD",
            "You may only raise a gate pass for your own child",
            403,
          );
        }
      }

      const row = await createGatePass(db, orgId, schoolId, {
        studentId,
        passType: passType as (typeof GATE_PASS_TYPES)[number],
        reason,
        requestedBy,
        pickupPersonName,
        pickupPersonRelation,
        pickupPersonPhone,
        scheduledAt: scheduledAtDate.toISOString(),
      });

      const approval = await submitApproval(db, orgId, schoolId, {
        type: "gatePass",
        title: `Gate pass — ${passType.replace(/_/g, " ")}`,
        summary: reason || passType.replace(/_/g, " "),
        requesterId: requestedBy,
        requesterName,
        entityType: "gate_pass",
        entityId: row.id,
        payload: { studentId, passType, scheduledAt: scheduledAtDate.toISOString() },
      });

      const linked = await linkApprovalRequest(db, orgId, schoolId, row.id, approval.id);
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("gatePass.pass.raised", "gate_pass", linked.id, {
          studentId,
          passType,
        }),
        req,
      );
      return linked;
    });
    return jsonResponse(envelope(gatePassToApi(created)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof GatePassError) return gatePassErrorResponse(error);
    throw error;
  }
}

// ── GET /gate-passes ─────────────────────────────────────────────────────────
export async function handleListGatePasses(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireQueueAccess(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const status = url.searchParams.get("status") ?? undefined;
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows: GatePassRow[] = await withTenantContext(config, auth.claims, (db) => {
      if (auth.claims.scope === "parent") {
        return listGatePassesForParent(db, orgId, schoolId, auth.claims.sub, status);
      }
      return listGatePassesForSchool(db, orgId, schoolId, status);
    });
    return jsonResponse(envelope({ items: rows.map((r) => gatePassToApi(r)), count: rows.length }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

// ── GET /gate-passes/:id ─────────────────────────────────────────────────────
export async function handleGetGatePass(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireQueueAccess(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, (db) => {
      if (auth.claims.scope === "parent") {
        return getGatePassForParent(db, orgId, schoolId, auth.claims.sub, id);
      }
      return getGatePassForStaff(db, orgId, schoolId, id);
    });
    if (!row) return errorEnvelope("NOT_FOUND", `Gate pass not found: ${id}`, 404);
    return jsonResponse(envelope(gatePassToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

// ── POST /gate-passes/:id/verify ─────────────────────────────────────────────
export async function handleVerifyGatePass(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "verifyGatePass") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const credential = str(body, "credential", "credential") ||
    str(body, "otp", "otp") ||
    str(body, "qr_token", "qrToken");
  if (!credential) {
    return errorEnvelope("VALIDATION_ERROR", "otp or qrToken is required", 422);
  }
  const note = str(body, "note", "note") || null;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const verified = await verifyGatePassCredential(
        db,
        orgId,
        schoolId,
        id,
        credential,
        auth.claims.sub,
        note,
      );
      // "Who released this child, and when" is THE audit question this module
      // exists to answer. Emitted inside the same transaction as the guarded
      // status flip, so an audit row cannot survive a rolled-back release.
      // The credential itself is never recorded — only the fact of the release.
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("gatePass.pass.verified", "gate_pass", verified.id, {
          studentId: verified.student_id,
          passType: verified.pass_type,
        }),
        req,
      );
      return verified;
    });
    return jsonResponse(envelope({ ...gatePassToApi(row), verified: true }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof GatePassVerificationFailedError) {
      // Deliberately generic — never confirms/denies pass existence or which
      // check failed (status/expiry/hash mismatch all look identical here).
      return errorEnvelope(
        "GATE_PASS_VERIFICATION_FAILED",
        "This gate pass credential is invalid, expired, or already used",
        422,
      );
    }
    throw error;
  }
}

// ── POST /gate-passes/:id/cancel ─────────────────────────────────────────────
// Only a school-scoped caller can write here (the migration grants UPDATE to
// the `school` RLS scope only — a parent-raised pass is withdrawn by staff,
// not directly by the parent; see the migration header + this module's
// gate_pass RLS policies for the rationale).
export async function handleCancelGatePass(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["requestGatePass", "approveGatePass"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const actorCanApprove = auth.claims.permissions.includes("approveGatePass");

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const cancelled = await cancelGatePass(
        db,
        orgId,
        schoolId,
        id,
        auth.claims.sub,
        actorCanApprove,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("gatePass.pass.cancelled", "gate_pass", cancelled.id, {
          studentId: cancelled.student_id,
        }),
        req,
      );
      return cancelled;
    });
    return jsonResponse(envelope(gatePassToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof GatePassError) return gatePassErrorResponse(error);
    throw error;
  }
}
