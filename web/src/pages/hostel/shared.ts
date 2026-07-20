import type { SemanticStatus } from '@/components/ui';
import type {
  HostelAttendanceStatus,
  HostelLeaveStatus,
  HostelRoomStatus,
  HostelStudentStatus,
  HostelVisitorStatus,
} from '@/lib/contracts/hostel';
import { MODULE_TABS } from '@/routes/navConfig';

export const HOSTEL_TABS = MODULE_TABS.hostel;

export const RESIDENT_STATUS: Record<HostelStudentStatus, { status: SemanticStatus; label: string }> = {
  awaitingAllocation: { status: 'warning', label: 'Awaiting room' },
  resident: { status: 'success', label: 'Resident' },
  onLeave: { status: 'info', label: 'On leave' },
  checkedOut: { status: 'neutral', label: 'Checked out' },
};

export const ROOM_STATUS: Record<HostelRoomStatus, { status: SemanticStatus; label: string }> = {
  occupied: { status: 'info', label: 'Occupied' },
  vacant: { status: 'success', label: 'Vacant' },
  maintenance: { status: 'warning', label: 'Maintenance' },
  alert: { status: 'error', label: 'Alert' },
};

export const HOSTEL_ATTENDANCE: Record<HostelAttendanceStatus, { status: SemanticStatus; label: string }> = {
  present: { status: 'success', label: 'Present' },
  absent: { status: 'error', label: 'Absent' },
  onLeave: { status: 'info', label: 'On leave' },
};

export const HOSTEL_LEAVE: Record<HostelLeaveStatus, { status: SemanticStatus; label: string }> = {
  pending: { status: 'warning', label: 'Pending' },
  approved: { status: 'success', label: 'Approved' },
  rejected: { status: 'error', label: 'Rejected' },
  active: { status: 'info', label: 'Active' },
};

export const VISITOR_STATUS: Record<HostelVisitorStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Inside' },
  checkedOut: { status: 'neutral', label: 'Checked out' },
  expired: { status: 'warning', label: 'Expired' },
};
