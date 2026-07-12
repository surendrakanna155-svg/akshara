import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { handleDashboard } from "./sis_dashboard_handlers.ts";
import {
  handleAdmissionsConversion,
  handleListAdmissionsConversion,
} from "./sis_conversion_handlers.ts";
import {
  handleCreateEnrollment,
  handleListEnrollments,
  handleUpdateEnrollment,
} from "./sis_enrollment_handlers.ts";
import {
  handleCreateStudent,
  handleGetStudent,
  handleListStudents,
  handleListStudentTransfers,
  handleUpdateStudent,
  handleUpdateStudentStatus,
} from "./sis_handlers.ts";
import {
  handleListStudentDocuments,
  handleUploadStudentDocument,
  handleVerifyStudentDocument,
} from "./sis_document_handlers.ts";
import {
  handleIssueCertificate,
  handleIssueTransferCertificate,
  handleListCertificates,
} from "./sis_certificate_handlers.ts";
import {
  handleGetStudent360Profile,
  handleGetStudentTimeline,
} from "./sis_student_360_handlers.ts";
import { handleListStudentSiblings } from "./sis_sibling_handlers.ts";
import { handleStudentClearance } from "../clearance/clearance_handlers.ts";
import {
  handleCreateClearanceWaiver,
  handleDecideClearanceWaiver,
  handleListPendingClearanceWaivers,
} from "../clearance/clearance_waiver_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchSisRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/sis/dashboard" && method === "GET") {
    return { handler: handleDashboard, args: [] };
  }

  if (path === "/sis/students" && method === "GET") {
    return { handler: handleListStudents, args: [] };
  }
  if (path === "/sis/students" && method === "POST") {
    return { handler: handleCreateStudent, args: [] };
  }

  if (path === "/sis/transfers" && method === "GET") {
    return { handler: handleListStudentTransfers, args: [] };
  }

  if (path === "/sis/enrollments" && method === "GET") {
    return { handler: handleListEnrollments, args: [] };
  }
  if (path === "/sis/enrollments" && method === "POST") {
    return { handler: handleCreateEnrollment, args: [] };
  }

  if (path === "/sis/admissions-conversion" && method === "GET") {
    return { handler: handleListAdmissionsConversion, args: [] };
  }
  if (path === "/sis/admissions-conversion" && method === "POST") {
    return { handler: handleAdmissionsConversion, args: [] };
  }

  // SCE-1 slice 3 — clearance dues-waivers (maker-checker). The approver queue
  // + decide are school-wide (not student-scoped); the raise is student-scoped
  // (matched below with the other /sis/students/:id/* routes).
  if (path === "/sis/clearance/waivers" && method === "GET") {
    return { handler: handleListPendingClearanceWaivers, args: [] };
  }
  const waiverDecideMatch = path.match(/^\/sis\/clearance\/waivers\/([^/]+)\/decide$/);
  if (waiverDecideMatch && method === "POST") {
    return { handler: handleDecideClearanceWaiver, args: [waiverDecideMatch[1]!] };
  }

  const enrollmentMatch = path.match(/^\/sis\/enrollments\/([^/]+)$/);
  if (enrollmentMatch && method === "PUT") {
    return { handler: handleUpdateEnrollment, args: [enrollmentMatch[1]!] };
  }

  const statusMatch = path.match(/^\/sis\/students\/([^/]+)\/status$/);
  if (statusMatch && method === "PATCH") {
    return { handler: handleUpdateStudentStatus, args: [statusMatch[1]!] };
  }

  const documentVerifyMatch = path.match(
    /^\/sis\/students\/([^/]+)\/documents\/([^/]+)\/verify$/,
  );
  if (documentVerifyMatch && method === "PATCH") {
    return {
      handler: handleVerifyStudentDocument,
      args: [documentVerifyMatch[1]!, documentVerifyMatch[2]!],
    };
  }

  const documentsMatch = path.match(/^\/sis\/students\/([^/]+)\/documents$/);
  if (documentsMatch) {
    if (method === "GET") {
      return { handler: handleListStudentDocuments, args: [documentsMatch[1]!] };
    }
    if (method === "POST") {
      return { handler: handleUploadStudentDocument, args: [documentsMatch[1]!] };
    }
  }

  // SCE-1 — Student Clearance / No-Dues report (read-only, cross-module).
  // Matched before the generic /certificates route so the specific path wins.
  const clearanceMatch = path.match(/^\/sis\/students\/([^/]+)\/clearance$/);
  if (clearanceMatch && method === "GET") {
    return { handler: handleStudentClearance, args: [clearanceMatch[1]!] };
  }
  // SCE-1 slice 3 — a maker raises a dues-waiver for the student (more specific
  // than /clearance, so match first).
  const waiverCreateMatch = path.match(/^\/sis\/students\/([^/]+)\/clearance\/waivers$/);
  if (waiverCreateMatch && method === "POST") {
    return { handler: handleCreateClearanceWaiver, args: [waiverCreateMatch[1]!] };
  }

  // SIS-D1 — transfer certificate (TC) engine. Matched BEFORE the generic
  // /certificates route so the more specific path wins.
  const transferCertMatch = path.match(
    /^\/sis\/students\/([^/]+)\/transfer-certificate$/,
  );
  if (transferCertMatch && method === "POST") {
    return {
      handler: handleIssueTransferCertificate,
      args: [transferCertMatch[1]!],
    };
  }

  // SIS-1 — certificate issuance register (bonafide/study/conduct) + list.
  const certificatesMatch = path.match(/^\/sis\/students\/([^/]+)\/certificates$/);
  if (certificatesMatch) {
    if (method === "GET") {
      return { handler: handleListCertificates, args: [certificatesMatch[1]!] };
    }
    if (method === "POST") {
      return { handler: handleIssueCertificate, args: [certificatesMatch[1]!] };
    }
  }

  // SIS-4 — read-only siblings / family list. More specific than the generic
  // /sis/students/:id GET, so matched before it.
  const siblingsMatch = path.match(/^\/sis\/students\/([^/]+)\/siblings$/);
  if (siblingsMatch && method === "GET") {
    return { handler: handleListStudentSiblings, args: [siblingsMatch[1]!] };
  }

  const profile360Match = path.match(/^\/sis\/students\/([^/]+)\/360$/);
  if (profile360Match && method === "GET") {
    return { handler: handleGetStudent360Profile, args: [profile360Match[1]!] };
  }

  const timelineMatch = path.match(/^\/sis\/students\/([^/]+)\/timeline$/);
  if (timelineMatch && method === "GET") {
    return { handler: handleGetStudentTimeline, args: [timelineMatch[1]!] };
  }

  const studentMatch = path.match(/^\/sis\/students\/([^/]+)$/);
  if (studentMatch) {
    const studentId = studentMatch[1]!;
    if (method === "GET") {
      return { handler: handleGetStudent, args: [studentId] };
    }
    if (method === "PUT") {
      return { handler: handleUpdateStudent, args: [studentId] };
    }
  }

  return null;
}

export async function routeSis(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/sis")) return null;

  const match = matchSisRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  for (const arg of match.args) {
    if (arg.includes("-") && !UUID_SEGMENT.test(arg)) {
      // Allow non-UUID legacy mock ids in path for compatibility
    }
  }

  return await match.handler(req, config, ...match.args);
}
