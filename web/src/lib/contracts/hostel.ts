/** Hostel contracts — mirror lib/features/hostel/hostel_models.dart. */
export type HostelRoomStatus = 'occupied' | 'vacant' | 'maintenance' | 'alert';
export type HostelRoomType = 'standard' | 'ac' | 'dormitory' | 'staff';
export type HostelStudentStatus = 'awaitingAllocation' | 'resident' | 'onLeave' | 'checkedOut';
export type HostelAttendanceStatus = 'present' | 'absent' | 'onLeave';
export type HostelLeaveStatus = 'pending' | 'approved' | 'rejected' | 'active';
export type HostelVisitorStatus = 'active' | 'checkedOut' | 'expired';
export type HostelMealType = 'breakfast' | 'lunch' | 'snacks' | 'dinner';

export interface HostelStudent {
  id: string;
  studentName: string;
  admissionNumber: string;
  classLabel: string;
  block: string;
  room: string;
  bed: string;
  status: HostelStudentStatus;
  feePending: string;
  parentAppLinked: boolean;
}

export interface HostelRoom {
  id: string;
  block: string;
  roomNumber: string;
  floor: number;
  type: HostelRoomType;
  totalBeds: number;
  occupiedBeds: number;
  status: HostelRoomStatus;
  facilities: string;
}

export interface HostelAttendanceRecord {
  id: string;
  studentName: string;
  room: string;
  rollNumber: string;
  morning: HostelAttendanceStatus;
  evening: HostelAttendanceStatus;
  night: HostelAttendanceStatus;
  overallStatus: HostelAttendanceStatus;
  remark: string;
  parentNotified: boolean;
}

export interface HostelLeaveRequest {
  id: string;
  studentName: string;
  room: string;
  fromDate: string;
  toDate: string;
  days: number;
  reason: string;
  parentContact: string;
  status: HostelLeaveStatus;
}

export interface HostelVisitor {
  id: string;
  visitorName: string;
  relation: string;
  studentName: string;
  checkIn: string;
  checkOut?: string;
  passId: string;
  status: HostelVisitorStatus;
}

export interface HostelMealMenu {
  day: string;
  mealType: HostelMealType;
  items: string;
  dietaryTags: string[];
}

export interface HostelMessData {
  weeklyMenus: HostelMealMenu[];
  costMtd: string;
}

export interface HostelKpi {
  id: string;
  label: string;
  value: string;
  delta?: number;
}

export interface HostelDashboardData {
  kpis: HostelKpi[];
}
