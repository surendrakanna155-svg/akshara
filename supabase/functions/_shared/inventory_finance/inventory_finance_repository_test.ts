import { assertEquals } from "jsr:@std/assert@1";

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
