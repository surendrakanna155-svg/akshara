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
