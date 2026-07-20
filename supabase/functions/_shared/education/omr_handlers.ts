// Smart OMR — HTTP handlers (capture → score → evidence, + item-analysis read).
//
// Owner decisions #8 (Smart OMR — resolves D1) + #15 (Assessment Intelligence).
//
// RBAC:
//   • INGEST (POST) — a school-scope staff member with manageEducation. OMR
//     capture is a teacher / exam-admin action; a student never ingests a scan
//     (unlike the self-attempt evidence path). No student-self branch by design.
//   • ITEM-ANALYSIS (GET) — school staff with viewEducation. It reads the
//     school-scoped question bank + evidence, so a persona scope sees nothing.

import type { AppConfig } from "../config.ts";
import {
  envelope,
  errorEnvelope,
  jsonResponse,
  MAX_BULK_ITEMS,
  readJson,
} from "../http.ts";
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
  educationAudit,
  emitMutationAudit,
} from "../audit/mutation_audit_catalog.ts";
import {
  getPaperItemAnalysis,
  ingestOmrScan,
  OmrIngestionError,
  type OmrScanResultRow,
} from "./omr_repository.ts";
import {
  type OmrBlankPolicy,
  type OmrMultiMarkPolicy,
  type OmrScoringPolicy,
  type OmrSheetMark,
} from "./omr_scoring.ts";

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

function handleOmrError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  if (error instanceof OmrIngestionError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  const message = error instanceof Error
    ? error.message
    : "OMR operation failed";
  return errorEnvelope("OMR_ERROR", message, 500);
}

/** Client → contract mapper for a persisted scan result. */
function toOmrScanContract(row: OmrScanResultRow) {
  return {
    id: row.id,
    examId: row.exam_id,
    paperId: row.paper_id,
    studentId: row.student_id,
    setLabel: row.set_label,
    totalScore: Number(row.total_score),
    maxScore: Number(row.max_score),
    correctCount: row.correct_count,
    incorrectCount: row.incorrect_count,
    blankCount: row.blank_count,
    ambiguousCount: row.ambiguous_count,
    unscoredCount: row.unscored_count,
    blankPolicy: row.blank_policy,
    multiMarkPolicy: row.multi_mark_policy,
    scoredAt: row.scored_at,
  };
}

interface IngestOmrBody {
  examId?: string;
  paperId?: string;
  studentId?: string;
  setLabel?: string | null;
  markedOptions?: OmrSheetMark[];
  policy?: { blank?: string; multiMark?: string };
  occurredAt?: string | null;
}

function parsePolicy(
  raw: IngestOmrBody["policy"],
): OmrScoringPolicy | Response {
  if (!raw) return { blank: "blank", multiMark: "blank" };
  const blank = raw.blank ?? "blank";
  const multiMark = raw.multiMark ?? "blank";
  if (blank !== "blank" && blank !== "wrong") {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "policy.blank must be 'blank' or 'wrong'",
      422,
    );
  }
  if (
    multiMark !== "blank" && multiMark !== "wrong" && multiMark !== "reject"
  ) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "policy.multiMark must be 'blank', 'wrong' or 'reject'",
      422,
    );
  }
  return {
    blank: blank as OmrBlankPolicy,
    multiMark: multiMark as OmrMultiMarkPolicy,
  };
}

/**
 * POST /education/omr/scans — ingest a scanned OMR sheet: score it against the
 * paper's answer key, persist the result, and emit EIP-6 evidence per scoreable
 * item. Idempotent per (exam, paper, student).
 */
export async function handleIngestOmrScan(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const claims = auth.claims;

  const denied = requireEducationWrite(claims);
  if (denied) return denied;

  const body = await readJson<IngestOmrBody>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);
  }

  if (!body.examId || !body.paperId || !body.studentId) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "examId, paperId and studentId are required",
      422,
    );
  }
  if (!Array.isArray(body.markedOptions)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "markedOptions must be an array of { questionNo, marked }",
      422,
    );
  }
  if (body.markedOptions.length > MAX_BULK_ITEMS) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `markedOptions exceeds the ${MAX_BULK_ITEMS}-question limit`,
      422,
    );
  }

  const policy = parsePolicy(body.policy);
  if (policy instanceof Response) return policy;

  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);

  try {
    const outcome = await withTenantContext(config, claims, async (db) => {
      const result = await ingestOmrScan(db, orgId, schoolId, {
        examId: body.examId!,
        paperId: body.paperId!,
        studentId: body.studentId!,
        setLabel: body.setLabel ?? null,
        markedOptions: body.markedOptions!,
        policy,
        occurredAt: body.occurredAt ?? null,
        scannedBy: claims.sub,
      });
      // Audit ONLY a genuinely-new scan; an idempotent replay is silent.
      if (result.created) {
        await emitMutationAudit(
          db,
          claims,
          educationAudit.itemResponseRecorded(
            result.scan.id,
            "omr",
            body.studentId!,
          ),
          req,
        );
      }
      return result;
    });

    return jsonResponse(
      envelope({
        scan: toOmrScanContract(outcome.scan),
        score: {
          totalScore: outcome.score.totalScore,
          maxScore: outcome.score.maxScore,
          correctCount: outcome.score.correctCount,
          incorrectCount: outcome.score.incorrectCount,
          blankCount: outcome.score.blankCount,
          ambiguousCount: outcome.score.ambiguousCount,
          unscoredCount: outcome.score.unscoredCount,
          answeredCount: outcome.score.answeredCount,
          perQuestion: outcome.score.perQuestion,
        },
        created: outcome.created,
        evidenceEmitted: outcome.evidenceEmitted,
      }),
      { status: outcome.created ? 201 : 200 },
    );
  } catch (error) {
    return handleOmrError(error);
  }
}

/**
 * GET /education/omr/papers/:paperId/item-analysis — per-item difficulty +
 * discrimination + question heatmap over EIP-6 evidence. Honest-null throughout.
 */
export async function handleGetPaperItemAnalysis(
  req: Request,
  config: AppConfig,
  paperId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const sourceParam = url.searchParams.get("source");
  const source = (sourceParam === "omr" || sourceParam === "exam" ||
      sourceParam === "homework" || sourceParam === "practice")
    ? sourceParam
    : undefined;

  try {
    const analysis = await withTenantContext(
      config,
      auth.claims,
      (db) => getPaperItemAnalysis(db, paperId, { source }),
    );
    return jsonResponse(envelope(analysis));
  } catch (error) {
    return handleOmrError(error);
  }
}
