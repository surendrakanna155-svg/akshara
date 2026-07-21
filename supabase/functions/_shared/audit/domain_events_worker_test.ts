import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { publishPendingDomainEvents } from "./domain_events_worker.ts";
import {
  clearDomainEventSubscribers,
  type DomainEvent,
  registerDomainEventSubscriber,
} from "./domain_event_subscribers.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";

interface Row {
  id: string;
  organization_id: string;
  school_id: string | null;
  event_type: string;
  payload: Record<string, unknown>;
  correlation_id: string | null;
  source_module: string;
  created_at: string;
  status: "pending" | "published" | "failed";
  attempt_count: number;
  next_retry_at: string | null;
  last_error: string | null;
}

let idSeq = 0;

function seed(
  overrides: Partial<Row> & { event_type: string },
): Row {
  return {
    id: `evt-${++idSeq}`,
    organization_id: ORG,
    school_id: SCHOOL,
    payload: {},
    correlation_id: null,
    source_module: "test",
    created_at: `2026-07-21T00:00:0${idSeq}.000Z`,
    status: "pending",
    attempt_count: 0,
    next_retry_at: null,
    last_error: null,
    ...overrides,
  };
}

/** In-memory stand-in for the tenant DB implementing exactly the four SQL
 * shapes the worker issues (drain SELECT + the published / failed / pending
 * UPDATEs). */
class FakeDomainEventsDb {
  constructor(public rows: Row[]) {}

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT") && sql.includes("FROM domain_events")) {
      const orgId = args[0] as string;
      const limit = args[1] as number;
      const nowMs = Date.now();
      const matched = this.rows
        .filter((r) =>
          r.organization_id === orgId &&
          (r.status === "pending" || r.status === "failed") &&
          (r.next_retry_at === null || new Date(r.next_retry_at).getTime() <= nowMs)
        )
        .sort((a, b) => a.created_at.localeCompare(b.created_at))
        .slice(0, limit)
        .map((r) => ({
          id: r.id,
          attempt_count: r.attempt_count,
          school_id: r.school_id,
          event_type: r.event_type,
          payload: r.payload,
          correlation_id: r.correlation_id,
          source_module: r.source_module,
          created_at: r.created_at,
        }));
      return matched as T[];
    }

    if (sql.includes("UPDATE domain_events") && sql.includes("status = 'published'")) {
      const id = args[0] as string;
      const attempt = args[1] as number;
      const row = this.rows.find(
        (r) => r.id === id && (r.status === "pending" || r.status === "failed"),
      );
      if (row) {
        row.status = "published";
        row.attempt_count = attempt;
        row.next_retry_at = null;
        row.last_error = null;
      }
      return [] as T[];
    }

    if (sql.includes("UPDATE domain_events") && sql.includes("status = 'failed'")) {
      const id = args[0] as string;
      const row = this.rows.find((r) => r.id === id);
      if (row) {
        row.status = "failed";
        row.attempt_count = args[1] as number;
        row.last_error = args[2] as string;
      }
      return [] as T[];
    }

    if (sql.includes("UPDATE domain_events") && sql.includes("status = 'pending'")) {
      const id = args[0] as string;
      const mins = Number(args[3]);
      const row = this.rows.find((r) => r.id === id);
      if (row) {
        row.status = "pending";
        row.attempt_count = args[1] as number;
        row.last_error = args[2] as string;
        row.next_retry_at = new Date(Date.now() + mins * 60_000).toISOString();
      }
      return [] as T[];
    }

    return [] as T[];
  }
}

function asDb(rows: Row[]): { db: TenantQueryClient; rows: Row[] } {
  const fake = new FakeDomainEventsDb(rows);
  return { db: fake as unknown as TenantQueryClient, rows: fake.rows };
}

// (1) A registered subscriber receives a matching pending event, and the event
// is marked published only after the subscriber succeeds.
Deno.test("dispatches matching event to subscriber then publishes", async () => {
  clearDomainEventSubscribers();
  const received: DomainEvent[] = [];
  registerDomainEventSubscriber({
    name: "capture",
    eventTypes: ["fees.payment.recorded"],
    handle: (event) => {
      received.push(event);
      return Promise.resolve();
    },
  });
  try {
    const { db, rows } = asDb([
      seed({ event_type: "fees.payment.recorded", payload: { studentId: "s1" } }),
    ]);
    const result = await publishPendingDomainEvents(db, ORG);

    assertEquals(result.processed, 1);
    assertEquals(result.published, 1);
    assertEquals(result.failed, 0);
    assertEquals(received.length, 1);
    assertEquals(received[0].eventType, "fees.payment.recorded");
    assertEquals(received[0].payload, { studentId: "s1" });
    assertEquals(rows[0].status, "published");
  } finally {
    clearDomainEventSubscribers();
  }
});

// (2) A subscriber that THROWS leaves its event un-published (retryable) and
// does NOT block a different, unmatched event from draining.
Deno.test("throwing subscriber leaves event pending; other events still drain", async () => {
  clearDomainEventSubscribers();
  let calls = 0;
  registerDomainEventSubscriber({
    name: "boom",
    eventTypes: ["exams.result.published"],
    handle: () => {
      calls++;
      throw new Error("subscriber failure");
    },
  });
  try {
    const failing = seed({ event_type: "exams.result.published" });
    const unrelated = seed({ event_type: "library.book.issued" });
    const { db, rows } = asDb([failing, unrelated]);

    const result = await publishPendingDomainEvents(db, ORG);

    assertEquals(result.processed, 2);
    assertEquals(result.published, 1); // only the unmatched event published
    assertEquals(result.retried, 1); // the failing one scheduled for retry
    assertEquals(result.failed, 0);
    assertEquals(calls, 1);

    const failingRow = rows.find((r) => r.id === failing.id)!;
    const unrelatedRow = rows.find((r) => r.id === unrelated.id)!;
    assertEquals(failingRow.status, "pending"); // NOT falsely published
    assertEquals(failingRow.attempt_count, 1);
    assertEquals(failingRow.last_error, "subscriber failure");
    assertEquals(typeof failingRow.next_retry_at, "string"); // backoff scheduled
    assertEquals(unrelatedRow.status, "published");
  } finally {
    clearDomainEventSubscribers();
  }
});

// (3) Event-type filtering: a subscriber only receives its declared types.
Deno.test("event-type filtering delivers only matching types", async () => {
  clearDomainEventSubscribers();
  const feesSeen: string[] = [];
  const attendanceSeen: string[] = [];
  registerDomainEventSubscriber({
    name: "fees-only",
    eventTypes: ["fees.payment.recorded"],
    handle: (e) => {
      feesSeen.push(e.eventType);
      return Promise.resolve();
    },
  });
  registerDomainEventSubscriber({
    name: "attendance-only",
    eventTypes: ["attendance.marked"],
    handle: (e) => {
      attendanceSeen.push(e.eventType);
      return Promise.resolve();
    },
  });
  try {
    const { db, rows } = asDb([
      seed({ event_type: "fees.payment.recorded" }),
      seed({ event_type: "attendance.marked" }),
    ]);

    const result = await publishPendingDomainEvents(db, ORG);

    assertEquals(result.published, 2);
    assertEquals(feesSeen, ["fees.payment.recorded"]);
    assertEquals(attendanceSeen, ["attendance.marked"]);
    assertEquals(rows.every((r) => r.status === "published"), true);
  } finally {
    clearDomainEventSubscribers();
  }
});

// (4) With NO subscribers, events still drain to published (log-only semantics).
Deno.test("no subscribers: events still drain to published (log-only)", async () => {
  clearDomainEventSubscribers();
  const { db, rows } = asDb([
    seed({ event_type: "some.event.a" }),
    seed({ event_type: "some.event.b" }),
  ]);

  const result = await publishPendingDomainEvents(db, ORG);

  assertEquals(result.processed, 2);
  assertEquals(result.published, 2);
  assertEquals(result.failed, 0);
  assertEquals(result.retried, 0);
  assertEquals(rows.every((r) => r.status === "published"), true);
});
