import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const PROBES_PATH = new URL("../tenant_isolation_probes.ts", import.meta.url);
const probesSource = await Deno.readTextFile(PROBES_PATH);

const COMM_PROBES = [
  "parent_a_cannot_see_school_b_notification",
  "parent_a_sees_own_notification",
  "parent_a_cannot_see_school_b_comm_thread",
  "parent_a_sees_own_comm_thread",
  "school_a_cannot_see_school_b_comm_thread",
  "student_denied_parent_notification_probe",
] as const;

Deno.test("Communication v7.1 isolation probes are registered", () => {
  for (const probe of COMM_PROBES) {
    assert(probesSource.includes(`name: "${probe}"`), `missing probe: ${probe}`);
  }
});

Deno.test("Communication fixtures imported in probes", () => {
  assert(probesSource.includes("NOTIFICATION_DELIVERY_PROBE_SCHOOL_A"));
  assert(probesSource.includes("COMM_THREAD_PROBE_DETAIL_SQL"));
});

function extractProbeNames(source: string): string[] {
  const names: string[] = [];
  for (const match of source.matchAll(/name:\s*"([^"]+)"/g)) {
    names.push(match[1]!);
  }
  return names;
}

Deno.test("tenant isolation probe count includes v7.6 probes (219)", () => {
  assertEquals(extractProbeNames(probesSource).length, 219);
});
