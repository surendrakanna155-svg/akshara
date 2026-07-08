import type { TenantQueryClient } from "../tenant_db.ts";
import { buildStudent360Profile } from "../sis/student_360_service.ts";
import { listStudentDistributions } from "../inventory_distribution/inventory_distribution_repository.ts";

export interface ParentExperienceHub {
  studentId: string;
  overview: {
    childName: string;
    classLabel: string;
    riskLevel: string;
    riskScore: number;
    pendingInventoryAcks: number;
    pendingPaymentRequests: number;
  };
  academics: {
    homeworkSubmitted: number;
    homeworkTotal: number;
    recentExams: Array<{ title: string; avgPct: number }>;
  };
  attendance: {
    present: number;
    absent: number;
    total: number;
    /** CANONICAL attendance % (attendance_percentage.ts); null when nothing to measure against. */
    pct: number | null;
  };
  inventory: {
    issued: number;
    pending: number;
    items: Array<{
      id: string;
      itemName: string;
      category: string;
      status: string;
      quantity: number;
    }>;
  };
  communication: { recentCount: number; lastMessageAt: string | null };
  guidance: {
    available: boolean;
    summary: string | null;
    reports: Array<{ mode: string; summary: string; createdAt: string }>;
  };
  homeworkIntelligence: {
    weakTopics: string[];
    suggestedRevision: string[];
    teacherRecommendations: string[];
  };
}

export async function buildParentExperienceHub(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
): Promise<ParentExperienceHub> {
  const profile = await buildStudent360Profile(
    client,
    organizationId,
    schoolId,
    studentId,
    "parent",
  );

  const distributions = await listStudentDistributions(client, { studentId });
  const pending = distributions.filter((d) =>
    ["distributed", "available"].includes(d.status)
  );
  const issued = distributions.filter((d) =>
    !["available", "cancelled"].includes(d.status)
  );

  const identity = profile.identity as Record<string, unknown>;
  const attendance = profile.attendance as {
    present: number;
    absent: number;
    total: number;
    percent: number | null;
  };
  const homework = profile.homework as Record<string, number>;
  const marksData = profile.marks as {
    exams?: Array<{ exam: string; averagePercent: number }>;
    items?: Array<{ examTitle: string; avgPct: number }>;
  };
  const examItems = marksData.items ??
    (marksData.exams ?? []).map((e) => ({ examTitle: e.exam, avgPct: e.averagePercent }));
  const risk = profile.risk as Record<string, unknown>;
  const communication = profile.communication as Record<string, unknown>;

  const present = Number(attendance.present ?? 0);
  const absent = Number(attendance.absent ?? 0);
  const total = Number(attendance.total ?? 0);
  // CANONICAL attendance-% (2026-07-09, attendance_percentage.ts): trust the
  // percentage already computed by buildStudent360Profile — never recompute
  // present/total locally (that was the divergent formula this fixes).
  const attendancePct = attendance.percent ?? null;

  const paymentPending = await client.queryObject<{ count: number }>(
    `SELECT count(*)::int AS count FROM payment_requests
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
       AND status IN ('pending', 'awaiting_payment')`,
    [studentId, organizationId, schoolId],
  );

  const guidanceRows = await client.queryObject<{
    mode: string;
    summary: string | null;
    created_at: string;
  }>(
    `SELECT mode, report->>'progressSummary' AS summary, created_at
     FROM intel_parent_guidance_reports
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
       AND status = 'published'
     ORDER BY created_at DESC LIMIT 5`,
    [studentId, organizationId, schoolId],
  );

  const weakMarks = await client.queryObject<{ exam_title: string; avg_pct: number }>(
    `SELECT exam_title,
       coalesce(avg(
         CASE WHEN max_marks > 0 THEN (marks_obtained::float / max_marks) * 100 ELSE 0 END
       ), 0)::int AS avg_pct
     FROM exam_mark_entries
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
     GROUP BY exam_title
     HAVING coalesce(avg(
       CASE WHEN max_marks > 0 THEN (marks_obtained::float / max_marks) * 100 ELSE 0 END
     ), 0) < 60
     ORDER BY avg_pct ASC
     LIMIT 5`,
    [studentId, organizationId, schoolId],
  );

  const homeworkTargets = await client.queryObject<{ title: string }>(
    `SELECT DISTINCT coalesce(comment, 'Review teacher feedback') AS title
     FROM homework_submissions
     WHERE student_id = $1 AND organization_id = $2 AND school_id = $3
       AND status IN ('returned', 'reviewed')
       AND comment IS NOT NULL AND comment <> ''
     ORDER BY submitted_at DESC
     LIMIT 5`,
    [studentId, organizationId, schoolId],
  );

  const guidanceReports = guidanceRows
    .filter((r) => r.summary)
    .map((r) => ({
      mode: r.mode,
      summary: r.summary!,
      createdAt: r.created_at,
    }));

  const weakTopics = weakMarks.length > 0
    ? weakMarks.map((m) => `${m.exam_title} (${m.avg_pct}%)`)
    : ["No critical weak areas detected"];

  const hwSubmitted = Number(homework.submitted ?? 0);
  const hwTotal = Number(homework.total ?? 0);
  const pendingHw = Math.max(0, hwTotal - hwSubmitted);

  const latestSummary = guidanceReports[0]?.summary ?? null;

  return {
    studentId,
    overview: {
      childName: String(identity.displayName ?? identity.fullName ?? "Student"),
      classLabel: String(identity.className ?? identity.classLabel ?? ""),
      riskLevel: String(risk.riskLevel ?? "unknown"),
      riskScore: Number(risk.riskScore ?? 0),
      pendingInventoryAcks: pending.length,
      pendingPaymentRequests: paymentPending[0]?.count ?? 0,
    },
    academics: {
      homeworkSubmitted: Number(homework.submitted ?? 0),
      homeworkTotal: Number(homework.total ?? 0),
      recentExams: examItems.slice(0, 5).map((e) => ({
        title: e.examTitle,
        avgPct: e.avgPct,
      })),
    },
    attendance: {
      present,
      absent,
      total,
      pct: attendancePct,
    },
    inventory: {
      issued: issued.length,
      pending: pending.length,
      items: distributions.slice(0, 20).map((d) => ({
        id: d.id,
        itemName: d.itemName,
        category: d.category,
        status: d.status,
        quantity: d.quantity,
      })),
    },
    communication: {
      recentCount: Number(communication.recentCount ?? communication.pendingNotices ?? 0),
      lastMessageAt: (communication.lastMessageAt as string | null) ??
        (communication.lastContactAt as string | null) ?? null,
    },
    guidance: {
      available: guidanceReports.length > 0,
      summary: latestSummary,
      reports: guidanceReports,
    },
    homeworkIntelligence: {
      weakTopics: weakTopics.slice(0, 5),
      suggestedRevision: weakTopics.length > 0
        ? weakTopics.map((t) => `Revise ${t.split(' (')[0]}`)
        : ["Maintain daily revision schedule"],
      teacherRecommendations: [
        ...homeworkTargets.map((t) => t.title),
        ...(pendingHw > 0 ? [`Complete ${pendingHw} pending homework assignment(s)`] : []),
        "Review teacher feedback before the next class",
      ].slice(0, 5),
    },
  };
}

export async function recordParentAcknowledgement(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: {
    studentId: string;
    distributionId: string;
    acknowledgedBy: string;
    acknowledgementType: "received" | "replacement_requested";
    notes?: string;
  },
): Promise<{ id: string }> {
  const rows = await client.queryObject<{ id: string }>(
    `INSERT INTO parent_item_acknowledgements (
       organization_id, school_id, student_id, distribution_id,
       acknowledged_by, acknowledgement_type, notes
     ) VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (distribution_id, acknowledged_by) DO UPDATE
       SET acknowledgement_type = EXCLUDED.acknowledgement_type,
           notes = EXCLUDED.notes
     RETURNING id`,
    [
      organizationId,
      schoolId,
      input.studentId,
      input.distributionId,
      input.acknowledgedBy,
      input.acknowledgementType,
      input.notes ?? null,
    ],
  );
  const status = input.acknowledgementType === "replacement_requested"
    ? "replacement_requested"
    : "parent_acknowledged";
  await client.queryObject(
    `UPDATE inv_student_distributions
     SET status = $1, acknowledged_at = timezone('utc', now())
     WHERE id = $2 AND student_id = $3`,
    [status, input.distributionId, input.studentId],
  );
  return rows[0]!;
}
