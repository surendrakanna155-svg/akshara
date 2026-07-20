/** Finance contracts — mirror lib/features/finance/finance_models.dart. Money
 * fields are pre-formatted strings from the backend. Contract only. */
export type FeeAccountStatus = 'active' | 'overdue' | 'closed' | 'pending';
export type CollectionStatus = 'completed' | 'pending' | 'failed' | 'refunded';
export type DefaulterAgingBucket = 'current' | 'days1to30' | 'days31to60' | 'days61to90' | 'over90';
export type RefundStatus = 'pending' | 'approved' | 'rejected' | 'processed';
export type DiscountApprovalStatus = 'pending' | 'approved' | 'rejected' | 'active';
export type FeeStructureStatus = 'active' | 'inactive';
export type FeeStructureCategory = 'tuition' | 'transport' | 'hostel' | 'activity';

export interface FinanceKpi {
  id: string;
  label: string;
  value: string;
  delta?: number;
}

export interface CollectionTrendPoint {
  label: string;
  collected: number;
}

/**
 * Mirrors `FinanceDashboardSnapshot` in
 * supabase/functions/_shared/finance/finance_dashboard_repository.ts — the
 * authoritative shape of GET /finance/dashboard. The snapshot is a flat set of
 * live totals: it carries no pre-built KPI list, no collection trend series and
 * no defaulters count, so the page derives its KPIs from these real values and
 * renders an honest "not provided" state for the trend (gap WEB-006).
 */
export interface FinanceDashboardData {
  totalStudents: number;
  activeFeeAssignments: number;
  totalInvoiced: number;
  totalCollected: number;
  totalOutstanding: number;
  collectionRate: number;
  pendingInvoices: number;
  partiallyPaidInvoices: number;
  paidInvoices: number;
  pendingRefunds: number;
  processedRefunds: number;
  todayCollections: number;
  todayCollectionCount: number;
  recentCollections: DashboardRecentCollection[];
  recentRefunds: DashboardRecentRefund[];
  /** Not sent by the live snapshot; honoured if a backend starts providing them. */
  collectionTrend?: CollectionTrendPoint[];
  aiInsight?: string;
}

export interface DashboardRecentCollection {
  id: string;
  receiptNumber: string;
  studentName: string;
  amount: number;
  paymentMethod: string;
  collectionDate: string;
}

export interface DashboardRecentRefund {
  id: string;
  studentName: string;
  amount: number;
  status: string;
  requestedDate?: string;
}

export interface CollectionPayment {
  id: string;
  receiptNumber: string;
  studentName: string;
  admissionNumber: string;
  amount: string;
  mode: string;
  collectedAt: string;
  collectedBy: string;
  status: CollectionStatus;
  classLabel: string;
}

export interface StudentFeeAccount {
  id: string;
  studentName: string;
  admissionNumber: string;
  classLabel: string;
  feeStructureName: string;
  totalDue: string;
  totalPaid: string;
  balance: string;
  status: FeeAccountStatus;
  lastPaymentDate: string;
  installmentPlan: string;
}

export interface FeeCategoryLine {
  category: FeeStructureCategory;
  label: string;
  amount: string;
}

export interface FinanceFeeStructure {
  id: string;
  name: string;
  academicYear: string;
  totalAnnual: string;
  categories: FeeCategoryLine[];
  status: FeeStructureStatus;
  installmentOptions: number[];
  classRange: string;
}

export interface DefaulterRecord {
  id: string;
  studentName: string;
  admissionNumber: string;
  classLabel: string;
  overdueAmount: string;
  daysOverdue: number;
  bucket: DefaulterAgingBucket;
  lastContact: string;
  collectionProbability: number;
  guardianPhone: string;
}

export interface RefundRequest {
  id: string;
  studentName: string;
  admissionNumber: string;
  classLabel: string;
  amount: string;
  reason: string;
  requestedAt: string;
  status: RefundStatus;
  approver: string;
  originalReceipt: string;
}

export interface StudentDiscountAssignment {
  id: string;
  studentName: string;
  admissionNumber: string;
  scholarshipName: string;
  discountAmount: string;
  status: DiscountApprovalStatus;
  impactOnFees: string;
}
