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
import {
  admissionsAudit,
  emitMutationAudit,
} from "../audit/mutation_audit_catalog.ts";
import { formatDisplayDateTime } from "./admissions_format.ts";
import {
  approvalToApi,
  enrollmentToApi,
  listEnvelope,
} from "./admissions_mapper.ts";
import {
  getApprovalById,
  getEnrollmentPrefillApplication,
  listPendingApprovals,
  listPendingEnrollments,
} from "./admissions_repository.ts";
import { getReports } from "./admissions_reports_repository.ts";
import { reportsToApi } from "./admissions_reports_mapper.ts";
import {
  addApprovalNote,
  getAdmissionsSettings,
  saveAdmissionsSettings,
} from "./admissions_settings_repository.ts";
// #4: the Fee-Handoff picker needs the same fee-structure catalog Finance
// already maintains. Reuse Finance's read repository + mapper cross-module
// (an established pattern — see transport/library/HR handlers importing
// from ../finance/*) instead of standing up a parallel admissions copy.
import {
  type FinanceFeeStructureItemRow,
  type FinanceFeeStructureRow,
  feeStructureToApi,
} from "../finance/finance_mapper.ts";
import { listFeeStructures } from "../finance/finance_structures_repository.ts";

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

function requireAdmissionsRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "viewAdmissions") ??
    requireSchoolOperationalScope(claims);
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

// ─── MJ-H14: GET /admissions/reports ─────────────────────────────────────────

export async function handleReports(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAdmissionsRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const snapshot = await runTenant(config, auth.claims, (db) =>
      getReports(db, orgId, schoolId)
    );
    return jsonResponse(envelope(reportsToApi(snapshot)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

// ─── MJ-H14: GET /admissions/settings ────────────────────────────────────────

export async function handleSettings(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAdmissionsRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const { settings } = await runTenant(config, auth.claims, (db) =>
      getAdmissionsSettings(db, orgId, schoolId)
    );
    return jsonResponse(envelope(settings));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

// ─── #6: POST /admissions/settings — persist the settings snapshot ───────────

export async function handleSaveSettings(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }
  // Accept either the settings object directly or wrapped under `settings`.
  const settings = (body.settings && typeof body.settings === "object")
    ? body.settings as Record<string, unknown>
    : body;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const saved = await runTenant(config, auth.claims, async (db) => {
      const result = await saveAdmissionsSettings(db, orgId, schoolId, settings);
      await emitMutationAudit(
        db,
        auth.claims,
        admissionsAudit.settingsSaved(schoolId, new Date().toISOString()),
        req,
      );
      return result;
    });
    return jsonResponse(envelope(saved));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

// ─── MJ-H14: GET /admissions/approval-queue ──────────────────────────────────

export async function handleApprovalQueue(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAdmissionsRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listPendingApprovals(db, orgId, schoolId, pagination)
    );
    return jsonResponse(
      envelope(
        listEnvelope(result.items.map(approvalToApi), {
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
    throw error;
  }
}

// ─── MJ-H14: GET /admissions/enrollments/pending ─────────────────────────────

export async function handlePendingEnrollments(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAdmissionsRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listPendingEnrollments(db, orgId, schoolId, pagination)
    );
    return jsonResponse(
      envelope(
        listEnvelope(result.items.map(enrollmentToApi), {
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
    throw error;
  }
}

// ─── MJ-H14: GET /admissions/enrollment/prefill ──────────────────────────────

const DEFAULT_ACADEMIC_YEAR = "2026–27";

export async function handleEnrollmentPrefill(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAdmissionsRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  // Client passes the standard query plus an optional applicationId to pin a
  // specific approved application; absent it we prefill from the most recent.
  const applicationId = url.searchParams.get("applicationId") ??
    url.searchParams.get("application_id");
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const app = await runTenant(config, auth.claims, (db) =>
      getEnrollmentPrefillApplication(db, orgId, schoolId, applicationId)
    );

    // Honest empty state: no approved application to prefill from yet.
    if (!app) {
      return jsonResponse(
        envelope({
          currentStep: "student",
          student: { fullName: "", dateOfBirth: "", gender: "", aadhaar: "" },
          parent: {
            guardianName: "",
            relationship: "",
            phone: "",
            email: "",
            address: "",
          },
          academic: {
            seekingClass: "",
            section: "",
            academicYear: DEFAULT_ACADEMIC_YEAR,
            previousSchool: "",
            needsTransport: false,
            needsHostel: false,
          },
          isSubmitting: false,
          isSubmitted: false,
          generatedAdmissionNumber: null,
          applicationId: null,
        }),
      );
    }

    // Only the fields that genuinely exist on the approved application are
    // prefilled; everything else stays blank for the operator to complete.
    return jsonResponse(
      envelope({
        currentStep: "student",
        student: {
          fullName: app.student_name,
          dateOfBirth: "",
          gender: "",
          aadhaar: "",
        },
        parent: {
          guardianName: app.parent_name,
          relationship: "",
          phone: "",
          email: "",
          address: "",
        },
        academic: {
          seekingClass: app.class_label,
          section: "",
          academicYear: DEFAULT_ACADEMIC_YEAR,
          previousSchool: "",
          needsTransport: false,
          needsHostel: false,
        },
        isSubmitting: false,
        isSubmitted: false,
        generatedAdmissionNumber: null,
        applicationId: app.id,
      }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

// ─── MJ-H15: POST /admissions/approval/{id}/notes ────────────────────────────

export async function handleAddApprovalNote(
  req: Request,
  config: AppConfig,
  approvalId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  // Adding a principal/counselor note is a manage-grade action, matching the
  // other admissions write handlers.
  const denied = requirePermission(auth.claims, "manageAdmissions") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }
  const content = String(body.content ?? "").trim();
  if (!content) {
    return errorEnvelope("VALIDATION_ERROR", "content is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const author = auth.claims.primary_role ?? "Staff";

  try {
    const note = await runTenant(config, auth.claims, async (db) => {
      const approval = await getApprovalById(db, orgId, schoolId, approvalId);
      if (!approval) return null;
      const saved = await addApprovalNote(
        db,
        orgId,
        schoolId,
        approval.application_id,
        author,
        content,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        admissionsAudit.approvalNoteAdded(approvalId, saved.id),
        req,
      );
      return saved;
    });

    if (!note) {
      return errorEnvelope("NOT_FOUND", `Approval not found: ${approvalId}`, 404);
    }

    return jsonResponse(
      envelope({
        id: note.id,
        author: note.author,
        timestampLabel: formatDisplayDateTime(note.createdAt),
        content: note.content,
      }),
      { status: 201 },
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}

// ─── #4: GET /admissions/fee-structures ──────────────────────────────────────
// The Fee-Handoff picker (admissions_fee_handoff_provider.dart) calls this to
// populate `feeStructureId` options before sending an approved student to
// Finance. There is no admissions-owned fee-structure table — Finance already
// owns and exposes this catalog at GET /finance/fee-structures — so this
// reads the same finance_fee_structures rows via Finance's own repository +
// mapper and reshapes them into the admissions client's FeeStructureOption
// contract ({id, label, annualAmount, installments}).

/** Pure, testable reshape from a Finance fee-structure row to the admissions picker's option shape. */
export function feeStructureToAdmissionsOption(
  structure: FinanceFeeStructureRow,
  items: FinanceFeeStructureItemRow[],
): Record<string, unknown> {
  const api = feeStructureToApi(structure, items);
  const installmentOptions = api.installmentOptions;
  return {
    id: api.id,
    label: api.name,
    annualAmount: api.totalAnnual,
    // Finance does not yet track distinct installment plans per structure
    // (installmentOptions is always []); default to 1 rather than fabricate
    // a count, matching the client's own fallback for a missing value.
    installments: Array.isArray(installmentOptions) && installmentOptions.length > 0
      ? installmentOptions.length
      : 1,
  };
}

export async function handleListFeeStructureOptions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireAdmissionsRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const academicYear = url.searchParams.get("academicYear") ??
    url.searchParams.get("academic_year") ?? undefined;
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      listFeeStructures(db, orgId, schoolId, pagination, academicYear || undefined)
    );
    return jsonResponse(
      envelope(
        listEnvelope(
          result.items.map(({ structure, items }) =>
            feeStructureToAdmissionsOption(structure, items)
          ),
          {
            page: result.page,
            pageSize: result.pageSize,
            total: result.total,
            hasMore: result.hasMore,
          },
        ),
      ),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}
