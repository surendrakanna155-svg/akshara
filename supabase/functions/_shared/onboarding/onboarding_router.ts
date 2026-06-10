import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCommitImportJob,
  handleCreateInvite,
  handleGetImportJob,
  handleListImportJobs,
  handleListInvites,
  handleOnboardingDashboard,
  handleRollbackImportJob,
  handleStudentImportPreview,
  handleTeacherImportPreview,
} from "./onboarding_handlers.ts";

function matchOnboardingRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/onboarding/dashboard" && method === "GET") {
    return { handler: handleOnboardingDashboard, args: [] };
  }
  if (path === "/onboarding/imports" && method === "GET") {
    return { handler: handleListImportJobs, args: [] };
  }
  if (path === "/onboarding/imports/students/preview" && method === "POST") {
    return { handler: handleStudentImportPreview, args: [] };
  }
  if (path === "/onboarding/imports/teachers/preview" && method === "POST") {
    return { handler: handleTeacherImportPreview, args: [] };
  }
  if (path === "/onboarding/invites" && method === "GET") {
    return { handler: handleListInvites, args: [] };
  }
  if (path === "/onboarding/invites" && method === "POST") {
    return { handler: handleCreateInvite, args: [] };
  }

  const jobMatch = path.match(/^\/onboarding\/imports\/([^/]+)$/);
  if (jobMatch && method === "GET") {
    return { handler: handleGetImportJob, args: [jobMatch[1]!] };
  }

  const commitMatch = path.match(/^\/onboarding\/imports\/([^/]+)\/commit$/);
  if (commitMatch && method === "POST") {
    return { handler: handleCommitImportJob, args: [commitMatch[1]!] };
  }

  const rollbackMatch = path.match(/^\/onboarding\/imports\/([^/]+)\/rollback$/);
  if (rollbackMatch && method === "POST") {
    return { handler: handleRollbackImportJob, args: [rollbackMatch[1]!] };
  }

  return null;
}

export async function routeOnboarding(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/onboarding")) return null;
  const match = matchOnboardingRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }
  return await match.handler(req, config, ...match.args);
}
