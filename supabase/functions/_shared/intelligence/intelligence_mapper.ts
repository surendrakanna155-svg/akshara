import type { StudentRiskSnapshotRow } from "./intelligence_types.ts";
import type { ClassRiskSummary } from "./student_risk_repository.ts";
import type { TeacherSuccessCenter } from "./teacher_success_service.ts";
import type { PrincipalIntelligenceCenter } from "./principal_intelligence_service.ts";
import type { MultilingualDraft } from "./communication_generator.ts";
import type { ParentGuidanceReport } from "./parent_guidance_generator.ts";

export function riskSnapshotToApi(row: StudentRiskSnapshotRow) {
  const inputs = row.inputs as { student_name?: string } | null;
  return {
    id: row.id,
    studentId: row.student_id,
    studentName: inputs?.student_name ?? null,
    academicYearLabel: row.academic_year_label,
    className: row.class_name,
    sectionName: row.section_name,
    riskScore: row.risk_score,
    riskLevel: row.risk_level,
    reasons: row.reasons,
    interventions: row.interventions,
    teacherActions: row.teacher_actions,
    parentNotifications: row.parent_notifications,
    inputs: row.inputs,
    computedAt: row.computed_at,
  };
}

export function classRiskToApi(summary: ClassRiskSummary) {
  return {
    className: summary.className,
    studentCount: summary.studentCount,
    averageRiskScore: summary.averageRiskScore,
    criticalCount: summary.criticalCount,
    highCount: summary.highCount,
    mediumCount: summary.mediumCount,
    lowCount: summary.lowCount,
  };
}

export function communicationDraftToApi(drafts: MultilingualDraft[]) {
  return { drafts, voiceNoteArchitecture: "transcription_stub_v1" };
}

export function parentGuidanceToApi(
  report: ParentGuidanceReport,
  meta: { id?: string; mode: string; language: string; studentId: string; status?: string },
) {
  return { ...meta, report, printable: true, status: meta.status ?? "draft" };
}

export function teacherSuccessToApi(center: TeacherSuccessCenter) {
  return center;
}

export function principalCenterToApi(center: PrincipalIntelligenceCenter) {
  return center;
}
