import type { TenantQueryClient } from "../tenant_db.ts";
import { getStudent, StudentNotFoundError } from "./sis_students_repository.ts";

export interface Student360Profile {
  identity: Record<string, unknown>;
  admissions: Record<string, unknown>;
  attendance: Record<string, unknown>;
  marks: Record<string, unknown>;
  homework: Record<string, unknown>;
  communication: Record<string, unknown>;
  fees: Record<string, unknown>;
  inventory: Record<string, unknown>;
  activities: Record<string, unknown>;
  achievements: Record<string, unknown>;
  risk: Record<string, unknown>;
  parentInformation: Record<string, unknown>;
}

export interface StudentTimelineEvent {
  id: string;
  eventType: string;
  eventAt: string;
  title: string;
  summary: string | null;
  sourceModule: string;
  payload: Record<string, unknown>;
}

export async function buildStudent360Profile(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  viewMode: "admin" | "teacher" | "principal" | "parent",
): Promise<Student360Profile> {
  const detail = await getStudent(client, organizationId, schoolId, studentId);
  if (!detail) throw new StudentNotFoundError(studentId);

  const [attendance, marks, homework, risk, inventory, fees] = await Promise.all([
    client.queryObject<{
      present: number;
      absent: number;
      total: number;
    }>(
      `SELECT
       count(*) FILTER (WHERE mark = 'present')::int AS present,
       count(*) FILTER (WHERE mark = 'absent')::int AS absent,
       count(*)::int AS total
     FROM attendance_records
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3`,
      [studentId, organizationId, schoolId],
    ),
    client.queryObject<{
      exam_title: string;
      avg_pct: number;
    }>(
      `SELECT exam_title,
       coalesce(avg(
         CASE WHEN max_marks > 0 THEN (marks_obtained::float / max_marks) * 100 ELSE 0 END
       ), 0)::int AS avg_pct
     FROM exam_mark_entries
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
     GROUP BY exam_title
     ORDER BY exam_title`,
      [studentId, organizationId, schoolId],
    ),
    client.queryObject<{ submitted: number; total: number }>(
      `SELECT
       count(*) FILTER (WHERE status IN ('submitted', 'reviewed'))::int AS submitted,
       count(*)::int AS total
     FROM homework_submissions
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3`,
      [studentId, organizationId, schoolId],
    ),
    client.queryObject<{
      risk_score: number;
      risk_level: string;
      reasons: unknown;
    }>(
      `SELECT risk_score, risk_level, reasons
     FROM intel_student_risk_snapshots
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY computed_at DESC LIMIT 1`,
      [studentId, organizationId, schoolId],
    ),
    client.queryObject<{
      item_name: string;
      category: string;
      status: string;
    }>(
      `SELECT c.name AS item_name, c.category, d.status
     FROM inv_student_distributions d
     JOIN inv_catalog_items c ON c.id = d.catalog_item_id
     WHERE d.student_id = $1 AND d.organization_id = $2 AND d.school_id = $3
     ORDER BY d.created_at DESC
     LIMIT 20`,
      [studentId, organizationId, schoolId],
    ),
    client.queryObject<{ pending_amount: number; invoice_count: number }>(
      `SELECT
       coalesce(sum(outstanding_amount), 0)::int AS pending_amount,
       count(*)::int AS invoice_count
     FROM finance_invoices
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
       AND invoice_status NOT IN ('paid', 'cancelled')`,
      [studentId, organizationId, schoolId],
    ),
  ]);

  const includeSensitive = viewMode !== "parent";

  return {
    identity: {
      studentId: detail.student.id,
      studentCode: detail.student.student_code,
      displayName: detail.student.display_name,
      status: detail.student.status,
      className: detail.currentEnrollment?.class_name ?? null,
      sectionName: detail.currentEnrollment?.section_name ?? null,
      rollNumber: detail.currentEnrollment?.roll_number ?? null,
    },
    admissions: {
      admissionNumber: detail.profile?.admission_number ?? null,
      dateOfBirth: detail.profile?.date_of_birth ?? null,
      gender: detail.profile?.gender ?? null,
    },
    attendance: {
      present: attendance[0]?.present ?? 0,
      absent: attendance[0]?.absent ?? 0,
      total: attendance[0]?.total ?? 0,
      percent: attendance[0]?.total
        ? Math.round(((attendance[0].present) / attendance[0].total) * 100)
        : null,
    },
    marks: {
      exams: marks.map((m) => ({ exam: m.exam_title, averagePercent: m.avg_pct })),
    },
    homework: {
      submitted: homework[0]?.submitted ?? 0,
      total: homework[0]?.total ?? 0,
      completionRate: homework[0]?.total
        ? Math.round(((homework[0].submitted) / homework[0].total) * 100)
        : null,
    },
    communication: includeSensitive ? { pendingNotices: 0, lastContactAt: null } : { summary: "Available on request" },
    fees: includeSensitive
      ? {
        pendingAmount: fees[0]?.pending_amount ?? 0,
        openInvoices: fees[0]?.invoice_count ?? 0,
      }
      : { summary: "Contact school office for fee details" },
    inventory: {
      items: inventory.map((i) => ({
        name: i.item_name,
        category: i.category,
        status: i.status,
      })),
    },
    activities: { clubs: [], events: [] },
    achievements: { badges: [], milestones: [] },
    risk: risk[0]
      ? {
        riskScore: risk[0].risk_score,
        riskLevel: risk[0].risk_level,
        reasons: risk[0].reasons,
      }
      : { riskScore: 0, riskLevel: "low", reasons: [] },
    parentInformation: {
      guardians: detail.guardians.map((g) => ({
        name: g.display_name,
        relationship: g.relationship,
        phone: includeSensitive ? g.phone : null,
        isPrimary: g.is_primary,
      })),
    },
  };
}

export async function buildStudentTimeline(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<StudentTimelineEvent[]> {
  const [stored, attendanceEvents, paymentEvents, riskEvents] = await Promise.all([
    client.queryObject<{
      id: string;
      event_type: string;
      event_at: string;
      title: string;
      summary: string | null;
      source_module: string;
      payload: Record<string, unknown>;
    }>(
      `SELECT id, event_type, event_at, title, summary, source_module, payload
     FROM student_timeline_events
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY event_at DESC
     LIMIT 100`,
      [studentId, organizationId, schoolId],
    ),
    client.queryObject<{
      id: string;
      mark: string;
      created_at: string;
    }>(
      `SELECT id, mark, created_at
     FROM attendance_records
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY created_at DESC LIMIT 20`,
      [studentId, organizationId, schoolId],
    ),
    client.queryObject<{
      id: string;
      amount: number;
      status: string;
      created_at: string;
    }>(
      `SELECT id, amount, status, created_at
     FROM payment_requests
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY created_at DESC LIMIT 10`,
      [studentId, organizationId, schoolId],
    ),
    client.queryObject<{
      id: string;
      risk_level: string;
      risk_score: number;
      computed_at: string;
    }>(
      `SELECT id, risk_level, risk_score, computed_at
     FROM intel_student_risk_snapshots
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY computed_at DESC LIMIT 10`,
      [studentId, organizationId, schoolId],
    ),
  ]);

  const live: StudentTimelineEvent[] = [];
  for (const row of attendanceEvents) {
    live.push({
      id: `att-${row.id}`,
      eventType: "attendance",
      eventAt: row.created_at,
      title: `Attendance marked ${row.mark}`,
      summary: null,
      sourceModule: "attendance",
      payload: { mark: row.mark },
    });
  }

  for (const row of paymentEvents) {
    live.push({
      id: `pay-${row.id}`,
      eventType: "payment",
      eventAt: row.created_at,
      title: `Payment ${row.status}`,
      summary: `Amount ${row.amount}`,
      sourceModule: "finance",
      payload: { amount: row.amount, status: row.status },
    });
  }

  for (const row of riskEvents) {
    live.push({
      id: `risk-${row.id}`,
      eventType: "risk_change",
      eventAt: row.computed_at,
      title: `Risk level ${row.risk_level}`,
      summary: `Score ${row.risk_score}`,
      sourceModule: "intelligence",
      payload: { riskLevel: row.risk_level, riskScore: row.risk_score },
    });
  }

  const merged = [
    ...stored.map((e) => ({
      id: e.id,
      eventType: e.event_type,
      eventAt: e.event_at,
      title: e.title,
      summary: e.summary,
      sourceModule: e.source_module,
      payload: e.payload,
    })),
    ...live,
  ];

  merged.sort((a, b) => new Date(b.eventAt).getTime() - new Date(a.eventAt).getTime());
  return merged.slice(0, 100);
}
