// W4 (Owner decision #12, FINAL) — Organization Device / Asset management repo.
//
// Two-table model (see migration 20260900000029):
//   * org_assets           — one row per physical asset instance (the register).
//   * device_assignments   — append-only custody ledger, one row per assignment
//                            EPISODE. A new assign ALWAYS inserts a fresh row;
//                            history is never overwritten. The only update is
//                            closing the OPEN episode (returned_at IS NULL) on
//                            return / loss.
//
// Lifecycle:  in_stock ─assign→ assigned ─return→ returned ─assign→ assigned …
//             (in_stock | returned | assigned) ─lost→ lost      (terminal)
//             (in_stock | returned)            ─retire→ retired (terminal)
//
// CONCURRENCY — the org_assets.status transition is the serialization point. Each
// lifecycle write is a single guarded UPDATE:
//     UPDATE org_assets SET status=<to> WHERE ... AND status = ANY(<allowed-from>)
// Under withTenantContext's open transaction the row lock serializes concurrent
// writers: the first flips the status and matches 1 row, the second sees the new
// status, matches 0 rows, and is REJECTED (throw-on-0-rows) — the exact
// money-integrity guard, so a concurrent double-assign can never double-assign.
// The unique partial index uq_device_assignments_open is the DB backstop: at most
// one un-returned episode per asset.

import type { TenantQueryClient } from "../tenant_db.ts";

// ─── Statuses + allowed transitions (mirror the DB CHECK + guard from-sets) ───

export const ASSET_STATUSES = [
  "in_stock",
  "assigned",
  "returned",
  "retired",
  "lost",
] as const;
export type AssetStatus = (typeof ASSET_STATUSES)[number];

/** The "available" states an asset can be (re)assigned from. */
export const ASSIGNABLE_FROM: AssetStatus[] = ["in_stock", "returned"];
/** Return is only valid from an actively-assigned asset. */
export const RETURNABLE_FROM: AssetStatus[] = ["assigned"];
/** Retire an asset that is idle (never assigned, or already returned). */
export const RETIRABLE_FROM: AssetStatus[] = ["in_stock", "returned"];
/** An asset can be lost from stock, after return, or while in someone's hands. */
export const LOSABLE_FROM: AssetStatus[] = ["in_stock", "returned", "assigned"];

// ─── Typed errors (mapped to HTTP status by the handlers) ─────────────────────

export class DeviceValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DeviceValidationError";
  }
}

export class DeviceNotFoundError extends Error {
  constructor(public readonly id: string) {
    super(`Asset not found: ${id}`);
    this.name = "DeviceNotFoundError";
  }
}

/** A guarded status transition matched 0 rows because the asset is in an
 * incompatible current status (e.g. assigning an already-assigned asset). */
export class DeviceStatusConflictError extends Error {
  constructor(
    public readonly id: string,
    public readonly currentStatus: string,
    public readonly attempted: string,
  ) {
    super(
      `Cannot ${attempted} asset ${id}: it is currently '${currentStatus}'`,
    );
    this.name = "DeviceStatusConflictError";
  }
}

/** Duplicate asset tag / serial — surfaced from the UNIQUE index violation. */
export class DeviceConflictError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DeviceConflictError";
  }
}

// ─── Row shapes ───────────────────────────────────────────────────────────────

export interface AssetRow {
  id: string;
  asset_tag: string;
  asset_type: string;
  serial_no: string | null;
  purchase_ref: string | null;
  purchase_cost: string;
  status: string;
  current_assignee: string | null;
  note: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface AssignmentRow {
  id: string;
  asset_id: string;
  assigned_to: string;
  assigned_by: string | null;
  assigned_at: string;
  returned_at: string | null;
  condition: string | null;
  note: string | null;
  created_at: string;
}

const ASSET_COLUMNS =
  `id, asset_tag, asset_type, serial_no, purchase_ref,
   purchase_cost::text AS purchase_cost, status, current_assignee, note,
   created_by::text AS created_by, created_at::text AS created_at,
   updated_at::text AS updated_at`;

const ASSIGNMENT_COLUMNS =
  `id, asset_id, assigned_to, assigned_by::text AS assigned_by,
   assigned_at::text AS assigned_at, returned_at::text AS returned_at,
   condition, note, created_at::text AS created_at`;

export interface DeviceScope {
  organizationId: string;
  schoolId: string;
}

// ─── Register / lookups ───────────────────────────────────────────────────────

export interface RegisterDeviceInput {
  assetTag: string;
  assetType: string;
  serialNo?: string | null;
  purchaseRef?: string | null;
  purchaseCost?: number;
  note?: string | null;
  createdBy?: string | null;
}

/** Recognise the two UNIQUE-index violations so they map to a 409, not a 500. */
function rethrowUniqueViolation(error: unknown): never {
  const msg = error instanceof Error ? error.message : String(error);
  if (msg.includes("uq_org_assets_tag")) {
    throw new DeviceConflictError("An asset with this asset tag already exists");
  }
  if (msg.includes("uq_org_assets_serial")) {
    throw new DeviceConflictError("An asset with this serial number already exists");
  }
  throw error;
}

/** Register a new asset in the in_stock pool. */
export async function registerDevice(
  db: TenantQueryClient,
  scope: DeviceScope,
  input: RegisterDeviceInput,
): Promise<AssetRow> {
  const assetTag = input.assetTag?.trim();
  const assetType = input.assetType?.trim();
  if (!assetTag) throw new DeviceValidationError("assetTag is required");
  if (!assetType) throw new DeviceValidationError("assetType is required");
  const cost = typeof input.purchaseCost === "number" && Number.isFinite(input.purchaseCost)
    ? input.purchaseCost
    : 0;
  if (cost < 0) throw new DeviceValidationError("purchaseCost cannot be negative");
  const serialNo = input.serialNo?.trim() || null;

  try {
    const rows = await db.queryObject<AssetRow>(
      `INSERT INTO org_assets (
         organization_id, school_id, asset_tag, asset_type, serial_no,
         purchase_ref, purchase_cost, status, current_assignee, note, created_by
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,'in_stock',NULL,$8,$9)
       RETURNING ${ASSET_COLUMNS}`,
      [
        scope.organizationId,
        scope.schoolId,
        assetTag,
        assetType,
        serialNo,
        input.purchaseRef?.trim() || null,
        cost,
        input.note?.trim() || null,
        input.createdBy ?? null,
      ],
    );
    const row = rows[0];
    if (!row) throw new Error("Failed to insert org_assets row");
    return row;
  } catch (error) {
    rethrowUniqueViolation(error);
  }
}

export async function findDeviceById(
  db: TenantQueryClient,
  scope: DeviceScope,
  id: string,
): Promise<AssetRow | null> {
  const rows = await db.queryObject<AssetRow>(
    `SELECT ${ASSET_COLUMNS}
       FROM org_assets
      WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid`,
    [scope.organizationId, scope.schoolId, id],
  );
  return rows[0] ?? null;
}

export interface ListDevicesOptions {
  status?: string;
  assetType?: string;
  assignee?: string;
  limit?: number;
}

/** The asset register, newest first, optionally filtered by status/type/assignee. */
export async function listDevices(
  db: TenantQueryClient,
  scope: DeviceScope,
  options: ListDevicesOptions = {},
): Promise<AssetRow[]> {
  const args: unknown[] = [scope.organizationId, scope.schoolId];
  const filters: string[] = [];
  if (options.status) {
    args.push(options.status);
    filters.push(`AND status = $${args.length}`);
  }
  if (options.assetType) {
    args.push(options.assetType);
    filters.push(`AND asset_type = $${args.length}`);
  }
  if (options.assignee) {
    args.push(options.assignee);
    filters.push(`AND current_assignee = $${args.length}`);
  }
  const limit = Math.min(1000, Math.max(1, options.limit ?? 500));
  return await db.queryObject<AssetRow>(
    `SELECT ${ASSET_COLUMNS}
       FROM org_assets
      WHERE organization_id = $1 AND school_id = $2
      ${filters.join("\n      ")}
      ORDER BY created_at DESC
      LIMIT ${limit}`,
    args,
  );
}

/** Assets CURRENTLY held by a staff member (status = 'assigned' + assignee). */
export async function listDevicesByStaff(
  db: TenantQueryClient,
  scope: DeviceScope,
  staffId: string,
  limit = 500,
): Promise<AssetRow[]> {
  return await db.queryObject<AssetRow>(
    `SELECT ${ASSET_COLUMNS}
       FROM org_assets
      WHERE organization_id = $1 AND school_id = $2
        AND status = 'assigned' AND current_assignee = $3
      ORDER BY updated_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, staffId, Math.min(1000, Math.max(1, limit))],
  );
}

/** The custody timeline for one asset (every episode, newest assignment first). */
export async function getDeviceHistory(
  db: TenantQueryClient,
  scope: DeviceScope,
  assetId: string,
  limit = 500,
): Promise<AssignmentRow[]> {
  return await db.queryObject<AssignmentRow>(
    `SELECT ${ASSIGNMENT_COLUMNS}
       FROM device_assignments
      WHERE organization_id = $1 AND school_id = $2 AND asset_id = $3::uuid
      ORDER BY assigned_at DESC
      LIMIT $4`,
    [scope.organizationId, scope.schoolId, assetId, Math.min(2000, Math.max(1, limit))],
  );
}

// ─── Guard helper: classify a 0-row transition into 404 vs 409 ────────────────

async function classifyTransitionFailure(
  db: TenantQueryClient,
  scope: DeviceScope,
  id: string,
  attempted: string,
): Promise<never> {
  const existing = await findDeviceById(db, scope, id);
  if (!existing) throw new DeviceNotFoundError(id);
  throw new DeviceStatusConflictError(id, existing.status, attempted);
}

// ─── Lifecycle writes (all guarded; run inside the caller's tenant txn) ───────

export interface AssignDeviceInput {
  assignedTo: string;
  assignedBy?: string | null;
  note?: string | null;
}

export interface AssignDeviceResult {
  asset: AssetRow;
  assignment: AssignmentRow;
}

/**
 * Assign an asset to a staff member. Guarded UPDATE (in_stock | returned ->
 * assigned) FIRST — that is the atomic gate — then INSERT a fresh custody episode.
 * Both run in the caller's transaction, so they commit together. A concurrent
 * second assign matches 0 rows on the guard and is rejected (no double-assign).
 */
export async function assignDevice(
  db: TenantQueryClient,
  scope: DeviceScope,
  id: string,
  input: AssignDeviceInput,
): Promise<AssignDeviceResult> {
  const assignedTo = input.assignedTo?.trim();
  if (!assignedTo) throw new DeviceValidationError("assignedTo is required");

  const updated = await db.queryObject<AssetRow>(
    `UPDATE org_assets
        SET status = 'assigned', current_assignee = $4,
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
        AND status = ANY($5)
      RETURNING ${ASSET_COLUMNS}`,
    [scope.organizationId, scope.schoolId, id, assignedTo, ASSIGNABLE_FROM],
  );
  const asset = updated[0];
  if (!asset) await classifyTransitionFailure(db, scope, id, "assign");

  const ledger = await db.queryObject<AssignmentRow>(
    `INSERT INTO device_assignments (
       organization_id, school_id, asset_id, assigned_to, assigned_by, note
     ) VALUES ($1,$2,$3,$4,$5,$6)
     RETURNING ${ASSIGNMENT_COLUMNS}`,
    [
      scope.organizationId,
      scope.schoolId,
      id,
      assignedTo,
      input.assignedBy ?? null,
      input.note?.trim() || null,
    ],
  );
  return { asset: asset!, assignment: ledger[0]! };
}

export interface ReturnDeviceInput {
  condition?: string | null;
  note?: string | null;
}

export interface ReturnDeviceResult {
  asset: AssetRow;
  assignment: AssignmentRow | null;
}

/**
 * Return an assigned asset. Guarded UPDATE (assigned -> returned, clears the
 * assignee), then CLOSE the open custody episode (returned_at + condition) — the
 * past episode row is updated in place to record the return, NOT overwritten:
 * assigned_to / assigned_at are untouched. A double-return matches 0 rows.
 */
export async function returnDevice(
  db: TenantQueryClient,
  scope: DeviceScope,
  id: string,
  input: ReturnDeviceInput = {},
): Promise<ReturnDeviceResult> {
  const updated = await db.queryObject<AssetRow>(
    `UPDATE org_assets
        SET status = 'returned', current_assignee = NULL,
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
        AND status = 'assigned'
      RETURNING ${ASSET_COLUMNS}`,
    [scope.organizationId, scope.schoolId, id],
  );
  const asset = updated[0];
  if (!asset) await classifyTransitionFailure(db, scope, id, "return");

  const closed = await db.queryObject<AssignmentRow>(
    `UPDATE device_assignments
        SET returned_at = timezone('utc', now()), condition = $4, note = COALESCE($5, note)
      WHERE organization_id = $1 AND school_id = $2 AND asset_id = $3::uuid
        AND returned_at IS NULL
      RETURNING ${ASSIGNMENT_COLUMNS}`,
    [
      scope.organizationId,
      scope.schoolId,
      id,
      input.condition?.trim() || null,
      input.note?.trim() || null,
    ],
  );
  return { asset: asset!, assignment: closed[0] ?? null };
}

/** Retire an idle asset (in_stock | returned -> retired). Return it first if it
 * is currently assigned. Terminal. */
export async function retireDevice(
  db: TenantQueryClient,
  scope: DeviceScope,
  id: string,
): Promise<AssetRow> {
  const updated = await db.queryObject<AssetRow>(
    `UPDATE org_assets
        SET status = 'retired', updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
        AND status = ANY($4)
      RETURNING ${ASSET_COLUMNS}`,
    [scope.organizationId, scope.schoolId, id, RETIRABLE_FROM],
  );
  const asset = updated[0];
  if (!asset) await classifyTransitionFailure(db, scope, id, "retire");
  return asset!;
}

/**
 * Mark an asset lost (in_stock | returned | assigned -> lost, clears the
 * assignee). Terminal. If it was assigned, the open custody episode is closed with
 * the loss recorded (condition defaults to 'lost'); if it was idle there is no open
 * episode and the close is a no-op. Preserves the custody history either way.
 */
export async function markDeviceLost(
  db: TenantQueryClient,
  scope: DeviceScope,
  id: string,
  input: { note?: string | null; condition?: string | null } = {},
): Promise<AssetRow> {
  const updated = await db.queryObject<AssetRow>(
    `UPDATE org_assets
        SET status = 'lost', current_assignee = NULL,
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
        AND status = ANY($4)
      RETURNING ${ASSET_COLUMNS}`,
    [scope.organizationId, scope.schoolId, id, LOSABLE_FROM],
  );
  const asset = updated[0];
  if (!asset) await classifyTransitionFailure(db, scope, id, "mark lost");

  // Close any open custody episode (no-op when the asset was idle).
  await db.queryObject<AssignmentRow>(
    `UPDATE device_assignments
        SET returned_at = timezone('utc', now()),
            condition = COALESCE($4, 'lost'),
            note = COALESCE($5, note)
      WHERE organization_id = $1 AND school_id = $2 AND asset_id = $3::uuid
        AND returned_at IS NULL
      RETURNING ${ASSIGNMENT_COLUMNS}`,
    [
      scope.organizationId,
      scope.schoolId,
      id,
      input.condition?.trim() || null,
      input.note?.trim() || null,
    ],
  );
  return asset!;
}

// ─── API projections (snake_case row → camelCase DTO) ─────────────────────────

export function assetRowToApi(row: AssetRow): Record<string, unknown> {
  return {
    id: row.id,
    assetTag: row.asset_tag,
    assetType: row.asset_type,
    serialNo: row.serial_no ?? "",
    purchaseRef: row.purchase_ref ?? "",
    purchaseCost: Number(row.purchase_cost),
    status: row.status,
    currentAssignee: row.current_assignee,
    note: row.note ?? "",
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function assignmentRowToApi(row: AssignmentRow): Record<string, unknown> {
  return {
    id: row.id,
    assetId: row.asset_id,
    assignedTo: row.assigned_to,
    assignedBy: row.assigned_by,
    assignedAt: row.assigned_at,
    returnedAt: row.returned_at,
    condition: row.condition ?? "",
    note: row.note ?? "",
    createdAt: row.created_at,
  };
}
