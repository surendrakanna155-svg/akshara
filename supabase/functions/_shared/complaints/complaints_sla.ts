// PRC-A Batch 2 (caps 101-108) — Complaint SLA policy.
//
// Deterministic, single source of truth for the response-time SLA: a lookup
// table keyed on (category, severity), never a scattered magic number. This
// project has an existing defect of exactly that shape (a hardcoded "7 days
// pending" alert) — this module is the fix pattern: one exported policy
// table, a pure function to compute `sla_due_at` at raise time, and a pure
// function to derive on-track/breached at read time.

export const COMPLAINT_CATEGORIES = [
  "facilities",
  "transport",
  "academics",
  "hostel",
  "finance",
  "safety",
  "staff",
  "other",
] as const;
export type ComplaintCategory = (typeof COMPLAINT_CATEGORIES)[number];

export const COMPLAINT_SEVERITIES = ["low", "medium", "high", "critical"] as const;
export type ComplaintSeverity = (typeof COMPLAINT_SEVERITIES)[number];

export const COMPLAINT_STATUSES = [
  "open",
  "assigned",
  "in_progress",
  "resolved",
  "closed",
  "reopened",
] as const;
export type ComplaintStatus = (typeof COMPLAINT_STATUSES)[number];

/**
 * Response-time SLA in HOURS, by (category, severity). This is the single
 * source of truth for `sla_due_at` at raise time. `safety` and `transport`
 * (a moving bus) are the tightest lanes; `other` is the loosest. Every
 * category defines all four severities so the table is total over the DB's
 * own CHECK-constrained domain — a lookup can never silently miss a cell.
 */
export const SLA_POLICY_HOURS: Record<ComplaintCategory, Record<ComplaintSeverity, number>> = {
  safety: { critical: 1, high: 4, medium: 24, low: 48 },
  transport: { critical: 2, high: 8, medium: 24, low: 72 },
  hostel: { critical: 2, high: 12, medium: 24, low: 72 },
  facilities: { critical: 4, high: 24, medium: 48, low: 96 },
  finance: { critical: 8, high: 24, medium: 48, low: 96 },
  academics: { critical: 8, high: 24, medium: 72, low: 120 },
  staff: { critical: 8, high: 24, medium: 72, low: 120 },
  other: { critical: 24, high: 48, medium: 96, low: 168 },
};

/**
 * Defensive fallback ONLY — the DB's CHECK constraints make an unmapped
 * (category, severity) pair impossible in practice, so this branch should
 * never execute against real data; it exists so the function stays total.
 */
export const DEFAULT_SLA_HOURS = 72;

export function slaResponseHours(category: string, severity: string): number {
  const byCategory = SLA_POLICY_HOURS[category as ComplaintCategory];
  const hours = byCategory?.[severity as ComplaintSeverity];
  return hours ?? DEFAULT_SLA_HOURS;
}

/** Computed once, deterministically, at raise time. */
export function computeSlaDueAt(createdAt: Date, category: string, severity: string): Date {
  const hours = slaResponseHours(category, severity);
  return new Date(createdAt.getTime() + hours * 60 * 60 * 1000);
}

export type SlaState = "onTrack" | "breached";

/**
 * Read-time SLA state. While still open, compares `now` against the due
 * date; once resolved, the due date is judged against the ACTUAL resolution
 * time (a complaint resolved late stays "breached" forever, even if read
 * long after — the SLA outcome does not silently heal itself over time).
 */
export function computeSlaState(
  slaDueAt: string | Date,
  now: Date,
  resolvedAt: string | Date | null,
): SlaState {
  const due = new Date(slaDueAt).getTime();
  const reference = resolvedAt != null ? new Date(resolvedAt).getTime() : now.getTime();
  return reference <= due ? "onTrack" : "breached";
}

// ─── Legal status transitions ──────────────────────────────────────────────
//
// A single deterministic table — every write endpoint consults this instead
// of hand-checking status strings inline, so the legal graph lives in one
// place and the tests can enumerate it exhaustively.

export const LEGAL_TRANSITIONS: Record<ComplaintStatus, readonly ComplaintStatus[]> = {
  open: ["assigned", "in_progress", "closed"],
  assigned: ["in_progress", "resolved", "closed"],
  in_progress: ["resolved", "closed"],
  resolved: ["closed", "reopened"],
  closed: ["reopened"],
  reopened: ["assigned", "in_progress", "resolved", "closed"],
};

export function isLegalTransition(from: string, to: string): boolean {
  const targets = LEGAL_TRANSITIONS[from as ComplaintStatus];
  return !!targets && (targets as readonly string[]).includes(to);
}

/** The statuses from which the dedicated /assign endpoint may run (it performs
 * the open->assigned / reopened->assigned edge plus the assignment fields in
 * one write; re-assignment while already assigned/in_progress is not
 * supported — reassign via /status then /assign, or extend deliberately). */
export const ASSIGNABLE_FROM: readonly ComplaintStatus[] = ["open", "reopened"];
