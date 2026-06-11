import type { TenantQueryClient } from "../tenant_db.ts";

export interface PilotDashboardSnapshot {
  onboardingStatus: string;
  setupWizardCompleted: boolean;
  importHealth: {
    totalJobs: number;
    committedJobs: number;
    failedRows: number;
    lastImportAt: string | null;
  };
  teacherActivation: {
    total: number;
    active: number;
    pending: number;
    activationRate: number;
  };
  parentActivation: {
    total: number;
    active: number;
    pending: number;
    activationRate: number;
  };
  otpDelivery: {
    sentLast7Days: number;
    failedLast7Days: number;
    deliveryRate: number;
  };
  pilotScore: number;
}

export async function buildPilotDashboard(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<PilotDashboardSnapshot> {
  const wizard = await db.queryObject<{ status: string }>(
    `SELECT status FROM setup_wizard_sessions
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY created_at DESC LIMIT 1`,
    [orgId, schoolId],
  );

  const imports = await db.queryObject<{
    total: string;
    committed: string;
    failed_rows: string;
    last_at: string | null;
  }>(
    `SELECT count(*)::text AS total,
            count(*) FILTER (WHERE status = 'committed')::text AS committed,
            coalesce(sum(invalid_rows + duplicate_rows), 0)::text AS failed_rows,
            max(updated_at)::text AS last_at
     FROM onboarding_import_jobs
     WHERE organization_id = $1 AND school_id = $2`,
    [orgId, schoolId],
  );

  const teachers = await db.queryObject<{ total: string; active: string }>(
    `SELECT count(*)::text AS total,
            count(*) FILTER (WHERE status = 'active')::text AS active
     FROM school_memberships
     WHERE school_id = $1 AND role = 'teacher'`,
    [schoolId],
  );

  const parents = await db.queryObject<{ total: string; active: string }>(
    `SELECT count(*)::text AS total,
            count(*) FILTER (WHERE status = 'active')::text AS active
     FROM school_memberships
     WHERE school_id = $1 AND role = 'parent'`,
    [schoolId],
  );

  const otp = await db.queryObject<{ sent: string; failed: string }>(
    `SELECT count(*) FILTER (WHERE consumed_at IS NOT NULL)::text AS sent,
            count(*) FILTER (WHERE consumed_at IS NULL AND expires_at < now())::text AS failed
     FROM otp_requests
     WHERE context_school_id = $1 AND created_at > now() - interval '7 days'`,
    [schoolId],
  );

  const teacherTotal = Number(teachers[0]?.total ?? 0);
  const teacherActive = Number(teachers[0]?.active ?? 0);
  const parentTotal = Number(parents[0]?.total ?? 0);
  const parentActive = Number(parents[0]?.active ?? 0);
  const otpSent = Number(otp[0]?.sent ?? 0);
  const otpFailed = Number(otp[0]?.failed ?? 0);
  const otpTotal = otpSent + otpFailed;

  const setupWizardCompleted = wizard[0]?.status === "completed";
  const teacherRate = teacherTotal > 0 ? Math.round((teacherActive / teacherTotal) * 100) : 0;
  const parentRate = parentTotal > 0 ? Math.round((parentActive / parentTotal) * 100) : 0;
  const otpRate = otpTotal > 0 ? Math.round((otpSent / otpTotal) * 100) : 100;

  const pilotScore = computePilotScore({
    setupWizardCompleted,
    importCommitted: Number(imports[0]?.committed ?? 0) > 0,
    teacherRate,
    parentRate,
    otpRate,
  });

  return {
    onboardingStatus: wizard[0]?.status ?? "not_started",
    setupWizardCompleted,
    importHealth: {
      totalJobs: Number(imports[0]?.total ?? 0),
      committedJobs: Number(imports[0]?.committed ?? 0),
      failedRows: Number(imports[0]?.failed_rows ?? 0),
      lastImportAt: imports[0]?.last_at ?? null,
    },
    teacherActivation: {
      total: teacherTotal,
      active: teacherActive,
      pending: teacherTotal - teacherActive,
      activationRate: teacherRate,
    },
    parentActivation: {
      total: parentTotal,
      active: parentActive,
      pending: parentTotal - parentActive,
      activationRate: parentRate,
    },
    otpDelivery: {
      sentLast7Days: otpSent,
      failedLast7Days: otpFailed,
      deliveryRate: otpRate,
    },
    pilotScore,
  };
}

export function computePilotScore(input: {
  setupWizardCompleted: boolean;
  importCommitted: boolean;
  teacherRate: number;
  parentRate: number;
  otpRate: number;
}): number {
  let score = 0;
  if (input.setupWizardCompleted) score += 25;
  if (input.importCommitted) score += 15;
  score += Math.round(input.teacherRate * 0.2);
  score += Math.round(input.parentRate * 0.2);
  score += Math.round(input.otpRate * 0.2);
  return Math.min(100, score);
}

export function pilotDashboardToApi(snapshot: PilotDashboardSnapshot) {
  return {
    onboardingStatus: snapshot.onboardingStatus,
    setupWizardCompleted: snapshot.setupWizardCompleted,
    importHealth: snapshot.importHealth,
    teacherActivation: snapshot.teacherActivation,
    parentActivation: snapshot.parentActivation,
    otpDelivery: snapshot.otpDelivery,
    pilotScore: snapshot.pilotScore,
  };
}
