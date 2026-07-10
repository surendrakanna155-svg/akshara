// Adaptive AI — P3-AI-2 / W2 persona rollout: STUDENT priority-item generators.
//
// The student feed is self-scoped: it reads ONLY the calling student's own rows
// (claims.student_id), via the exact deterministic reads that back the /student/*
// routes — studentStore.listEntities("homework_item") + overlayStudentHomework-
// FromSubmissions (real overdue derivation) and overlayAttendanceSnapshotFrom-
// Records (canonical attendance %). Those routes are RLS-scope-gated to the
// student, so no new query or RLS surface is added.
//
// PRODUCT-SAFETY: a student must NEVER be shown risk/dropout/predictive signals.
// This feed surfaces only encouraging, actionable, own-work nudges (homework due,
// attendance) — the sensitive student-success/risk services are deliberately not
// used here. PURE generators + one async loader. Zero model calls.

import type { AccessTokenClaims } from "../../jwt.ts";
import { organizationIdFromClaims, schoolIdFromClaims } from "../../permission_middleware.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import {
  overlayAttendanceSnapshotFromRecords,
  overlayStudentHomeworkFromSubmissions,
} from "../../pilot/pilot_operations_repository.ts";
import { studentStore } from "../../student/student_read_repository.ts";
import { dueInDaysFrom } from "./feed_dates.ts";
import type { Persona, RawPriorityItem } from "./priority_types.ts";

const STUDENT: Persona[] = ["student"];

/** Below this the student gets a gentle "keep it up" nudge (mirrors the parent
 * alert threshold, framed encouragingly rather than as a risk flag). */
export const STUDENT_ATTENDANCE_NUDGE_PERCENT = 75;

// ─── Structural inputs ───────────────────────────────────────────────────────

export interface StudentHomeworkInput {
  homeworkId: string;
  title: string;
  subject: string;
  /** Overlay-derived display status: overdue / pending / submitted / reviewed. */
  status: string;
  /** Days until due; ≤0 overdue; undefined = no date (loader-computed). */
  dueInDays?: number;
}

// ─── Pure generators ─────────────────────────────────────────────────────────

function dueSoonPhrase(dueInDays: number | undefined): string {
  if (dueInDays === 0) return "today";
  if (dueInDays === 1) return "tomorrow";
  if (typeof dueInDays === "number") return `in ${dueInDays} days`;
  return "soon";
}

/** (1) Homework that is overdue (always) or due within two days (deadline). A
 * submitted/reviewed item is never surfaced — the overlay already marks it done. */
export function studentHomeworkItems(homework: StudentHomeworkInput[]): RawPriorityItem[] {
  return homework
    .filter((h) => {
      const s = h.status.toLowerCase();
      if (s === "overdue") return true;
      if (s !== "pending") return false; // submitted / reviewed / returned → done
      return typeof h.dueInDays === "number" && h.dueInDays >= 0 && h.dueInDays <= 2;
    })
    .map((h) => {
      const overdue = h.status.toLowerCase() === "overdue";
      return {
        itemKey: `student:homework:${h.homeworkId}`,
        type: overdue ? ("exception" as const) : ("deadline" as const),
        title: overdue ? `Overdue homework: ${h.title}` : `Homework due soon: ${h.title}`,
        detail: overdue
          ? `Your ${h.subject} homework "${h.title}" is past its due date. Submit it as soon as you can.`
          : `Your ${h.subject} homework "${h.title}" is due ${dueSoonPhrase(h.dueInDays)}. Plan some time to finish it.`,
        personas: STUDENT,
        entityTags: [`homework:${h.homeworkId}`],
        // Overdue reads as due-today (max urgency); due-soon carries its real clock.
        factors: { dueInDays: overdue ? 0 : h.dueInDays },
        source: "student_homework",
      };
    });
}

/** (2) A gentle attendance nudge when the student's own attendance dips below
 * the threshold. Encouraging framing — NOT a risk score. */
export function studentAttendanceItems(attendancePercent: number | null): RawPriorityItem[] {
  if (attendancePercent === null || attendancePercent >= STUDENT_ATTENDANCE_NUDGE_PERCENT) {
    return [];
  }
  const pct = Math.round(attendancePercent);
  return [{
    itemKey: "student:attendance",
    type: "exception",
    title: "Keep your attendance up",
    detail: `Your attendance is ${pct}%. Attending regularly helps you keep up in class — ` +
      `aim to be present every day you can.`,
    personas: STUDENT,
    entityTags: ["student:attendance"],
    factors: { impactClass: "elevated" },
    source: "student_attendance",
  }];
}

export interface StudentSourceInputs {
  homework?: StudentHomeworkInput[];
  /** null = no usable attendance data (no nudge); a number = the student's %. */
  attendancePercent?: number | null;
}

export function collectStudentRawItems(inputs: StudentSourceInputs): RawPriorityItem[] {
  const items: RawPriorityItem[] = [];
  if (inputs.homework) items.push(...studentHomeworkItems(inputs.homework));
  if (inputs.attendancePercent !== undefined) {
    items.push(...studentAttendanceItems(inputs.attendancePercent));
  }
  return items;
}

// ─── Loader (DB reads; reuses the /student-route repo functions) ──────────────

/** Load the calling student's own raw priority items. Everything is scope-gated
 * to claims.student_id (RLS) — a student can only ever read their own rows.
 * Honest empty feed when there is nothing due. Never degraded (self-scoped, no
 * permission-gated cross-cohort sources). Deterministic, zero model calls. */
export async function loadStudentFeedSources(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  nowIso: string,
): Promise<{ rawItems: RawPriorityItem[]; degraded: boolean }> {
  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);
  // requireStudentSelfScope guarantees student_id is present before we get here.
  const studentId = claims.student_id ?? "";

  // Homework: the exact /student/homework read path — entity list + real overdue
  // overlay (deriveHomeworkDisplayStatus).
  const hwPage = await studentStore.listEntities(db, orgId, schoolId, studentId, "homework_item", {
    page: 1,
    pageSize: 50,
  });
  const overlaid = await overlayStudentHomeworkFromSubmissions(db, orgId, schoolId, studentId, hwPage.items);
  const homework: StudentHomeworkInput[] = overlaid.map((h) => ({
    homeworkId: String(h.id ?? ""),
    title: String(h.title ?? "Homework"),
    subject: String(h.subject ?? ""),
    status: String(h.status ?? "pending"),
    dueInDays: dueInDaysFrom(nowIso, h.dueDate == null ? null : String(h.dueDate)),
  }));

  // Attendance: same canonical overlay, self-scoped to student_id.
  const att = await overlayAttendanceSnapshotFromRecords(db, orgId, schoolId, studentId, {});
  const kpi = (att.kpi ?? {}) as { attendancePercent?: number | null };
  const attendancePercent = typeof kpi.attendancePercent === "number" ? kpi.attendancePercent : null;

  return {
    rawItems: collectStudentRawItems({ homework, attendancePercent }),
    degraded: false,
  };
}
