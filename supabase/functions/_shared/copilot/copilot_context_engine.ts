import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { claimsHasPermission } from "./copilot_repository.ts";
import type { CopilotAssistantType } from "./copilot_types.ts";
import { loadAdmissionsIntelligence } from "../admissions/admissions_intelligence_repository.ts";
import { computeAnalyticsBundle } from "../analytics/analytics_repository.ts";
import {
  getSchoolConflicts,
  getSchoolWorkload,
  getTimetableSummary,
} from "../timetable/timetable_repository.ts";
import { buildSchedulingRecommendations } from "../timetable/timetable_scheduling_advisor.ts";

export interface CopilotContextBundle {
  school: Record<string, unknown>;
  academicYear: Record<string, unknown>;
  finance: Record<string, unknown>;
  admissions: Record<string, unknown>;
  sis: Record<string, unknown>;
  communication: Record<string, unknown>;
  timetable: Record<string, unknown>;
  teacherOps: Record<string, unknown>;
  analytics: Record<string, unknown>;
  studentLookup: Record<string, unknown>;
}

export async function loadCopilotContext(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  organizationId: string,
  schoolId: string,
  assistantType: CopilotAssistantType,
  userMessage: string,
): Promise<CopilotContextBundle> {
  const [schoolRow] = await db.queryObject<{ name: string; code: string }>(
    `SELECT name, code FROM schools WHERE id = $1 AND organization_id = $2`,
    [schoolId, organizationId],
  );

  const school = {
    schoolId,
    name: schoolRow?.name ?? "Unknown school",
    code: schoolRow?.code ?? "",
  };

  const yearRows = await db.queryObject<{ year_label: string; status: string }>(
    `SELECT year_label, status FROM academic_years
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY is_current DESC, created_at DESC LIMIT 1`,
    [organizationId, schoolId],
  );
  const academicYear = {
    label: yearRows[0]?.year_label ?? "Not configured",
    status: yearRows[0]?.status ?? "unknown",
  };

  const finance = claimsHasPermission(claims, "viewFinance") &&
      (assistantType === "finance" || assistantType === "communication" ||
        assistantType === "parentGuidance")
    ? await loadFinanceContext(db, organizationId, schoolId)
    : { access: "denied" };

  const admissions = claimsHasPermission(claims, "viewAdmissions") &&
      assistantType === "admissions"
    ? await loadAdmissionsContext(db, organizationId, schoolId)
    : { access: "denied" };

  const sis = claimsHasPermission(claims, "viewSis") &&
      (assistantType === "sis" || assistantType === "academic" || assistantType === "parentGuidance")
    ? await loadSisContext(db, organizationId, schoolId)
    : { access: "denied" };

  const communication = claimsHasPermission(claims, "viewCommunications") &&
      (assistantType === "communication" || assistantType === "parentGuidance")
    ? await loadCommunicationContext(db, organizationId, schoolId)
    : { access: "denied" };

  const studentLookup = claimsHasPermission(claims, "viewSis") &&
      /\b(student|lookup|enrollment)\b/i.test(userMessage)
    ? await loadStudentLookupContext(db, organizationId, schoolId)
    : { access: "not_requested" };

  const timetable = claimsHasPermission(claims, "viewAcademicTimetable") &&
      (assistantType === "academic" || assistantType === "teacher")
    ? await loadTimetableContext(db, organizationId, schoolId, yearRows[0]?.year_label)
    : { access: "denied" };

  const teacherOps = assistantType === "teacher"
    ? await loadTeacherOpsContext(db, organizationId, schoolId)
    : { access: "denied" };

  const analytics = claimsHasPermission(claims, "viewAnalytics") &&
      (assistantType === "academic" || assistantType === "principal")
    ? await loadAnalyticsContext(db, organizationId, schoolId)
    : { access: "denied" };

  return {
    school,
    academicYear,
    finance,
    admissions,
    sis,
    communication,
    timetable,
    teacherOps,
    analytics,
    studentLookup,
  };
}

async function loadTeacherOpsContext(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>> {
  const todaySessions = await db.queryCount(
    `SELECT count(*)::text AS count FROM attendance_sessions
     WHERE organization_id = $1 AND school_id = $2 AND session_date = CURRENT_DATE`,
    [organizationId, schoolId],
  );
  const submittedToday = await db.queryCount(
    `SELECT count(*)::text AS count FROM attendance_sessions
     WHERE organization_id = $1 AND school_id = $2 AND session_date = CURRENT_DATE
       AND status = 'submitted'`,
    [organizationId, schoolId],
  );
  return {
    access: "granted",
    todaySessions,
    submittedToday,
    readOnly: true,
  };
}

async function loadFinanceContext(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>> {
  const [collections] = await db.queryObject<{ count: number; total: string }>(
    `SELECT count(*)::int AS count, coalesce(sum(amount_collected), 0)::text AS total
     FROM finance_collections
     WHERE organization_id = $1 AND school_id = $2 AND collection_status = 'completed'`,
    [organizationId, schoolId],
  );
  const [apOpen] = await db.queryObject<{ count: number; amount: number }>(
    `SELECT count(*)::int AS count, coalesce(sum(amount), 0)::int AS amount
     FROM finance_ap_commitments
     WHERE organization_id = $1 AND school_id = $2 AND status = 'open'`,
    [organizationId, schoolId],
  );
  return {
    access: "granted",
    completedCollections: collections?.count ?? 0,
    collectedAmount: collections?.total ?? "0",
    openApCommitments: apOpen?.count ?? 0,
    openApAmountPaise: apOpen?.amount ?? 0,
  };
}

async function loadAdmissionsContext(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>> {
  // B4 — ground the admissions persona in the real B1 CRM funnel plus the
  // deterministic next-best-actions, instead of a bare lead count.
  const intelligence = await loadAdmissionsIntelligence(db, organizationId, schoolId);

  const appRows = await db.queryObject<{ status: string; count: number }>(
    `SELECT status, count(*)::int AS count FROM admissions_applications
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY status`,
    [organizationId, schoolId],
  );

  return {
    access: "granted",
    leadCount: String(intelligence.funnel.totalLeads),
    funnel: intelligence.funnel,
    nextBestActions: intelligence.nextBestActions,
    applicationsByStatus: Object.fromEntries(appRows.map((r) => [r.status, r.count])),
  };
}

async function loadSisContext(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>> {
  const studentCount = await db.queryCount(
    `SELECT count(*)::text AS count FROM students
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const enrollmentCount = await db.queryCount(
    `SELECT count(*)::text AS count FROM sis_student_enrollments
     WHERE organization_id = $1 AND school_id = $2 AND is_current = true`,
    [organizationId, schoolId],
  );
  const classCount = await db.queryCount(
    `SELECT count(*)::text AS count FROM classes
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  return {
    access: "granted",
    studentCount,
    activeEnrollments: enrollmentCount,
    academicClasses: classCount,
  };
}

async function loadCommunicationContext(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>> {
  const templateCount = await db.queryCount(
    `SELECT count(*)::text AS count FROM notification_templates
     WHERE organization_id = $1`,
    [organizationId],
  );
  const broadcastCount = await db.queryCount(
    `SELECT count(*)::text AS count FROM comm_broadcasts
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const pendingDeliveries = await db.queryCount(
    `SELECT count(*)::text AS count FROM notification_deliveries
     WHERE organization_id = $1 AND status IN ('pending', 'queued')`,
    [organizationId],
  );
  const sentDeliveries = await db.queryCount(
    `SELECT count(*)::text AS count FROM notification_deliveries
     WHERE organization_id = $1 AND status = 'sent'`,
    [organizationId],
  );
  return {
    access: "granted",
    templateCount,
    broadcastCount,
    pendingDeliveries,
    sentDeliveries,
    channels: ["sms", "email", "push", "whatsapp"],
    draftMode: "guidance_only",
  };
}

async function loadTimetableContext(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  yearLabel?: string,
): Promise<Record<string, unknown>> {
  const yearFilter = yearLabel
    ? await db.queryObject<{ id: string }>(
      `SELECT id FROM academic_years
       WHERE organization_id = $1 AND school_id = $2 AND year_label = $3 LIMIT 1`,
      [organizationId, schoolId, yearLabel],
    )
    : [];
  const academicYearId = yearFilter[0]?.id;
  if (!academicYearId) {
    return { access: "granted", configured: false };
  }

  const summary = await getTimetableSummary(db, organizationId, schoolId, academicYearId);
  const conflicts = await getSchoolConflicts(db, organizationId, schoolId, academicYearId);
  const workload = await getSchoolWorkload(db, organizationId, schoolId, academicYearId);
  const recommendations = buildSchedulingRecommendations({
    validation: {
      valid: conflicts.length === 0 && summary.gapCount === 0,
      conflictCount: conflicts.length,
      gapCount: summary.gapCount,
      conflicts: conflicts.slice(0, 5),
      gaps: [],
    },
    workload,
    summary,
  });

  return {
    access: "granted",
    configured: true,
    summary,
    conflictCount: conflicts.length,
    overloadedTeachers: workload.filter((w) => w.isOverloaded).length,
    recommendations: recommendations.slice(0, 5),
    readOnly: true,
  };
}

async function loadAnalyticsContext(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>> {
  const bundle = await computeAnalyticsBundle(db, organizationId, schoolId);
  return {
    access: "granted",
    dashboard: bundle.dashboard,
    health: bundle.health,
    risks: bundle.risks,
    trends: bundle.trends,
    anomalies: bundle.anomalies,
    principalSummary: bundle.principalSummary,
    weeklyBriefing: bundle.weeklyBriefing,
    recommendations: bundle.recommendations,
    readOnly: true,
  };
}

async function loadStudentLookupContext(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ id: string; display_name: string; status: string }>(
    `SELECT id::text, display_name, status FROM students
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY updated_at DESC LIMIT 5`,
    [organizationId, schoolId],
  );
  return {
    access: "granted",
    recentStudents: rows.map((r) => ({
      id: r.id,
      name: r.display_name,
      status: r.status,
    })),
  };
}
