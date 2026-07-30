import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type ClaimResult,
  dispatchWithIdempotency,
  type IdempotencyDeps,
  IN_FLIGHT_CLAIM_TTL_MS,
  type IdempotencyStore,
  idempotencyKeyOf,
} from "./idempotency_dispatch.ts";
import type { AppConfig } from "./config.ts";

const CONFIG = {} as AppConfig;

/** One row of the fake `request_idempotency` table. */
interface FakeRow {
  status: number | null;
  payload: unknown; // null while in-flight (mirrors NULL response_payload)
  method: string;
  path: string;
  createdAt: number; // FakeStore.now captured at claim / re-claim
}

/**
 * In-memory store faithfully mirroring `request_idempotency` semantics:
 * `INSERT … ON CONFLICT DO NOTHING`, NULL-payload in-flight rows, the persisted
 * `(method, path)` identity (ICA-D1), and a re-claimable staleness window keyed
 * off `IN_FLIGHT_CLAIM_TTL_MS` (ICA-A4). A controllable static `now` lets a test
 * cross the staleness window without waiting.
 */
class FakeStore implements IdempotencyStore {
  // Shared across instances so a "retry" with the same key sees the same row.
  static rows = new Map<string, FakeRow>();
  // Controllable clock (ms). Tests advance it to cross IN_FLIGHT_CLAIM_TTL_MS.
  static now = 0;
  claims = 0;
  stores = 0;
  releases = 0;
  reclaims = 0;

  constructor(
    private key: string,
    private opts: { failStore?: boolean } = {},
  ) {}

  claim(method: string, path: string): Promise<ClaimResult> {
    this.claims++;
    const existing = FakeStore.rows.get(this.key);
    if (existing === undefined) {
      FakeStore.rows.set(this.key, {
        status: null,
        payload: null,
        method,
        path,
        createdAt: FakeStore.now,
      });
      return Promise.resolve({ claimed: true, priorStatus: null, priorPayload: null });
    }
    // ICA-D1: same key first used for a DIFFERENT endpoint → reject.
    if (existing.method !== method || existing.path !== path) {
      return Promise.resolve({
        claimed: false,
        priorStatus: null,
        priorPayload: null,
        mismatch: true,
      });
    }
    // Completed prior response → replay.
    if (existing.payload != null) {
      return Promise.resolve({
        claimed: false,
        priorStatus: existing.status,
        priorPayload: existing.payload as Record<string, unknown> | null,
      });
    }
    // ICA-A4: in-flight NULL-payload row abandoned past the staleness window →
    // re-claim it (CAS on created_at) so a crashed claim self-heals on retry.
    if (FakeStore.now - existing.createdAt >= IN_FLIGHT_CLAIM_TTL_MS) {
      existing.createdAt = FakeStore.now;
      this.reclaims++;
      return Promise.resolve({ claimed: true, priorStatus: null, priorPayload: null });
    }
    // Genuinely in-flight (NULL payload, not stale) → transient conflict.
    return Promise.resolve({ claimed: false, priorStatus: null, priorPayload: null });
  }

  store(status: number, payload: unknown): Promise<void> {
    this.stores++;
    if (this.opts.failStore) {
      // ICA-A4: simulate a store() failure AFTER the write already committed (or
      // a process crash before store() runs): the row is left in-flight (NULL).
      return Promise.reject(new Error("store failed after committed write"));
    }
    const row = FakeStore.rows.get(this.key);
    if (row) {
      row.status = status;
      row.payload = payload;
    }
    return Promise.resolve();
  }

  release(): Promise<void> {
    this.releases++;
    const row = FakeStore.rows.get(this.key);
    if (row && row.payload == null) FakeStore.rows.delete(this.key);
    return Promise.resolve();
  }
}

function depsFor(
  stores: FakeStore[],
  opts: { failStore?: boolean } = {},
): IdempotencyDeps {
  return {
    resolveScope: () =>
      Promise.resolve({
        organizationId: "org-1",
        schoolId: "school-1",
        // deno-lint-ignore no-explicit-any
        claims: {} as any,
      }),
    makeStore: (_c, _s, key) => {
      const store = new FakeStore(key, opts);
      stores.push(store);
      return store;
    },
  };
}

function reqFor(method: string, path: string, key?: string): Request {
  return new Request(`https://api.test${path}`, {
    method,
    headers: key ? { "Idempotency-Key": key } : {},
    body: JSON.stringify({ classId: "8A" }),
  });
}

function postReq(key?: string): Request {
  return reqFor("POST", "/teacher/attendance/submit", key);
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

Deno.test("ICA-A4: store() failure after a committed write never 500s and self-heals on a later retry", async () => {
  FakeStore.rows.clear();
  FakeStore.now = 1_000_000; // fixed base clock
  const stores: FakeStore[] = [];
  // A store whose store() rejects — models a crash / store failure AFTER the
  // write already committed, which under the old code left a poisoned NULL row.
  const deps = depsFor(stores, { failStore: true });
  let dispatched = 0;
  const run = () =>
    dispatchWithIdempotency(postReq("key-crash"), CONFIG, () => {
      dispatched++;
      return Promise.resolve(okResponse({ receiptId: "R1", n: dispatched }));
    }, deps);

  // First attempt: the write commits (dispatch → 201) but store() throws. The
  // wrapper must return the REAL 201, NOT a 500 for a succeeded write.
  const first = await run();
  assertEquals(first.status, 201, "committed write must not become a 500 when store() fails");
  assertEquals(dispatched, 1);
  const row = FakeStore.rows.get("key-crash");
  assertExists(row);
  assertEquals(row!.payload, null, "row left in-flight (NULL) — poisoned under the old code");

  // A retry WITHIN the staleness window still 409s — transient, and crucially
  // it does NOT re-run the write (no duplicate money write while possibly live).
  FakeStore.now = 1_000_000 + IN_FLIGHT_CLAIM_TTL_MS - 1;
  const early = await run();
  assertEquals(early.status, 409, "still in-flight → transient conflict, not a duplicate write");
  assertEquals(dispatched, 1, "no re-dispatch while the claim is fresh");

  // A retry AFTER the window re-claims the abandoned slot and re-dispatches,
  // recovering with the real 2xx (in production the route's money-safe backstop
  // makes this exactly-once). NOT a permanent 409, NOT a 500.
  FakeStore.now = 1_000_000 + IN_FLIGHT_CLAIM_TTL_MS + 1;
  const recovered = await run();
  assertEquals(recovered.status, 201, "stale claim re-dispatches → recovers (no permanent 409 / 500)");
  assertEquals(dispatched, 2, "re-dispatched exactly once");
  assertEquals(stores.at(-1)!.reclaims, 1, "the stale slot was re-claimed, not treated as a fresh insert");
});

Deno.test("ICA-D1: same Idempotency-Key on a different method/path is rejected, not a wrong-response replay", async () => {
  FakeStore.rows.clear();
  FakeStore.now = 2_000_000;
  const stores: FakeStore[] = [];
  const deps = depsFor(stores);

  // First use of the key: POST /teacher/attendance/submit → completes + stores.
  const first = await dispatchWithIdempotency(
    reqFor("POST", "/teacher/attendance/submit", "key-reuse"),
    CONFIG,
    () => Promise.resolve(okResponse({ what: "attendance" })),
    deps,
  );
  assertEquals(first.status, 201);

  // Reuse the SAME key on a DIFFERENT endpoint (a money write). Replaying the
  // attendance response here would be a wrong-response replay that could mask a
  // real payment — the wrapper must reject with a clear reuse error instead.
  let dispatched = 0;
  const reused = await dispatchWithIdempotency(
    reqFor("POST", "/finance/payments", "key-reuse"),
    CONFIG,
    () => {
      dispatched++;
      return Promise.resolve(okResponse({ what: "payment" }));
    },
    deps,
  );
  assertEquals(reused.status, 422);
  const body = await reused.json();
  assertEquals(body.error.code, "IDEMPOTENCY_KEY_REUSED");
  assertEquals(dispatched, 0, "different endpoint must not run and must not replay the wrong response");
});

Deno.test("ICA-D1: SAME method/path replay of the same key still returns the stored response (happy path intact)", async () => {
  FakeStore.rows.clear();
  FakeStore.now = 3_000_000;
  const stores: FakeStore[] = [];
  const deps = depsFor(stores);
  let dispatched = 0;
  const run = () =>
    dispatchWithIdempotency(
      reqFor("POST", "/finance/payments", "key-same"),
      CONFIG,
      () => {
        dispatched++;
        return Promise.resolve(okResponse({ receiptId: "RCPT-1", n: dispatched }));
      },
      deps,
    );

  const first = await run();
  assertEquals(first.status, 201);
  assertEquals(dispatched, 1);

  const replay = await run();
  assertEquals(dispatched, 1, "same-request retry must NOT re-run the write");
  assertEquals(replay.status, 201);
  const body = await replay.json();
  assertEquals(body.data.receiptId, "RCPT-1");
  assertEquals(body.data.n, 1, "replays the stored response, not a fresh write");
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
