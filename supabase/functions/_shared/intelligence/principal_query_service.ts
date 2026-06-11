import type { TenantQueryClient } from "../tenant_db.ts";
import { listRiskSnapshots } from "./student_risk_repository.ts";

export interface PrincipalQueryResult {
  query: string;
  intent: string;
  summary: string;
  count: number;
  items: Array<Record<string, unknown>>;
}

type QueryIntent =
  | "low_attendance"
  | "high_risk"
  | "fee_defaulters"
  | "homework_gaps"
  | "unknown";

export function detectPrincipalQueryIntent(query: string): QueryIntent {
  const q = query.toLowerCase();
  if (q.includes("attendance") && (q.includes("below") || q.includes("low") || q.includes("<"))) {
    return "low_attendance";
  }
  if (q.includes("risk") || q.includes("at-risk") || q.includes("at risk")) {
    return "high_risk";
  }
  if (q.includes("fee") && (q.includes("default") || q.includes("pending") || q.includes("unpaid"))) {
    return "fee_defaulters";
  }
  if (q.includes("homework") && (q.includes("missing") || q.includes("gap") || q.includes("pending"))) {
    return "homework_gaps";
  }
  return "unknown";
}

function studentName(row: { student_id: string; inputs: unknown }): string {
  const inputs = row.inputs as { student_name?: string } | null;
  return inputs?.student_name ?? row.student_id;
}

function attendancePercent(row: { inputs: unknown }): number {
  const inputs = row.inputs as { attendance_percent?: number } | null;
  return inputs?.attendance_percent ?? 100;
}

function homeworkRate(row: { inputs: unknown }): number {
  const inputs = row.inputs as { homework_completion_rate?: number } | null;
  return inputs?.homework_completion_rate ?? 100;
}

function feeOutstanding(row: { inputs: unknown }): number {
  const inputs = row.inputs as { fee_outstanding?: number } | null;
  return inputs?.fee_outstanding ?? 0;
}

export async function executePrincipalQuery(
  client: TenantQueryClient,
  queryText: string,
): Promise<PrincipalQueryResult> {
  const query = queryText.trim();
  const intent = detectPrincipalQueryIntent(query);
  const snapshots = await listRiskSnapshots(client, {});

  if (intent === "low_attendance") {
    const threshold = 75;
    const matches = snapshots.filter((s) => attendancePercent(s) < threshold);
    return {
      query,
      intent,
      summary: `${matches.length} students below ${threshold}% attendance`,
      count: matches.length,
      items: matches.slice(0, 50).map((s) => ({
        studentId: s.student_id,
        studentName: studentName(s),
        className: s.class_name,
        attendancePercent: attendancePercent(s),
        riskLevel: s.risk_level,
      })),
    };
  }

  if (intent === "high_risk") {
    const matches = snapshots.filter((s) =>
      s.risk_level === "critical" || s.risk_level === "high"
    );
    return {
      query,
      intent,
      summary: `${matches.length} high-risk students (critical + high)`,
      count: matches.length,
      items: matches.slice(0, 50).map((s) => ({
        studentId: s.student_id,
        studentName: studentName(s),
        className: s.class_name,
        riskScore: s.risk_score,
        riskLevel: s.risk_level,
      })),
    };
  }

  if (intent === "fee_defaulters") {
    const matches = snapshots.filter((s) => feeOutstanding(s) > 0);
    return {
      query,
      intent,
      summary: `${matches.length} students with outstanding fee balance`,
      count: matches.length,
      items: matches.slice(0, 50).map((s) => ({
        studentId: s.student_id,
        studentName: studentName(s),
        className: s.class_name,
        feeOutstanding: feeOutstanding(s),
        riskLevel: s.risk_level,
      })),
    };
  }

  if (intent === "homework_gaps") {
    const matches = snapshots.filter((s) => homeworkRate(s) < 70);
    return {
      query,
      intent,
      summary: `${matches.length} students with homework completion below 70%`,
      count: matches.length,
      items: matches.slice(0, 50).map((s) => ({
        studentId: s.student_id,
        studentName: studentName(s),
        className: s.class_name,
        homeworkCompletionRate: homeworkRate(s),
        riskLevel: s.risk_level,
      })),
    };
  }

  const atRisk = snapshots.filter((s) => s.risk_level !== "low");
  return {
    query,
    intent: "unknown",
    summary:
      `Could not match query intent. Showing ${atRisk.length} students above low risk. ` +
      `Try: "students below 75% attendance", "high risk students", "fee defaulters".`,
    count: atRisk.length,
    items: atRisk.slice(0, 20).map((s) => ({
      studentId: s.student_id,
      studentName: studentName(s),
      className: s.class_name,
      riskLevel: s.risk_level,
      riskScore: s.risk_score,
    })),
  };
}
