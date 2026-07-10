// Adaptive AI — P3-AI-2 / W2.0b: the pre-staged one-click action registry
// (design doc 04 §4, pattern P11).
//
// A recommendation = priority item + a pre-staged action. The action carries a
// deep-link and a pre-filled payload; the HUMAN confirms and the normal ERP
// route performs the write. AI NEVER executes (governance rail, doc 01 §6) —
// hence `requiresConfirmation: true` on every action, always. Pure + deterministic.

import type { PriorityItemType, RawPriorityItem } from "./priority_types.ts";

export interface PriorityAction {
  /** Button label the UI renders. */
  label: string;
  /** Logical deep-link the client maps to a route (client owns the mapping). */
  deepLink: string;
  /** Pre-filled parameters for the target surface (e.g. { studentId }). */
  payload: Record<string, unknown>;
  /** ALWAYS true — the action is staged for a human, never auto-executed. */
  requiresConfirmation: true;
}

/** Extract the student id from a `risk:student:<uuid>` item key. */
function studentIdFromKey(itemKey: string): string | null {
  const m = itemKey.match(/^risk:student:(.+)$/);
  return m ? m[1]! : null;
}

/** The suffix after a fixed itemKey prefix (the entity id), or null. */
function suffixAfter(itemKey: string, prefix: string): string | null {
  return itemKey.startsWith(prefix) ? itemKey.slice(prefix.length) : null;
}

/** Map a priority item to its pre-staged one-click action (or undefined when
 * the item is informational and carries no single next step). Keyed on the
 * generator `source` so it stays stable as titles/wording evolve. */
export function actionForItem(item: RawPriorityItem): PriorityAction | undefined {
  switch (item.source) {
    case "fee_collection":
      return {
        label: "Open recovery call queue",
        deepLink: "/finance/recovery/call-queue",
        payload: {},
        requiresConfirmation: true,
      };
    case "student_risk": {
      const studentId = studentIdFromKey(item.itemKey);
      return {
        label: "Review student risk",
        deepLink: studentId
          ? `/intelligence/risk/students/${studentId}`
          : "/intelligence/risk/students",
        payload: studentId ? { studentId } : {},
        requiresConfirmation: true,
      };
    }
    case "timetable_health":
      return {
        label: "Review timetable conflicts",
        deepLink: "/timetable/conflicts",
        payload: {},
        requiresConfirmation: true,
      };
    case "attendance_risk":
      return {
        label: "Review attendance",
        deepLink: "/analytics/attendance",
        payload: {},
        requiresConfirmation: true,
      };
    case "analytics_risk":
      // Finance-tagged analytics risks route to recovery; others to analytics.
      return item.entityTags.includes("school:fees")
        ? {
          label: "Open recovery call queue",
          deepLink: "/finance/recovery/call-queue",
          payload: {},
          requiresConfirmation: true,
        }
        : {
          label: "Open analytics",
          deepLink: "/analytics/dashboard",
          payload: {},
          requiresConfirmation: true,
        };
    // ---- Teacher (own-class scope) ----
    case "teacher_attendance": {
      const classLabel = suffixAfter(item.itemKey, "teacher:attendance:");
      return {
        label: "Mark attendance",
        deepLink: "/teacher/attendance",
        payload: classLabel ? { classId: `class_${classLabel}`, classLabel } : {},
        requiresConfirmation: true,
      };
    }
    case "teacher_homework": {
      const homeworkId = suffixAfter(item.itemKey, "teacher:homework:");
      return {
        label: "Review submissions",
        deepLink: homeworkId ? `/teacher/homework/${homeworkId}` : "/teacher/homework",
        payload: homeworkId ? { homeworkId } : {},
        requiresConfirmation: true,
      };
    }
    case "teacher_exam": {
      const examId = suffixAfter(item.itemKey, "teacher:exam:");
      return {
        label: "Enter marks",
        deepLink: examId ? `/teacher/exams/${examId}/marks` : "/teacher/exams",
        payload: examId ? { examId } : {},
        requiresConfirmation: true,
      };
    }
    // ---- Parent (own-children scope) ----
    case "parent_attendance": {
      const studentId = suffixAfter(item.itemKey, "parent:attendance:");
      return {
        label: "View attendance",
        deepLink: "/parent/attendance",
        payload: studentId ? { activeChildId: studentId } : {},
        requiresConfirmation: true,
      };
    }
    case "parent_fees": {
      const studentId = suffixAfter(item.itemKey, "parent:fees:");
      return {
        label: "View fees",
        deepLink: "/parent/fees",
        payload: studentId ? { activeChildId: studentId } : {},
        requiresConfirmation: true,
      };
    }
    // ---- Student (self scope) ----
    case "student_homework":
      return {
        label: "Open homework",
        deepLink: "/student/homework",
        payload: {},
        requiresConfirmation: true,
      };
    case "student_attendance":
      return {
        label: "View attendance",
        deepLink: "/student/attendance",
        payload: {},
        requiresConfirmation: true,
      };
    default:
      return undefined;
  }
}

/** The item types that always carry an action, for coverage assertions. */
export const ACTIONABLE_TYPES: readonly PriorityItemType[] = [
  "exception",
  "follow_up",
] as const;
