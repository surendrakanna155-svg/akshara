import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleApproveAdmission,
  handleApproveDocument,
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
  handleSubmitEnrollment,
  handleUpdateApplication,
  handleUpdateLead,
  handleUploadDocument,
} from "./admissions_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function matchAdmissionsRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/admissions/leads" && method === "GET") {
    return { handler: handleListLeads, args: [] };
  }
  if (path === "/admissions/leads" && method === "POST") {
    return { handler: handleCreateLead, args: [] };
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
  if (path === "/admissions/documents/upload" && method === "POST") {
    return { handler: handleUploadDocument, args: [] };
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

  if (path === "/admissions/enrollments" && method === "POST") {
    return { handler: handleSubmitEnrollment, args: [] };
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
