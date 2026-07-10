import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleComputeStudentRisks,
  handleGenerateCommunication,
  handleGenerateParentGuidance,
  handleGetStudentRisk,
  handleListClassRisks,
  handleListStudentRisks,
  handlePrincipalIntelligenceCenter,
  handlePrincipalQuery,
  handlePublishParentGuidance,
  handleTeacherSuccessCenter,
} from "./intelligence_handlers.ts";
import {
  handleHomeworkIntelligenceGenerate,
  handleHomeworkIntelligencePlan,
} from "./homework_intelligence_handlers.ts";
import {
  handleGenerateParentMeetingSummary,
  handleGetLessonEffectivenessScores,
  handleGetTeacherPerformanceInsights,
  handleGetTeacherPlanningCenter,
  handleGetTopicMasteryAnalytics,
} from "./teacher_effectiveness_handlers.ts";
import {
  handleComputeStudentSuccess,
  handleGetStudentSuccess,
  handleStudentSuccessDashboard,
  handleStudentSuccessImprovements,
  handleStudentSuccessInterventions,
  handleStudentSuccessPredictions,
} from "./student_success_handlers.ts";
import {
  handleExamAnalytics,
  handleExamForecast,
  handleExamRankMovement,
  handleExamResultIntelligence,
  handleExamSubjectPerformance,
  handleExamWeakChapters,
} from "./exam_intelligence_handlers.ts";
import { handlePriorityFeed } from "./priority/priority_handlers.ts";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchIntelligenceRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;
  args: string[];
} | null {
  // W2.0a — the per-persona Priority Feed (Adaptive Intelligence Layer).
  if (path === "/intelligence/priorities" && method === "GET") {
    return { handler: handlePriorityFeed, args: [] };
  }

  if (path === "/intelligence/risk/students" && method === "GET") {
    return { handler: handleListStudentRisks, args: [] };
  }
  if (path === "/intelligence/risk/students/compute" && method === "POST") {
    return { handler: handleComputeStudentRisks, args: [] };
  }
  if (path === "/intelligence/risk/classes" && method === "GET") {
    return { handler: handleListClassRisks, args: [] };
  }

  const studentMatch = path.match(/^\/intelligence\/risk\/students\/([^/]+)$/);
  if (studentMatch && method === "GET" && UUID.test(studentMatch[1]!)) {
    return { handler: handleGetStudentRisk, args: [studentMatch[1]!] };
  }

  if (path === "/intelligence/communication/generate" && method === "POST") {
    return { handler: handleGenerateCommunication, args: [] };
  }
  if (path === "/intelligence/parent-guidance/generate" && method === "POST") {
    return { handler: handleGenerateParentGuidance, args: [] };
  }
  const guidancePublishMatch = path.match(
    /^\/intelligence\/parent-guidance\/([^/]+)\/publish$/,
  );
  if (guidancePublishMatch && method === "POST" && UUID.test(guidancePublishMatch[1]!)) {
    return { handler: handlePublishParentGuidance, args: [guidancePublishMatch[1]!] };
  }
  if (path === "/intelligence/principal/query" && method === "GET") {
    return { handler: handlePrincipalQuery, args: [] };
  }
  if (path === "/intelligence/teacher/success-center" && method === "GET") {
    return { handler: handleTeacherSuccessCenter, args: [] };
  }
  if (path === "/intelligence/principal/center" && method === "GET") {
    return { handler: handlePrincipalIntelligenceCenter, args: [] };
  }
  if (path === "/intelligence/homework-intelligence/plan" && method === "GET") {
    return { handler: handleHomeworkIntelligencePlan, args: [] };
  }
  if (path === "/intelligence/homework-intelligence/generate" && method === "POST") {
    return { handler: handleHomeworkIntelligenceGenerate, args: [] };
  }

  if (path === "/intelligence/student-success/dashboard" && method === "GET") {
    return { handler: handleStudentSuccessDashboard, args: [] };
  }
  if (path === "/intelligence/student-success/predictions" && method === "GET") {
    return { handler: handleStudentSuccessPredictions, args: [] };
  }
  if (path === "/intelligence/student-success/compute" && method === "POST") {
    return { handler: handleComputeStudentSuccess, args: [] };
  }
  if (path === "/intelligence/student-success/improvements" && method === "GET") {
    return { handler: handleStudentSuccessImprovements, args: [] };
  }
  if (path === "/intelligence/student-success/interventions" && method === "GET") {
    return { handler: handleStudentSuccessInterventions, args: [] };
  }
  const studentSuccessMatch = path.match(/^\/intelligence\/student-success\/students\/([^/]+)$/);
  if (studentSuccessMatch && method === "GET" && UUID.test(studentSuccessMatch[1]!)) {
    return { handler: handleGetStudentSuccess, args: [studentSuccessMatch[1]!] };
  }

  if (path === "/intelligence/exam/analytics" && method === "GET") {
    return { handler: handleExamAnalytics, args: [] };
  }
  if (path === "/intelligence/exam/subject-performance" && method === "GET") {
    return { handler: handleExamSubjectPerformance, args: [] };
  }
  if (path === "/intelligence/exam/weak-chapters" && method === "GET") {
    return { handler: handleExamWeakChapters, args: [] };
  }
  if (path === "/intelligence/exam/result-intelligence" && method === "GET") {
    return { handler: handleExamResultIntelligence, args: [] };
  }
  if (path === "/intelligence/exam/forecast" && method === "GET") {
    return { handler: handleExamForecast, args: [] };
  }
  if (path === "/intelligence/exam/rank-movement" && method === "GET") {
    return { handler: handleExamRankMovement, args: [] };
  }

  if (path === "/intelligence/teacher-effectiveness/lesson-scores" && method === "GET") {
    return { handler: handleGetLessonEffectivenessScores, args: [] };
  }
  if (path === "/intelligence/teacher-effectiveness/topic-mastery" && method === "GET") {
    return { handler: handleGetTopicMasteryAnalytics, args: [] };
  }
  if (path === "/intelligence/teacher-effectiveness/performance" && method === "GET") {
    return { handler: handleGetTeacherPerformanceInsights, args: [] };
  }
  if (path === "/intelligence/teacher-effectiveness/planning-center" && method === "GET") {
    return { handler: handleGetTeacherPlanningCenter, args: [] };
  }
  if (path === "/intelligence/teacher-effectiveness/parent-meeting-summary" && method === "POST") {
    return { handler: handleGenerateParentMeetingSummary, args: [] };
  }

  return null;
}

export async function routeIntelligence(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/intelligence")) return null;
  const match = matchIntelligenceRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }
  try {
    return await match.handler(req, config, ...match.args);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Intelligence route failed";
    return errorEnvelope("INTELLIGENCE_ROUTE_ERROR", message, 500);
  }
}
