import type { SemanticStatus } from '@/components/ui';
import type { HrAttendanceStatus, HrLeaveStatus, HrPayrollStatus, HrRecruitmentStage } from '@/lib/contracts/hr';
import { MODULE_TABS } from '@/routes/navConfig';

export const HR_TABS = MODULE_TABS.hr;

export const HR_ATTENDANCE_STATUS: Record<HrAttendanceStatus, { status: SemanticStatus; label: string }> = {
  present: { status: 'success', label: 'Present' },
  absent: { status: 'error', label: 'Absent' },
  late: { status: 'warning', label: 'Late' },
  onLeave: { status: 'info', label: 'On leave' },
  halfDay: { status: 'pending', label: 'Half day' },
};

export const HR_LEAVE_STATUS: Record<HrLeaveStatus, { status: SemanticStatus; label: string }> = {
  pending: { status: 'warning', label: 'Pending' },
  approved: { status: 'success', label: 'Approved' },
  rejected: { status: 'error', label: 'Rejected' },
  cancelled: { status: 'neutral', label: 'Cancelled' },
};

export const HR_PAYROLL_STATUS: Record<HrPayrollStatus, { status: SemanticStatus; label: string }> = {
  draft: { status: 'neutral', label: 'Draft' },
  processed: { status: 'info', label: 'Processed' },
  paid: { status: 'success', label: 'Paid' },
  onHold: { status: 'warning', label: 'On hold' },
};

export const HR_STAGE: Record<HrRecruitmentStage, { status: SemanticStatus; label: string }> = {
  applied: { status: 'neutral', label: 'Applied' },
  screening: { status: 'info', label: 'Screening' },
  interview: { status: 'pending', label: 'Interview' },
  selected: { status: 'success', label: 'Selected' },
  joined: { status: 'success', label: 'Joined' },
};

export const HR_DEPARTMENTS = ['academics', 'administration', 'transport', 'finance', 'hr', 'support'];
