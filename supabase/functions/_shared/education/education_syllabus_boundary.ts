import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * Thrown when a question-paper request targets chapters outside the seeded
 * syllabus for the given class + subject. Maps to an HTTP 422 in the handler.
 */
export class OffSyllabusError extends Error {
  constructor(
    readonly className: string,
    readonly subjectName: string,
    readonly offSyllabus: string[],
    readonly allowed: string[],
  ) {
    super(
      `Off-syllabus chapter(s) for ${subjectName} (${className}): ` +
        `${offSyllabus.join(", ")}. ` +
        (allowed.length > 0
          ? `Allowed chapters: ${allowed.join(", ")}.`
          : `No syllabus is seeded for this class + subject.`),
    );
    this.name = "OffSyllabusError";
  }
}

/** Normalise a chapter/grade string for tolerant comparison. */
function norm(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

/**
 * Extracts the numeric/identifying grade token from a class label so that
 * "10", "10-A", "Class 10" and "Grade 10" all resolve to the same template
 * grade ("grade 10").
 */
function gradeKey(className: string): string {
  const match = className.match(/(\d+)/);
  return match ? `grade ${match[1]}` : norm(className);
}

/**
 * Loads the authoritative set of allowed chapter names for a class + subject.
 *
 * School-first: the per-school materialised `syllabus_chapters` (produced by the
 * syllabus wizard) is authoritative. If a school has not yet materialised any
 * chapters for this class + subject, we fall back to the global seeded
 * `subject_templates` catalogue (board-agnostic, matched on grade + subject),
 * so the boundary still holds for freshly-onboarded schools.
 *
 * Returns the allowed chapter names (already normalised for comparison) and
 * whether any syllabus source was found at all.
 */
export async function loadAllowedChapters(
  client: TenantQueryClient,
  className: string,
  subjectName: string,
): Promise<{ allowed: Set<string>; display: string[]; hasSyllabus: boolean }> {
  // 1) School-scoped materialised syllabus (authoritative when present).
  const schoolRows = await client.queryObject<{ chapter_name: string }>(
    `SELECT sc.chapter_name
       FROM syllabus_chapters sc
       JOIN academic_subjects asub ON asub.id = sc.subject_id
      WHERE sc.organization_id = app_current_tenant_id()
        AND sc.school_id = app_current_school_id()
        AND sc.class_name ILIKE $1
        AND asub.subject_name ILIKE $2`,
    [className, subjectName],
  );

  if (schoolRows.length > 0) {
    const display = schoolRows.map((r) => r.chapter_name);
    return {
      allowed: new Set(display.map(norm)),
      display,
      hasSyllabus: true,
    };
  }

  // 2) Global seeded catalogue fallback (subject_templates.chapters jsonb).
  const catalogRows = await client.queryObject<{ chapters: unknown }>(
    `SELECT chapters
       FROM subject_templates
      WHERE subject_name ILIKE $1
        AND lower(grade_label) = $2`,
    [subjectName, gradeKey(className)],
  );

  const display: string[] = [];
  for (const row of catalogRows) {
    const chapters = Array.isArray(row.chapters) ? row.chapters : [];
    for (const ch of chapters) {
      const name = (ch as { name?: unknown })?.name;
      if (typeof name === "string" && name.trim().length > 0) {
        display.push(name);
      }
    }
  }

  return {
    allowed: new Set(display.map(norm)),
    display,
    hasSyllabus: display.length > 0,
  };
}

/**
 * Hard syllabus boundary: rejects the request when any requested chapter is
 * outside the seeded syllabus for the class + subject. Empty chapter lists are
 * allowed (the solver then targets the whole subject bank); a non-empty list is
 * fully validated.
 *
 * Throws {@link OffSyllabusError} on violation.
 */
export async function assertChaptersWithinSyllabus(
  client: TenantQueryClient,
  className: string,
  subjectName: string,
  requestedChapters: string[],
): Promise<void> {
  const requested = requestedChapters
    .map((c) => c.trim())
    .filter((c) => c.length > 0);
  if (requested.length === 0) return;

  const { allowed, display } = await loadAllowedChapters(
    client,
    className,
    subjectName,
  );

  // No seeded syllabus at all → cannot honour a chapter restriction safely.
  if (allowed.size === 0) {
    throw new OffSyllabusError(className, subjectName, requested, []);
  }

  const offSyllabus = requested.filter((c) => !allowed.has(norm(c)));
  if (offSyllabus.length > 0) {
    throw new OffSyllabusError(className, subjectName, offSyllabus, display);
  }
}
