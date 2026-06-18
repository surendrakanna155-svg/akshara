import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { approvalPermissionForType } from "./approval_permissions.ts";
import { isF2ApprovalType } from "./approval_types.ts";

Deno.test("F2 approval types include all seven handlers", () => {
  const expected = [
    "examResults",
    "studentLeave",
    "staffLeave",
    "attendanceCorrection",
    "feeConcession",
    "refund",
    "inventoryPo",
  ];
  for (const type of expected) {
    assertEquals(isF2ApprovalType(type), true);
    assertEquals(approvalPermissionForType(type) != null, true);
  }
});

Deno.test("inventoryPo maps to approvePurchaseOrder permission", () => {
  assertEquals(approvalPermissionForType("inventoryPo"), "approvePurchaseOrder");
});

Deno.test("refund maps to approveRefunds permission", () => {
  assertEquals(approvalPermissionForType("refund"), "approveRefunds");
});
