# Domain Events Architecture (ICA-G1)

Status: implemented on `integration/w0-canonical`.
Scope: the internal `domain_events` outbox, its drain worker, and the in-process
subscriber seam.

## Owner decision (G1, verbatim)

> "Keep the current internal domain event log as the canonical implementation.
> Design the interfaces so they remain future-compatible with an external event
> bus, but do NOT introduce Kafka, NATS, RabbitMQ, or any other external
> messaging infrastructure at this stage."

Accordingly:

- The `domain_events` table **is** the canonical event log. It is a
  transactional outbox: producers write an event in the same DB transaction as
  the business mutation, so an event is never lost or emitted for a rolled-back
  change.
- There is an in-process **subscriber seam** whose interface is deliberately
  bus-shaped, so an external bus can slot behind it later as a drop-in.
- **No external messaging infrastructure and no messaging library are added.**
  The registry module imports only the tenant DB type. Dispatch is a plain
  in-process function call driven by the drain worker.

## The defect this closes

Before ICA-G1, `publishPendingDomainEvents` selected pending rows and the sole
action per event was `UPDATE domain_events SET status='published'` — **nothing
ran between the SELECT and the UPDATE.** "Published" meant only "row flipped",
not "delivered": the table had full outbox shape but no consumer of the
`published` transition. (The AI Signal Refinery is **not** that consumer — see
below.) The seam makes the drain actually dispatch, and makes the meaning of
"published" honest.

## Components

### Producers — `_shared/audit/audit_repository.ts`
`enqueueDomainEvent()` (via `recordMutationAudit`) is the single writer. It
inserts with `idempotency_key` dedup. Note it currently inserts already-terminal
(`status='published'`) rows for the mutation-audit path; the drain worker below
governs any event inserted as `pending` (the outbox path the seam is built for).

### The log — `domain_events` table
`migrations/20260614500000_audit_ingestion_domain_events.sql` (base shape,
`status IN ('pending','published','failed')`, RLS FORCE, org/school tenancy) plus
`migrations/20260614930000_production_hardening.sql` (adds `attempt_count`,
`next_retry_at`, `last_error` and a retry index) — the retry/outbox columns.

### The drain worker — `_shared/audit/domain_events_worker.ts`
`publishPendingDomainEvents(db, orgId, limit)` selects `pending`/`failed` rows
whose `next_retry_at` is due, ordered by `created_at`, under the caller's tenant
RLS scope. For each row it now:

1. Builds a self-contained `DomainEvent`.
2. **Dispatches** it to every registered subscriber whose `eventTypes` match
   (`dispatchDomainEvent`).
3. Marks the row `published` **only after** all matching subscribers succeed.

On any throw (a subscriber, or the terminal UPDATE) the existing retry path runs:
`attempt_count++`; below `MAX_ATTEMPTS` (5) → back to `pending` with exponential
backoff `next_retry_at`; at the cap → `failed`. A throw for one event does not
abort the loop — each row is isolated in its own try/catch.

### The subscriber seam — `_shared/audit/domain_event_subscribers.ts` (new)

```ts
export interface DomainEventSubscriber {
  name: string;                       // consumer-group name in a future bus
  eventTypes: string[] | "*";         // topic/subscription filter
  handle(event: DomainEvent, db: TenantQueryClient): Promise<void>; // callback
}
```

- `registerDomainEventSubscriber(sub)` — register (rejects duplicate `name` to
  prevent double-invocation).
- `getDomainEventSubscribers()` — read-only snapshot.
- `clearDomainEventSubscribers()` — test isolation.
- `dispatchDomainEvent(event, db)` — the loop the worker calls; the ONE piece an
  external-bus migration replaces.

`DomainEvent` carries every business field (`id`, `organizationId`, `schoolId`,
`eventType`, `payload`, `correlationId`, `sourceModule`, `createdAt`) so a future
bus adapter can reconstruct it from a serialized message with no subscriber
change. `db` is an in-process convenience; a subscriber needing none may declare
`handle(event)` and still satisfy the type.

## Delivery semantics — at-least-once

- The drain publishes a row **only after** all matching subscribers succeed.
- If any matching subscriber throws, the event is **not** marked published; it is
  redelivered to **every** matching subscriber on the next drain.
- Therefore **subscribers MUST be idempotent**: on redelivery, a subscriber that
  already succeeded for an event will be called again.
- Ordering is best-effort `created_at` within a drain batch; there is no
  cross-batch ordering guarantee.

## Why the AI Signal Refinery is NOT registered (no double-invocation)

The Signal Refinery (`_shared/ai/signal_refinery.ts`) is **not** a consumer of
the `published` status. It reads `domain_events` by a **per-school `created_at`
watermark** (regardless of status), under **school** RLS scope, and is invoked
**directly** — once per affected school — in `handleProcessDomainEvents` **after**
the drain commits, each in its own school-scoped transaction with SAVEPOINT
isolation.

Registering it as an in-process subscriber would:
1. **Double-fire** it (already invoked directly post-drain), and
2. break its scoping model (the drain loop is org-scoped; the Refinery requires
   school scope) and its watermark/savepoint design.

So it is genuinely a direct invocation and is **left unregistered**. The registry
therefore has **zero subscribers today** — by design — and the worker still
drains the queue so the table stays bounded. With zero subscribers, "published"
honestly means **"dispatched to all registered subscribers (none configured), i.e.
durably logged."**

## How to add an in-process subscriber

```ts
import { registerDomainEventSubscriber } from "../audit/domain_event_subscribers.ts";

registerDomainEventSubscriber({
  name: "my-consumer",
  eventTypes: ["fees.payment.recorded", "fees.refund.issued"], // or "*"
  async handle(event, db) {
    // Idempotent work. A throw => event redelivered next drain.
  },
});
```

Register once at module/boot init on a code path the edge function imports. Keep
`handle` idempotent and reasonably fast (it runs inside the drain).

## How an external bus slots in later (future-compat)

The seam is the migration boundary. To adopt Kafka/NATS/RabbitMQ later, replace
**only** `dispatchDomainEvent` — publish each drained event to the bus (`name` →
consumer group, `eventTypes` → topics/filters) instead of calling handlers
in-process. Subscriber implementations, the `DomainEvent` shape, the outbox
table, the retry/at-least-once contract, and producers all stay unchanged. No
subscriber has to know whether delivery was in-process or over a bus.
