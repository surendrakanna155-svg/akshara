import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAutomateTimetables,
  handleCreateLessonLog,
  handleCreateSubject,
  handleGetSchoolBranding,
  handleGetWhatsAppProvider,
  handleListLessonLogs,
  handleListSubjects,
  handleSaveSchoolBranding,
  handleSaveWhatsAppProvider,
  handleTestWhatsAppProvider,
  handleUpdateSubject,
  schoolCompletionUuidPattern,
} from "./school_completion_handlers.ts";
import {
  handleCreateClassSubjectAssignment,
  handleCreateTeacherSubjectAssignment,
  handleDeleteClassSubjectAssignment,
  handleGetDeliveryAnalytics,
  handleGetPilotDashboard,
  handleGetPrincipalLessonAnalytics,
  handleGetSubjectWorkload,
  handleGetTeacherLessonAnalytics,
  handleGetTimetableOptimization,
  handleListClassSubjectAssignments,
  handleListTeacherSubjectAssignments,
  handleSendTemplateMessage,
} from "./phase9_handlers.ts";
import {
  handleAllocateRooms,
  handleCloneSyllabus,
  handleCompleteTopic,
  handleCreateRoom,
  handleGenerateExamTimetable,
  handleGenerateSyllabus,
  handleGetPrincipalAcademicProgress,
  handleGetTeacherProgress,
  handleGetTimetableIntelligence,
  handleListRooms,
  handleListSubjectTemplates,
  handleListSyllabusChapters,
} from "./phase10_handlers.ts";
import {
  handleGetAnalyticsDelivery,
  handleGetCampaignAnalytics,
  handleGetCommunicationAnalyticsSummary,
  handleGetCommunicationEffectiveness,
  handleGetParentAdoptionAnalytics,
  handleGetParentEngagementAnalytics,
} from "./phase15_handlers.ts";

export async function routeSchoolCompletion(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/school/")) return null;

  if (path === "/school/subjects" && method === "GET") return handleListSubjects(req, config);
  if (path === "/school/subjects" && method === "POST") return handleCreateSubject(req, config);

  const subjectMatch = path.match(/^\/school\/subjects\/([^/]+)$/);
  if (subjectMatch && method === "PATCH" && schoolCompletionUuidPattern.test(subjectMatch[1]!)) {
    return handleUpdateSubject(req, config, subjectMatch[1]!);
  }

  if (path === "/school/lesson-logs" && method === "GET") return handleListLessonLogs(req, config);
  if (path === "/school/lesson-logs" && method === "POST") return handleCreateLessonLog(req, config);

  if (path === "/school/timetables/automate" && method === "POST") {
    return handleAutomateTimetables(req, config);
  }

  if (path === "/school/branding" && method === "GET") return handleGetSchoolBranding(req, config);
  if (path === "/school/branding" && method === "PUT") return handleSaveSchoolBranding(req, config);

  if (path === "/school/whatsapp-provider" && method === "GET") {
    return handleGetWhatsAppProvider(req, config);
  }
  if (path === "/school/whatsapp-provider" && method === "PUT") {
    return handleSaveWhatsAppProvider(req, config);
  }
  if (path === "/school/whatsapp-provider/test" && method === "POST") {
    return handleTestWhatsAppProvider(req, config);
  }

  if (path === "/school/class-subject-assignments" && method === "GET") {
    return handleListClassSubjectAssignments(req, config);
  }
  if (path === "/school/class-subject-assignments" && method === "POST") {
    return handleCreateClassSubjectAssignment(req, config);
  }
  const classSubjectMatch = path.match(/^\/school\/class-subject-assignments\/([^/]+)$/);
  if (classSubjectMatch && method === "DELETE" && schoolCompletionUuidPattern.test(classSubjectMatch[1]!)) {
    return handleDeleteClassSubjectAssignment(req, config, classSubjectMatch[1]!);
  }

  if (path === "/school/teacher-subject-assignments" && method === "GET") {
    return handleListTeacherSubjectAssignments(req, config);
  }
  if (path === "/school/teacher-subject-assignments" && method === "POST") {
    return handleCreateTeacherSubjectAssignment(req, config);
  }

  if (path === "/school/subject-workload" && method === "GET") {
    return handleGetSubjectWorkload(req, config);
  }

  if (path === "/school/lesson-analytics/teacher" && method === "GET") {
    return handleGetTeacherLessonAnalytics(req, config);
  }
  if (path === "/school/lesson-analytics/principal" && method === "GET") {
    return handleGetPrincipalLessonAnalytics(req, config);
  }

  if (path === "/school/timetables/optimize" && method === "GET") {
    return handleGetTimetableOptimization(req, config);
  }

  if (path === "/school/communications/analytics/summary" && method === "GET") {
    return handleGetCommunicationAnalyticsSummary(req, config);
  }
  if (path === "/school/communications/analytics/campaigns" && method === "GET") {
    return handleGetCampaignAnalytics(req, config);
  }
  if (path === "/school/communications/analytics/delivery" && method === "GET") {
    return handleGetAnalyticsDelivery(req, config);
  }
  if (path === "/school/communications/analytics/effectiveness" && method === "GET") {
    return handleGetCommunicationEffectiveness(req, config);
  }
  if (path === "/school/communications/analytics/parent-engagement" && method === "GET") {
    return handleGetParentEngagementAnalytics(req, config);
  }
  if (path === "/school/communications/analytics/parent-adoption" && method === "GET") {
    return handleGetParentAdoptionAnalytics(req, config);
  }
  if (path === "/school/communications/delivery-analytics" && method === "GET") {
    return handleGetDeliveryAnalytics(req, config);
  }
  if (path === "/school/communications/send-template" && method === "POST") {
    return handleSendTemplateMessage(req, config);
  }

  if (path === "/school/pilot/dashboard" && method === "GET") {
    return handleGetPilotDashboard(req, config);
  }

  if (path === "/school/syllabus/templates" && method === "GET") {
    return handleListSubjectTemplates(req, config);
  }
  if (path === "/school/syllabus/generate" && method === "POST") {
    return handleGenerateSyllabus(req, config);
  }
  if (path === "/school/syllabus/clone" && method === "POST") {
    return handleCloneSyllabus(req, config);
  }
  if (path === "/school/syllabus/chapters" && method === "GET") {
    return handleListSyllabusChapters(req, config);
  }
  if (path === "/school/academic/complete-topic" && method === "POST") {
    return handleCompleteTopic(req, config);
  }
  if (path === "/school/academic/teacher-progress" && method === "GET") {
    return handleGetTeacherProgress(req, config);
  }
  if (path === "/school/academic/principal-progress" && method === "GET") {
    return handleGetPrincipalAcademicProgress(req, config);
  }
  if (path === "/school/rooms" && method === "GET") {
    return handleListRooms(req, config);
  }
  if (path === "/school/rooms" && method === "POST") {
    return handleCreateRoom(req, config);
  }
  if (path === "/school/rooms/allocate" && method === "POST") {
    return handleAllocateRooms(req, config);
  }
  if (path === "/school/exam-timetable/generate" && method === "POST") {
    return handleGenerateExamTimetable(req, config);
  }
  if (path === "/school/timetables/intelligence" && method === "GET") {
    return handleGetTimetableIntelligence(req, config);
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
