/** HR contracts — mirror lib/features/hr/hr_models.dart. Contract only. */
export type HrDepartment = 'academics' | 'administration' | 'transport' | 'finance' | 'hr' | 'support';
export type HrEmployeeRole = 'teacher' | 'driver' | 'admin' | 'principal' | 'staff';
export type HrEmployeeStatus = 'active' | 'onLeave' | 'probation' | 'inactive';

export type HrAttendanceStatus = 'present' | 'absent' | 'late' | 'onLeave' | 'halfDay';
export type HrLeaveType = 'casual' | 'sick' | 'earned' | 'maternity' | 'unpaid';
export type HrLeaveStatus = 'pending' | 'approved' | 'rejected' | 'cancelled';
export type HrPayrollStatus = 'draft' | 'processed' | 'paid' | 'onHold';
export type HrRecruitmentStage = 'applied' | 'screening' | 'interview' | 'selected' | 'joined';
export type HrReviewCycle = 'q1' | 'q2' | 'q3' | 'annual';

export interface HrAttendanceRecord {
  id: string;
  employeeId: string;
  employeeName: string;
  department: HrDepartment;
  date: string;
  checkIn: string;
  checkOut: string;
  status: HrAttendanceStatus;
  geoVerified: boolean;
  faceVerified: boolean;
}

export interface HrLeaveRequest {
  id: string;
  employeeId: string;
  employeeName: string;
  department: HrDepartment;
  leaveType: HrLeaveType;
  fromDate: string;
  toDate: string;
  days: number;
  status: HrLeaveStatus;
  approver: string;
  reason: string;
}

export interface HrPayrollEntry {
  id: string;
  employeeId: string;
  employeeName: string;
  department: HrDepartment;
  basicPay: string;
  allowances: string;
  deductions: string;
  netPay: string;
  status: HrPayrollStatus;
}

export interface HrCandidate {
  id: string;
  candidateName: string;
  position: string;
  stage: HrRecruitmentStage;
  appliedOn: string;
  source?: string;
}

export interface HrPerformanceReview {
  id: string;
  employeeName: string;
  department: HrDepartment;
  cycle: HrReviewCycle;
  rating: string;
  status: string;
  reviewer: string;
  dueDate: string;
}

export interface HrKpi {
  id: string;
  label: string;
  value: string;
  delta?: number;
}

export interface HrDashboardData {
  kpis: HrKpi[];
  headcountTrend: { month: string; count: number }[];
  attendanceTrend: { month: string; rate: number }[];
}

export interface HrEmployee {
  id: string;
  name: string;
  employeeCode: string;
  department: HrDepartment;
  role: HrEmployeeRole;
  designation: string;
  email: string;
  phone: string;
  joinDate: string;
  status: HrEmployeeStatus;
  teacherAppLinked?: boolean;
  classLabel?: string;
}
