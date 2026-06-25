// Holiday/Event Calendar — handlers (Phase 1).

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  CALENDAR_EVENT_TYPES,
  type CalendarEventRow,
  createCalendarEvent,
  deleteCalendarEvent,
  listCalendarEvents,
} from "./school_calendar_repository.ts";

function requireCalendarRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewSchoolCalendar") ?? requireSchoolOperationalScope(claims);
}

function requireCalendarManage(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageSchoolCalendar") ?? requireSchoolOperationalScope(claims);
}

function mapEvent(row: CalendarEventRow) {
  return {
    id: row.id,
    eventDate: row.event_date,
    endDate: row.end_date,
    title: row.title,
    eventType: row.event_type,
    description: row.description,
    createdAt: row.created_at,
  };
}

function calendarError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  return errorEnvelope("SCHOOL_CALENDAR_ERROR", String(error), 500);
}

export async function handleListCalendar(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireCalendarRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listCalendarEvents(db, {
        from: url.searchParams.get("from") ?? undefined,
        to: url.searchParams.get("to") ?? undefined,
        eventType: url.searchParams.get("eventType") ?? undefined,
      }));
    return jsonResponse(envelope({ items: items.map(mapEvent) }));
  } catch (error) {
    return calendarError(error);
  }
}

export async function handleCreateCalendarEvent(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireCalendarManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    eventDate?: string;
    endDate?: string;
    title?: string;
    eventType?: string;
    description?: string;
  }>(req);
  if (!body?.eventDate || !body.title) {
    return errorEnvelope("VALIDATION_ERROR", "eventDate and title are required", 422);
  }
  const eventType = body.eventType ?? "holiday";
  if (!(CALENDAR_EVENT_TYPES as readonly string[]).includes(eventType)) {
    return errorEnvelope("VALIDATION_ERROR", `eventType must be one of ${CALENDAR_EVENT_TYPES.join(", ")}`, 422);
  }

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createCalendarEvent(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        {
          eventDate: body.eventDate!,
          endDate: body.endDate ?? null,
          title: body.title!,
          eventType,
          description: body.description ?? null,
          createdBy: auth.claims.sub,
        },
      );
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("school_calendar.event.created", "school_calendar_event", created.id, {
          eventType,
        }),
        req,
      );
      return created;
    });
    return jsonResponse(envelope(mapEvent(row)), { status: 201 });
  } catch (error) {
    return calendarError(error);
  }
}

export async function handleDeleteCalendarEvent(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireCalendarManage(auth.claims);
  if (denied) return denied;

  try {
    const ok = await withTenantContext(config, auth.claims, async (db) => {
      const deleted = await deleteCalendarEvent(db, id);
      if (deleted) {
        await emitMutationAudit(
          db,
          auth.claims,
          moduleEntityAudit("school_calendar.event.deleted", "school_calendar_event", id, {}),
          req,
        );
      }
      return deleted;
    });
    if (!ok) return errorEnvelope("NOT_FOUND", "Calendar event not found", 404);
    return jsonResponse(envelope({ id, deleted: true }));
  } catch (error) {
    return calendarError(error);
  }
}
