// EIP-6 Learning Evidence spine — HTTP handlers (the live callers of the spine).
//
// These are what make the previously-dormant `edu_student_item_responses` table
// a LIVE spine: a real writer (POST) and real readers (GET), RBAC-gated.
//
// RBAC model:
//   • WRITE  — a student-scope session records its OWN evidence (practice /
//     homework self-attempts; studentId is forced to the session's student_id, a
//     body-supplied studentId is ignored). A school-scope session with
//     manageEducation records evidence FOR a student (teacher marks-grid / OMR /
//     graded exam capture).
//   • READ per-student history — the student itself (own only), OR school staff
//     with viewEducation (RLS scopes to their school).
//   • READ item aggregate + concept-mastery seed — school staff only
//     (viewEducation + school scope). These join the school-scoped question bank,
//     so a persona scope would (correctly) see nothing; they are staff analytics.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  requireStudentSelfScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { educationAudit, emitMutationAudit } from "../audit/mutation_audit_catalog.ts";
import {
  getItemResponseAggregate,
  getStudentConceptMastery,
  LearningEvidenceValidationError,
  listStudentItemResponses,
  recordItemResponse,
} from "./learning_evidence_repository.ts";
import {
  type EduEvidenceSource,
  isEvidenceSource,
  toLearningEvidenceContract,
} from "./learning_evidence_contract.ts";

function requireEducationRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "viewEducation") ??
    requireSchoolOperationalScope(claims, "Education");
}

function requireEducationWrite(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "manageEducation") ??
    requireSchoolOperationalScope(claims, "Education");
}

function handleEvidenceError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  if (error instanceof LearningEvidenceValidationError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  const message = error instanceof Error ? error.message : "Learning-evidence operation failed";
  return errorEnvelope("LEARNING_EVIDENCE_ERROR", message, 500);
}

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

interface RecordEvidenceBody {
  studentId?: string;
  itemId?: string;
  source?: EduEvidenceSource;
  contextRef?: string;
  maxMarks?: number;
  attemptNo?: number;
  attempted?: boolean;
  isCorrect?: boolean | null;
  marksAwarded?: number | null;
  timeTakenMs?: number | null;
  confidence?: number | null;
  hintsUsed?: number;
  chosenOption?: number | null;
  itemVersion?: number;
  occurredAt?: string | null;
}

/** POST /education/evidence/responses — record one item interaction as evidence. */
export async function handleRecordItemResponse(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const claims = auth.claims;

  const body = await readJson<RecordEvidenceBody>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);

  // Resolve the subject student under the correct gate.
  let studentId: string;
  if (claims.scope === "student") {
    const denied = requireStudentSelfScope(claims);
    if (denied) return denied;
    // A student records only its OWN evidence; ignore any body studentId.
    studentId = claims.student_id!;
  } else {
    const denied = requireEducationWrite(claims);
    if (denied) return denied;
    if (!body.studentId) {
      return errorEnvelope("VALIDATION_ERROR", "studentId is required", 422);
    }
    studentId = body.studentId;
  }

  if (!body.itemId || !body.contextRef || !isEvidenceSource(body.source)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "itemId, contextRef, and a valid source (practice|homework|exam|omr) are required",
      422,
    );
  }
  if (body.maxMarks == null) {
    return errorEnvelope("VALIDATION_ERROR", "maxMarks is required", 422);
  }

  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);

  try {
    const outcome = await withTenantContext(config, claims, async (db) => {
      const result = await recordItemResponse(db, orgId, schoolId, {
        studentId,
        itemId: body.itemId!,
        source: body.source!,
        contextRef: body.contextRef!,
        maxMarks: body.maxMarks!,
        attemptNo: body.attemptNo,
        attempted: body.attempted,
        isCorrect: body.isCorrect,
        marksAwarded: body.marksAwarded,
        timeTakenMs: body.timeTakenMs,
        confidence: body.confidence,
        hintsUsed: body.hintsUsed,
        chosenOption: body.chosenOption,
        itemVersion: body.itemVersion,
        occurredAt: body.occurredAt,
        capturedBy: claims.sub,
      });
      // Audit ONLY a genuinely-new evidence row — an idempotent replay is silent,
      // so a retried submit never enqueues a second domain event.
      if (result.created) {
        await emitMutationAudit(
          db,
          claims,
          educationAudit.itemResponseRecorded(
            result.row.id,
            result.row.evidence_source ?? body.source!,
            studentId,
          ),
          req,
        );
      }
      return result;
    });

    return jsonResponse(
      envelope({
        response: toLearningEvidenceContract(outcome.row),
        created: outcome.created,
      }),
      { status: outcome.created ? 201 : 200 },
    );
  } catch (error) {
    return handleEvidenceError(error);
  }
}

/** GET /education/evidence/students/:studentId/responses — per-student history. */
export async function handleListStudentResponses(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const claims = auth.claims;

  if (claims.scope === "student") {
    const denied = requireStudentSelfScope(claims);
    if (denied) return denied;
    if (claims.student_id !== studentId) {
      return errorEnvelope("FORBIDDEN", "A student may only read its own evidence", 403);
    }
  } else {
    const denied = requireEducationRead(claims);
    if (denied) return denied;
  }

  const url = new URL(req.url);
  const { page, pageSize } = parsePagination(url);
  const sourceParam = url.searchParams.get("source");
  const source = isEvidenceSource(sourceParam) ? sourceParam : undefined;

  try {
    const result = await withTenantContext(config, claims, (db) =>
      listStudentItemResponses(db, {
        studentId,
        itemId: url.searchParams.get("itemId") ?? undefined,
        source,
        page,
        pageSize,
      })
    );
    return jsonResponse(envelope(result));
  } catch (error) {
    return handleEvidenceError(error);
  }
}

/** GET /education/evidence/items/:itemId/aggregate — per-item item-analysis. */
export async function handleItemResponseAggregate(
  req: Request,
  config: AppConfig,
  itemId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const sourceParam = url.searchParams.get("source");
  const source = isEvidenceSource(sourceParam) ? sourceParam : undefined;

  try {
    const aggregate = await withTenantContext(config, auth.claims, (db) =>
      getItemResponseAggregate(db, itemId, { source })
    );
    return jsonResponse(envelope(aggregate));
  } catch (error) {
    return handleEvidenceError(error);
  }
}

/**
 * GET /education/evidence/students/:studentId/concept-mastery — the EIP-7 / W5
 * per-student, per-concept mastery/weakness roll-up SEED. School staff only.
 */
export async function handleStudentConceptMastery(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const sourceParam = url.searchParams.get("source");
  const source = isEvidenceSource(sourceParam) ? sourceParam : undefined;

  try {
    const seeds = await withTenantContext(config, auth.claims, (db) =>
      getStudentConceptMastery(db, studentId, {
        subjectName: url.searchParams.get("subjectName") ?? undefined,
        source,
      })
    );
    return jsonResponse(envelope({ studentId, concepts: seeds }));
  } catch (error) {
    return handleEvidenceError(error);
  }
}
