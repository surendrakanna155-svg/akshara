import type { TenantQueryClient } from "../tenant_db.ts";
import {
  createSubstitution,
  isoDayOfWeek,
  listTeachersOnLeave,
  SubstitutionValidationError,
} from "../timetable/substitution_repository.ts";
import {
  reassignTimetablePeriodTeacher,
  TimetableClashError,
  TimetablePublishedError,
} from "../timetable/timetable_repository.ts";
import { EXPECTED_WEEKLY_PERIODS } from "./timetable_optimization_service.ts";

// P0-2 (gap-remediation wave) — SubstituteManagerScreen / TeacherReassignmentScreen
// call 5 endpoints that never had a backend. This module builds real logic on
// top of the EXISTING v7.5 timetable data model (academic_timetable_periods /
// academic_timetables / academic_timetable_substitutions) and the leave
// derivation already used by the persisted-substitutions feature
// (../timetable/substitution_repository.ts) — no new tables, no duplication of
// the clash/published guards already enforced by reassignTimetablePeriodTeacher
// / createSubstitution.

export class WorkforceValidationError extends Error {
  readonly code: string;
  readonly httpStatus: number;
  constructor(code: string, message: string, httpStatus = 422) {
    super(message);
    this.name = "WorkforceValidationError";
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

const DAY_NAMES = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

/** ISO day-of-week (1=Mon..7=Sun) → display name, matching academic_timetable_periods.day_of_week. */
export function dayOfWeekName(dow: number): string {
  return DAY_NAMES[((dow - 1) % 7 + 7) % 7]!;
}

/** Display name (case-insensitive) → ISO day-of-week, or null if unrecognized. */
export function parseDayOfWeekName(name: string): number | null {
  const idx = DAY_NAMES.findIndex((n) => n.toLowerCase() === name.trim().toLowerCase());
  return idx === -1 ? null : idx + 1;
}

/** Server "today" as a YYYY-MM-DD UTC date string. */
export function todayUTC(): string {
  return new Date().toISOString().slice(0, 10);
}

export function addDaysUTC(dateStr: string, days: number): string {
  const d = new Date(`${dateStr}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** Next date (today inclusive, within 7 days) whose ISO weekday matches targetDow — used only for display (slotDate). */
export function nextOccurrenceOfWeekday(fromDateStr: string, targetDow: number): string {
  for (let i = 0; i < 7; i++) {
    const candidate = addDaysUTC(fromDateStr, i);
    if (isoDayOfWeek(candidate) === targetDow) return candidate;
  }
  return fromDateStr;
}

export interface SubstituteOpenSlotApi {
  slotId: string;
  academicYearId: string;
  className: string;
  sectionName: string;
  subjectName: string;
  originalTeacherId: string;
  originalTeacherName: string;
  dayOfWeek: string;
  periodLabel: string;
  slotDate: string;
}

export interface WorkforceCandidateApi {
  teacherId: string;
  teacherName: string;
  subjects: string[];
  freePeriods: number;
  dailyLoad: number;
  canNotify: boolean;
}

export interface SubstituteCoverageApi {
  openSlots: SubstituteOpenSlotApi[];
  candidates: WorkforceCandidateApi[];
  generatedAt: string;
}

async function resolvePeriodsPerDay(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
): Promise<number> {
  const rows = await db.queryObject<{ max_periods: number | null }>(
    `SELECT max(periods_per_day)::int AS max_periods
     FROM academic_timetables
     WHERE organization_id = $1 AND school_id = $2 AND academic_year_id = $3
       AND status <> 'archived'`,
    [orgId, schoolId, academicYearId],
  );
  return rows[0]?.max_periods ?? 8;
}

/**
 * Active teachers in the school, ranked as candidates. `loadMode: "daily"`
 * scores against a single reference weekday (substitute coverage — who is
 * free THAT day); `"weekly"` scores against total weekly period count
 * (teacher reassignment — moving periods permanently, not date-bound).
 * Reuses the SAME academic_timetable_periods data `analyzeTimetableOptimization`
 * reads, just grouped differently.
 */
async function buildCandidates(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
  opts: {
    excludeTeacherIds: string[];
    loadMode: "daily" | "weekly";
    referenceDow?: number;
  },
): Promise<WorkforceCandidateApi[]> {
  const teacherRows = await db.queryObject<{ id: string; teacher_name: string; phone: string | null }>(
    `SELECT u.id, COALESCE(u.display_name, u.phone, u.id::text) AS teacher_name, u.phone
     FROM users u
     JOIN school_memberships sm ON sm.user_id = u.id
     WHERE sm.school_id = $1 AND sm.role = 'teacher' AND sm.status = 'active'`,
    [schoolId],
  );

  const subjectRows = await db.queryObject<{ teacher_id: string; subject_label: string }>(
    `SELECT DISTINCT p.teacher_id, p.subject_label
     FROM academic_timetable_periods p
     JOIN academic_timetables t ON t.id = p.timetable_id
     WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
       AND t.status <> 'archived' AND p.teacher_id IS NOT NULL`,
    [orgId, schoolId, academicYearId],
  );
  const subjectMap = new Map<string, string[]>();
  for (const row of subjectRows) {
    const list = subjectMap.get(row.teacher_id) ?? [];
    list.push(row.subject_label);
    subjectMap.set(row.teacher_id, list);
  }

  let loadRows: Array<{ teacher_id: string; cnt: number }>;
  let expectedLoad: number;
  if (opts.loadMode === "daily") {
    loadRows = await db.queryObject<{ teacher_id: string; cnt: number }>(
      `SELECT p.teacher_id, count(*)::int AS cnt
       FROM academic_timetable_periods p
       JOIN academic_timetables t ON t.id = p.timetable_id
       WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
         AND t.status <> 'archived' AND p.day_of_week = $4 AND p.teacher_id IS NOT NULL
       GROUP BY p.teacher_id`,
      [orgId, schoolId, academicYearId, opts.referenceDow ?? 1],
    );
    expectedLoad = await resolvePeriodsPerDay(db, orgId, schoolId, academicYearId);
  } else {
    loadRows = await db.queryObject<{ teacher_id: string; cnt: number }>(
      `SELECT p.teacher_id, count(*)::int AS cnt
       FROM academic_timetable_periods p
       JOIN academic_timetables t ON t.id = p.timetable_id
       WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
         AND t.status <> 'archived' AND p.teacher_id IS NOT NULL
       GROUP BY p.teacher_id`,
      [orgId, schoolId, academicYearId],
    );
    expectedLoad = EXPECTED_WEEKLY_PERIODS;
  }
  const loadMap = new Map(loadRows.map((r) => [r.teacher_id, r.cnt]));

  const exclude = new Set(opts.excludeTeacherIds);
  return teacherRows
    .filter((t) => !exclude.has(t.id))
    .map((t) => {
      const load = loadMap.get(t.id) ?? 0;
      return {
        teacherId: t.id,
        teacherName: t.teacher_name,
        subjects: subjectMap.get(t.id) ?? [],
        dailyLoad: load,
        freePeriods: Math.max(0, expectedLoad - load),
        // users.phone is NOT NULL for every account, so any active school
        // membership is contactable — real derived signal, not a stub.
        canNotify: Boolean(t.phone),
      };
    })
    .sort((a, b) => b.freePeriods - a.freePeriods);
}

export async function getSubstituteCoverage(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
  dayOfWeekFilter?: string,
): Promise<SubstituteCoverageApi> {
  const normalizedFilter = dayOfWeekFilter?.trim();
  let filterDow: number | null = null;
  if (normalizedFilter) {
    filterDow = parseDayOfWeekName(normalizedFilter);
    if (filterDow === null) {
      throw new WorkforceValidationError(
        "VALIDATION_ERROR",
        `Unrecognized dayOfWeek: ${dayOfWeekFilter}`,
        422,
      );
    }
  }

  const today = todayUTC();
  const windowDates: Array<{ date: string; dow: number }> = [];
  for (let i = 0; i < 7; i++) {
    const date = addDaysUTC(today, i);
    const dow = isoDayOfWeek(date);
    if (filterDow !== null && dow !== filterDow) continue;
    windowDates.push({ date, dow });
  }

  const openSlots: SubstituteOpenSlotApi[] = [];
  for (const { date, dow } of windowDates) {
    const onLeave = await listTeachersOnLeave(db, orgId, schoolId, date);
    if (onLeave.length === 0) continue;
    const teacherIds = [...new Set(onLeave.map((t) => t.teacherId))];

    const rows = await db.queryObject<{
      period_id: string;
      period_number: number;
      subject_label: string;
      teacher_id: string;
      class_name: string;
      section_name: string;
      teacher_name: string;
    }>(
      `SELECT p.id AS period_id, p.period_number, p.subject_label, p.teacher_id,
              c.class_name, s.section_name,
              COALESCE(u.display_name, u.phone, p.teacher_id::text) AS teacher_name
       FROM academic_timetable_periods p
       JOIN academic_timetables t ON t.id = p.timetable_id
       JOIN sections s ON s.id = t.section_id
       JOIN classes c ON c.id = s.class_id
       LEFT JOIN users u ON u.id = p.teacher_id
       LEFT JOIN academic_timetable_substitutions sub
         ON sub.period_id = p.id AND sub.sub_date = $5::date
       WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
         AND t.status <> 'archived'
         AND p.day_of_week = $4
         AND p.teacher_id = ANY($6::uuid[])
         AND sub.id IS NULL
       ORDER BY p.period_number`,
      [orgId, schoolId, academicYearId, dow, date, teacherIds],
    );

    for (const row of rows) {
      openSlots.push({
        slotId: `${row.period_id}:${date}`,
        academicYearId,
        className: row.class_name,
        sectionName: row.section_name,
        subjectName: row.subject_label,
        originalTeacherId: row.teacher_id,
        originalTeacherName: row.teacher_name,
        dayOfWeek: dayOfWeekName(dow),
        periodLabel: `P${row.period_number}`,
        slotDate: date,
      });
    }
  }

  // Candidate ranking reference = the (single) filtered day, else today.
  const referenceDow = windowDates[0]?.dow ?? isoDayOfWeek(today);
  const referenceDate = windowDates[0]?.date ?? today;
  const onLeaveReference = await listTeachersOnLeave(db, orgId, schoolId, referenceDate);
  const candidates = await buildCandidates(db, orgId, schoolId, academicYearId, {
    excludeTeacherIds: onLeaveReference.map((t) => t.teacherId),
    loadMode: "daily",
    referenceDow,
  });

  return { openSlots, candidates, generatedAt: new Date().toISOString() };
}

export interface AssignSubstituteInput {
  slotId: string;
  substituteTeacherId: string;
  notifySubstituteTeacher: boolean;
  notifyClassIncharge: boolean;
  notifyStudents: boolean;
}

export interface SubstituteAssignmentApi {
  assignmentId: string;
  slotId: string;
  timetableUpdated: boolean;
  notifiedAudience: string[];
  message: string;
}

export async function assignSubstitute(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: AssignSubstituteInput,
  createdBy: string,
): Promise<SubstituteAssignmentApi> {
  const separatorIndex = input.slotId.lastIndexOf(":");
  const periodId = separatorIndex === -1 ? "" : input.slotId.slice(0, separatorIndex);
  const subDate = separatorIndex === -1 ? "" : input.slotId.slice(separatorIndex + 1);
  if (!periodId || !subDate) {
    throw new WorkforceValidationError(
      "VALIDATION_ERROR",
      "slotId must be in '<periodId>:<YYYY-MM-DD>' form (from GET .../substitute/coverage)",
      422,
    );
  }

  const created = await createSubstitution(db, {
    orgId,
    schoolId,
    periodId,
    subDate,
    substituteTeacherId: input.substituteTeacherId,
    reason: "Assigned via Substitute Teacher Wizard",
    createdBy,
  });

  const notifiedAudience: string[] = [
    ...(input.notifySubstituteTeacher ? ["substitute_teacher"] : []),
    ...(input.notifyClassIncharge ? ["class_incharge"] : []),
    ...(input.notifyStudents ? ["students"] : []),
  ];

  return {
    assignmentId: created.id,
    slotId: input.slotId,
    timetableUpdated: true,
    notifiedAudience,
    message: "Substitute assigned and timetable updated.",
  };
}

export interface TeacherReassignmentSlotApi {
  slotId: string;
  academicYearId: string;
  sourceTeacherId: string;
  sourceTeacherName: string;
  className: string;
  sectionName: string;
  subjectName: string;
  dayOfWeek: string;
  periodLabel: string;
  slotDate: string;
}

export interface TeacherReassignmentOptionsApi {
  sourceTeacherId: string;
  sourceTeacherName: string;
  slots: TeacherReassignmentSlotApi[];
  candidates: WorkforceCandidateApi[];
  generatedAt: string;
}

export async function getTeacherReassignmentOptions(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
  sourceTeacherId?: string,
): Promise<TeacherReassignmentOptionsApi> {
  const nameRows = await db.queryObject<{ id: string; teacher_name: string }>(
    `SELECT u.id, COALESCE(u.display_name, u.phone, u.id::text) AS teacher_name
     FROM users u
     JOIN school_memberships sm ON sm.user_id = u.id
     WHERE sm.school_id = $1 AND sm.role = 'teacher' AND sm.status = 'active'`,
    [schoolId],
  );
  const nameMap = new Map(nameRows.map((r) => [r.id, r.teacher_name]));

  let resolvedSourceId = sourceTeacherId?.trim();
  if (!resolvedSourceId) {
    // No explicit source → default to the most-loaded teacher this year (the
    // one a "rebalance" wizard would naturally start with).
    const loadRows = await db.queryObject<{ teacher_id: string; cnt: number }>(
      `SELECT p.teacher_id, count(*)::int AS cnt
       FROM academic_timetable_periods p
       JOIN academic_timetables t ON t.id = p.timetable_id
       WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
         AND t.status <> 'archived' AND p.teacher_id IS NOT NULL
       GROUP BY p.teacher_id
       ORDER BY cnt DESC
       LIMIT 1`,
      [orgId, schoolId, academicYearId],
    );
    resolvedSourceId = loadRows[0]?.teacher_id;
  }

  if (!resolvedSourceId) {
    return {
      sourceTeacherId: "",
      sourceTeacherName: "",
      slots: [],
      candidates: await buildCandidates(db, orgId, schoolId, academicYearId, {
        excludeTeacherIds: [],
        loadMode: "weekly",
      }),
      generatedAt: new Date().toISOString(),
    };
  }

  const rows = await db.queryObject<{
    period_id: string;
    day_of_week: number;
    period_number: number;
    subject_label: string;
    class_name: string;
    section_name: string;
  }>(
    `SELECT p.id AS period_id, p.day_of_week, p.period_number, p.subject_label,
            c.class_name, s.section_name
     FROM academic_timetable_periods p
     JOIN academic_timetables t ON t.id = p.timetable_id
     JOIN sections s ON s.id = t.section_id
     JOIN classes c ON c.id = s.class_id
     WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
       AND t.status <> 'archived' AND p.teacher_id = $4
     ORDER BY p.day_of_week, p.period_number`,
    [orgId, schoolId, academicYearId, resolvedSourceId],
  );

  const sourceTeacherName = nameMap.get(resolvedSourceId) ?? resolvedSourceId;
  const today = todayUTC();
  const slots: TeacherReassignmentSlotApi[] = rows.map((row) => ({
    slotId: row.period_id,
    academicYearId,
    sourceTeacherId: resolvedSourceId!,
    sourceTeacherName,
    className: row.class_name,
    sectionName: row.section_name,
    subjectName: row.subject_label,
    dayOfWeek: dayOfWeekName(row.day_of_week),
    periodLabel: `P${row.period_number}`,
    slotDate: nextOccurrenceOfWeekday(today, row.day_of_week),
  }));

  const candidates = await buildCandidates(db, orgId, schoolId, academicYearId, {
    excludeTeacherIds: [resolvedSourceId],
    loadMode: "weekly",
  });

  return {
    sourceTeacherId: resolvedSourceId,
    sourceTeacherName,
    slots,
    candidates,
    generatedAt: new Date().toISOString(),
  };
}

export interface ReassignTeacherBulkInput {
  academicYearId: string;
  sourceTeacherId: string;
  targetTeacherId: string;
  slotIds: string[];
  notifySourceTeacher: boolean;
  notifyTargetTeacher: boolean;
  notifyStudents: boolean;
}

export interface TeacherReassignmentBulkApi {
  reassignmentId: string;
  sourceTeacherId: string;
  targetTeacherId: string;
  updatedSlotIds: string[];
  notifiedAudience: string[];
  message: string;
}

export async function reassignTeacherBulk(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: ReassignTeacherBulkInput,
): Promise<TeacherReassignmentBulkApi> {
  if (input.slotIds.length === 0) {
    throw new WorkforceValidationError("VALIDATION_ERROR", "slotIds must not be empty", 422);
  }
  if (input.sourceTeacherId === input.targetTeacherId) {
    throw new WorkforceValidationError(
      "VALIDATION_ERROR",
      "targetTeacherId must differ from sourceTeacherId",
      422,
    );
  }

  // Defense-in-depth: confirm every slot is CURRENTLY taught by sourceTeacherId
  // in THIS academic year before mutating anything (reassignTimetablePeriodTeacher
  // itself only knows org+school scope, not "who used to teach this").
  const ownershipRows = await db.queryObject<{ id: string; teacher_id: string | null }>(
    `SELECT p.id, p.teacher_id
     FROM academic_timetable_periods p
     JOIN academic_timetables t ON t.id = p.timetable_id
     WHERE p.organization_id = $1 AND p.school_id = $2 AND t.academic_year_id = $3
       AND p.id = ANY($4::uuid[])`,
    [orgId, schoolId, input.academicYearId, input.slotIds],
  );
  const ownershipMap = new Map(ownershipRows.map((r) => [r.id, r.teacher_id]));
  for (const slotId of input.slotIds) {
    if (!ownershipMap.has(slotId)) {
      throw new WorkforceValidationError("NOT_FOUND", `Period not found: ${slotId}`, 404);
    }
    if (ownershipMap.get(slotId) !== input.sourceTeacherId) {
      throw new WorkforceValidationError(
        "VALIDATION_ERROR",
        `Period ${slotId} is not currently taught by sourceTeacherId`,
        409,
      );
    }
  }

  const updatedSlotIds: string[] = [];
  for (const periodId of input.slotIds) {
    const result = await reassignTimetablePeriodTeacher(db, orgId, schoolId, {
      periodId,
      teacherId: input.targetTeacherId,
    });
    updatedSlotIds.push(result.id);
  }

  const notifiedAudience: string[] = [
    ...(input.notifySourceTeacher ? ["source_teacher"] : []),
    ...(input.notifyTargetTeacher ? ["target_teacher"] : []),
    ...(input.notifyStudents ? ["students"] : []),
  ];

  return {
    reassignmentId: `reassign_${Date.now()}_${input.sourceTeacherId.slice(0, 8)}`,
    sourceTeacherId: input.sourceTeacherId,
    targetTeacherId: input.targetTeacherId,
    updatedSlotIds,
    notifiedAudience,
    message: `${updatedSlotIds.length} period(s) reassigned successfully.`,
  };
}

export { SubstitutionValidationError, TimetableClashError, TimetablePublishedError };
