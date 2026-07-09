// Gap-sweep 2 · Step 4 (#2) — inventory replacement workflow repo coverage
// (DB-free stateful fake, mirroring inventory_stock_repository_test.ts).
//
// Proves the state machine built on top of `inv_student_distributions`
// (reused, not a parallel table):
//   • requestReplacement (existing handler, now extended) opens the workflow
//     in `pending` and stamps `replacement_requested_at`.
//   • listReplacementRequests only surfaces rows with a replacement sub-state,
//     and can filter by it.
//   • approve: pending -> approved; wrong starting state is rejected.
//   • fulfill: approved -> fulfilled, issues a NEW distribution row linked via
//     replacement_of_id (reusing createDistribution's stock-decrement path),
//     and flips the original row's overall `status` to `reissued`.
//   • reject: pending|approved -> rejected, with a reason recorded; wrong
//     starting state (e.g. already fulfilled) is rejected.
//   • unknown id -> ReplacementRequestNotFoundError on every action.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  approveReplacementRequest,
  createDistribution,
  DistributionUpdateBlockedError,
  fulfillReplacementRequest,
  listReplacementRequests,
  rejectReplacementRequest,
  ReplacementRequestInvalidStateError,
  ReplacementRequestNotFoundError,
  requestReplacement,
} from "./inventory_distribution_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000001";

interface CatalogRow {
  id: string;
  name: string;
  category: string;
  unit_price: number;
  stock_on_hand: number;
}

interface DistRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  catalog_item_id: string;
  quantity: number;
  status: string;
  distributed_at: string | null;
  acknowledged_at: string | null;
  payment_request_id: string | null;
  replacement_of_id: string | null;
  notes: string | null;
  created_by: string | null;
  created_at: string;
  replacement_status: string | null;
  replacement_requested_at: string | null;
  replacement_resolved_at: string | null;
  replacement_rejection_reason: string | null;
}

interface PaymentRequestRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  payer_user_id: string;
  source_type: string;
  source_id: string;
  invoice_id: string | null;
  amount: number;
  currency: string;
  status: string;
  idempotency_key: string | null;
}

/** Stateful in-memory model of the tables this workflow touches. */
class FakeDistributionDb {
  catalog = new Map<string, CatalogRow>();
  distributions = new Map<string, DistRow>();
  /// Gap-remediation P0-3: models `payment_requests` so the paid-item branch
  /// of `requestReplacement` (unit_price > 0) can be exercised here too.
  paymentRequests = new Map<string, PaymentRequestRow>();
  /// Gap-remediation P0-3: simulates the exact bug this file proves is fixed —
  /// an RLS policy silently filtering the replacement-status UPDATE to 0 rows
  /// (pre-fix: any parent-scope session, since only a school-scope write
  /// policy existed). When true, every `replacement_status`-mutating UPDATE
  /// below returns `[]` instead of the updated row.
  simulateBlockedUpdate = false;
  private seq = 0;

  private nextId(prefix: string): string {
    this.seq += 1;
    return `${prefix}-${this.seq}`;
  }

  private withCatalog(row: DistRow): DistRow & { itemName: string; category: string } {
    const cat = this.catalog.get(row.catalog_item_id)!;
    return { ...row, itemName: cat.name, category: cat.category };
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, params: unknown[] = []): Promise<T[]> {
    const q = sql.replace(/\s+/g, " ").trim();

    if (
      this.simulateBlockedUpdate &&
      ((q.startsWith("UPDATE inv_student_distributions") && q.includes("payment_request_id = $2")) ||
        q.includes("SET replacement_status = 'approved'") ||
        q.includes("SET replacement_status = 'rejected'") ||
        q.includes("SET replacement_status = 'fulfilled'"))
    ) {
      return [];
    }

    if (q.startsWith("SELECT * FROM payment_requests")) {
      const [organizationId, sourceType, sourceId, payerUserId] = params as [string, string, string, string];
      const existing = [...this.paymentRequests.values()].find((p) =>
        p.organization_id === organizationId &&
        p.source_type === sourceType &&
        p.source_id === sourceId &&
        p.payer_user_id === payerUserId
      );
      return existing ? [existing as unknown as T] : [];
    }

    if (q.startsWith("INSERT INTO payment_requests")) {
      const [
        organizationId,
        schoolId,
        studentId,
        payerUserId,
        sourceType,
        sourceId,
        invoiceId,
        amount,
        idempotencyKey,
      ] = params as [string, string, string, string, string, string, string | null, number, string | null];
      const row: PaymentRequestRow = {
        id: this.nextId("pay"),
        organization_id: organizationId,
        school_id: schoolId,
        student_id: studentId,
        payer_user_id: payerUserId,
        source_type: sourceType,
        source_id: sourceId,
        invoice_id: invoiceId,
        amount,
        currency: "INR",
        status: "pending",
        idempotency_key: idempotencyKey,
      };
      this.paymentRequests.set(row.id, row);
      return [row as unknown as T];
    }

    if (q.startsWith("INSERT INTO inv_student_distributions")) {
      const [organizationId, schoolId, studentId, catalogItemId, quantity, createdBy, replacementOfId] =
        params as [string, string, string, string, number, string | null, string | null];
      const row: DistRow = {
        id: this.nextId("dist"),
        organization_id: organizationId,
        school_id: schoolId,
        student_id: studentId,
        catalog_item_id: catalogItemId,
        quantity,
        status: "available",
        distributed_at: null,
        acknowledged_at: null,
        payment_request_id: null,
        replacement_of_id: replacementOfId,
        notes: null,
        created_by: createdBy,
        created_at: new Date().toISOString(),
        replacement_status: null,
        replacement_requested_at: null,
        replacement_resolved_at: null,
        replacement_rejection_reason: null,
      };
      this.distributions.set(row.id, row);
      return [row as unknown as T];
    }

    if (q.startsWith("UPDATE inv_catalog_items") && q.includes("stock_on_hand = greatest")) {
      const [quantity, catalogItemId] = params as [number, string];
      const cat = this.catalog.get(catalogItemId);
      if (cat) cat.stock_on_hand = Math.max(0, cat.stock_on_hand - quantity);
      return [];
    }

    if (q.startsWith("SELECT d.*, c.unit_price")) {
      const [distributionId] = params as [string];
      const row = this.distributions.get(distributionId);
      if (!row) return [];
      const cat = this.catalog.get(row.catalog_item_id)!;
      return [{ ...row, unit_price: cat.unit_price } as unknown as T];
    }

    if (q.startsWith("UPDATE inv_student_distributions") && q.includes("payment_request_id = $2")) {
      const [status, paymentRequestId, notes, distributionId] =
        params as [string, string | null, string | null, string];
      const row = this.distributions.get(distributionId);
      if (!row) return [];
      row.status = status;
      row.payment_request_id = paymentRequestId;
      if (notes != null) row.notes = notes;
      row.replacement_status = "pending";
      row.replacement_requested_at = new Date().toISOString();
      return [row as unknown as T];
    }

    if (q.startsWith("SELECT d.*, c.name")) {
      const statusFilter = q.includes("d.replacement_status = $1") ? (params[0] as string) : undefined;
      const rows = [...this.distributions.values()]
        .filter((r) => r.replacement_status != null)
        .filter((r) => !statusFilter || r.replacement_status === statusFilter)
        .sort((a, b) => (b.replacement_requested_at ?? "").localeCompare(a.replacement_requested_at ?? ""))
        .map((r) => this.withCatalog(r));
      return rows as unknown as T[];
    }

    if (q.startsWith("SELECT * FROM inv_student_distributions WHERE id")) {
      const [requestId] = params as [string];
      const row = this.distributions.get(requestId);
      if (!row || row.replacement_status == null) return [];
      return [row as unknown as T];
    }

    if (q.includes("SET replacement_status = 'approved'")) {
      const [requestId] = params as [string];
      const row = this.distributions.get(requestId)!;
      row.replacement_status = "approved";
      return [this.withCatalog(row) as unknown as T];
    }

    if (q.includes("SET replacement_status = 'rejected'")) {
      const [requestId, reason] = params as [string, string | null];
      const row = this.distributions.get(requestId)!;
      row.replacement_status = "rejected";
      row.replacement_resolved_at = new Date().toISOString();
      row.replacement_rejection_reason = reason;
      return [this.withCatalog(row) as unknown as T];
    }

    if (q.includes("SET replacement_status = 'fulfilled'")) {
      const [requestId] = params as [string];
      const row = this.distributions.get(requestId)!;
      row.replacement_status = "fulfilled";
      row.replacement_resolved_at = new Date().toISOString();
      row.status = "reissued";
      return [this.withCatalog(row) as unknown as T];
    }

    throw new Error(`FakeDistributionDb: unhandled query: ${q}`);
  }
}

function makeDb(): { fake: FakeDistributionDb; db: TenantQueryClient } {
  const fake = new FakeDistributionDb();
  fake.catalog.set("cat-1", {
    id: "cat-1",
    name: "Mathematics Textbook Grade 8",
    category: "books",
    unit_price: 0, // free-reissue item — keeps the fake payment-free
    stock_on_hand: 50,
  });
  return { fake, db: fake as unknown as TenantQueryClient };
}

async function seedDistribution(db: TenantQueryClient): Promise<string> {
  const created = await createDistribution(db, ORG, SCHOOL, {
    studentId: STUDENT,
    catalogItemId: "cat-1",
    quantity: 1,
    createdBy: STAFF,
  });
  return created.id;
}

Deno.test("gap-sweep-2/step-4: requestReplacement opens the workflow pending", async () => {
  const { fake, db } = makeDb();
  const distributionId = await seedDistribution(db);

  const result = await requestReplacement(db, ORG, SCHOOL, distributionId, STAFF, "Torn cover");

  assertEquals(result.distribution.status, "replacement_requested");
  assertEquals(result.paymentRequestId, null);
  const stored = fake.distributions.get(distributionId)!;
  assertEquals(stored.replacement_status, "pending");
  assertEquals(typeof stored.replacement_requested_at, "string");
});

Deno.test("gap-sweep-2/step-4: listReplacementRequests only surfaces rows with a sub-state, filterable", async () => {
  const { db } = makeDb();
  const untouched = await seedDistribution(db);
  const requested = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, requested, STAFF);

  const all = await listReplacementRequests(db);
  assertEquals(all.length, 1);
  assertEquals(all[0]!.id, requested);
  assertEquals(all[0]!.itemName, "Mathematics Textbook Grade 8");

  const pendingOnly = await listReplacementRequests(db, "pending");
  assertEquals(pendingOnly.length, 1);

  const approvedOnly = await listReplacementRequests(db, "approved");
  assertEquals(approvedOnly.length, 0);

  // Sanity: the untouched distribution never shows up regardless of filter.
  assertEquals(all.every((r) => r.id !== untouched), true);
});

Deno.test("gap-sweep-2/step-4: approve moves pending -> approved", async () => {
  const { db } = makeDb();
  const distributionId = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, distributionId, STAFF);

  const approved = await approveReplacementRequest(db, distributionId);

  assertEquals(approved.replacement_status, "approved");
});

Deno.test("gap-sweep-2/step-4: approve rejects a request that isn't pending", async () => {
  const { db } = makeDb();
  const distributionId = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, distributionId, STAFF);
  await approveReplacementRequest(db, distributionId);

  await assertRejects(
    () => approveReplacementRequest(db, distributionId),
    ReplacementRequestInvalidStateError,
  );
});

Deno.test("gap-sweep-2/step-4: approve on an unknown id throws not-found", async () => {
  const { db } = makeDb();
  await assertRejects(
    () => approveReplacementRequest(db, "does-not-exist"),
    ReplacementRequestNotFoundError,
  );
});

Deno.test("gap-sweep-2/step-4: fulfill issues a new linked distribution and flips the original to reissued", async () => {
  const { fake, db } = makeDb();
  const distributionId = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, distributionId, STAFF);
  await approveReplacementRequest(db, distributionId);

  const before = fake.distributions.size;
  const fulfilled = await fulfillReplacementRequest(db, ORG, SCHOOL, distributionId, STAFF);

  assertEquals(fulfilled.replacement_status, "fulfilled");
  assertEquals(fulfilled.status, "reissued");
  assertEquals(typeof fulfilled.replacement_resolved_at, "string");
  assertEquals(fake.distributions.size, before + 1, "fulfill must issue a brand-new distribution row");

  const reissued = [...fake.distributions.values()].find((r) => r.replacement_of_id === distributionId);
  assertEquals(reissued !== undefined, true);
  assertEquals(reissued!.student_id, STUDENT);
  assertEquals(reissued!.status, "available");
});

Deno.test("gap-sweep-2/step-4: fulfill rejects a request that isn't approved", async () => {
  const { db } = makeDb();
  const distributionId = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, distributionId, STAFF);

  await assertRejects(
    () => fulfillReplacementRequest(db, ORG, SCHOOL, distributionId, STAFF),
    ReplacementRequestInvalidStateError,
  );
});

Deno.test("gap-sweep-2/step-4: reject works from pending and from approved", async () => {
  const { db } = makeDb();

  const pendingId = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, pendingId, STAFF);
  const rejectedFromPending = await rejectReplacementRequest(db, pendingId, "Not eligible");
  assertEquals(rejectedFromPending.replacement_status, "rejected");
  assertEquals(rejectedFromPending.replacement_rejection_reason, "Not eligible");

  const approvedId = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, approvedId, STAFF);
  await approveReplacementRequest(db, approvedId);
  const rejectedFromApproved = await rejectReplacementRequest(db, approvedId);
  assertEquals(rejectedFromApproved.replacement_status, "rejected");
});

Deno.test("gap-sweep-2/step-4: reject rejects a request that's already fulfilled", async () => {
  const { db } = makeDb();
  const distributionId = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, distributionId, STAFF);
  await approveReplacementRequest(db, distributionId);
  await fulfillReplacementRequest(db, ORG, SCHOOL, distributionId, STAFF);

  await assertRejects(
    () => rejectReplacementRequest(db, distributionId),
    ReplacementRequestInvalidStateError,
  );
});

// ─── Gap-remediation P0-3 — RLS-blocked UPDATE must never be swallowed ─────
//
// `requestReplacement` is reachable by a parent-scope session (see
// inventory_distribution_handlers.ts `handleRequestReplacement`'s explicit
// `scope !== "parent"` bypass of the staff write-permission gate), which
// commits a `payment_request` (paid items) THEN updates the distribution's
// status/replacement_status. Pre-fix, if the latter UPDATE's RLS predicate
// excluded every row (0 rows, no Postgres error), `updated[0]!` returned
// `undefined` with no signal — the payment could commit while the
// distribution's own state never moved. These tests prove: (1) the paid,
// unblocked path still keeps payment + status consistent, and (2) a blocked
// UPDATE now throws instead of silently succeeding, for every mutating
// replacement-workflow call (request/approve/reject/fulfill).

Deno.test("gap-remediation/P0-3: requestReplacement (paid item, unblocked) keeps the payment_request and the status flip consistent", async () => {
  const { fake, db } = makeDb();
  fake.catalog.set("cat-paid", {
    id: "cat-paid",
    name: "School Blazer",
    category: "uniforms",
    unit_price: 500,
    stock_on_hand: 10,
  });
  const created = await createDistribution(db, ORG, SCHOOL, {
    studentId: STUDENT,
    catalogItemId: "cat-paid",
    quantity: 1,
    createdBy: STAFF,
  });

  const result = await requestReplacement(db, ORG, SCHOOL, created.id, STAFF, "Blazer torn");

  assertEquals(result.distribution.status, "payment_pending");
  assertEquals(result.paymentRequestId !== null, true);
  assertEquals(fake.paymentRequests.size, 1);
  const stored = fake.distributions.get(created.id)!;
  assertEquals(stored.replacement_status, "pending");
  assertEquals(stored.payment_request_id, result.paymentRequestId);
});

Deno.test("gap-remediation/P0-3: requestReplacement throws DistributionUpdateBlockedError (never a fabricated success) when the status UPDATE is RLS-blocked", async () => {
  const { fake, db } = makeDb();
  fake.catalog.set("cat-paid", {
    id: "cat-paid",
    name: "School Blazer",
    category: "uniforms",
    unit_price: 500,
    stock_on_hand: 10,
  });
  const created = await createDistribution(db, ORG, SCHOOL, {
    studentId: STUDENT,
    catalogItemId: "cat-paid",
    quantity: 1,
    createdBy: STAFF,
  });

  // Simulates the bug this ticket fixes: a parent-scope session reaches
  // requestReplacement(), but (pre-fix) no RLS policy permitted the status
  // UPDATE under scope='parent' — Postgres silently returns 0 rows.
  fake.simulateBlockedUpdate = true;

  await assertRejects(
    () => requestReplacement(db, ORG, SCHOOL, created.id, STAFF, "Blazer torn"),
    DistributionUpdateBlockedError,
  );

  // The payment_request was already inserted by this point in a real
  // Postgres transaction, `withTenantContext` (tenant_db.ts) wraps every
  // repository call in BEGIN/COMMIT-or-ROLLBACK, so throwing here rolls that
  // insert back too — the fix this proves is that the repository now
  // SIGNALS the failure instead of returning `{ distribution: undefined }`.
  assertEquals(fake.paymentRequests.size, 1);

  // And the distribution row itself was never mutated into a false
  // "payment_pending"/"replacement_status=pending" state.
  const stored = fake.distributions.get(created.id)!;
  assertEquals(stored.status, "available");
  assertEquals(stored.replacement_status, null);
});

Deno.test("gap-remediation/P0-3: approve throws DistributionUpdateBlockedError instead of returning rows[0]! === undefined", async () => {
  const { fake, db } = makeDb();
  const pendingId = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, pendingId, STAFF);

  fake.simulateBlockedUpdate = true;
  await assertRejects(
    () => approveReplacementRequest(db, pendingId),
    DistributionUpdateBlockedError,
  );
  // The blocked UPDATE must not have mutated the row either.
  assertEquals(fake.distributions.get(pendingId)!.replacement_status, "pending");
});

Deno.test("gap-remediation/P0-3: reject throws DistributionUpdateBlockedError instead of returning rows[0]! === undefined", async () => {
  const { fake, db } = makeDb();
  const pendingId = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, pendingId, STAFF);

  fake.simulateBlockedUpdate = true;
  await assertRejects(
    () => rejectReplacementRequest(db, pendingId, "Not eligible"),
    DistributionUpdateBlockedError,
  );
  assertEquals(fake.distributions.get(pendingId)!.replacement_status, "pending");
});

Deno.test("gap-remediation/P0-3: fulfill throws DistributionUpdateBlockedError instead of returning rows[0]! === undefined (and still issued the new item)", async () => {
  const { fake, db } = makeDb();
  const approvedId = await seedDistribution(db);
  await requestReplacement(db, ORG, SCHOOL, approvedId, STAFF);
  await approveReplacementRequest(db, approvedId);

  const before = fake.distributions.size;
  fake.simulateBlockedUpdate = true;
  await assertRejects(
    () => fulfillReplacementRequest(db, ORG, SCHOOL, approvedId, STAFF),
    DistributionUpdateBlockedError,
  );
  // fulfillReplacementRequest issues the new distribution row (a plain
  // INSERT, self-protected by Postgres — WITH CHECK violations raise rather
  // than silently drop) BEFORE the final blocked UPDATE. In a real Postgres
  // transaction this insert rolls back together with everything else in the
  // same withTenantContext operation; the fake proves the repository layer
  // now signals the failure instead of returning a fabricated "fulfilled" row.
  assertEquals(fake.distributions.size, before + 1);
  assertEquals(fake.distributions.get(approvedId)!.replacement_status, "approved");
  // Still whatever requestReplacement() left it at — never flipped to
  // 'reissued' by the blocked fulfil UPDATE.
  assertEquals(fake.distributions.get(approvedId)!.status, "replacement_requested");
});
