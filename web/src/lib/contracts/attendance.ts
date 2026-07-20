/** Attendance contracts — mirror lib/core/attendance/*. */
export type AttendanceCorrectionStatus = 'pending' | 'approved' | 'rejected';

export interface AttendanceCorrectionRequest {
  id: string;
  studentName: string;
  classLabel: string;
  section: string;
  dateLabel: string;
  fromMark: string;
  toMark: string;
  reason: string;
  requesterName: string;
  requesterRole: string;
  status: AttendanceCorrectionStatus;
  studentsAffected: number;
}

export interface AttendanceRegisterEntry {
  studentId: string;
  name: string;
  classLabel: string;
  mark: string;
  roll?: string;
}

export interface ShortAttendanceAlert {
  studentId: string;
  studentName: string;
  classLabel: string;
  /** Not exposed by /attendance/alerts/short-attendance — omitted when absent. */
  section?: string;
  percentPresent: number;
}

/** The live alerts endpoint sends the student as `name`; map it to the contract. */
export function normalizeShortAttendanceAlert(raw: ShortAttendanceAlert): ShortAttendanceAlert {
  const src = raw as unknown as Record<string, unknown>;
  const name = typeof raw.studentName === 'string' && raw.studentName !== '' ? raw.studentName : src.name;
  return { ...raw, studentName: typeof name === 'string' ? name : '' };
}
