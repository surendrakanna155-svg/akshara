import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  filterLayoutByCapabilities,
  optionalCapabilityForDataSource,
} from "./widget_layout_handlers.ts";
import { packDefaultLayout, type RoleDashboardLayoutDef } from "./widget_pack_catalog.ts";

// G5 — dashboard layout must drop widgets for disabled optional modules.

Deno.test("optionalCapabilityForDataSource maps optional prefixes, keeps core null", () => {
  assertEquals(optionalCapabilityForDataSource("transport.routes"), "transport");
  assertEquals(optionalCapabilityForDataSource("hr.headcount"), "hrPayroll");
  assertEquals(optionalCapabilityForDataSource("library.circulation"), "library");
  // Core / vertical prefixes are never gated by the optional flags.
  assertEquals(optionalCapabilityForDataSource("finance.fee_collection"), null);
  assertEquals(optionalCapabilityForDataSource("intelligence.student_risk"), null);
  assertEquals(optionalCapabilityForDataSource("salon.chair_utilization"), null);
});

Deno.test("filterLayoutByCapabilities is a no-op for the core school pack", () => {
  const layout = packDefaultLayout("principal", "school");
  const filtered = filterLayoutByCapabilities(layout, { transport: false });
  // The school pack has only core widgets, so nothing is dropped.
  assertEquals(filtered.widgets.length, layout.widgets.length);
});

Deno.test("filterLayoutByCapabilities drops a disabled optional-module widget", () => {
  const layout: RoleDashboardLayoutDef = {
    layoutId: "x",
    role: "principal",
    verticalPack: "school",
    version: 1,
    isTenantOverride: true,
    navigation: [],
    widgets: [
      { id: "w1", title: "Fees", type: "kpi", dataSource: "finance.fee_collection", permissions: [], size: "half", visible: true, order: 0 },
      { id: "w2", title: "Routes", type: "list", dataSource: "transport.routes", permissions: [], size: "half", visible: true, order: 1 },
    ],
  };
  const filtered = filterLayoutByCapabilities(layout, { transport: false });
  assertEquals(filtered.widgets.map((w) => w.id), ["w1"]);
});

Deno.test("filterLayoutByCapabilities keeps an enabled optional-module widget", () => {
  const layout: RoleDashboardLayoutDef = {
    layoutId: "x",
    role: "principal",
    verticalPack: "school",
    version: 1,
    isTenantOverride: true,
    navigation: [],
    widgets: [
      { id: "w2", title: "Routes", type: "list", dataSource: "transport.routes", permissions: [], size: "half", visible: true, order: 1 },
    ],
  };
  const filtered = filterLayoutByCapabilities(layout, { transport: true });
  assertEquals(filtered.widgets.length, 1);
});
