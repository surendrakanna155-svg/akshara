// Adaptive AI — P3-AI-2 / W2 persona rollout: shared feed date math.
//
// One place for the per-user feed loaders (teacher / parent / student) to turn a
// due date into a clock-free `dueInDays` factor, so due-date urgency is computed
// identically for every persona. Pure; the caller supplies "now" (the handler's
// generatedAt) so the value is deterministic per request.

const DAY_MS = 24 * 60 * 60 * 1000;
// School-local timezone. NIKSHA is India-first (CBSE/CISCE/AP/TS boards), so
// "today"/"overdue" must be computed on the IST wall clock, not server UTC —
// otherwise during IST 00:00–05:29 (UTC 18:30–23:59 the prior day) a homework
// due "today" reads dueInDays=1 and an item overdue since IST-midnight reads 0.
// (P2-7. Per-tenant timezones can replace this constant later.)
const IST_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;

/** The IST calendar date (YYYY-MM-DD) for an ISO timestamp — the school-local
 * "today" for date-string comparisons (same P2-7 rationale as dueInDaysFrom). */
export function istDateOf(nowIso: string): string {
  const t = Date.parse(nowIso);
  const shifted = new Date((Number.isFinite(t) ? t : Date.now()) + IST_OFFSET_MS);
  return shifted.toISOString().slice(0, 10);
}

/** The IST calendar-day index for an ISO timestamp or date-only string. */
function istDayIndex(iso: string): number | undefined {
  const t = Date.parse(iso.length <= 10 ? `${iso}T00:00:00Z` : iso);
  if (!Number.isFinite(t)) return undefined;
  return Math.floor((t + IST_OFFSET_MS) / DAY_MS);
}

/** How long something has been waiting, in whole days, measured on the IST
 * calendar — the inverse direction of [dueInDaysFrom].
 *
 * This is the wait clock that revives the engine's `ageBoost` factor. Until
 * Phase 6a nothing populated `factors.waitingDays`, so `ageBoostFactor` returned
 * a constant 1.0 and the promise in its doc comment — "an approval nobody has
 * touched in two weeks climbs above a fresh one" — never actually happened.
 *
 * Returns undefined for a missing/unparseable timestamp: no clock, rather than a
 * fabricated zero. A `0` here would read as "just arrived", which is a claim we
 * cannot support without a real created_at.
 *
 * Negative differences clamp to 0 — a row stamped in the future (clock skew) has
 * not been waiting a negative amount of time. */
export function waitingDaysSince(
  nowIso: string,
  createdIso: string | null | undefined,
): number | undefined {
  const days = dueInDaysFrom(createdIso ?? "", nowIso);
  if (days === undefined) return undefined;
  return Math.max(0, days);
}

/** Whole-date difference in days from `fromIso` to `toIso`, measured on the
 * school-local (IST) calendar. Returns undefined when either side is missing/
 * unparseable — the generators treat "no date" as "no clock" rather than
 * fabricating urgency. */
export function dueInDaysFrom(
  fromIso: string,
  toIso: string | null | undefined,
): number | undefined {
  if (!toIso) return undefined;
  const from = istDayIndex(fromIso);
  const to = istDayIndex(toIso);
  if (from === undefined || to === undefined) return undefined;
  return to - from;
}
