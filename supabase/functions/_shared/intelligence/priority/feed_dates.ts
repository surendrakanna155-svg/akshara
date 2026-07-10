// Adaptive AI — P3-AI-2 / W2 persona rollout: shared feed date math.
//
// One place for the per-user feed loaders (teacher / parent / student) to turn a
// due date into a clock-free `dueInDays` factor, so due-date urgency is computed
// identically for every persona. Pure; the caller supplies "now" (the handler's
// generatedAt) so the value is deterministic per request.

/** Whole-date difference in days from `fromIso` to `toIso` (date-only, UTC).
 * Returns undefined when either side is missing/unparseable — the generators
 * treat "no date" as "no clock" rather than fabricating urgency. */
export function dueInDaysFrom(
  fromIso: string,
  toIso: string | null | undefined,
): number | undefined {
  if (!toIso) return undefined;
  const DAY = 24 * 60 * 60 * 1000;
  const from = Date.parse(`${fromIso.slice(0, 10)}T00:00:00Z`);
  const to = Date.parse(`${toIso.slice(0, 10)}T00:00:00Z`);
  if (!Number.isFinite(from) || !Number.isFinite(to)) return undefined;
  return Math.round((to - from) / DAY);
}
