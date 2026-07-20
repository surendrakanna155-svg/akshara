/** Admissions contracts — mirror lib/features/admissions/admissions_models.dart. */
export type LeadStage =
  | 'newEnquiry'
  | 'contacted'
  | 'schoolVisit'
  | 'application'
  | 'admitted'
  | 'enrolled'
  | 'lost';
export type LeadScore = 'hot' | 'warm' | 'cold';
export type LeadSource = string;

export interface AdmissionsLead {
  id: string;
  parentName: string;
  studentName: string;
  classLabel: string;
  phone: string;
  source: LeadSource;
  campaign: string;
  stage: LeadStage;
  counselor: string;
  score: LeadScore;
  nextFollowUpLabel: string;
}

export type ApplicationStatus = 'draft' | 'submitted' | 'documentsPending' | 'underReview' | 'approved' | 'rejected';

export interface AdmissionsApplication {
  id: string;
  studentName: string;
  classLabel: string;
  parentName: string;
  submittedLabel: string;
  status: ApplicationStatus;
  documentsComplete: number;
  documentsTotal: number;
  counselor: string;
}

export type DocumentVerificationStatus = 'missing' | 'uploaded' | 'verified' | 'rejected';

export interface AdmissionsDocumentRow {
  id: string;
  studentName: string;
  classLabel: string;
  docType: string;
  status: DocumentVerificationStatus;
}

export interface AdmissionsEnrollmentPending {
  id: string;
  studentName: string;
  classLabel: string;
  guardianName: string;
  phone: string;
  status: string;
}

export interface AdmissionsApprovalItem {
  id: string;
  studentName: string;
  classLabel: string;
  parentName: string;
  submittedLabel: string;
  status: ApplicationStatus;
  counselor: string;
}

export interface AdmissionsDashboard {
  totalLeads: number;
  hotLeads: number;
  conversionRate: number;
  pendingFollowUps: number;
  /** Not derivable from the live dashboard response — rendered as "—" when absent. */
  unassignedLeads?: number;
  stageCounts: Record<string, number>;
  topSource?: string;
  topSourceCount: number;
}

/**
 * GET /admissions/dashboard answers the shape built by
 * supabase/functions/_shared/admissions/admissions_dashboard_mapper.ts: a `kpis`
 * list keyed by id, a `pipeline` per stage, `sourceSegments` and `followUps` —
 * not this contract's flat counters. Project the real values onto it.
 */
export function normalizeAdmissionsDashboard(raw: Record<string, unknown>): AdmissionsDashboard {
  const kpis = (Array.isArray(raw.kpis) ? raw.kpis : []) as { id?: string; value?: string }[];
  const kpi = (id: string): number => {
    const v = kpis.find((k) => k.id === id)?.value;
    // `conversion` arrives pre-formatted as "42%".
    const n = Number.parseFloat(String(v ?? '').replace('%', ''));
    return Number.isFinite(n) ? n : 0;
  };
  const pipeline = (Array.isArray(raw.pipeline) ? raw.pipeline : []) as { stage?: string; count?: number }[];
  const sources = (Array.isArray(raw.sourceSegments) ? raw.sourceSegments : []) as { label?: string; value?: number }[];
  const top = [...sources].sort((a, b) => (b.value ?? 0) - (a.value ?? 0))[0];

  return {
    totalLeads: kpi('total_leads'),
    hotLeads: kpi('hot_leads'),
    conversionRate: kpi('conversion'),
    pendingFollowUps: Array.isArray(raw.followUps) ? raw.followUps.length : 0,
    unassignedLeads: undefined,
    stageCounts: Object.fromEntries(pipeline.map((p) => [String(p.stage), p.count ?? 0])),
    topSource: top?.label,
    topSourceCount: top?.value ?? 0,
  };
}
