import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type ClaimResult,
  dispatchWithIdempotency,
  type IdempotencyDeps,
  type IdempotencyStore,
  idempotencyKeyOf,
} from "./idempotency_dispatch.ts";
import type { AppConfig } from "./config.ts";

const CONFIG = {} as AppConfig;

/** In-memory store mirroring `request_idempotency` semantics. */
class FakeStore implements IdempotencyStore {
  // Shared across instances so a "retry" with the same key sees the same row.
  static rows = new Map<
    string,
    { status: number | null; payload: unknown }
  >();
  claims = 0;
  stores = 0;
  releases = 0;

  constructor(private key: string) {}

  claim(): Promise<ClaimResult> {
    this.claims++;
    const existing = FakeStore.rows.get(this.key);
    if (existing === undefined) {
      FakeStore.rows.set(this.key, { status: null, payload: null });
      return Promise.resolve({ claimed: true, priorStatus: null, priorPayload: null });
    }
    return Promise.resolve({
      claimed: false,
      priorStatus: existing.status,
      priorPayload: existing.payload as Record<string, unknown> | null,
    });
  }

  store(status: number, payload: unknown): Promise<void> {
    this.stores++;
    FakeStore.rows.set(this.key, { status, payload });
    return Promise.resolve();
  }

  release(): Promise<void> {
    this.releases++;
    const row = FakeStore.rows.get(this.key);
    if (row && row.payload == null) FakeStore.rows.delete(this.key);
    return Promise.resolve();
  }
}

function depsFor(stores: FakeStore[]): IdempotencyDeps {
  return {
    resolveScope: () =>
      Promise.resolve({
        organizationId: "org-1",
        schoolId: "school-1",
        // deno-lint-ignore no-explicit-any
        claims: {} as any,
      }),
    makeStore: (_c, _s, key) => {
      const store = new FakeStore(key);
      stores.push(store);
      return store;
    },
  };
}

function postReq(key?: string): Request {
  return new Request("https://api.test/teacher/attendance/submit", {
    method: "POST",
    headers: key ? { "Idempotency-Key": key } : {},
    body: JSON.stringify({ classId: "8A" }),
  });
}

function okResponse(body: Record<string, unknown>): Response {
  return new Response(JSON.stringify({ data: body, error: null }), {
    status: 201,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.test("no Idempotency-Key → wrapper is inert (dispatch runs, no claim)", async () => {
  FakeStore.rows.clear();
  const stores: FakeStore[] = [];
  let dispatched = 0;
  const res = await dispatchWithIdempotency(postReq(), CONFIG, () => {
    dispatched++;
    return Promise.resolve(okResponse({ ok: true }));
  }, depsFor(stores));
  assertEquals(dispatched, 1);
  assertEquals(stores.length, 0);
  assertEquals(res.status, 201);
});

Deno.test("first write claims + stores; retry replays exactly-once (no second dispatch)", async () => {
  FakeStore.rows.clear();
  const stores: FakeStore[] = [];
  const deps = depsFor(stores);
  let dispatched = 0;
  const run = () =>
    dispatchWithIdempotency(postReq("key-A"), CONFIG, () => {
      dispatched++;
      return Promise.resolve(okResponse({ submittedAt: "now", n: dispatched }));
    }, deps);

  const first = await run();
  assertEquals(first.status, 201);
  assertEquals(dispatched, 1, "first request runs the write");

  const replay = await run();
  assertEquals(dispatched, 1, "retry must NOT run the write again");
  assertEquals(replay.status, 201);
  const body = await replay.json();
  // Replays the stored response from the first call (n == 1), not a new write.
  assertEquals(body.data.n, 1);
});

Deno.test("concurrent in-flight duplicate → clean 409 IDEMPOTENCY_CONFLICT", async () => {
  FakeStore.rows.clear();
  const stores: FakeStore[] = [];
  const deps = depsFor(stores);

  // Simulate a duplicate arriving while the first is still in flight: the first
  // dispatch hasn't stored yet when the second claims.
  let resolveFirst!: () => void;
  const gate = new Promise<void>((r) => (resolveFirst = r));

  const first = dispatchWithIdempotency(postReq("key-B"), CONFIG, async () => {
    await gate; // hold the write open
    return okResponse({ ok: true });
  }, deps);

  // Second request claims while first is still running (row exists, payload null).
  const second = await dispatchWithIdempotency(
    postReq("key-B"),
    CONFIG,
    () => Promise.resolve(okResponse({ ok: "SHOULD_NOT_RUN" })),
    deps,
  );
  assertEquals(second.status, 409);
  const body = await second.json();
  assertEquals(body.error.code, "IDEMPOTENCY_CONFLICT");

  resolveFirst();
  const firstRes = await first;
  assertEquals(firstRes.status, 201);
});

Deno.test("non-2xx response releases the claim (key stays retryable)", async () => {
  FakeStore.rows.clear();
  const stores: FakeStore[] = [];
  const deps = depsFor(stores);

  const failed = await dispatchWithIdempotency(
    postReq("key-C"),
    CONFIG,
    () =>
      Promise.resolve(
        new Response(JSON.stringify({ data: null, error: { code: "SERVER_ERROR" } }), {
          status: 503,
        }),
      ),
    deps,
  );
  assertEquals(failed.status, 503);
  assertEquals(stores[0].releases, 1, "transient failure releases the claim");
  assertEquals(FakeStore.rows.has("key-C"), false, "claim row removed → retryable");

  // A subsequent retry can now succeed and claim cleanly.
  let dispatched = 0;
  const retry = await dispatchWithIdempotency(postReq("key-C"), CONFIG, () => {
    dispatched++;
    return Promise.resolve(okResponse({ ok: true }));
  }, deps);
  assertEquals(retry.status, 201);
  assertEquals(dispatched, 1);
});

Deno.test("a thrown dispatch releases the claim and rethrows", async () => {
  FakeStore.rows.clear();
  const stores: FakeStore[] = [];
  const deps = depsFor(stores);
  let threw = false;
  try {
    await dispatchWithIdempotency(postReq("key-D"), CONFIG, () => {
      throw new Error("boom");
    }, deps);
  } catch (_) {
    threw = true;
  }
  assertEquals(threw, true);
  assertEquals(stores[0].releases, 1);
  assertEquals(FakeStore.rows.has("key-D"), false);
});

Deno.test("idempotencyKeyOf reads either header casing", () => {
  assertExists(idempotencyKeyOf(postReq("k")));
  assertEquals(
    idempotencyKeyOf(
      new Request("https://api.test/x", {
        method: "POST",
        headers: { "idempotency-key": "lower" },
      }),
    ),
    "lower",
  );
  assertEquals(idempotencyKeyOf(postReq()), null);
});
