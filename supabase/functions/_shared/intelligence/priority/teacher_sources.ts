// Adaptive AI — P3-AI-2 / W2 persona rollout: TEACHER priority-item generators.
//
// The teacher feed is per-user-scoped: it surfaces only what THIS teacher owns
// (their own classes, homework, exams). It reuses the already-teacher-scoped
// deterministic reads in `pilot_operations_repository.ts` — every one of those
// filters on `teacher_user_id = claims.sub` at the SQL layer, which is the RBAC
// wall (doc 10 §4): timetable/exam RLS is only school-level, so the explicit
// teacher WHERE is what keeps one teacher from seeing another's classes. Reusing
// those functions is therefore the reuse-first AND the RBAC-safe path — a new
// raw query against the same tables would risk cross-teacher leakage.
//
// Split, matching priority_sources.ts: PURE generators (structural input →
// RawPriorityItem, no DB / no clock / no model — unit-tested below) + one async
// loader that does the permitted DB reads and maps them onto those inputs.

import type { AccessTokenClaims } from "../../jwt.ts";
import { organizationIdFromClaims, schoolIdFromClaims } from "../../permission_middleware.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import {
  listTeacherAttendanceClasses,
  listTeacherHomeworkHistory,
  listTeacherUpcomingExams,
} from "../../pilot/pilot_operations_repository.ts";
import type { Persona, RawPriorityItem } from "./priority_types.ts";

const TEACHER: Persona[] = ["teacher"];

// ─── Structural inputs (the loader maps repo rows onto these) ─────────────────

export interface TeacherAttendanceClassInput {
  /** Class label, e.g. "8-A" — the deep-link / entity key. */
  classLabel: string;
  /** Display label (class + subject), e.g. "8-A Mathematics". */
  label: string;
  subject: string;
  studentCount: number;
  /** No submitted attendance session for this class today. */
  isPending: boolean;
}

export interface TeacherHomeworkInput {
  homeworkId: string;
  title: string;
  classLabel: string;
  subject: string;
  submittedCount: number;
  totalCount: number;
  /** Days until due; ≤0 overdue; undefined = no/unparseable date (computed by
   * the loader so the generator stays clock-free). */
  dueInDays?: number;
}

export interface TeacherExamInput {
  examId: string;
  title: string;
  classLabel: string;
  maxMarks: number;
}

// ─── Pure generators ─────────────────────────────────────────────────────────

/** (1) Classes with attendance unmarked today → a due-today exception per class.
 * This is the teacher's top standing obligation, so it is scored as overdue. */
export function teacherAttendanceItems(
  classes: TeacherAttendanceClassInput[],
): RawPriorityItem[] {
  return classes
    .filter((c) => c.isPending)
    .map((c) => {
      const n = Math.max(0, Math.trunc(c.studentCount));
      return {
        itemKey: `teacher:attendance:${c.classLabel}`,
        type: "exception" as const,
        title: `Attendance pending — ${c.classLabel}`,
        detail: `${n} student${n === 1 ? "" : "s"} in ${c.label} not yet marked today. ` +
          `Submit attendance before end of day.`,
        personas: TEACHER,
        entityTags: [`class:${c.classLabel}:attendance`, "teacher:attendance"],
        factors: { dueInDays: 0, peopleAffected: n || 1, impactClass: "elevated" as const },
        source: "teacher_attendance",
      };
    });
}

/** (2) Homework with outstanding submissions in the actionable window → a
 * follow-up per assignment (chase the students who have not submitted). Only
 * surfaces items due within a week or recently overdue, so old assignments with
 * a couple of stragglers do not flood the feed. */
export function teacherHomeworkItems(homework: TeacherHomeworkInput[]): RawPriorityItem[] {
  return homework
    .filter((h) => {
      const pending = h.totalCount - h.submittedCount;
      if (pending <= 0) return false;
      // Clock-free relevance window (dueInDays supplied by the loader): due in
      // the next 7 days or overdue by no more than 14. No date → not surfaced.
      return typeof h.dueInDays === "number" && h.dueInDays <= 7 && h.dueInDays >= -14;
    })
    .map((h) => {
      const pending = h.totalCount - h.submittedCount;
      return {
        itemKey: `teacher:homework:${h.homeworkId}`,
        type: "follow_up" as const,
        title: `${pending} not submitted — ${h.title}`,
        detail: `${h.submittedCount}/${h.totalCount} submitted in ${h.classLabel} (${h.subject}). ` +
          `Follow up with the ${pending} pending student${pending === 1 ? "" : "s"}.`,
        personas: TEACHER,
        entityTags: [`homework:${h.homeworkId}`, "teacher:homework"],
        factors: { dueInDays: h.dueInDays, peopleAffected: pending },
        source: "teacher_homework",
      };
    });
}

/** (3) Exams for the teacher's classes not yet published → a marks-entry
 * deadline. No reliable ISO date exists on the session, so severity (not a
 * clock) carries the urgency. */
export function teacherExamItems(exams: TeacherExamInput[]): RawPriorityItem[] {
  return exams.map((e) => ({
    itemKey: `teacher:exam:${e.examId}`,
    type: "deadline" as const,
    title: `Marks entry — ${e.title}`,
    detail: `${e.title} for ${e.classLabel} is not yet published (max ${e.maxMarks}). ` +
      `Enter and verify marks so results can be released.`,
    personas: TEACHER,
    entityTags: [`exam:${e.examId}`, "teacher:exam"],
    factors: { impactClass: "elevated" as const },
    source: "teacher_exam",
  }));
}

export interface TeacherSourceInputs {
  attendanceClasses?: TeacherAttendanceClassInput[];
  homework?: TeacherHomeworkInput[];
  exams?: TeacherExamInput[];
}

/** Assemble every teacher generator's output. Order is irrelevant — buildFeed
 * scores + sorts deterministically. */
export function collectTeacherRawItems(inputs: TeacherSourceInputs): RawPriorityItem[] {
  const items: RawPriorityItem[] = [];
  if (inputs.attendanceClasses) items.push(...teacherAttendanceItems(inputs.attendanceClasses));
  if (inputs.homework) items.push(...teacherHomeworkItems(inputs.homework));
  if (inputs.exams) items.push(...teacherExamItems(inputs.exams));
  return items;
}

// ─── Loader (DB reads; reuses the teacher-scoped pilot repo) ──────────────────

/** Whole-date difference in days from `fromIso` to `toIso` (date-only). Returns
 * undefined when either side is unparseable. */
function dueInDaysFrom(fromIso: string, toIso: string): number | undefined {
  const DAY = 24 * 60 * 60 * 1000;
  const from = Date.parse(`${fromIso.slice(0, 10)}T00:00:00Z`);
  const to = Date.parse(`${toIso.slice(0, 10)}T00:00:00Z`);
  if (!Number.isFinite(from) || !Number.isFinite(to)) return undefined;
  return Math.round((to - from) / DAY);
}

function toAttendanceInput(r: Record<string, unknown>): TeacherAttendanceClassInput {
  const id = String(r.id ?? "");
  const classLabel = id.startsWith("class_") ? id.slice("class_".length) : id;
  return {
    classLabel,
    label: String(r.label ?? classLabel),
    subject: String(r.subject ?? ""),
    studentCount: Number(r.studentCount ?? 0),
    isPending: Boolean(r.isPending),
  };
}

function toHomeworkInput(h: Record<string, unknown>, nowIso: string): TeacherHomeworkInput {
  const dueDate = h.dueDate == null ? null : String(h.dueDate);
  return {
    homeworkId: String(h.id ?? ""),
    title: String(h.title ?? "Homework"),
    classLabel: String(h.classLabel ?? ""),
    subject: String(h.subject ?? ""),
    submittedCount: Number(h.submittedCount ?? 0),
    totalCount: Number(h.totalCount ?? 0),
    dueInDays: dueDate ? dueInDaysFrom(nowIso, dueDate) : undefined,
  };
}

function toExamInput(e: Record<string, unknown>): TeacherExamInput {
  return {
    examId: String(e.id ?? ""),
    title: String(e.title ?? "Exam"),
    classLabel: String(e.classLabel ?? ""),
    maxMarks: Number(e.maxMarks ?? 0),
  };
}

/** Load the teacher's raw priority items under the current tenant transaction.
 * All three reads self-scope to `claims.sub` at the SQL layer (RBAC wall). A
 * teacher with no timetable/homework/exams returns an honest empty feed. Never
 * degraded — these are the caller's own self-scoped reads, not permission-gated
 * cross-cohort sources. Deterministic, zero model calls. */
export async function loadTeacherFeedSources(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  nowIso: string,
): Promise<{ rawItems: RawPriorityItem[]; degraded: boolean }> {
  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);
  const teacherUserId = claims.sub;
  const wide = { page: 1, pageSize: 50 };

  // Sequential: TenantQueryClient wraps a single pooled connection inside one
  // transaction — concurrent queries on it are unsafe.
  const attendance = await listTeacherAttendanceClasses(db, orgId, schoolId, teacherUserId, wide);
  const homework = await listTeacherHomeworkHistory(db, orgId, schoolId, teacherUserId, {}, wide);
  const exams = await listTeacherUpcomingExams(db, orgId, schoolId, teacherUserId, {
    page: 1,
    pageSize: 8,
  });

  const inputs: TeacherSourceInputs = {
    attendanceClasses: attendance.items.map(toAttendanceInput),
    homework: homework.items.map((h) => toHomeworkInput(h, nowIso)),
    exams: exams.items.map(toExamInput),
  };
  return { rawItems: collectTeacherRawItems(inputs), degraded: false };
}
