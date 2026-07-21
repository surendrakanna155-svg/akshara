import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleExecuteTransition,
  handleGetTransition,
  handlePreviewTransition,
  handleSuggestTransitionMappings,
} from "./academic_transition_handlers.ts";
import {
  handleCreateAcademicYear,
  handleCreateClass,
  handleCreateSection,
  handleCreateTeacherAssignment,
  handleListAcademicYears,
  handleListClasses,
  handleListSections,
  handleListTeacherAssignments,
  handleUpdateAcademicYear,
  handleUpdateClass,
  handleUpdateSection,
  handleUpdateTeacherAssignment,
} from "./academic_handlers.ts";

export function matchAcademicRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;
  args: string[];
} | null {
  if (path === "/academic/years" && method === "GET") {
    return { handler: handleListAcademicYears, args: [] };
  }
  if (path === "/academic/years" && method === "POST") {
    return { handler: handleCreateAcademicYear, args: [] };
  }

  if (path === "/academic/classes" && method === "GET") {
    return { handler: handleListClasses, args: [] };
  }
  if (path === "/academic/classes" && method === "POST") {
    return { handler: handleCreateClass, args: [] };
  }

  if (path === "/academic/sections" && method === "GET") {
    return { handler: handleListSections, args: [] };
  }
  if (path === "/academic/sections" && method === "POST") {
    return { handler: handleCreateSection, args: [] };
  }

  if (path === "/academic/teacher-assignments" && method === "GET") {
    return { handler: handleListTeacherAssignments, args: [] };
  }
  if (path === "/academic/teacher-assignments" && method === "POST") {
    return { handler: handleCreateTeacherAssignment, args: [] };
  }

  if (path === "/academic/transitions/mapping-suggestions" && method === "GET") {
    return { handler: handleSuggestTransitionMappings, args: [] };
  }
  if (path === "/academic/transitions/preview" && method === "POST") {
    return { handler: handlePreviewTransition, args: [] };
  }

  const transitionExecuteMatch = path.match(/^\/academic\/transitions\/([^/]+)\/execute$/);
  if (transitionExecuteMatch && method === "POST") {
    return { handler: handleExecuteTransition, args: [transitionExecuteMatch[1]!] };
  }

  const transitionMatch = path.match(/^\/academic\/transitions\/([^/]+)$/);
  if (transitionMatch && method === "GET") {
    return { handler: handleGetTransition, args: [transitionMatch[1]!] };
  }

  const yearMatch = path.match(/^\/academic\/years\/([^/]+)$/);
  if (yearMatch && method === "PUT") {
    return { handler: handleUpdateAcademicYear, args: [yearMatch[1]!] };
  }

  const classMatch = path.match(/^\/academic\/classes\/([^/]+)$/);
  if (classMatch && method === "PUT") {
    return { handler: handleUpdateClass, args: [classMatch[1]!] };
  }

  const sectionMatch = path.match(/^\/academic\/sections\/([^/]+)$/);
  if (sectionMatch && method === "PUT") {
    return { handler: handleUpdateSection, args: [sectionMatch[1]!] };
  }

  const assignmentMatch = path.match(/^\/academic\/teacher-assignments\/([^/]+)$/);
  if (assignmentMatch && method === "PUT") {
    return { handler: handleUpdateTeacherAssignment, args: [assignmentMatch[1]!] };
  }

  return null;
}

export async function routeAcademic(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/academic")) return null;

  const match = matchAcademicRoute(method, path);
  if (!match) {
    // Let downstream routers (e.g. timetable) handle /academic/* paths we do not own.
    return null;
  }

  return await match.handler(req, config, ...match.args);
}
