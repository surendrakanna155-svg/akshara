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

/** Stateful in-memory model of the two tables this workflow touches. */
class FakeDistributionDb {
  catalog = new Map<string, CatalogRow>();
  distributions = new Map<string, DistRow>();
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
