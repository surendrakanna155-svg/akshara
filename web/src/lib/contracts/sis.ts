/**
 * Typed contract for the Student Information System (SIS) registry.
 * Mirrors lib/features/sis/sis_models.dart (registry student).
 */
export type SisStudentStatus = 'active' | 'prospect' | 'transferred' | 'exited' | 'alumni';
export type SisGender = 'male' | 'female' | 'other';

export interface SisStudent {
  id: string;
  studentName: string;
  admissionNumber: string;
  publicStudentId?: string;
  classLabel: string;
  section: string;
  academicYear: string;
  status: SisStudentStatus;
  gender: SisGender;
  dateOfBirth: string;
  guardianName: string;
  phone: string;
  email: string;
  enrolledAt: string;
}

/**
 * The live SIS router names registry fields differently from this contract
 * (`displayName`/`className`/`sectionName`/`guardianPhone`/`createdAt`). Map them
 * on the way in, keeping contract-shaped fields when a backend already sends them.
 * `gender`/`dateOfBirth`/`email` are not exposed by the endpoint — left blank so
 * the UI renders its honest placeholder rather than an invented value.
 */
export function normalizeSisStudent(raw: SisStudent): SisStudent {
  const src = raw as unknown as Record<string, unknown>;
  const pick = (...keys: string[]): string => {
    for (const k of keys) {
      const v = src[k];
      if (typeof v === 'string' && v !== '') return v;
    }
    return '';
  };
  return {
    ...raw,
    id: pick('id', 'studentId'),
    studentName: pick('studentName', 'displayName'),
    admissionNumber: pick('admissionNumber', 'studentCode'),
    publicStudentId: pick('publicStudentId') || undefined,
    classLabel: pick('classLabel', 'className'),
    section: pick('section', 'sectionName'),
    academicYear: pick('academicYear'),
    status: (pick('status') || 'active') as SisStudentStatus,
    guardianName: pick('guardianName'),
    phone: pick('phone', 'guardianPhone'),
    email: pick('email'),
    enrolledAt: pick('enrolledAt', 'createdAt'),
  };
}

/** Matches `listEnvelope(items, {page,pageSize,total,hasMore})` from sis_router.ts. */
export interface SisKpi {
  id: string;
  label: string;
  value: string;
  delta?: number;
}

export interface SisDashboardData {
  kpis: SisKpi[];
  classDistribution?: { label: string; value: number }[];
  genderDistribution?: { label: string; value: number }[];
}

export interface SisTransferRecord {
  studentId: string;
  studentName: string;
  admissionNumber: string;
  classLabel: string;
  section: string;
  academicYear: string;
  status: SisStudentStatus;
  exitedAt: string;
  reason?: string;
}

export interface SisConversionQueueItem {
  id: string;
  studentName: string;
  classLabel: string;
  guardianName: string;
  status: string;
}

export interface SisRegistryResponse {
  items: SisStudent[];
  total: number;
  page?: number;
  pageSize?: number;
  hasMore?: boolean;
}
