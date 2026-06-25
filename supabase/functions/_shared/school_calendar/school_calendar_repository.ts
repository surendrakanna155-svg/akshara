// Holiday/Event Calendar — repository (Phase 1).
// Principal/admin-managed school calendar (holidays, festivals, events). Delivery
// to parents/students/teachers/staff happens via the Publisher (broadcast hub),
// not here — this is the school-scoped source of truth.

import type { TenantQueryClient } from "../tenant_db.ts";

export const CALENDAR_EVENT_TYPES = [
  "holiday",
  "festival",
  "event",
  "exam",
  "result",
  "admission",
  "achievement",
  "general",
] as const;
export type CalendarEventType = typeof CALENDAR_EVENT_TYPES[number];

export interface CalendarEventRow {
  id: string;
  event_date: string;
  end_date: string | null;
  title: string;
  event_type: string;
  description: string | null;
  created_at: string;
}

const SELECT = `id, to_char(event_date, 'YYYY-MM-DD') AS event_date,
  to_char(end_date, 'YYYY-MM-DD') AS end_date, title, event_type, description, created_at`;

export async function listCalendarEvents(
  db: TenantQueryClient,
  filters: { from?: string; to?: string; eventType?: string },
): Promise<CalendarEventRow[]> {
  const conds: string[] = [];
  const params: unknown[] = [];
  if (filters.from) {
    params.push(filters.from);
    conds.push(`event_date >= $${params.length}`);
  }
  if (filters.to) {
    params.push(filters.to);
    conds.push(`event_date <= $${params.length}`);
  }
  if (filters.eventType) {
    params.push(filters.eventType);
    conds.push(`event_type = $${params.length}`);
  }
  const where = conds.length ? `WHERE ${conds.join(" AND ")}` : "";
  return await db.queryObject<CalendarEventRow>(
    `SELECT ${SELECT} FROM school_calendar_events ${where} ORDER BY event_date ASC`,
    params,
  );
}

export async function getCalendarEvent(
  db: TenantQueryClient,
  id: string,
): Promise<CalendarEventRow | null> {
  const rows = await db.queryObject<CalendarEventRow>(
    `SELECT ${SELECT} FROM school_calendar_events WHERE id = $1`,
    [id],
  );
  return rows[0] ?? null;
}

export async function createCalendarEvent(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    eventDate: string;
    endDate?: string | null;
    title: string;
    eventType: string;
    description?: string | null;
    createdBy: string;
  },
): Promise<CalendarEventRow> {
  const rows = await db.queryObject<CalendarEventRow>(
    `INSERT INTO school_calendar_events
       (organization_id, school_id, event_date, end_date, title, event_type, description, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING ${SELECT}`,
    [
      orgId,
      schoolId,
      input.eventDate,
      input.endDate ?? null,
      input.title,
      input.eventType,
      input.description ?? null,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

export async function deleteCalendarEvent(
  db: TenantQueryClient,
  id: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `DELETE FROM school_calendar_events WHERE id = $1 RETURNING id`,
    [id],
  );
  return rows.length > 0;
}
