import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  DEFAULT_ROLES,
  packDefaultLayout,
  WIDGET_DATA_SOURCES,
} from "./widget_pack_catalog.ts";

Deno.test("data sources are namespaced and reference real permissions", () => {
  assertEquals(WIDGET_DATA_SOURCES.length, 6);
  for (const ds of WIDGET_DATA_SOURCES) {
    assertEquals(ds.key.includes("."), true, ds.key);
    assertEquals(ds.requiredPermission.length > 0, true, ds.key);
    assertEquals(ds.supportedTypes.length > 0, true, ds.key);
  }
});

Deno.test("school principal default layout matches evolution widget ids", () => {
  const layout = packDefaultLayout("principal", "school");
  assertEquals(layout.role, "principal");
  assertEquals(layout.verticalPack, "school");
  assertEquals(layout.version, 1);
  assertEquals(layout.isTenantOverride, false);
  const ids = layout.widgets.map((w) => w.id);
  for (const id of ["school_health", "fee_collection", "student_risk", "attendance_risk"]) {
    assertEquals(ids.includes(id), true, `missing ${id}`);
  }
});

Deno.test("role-specific school layouts differ", () => {
  const teacher = packDefaultLayout("teacher", "school").widgets.map((w) => w.id);
  const finance = packDefaultLayout("financeAdmin", "school").widgets.map((w) => w.id);
  assertEquals(teacher.includes("homework_summary"), true);
  assertEquals(finance, ["fee_collection"]);
});

Deno.test("vertical packs resolve their own widgets", () => {
  assertEquals(packDefaultLayout("owner", "salon").widgets.map((w) => w.id), [
    "chair_utilization",
    "appointment_pipeline",
  ]);
  assertEquals(packDefaultLayout("owner", "hospital").widgets.map((w) => w.id), [
    "bed_occupancy",
    "opd_queue",
  ]);
  assertEquals(packDefaultLayout("owner", "restaurant").widgets.map((w) => w.id), [
    "active_covers",
    "ticket_time",
  ]);
});

Deno.test("default roles cover the school pack personas", () => {
  assertEquals(DEFAULT_ROLES.includes("principal"), true);
  assertEquals(DEFAULT_ROLES.includes("teacher"), true);
  assertEquals(DEFAULT_ROLES.includes("financeAdmin"), true);
  assertEquals(DEFAULT_ROLES.includes("schoolAdmin"), true);
});
