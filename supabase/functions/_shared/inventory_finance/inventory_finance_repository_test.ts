import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  approvePurchaseOrder,
  type PurchaseOrderRow,
  PurchaseOrderSelfApproveDeniedError,
} from "./inventory_finance_repository.ts";

Deno.test("weighted average cost formula", () => {
  const oldQty = 10;
  const oldCost = 100;
  const qtyReceived = 5;
  const unitCost = 130;
  const newQty = oldQty + qtyReceived;
  const newAvg = Math.round((oldQty * oldCost + qtyReceived * unitCost) / newQty);
  assertEquals(newAvg, 110);
});

Deno.test("inventory finance router exposes procurement approve route", async () => {
  const { matchInventoryFinanceRoute } = await import("./inventory_finance_router.ts");
  const match = matchInventoryFinanceRoute(
    "POST",
    "/inventory/procurement/orders/d8100000-0000-4000-8000-000000000001/approve",
  );
  assertEquals(match?.handler.name, "handleApprovePurchaseOrder");
});

Deno.test("inventory finance router exposes purchase order detail route", async () => {
  const { matchInventoryFinanceRoute } = await import("./inventory_finance_router.ts");
  const match = matchInventoryFinanceRoute(
    "GET",
    "/inventory/procurement/orders/d8100000-0000-4000-8000-000000000001",
  );
  assertEquals(match?.handler.name, "handleGetPurchaseOrder");
});

// INV-5: the GRN register is exposed on the INVENTORY surface (viewInventory-
// gated in the handler) so store staff can list/export GRNs without viewFinance.
Deno.test("inventory finance router exposes the GRN register route", async () => {
  const { matchInventoryFinanceRoute } = await import("./inventory_finance_router.ts");
  const match = matchInventoryFinanceRoute("GET", "/inventory/procurement/grns");
  assertEquals(match?.handler.name, "handleListGrns");
  // Not a write route: POST does not match.
  assertEquals(matchInventoryFinanceRoute("POST", "/inventory/procurement/grns"), null);
});

Deno.test("INV-5: listGoodsReceipts scopes to org+school and joins PO + vendor", async () => {
  const { listGoodsReceipts } = await import("./inventory_finance_repository.ts");
  const calls: Array<{ sql: string; args: unknown[] }> = [];
  const db = {
    queryObject(sql: string, args: unknown[] = []) {
      calls.push({ sql, args });
      return Promise.resolve([{
        id: "grn-1",
        grn_number: "GRN-PO-1-000001",
        purchase_order_id: "po-1",
        po_number: "PO-1",
        vendor_name: "Vendor A",
        received_at: "2026-07-06T00:00:00.000Z",
        status: "posted",
        line_count: 2,
      }]);
    },
    // deno-lint-ignore no-explicit-any
  } as any;
  const rows = await listGoodsReceipts(db, "org-1", "school-1");
  assertEquals(rows.length, 1);
  assertEquals(rows[0].grn_number, "GRN-PO-1-000001");
  const q = calls[0];
  assertEquals(q.args, ["org-1", "school-1"]);
  assertEquals(q.sql.includes("FROM goods_receipts"), true);
  assertEquals(q.sql.includes("JOIN purchase_orders"), true);
  assertEquals(q.sql.includes("JOIN inventory_vendors"), true);
  assertEquals(q.sql.includes("gr.organization_id = $1 AND gr.school_id = $2"), true);
});

Deno.test("finance router exposes inventory reconciliation dashboard", async () => {
  const { matchFinanceRoute } = await import("../finance/finance_router.ts");
  const match = matchFinanceRoute(
    "GET",
    "/finance/inventory-reconciliation/dashboard",
  );
  assertEquals(match?.handler.name, "handleReconciliationDashboard");
});

// ─── INV-1..7: Store stock module route wiring ───────────────────────────────

Deno.test("stock router: issue / adjust / count / register / low-stock / items resolve", async () => {
  const { matchInventoryFinanceRoute } = await import("./inventory_finance_router.ts");
  const cases: Array<[string, string, string]> = [
    ["POST", "/inventory/stock/issue", "handleIssueStock"],
    ["POST", "/inventory/stock/adjust", "handleAdjustStock"],
    ["GET", "/inventory/stock/adjustments", "handleListPendingAdjustments"],
    ["POST", "/inventory/stock/count", "handleRecordStockCount"],
    ["GET", "/inventory/stock/items", "handleListStockItems"],
    ["POST", "/inventory/stock/items", "handleUpsertStockItem"],
    ["PUT", "/inventory/stock/items", "handleUpsertStockItem"],
    ["GET", "/inventory/stock/register", "handleStockRegister"],
    ["GET", "/inventory/stock/low-stock", "handleLowStock"],
  ];
  for (const [method, path, name] of cases) {
    const match = matchInventoryFinanceRoute(method, path);
    assertEquals(match?.handler.name, name, `${method} ${path}`);
  }
});

Deno.test("stock router: maker-checker :id sub-paths match before the list", async () => {
  const { matchInventoryFinanceRoute } = await import("./inventory_finance_router.ts");
  const id = "d8100000-0000-4000-8000-000000000001";
  const approve = matchInventoryFinanceRoute("POST", `/inventory/stock/adjustments/${id}/approve`);
  assertEquals(approve?.handler.name, "handleApproveStockAdjustment");
  assertEquals(approve?.args?.[0], id);
  const reject = matchInventoryFinanceRoute("POST", `/inventory/stock/adjustments/${id}/reject`);
  assertEquals(reject?.handler.name, "handleRejectStockAdjustment");
  assertEquals(reject?.args?.[0], id);
});

Deno.test("stock migration: valuations RLS gets WITH CHECK; ledger is insert-only immutable", async () => {
  const sql = await Deno.readTextFile(
    new URL(
      "../../../migrations/20260839000000_inventory_stock_movements.sql",
      import.meta.url,
    ),
  );
  // Valuations policy DROP/CREATE with a WITH CHECK (mirrors inv_catalog_items).
  assertEquals(sql.includes("DROP POLICY IF EXISTS inventory_stock_valuations_school"), true);
  assertEquals(sql.includes("CREATE POLICY inventory_stock_valuations_school"), true);
  // Non-negative guard present at the DB.
  assertEquals(sql.includes("quantity_on_hand_non_negative CHECK (quantity_on_hand >= 0)"), true);
  // stock_movements is immutable: SELECT/INSERT grant only, no UPDATE/DELETE.
  assertEquals(sql.includes("GRANT SELECT, INSERT ON stock_movements TO erp_tenant;"), true);
  assertEquals(/GRANT[^;]*(UPDATE|DELETE)[^;]*ON stock_movements/.test(sql), false);
  // Every new policy carries a WITH CHECK.
  const withCheckCount = (sql.match(/WITH CHECK \(/g) ?? []).length;
  assertEquals(withCheckCount >= 6, true, `expected >=6 WITH CHECK clauses, saw ${withCheckCount}`);
  // SoD backstop: checker can never be the maker at the DB level.
  assertEquals(sql.includes("stock_adjustment_checker_not_maker"), true);
});

// ─── Gap-sweep FIX 1: Purchase-order maker-checker (P0 self-approval hole) ───
//
// approvePurchaseOrder had NO maker != checker check, so a single user with
// manageInventory + approvePurchaseOrder (both commonly granted to the same
// role, e.g. schoolAdmin) could create a PO and approve their own request.
// Mirrors the stock domain's StockSelfApproveDeniedError (see
// "maker-checker: self-approve is blocked (409)" above) and the refund
// domain's RefundSelfApprovalError.

const PO_ORG = "e1000000-0000-4000-8000-000000000001";
const PO_SCHOOL = "e2000000-0000-4000-8000-000000000001";
const PO_MAKER = "e3000000-0000-4000-8000-000000000001";
const PO_CHECKER = "e3000000-0000-4000-8000-000000000002";
const PO_ID = "e4000000-0000-4000-8000-000000000001";

/** Stateful in-memory model of the purchase-order approval flow. */
class FakePoDb {
  po: PurchaseOrderRow = {
    id: PO_ID,
    po_number: "PO-1001",
    vendor_id: "vendor-1",
    status: "draft",
    total_amount: 5000,
    currency: "INR",
    created_at: "2026-07-08T00:00:00.000Z",
    requested_by: PO_MAKER,
  };

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("FROM purchase_orders") && sql.includes("SELECT id, po_number")) {
      return (this.po.id === args[0] ? [{ ...this.po }] : []) as T[];
    }
    if (sql.includes("UPDATE purchase_orders") && sql.includes("SET status = 'approved'")) {
      this.po = { ...this.po, status: "approved" };
      return [] as T[];
    }
    if (sql.includes("INSERT INTO finance_ap_commitments")) {
      return [{ id: "ap-commitment-1" }] as T[];
    }
    if (sql.includes("INSERT INTO inventory_finance_postings")) {
      return [{ id: "posting-1" }] as T[];
    }
    if (sql.includes("INSERT INTO procurement_finance_links")) {
      return [] as T[];
    }
    throw new Error(`Unhandled SQL in FakePoDb: ${sql.slice(0, 80)}`);
  }
}

function poDb(fake: FakePoDb): TenantQueryClient {
  return fake as unknown as TenantQueryClient;
}

Deno.test("PO maker-checker: self-approve is blocked (PurchaseOrderSelfApproveDeniedError)", async () => {
  const fake = new FakePoDb();
  await assertRejects(
    () => approvePurchaseOrder(poDb(fake), PO_ORG, PO_SCHOOL, PO_ID, PO_MAKER),
    PurchaseOrderSelfApproveDeniedError,
  );
  assertEquals(fake.po.status, "draft", "PO must stay draft on a blocked self-approve");
});

Deno.test("PO maker-checker: approve by a different user succeeds (finance-integrated)", async () => {
  const fake = new FakePoDb();
  const result = await approvePurchaseOrder(poDb(fake), PO_ORG, PO_SCHOOL, PO_ID, PO_CHECKER);
  assertEquals(result.purchaseOrder.status, "approved");
  assertEquals(result.apCommitmentId, "ap-commitment-1");
  assertEquals(fake.po.status, "approved");
});

Deno.test("PO maker-checker: legacy PO with no requested_by is not blocked (defensive skip)", async () => {
  const fake = new FakePoDb();
  // deno-lint-ignore no-explicit-any
  (fake.po as any).requested_by = null;
  const result = await approvePurchaseOrder(poDb(fake), PO_ORG, PO_SCHOOL, PO_ID, PO_MAKER);
  assertEquals(result.purchaseOrder.status, "approved");
});
