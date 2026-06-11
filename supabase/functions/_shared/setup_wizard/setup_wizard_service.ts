export interface SetupWizardInputs {
  schoolName?: string;
  curriculum?: string;
  grades?: string[];
  sectionsPerGrade?: number;
  studentCount?: number;
  teacherCount?: number;
  feeModel?: string;
  subjects?: string[];
}

export interface SetupWizardRecommendation {
  academicYear: string;
  classes: string[];
  sections: string[];
  subjects: string[];
  feeStructures: string[];
  teacherStudentRatio: string;
  timetableSlots: number;
}

export interface SetupWizardResult {
  recommendations: SetupWizardRecommendation;
  warnings: string[];
  missingItems: string[];
}

export function buildSetupRecommendations(inputs: SetupWizardInputs): SetupWizardResult {
  const grades = inputs.grades?.length
    ? inputs.grades
    : ["Nursery", "LKG", "UKG", "Grade 1", "Grade 2"];
  const sections = grades.flatMap((g) =>
    Array.from({ length: inputs.sectionsPerGrade ?? 2 }, (_, i) => `${g} — Section ${String.fromCharCode(65 + i)}`)
  );
  const studentCount = inputs.studentCount ?? 200;
  const teacherCount = inputs.teacherCount ?? 12;
  const ratio = teacherCount > 0
    ? `1:${Math.round(studentCount / teacherCount)}`
    : "1:20 (recommended)";

  const warnings: string[] = [];
  if (studentCount / Math.max(teacherCount, 1) > 25) {
    warnings.push("Teacher-student ratio exceeds 1:25 — consider hiring more teachers");
  }
  if (!inputs.feeModel) {
    warnings.push("Fee model not specified — default term-wise structure recommended");
  }
  if ((inputs.subjects?.length ?? 0) < 3) {
    warnings.push("Add core subjects (English, Mathematics, Science) before go-live");
  }

  const missingItems: string[] = [];
  if (!inputs.curriculum) missingItems.push("Curriculum selection");
  if (!inputs.feeModel) missingItems.push("Fee structure configuration");
  missingItems.push("Teacher CSV import", "Student CSV import", "Timetable publication");

  return {
    recommendations: {
      academicYear: "2026-27",
      classes: grades,
      sections,
      subjects: inputs.subjects?.length
        ? inputs.subjects
        : ["English", "Mathematics", "Science", "Social Studies", "Hindi"],
      feeStructures: inputs.feeModel
        ? [inputs.feeModel, "Transport fee", "Activity fee"]
        : ["Term 1 tuition", "Term 2 tuition", "Annual activity fee"],
      teacherStudentRatio: ratio,
      timetableSlots: grades.length * 6,
    },
    warnings,
    missingItems,
  };
}
