// Adaptive AI — P3-AI-2 / W2-GATE-2: the Persona Quick Action Registry
// (design doc 10 §7, owner-locked rules 7 & 8).
//
// A server-driven, RBAC-filtered, per-persona catalog of predefined actions —
// the "action-first, AI-last" surface (doc 10 §6). Each action declares a TIER:
//   • t1 = deterministic (ERP data / rules) → resolves to an existing endpoint,
//          ZERO tokens. Rule 7: if a rule/query can answer, it MUST.
//   • t3 = genuinely generative (reasoning / explanation) → opens the governed
//          copilot with a pre-filled prompt, which then passes the Domain Gate +
//          the W1 gateway (metered). Rule 8: LLM only for real value-add.
// This replaces the client's 6 hardcoded stub actions with one reviewable,
// permission-aware registry. RBAC is inherited from the ERP (rule 1/5): an action
// is offered only if the caller holds its `requiredPermission`.

import { isPersona, type Persona } from "../priority/priority_types.ts";

export { isPersona };
export type { Persona };

export type QuickActionTier = "t1" | "t3";

export interface QuickActionResolver {
  /** endpoint = deterministic data route (0 tokens); copilot = governed t3 chat. */
  kind: "endpoint" | "copilot";
  /** For `endpoint`: the API path. For `copilot`: the assistant type. */
  target: string;
  /** For `copilot`: the pre-filled prompt (still passes the Domain Gate). */
  prompt?: string;
}

export interface QuickAction {
  id: string;
  label: string;
  personas: Persona[];
  tier: QuickActionTier;
  /** ERP permission the caller must hold; omitted = any school-scoped user. */
  requiredPermission?: string;
  /** Set when the action needs a specific entity selected first (client supplies
   * the id and substitutes it into the resolver target at tap time). */
  requiresEntity?: "student";
  resolver: QuickActionResolver;
}

// ─── The catalog ─────────────────────────────────────────────────────────────

export const QUICK_ACTIONS: readonly QuickAction[] = [
  // ---- Principal (school-wide operational leadership) ----
  {
    id: "principal_today_priorities",
    label: "Today's priorities",
    personas: ["principal", "admin"],
    tier: "t1",
    requiredPermission: "viewAnalytics",
    resolver: { kind: "endpoint", target: "/intelligence/priorities?persona=principal" },
  },
  {
    id: "principal_high_risk_students",
    label: "High-risk students",
    personas: ["principal", "admin"],
    tier: "t1",
    requiredPermission: "viewStudentRisk",
    resolver: { kind: "endpoint", target: "/intelligence/risk/students?riskLevel=high" },
  },
  {
    id: "principal_fee_collection_summary",
    label: "Fee collection summary",
    personas: ["principal", "admin", "finance"],
    tier: "t1",
    requiredPermission: "viewFinance",
    resolver: { kind: "endpoint", target: "/analytics/dashboard" },
  },
  {
    id: "principal_school_health",
    label: "School health summary",
    personas: ["principal", "admin"],
    tier: "t1",
    requiredPermission: "viewAnalytics",
    resolver: { kind: "endpoint", target: "/intelligence/principal/center" },
  },
  {
    id: "principal_recommendations",
    label: "Recommended actions",
    personas: ["principal", "admin", "finance"],
    tier: "t1",
    requiredPermission: "viewAnalytics",
    resolver: { kind: "endpoint", target: "/intelligence/recommendations?persona=principal" },
  },

  // ---- Teacher (class/section scope) ----
  {
    id: "teacher_class_attendance_summary",
    label: "Attendance summary",
    personas: ["teacher"],
    tier: "t1",
    requiredPermission: "viewAcademicAttendance",
    resolver: { kind: "endpoint", target: "/analytics/dashboard" },
  },
  {
    id: "teacher_weak_chapters",
    label: "Show weak chapters",
    personas: ["teacher"],
    tier: "t1",
    requiredPermission: "viewAnalytics",
    resolver: { kind: "endpoint", target: "/intelligence/exam/weak-chapters" },
  },
  {
    id: "teacher_why_student_at_risk",
    label: "Why is this student at risk?",
    personas: ["teacher", "principal"],
    tier: "t1",
    requiredPermission: "viewStudentRisk",
    requiresEntity: "student",
    // {studentId} substituted client-side; the endpoint returns the deterministic
    // risk reasons already computed by the risk engine (0 tokens).
    resolver: { kind: "endpoint", target: "/intelligence/risk/students/{studentId}" },
  },
  {
    id: "teacher_explain_score_drop",
    label: "Explain score drop",
    personas: ["teacher"],
    tier: "t3",
    requiredPermission: "runAiCopilot",
    requiresEntity: "student",
    resolver: {
      kind: "copilot",
      target: "academic",
      prompt: "Explain the recent drop in this student's exam scores using their marks trend.",
    },
  },

  // ---- Parent (own-children scope) ----
  {
    id: "parent_homework_summary",
    label: "Homework summary",
    personas: ["parent"],
    tier: "t1",
    resolver: { kind: "endpoint", target: "/parent/homework/summary" },
  },
  {
    id: "parent_explain_attendance",
    label: "Explain attendance",
    personas: ["parent"],
    tier: "t3",
    requiredPermission: "runAiCopilot",
    resolver: {
      kind: "copilot",
      target: "parentGuidance",
      prompt: "Explain my child's attendance this month and whether it needs attention.",
    },
  },
  {
    id: "parent_exam_preparation",
    label: "Exam preparation tips",
    personas: ["parent"],
    tier: "t3",
    requiredPermission: "runAiCopilot",
    resolver: {
      kind: "copilot",
      target: "parentGuidance",
      prompt: "How can I help my child prepare for the upcoming exams at home?",
    },
  },
  {
    id: "parent_fee_reminder_explanation",
    label: "Explain fee due",
    personas: ["parent"],
    tier: "t1",
    resolver: { kind: "endpoint", target: "/parent/fees/summary" },
  },
] as const;

/** Actions offered to `persona` that the caller is permitted to use (RBAC
 * inherited from the ERP — an action gated on a permission the caller lacks is
 * never shown, honouring "can't see in UI → AI never reveals", rule 5). */
export function quickActionsFor(persona: Persona, permissions: readonly string[]): QuickAction[] {
  return QUICK_ACTIONS.filter((a) =>
    a.personas.includes(persona) &&
    (a.requiredPermission === undefined || permissions.includes(a.requiredPermission))
  );
}
