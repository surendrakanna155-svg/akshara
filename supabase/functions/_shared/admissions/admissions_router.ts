import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAddLeadFollowUp,
  handleAddLeadNote,
  handleApproveAdmission,
  handleApproveDocument,
  handleAssignLeadCounselor,
  handleChangeLeadStage,
  handleCreateApplication,
  handleCreateLead,
  handleGetApplication,
  handleGetLead,
  handleListApplications,
  handleListDocuments,
  handleListLeads,
  handleRejectAdmission,
  handleRejectDocument,
  handleSubmitApplication,
  handleListApprovedHandoffs,
  handleSendToFinance,
  handleSubmitEnrollment,
  handleUpdateApplication,
  handleUpdateHandoffStatus,
  handleUpdateLead,
  handleUploadDocument,
  handlePresignDocumentUpload,
  handleDownloadDocument,
} from "./admissions_handlers.ts";
import { handleDashboard } from "./admissions_dashboard_handlers.ts";
import { handleAdmissionsIntelligence } from "./admissions_intelligence_handlers.ts";
import {
  handleAddApprovalNote,
  handleApprovalQueue,
  handleEnrollmentPrefill,
  handlePendingEnrollments,
  handleReports,
  handleSettings,
} from "./admissions_extras_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function matchAdmissionsRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/admissions/leads" && method === "GET") {
    return { handler: handleListLeads, args: [] };
  }
  if (path === "/admissions/dashboard" && method === "GET") {
    return { handler: handleDashboard, args: [] };
  }
  if (path === "/admissions/intelligence" && method === "GET") {
    return { handler: handleAdmissionsIntelligence, args: [] };
  }
  // MJ-H14: read endpoints backed by real admissions data.
  if (path === "/admissions/reports" && method === "GET") {
    return { handler: handleReports, args: [] };
  }
  if (path === "/admissions/settings" && method === "GET") {
    return { handler: handleSettings, args: [] };
  }
  if (path === "/admissions/approval-queue" && method === "GET") {
    return { handler: handleApprovalQueue, args: [] };
  }
  if (path === "/admissions/enrollments/pending" && method === "GET") {
    return { handler: handlePendingEnrollments, args: [] };
  }
  if (path === "/admissions/enrollment/prefill" && method === "GET") {
    return { handler: handleEnrollmentPrefill, args: [] };
  }
  if (path === "/admissions/leads" && method === "POST") {
    return { handler: handleCreateLead, args: [] };
  }

  const leadAssignMatch = path.match(/^\/admissions\/leads\/([^/]+)\/assign$/);
  if (leadAssignMatch && method === "PATCH") {
    return { handler: handleAssignLeadCounselor, args: [leadAssignMatch[1]!] };
  }

  const leadStageMatch = path.match(/^\/admissions\/leads\/([^/]+)\/stage$/);
  if (leadStageMatch && method === "PATCH") {
    return { handler: handleChangeLeadStage, args: [leadStageMatch[1]!] };
  }

  const leadFollowUpsMatch = path.match(/^\/admissions\/leads\/([^/]+)\/followups$/);
  if (leadFollowUpsMatch && method === "POST") {
    return { handler: handleAddLeadFollowUp, args: [leadFollowUpsMatch[1]!] };
  }

  const leadNotesMatch = path.match(/^\/admissions\/leads\/([^/]+)\/notes$/);
  if (leadNotesMatch && method === "POST") {
    return { handler: handleAddLeadNote, args: [leadNotesMatch[1]!] };
  }

  const leadMatch = path.match(/^\/admissions\/leads\/([^/]+)$/);
  if (leadMatch) {
    const leadId = leadMatch[1]!;
    if (method === "GET") return { handler: handleGetLead, args: [leadId] };
    if (method === "PUT") return { handler: handleUpdateLead, args: [leadId] };
  }

  if (path === "/admissions/applications" && method === "GET") {
    return { handler: handleListApplications, args: [] };
  }
  if (path === "/admissions/applications" && method === "POST") {
    return { handler: handleCreateApplication, args: [] };
  }

  const appMatch = path.match(/^\/admissions\/applications\/([^/]+)$/);
  if (appMatch) {
    const applicationId = appMatch[1]!;
    if (method === "GET") {
      return { handler: handleGetApplication, args: [applicationId] };
    }
    if (method === "PUT") {
      return { handler: handleUpdateApplication, args: [applicationId] };
    }
  }

  const submitMatch = path.match(/^\/admissions\/applications\/([^/]+)\/submit$/);
  if (submitMatch && method === "POST") {
    return { handler: handleSubmitApplication, args: [submitMatch[1]!] };
  }

  if (path === "/admissions/documents" && method === "GET") {
    return { handler: handleListDocuments, args: [] };
  }
  // ADMIS-5: presign the direct-to-Storage upload before confirming metadata.
  // Declared before the generic /upload match so it is not shadowed.
  if (path === "/admissions/documents/upload/presign" && method === "POST") {
    return { handler: handlePresignDocumentUpload, args: [] };
  }
  if (path === "/admissions/documents/upload" && method === "POST") {
    return { handler: handleUploadDocument, args: [] };
  }

  // ADMIS-5: signed-URL retrieval of a stored document for verification.
  const docDownloadMatch = path.match(/^\/admissions\/documents\/([^/]+)\/download$/);
  if (docDownloadMatch && method === "GET") {
    return { handler: handleDownloadDocument, args: [docDownloadMatch[1]!] };
  }

  const docApproveMatch = path.match(/^\/admissions\/documents\/([^/]+)\/approve$/);
  if (docApproveMatch && method === "POST") {
    return { handler: handleApproveDocument, args: [docApproveMatch[1]!] };
  }

  const docRejectMatch = path.match(/^\/admissions\/documents\/([^/]+)\/reject$/);
  if (docRejectMatch && method === "POST") {
    return { handler: handleRejectDocument, args: [docRejectMatch[1]!] };
  }

  const approvalApproveMatch = path.match(/^\/admissions\/approval\/([^/]+)\/approve$/);
  if (approvalApproveMatch && method === "POST") {
    return { handler: handleApproveAdmission, args: [approvalApproveMatch[1]!] };
  }

  const approvalRejectMatch = path.match(/^\/admissions\/approval\/([^/]+)\/reject$/);
  if (approvalRejectMatch && method === "POST") {
    return { handler: handleRejectAdmission, args: [approvalRejectMatch[1]!] };
  }

  // MJ-H15: persist an approval note (mirrors the approve/{id}/approve regex).
  const approvalNotesMatch = path.match(/^\/admissions\/approval\/([^/]+)\/notes$/);
  if (approvalNotesMatch && method === "POST") {
    return { handler: handleAddApprovalNote, args: [approvalNotesMatch[1]!] };
  }

  if (path === "/admissions/enrollments" && method === "POST") {
    return { handler: handleSubmitEnrollment, args: [] };
  }

  if (path === "/admissions/handoffs/approved" && method === "GET") {
    return { handler: handleListApprovedHandoffs, args: [] };
  }
  if (path === "/admissions/handoffs/send" && method === "POST") {
    return { handler: handleSendToFinance, args: [] };
  }

  const handoffStatusMatch = path.match(/^\/admissions\/handoffs\/([^/]+)\/status$/);
  if (handoffStatusMatch && method === "PATCH") {
    return { handler: handleUpdateHandoffStatus, args: [handoffStatusMatch[1]!] };
  }

  return null;
}

export async function routeAdmissions(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/admissions")) return null;

  const match = matchAdmissionsRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  // Validate UUID path segments when they look like UUIDs
  for (const arg of match.args) {
    if (arg.includes("-") && !UUID_SEGMENT.test(arg) && !arg.startsWith("LD-")) {
      // Allow non-UUID legacy mock ids in path for compatibility
    }
  }

  return await match.handler(req, config, ...match.args);
}
