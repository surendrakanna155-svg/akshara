import type { AppConfig } from "../config.ts";
import { envelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  listDefaulterAccounts,
  listRecentContactsForStudents,
} from "./finance_recovery_repository.ts";

// STF-3 / INT-2 — GET /finance/defaulters. Aggregates real overdue student
// accounts into the DefaultersDashboardData contract the Flutter client maps
// (kpis, agingBuckets, defaulters[], aiInsight, aiActionLabel). guardianPhone is
// the student's primary guardian's real phone so the WhatsApp surface works.

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ?? requireSchoolOperationalScope(claims);
}

function formatAmount(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(2);
}

type Bucket = "current" | "days_1_to_30" | "days_31_to_60" | "days_61_to_90" | "over_90";

function bucketFor(daysOverdue: number): Bucket {
  if (daysOverdue <= 0) return "current";
  if (daysOverdue <= 30) return "days_1_to_30";
  if (daysOverdue <= 60) return "days_31_to_60";
  if (daysOverdue <= 90) return "days_61_to_90";
  return "over_90";
}

const BUCKET_LABELS: Record<Bucket, string> = {
  current: "Current",
  days_1_to_30: "1–30 days",
  days_31_to_60: "31–60 days",
  days_61_to_90: "61–90 days",
  over_90: "90+ days",
};

export async function handleFinanceDefaulters(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const { rows, contacts } = await withTenantContext(config, auth.claims, async (db) => {
      const defaulterRows = await listDefaulterAccounts(db, orgId, schoolId);
      // FIN-R4: attach real recovery-contact history (was hardcoded empty).
      const contactRows = await listRecentContactsForStudents(
        db,
        orgId,
        schoolId ?? "",
        defaulterRows.map((r) => r.student_id),
      );
      return { rows: defaulterRows, contacts: contactRows };
    });

    // Group contacts by student, preserving recency order (most recent first).
    const contactsByStudent = new Map<string, {
      id: string;
      timestamp: string;
      channel: string;
      outcome: string;
      notes: string;
    }[]>();
    for (const c of contacts) {
      const list = contactsByStudent.get(c.student_id) ?? [];
      list.push({
        id: c.id,
        timestamp: c.created_at,
        channel: c.channel,
        outcome: c.outcome,
        notes: c.notes,
      });
      contactsByStudent.set(c.student_id, list);
    }

    const defaulters = rows.map((r) => {
      const outstanding = parseFloat(r.outstanding) || 0;
      const daysOverdue = parseInt(r.days_overdue, 10) || 0;
      const bucket = bucketFor(daysOverdue);
      // Recovery likelihood decays with age of arrears (real, deterministic).
      const collectionProbability = Math.max(
        5,
        Math.min(95, 90 - daysOverdue),
      );
      const history = contactsByStudent.get(r.student_id) ?? [];
      return {
        id: r.student_id,
        studentName: r.student_name,
        admissionNumber: r.admission_number,
        classLabel: r.class_label,
        overdueAmount: formatAmount(outstanding),
        daysOverdue,
        bucket,
        lastContact: history.length > 0 ? history[0]!.timestamp : "",
        collectionProbability,
        feeAccountId: r.fee_account_id,
        guardianPhone: r.guardian_phone ?? "",
        contactHistory: history,
      };
    });

    // Only students actually past due count as defaulters for the aging view.
    const overdue = defaulters.filter((d) => d.daysOverdue > 0);
    const totalOverdue = overdue.reduce(
      (sum, d) => sum + (parseFloat(d.overdueAmount) || 0),
      0,
    );

    const bucketOrder: Bucket[] = [
      "days_1_to_30",
      "days_31_to_60",
      "days_61_to_90",
      "over_90",
    ];
    const agingBuckets = bucketOrder.map((bucket) => {
      const inBucket = overdue.filter((d) => d.bucket === bucket);
      const total = inBucket.reduce(
        (sum, d) => sum + (parseFloat(d.overdueAmount) || 0),
        0,
      );
      return {
        bucket,
        label: BUCKET_LABELS[bucket],
        studentCount: inBucket.length,
        totalAmount: formatAmount(total),
      };
    });

    const critical = overdue.filter((d) => d.daysOverdue > 60).length;
    const kpis = [
      {
        id: "defaulter_count",
        value: String(overdue.length),
        label: "Defaulters",
        accentName: overdue.length > 0 ? "warning" : "success",
      },
      {
        id: "overdue_amount",
        value: formatAmount(totalOverdue),
        label: "Total overdue",
        accentName: totalOverdue > 0 ? "warning" : "neutral",
      },
      {
        id: "critical_count",
        value: String(critical),
        label: "Critical (60+ days)",
        accentName: critical > 0 ? "error" : "success",
      },
    ];

    const aiInsight = overdue.length === 0
      ? "No overdue fee accounts. Collections are current."
      : `${overdue.length} student${overdue.length === 1 ? "" : "s"} overdue (₹${
        formatAmount(totalOverdue)
      } outstanding)${critical > 0 ? `, ${critical} critical (60+ days)` : ""}. ` +
        "Prioritise the highest-balance and oldest arrears for follow-up.";
    const aiActionLabel = overdue.length === 0
      ? "All clear"
      : "Message top defaulters";

    return jsonResponse(envelope({
      kpis,
      agingBuckets,
      defaulters,
      aiInsight,
      aiActionLabel,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    throw error;
  }
}
