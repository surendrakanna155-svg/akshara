import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  INTEL_RISK_API_PROBE_SQL,
  INTEL_RISK_PROBE_SCHOOL_A,
  INTEL_RISK_PROBE_SCHOOL_B,
  INTEL_RISK_PROBE_SQL,
} from "./student_risk_repository.ts";

Deno.test("student risk repository exports tenant isolation probe SQL", () => {
  assert(INTEL_RISK_PROBE_SQL.includes("intel_student_risk_snapshots"));
  assert(INTEL_RISK_API_PROBE_SQL.includes("app_current_tenant_id()"));
  assert(INTEL_RISK_API_PROBE_SQL.includes("app_current_school_id()"));
  assertEquals(INTEL_RISK_PROBE_SCHOOL_A, "f0500000-0000-4000-8000-000000000001");
  assertEquals(INTEL_RISK_PROBE_SCHOOL_B, "f0500000-0000-4000-8000-000000000002");
});

Deno.test("recovery migration seeds match repository probe fixture ids", async () => {
  const recoverySql = await Deno.readTextFile(
    new URL("../../../migrations/20260627100000_staging_intelligence_layer_recovery.sql", import.meta.url),
  );
  assert(recoverySql.includes(INTEL_RISK_PROBE_SCHOOL_A));
  assert(recoverySql.includes(INTEL_RISK_PROBE_SCHOOL_B));
});
