import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  runDueScheduledBroadcasts,
  scheduleBroadcastMessage,
} from "../communication/communication_service.ts";

// XCT-2 — the shared in-app reminder / scheduling rail.
//
// ONE rail every module reuses. Homework "due tomorrow" (HWK-8), library
// overdue (LIB-5), transport trip (TRN-8), inventory low-stock (INV-7),
// upcoming exam (EXM-6), communication schedule-send (COM-4), principal /
// parent digests (PRI-5 / PAR-5) and the Finance fee-reminder ladder
// (T-3 / T0 / T+7) all schedule THROUGH here — no module invents its own
// scheduler. A reminder is authored now and fired IN-APP at its due time by
// {@link runDueReminders}; it lands in the recipient's notification inbox
// (`notification_deliveries`, surfaced by the client notifications screen).
// External push / SMS / WhatsApp delivery stays owner-gated — in-app
// surfacing ships now.
//
// Implementation: reminders ride the proven scheduled-broadcast substrate
// (persisted `scheduled_at` row → atomic `FOR UPDATE SKIP LOCKED` claim →
// audience fan-out → pending in-app delivery + audit). This module is the
// module-facing NAME for that rail, so call sites depend on "reminders" and
// never on communication internals.

export interface ScheduleReminderInput {
  /**
   * Who the reminder targets — a broadcast audience token (`school_wide`,
   * `all_parents`, `all_teachers`, `class_parents`, `class_students`, …). Class
   * audiences must carry {@link audienceClass}; the recipient set is resolved at
   * FIRE time (not now), so the audience is always current when it fires.
   */
  audience: string;
  title: string;
  body: string;
  /** When the reminder fires. Any Date-parseable value; normalized to UTC ISO. */
  remindAt: string;
  audienceClass?: string | null;
  audienceSection?: string | null;
  /** COM-D1 — require an explicit acknowledgement from each recipient. */
  requiresAck?: boolean;
}

/**
 * XCT-2 — schedule an in-app reminder to fire at {@link ScheduleReminderInput.remindAt}.
 * Persists a `scheduled` row (recipients are NOT resolved yet) and audits it.
 * Rejects an empty / unparseable `remindAt` (422) so a bad payload fails loud
 * instead of silently never firing. Delegates to the scheduled-broadcast
 * authoring path — the single write seam for the rail.
 */
export function scheduleReminder(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: ScheduleReminderInput,
  req?: Request,
): Promise<Record<string, unknown>> {
  return scheduleBroadcastMessage(
    db,
    claims,
    {
      audience: input.audience,
      title: input.title,
      body: input.body,
      scheduledAt: input.remindAt,
      audienceClass: input.audienceClass,
      audienceSection: input.audienceSection,
      requiresAck: input.requiresAck,
    },
    req,
  );
}

/**
 * XCT-2 — fire every reminder whose time has come for the caller's org and
 * surface each in-app. Idempotent / re-entrant: safe to invoke on a cron / timer
 * OR on demand, and a reminder is claimed by exactly one pass (never
 * double-fired). This is deliberately the SAME runner as the scheduled-broadcast
 * path — literally one runner — so a module reminder and a scheduled broadcast
 * can never diverge in how they fire.
 */
export const runDueReminders = runDueScheduledBroadcasts;
