import type {
  StudentDetailData,
  StudentDirectoryRow,
  StudentTransferRow,
} from "./sis_students_repository.ts";
import type { AdmissionsConversionResult } from "./sis_conversion_repository.ts";
import type { EnrollmentListRow } from "./sis_enrollments_repository.ts";
import type { SisDashboardSnapshot } from "./sis_dashboard_repository.ts";
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
    publicStudentId: row.public_student_id ?? "",
    academicYear: row.academic_year ?? "",
    className: row.class_name ?? "",
    sectionName: row.section_name ?? "",
    rollNumber: row.roll_number ?? "",
    // SIS-2: primary guardian contact for the richer registry export.
    guardianName: row.guardian_name ?? "",
    guardianPhone: row.guardian_phone ?? "",
    guardianCount: parseInt(row.guardian_count, 10) || 0,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// SIS-5: transfer / exit log row → API (backs the exportable exit register).
export function studentTransferItemToApi(row: StudentTransferRow): Record<string, unknown> {
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
    transitionedAt: row.transitioned_at,
    createdAt: row.created_at,
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
        publicStudentId: profile.public_student_id ?? "",
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
    academicYearId: row.academic_year_id,
    className: row.class_name,
    classId: row.class_id,
    sectionName: row.section_name ?? "",
    sectionId: row.section_id,
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

function formatCount(value: number): string {
  return value.toLocaleString("en-IN");
}

function formatEnrollmentDate(iso: string): string {
  if (!iso) return "";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return date.toISOString().slice(0, 10);
}

function buildDashboardAiInsight(data: SisDashboardSnapshot): string {
  if (data.pendingConversions > 0) {
    return `${data.pendingConversions} admissions enrollment${
      data.pendingConversions === 1 ? "" : "s"
    } awaiting SIS conversion. Complete registration before fee assignment.`;
  }
  if (data.inactiveStudents > 0) {
    return `${data.inactiveStudents} inactive student${
      data.inactiveStudents === 1 ? "" : "s"
    } on record. Review status before the next academic term.`;
  }
  return "Student information system is up to date for the current school scope.";
}

function buildDashboardKpis(data: SisDashboardSnapshot): Record<string, unknown>[] {
  return [
    {
      id: "total_students",
      value: formatCount(data.totalStudents),
      label: "Total Students",
      accentName: "primary",
    },
    {
      id: "recent_admissions",
      value: formatCount(data.recentAdmissions),
      label: "Recent Admissions (30d)",
      accentName: "success",
    },
    {
      id: "active_students",
      value: formatCount(data.activeStudents),
      label: "Active Students",
      accentName: "success",
    },
    {
      id: "pending_conversion",
      value: formatCount(data.pendingConversions),
      label: "Pending Conversion",
      accentName: "warning",
    },
    {
      id: "current_enrollments",
      value: formatCount(data.currentEnrollments),
      label: "Current Enrollments",
      accentName: "neutral",
    },
    {
      id: "classes",
      value: formatCount(data.distinctClasses),
      label: "Classes",
      accentName: "neutral",
    },
    {
      id: "sections",
      value: formatCount(data.distinctSections),
      label: "Sections",
      accentName: "neutral",
    },
  ];
}

export function dashboardToApi(data: SisDashboardSnapshot): Record<string, unknown> {
  return {
    totalStudents: data.totalStudents,
    activeStudents: data.activeStudents,
    inactiveStudents: data.inactiveStudents,
    graduatedStudents: data.graduatedStudents,
    transferredStudents: data.transferredStudents,
    currentEnrollments: data.currentEnrollments,
    recentAdmissions: data.recentAdmissions,
    recentConversions: data.recentConversions,
    pendingConversions: data.pendingConversions,
    distinctClasses: data.distinctClasses,
    distinctSections: data.distinctSections,
    kpis: buildDashboardKpis(data),
    classDistribution: data.classDistribution.map((row) => ({
      label: row.label,
      count: row.count,
      percent: row.percent,
    })),
    sectionDistribution: data.sectionDistribution.map((row) => ({
      label: row.label,
      count: row.count,
      percent: row.percent,
    })),
    genderDistribution: data.genderDistribution.map((row) => ({
      label: row.label,
      count: row.count,
      percent: row.percent,
    })),
    recentStudents: data.recentStudents.map((row) => ({
      id: row.id,
      studentName: row.student_name,
      admissionNumber: row.admission_number,
      classLabel: row.class_name,
      section: row.section_name,
      createdAt: row.created_at,
      status: row.status,
    })),
    recentEnrollments: data.recentEnrollments.map((row) => ({
      id: row.id,
      studentId: row.student_id,
      studentName: row.student_name,
      admissionNumber: row.admission_number,
      classLabel: row.class_name,
      section: row.section_name,
      enrolledAt: formatEnrollmentDate(row.enrolled_at),
      status: row.status,
    })),
    recentConversionItems: data.recentConversionsList.map((row) => ({
      id: row.id,
      studentName: row.student_name,
      admissionNumber: row.admission_number,
      classLabel: row.class_name,
      section: row.section_name,
      convertedAt: formatEnrollmentDate(row.converted_at),
    })),
    aiInsight: buildDashboardAiInsight(data),
  };
}
