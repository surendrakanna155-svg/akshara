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
import { educationAudit, emitMutationAudit } from "../audit/mutation_audit_catalog.ts";
import {
  homeworkToApi,
  paperExportDocument,
  questionBankToApi,
  questionPaperItemToApi,
  questionPaperReviewToApi,
  questionPaperToApi,
  reportRemarkToApi,
} from "./education_mapper.ts";
import { generateQuestionPaper, regeneratePaperItem } from "./education_question_paper_service.ts";
import {
  buildPaperDocumentV2,
  DEFAULT_SET_LABELS,
  paperV2InputFromStored,
} from "./education_paper_export.ts";
import { resolveAiConfig } from "../ai/ai_settings.ts";
import {
  archiveQuestionBankItem,
  createHomeworkAssignment,
  createQuestionBankItem,
  createQuestionPaper,
  createReportRemark,
  getHomeworkAssignment,
  getQuestionPaperWithItems,
  importQuestionBankItems,
  listHomeworkAssignments,
  listPaperReviews,
  listQuestionBankItems,
  listQuestionPapers,
  listReportRemarks,
  moderatePaperItem,
  promotePaperItemToBank,
  publishHomeworkAssignment,
  publishQuestionPaper,
  publishReportRemark,
  reviewQuestionPaper,
  submitQuestionPaper,
  updatePaperItem,
  updateQuestionBankItem,
  updateReportRemark,
} from "./education_repository.ts";
import {
  generateStubHomeworkContent,
  generateStubRemark,
  type RemarkInputs,
} from "./education_generator.ts";
import {
  assertChaptersWithinSyllabus,
  OffSyllabusError,
} from "./education_syllabus_boundary.ts";
import type {
  EduCognitiveLevel,
  EduDifficulty,
  EduExamType,
  EduHomeworkType,
  EduProgramTrack,
  EduQuestionSource,
  EduQuestionType,
  EduRemarkLanguage,
  EduRemarkType,
  GenerateQuestionPaperInput,
} from "./education_types.ts";

function requireEducationRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "viewEducation") ??
    requireSchoolOperationalScope(claims);
}

function requireEducationWrite(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "manageEducation") ??
    requireSchoolOperationalScope(claims);
}

/**
 * Validation gate: only a principal-level reviewer (approveEducation) may
 * approve / request changes / publish a paper. Teachers (manageEducation) build
 * and submit but cannot sign off their own paper.
 */
function requireEducationApprove(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "approveEducation") ??
    requireSchoolOperationalScope(claims);
}

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
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function handleEducationError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  if (error instanceof OffSyllabusError) {
    return errorEnvelope("OFF_SYLLABUS", error.message, 422);
  }
  const message = error instanceof Error ? error.message : "Education operation failed";
  return errorEnvelope("EDUCATION_ERROR", message, 500);
}

// ─── Question Bank ───────────────────────────────────────────────────────────

export async function handleListQuestionBank(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const { page, pageSize } = parsePagination(url);

  try {
    const result = await runTenant(config, auth.claims, (client) =>
      listQuestionBankItems(client, {
        subjectName: url.searchParams.get("subjectName") ?? undefined,
        chapter: url.searchParams.get("chapter") ?? undefined,
        topic: url.searchParams.get("topic") ?? undefined,
        difficulty: url.searchParams.get("difficulty") ?? undefined,
        questionType: url.searchParams.get("questionType") ?? undefined,
        search: url.searchParams.get("search") ?? undefined,
        page,
        pageSize,
      })
    );

    return jsonResponse(envelope({
      items: result.items.map(questionBankToApi),
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleCreateQuestionBank(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    subjectName: string;
    chapter: string;
    topic?: string;
    difficulty: EduDifficulty;
    questionType: EduQuestionType;
    marks: number;
    questionText: string;
    answerText?: string;
    options?: string[];
    source?: EduQuestionSource;
    sourceReference?: string;
    programTrack?: EduProgramTrack;
    jeeQuestionType?: string;
    cognitiveLevel?: EduCognitiveLevel;
    syllabusChapterId?: string;
    syllabusTopicId?: string;
    learningOutcome?: string;
  }>(req);
  if (!body?.subjectName || !body.chapter || !body.questionText) {
    return errorEnvelope("VALIDATION_ERROR", "subjectName, chapter, and questionText are required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const created = await createQuestionBankItem(db, orgId, schoolId, {
        ...body,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(db, auth.claims, educationAudit.questionBankCreated(created.id), req);
      return created;
    });

    return jsonResponse(envelope(questionBankToApi(row)), { status: 201 });
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleImportQuestionBank(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ items: Array<{
    subjectName: string;
    chapter: string;
    topic?: string;
    difficulty: EduDifficulty;
    questionType: EduQuestionType;
    marks: number;
    questionText: string;
    answerText?: string;
    options?: string[];
    source?: EduQuestionSource;
    sourceReference?: string;
    programTrack?: EduProgramTrack;
    jeeQuestionType?: string;
    cognitiveLevel?: EduCognitiveLevel;
    syllabusChapterId?: string;
    syllabusTopicId?: string;
    learningOutcome?: string;
  }> }>(req);
  if (!body?.items?.length) {
    return errorEnvelope("VALIDATION_ERROR", "items array is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const imported = await importQuestionBankItems(db, orgId, schoolId, {
        items: body.items.map((item) => ({
          ...item,
          source: item.source ?? "import",
          createdBy: auth.claims.sub,
        })),
        createdBy: auth.claims.sub,
      });
      for (const row of imported.created) {
        await emitMutationAudit(db, auth.claims, educationAudit.questionBankCreated(row.id), req);
      }
      return imported;
    });

    return jsonResponse(envelope({
      imported: result.created.length,
      skippedDuplicates: result.skippedDuplicates,
      items: result.created.map(questionBankToApi),
    }), { status: 201 });
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleExportQuestionBank(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  try {
    const result = await runTenant(config, auth.claims, (client) =>
      listQuestionBankItems(client, { page: 1, pageSize: 500, status: "active" })
    );

    return jsonResponse(envelope({
      exportedAt: new Date().toISOString(),
      count: result.items.length,
      items: result.items.map(questionBankToApi),
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleArchiveQuestionBank(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const archived = await archiveQuestionBankItem(db, id);
      if (!archived) return null;
      await emitMutationAudit(db, auth.claims, educationAudit.questionBankArchived(id), req);
      return archived;
    });
    if (!row) return errorEnvelope("NOT_FOUND", "Question bank item not found", 404);

    return jsonResponse(envelope(questionBankToApi(row)));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleUpdateQuestionBank(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    subjectName?: string;
    chapter?: string;
    topic?: string;
    difficulty?: EduDifficulty;
    questionType?: EduQuestionType;
    marks?: number;
    questionText?: string;
    answerText?: string | null;
    options?: string[];
    programTrack?: EduProgramTrack;
    cognitiveLevel?: EduCognitiveLevel | null;
    syllabusChapterId?: string | null;
    syllabusTopicId?: string | null;
    learningOutcome?: string | null;
    sourceReference?: string | null;
  }>(req);
  if (!body || Object.keys(body).length === 0) {
    return errorEnvelope("VALIDATION_ERROR", "At least one field is required", 422);
  }

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const updated = await updateQuestionBankItem(db, id, body);
      if (!updated) return null;
      await emitMutationAudit(
        db, auth.claims, educationAudit.questionBankUpdated(id, crypto.randomUUID()), req,
      );
      return updated;
    });
    if (!row) return errorEnvelope("NOT_FOUND", "Question bank item not found", 404);

    return jsonResponse(envelope(questionBankToApi(row)));
  } catch (error) {
    return handleEducationError(error);
  }
}

// ─── Question Papers ─────────────────────────────────────────────────────────

export async function handleListQuestionPapers(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const { page, pageSize } = parsePagination(url);

  try {
    const result = await runTenant(config, auth.claims, (client) =>
      listQuestionPapers(client, {
        className: url.searchParams.get("className") ?? undefined,
        subjectName: url.searchParams.get("subjectName") ?? undefined,
        page,
        pageSize,
      })
    );

    return jsonResponse(envelope({
      items: result.items.map(questionPaperToApi),
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleGenerateQuestionPaper(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<GenerateQuestionPaperInput>(req);
  if (!body?.className || !body.subjectName || !body.academicYearLabel) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearLabel, className, and subjectName are required", 422);
  }
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      // Hard syllabus boundary: reject off-syllabus chapters before any
      // bank/solver/AI work runs. Keeps generation on-curriculum.
      await assertChaptersWithinSyllabus(
        db,
        body.className,
        body.subjectName,
        body.chapters ?? [],
      );
      const ai = await resolveAiConfig(db, orgId);
      const generated = await generateQuestionPaper(db, body, ai, undefined, {
        db,
        organizationId: orgId,
        schoolId,
        userId: auth.claims.sub,
      });
      const saved = await createQuestionPaper(db, orgId, schoolId, {
        academicYearId: body.academicYearId,
        academicYearLabel: body.academicYearLabel,
        className: body.className,
        sectionName: body.sectionName,
        subjectName: body.subjectName,
        chapters: body.chapters,
        difficulty: body.difficulty,
        totalMarks: body.totalMarks,
        examType: body.examType,
        programTrack: generated.programTrack,
        title: generated.title,
        blueprint: generated.blueprint,
        answerKey: generated.answerKey,
        createdBy: auth.claims.sub,
        items: generated.items.map((item) => ({
          bankItemId: item.bankItemId,
          questionType: item.questionType,
          marks: item.marks,
          questionText: item.questionText,
          answerText: item.answerText,
          options: item.options,
          source: item.source,
          reviewStatus: item.reviewStatus,
        })),
      });
      await emitMutationAudit(
        db,
        auth.claims,
        educationAudit.questionPaperGenerated(saved.paper.id),
        req,
      );
      return { generated, saved };
    });

    return jsonResponse(envelope({
      paper: questionPaperToApi(result.saved.paper),
      items: result.saved.items.map((item, i) => questionPaperItemToApi(item, i)),
      bankReuseCount: result.generated.bankReuseCount,
      aiGeneratedCount: result.generated.aiGeneratedCount,
      aiCandidateCount: result.generated.aiCandidateCount,
      unfilledGapCount: result.generated.unfilledGapCount,
      gaps: result.generated.gaps,
    }), { status: 201 });
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleGetQuestionPaper(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  try {
    const result = await runTenant(config, auth.claims, (client) =>
      getQuestionPaperWithItems(client, id)
    );
    if (!result) return errorEnvelope("NOT_FOUND", "Question paper not found", 404);

    return jsonResponse(envelope({
      paper: questionPaperToApi(result.paper),
      items: result.items.map((item, i) => questionPaperItemToApi(item, i)),
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handlePublishQuestionPaper(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationApprove(auth.claims);
  if (denied) return denied;

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const outcome = await publishQuestionPaper(db, id);
      if (outcome.ok) {
        await emitMutationAudit(db, auth.claims, educationAudit.questionPaperPublished(id), req);
      }
      return outcome;
    });

    if (!result.ok) {
      if (result.reason === "not_found") {
        return errorEnvelope("NOT_FOUND", "Question paper not found", 404);
      }
      if (result.reason === "not_approved") {
        return errorEnvelope(
          "PAPER_NOT_APPROVED",
          "Paper must be approved before it can be published",
          409,
        );
      }
      return errorEnvelope(
        "PAPER_HAS_PENDING_ITEMS",
        `Paper has ${result.pendingItems} AI candidate(s) awaiting moderation`,
        409,
      );
    }

    return jsonResponse(envelope(questionPaperToApi(result.paper)));
  } catch (error) {
    return handleEducationError(error);
  }
}

// ─── Paper review / approval governance (Batch 8b) ───────────────────────────

export async function handleSubmitQuestionPaper(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const submitted = await submitQuestionPaper(db, orgId, schoolId, id, auth.claims.sub);
      if (!submitted) return null;
      await emitMutationAudit(db, auth.claims, educationAudit.questionPaperSubmitted(id), req);
      return submitted;
    });
    if (!result) {
      return errorEnvelope(
        "PAPER_NOT_SUBMITTABLE",
        "Paper not found or not in a draft/changes-requested state",
        409,
      );
    }

    return jsonResponse(envelope({
      paper: questionPaperToApi(result.paper),
      review: questionPaperReviewToApi(result.review),
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleReviewQuestionPaper(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationApprove(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ decision: "approved" | "changes_requested"; comments?: string }>(req);
  if (body?.decision !== "approved" && body?.decision !== "changes_requested") {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "decision must be 'approved' or 'changes_requested'",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const reviewed = await reviewQuestionPaper(
        db, orgId, schoolId, id, body.decision, auth.claims.sub, body.comments ?? null,
      );
      if (!reviewed) return null;
      await emitMutationAudit(
        db, auth.claims, educationAudit.questionPaperReviewed(id, body.decision), req,
      );
      return reviewed;
    });
    if (!result) {
      return errorEnvelope(
        "PAPER_NOT_REVIEWABLE",
        "Paper not found or not in a submitted state",
        409,
      );
    }

    return jsonResponse(envelope({
      paper: questionPaperToApi(result.paper),
      review: questionPaperReviewToApi(result.review),
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleListPaperReviews(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  try {
    const reviews = await runTenant(config, auth.claims, (db) => listPaperReviews(db, id));
    return jsonResponse(envelope({ items: reviews.map(questionPaperReviewToApi) }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleModeratePaperItem(
  req: Request,
  config: AppConfig,
  paperId: string,
  itemId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ decision: "approved" | "rejected" }>(req);
  if (body?.decision !== "approved" && body?.decision !== "rejected") {
    return errorEnvelope("VALIDATION_ERROR", "decision must be 'approved' or 'rejected'", 422);
  }

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const moderated = await moderatePaperItem(db, paperId, itemId, body.decision);
      if (!moderated) return null;
      await emitMutationAudit(
        db,
        auth.claims,
        educationAudit.questionPaperItemModerated(paperId, itemId, body.decision),
        req,
      );
      return moderated;
    });
    if (!row) {
      return errorEnvelope(
        "ITEM_NOT_MODERATABLE",
        "Item not found or not awaiting moderation",
        409,
      );
    }

    return jsonResponse(envelope(questionPaperItemToApi(row, row.sort_order)));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleUpdatePaperItem(
  req: Request,
  config: AppConfig,
  paperId: string,
  itemId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    questionType?: EduQuestionType;
    marks?: number;
    questionText?: string;
    answerText?: string | null;
    options?: string[];
  }>(req);
  if (!body || Object.keys(body).length === 0) {
    return errorEnvelope("VALIDATION_ERROR", "At least one field is required", 422);
  }
  if (body.questionText !== undefined && !body.questionText.trim()) {
    return errorEnvelope("VALIDATION_ERROR", "questionText cannot be empty", 422);
  }

  try {
    const outcome = await runTenant(config, auth.claims, async (db) => {
      const result = await updatePaperItem(db, paperId, itemId, body);
      if (result.ok) {
        await emitMutationAudit(
          db, auth.claims, educationAudit.questionPaperItemEdited(paperId, itemId, crypto.randomUUID()), req,
        );
      }
      return result;
    });

    if (!outcome.ok) {
      if (outcome.reason === "not_editable") {
        return errorEnvelope(
          "PAPER_NOT_EDITABLE",
          "A published or archived paper cannot be edited",
          409,
        );
      }
      return errorEnvelope("NOT_FOUND", "Paper item not found", 404);
    }

    return jsonResponse(envelope({
      item: questionPaperItemToApi(outcome.item, outcome.item.sort_order),
      approvalReset: outcome.approvalReset,
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleRegeneratePaperItem(
  req: Request,
  config: AppConfig,
  paperId: string,
  itemId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ chapter?: string }>(req).catch(() => ({} as { chapter?: string }));
  const orgId = organizationIdFromClaims(auth.claims);

  try {
    const outcome = await runTenant(config, auth.claims, async (db) => {
      const ai = await resolveAiConfig(db, orgId);
      const result = await regeneratePaperItem(db, paperId, itemId, {
        chapter: body?.chapter,
        ai,
        governance: {
          db,
          organizationId: orgId,
          schoolId: schoolIdFromClaims(auth.claims),
          userId: auth.claims.sub,
        },
      });
      if (result.ok) {
        await emitMutationAudit(
          db, auth.claims, educationAudit.questionPaperItemRegenerated(paperId, itemId, crypto.randomUUID()), req,
        );
      }
      return result;
    });

    if (!outcome.ok) {
      if (outcome.reason === "not_editable") {
        return errorEnvelope("PAPER_NOT_EDITABLE", "A published or archived paper cannot be edited", 409);
      }
      if (outcome.reason === "ai_unavailable") {
        return errorEnvelope(
          "AI_UNAVAILABLE",
          "AI is not configured. Set an AI key, or edit the question manually.",
          409,
        );
      }
      if (outcome.reason === "no_candidate") {
        return errorEnvelope(
          "AI_NO_CANDIDATE",
          "AI did not return a valid replacement. Try again or edit the question manually.",
          422,
        );
      }
      return errorEnvelope("NOT_FOUND", "Paper item not found", 404);
    }

    return jsonResponse(envelope({
      item: questionPaperItemToApi(outcome.result.item, outcome.result.item.sort_order),
      approvalReset: outcome.result.approvalReset,
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handlePromotePaperItem(
  req: Request,
  config: AppConfig,
  paperId: string,
  itemId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  type PromoteBody = {
    chapter?: string;
    topic?: string;
    difficulty?: EduDifficulty;
    cognitiveLevel?: EduCognitiveLevel;
    syllabusChapterId?: string;
    syllabusTopicId?: string;
    learningOutcome?: string;
  };
  const body = await readJson<PromoteBody>(req).catch(() => ({} as PromoteBody));

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const outcome = await runTenant(config, auth.claims, async (db) => {
      const result = await promotePaperItemToBank(
        db, orgId, schoolId, paperId, itemId, body ?? {}, auth.claims.sub,
      );
      if (result.ok && !result.duplicate) {
        await emitMutationAudit(
          db, auth.claims, educationAudit.questionPaperItemPromoted(paperId, itemId, result.item.id), req,
        );
      }
      return result;
    });

    if (!outcome.ok) {
      if (outcome.reason === "not_approved") {
        return errorEnvelope(
          "ITEM_NOT_PROMOTABLE",
          "Only an approved AI candidate can be saved to the bank",
          409,
        );
      }
      return errorEnvelope("NOT_FOUND", "Paper item not found", 404);
    }

    return jsonResponse(envelope({
      item: questionBankToApi(outcome.item),
      duplicate: outcome.duplicate,
    }), { status: outcome.duplicate ? 200 : 201 });
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleExportQuestionPaper(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  try {
    const result = await runTenant(config, auth.claims, (client) =>
      getQuestionPaperWithItems(client, id)
    );
    if (!result) return errorEnvelope("NOT_FOUND", "Question paper not found", 404);

    // AI-2 moderation gate: a paper may only be exported as a student-facing
    // document once it has cleared the publish gate (which itself blocks any
    // pending AI candidate). This stops a draft/submitted paper — whose items
    // may still be unmoderated — from being exported around the governance flow.
    if (result.paper.review_status !== "published") {
      return errorEnvelope(
        "PAPER_NOT_PUBLISHED",
        "Only a published question paper can be exported",
        409,
      );
    }

    // CI-C3 — opt-in structured v2 export (multi-set A/B/C + per-set keys).
    // DORMANT: with neither `format=v2` nor `sets` present, the certified v1
    // document is returned BYTE-IDENTICALLY. `?sets=A,B,C` (or `?format=v2`)
    // switches to the structured, deterministic multi-set document.
    const url = new URL(req.url);
    const setsParam = url.searchParams.get("sets");
    if (url.searchParams.get("format") === "v2" || setsParam) {
      const sets = setsParam
        ? setsParam.split(",").map((s) => s.trim()).filter((s) => s.length > 0)
        : [DEFAULT_SET_LABELS[0]];
      const doc = buildPaperDocumentV2(
        paperV2InputFromStored(result.paper, result.items),
        { sets, seed: result.paper.id },
      );
      return jsonResponse(envelope(doc));
    }

    return jsonResponse(envelope(paperExportDocument(result.paper, result.items)));
  } catch (error) {
    return handleEducationError(error);
  }
}

// ─── Homework ──────────────────────────────────────────────────────────────────

export async function handleListHomework(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const { page, pageSize } = parsePagination(url);

  try {
    const result = await runTenant(config, auth.claims, (client) =>
      listHomeworkAssignments(client, {
        className: url.searchParams.get("className") ?? undefined,
        subjectName: url.searchParams.get("subjectName") ?? undefined,
        status: url.searchParams.get("status") ?? undefined,
        page,
        pageSize,
      })
    );

    return jsonResponse(envelope({
      items: result.items.map(homeworkToApi),
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleGenerateHomework(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    academicYearLabel: string;
    className: string;
    sectionName?: string;
    subjectName: string;
    topic: string;
    difficulty: EduDifficulty;
    assignmentType: EduHomeworkType;
    dueDate?: string;
  }>(req);
  if (!body?.className || !body.subjectName || !body.topic) {
    return errorEnvelope("VALIDATION_ERROR", "className, subjectName, and topic are required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  const content = generateStubHomeworkContent(
    body.subjectName,
    body.topic,
    body.difficulty,
    body.assignmentType,
  );
  const title =
    `${body.className} — ${body.subjectName} ${body.assignmentType.replaceAll("_", " ")}`;

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const created = await createHomeworkAssignment(db, orgId, schoolId, {
        ...body,
        title,
        content,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(db, auth.claims, educationAudit.homeworkGenerated(created.id), req);
      return created;
    });

    return jsonResponse(envelope(homeworkToApi(row)), { status: 201 });
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleGetHomework(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  try {
    const row = await runTenant(config, auth.claims, (client) =>
      getHomeworkAssignment(client, id)
    );
    if (!row) return errorEnvelope("NOT_FOUND", "Homework not found", 404);
    return jsonResponse(envelope(homeworkToApi(row)));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handlePublishHomework(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const published = await publishHomeworkAssignment(db, id);
      if (!published) return null;
      await emitMutationAudit(db, auth.claims, educationAudit.homeworkPublished(id), req);
      return published;
    });
    if (!row) return errorEnvelope("NOT_FOUND", "Homework not found", 404);

    return jsonResponse(envelope(homeworkToApi(row)));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleExportHomework(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  try {
    const row = await runTenant(config, auth.claims, (client) =>
      getHomeworkAssignment(client, id)
    );
    if (!row) return errorEnvelope("NOT_FOUND", "Homework not found", 404);

    return jsonResponse(envelope({
      title: row.title,
      meta: homeworkToApi(row),
      content: row.content,
      format: "akshara-education-pdf-v1",
      generatedAt: new Date().toISOString(),
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

// ─── Report Card Remarks ───────────────────────────────────────────────────────

export async function handleListReportRemarks(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const { page, pageSize } = parsePagination(url);

  try {
    const result = await runTenant(config, auth.claims, (client) =>
      listReportRemarks(client, {
        studentId: url.searchParams.get("studentId") ?? undefined,
        academicYearLabel: url.searchParams.get("academicYearLabel") ?? undefined,
        page,
        pageSize,
      })
    );

    return jsonResponse(envelope({
      items: result.items.map(reportRemarkToApi),
      total: result.total,
      page: result.page,
      pageSize: result.pageSize,
    }));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleGenerateReportRemark(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    studentId: string;
    academicYearLabel: string;
    remarkType: EduRemarkType;
    language: EduRemarkLanguage;
    inputs: RemarkInputs;
  }>(req);
  if (!body?.studentId || !body.academicYearLabel) {
    return errorEnvelope("VALIDATION_ERROR", "studentId and academicYearLabel are required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  const generatedRemark = generateStubRemark(body.remarkType, body.language, body.inputs);

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const created = await createReportRemark(db, orgId, schoolId, {
        studentId: body.studentId,
        academicYearLabel: body.academicYearLabel,
        remarkType: body.remarkType,
        language: body.language,
        inputs: body.inputs as Record<string, unknown>,
        generatedRemark,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(db, auth.claims, educationAudit.reportRemarkGenerated(created.id), req);
      return created;
    });

    return jsonResponse(envelope(reportRemarkToApi(row)), { status: 201 });
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handleUpdateReportRemark(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ editedRemark: string }>(req);
  if (!body?.editedRemark?.trim()) {
    return errorEnvelope("VALIDATION_ERROR", "editedRemark is required", 422);
  }

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const updated = await updateReportRemark(db, id, body.editedRemark);
      if (!updated) return null;
      await emitMutationAudit(db, auth.claims, educationAudit.reportRemarkUpdated(id), req);
      return updated;
    });
    if (!row) return errorEnvelope("NOT_FOUND", "Report remark not found", 404);

    return jsonResponse(envelope(reportRemarkToApi(row)));
  } catch (error) {
    return handleEducationError(error);
  }
}

export async function handlePublishReportRemark(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEducationWrite(auth.claims);
  if (denied) return denied;

  try {
    const row = await runTenant(config, auth.claims, async (db) => {
      const published = await publishReportRemark(db, id);
      if (!published) return null;
      await emitMutationAudit(db, auth.claims, educationAudit.reportRemarkPublished(id), req);
      return published;
    });
    if (!row) return errorEnvelope("NOT_FOUND", "Report remark not found", 404);

    return jsonResponse(envelope(reportRemarkToApi(row)));
  } catch (error) {
    return handleEducationError(error);
  }
}
