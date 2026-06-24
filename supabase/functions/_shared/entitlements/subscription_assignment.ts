// B2 — Step 4.5 · pure helpers for the platform plan-assignment route.
//
// Request parsing/validation kept DB-free and side-effect-free for unit tests.
// Scope: entitlement assignment only — no billing/payments/renewals.

export const ASSIGNABLE_PLAN_SLUGS = [
  "trial",
  "standard",
  "professional",
  "enterprise",
] as const;

export const ASSIGNABLE_STATUSES = [
  "trial",
  "active",
  "grace",
  "suspended",
] as const;

export interface AssignmentInput {
  planSlug: string;
  status: string;
}

/** Default status implied by a plan when the caller does not specify one. */
export function defaultStatusForPlan(planSlug: string): string {
  return planSlug === "trial" ? "trial" : "active";
}

/**
 * Parses/validates the PUT body. Returns null when the plan slug is missing or
 * not assignable, or the (optional) status is invalid. Status defaults from the
 * plan when omitted.
 */
export function parseAssignmentBody(
  body: Record<string, unknown> | null,
): AssignmentInput | null {
  if (!body) return null;
  const planSlug = typeof body.planSlug === "string"
    ? body.planSlug
    : (typeof body.plan_slug === "string" ? body.plan_slug : "");
  if (!ASSIGNABLE_PLAN_SLUGS.includes(planSlug as typeof ASSIGNABLE_PLAN_SLUGS[number])) {
    return null;
  }
  const rawStatus = typeof body.status === "string" && body.status.length > 0
    ? body.status
    : defaultStatusForPlan(planSlug);
  if (!ASSIGNABLE_STATUSES.includes(rawStatus as typeof ASSIGNABLE_STATUSES[number])) {
    return null;
  }
  return { planSlug, status: rawStatus };
}
