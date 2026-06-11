import type { TenantQueryClient } from "../tenant_db.ts";
import { createAcademicYear } from "../academic/academic_years_repository.ts";
import { createClass } from "../academic/classes_repository.ts";
import { createSection } from "../academic/sections_repository.ts";
import { createFeeStructure } from "../finance/finance_structures_repository.ts";
import { encodeFeeHead } from "../finance/finance_mapper.ts";
import { createSubject } from "../school_completion/subjects_repository.ts";
import { generateSyllabusFromTemplates } from "../school_completion/syllabus_automation_service.ts";
import { buildSetupRecommendations, type SetupWizardInputs } from "./setup_wizard_service.ts";

export interface ProvisionResult {
  academicYearId?: string;
  classIds: string[];
  sectionIds: string[];
  feeStructureIds: string[];
  subjectIds: string[];
  syllabusTopicsCreated: number;
  warnings: string[];
  provisioned: boolean;
}

export async function provisionSchoolFromWizard(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  inputs: SetupWizardInputs,
): Promise<ProvisionResult> {
  const built = buildSetupRecommendations(inputs);
  const warnings = [...built.warnings];
  const classIds: string[] = [];
  const sectionIds: string[] = [];
  const feeStructureIds: string[] = [];
  const subjectIds: string[] = [];
  let syllabusTopicsCreated = 0;

  const yearLabel = built.recommendations.academicYear;
  const startYear = new Date().getFullYear();
  const year = await createAcademicYear(db, organizationId, schoolId, {
    yearLabel,
    startDate: `${startYear}-04-01`,
    endDate: `${startYear + 1}-03-31`,
    isCurrent: true,
    createdBy: userId,
  });

  for (const [idx, grade] of built.recommendations.classes.entries()) {
    const cls = await createClass(db, organizationId, schoolId, {
      academicYearId: year.id,
      className: grade,
      displayOrder: idx,
      createdBy: userId,
    });
    classIds.push(cls.id);

    const sectionsForGrade = built.recommendations.sections.filter((s) => s.startsWith(grade));
    for (const sectionLabel of sectionsForGrade) {
      const sectionName = sectionLabel.split(" — ")[1]?.trim() ?? "A";
      const capacity = 40;
      const sec = await createSection(db, organizationId, schoolId, {
        classId: cls.id,
        sectionName,
        capacity,
        createdBy: userId,
      });
      sectionIds.push(sec.id);
      if (capacity > 35) {
        warnings.push(`Large class size configured for ${grade} ${sectionName} (capacity ${capacity})`);
      }
    }
  }

  const teacherCount = inputs.teacherCount ?? 12;
  if (classIds.length > teacherCount) {
    warnings.push(
      `Teacher shortage: ${classIds.length} classes provisioned but only ${teacherCount} teachers reported`,
    );
  }

  if (built.recommendations.subjects.length < 3) {
    warnings.push("Missing core subjects — add English, Mathematics, and Science before go-live");
  }

  const defaultSubjects = built.recommendations.subjects.length
    ? built.recommendations.subjects
    : ["English", "Mathematics", "Science"];
  for (const [idx, name] of defaultSubjects.entries()) {
    const code = name.slice(0, 3).toUpperCase().padEnd(3, "X");
    try {
      const subject = await createSubject(db, organizationId, schoolId, {
        subjectCode: `${code}${idx}`,
        subjectName: name,
        category: "core",
        gradeLabels: built.recommendations.classes,
        createdBy: userId,
      });
      subjectIds.push(subject.id);

      try {
        const gradeLabel = built.recommendations.classes[0] ?? "Grade 1";
        const syllabus = await generateSyllabusFromTemplates(db, organizationId, schoolId, {
          academicYearId: year.id,
          className: gradeLabel,
          subjectId: subject.id,
          subjectName: name,
          gradeLabel,
          source: "wizard",
          createdBy: userId,
        });
        syllabusTopicsCreated += syllabus.topicsCreated;
      } catch {
        warnings.push(`Syllabus auto-generation skipped for ${name}`);
      }
    } catch {
      warnings.push(`Subject ${name} may already exist — skipped duplicate`);
    }
  }

  for (const [idx, feeName] of built.recommendations.feeStructures.slice(0, 2).entries()) {
    const fee = await createFeeStructure(db, organizationId, schoolId, {
      name: feeName,
      academicYear: yearLabel,
      academicYearId: year.id,
      description: "Auto-provisioned by setup wizard",
      status: "draft",
      createdBy: userId,
      items: [{
        feeHead: encodeFeeHead("tuition", feeName),
        amount: 0,
        sortOrder: idx,
      }],
    });
    feeStructureIds.push(fee.structure.id);
  }

  if (built.recommendations.timetableSlots > 0) {
    warnings.push(
      `Timetable defaults: ${built.recommendations.timetableSlots} slots recommended — publish timetable before go-live`,
    );
  }

  return {
    academicYearId: year.id,
    classIds,
    sectionIds,
    feeStructureIds,
    subjectIds,
    syllabusTopicsCreated,
    warnings,
    provisioned: true,
  };
}
