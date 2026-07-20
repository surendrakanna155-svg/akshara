/**
 * Typed contract for the school overview dashboard. This is a CONTRACT ONLY —
 * it declares the shape the live endpoint returns; it holds no data. The page
 * fetches `/control-center/intelligence/dashboard` and renders against this.
 */
export interface DashboardKpis {
  students: number;
  studentsDelta: number;
  attendanceToday: number;
  attendanceDelta: number;
  feesCollected: number;
  feesDelta: number;
  pendingAdmissions: number;
  admissionsDelta: number;
}

export interface EnrollmentPoint {
  month: string;
  students: number;
  capacity: number;
}

export interface FeeCollectionPoint {
  month: string;
  collected: number;
  due: number;
}

export interface AttendanceSlice {
  name: string;
  value: number;
}

export interface ActivityItem {
  id: string;
  icon: string;
  title: string;
  detail: string;
  time: string;
  tone: 'info' | 'success' | 'warning';
}

export interface ApprovalItem {
  id: string;
  title: string;
  requester: string;
  amount?: string;
  type: string;
}

export interface DashboardData {
  kpis: DashboardKpis;
  enrollmentTrend: EnrollmentPoint[];
  feeCollection: FeeCollectionPoint[];
  attendanceByGrade: AttendanceSlice[];
  activity: ActivityItem[];
  approvals: ApprovalItem[];
}
