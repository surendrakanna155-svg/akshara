import type { StudentDetailData, StudentDirectoryRow } from "./sis_students_repository.ts";
import type { AdmissionsConversionResult } from "./sis_conversion_repository.ts";
import type { EnrollmentListRow } from "./sis_enrollments_repository.ts";
import { statusFromDb } from "./sis_status_codec.ts";

export function listEnvelope(
  items: Record<string, unknown>[],
  pagination: {
    page: number;
    pageSize: number;
    total: number;
    hasMore: boolean;
  },
): Record<string, unknown> {
  return {
    items,
    pagination: {
      page: pagination.page,
      pageSize: pagination.pageSize,
      total: pagination.total,
      hasMore: pagination.hasMore,
    },
  };
}

export function studentDirectoryItemToApi(row: StudentDirectoryRow): Record<string, unknown> {
  return {
    studentId: row.student_id,
    studentCode: row.student_code,
    displayName: row.display_name,
    status: statusFromDb(row.status),
    admissionNumber: row.admission_number ?? "",
    academicYear: row.academic_year ?? "",
    className: row.class_name ?? "",
    sectionName: row.section_name ?? "",
    rollNumber: row.roll_number ?? "",
    guardianCount: parseInt(row.guardian_count, 10) || 0,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function studentDetailToApi(data: StudentDetailData): Record<string, unknown> {
  const { student, profile, currentEnrollment, guardians } = data;
  return {
    student: {
      id: student.id,
      studentCode: student.student_code,
      displayName: student.display_name,
      status: statusFromDb(student.status),
      createdAt: student.created_at,
      updatedAt: student.updated_at,
    },
    profile: profile
      ? {
        id: profile.id,
        admissionNumber: profile.admission_number,
        dateOfBirth: profile.date_of_birth,
        gender: profile.gender,
        bloodGroup: profile.blood_group,
        address: profile.address,
        city: profile.city,
        state: profile.state,
        postalCode: profile.postal_code,
        country: profile.country,
        createdAt: profile.created_at,
        updatedAt: profile.updated_at,
      }
      : null,
    currentEnrollment: currentEnrollment
      ? {
        id: currentEnrollment.id,
        academicYear: currentEnrollment.academic_year,
        className: currentEnrollment.class_name,
        sectionName: currentEnrollment.section_name,
        rollNumber: currentEnrollment.roll_number,
        isCurrent: currentEnrollment.is_current,
        createdAt: currentEnrollment.created_at,
        updatedAt: currentEnrollment.updated_at,
      }
      : null,
    guardians: guardians.map((guardian) => ({
      id: guardian.id,
      guardianUserId: guardian.guardian_user_id,
      relationship: guardian.relationship,
      isPrimary: guardian.is_primary,
      status: guardian.status,
      displayName: guardian.display_name ?? "",
      phone: guardian.phone ?? "",
      email: guardian.email ?? "",
    })),
  };
}

export function enrollmentListItemToApi(row: EnrollmentListRow): Record<string, unknown> {
  return {
    enrollmentId: row.enrollment_id,
    studentId: row.student_id,
    studentCode: row.student_code,
    studentName: row.student_name,
    academicYear: row.academic_year,
    className: row.class_name,
    sectionName: row.section_name ?? "",
    rollNumber: row.roll_number ?? "",
    isCurrent: row.is_current,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function admissionsConversionToApi(
  result: AdmissionsConversionResult,
): Record<string, unknown> {
  return {
    admissionsEnrollmentId: result.admissionsEnrollmentId,
    studentId: result.studentId,
    profileId: result.profileId,
    sisEnrollmentId: result.sisEnrollmentId,
    admissionNumber: result.admissionNumber,
    studentName: result.studentName,
    className: result.className,
    classLabel: result.className,
    sectionName: result.sectionName ?? "",
    section: result.sectionName ?? "",
    rollNumber: result.rollNumber ?? "",
    academicYear: result.academicYear,
    conversionStatus: result.conversionStatus,
    idempotent: result.idempotent,
  };
}
