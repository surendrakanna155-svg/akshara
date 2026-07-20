import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleArchiveQuestionBank,
  handleCreateQuestionBank,
  handleExportHomework,
  handleExportQuestionBank,
  handleExportQuestionPaper,
  handleGenerateHomework,
  handleGenerateQuestionPaper,
  handleGenerateReportRemark,
  handleGetHomework,
  handleGetQuestionPaper,
  handleImportQuestionBank,
  handleListHomework,
  handleListPaperReviews,
  handleListQuestionBank,
  handleListQuestionPapers,
  handleListReportRemarks,
  handleModeratePaperItem,
  handlePromotePaperItem,
  handlePublishHomework,
  handlePublishQuestionPaper,
  handlePublishReportRemark,
  handleRegeneratePaperItem,
  handleReviewQuestionPaper,
  handleSubmitQuestionPaper,
  handleUpdatePaperItem,
  handleUpdateQuestionBank,
  handleUpdateReportRemark,
} from "./education_handlers.ts";
import { matchLearningEvidenceRoute } from "./learning_evidence_router.ts";
import { matchOmrRoute } from "./omr_router.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchEducationRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;
  args: string[];
} | null {
  // EIP-6 — the Learning Evidence spine owns `/education/evidence/*`. Delegated
  // here so it goes live through the already-mounted routeEducation entry (no
  // api/app.ts change). Its self-contained matcher is authoritative for that
  // subtree; a miss falls through to the existing education routes below.
  const evidence = matchLearningEvidenceRoute(method, path);
  if (evidence) return evidence;

  // W5 Smart OMR — the OMR capture→score + item-analysis surface owns
  // `/education/omr/*`. Delegated here (same pattern as evidence) so it goes live
  // through routeEducation with no api/app.ts change. OMR is an ADDITIONAL capture
  // path; the frozen marks-grid is untouched.
  const omr = matchOmrRoute(method, path);
  if (omr) return omr;

  if (path === "/education/question-bank" && method === "GET") {
    return { handler: handleListQuestionBank, args: [] };
  }
  if (path === "/education/question-bank" && method === "POST") {
    return { handler: handleCreateQuestionBank, args: [] };
  }
  if (path === "/education/question-bank/import" && method === "POST") {
    return { handler: handleImportQuestionBank, args: [] };
  }
  if (path === "/education/question-bank/export" && method === "GET") {
    return { handler: handleExportQuestionBank, args: [] };
  }

  const bankItemMatch = path.match(/^\/education\/question-bank\/([^/]+)$/);
  if (bankItemMatch && UUID_SEGMENT.test(bankItemMatch[1]!)) {
    if (method === "DELETE") {
      return { handler: handleArchiveQuestionBank, args: [bankItemMatch[1]!] };
    }
    if (method === "PUT") {
      return { handler: handleUpdateQuestionBank, args: [bankItemMatch[1]!] };
    }
  }

  if (path === "/education/question-papers" && method === "GET") {
    return { handler: handleListQuestionPapers, args: [] };
  }
  if (path === "/education/question-papers/generate" && method === "POST") {
    return { handler: handleGenerateQuestionPaper, args: [] };
  }

  const paperExportMatch = path.match(/^\/education\/question-papers\/([^/]+)\/export$/);
  if (paperExportMatch && method === "GET" && UUID_SEGMENT.test(paperExportMatch[1]!)) {
    return { handler: handleExportQuestionPaper, args: [paperExportMatch[1]!] };
  }

  const paperPublishMatch = path.match(/^\/education\/question-papers\/([^/]+)\/publish$/);
  if (paperPublishMatch && method === "POST" && UUID_SEGMENT.test(paperPublishMatch[1]!)) {
    return { handler: handlePublishQuestionPaper, args: [paperPublishMatch[1]!] };
  }

  const paperSubmitMatch = path.match(/^\/education\/question-papers\/([^/]+)\/submit$/);
  if (paperSubmitMatch && method === "POST" && UUID_SEGMENT.test(paperSubmitMatch[1]!)) {
    return { handler: handleSubmitQuestionPaper, args: [paperSubmitMatch[1]!] };
  }

  const paperReviewMatch = path.match(/^\/education\/question-papers\/([^/]+)\/review$/);
  if (paperReviewMatch && method === "POST" && UUID_SEGMENT.test(paperReviewMatch[1]!)) {
    return { handler: handleReviewQuestionPaper, args: [paperReviewMatch[1]!] };
  }

  const paperReviewsMatch = path.match(/^\/education\/question-papers\/([^/]+)\/reviews$/);
  if (paperReviewsMatch && method === "GET" && UUID_SEGMENT.test(paperReviewsMatch[1]!)) {
    return { handler: handleListPaperReviews, args: [paperReviewsMatch[1]!] };
  }

  const itemModerateMatch = path.match(
    /^\/education\/question-papers\/([^/]+)\/items\/([^/]+)\/moderate$/,
  );
  if (
    itemModerateMatch && method === "POST" &&
    UUID_SEGMENT.test(itemModerateMatch[1]!) && UUID_SEGMENT.test(itemModerateMatch[2]!)
  ) {
    return {
      handler: handleModeratePaperItem,
      args: [itemModerateMatch[1]!, itemModerateMatch[2]!],
    };
  }

  const itemRegenerateMatch = path.match(
    /^\/education\/question-papers\/([^/]+)\/items\/([^/]+)\/regenerate$/,
  );
  if (
    itemRegenerateMatch && method === "POST" &&
    UUID_SEGMENT.test(itemRegenerateMatch[1]!) && UUID_SEGMENT.test(itemRegenerateMatch[2]!)
  ) {
    return {
      handler: handleRegeneratePaperItem,
      args: [itemRegenerateMatch[1]!, itemRegenerateMatch[2]!],
    };
  }

  const itemPromoteMatch = path.match(
    /^\/education\/question-papers\/([^/]+)\/items\/([^/]+)\/promote$/,
  );
  if (
    itemPromoteMatch && method === "POST" &&
    UUID_SEGMENT.test(itemPromoteMatch[1]!) && UUID_SEGMENT.test(itemPromoteMatch[2]!)
  ) {
    return {
      handler: handlePromotePaperItem,
      args: [itemPromoteMatch[1]!, itemPromoteMatch[2]!],
    };
  }

  const itemEditMatch = path.match(
    /^\/education\/question-papers\/([^/]+)\/items\/([^/]+)$/,
  );
  if (
    itemEditMatch && method === "PUT" &&
    UUID_SEGMENT.test(itemEditMatch[1]!) && UUID_SEGMENT.test(itemEditMatch[2]!)
  ) {
    return {
      handler: handleUpdatePaperItem,
      args: [itemEditMatch[1]!, itemEditMatch[2]!],
    };
  }

  const paperMatch = path.match(/^\/education\/question-papers\/([^/]+)$/);
  if (paperMatch && method === "GET" && UUID_SEGMENT.test(paperMatch[1]!)) {
    return { handler: handleGetQuestionPaper, args: [paperMatch[1]!] };
  }

  if (path === "/education/homework" && method === "GET") {
    return { handler: handleListHomework, args: [] };
  }
  if (path === "/education/homework/generate" && method === "POST") {
    return { handler: handleGenerateHomework, args: [] };
  }

  const homeworkExportMatch = path.match(/^\/education\/homework\/([^/]+)\/export$/);
  if (homeworkExportMatch && method === "GET" && UUID_SEGMENT.test(homeworkExportMatch[1]!)) {
    return { handler: handleExportHomework, args: [homeworkExportMatch[1]!] };
  }

  const homeworkPublishMatch = path.match(/^\/education\/homework\/([^/]+)\/publish$/);
  if (homeworkPublishMatch && method === "POST" && UUID_SEGMENT.test(homeworkPublishMatch[1]!)) {
    return { handler: handlePublishHomework, args: [homeworkPublishMatch[1]!] };
  }

  const homeworkMatch = path.match(/^\/education\/homework\/([^/]+)$/);
  if (homeworkMatch && method === "GET" && UUID_SEGMENT.test(homeworkMatch[1]!)) {
    return { handler: handleGetHomework, args: [homeworkMatch[1]!] };
  }

  if (path === "/education/report-remarks" && method === "GET") {
    return { handler: handleListReportRemarks, args: [] };
  }
  if (path === "/education/report-remarks/generate" && method === "POST") {
    return { handler: handleGenerateReportRemark, args: [] };
  }

  const remarkPublishMatch = path.match(/^\/education\/report-remarks\/([^/]+)\/publish$/);
  if (remarkPublishMatch && method === "POST" && UUID_SEGMENT.test(remarkPublishMatch[1]!)) {
    return { handler: handlePublishReportRemark, args: [remarkPublishMatch[1]!] };
  }

  const remarkMatch = path.match(/^\/education\/report-remarks\/([^/]+)$/);
  if (remarkMatch && method === "PUT" && UUID_SEGMENT.test(remarkMatch[1]!)) {
    return { handler: handleUpdateReportRemark, args: [remarkMatch[1]!] };
  }

  return null;
}

export async function routeEducation(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  const match = matchEducationRoute(method, path);
  if (!match) return null;

  try {
    return await match.handler(req, config, ...match.args);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Education route failed";
    return errorEnvelope("EDUCATION_ROUTE_ERROR", message, 500);
  }
}
