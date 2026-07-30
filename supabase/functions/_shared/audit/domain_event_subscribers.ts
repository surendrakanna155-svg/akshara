// Domain-event in-process subscriber registry (ICA-G1).
//
// OWNER DECISION (G1): the internal `domain_events` log is the CANONICAL event
// implementation. This registry is the FUTURE-COMPATIBILITY SEAM — a clean,
// bus-shaped subscriber contract that an external event bus (Kafka / NATS /
// RabbitMQ / …) can slot behind LATER as a drop-in. No external messaging
// infrastructure is introduced now, and this module imports no messaging
// library — dispatch is purely in-process, driven by the outbox drain worker
// (`domain_events_worker.ts`).
//
// Why a registry at all: before this seam, `publishPendingDomainEvents` flipped
// `status='published'` with NOTHING running between the SELECT and the UPDATE —
// "published" meant only "row flipped", never "delivered". With the registry,
// the drain DISPATCHES each event to every matching subscriber and marks it
// published ONLY after they all succeed (at-least-once; a throw leaves the event
// pending/failed for the next drain). With zero subscribers the drain still
// bounds the table — "published" then honestly means "dispatched to all
// registered subscribers (none configured), i.e. durably logged".

import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * A single domain event as delivered to an in-process subscriber. Deliberately
 * self-contained: it carries every business field a consumer needs so that a
 * future EXTERNAL-bus adapter can reconstruct the same object from a serialized
 * message with no schema change to subscribers.
 */
export interface DomainEvent {
  /** `domain_events.id` (uuid, as text). */
  id: string;
  organizationId: string;
  schoolId: string | null;
  eventType: string;
  payload: Record<string, unknown>;
  correlationId: string | null;
  sourceModule: string;
  /** ISO-8601 UTC. */
  createdAt: string;
}

/**
 * The future-compatibility seam. An in-process subscriber consumes domain
 * events during the outbox drain.
 *
 * This interface is intentionally bus-shaped: `name` maps to an external event
 * bus's CONSUMER-GROUP name, `eventTypes` to its topic/subscription filter, and
 * `handle` to its message callback. Migrating to an external bus later replaces
 * ONLY the dispatch loop (`dispatchDomainEvent`) — every subscriber
 * implementation carries over unchanged.
 *
 * The second `db` argument is an in-process convenience (the drain's
 * tenant-scoped client) so a subscriber can do DB work in the same tenant
 * context; a subscriber that needs none may declare `handle(event)` and still
 * satisfy this type. An external-bus adapter would simply not pass it.
 */
export interface DomainEventSubscriber {
  /** Stable identifier; a consumer-group name in a future external bus. */
  name: string;
  /** Event types this subscriber consumes, or `"*"` for all. */
  eventTypes: string[] | "*";
  /**
   * Handle exactly one event. MUST be idempotent: delivery is AT-LEAST-ONCE, so
   * a throw (from this subscriber or a later one for the same event) leaves the
   * event un-published and it is REDELIVERED to every matching subscriber on the
   * next drain.
   */
  handle(event: DomainEvent, db: TenantQueryClient): Promise<void>;
}

const registry: DomainEventSubscriber[] = [];

/** True when `subscriber` consumes `eventType`. */
export function subscriberMatches(
  subscriber: DomainEventSubscriber,
  eventType: string,
): boolean {
  return subscriber.eventTypes === "*" || subscriber.eventTypes.includes(eventType);
}

/**
 * Register an in-process subscriber. Names must be unique — a duplicate name is
 * rejected to prevent the exact double-invocation hazard the seam exists to
 * avoid (a handler firing twice per event).
 */
export function registerDomainEventSubscriber(subscriber: DomainEventSubscriber): void {
  if (registry.some((s) => s.name === subscriber.name)) {
    throw new Error(`Domain event subscriber already registered: ${subscriber.name}`);
  }
  registry.push(subscriber);
}

/** The currently registered subscribers (read-only snapshot). */
export function getDomainEventSubscribers(): readonly DomainEventSubscriber[] {
  return registry;
}

/** Remove all subscribers. Intended for test isolation. */
export function clearDomainEventSubscribers(): void {
  registry.length = 0;
}

/**
 * Dispatch one event to every registered subscriber whose `eventTypes` match,
 * in registration order. Any subscriber throwing propagates to the caller (the
 * drain worker), which then leaves the event pending/failed for retry — so this
 * never partially "commits" a publish. With no matching subscribers this is a
 * no-op and the event is published as a pure log entry.
 */
export async function dispatchDomainEvent(
  event: DomainEvent,
  db: TenantQueryClient,
): Promise<void> {
  for (const subscriber of registry) {
    if (subscriberMatches(subscriber, event.eventType)) {
      await subscriber.handle(event, db);
    }
  }
}
