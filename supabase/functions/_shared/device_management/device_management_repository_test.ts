import {
  assertEquals,
  assertInstanceOf,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ASSIGNABLE_FROM,
  assetRowToApi,
  assignDevice,
  assignmentRowToApi,
  DeviceConflictError,
  DeviceNotFoundError,
  DeviceStatusConflictError,
  DeviceValidationError,
  findDeviceById,
  getDeviceHistory,
  LOSABLE_FROM,
  listDevices,
  listDevicesByStaff,
  markDeviceLost,
  registerDevice,
  RETIRABLE_FROM,
  returnDevice,
  retireDevice,
} from "./device_management_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const OTHER_SCHOOL = "a2000000-0000-4000-8000-000000000002";
const SCOPE = { organizationId: ORG, schoolId: SCHOOL };
const OTHER_SCOPE = { organizationId: ORG, schoolId: OTHER_SCHOOL };
const STAFF_A = "staff-aaaa";
const STAFF_B = "staff-bbbb";

interface IAsset {
  id: string;
  organization_id: string;
  school_id: string;
  asset_tag: string;
  asset_type: string;
  serial_no: string | null;
  purchase_ref: string | null;
  purchase_cost: number;
  status: string;
  current_assignee: string | null;
  note: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

interface IAssignment {
  id: string;
  organization_id: string;
  school_id: string;
  asset_id: string;
  assigned_to: string;
  assigned_by: string | null;
  assigned_at: string;
  returned_at: string | null;
  condition: string | null;
  note: string | null;
  created_at: string;
}

/**
 * Faithful in-memory model of the EXACT SQL device_management_repository issues.
 * Every queryObject call runs its body SYNCHRONOUSLY before the promise resolves,
 * so a single call is atomic — this is what models the row lock that serializes
 * the guarded status UPDATE (WHERE status = ANY(<allowed-from>)), letting the
 * double-assign race be proven deterministically without a live Postgres.
 */
class DeviceMockDb {
  assets: IAsset[] = [];
  assignments: IAssignment[] = [];
  private clock = 0;

  private now(): string {
    // Monotonic, unique per call → deterministic ORDER BY created_at/updated_at.
    return new Date(Date.UTC(2026, 6, 20, 0, 0, this.clock++)).toISOString();
  }

  private projectAsset(r: IAsset): Record<string, unknown> {
    return {
      id: r.id,
      asset_tag: r.asset_tag,
      asset_type: r.asset_type,
      serial_no: r.serial_no,
      purchase_ref: r.purchase_ref,
      purchase_cost: r.purchase_cost.toFixed(2), // ::text of NUMERIC(12,2)
      status: r.status,
      current_assignee: r.current_assignee,
      note: r.note,
      created_by: r.created_by,
      created_at: r.created_at,
      updated_at: r.updated_at,
    };
  }

  private projectAssignment(r: IAssignment): Record<string, unknown> {
    return {
      id: r.id,
      asset_id: r.asset_id,
      assigned_to: r.assigned_to,
      assigned_by: r.assigned_by,
      assigned_at: r.assigned_at,
      returned_at: r.returned_at,
      condition: r.condition,
      note: r.note,
      created_at: r.created_at,
    };
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // ── INSERT org_assets (RETURNING) with UNIQUE tag/serial guards ──
    if (sql.includes("INSERT INTO org_assets")) {
      const [org, school, tag, type, serial, purchaseRef, cost, note, createdBy] = args as [
        string, string, string, string, string | null, string | null, number, string | null, string | null,
      ];
      if (
        this.assets.some((a) =>
          a.organization_id === org && a.school_id === school && a.asset_tag === tag
        )
      ) {
        throw new Error(`duplicate key value violates unique constraint "uq_org_assets_tag"`);
      }
      if (
        serial != null &&
        this.assets.some((a) =>
          a.organization_id === org && a.school_id === school && a.serial_no === serial
        )
      ) {
        throw new Error(`duplicate key value violates unique constraint "uq_org_assets_serial"`);
      }
      const ts = this.now();
      const row: IAsset = {
        id: crypto.randomUUID(),
        organization_id: org,
        school_id: school,
        asset_tag: tag,
        asset_type: type,
        serial_no: serial ?? null,
        purchase_ref: purchaseRef ?? null,
        purchase_cost: Number(cost),
        status: "in_stock",
        current_assignee: null,
        note: note ?? null,
        created_by: createdBy ?? null,
        created_at: ts,
        updated_at: ts,
      };
      this.assets.push(row);
      return [this.projectAsset(row)] as T[];
    }

    // ── Guarded org_assets status UPDATEs (throw-on-0-rows lives in the repo) ──
    if (sql.includes("UPDATE org_assets") && sql.includes("SET status = 'assigned'")) {
      const [org, school, id, assignee, allowedFrom] = args as [string, string, string, string, string[]];
      const row = this.assets.find((a) =>
        a.organization_id === org && a.school_id === school && a.id === id
      );
      if (!row || !allowedFrom.includes(row.status)) return [] as T[];
      row.status = "assigned";
      row.current_assignee = assignee;
      row.updated_at = this.now();
      return [this.projectAsset(row)] as T[];
    }
    if (sql.includes("UPDATE org_assets") && sql.includes("SET status = 'returned'")) {
      const [org, school, id] = args as [string, string, string];
      const row = this.assets.find((a) =>
        a.organization_id === org && a.school_id === school && a.id === id
      );
      if (!row || row.status !== "assigned") return [] as T[]; // AND status = 'assigned'
      row.status = "returned";
      row.current_assignee = null;
      row.updated_at = this.now();
      return [this.projectAsset(row)] as T[];
    }
    if (sql.includes("UPDATE org_assets") && sql.includes("SET status = 'retired'")) {
      const [org, school, id, allowedFrom] = args as [string, string, string, string[]];
      const row = this.assets.find((a) =>
        a.organization_id === org && a.school_id === school && a.id === id
      );
      if (!row || !allowedFrom.includes(row.status)) return [] as T[];
      row.status = "retired";
      row.updated_at = this.now();
      return [this.projectAsset(row)] as T[];
    }
    if (sql.includes("UPDATE org_assets") && sql.includes("SET status = 'lost'")) {
      const [org, school, id, allowedFrom] = args as [string, string, string, string[]];
      const row = this.assets.find((a) =>
        a.organization_id === org && a.school_id === school && a.id === id
      );
      if (!row || !allowedFrom.includes(row.status)) return [] as T[];
      row.status = "lost";
      row.current_assignee = null;
      row.updated_at = this.now();
      return [this.projectAsset(row)] as T[];
    }

    // ── INSERT device_assignments (a fresh custody episode) ──
    if (sql.includes("INSERT INTO device_assignments")) {
      const [org, school, assetId, assignedTo, assignedBy, note] = args as [
        string, string, string, string, string | null, string | null,
      ];
      const row: IAssignment = {
        id: crypto.randomUUID(),
        organization_id: org,
        school_id: school,
        asset_id: assetId,
        assigned_to: assignedTo,
        assigned_by: assignedBy ?? null,
        assigned_at: this.now(),
        returned_at: null,
        condition: null,
        note: note ?? null,
        created_at: this.now(),
      };
      this.assignments.push(row);
      return [this.projectAssignment(row)] as T[];
    }

    // ── Close the OPEN custody episode on return / loss (returned_at IS NULL) ──
    if (sql.includes("UPDATE device_assignments") && sql.includes("returned_at = timezone")) {
      const [org, school, assetId, cond, note] = args as [
        string, string, string, string | null, string | null,
      ];
      const open = this.assignments.find((a) =>
        a.organization_id === org && a.school_id === school &&
        a.asset_id === assetId && a.returned_at === null
      );
      if (!open) return [] as T[];
      open.returned_at = this.now();
      // return: condition = $4 ; lost: condition = COALESCE($4, 'lost')
      open.condition = sql.includes("'lost'") ? (cond ?? "lost") : (cond ?? null);
      if (note != null) open.note = note; // note = COALESCE($5, note)
      return [this.projectAssignment(open)] as T[];
    }

    // ── SELECT one asset by id ──
    if (sql.includes("FROM org_assets") && sql.includes("AND id = $3::uuid")) {
      const [org, school, id] = args as [string, string, string];
      const row = this.assets.find((a) =>
        a.organization_id === org && a.school_id === school && a.id === id
      );
      return row ? [this.projectAsset(row)] as T[] : [] as T[];
    }

    // ── SELECT assets currently held by a staff member ──
    if (
      sql.includes("FROM org_assets") &&
      sql.includes("status = 'assigned' AND current_assignee = $3")
    ) {
      const [org, school, staffId] = args as [string, string, string];
      const rows = this.assets.filter((a) =>
        a.organization_id === org && a.school_id === school &&
        a.status === "assigned" && a.current_assignee === staffId
      ).sort((x, y) => y.updated_at.localeCompare(x.updated_at));
      return rows.map((r) => this.projectAsset(r)) as T[];
    }

    // ── SELECT the asset register (filters appended positionally) ──
    if (sql.includes("FROM org_assets") && sql.includes("ORDER BY created_at DESC")) {
      const [org, school] = args as [string, string];
      let rows = this.assets.filter((a) => a.organization_id === org && a.school_id === school);
      let i = 2;
      if (sql.includes("AND status = $")) {
        const v = String(args[i++]);
        rows = rows.filter((r) => r.status === v);
      }
      if (sql.includes("AND asset_type = $")) {
        const v = String(args[i++]);
        rows = rows.filter((r) => r.asset_type === v);
      }
      if (sql.includes("AND current_assignee = $")) {
        const v = String(args[i++]);
        rows = rows.filter((r) => r.current_assignee === v);
      }
      rows = [...rows].sort((x, y) => y.created_at.localeCompare(x.created_at));
      return rows.map((r) => this.projectAsset(r)) as T[];
    }

    // ── SELECT the custody timeline for one asset ──
    if (sql.includes("FROM device_assignments") && sql.includes("ORDER BY assigned_at DESC")) {
      const [org, school, assetId] = args as [string, string, string];
      const rows = this.assignments
        .filter((a) =>
          a.organization_id === org && a.school_id === school && a.asset_id === assetId
        )
        .sort((x, y) => y.assigned_at.localeCompare(x.assigned_at));
      return rows.map((r) => this.projectAssignment(r)) as T[];
    }

    return [] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
}

function client(mock: DeviceMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

async function seedAsset(
  db: TenantQueryClient,
  overrides: Partial<{ assetTag: string; assetType: string; serialNo: string; cost: number }> = {},
) {
  return await registerDevice(db, SCOPE, {
    assetTag: overrides.assetTag ?? `LAP-${crypto.randomUUID().slice(0, 4)}`,
    assetType: overrides.assetType ?? "laptop",
    serialNo: overrides.serialNo ?? null,
    purchaseCost: overrides.cost ?? 45000,
  });
}

// ── Sanity: transition from-sets match the intended lifecycle ────────────────

Deno.test("transition from-sets model the lifecycle", () => {
  assertEquals(ASSIGNABLE_FROM, ["in_stock", "returned"]);
  assertEquals(RETIRABLE_FROM, ["in_stock", "returned"]);
  assertEquals(LOSABLE_FROM, ["in_stock", "returned", "assigned"]);
});

// ── registerDevice ───────────────────────────────────────────────────────────

Deno.test("registerDevice: lands in_stock with no assignee and stored fields", async () => {
  const db = client(new DeviceMockDb());
  const a = await registerDevice(db, SCOPE, {
    assetTag: "LAP-0007",
    assetType: "laptop",
    serialNo: "SN-123",
    purchaseRef: "PO-99",
    purchaseCost: 45000.5,
    note: "dell latitude",
    createdBy: "admin-1",
  });
  assertEquals(a.asset_tag, "LAP-0007");
  assertEquals(a.asset_type, "laptop");
  assertEquals(a.serial_no, "SN-123");
  assertEquals(a.purchase_ref, "PO-99");
  assertEquals(a.purchase_cost, "45000.50");
  assertEquals(a.status, "in_stock");
  assertEquals(a.current_assignee, null);
});

Deno.test("registerDevice: rejects missing tag/type and negative cost", async () => {
  const db = client(new DeviceMockDb());
  await assertRejects(() => registerDevice(db, SCOPE, { assetTag: "  ", assetType: "laptop" }), DeviceValidationError, "assetTag is required");
  await assertRejects(() => registerDevice(db, SCOPE, { assetTag: "T1", assetType: " " }), DeviceValidationError, "assetType is required");
  await assertRejects(() => registerDevice(db, SCOPE, { assetTag: "T1", assetType: "laptop", purchaseCost: -1 }), DeviceValidationError, "purchaseCost cannot be negative");
});

Deno.test("registerDevice: duplicate asset tag / serial -> DeviceConflictError", async () => {
  const db = client(new DeviceMockDb());
  await registerDevice(db, SCOPE, { assetTag: "DUP", assetType: "laptop", serialNo: "S-1" });
  await assertRejects(() => registerDevice(db, SCOPE, { assetTag: "DUP", assetType: "tablet" }), DeviceConflictError, "asset tag already exists");
  await assertRejects(() => registerDevice(db, SCOPE, { assetTag: "OTHER", assetType: "tablet", serialNo: "S-1" }), DeviceConflictError, "serial number already exists");
  // Two NULL serials never clash.
  await registerDevice(db, SCOPE, { assetTag: "N1", assetType: "laptop" });
  await registerDevice(db, SCOPE, { assetTag: "N2", assetType: "laptop" });
});

// ── assign / return / reassign — lifecycle & history preservation ────────────

Deno.test("assignDevice: in_stock -> assigned, opens a custody episode", async () => {
  const db = client(new DeviceMockDb());
  const a = await seedAsset(db, { assetTag: "A1" });
  const { asset, assignment } = await assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_A, assignedBy: "admin" });
  assertEquals(asset.status, "assigned");
  assertEquals(asset.current_assignee, STAFF_A);
  assertEquals(assignment.assigned_to, STAFF_A);
  assertEquals(assignment.returned_at, null); // open episode
  const history = await getDeviceHistory(db, SCOPE, a.id);
  assertEquals(history.length, 1);
});

Deno.test("assignDevice: assigning an already-assigned asset is rejected (409, guard=0 rows)", async () => {
  const db = client(new DeviceMockDb());
  const a = await seedAsset(db, { assetTag: "A2" });
  await assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_A });
  const err = await assertRejects(
    () => assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_B }),
    DeviceStatusConflictError,
    "currently 'assigned'",
  );
  assertEquals((err as DeviceStatusConflictError).currentStatus, "assigned");
  // The rejected assign did NOT create a second episode nor change the assignee.
  assertEquals((await getDeviceHistory(db, SCOPE, a.id)).length, 1);
  assertEquals((await findDeviceById(db, SCOPE, a.id))?.current_assignee, STAFF_A);
});

Deno.test("assignDevice: unknown asset id -> 404 not found", async () => {
  const db = client(new DeviceMockDb());
  await assertRejects(
    () => assignDevice(db, SCOPE, "ffffffff-0000-4000-8000-000000000000", { assignedTo: STAFF_A }),
    DeviceNotFoundError,
    "not found",
  );
});

Deno.test("returnDevice: assigned -> returned, CLOSES the episode without overwriting who-had-it", async () => {
  const db = client(new DeviceMockDb());
  const a = await seedAsset(db, { assetTag: "A3" });
  await assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_A });
  const { asset, assignment } = await returnDevice(db, SCOPE, a.id, { condition: "good", note: "ok" });
  assertEquals(asset.status, "returned");
  assertEquals(asset.current_assignee, null);
  assertEquals(assignment?.assigned_to, STAFF_A); // history NOT overwritten
  assertEquals(assignment?.condition, "good");
  assertEquals(typeof assignment?.returned_at, "string");
});

Deno.test("returnDevice: returning a non-assigned asset is rejected", async () => {
  const db = client(new DeviceMockDb());
  const a = await seedAsset(db, { assetTag: "A4" });
  await assertRejects(
    () => returnDevice(db, SCOPE, a.id),
    DeviceStatusConflictError,
    "currently 'in_stock'",
  );
});

Deno.test("LIFECYCLE assign->return->reassign preserves full custody history (2 distinct episodes)", async () => {
  const db = client(new DeviceMockDb());
  const a = await seedAsset(db, { assetTag: "LIFE-1" });

  // Episode 1: staff A takes it, returns it damaged.
  await assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_A, note: "term 1" });
  await returnDevice(db, SCOPE, a.id, { condition: "damaged", note: "cracked hinge" });

  // Episode 2: reassign the SAME asset to staff B.
  const reassigned = await assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_B });
  assertEquals(reassigned.asset.status, "assigned");
  assertEquals(reassigned.asset.current_assignee, STAFF_B);

  const history = await getDeviceHistory(db, SCOPE, a.id);
  assertEquals(history.length, 2, "each assignment is its own row — history is not overwritten");
  // Newest assignment first.
  assertEquals(history[0].assigned_to, STAFF_B);
  assertEquals(history[0].returned_at, null); // episode 2 still open
  // Episode 1 (staff A) is intact: closed, condition recorded, assignee unchanged.
  assertEquals(history[1].assigned_to, STAFF_A);
  assertEquals(history[1].condition, "damaged");
  assertEquals(typeof history[1].returned_at, "string");
});

// ── Double-assign guard (concurrent) ─────────────────────────────────────────

Deno.test("CONCURRENT assign never double-assigns (guard = throw-on-0-rows)", async () => {
  const db = client(new DeviceMockDb());
  const a = await seedAsset(db, { assetTag: "RACE-1" });

  const results = await Promise.allSettled([
    assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_A }),
    assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_B }),
  ]);
  const fulfilled = results.filter((r) => r.status === "fulfilled");
  const rejected = results.filter((r) => r.status === "rejected");
  assertEquals(fulfilled.length, 1, "exactly one assign wins");
  assertEquals(rejected.length, 1, "the racing assign is rejected");
  assertInstanceOf((rejected[0] as PromiseRejectedResult).reason, DeviceStatusConflictError);

  // Only ONE custody episode was opened; the asset has a single custodian.
  const history = await getDeviceHistory(db, SCOPE, a.id);
  assertEquals(history.length, 1);
  const asset = await findDeviceById(db, SCOPE, a.id);
  assertEquals(asset?.status, "assigned");
  assertEquals([STAFF_A, STAFF_B].includes(asset!.current_assignee!), true);
});

// ── retire / lost transitions (terminal) ─────────────────────────────────────

Deno.test("retireDevice: in_stock -> retired and returned -> retired", async () => {
  const db = client(new DeviceMockDb());
  const idle = await seedAsset(db, { assetTag: "R1" });
  assertEquals((await retireDevice(db, SCOPE, idle.id)).status, "retired");

  const used = await seedAsset(db, { assetTag: "R2" });
  await assignDevice(db, SCOPE, used.id, { assignedTo: STAFF_A });
  await returnDevice(db, SCOPE, used.id);
  assertEquals((await retireDevice(db, SCOPE, used.id)).status, "retired");
});

Deno.test("retireDevice: cannot retire an actively-assigned asset (return it first)", async () => {
  const db = client(new DeviceMockDb());
  const a = await seedAsset(db, { assetTag: "R3" });
  await assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_A });
  await assertRejects(() => retireDevice(db, SCOPE, a.id), DeviceStatusConflictError, "currently 'assigned'");
});

Deno.test("markDeviceLost: from stock, and from assigned (closes the episode as lost)", async () => {
  const db = client(new DeviceMockDb());
  // Lost from stock — no open episode, close is a no-op.
  const s = await seedAsset(db, { assetTag: "L1" });
  assertEquals((await markDeviceLost(db, SCOPE, s.id)).status, "lost");

  // Lost while assigned — the open episode is closed with condition 'lost',
  // preserving who had it.
  const a = await seedAsset(db, { assetTag: "L2" });
  await assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_A });
  const lost = await markDeviceLost(db, SCOPE, a.id, { note: "not returned" });
  assertEquals(lost.status, "lost");
  assertEquals(lost.current_assignee, null);
  const history = await getDeviceHistory(db, SCOPE, a.id);
  assertEquals(history.length, 1);
  assertEquals(history[0].assigned_to, STAFF_A); // preserved
  assertEquals(history[0].condition, "lost");
  assertEquals(typeof history[0].returned_at, "string");
});

Deno.test("terminal states are terminal: cannot assign/re-lose a retired or lost asset", async () => {
  const db = client(new DeviceMockDb());
  const retired = await seedAsset(db, { assetTag: "T1" });
  await retireDevice(db, SCOPE, retired.id);
  await assertRejects(() => assignDevice(db, SCOPE, retired.id, { assignedTo: STAFF_A }), DeviceStatusConflictError, "currently 'retired'");

  const lost = await seedAsset(db, { assetTag: "T2" });
  await markDeviceLost(db, SCOPE, lost.id);
  await assertRejects(() => assignDevice(db, SCOPE, lost.id, { assignedTo: STAFF_A }), DeviceStatusConflictError, "currently 'lost'");
  await assertRejects(() => markDeviceLost(db, SCOPE, lost.id), DeviceStatusConflictError, "currently 'lost'");
});

// ── Lists ────────────────────────────────────────────────────────────────────

Deno.test("listDevices: newest first, filterable by status / type / assignee", async () => {
  const db = client(new DeviceMockDb());
  const l1 = await seedAsset(db, { assetTag: "D1", assetType: "laptop" });
  await seedAsset(db, { assetTag: "D2", assetType: "tablet" });
  const l3 = await seedAsset(db, { assetTag: "D3", assetType: "laptop" });
  await assignDevice(db, SCOPE, l3.id, { assignedTo: STAFF_A });

  const all = await listDevices(db, SCOPE);
  assertEquals(all.map((r) => r.asset_tag), ["D3", "D2", "D1"]); // created_at DESC

  const laptops = await listDevices(db, SCOPE, { assetType: "laptop" });
  assertEquals(laptops.map((r) => r.asset_tag).sort(), ["D1", "D3"]);

  const inStock = await listDevices(db, SCOPE, { status: "in_stock" });
  assertEquals(inStock.map((r) => r.asset_tag).sort(), ["D1", "D2"]);
  assertEquals(inStock.map((r) => r.id).includes(l1.id), true);

  const byAssignee = await listDevices(db, SCOPE, { assignee: STAFF_A });
  assertEquals(byAssignee.map((r) => r.asset_tag), ["D3"]);
});

Deno.test("listDevicesByStaff: only CURRENTLY-held assets; drops returned ones; per-staff isolation", async () => {
  const db = client(new DeviceMockDb());
  const x = await seedAsset(db, { assetTag: "S1" });
  const y = await seedAsset(db, { assetTag: "S2" });
  const z = await seedAsset(db, { assetTag: "S3" });
  await assignDevice(db, SCOPE, x.id, { assignedTo: STAFF_A });
  await assignDevice(db, SCOPE, y.id, { assignedTo: STAFF_A });
  await assignDevice(db, SCOPE, z.id, { assignedTo: STAFF_B });

  let heldByA = await listDevicesByStaff(db, SCOPE, STAFF_A);
  assertEquals(heldByA.map((r) => r.asset_tag).sort(), ["S1", "S2"]);
  const heldByB = await listDevicesByStaff(db, SCOPE, STAFF_B);
  assertEquals(heldByB.map((r) => r.asset_tag), ["S3"]);

  // After A returns S1, it drops off A's held list.
  await returnDevice(db, SCOPE, x.id);
  heldByA = await listDevicesByStaff(db, SCOPE, STAFF_A);
  assertEquals(heldByA.map((r) => r.asset_tag), ["S2"]);
});

// ── Tenant / school isolation ────────────────────────────────────────────────

Deno.test("school isolation: an asset in one school is invisible/immutable from another", async () => {
  const db = client(new DeviceMockDb());
  const a = await seedAsset(db, { assetTag: "ISO-1" });
  assertEquals(await findDeviceById(db, OTHER_SCOPE, a.id), null);
  // A cross-school assign matches no row -> treated as not found.
  await assertRejects(
    () => assignDevice(db, OTHER_SCOPE, a.id, { assignedTo: STAFF_A }),
    DeviceNotFoundError,
    "not found",
  );
  // Same asset tag can be reused in a DIFFERENT school (unique is per school).
  await registerDevice(db, OTHER_SCOPE, { assetTag: "ISO-1", assetType: "laptop" });
});

Deno.test("getDeviceHistory: scoped per (org, school)", async () => {
  const db = client(new DeviceMockDb());
  const a = await seedAsset(db, { assetTag: "H1" });
  await assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_A });
  assertEquals((await getDeviceHistory(db, SCOPE, a.id)).length, 1);
  assertEquals((await getDeviceHistory(db, OTHER_SCOPE, a.id)).length, 0);
});

// ── API projections ──────────────────────────────────────────────────────────

Deno.test("assetRowToApi / assignmentRowToApi: snake -> camel, numeric cost", async () => {
  const db = client(new DeviceMockDb());
  const a = await registerDevice(db, SCOPE, { assetTag: "MAP-1", assetType: "tablet", serialNo: "SN9", purchaseCost: 500 });
  const api = assetRowToApi(a);
  assertEquals(api.assetTag, "MAP-1");
  assertEquals(api.assetType, "tablet");
  assertEquals(api.serialNo, "SN9");
  assertEquals(api.purchaseCost, 500); // number, not "500.00"
  assertEquals(api.status, "in_stock");

  const { assignment } = await assignDevice(db, SCOPE, a.id, { assignedTo: STAFF_A });
  const aapi = assignmentRowToApi(assignment);
  assertEquals(aapi.assignedTo, STAFF_A);
  assertEquals(aapi.assetId, a.id);
  assertEquals(aapi.returnedAt, null);
});

// ── Migration shape (tables + RLS + grants + guards, no DELETE) ───────────────

Deno.test("device_management migration: two tables, FORCE RLS, grants (no DELETE), guards", async () => {
  const migration = await Deno.readTextFile(
    new URL("../../../migrations/20260900000029_device_management.sql", import.meta.url),
  );
  // Register table.
  assertStringIncludes(migration, "CREATE TABLE IF NOT EXISTS org_assets");
  assertStringIncludes(migration, "status IN ('in_stock', 'assigned', 'returned', 'retired', 'lost')");
  assertStringIncludes(migration, "CREATE UNIQUE INDEX IF NOT EXISTS uq_org_assets_tag");
  assertStringIncludes(migration, "CREATE UNIQUE INDEX IF NOT EXISTS uq_org_assets_serial");
  assertStringIncludes(migration, "ALTER TABLE org_assets FORCE ROW LEVEL SECURITY");
  assertStringIncludes(migration, "CREATE POLICY org_assets_school_scope");
  assertStringIncludes(migration, "app_current_scope() = 'school'");
  assertStringIncludes(migration, "GRANT SELECT, INSERT, UPDATE ON org_assets TO erp_tenant");
  assertEquals(migration.includes("DELETE ON org_assets"), false);
  // Append-only custody ledger.
  assertStringIncludes(migration, "CREATE TABLE IF NOT EXISTS device_assignments");
  assertStringIncludes(migration, "CREATE UNIQUE INDEX IF NOT EXISTS uq_device_assignments_open");
  assertStringIncludes(migration, "WHERE returned_at IS NULL");
  assertStringIncludes(migration, "ALTER TABLE device_assignments FORCE ROW LEVEL SECURITY");
  assertStringIncludes(migration, "GRANT SELECT, INSERT, UPDATE ON device_assignments TO erp_tenant");
  assertEquals(migration.includes("DELETE ON device_assignments"), false);
});
