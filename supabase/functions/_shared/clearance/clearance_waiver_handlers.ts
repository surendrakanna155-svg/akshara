// SCE-1 slice 3 — clearance dues-waiver handlers (maker-checker).
//
//   POST /sis/students/{id}/clearance/waivers   maker raises a waiver (manageSis)
//   GET  /sis/clearance/waivers                 the pending approver queue
//   POST /sis/clearance/waivers/{id}/decide     checker approves/rejects (SoD)
//
// The maker snapshots the current blocking dues; a DIFFERENT checker
// (approveClearanceWaiver) decides. Only an approved, un-consumed waiver that
// still covers the dues lets the clearance gate pass (enforced in the gate).

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { clearanceWaiverAudit, emitMutationAudit } from "../audit/mutation_audit_catalog.ts";
import { StudentNotFoundError } from "../sis/sis_students_repository.ts";
import { resolveStudentId } from "../sis/sis_student_resolver.ts";
import { evaluateClearanceGate } from "./clearance_gate.ts";
import {
  type ClearanceWaiverRow,
  ClearanceWaiverError,
  createWaiver,
  decideWaiver,
  listPendingWaivers,
  revokeApprovedWaiver,
} from "./clearance_waiver_repository.ts";

type AuthedClaims = Parameters<typeof requirePermission>[0];

function requireWaiverMaker(claims: AuthedClaims): Response | null {
  return requirePermission(claims, "manageSis") ??
    requireSchoolOperationalScope(claims);
}

function requireWaiverChecker(claims: AuthedClaims): Response | null {
  return requirePermission(claims, "approveClearanceWaiver") ??
    requireSchoolOperationalScope(claims);
}

function subjectOf(claims: unknown): string {
  return String((claims as { sub?: string }).sub ?? "");
}

/** The maker-raise lifecycle: only the exit events on which finance actually
 * blocks (a waiver on a non-blocking lifecycle would be meaningless). */
const WAIVER_MAKE_LIFECYCLE = "transfer_certificate" as const;

function waiverToApi(r: ClearanceWaiverRow) {
  return {
    id: r.id,
    studentId: r.student_id,
    // Present only on the approver-queue join — the checker must see WHOSE exit
    // they are clearing (audit slice-4 P2).
    ...(r.student_name != null ? { studentName: r.student_name } : {}),
    lifecycle: r.lifecycle,
    reason: r.reason,
    amount: Number(r.blocking_amount ?? 0),
    status: r.status,
    makerId: r.maker_id,
    checkerId: r.checker_id,
    createdAt: r.created_at,
    decidedAt: r.decided_at,
  };
}

function waiverErrorResponse(e: ClearanceWaiverError): Response {
  return errorEnvelope(`CLEARANCE_WAIVER_${e.code}`, e.message, e.status);
}

// ── POST /sis/students/{id}/clearance/waivers ────────────────────────────────
export async function handleCreateClearanceWaiver(
  req: Request,
  config: AppConfig,
  studentIdOrCode: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWaiverMaker(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }
  const reason = String(body.reason ?? "").trim();
  if (reason.length < 3) {
    return errorEnvelope("CLEARANCE_WAIVER_REASON_REQUIRED", "A reason (>=3 chars) is required to waive dues", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const makerId = subjectOf(auth.claims);

  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const resolved = await resolveStudentId(db, orgId, schoolId, studentIdOrCode);
      if (!resolved) throw new StudentNotFoundError(studentIdOrCode);
      // Snapshot the CURRENT blocking dues (the raw gate report, no waiver).
      const report = await evaluateClearanceGate(
        db,
        { organizationId: orgId, schoolId },
        resolved,
        WAIVER_MAKE_LIFECYCLE,
      );
      if (!(report.blockingAmount > 0)) {
        throw new ClearanceWaiverError(
          "NO_DUES_TO_WAIVE",
          "This student has no blocking dues to waive",
        );
      }
      const waiver = await createWaiver(db, { organizationId: orgId, schoolId }, {
        studentId: resolved,
        lifecycle: WAIVER_MAKE_LIFECYCLE,
        reason,
        blockingAmount: report.blockingAmount,
        makerId,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        clearanceWaiverAudit.requested(waiver.id, resolved, WAIVER_MAKE_LIFECYCLE, report.blockingAmount),
        req,
      );
      return waiver;
    });
    return jsonResponse(envelope(waiverToApi(created)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof StudentNotFoundError) return errorEnvelope("NOT_FOUND", error.message, 404);
    if (error instanceof ClearanceWaiverError) return waiverErrorResponse(error);
    throw error;
  }
}

// ── GET /sis/clearance/waivers ───────────────────────────────────────────────
export async function handleListPendingClearanceWaivers(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWaiverChecker(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const limitRaw = Number(url.searchParams.get("limit") ?? "50");
  const limit = Number.isFinite(limitRaw) ? Math.min(100, Math.max(1, Math.trunc(limitRaw))) : 50;
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      listPendingWaivers(db, { organizationId: orgId, schoolId }, limit));
    return jsonResponse(envelope({ items: rows.map(waiverToApi), count: rows.length }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

// ── POST /sis/clearance/waivers/{id}/decide ──────────────────────────────────
export async function handleDecideClearanceWaiver(
  req: Request,
  config: AppConfig,
  waiverId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWaiverChecker(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }
  const approve = body.approve === true || body.approved === true;
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const checkerId = subjectOf(auth.claims);

  try {
    const decided = await withTenantContext(config, auth.claims, async (db) => {
      const out = await decideWaiver(db, { organizationId: orgId, schoolId }, waiverId, checkerId, approve);
      await emitMutationAudit(
        db,
        auth.claims,
        clearanceWaiverAudit.decided(waiverId, checkerId, out.status),
        req,
      );
      return out;
    });
    return jsonResponse(envelope(waiverToApi(decided)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof ClearanceWaiverError) return waiverErrorResponse(error);
    throw error;
  }
}

// ── POST /sis/clearance/waivers/{id}/revoke ──────────────────────────────────
// Checker revokes a stale APPROVED (un-consumed) waiver so a corrective, larger
// waiver can be raised when dues grew past what it covered (audit final P2).
export async function handleRevokeClearanceWaiver(
  req: Request,
  config: AppConfig,
  waiverId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWaiverChecker(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const checkerId = subjectOf(auth.claims);

  try {
    const revoked = await withTenantContext(config, auth.claims, async (db) => {
      const out = await revokeApprovedWaiver(db, { organizationId: orgId, schoolId }, waiverId, checkerId);
      await emitMutationAudit(
        db,
        auth.claims,
        clearanceWaiverAudit.decided(waiverId, checkerId, "revoked"),
        req,
      );
      return out;
    });
    return jsonResponse(envelope(waiverToApi(revoked)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof ClearanceWaiverError) return waiverErrorResponse(error);
    throw error;
  }
}
