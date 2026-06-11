import type { TenantQueryClient } from "../tenant_db.ts";
import { resolveAcademicPlacement } from "./academic_catalog_resolver.ts";
import { getAcademicYear } from "./academic_years_repository.ts";
import { listClasses } from "./classes_repository.ts";

export interface ClassMappingRule {
  sourceClassName: string;
  targetClassName: string;
  keepSection?: boolean;
  action?: "promote" | "graduate" | "repeat" | "skip";
}

export interface TransitionPreviewRow {
  studentId: string;
  studentName: string;
  enrollmentId: string;
  sourceClassName: string;
  sourceSectionName: string | null;
  targetClassName: string | null;
  targetSectionName: string | null;
  status: "promote" | "graduate" | "skip" | "invalid";
  errors: string[];
}

export interface AcademicYearTransitionRow {
  id: string;
  organization_id: string;
  school_id: string;
  source_year_id: string;
  target_year_id: string;
  status: string;
  class_mapping: ClassMappingRule[];
  preview_report: Record<string, unknown>;
  execution_report: Record<string, unknown>;
  promoted_count: number;
  skipped_count: number;
  failed_count: number;
  set_target_current: boolean;
  archive_source_year: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  executed_at: string | null;
}

export class AcademicTransitionValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "AcademicTransitionValidationError";
  }
}

export class AcademicTransitionNotFoundError extends Error {
  constructor(id: string) {
    super(`Academic year transition not found: ${id}`);
    this.name = "AcademicTransitionNotFoundError";
  }
}

interface EnrollmentSourceRow {
  id: string;
  student_id: string;
  display_name: string;
  class_name: string;
  section_name: string | null;
  roll_number: string | null;
}

function mappingForClass(
  mappings: ClassMappingRule[],
  sourceClassName: string,
): ClassMappingRule {
  const explicit = mappings.find((m) =>
    m.sourceClassName.trim().toLowerCase() === sourceClassName.trim().toLowerCase()
  );
  if (explicit) return explicit;

  const numeric = parseInt(sourceClassName, 10);
  if (!Number.isNaN(numeric)) {
    return {
      sourceClassName,
      targetClassName: String(numeric + 1),
      keepSection: true,
      action: "promote",
    };
  }

  return {
    sourceClassName,
    targetClassName: sourceClassName,
    keepSection: true,
    action: "repeat",
  };
}

export async function suggestClassMappings(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sourceYearId: string,
  targetYearId: string,
): Promise<ClassMappingRule[]> {
  const sourceClasses = await listClasses(db, organizationId, schoolId, sourceYearId);
  const targetNames = new Set(
    (await listClasses(db, organizationId, schoolId, targetYearId))
      .map((c) => c.class_name.toLowerCase()),
  );

  return sourceClasses.map((c) => {
    const numeric = parseInt(c.class_name, 10);
    let targetClassName = c.class_name;
    let action: ClassMappingRule["action"] = "repeat";

    if (!Number.isNaN(numeric)) {
      const promoted = String(numeric + 1);
      if (targetNames.has(promoted.toLowerCase())) {
        targetClassName = promoted;
        action = "promote";
      } else if (numeric >= 10) {
        action = "graduate";
        targetClassName = "";
      }
    }

    return {
      sourceClassName: c.class_name,
      targetClassName,
      keepSection: true,
      action,
    };
  });
}

async function listSourceEnrollments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sourceYearId: string,
  sourceYearLabel: string,
): Promise<EnrollmentSourceRow[]> {
  return await db.queryObject<EnrollmentSourceRow>(
    `SELECT e.id, e.student_id, s.display_name, e.class_name, e.section_name, e.roll_number
     FROM sis_student_enrollments e
     INNER JOIN students s ON s.id = e.student_id
     WHERE e.organization_id = $1 AND e.school_id = $2
       AND e.is_current = true
       AND (e.academic_year_id = $3 OR e.academic_year = $4)
     ORDER BY e.class_name, e.section_name, s.display_name`,
    [organizationId, schoolId, sourceYearId, sourceYearLabel],
  );
}

export async function buildTransitionPreview(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sourceYearId: string,
  targetYearId: string,
  classMappings: ClassMappingRule[],
): Promise<{ rows: TransitionPreviewRow[]; suggestedMappings: ClassMappingRule[] }> {
  const sourceYear = await getAcademicYear(db, organizationId, schoolId, sourceYearId);
  const targetYear = await getAcademicYear(db, organizationId, schoolId, targetYearId);
  if (!sourceYear || !targetYear) {
    throw new AcademicTransitionValidationError("Source or target academic year not found");
  }
  if (sourceYear.id === targetYear.id) {
    throw new AcademicTransitionValidationError("Source and target year must differ");
  }

  const mappings = classMappings.length
    ? classMappings
    : await suggestClassMappings(db, organizationId, schoolId, sourceYearId, targetYearId);

  const enrollments = await listSourceEnrollments(
    db,
    organizationId,
    schoolId,
    sourceYearId,
    sourceYear.year_label,
  );

  const rows: TransitionPreviewRow[] = [];
  for (const enrollment of enrollments) {
    const rule = mappingForClass(mappings, enrollment.class_name);
    const action = rule.action ?? "promote";
    const errors: string[] = [];

    if (action === "skip") {
      rows.push({
        studentId: enrollment.student_id,
        studentName: enrollment.display_name,
        enrollmentId: enrollment.id,
        sourceClassName: enrollment.class_name,
        sourceSectionName: enrollment.section_name,
        targetClassName: null,
        targetSectionName: null,
        status: "skip",
        errors,
      });
      continue;
    }

    if (action === "graduate") {
      rows.push({
        studentId: enrollment.student_id,
        studentName: enrollment.display_name,
        enrollmentId: enrollment.id,
        sourceClassName: enrollment.class_name,
        sourceSectionName: enrollment.section_name,
        targetClassName: null,
        targetSectionName: null,
        status: "graduate",
        errors,
      });
      continue;
    }

    const targetClassName = rule.targetClassName?.trim() ?? "";
    if (!targetClassName) {
      errors.push("targetClassName is required for promote action");
      rows.push({
        studentId: enrollment.student_id,
        studentName: enrollment.display_name,
        enrollmentId: enrollment.id,
        sourceClassName: enrollment.class_name,
        sourceSectionName: enrollment.section_name,
        targetClassName: null,
        targetSectionName: null,
        status: "invalid",
        errors,
      });
      continue;
    }

    const targetSectionName = rule.keepSection !== false
      ? (enrollment.section_name ?? "")
      : "";

    try {
      await resolveAcademicPlacement(
        { db, organizationId, schoolId },
        {
          academicYear: targetYear.year_label,
          className: targetClassName,
          sectionName: targetSectionName || undefined,
        },
        { mode: "full" },
      );
      rows.push({
        studentId: enrollment.student_id,
        studentName: enrollment.display_name,
        enrollmentId: enrollment.id,
        sourceClassName: enrollment.class_name,
        sourceSectionName: enrollment.section_name,
        targetClassName,
        targetSectionName: targetSectionName || null,
        status: "promote",
        errors,
      });
    } catch (error) {
      errors.push(error instanceof Error ? error.message : "Target placement invalid");
      rows.push({
        studentId: enrollment.student_id,
        studentName: enrollment.display_name,
        enrollmentId: enrollment.id,
        sourceClassName: enrollment.class_name,
        sourceSectionName: enrollment.section_name,
        targetClassName,
        targetSectionName: targetSectionName || null,
        status: "invalid",
        errors,
      });
    }
  }

  return { rows, suggestedMappings: mappings };
}

export async function createTransitionPreviewJob(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  createdBy: string,
  input: {
    sourceYearId: string;
    targetYearId: string;
    classMappings?: ClassMappingRule[];
    setTargetCurrent?: boolean;
    archiveSourceYear?: boolean;
  },
): Promise<{ job: AcademicYearTransitionRow; preview: TransitionPreviewRow[] }> {
  const { rows, suggestedMappings } = await buildTransitionPreview(
    db,
    organizationId,
    schoolId,
    input.sourceYearId,
    input.targetYearId,
    input.classMappings ?? [],
  );

  const promote = rows.filter((r) => r.status === "promote").length;
  const graduate = rows.filter((r) => r.status === "graduate").length;
  const skip = rows.filter((r) => r.status === "skip").length;
  const invalid = rows.filter((r) => r.status === "invalid").length;

  const jobRows = await db.queryObject<AcademicYearTransitionRow>(
    `INSERT INTO academic_year_transitions (
       organization_id, school_id, source_year_id, target_year_id, status,
       class_mapping, preview_report, set_target_current, archive_source_year, created_by
     ) VALUES ($1, $2, $3, $4, 'previewed', $5::jsonb, $6::jsonb, $7, $8, $9)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.sourceYearId,
      input.targetYearId,
      JSON.stringify(input.classMappings?.length ? input.classMappings : suggestedMappings),
      JSON.stringify({ rows, summary: { promote, graduate, skip, invalid, total: rows.length } }),
      input.setTargetCurrent ?? true,
      input.archiveSourceYear ?? true,
      createdBy,
    ],
  );

  return { job: jobRows[0]!, preview: rows };
}

export async function executeTransitionJob(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  transitionId: string,
  executedBy: string,
): Promise<AcademicYearTransitionRow> {
  const jobRows = await db.queryObject<AcademicYearTransitionRow>(
    `SELECT * FROM academic_year_transitions
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [transitionId, organizationId, schoolId],
  );
  const job = jobRows[0];
  if (!job) throw new AcademicTransitionNotFoundError(transitionId);
  if (job.status === "completed") return job;
  if (job.status !== "previewed") {
    throw new AcademicTransitionValidationError(`Transition status ${job.status} cannot be executed`);
  }

  const preview = job.preview_report as { rows?: TransitionPreviewRow[] };
  const rows = preview.rows ?? [];
  const invalid = rows.filter((r) => r.status === "invalid");
  if (invalid.length > 0) {
    throw new AcademicTransitionValidationError(
      `${invalid.length} invalid preview rows — fix mappings before execute`,
    );
  }

  const targetYear = await getAcademicYear(db, organizationId, schoolId, job.target_year_id);
  const sourceYear = await getAcademicYear(db, organizationId, schoolId, job.source_year_id);
  if (!targetYear || !sourceYear) {
    throw new AcademicTransitionValidationError("Academic year not found");
  }

  await db.queryObject(
    `UPDATE academic_year_transitions SET status = 'executing' WHERE id = $1`,
    [transitionId],
  );

  let promoted = 0;
  let skipped = 0;
  let failed = 0;
  const failures: Array<{ studentId: string; error: string }> = [];

  for (const row of rows) {
    if (row.status === "skip" || row.status === "graduate") {
      await db.queryObject(
        `UPDATE sis_student_enrollments SET is_current = false, updated_at = timezone('utc', now())
         WHERE id = $1`,
        [row.enrollmentId],
      );
      if (row.status === "graduate") {
        await db.queryObject(
          `UPDATE students SET status = 'alumni', updated_at = timezone('utc', now())
           WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
          [row.studentId, organizationId, schoolId],
        );
      }
      skipped++;
      continue;
    }

    if (row.status !== "promote" || !row.targetClassName) {
      skipped++;
      continue;
    }

    try {
      await db.queryObject(`SAVEPOINT academic_transition_row`);
      const placement = await resolveAcademicPlacement(
        { db, organizationId, schoolId },
        {
          academicYear: targetYear.year_label,
          className: row.targetClassName,
          sectionName: row.targetSectionName ?? undefined,
        },
        { mode: "full" },
      );

      await db.queryObject(
        `UPDATE sis_student_enrollments SET is_current = false, updated_at = timezone('utc', now())
         WHERE student_id = $1 AND organization_id = $2 AND school_id = $3 AND is_current = true`,
        [row.studentId, organizationId, schoolId],
      );

      const exists = await db.queryCount(
        `SELECT count(*)::text AS count FROM sis_student_enrollments
         WHERE student_id = $1 AND academic_year = $2 AND organization_id = $3 AND school_id = $4`,
        [row.studentId, targetYear.year_label, organizationId, schoolId],
      );
      if (exists > 0) {
        throw new AcademicTransitionValidationError("Enrollment already exists for target year");
      }

      await db.queryObject(
        `INSERT INTO sis_student_enrollments (
           organization_id, school_id, student_id, academic_year, academic_year_id,
           class_name, class_id, section_name, section_id, roll_number, is_current, created_by
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, true, $11)`,
        [
          organizationId,
          schoolId,
          row.studentId,
          targetYear.year_label,
          placement.academicYearId,
          placement.className,
          placement.classId,
          placement.sectionName,
          placement.sectionId,
          null,
          executedBy,
        ],
      );
      await db.queryObject(`RELEASE SAVEPOINT academic_transition_row`);
      promoted++;
    } catch (error) {
      await db.queryObject(`ROLLBACK TO SAVEPOINT academic_transition_row`);
      failed++;
      failures.push({
        studentId: row.studentId,
        error: error instanceof Error ? error.message : "promotion failed",
      });
    }
  }

  if (job.set_target_current) {
    await db.queryObject(
      `UPDATE academic_years SET is_current = false
       WHERE organization_id = $1 AND school_id = $2 AND is_current = true`,
      [organizationId, schoolId],
    );
    await db.queryObject(
      `UPDATE academic_years SET is_current = true, status = 'active'
       WHERE id = $1`,
      [job.target_year_id],
    );
  }

  if (job.archive_source_year) {
    await db.queryObject(
      `UPDATE academic_years SET status = 'archived', is_current = false
       WHERE id = $1`,
      [job.source_year_id],
    );
  }

  const updated = await db.queryObject<AcademicYearTransitionRow>(
    `UPDATE academic_year_transitions
     SET status = $2, promoted_count = $3, skipped_count = $4, failed_count = $5,
         execution_report = $6::jsonb, executed_at = timezone('utc', now())
     WHERE id = $1 RETURNING *`,
    [
      transitionId,
      failed > 0 ? "failed" : "completed",
      promoted,
      skipped,
      failed,
      JSON.stringify({ failures }),
    ],
  );
  return updated[0]!;
}

export async function getTransitionJob(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  transitionId: string,
): Promise<AcademicYearTransitionRow | null> {
  const rows = await db.queryObject<AcademicYearTransitionRow>(
    `SELECT * FROM academic_year_transitions
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [transitionId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}
