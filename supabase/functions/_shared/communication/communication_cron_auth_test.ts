// COM-4 (Track B gap-sweep) — internal cron token auth, DB-free unit tests.
// Mirrors communication_webhook_auth_test.ts's style: construct the small
// config object directly rather than mutating real env vars, since
// `verifyInternalCronToken` takes it as a plain argument.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type CommunicationCronConfig,
  loadCommunicationCronConfig,
  verifyInternalCronToken,
} from "./communication_cron_auth.ts";

const configured: CommunicationCronConfig = { token: "sched-cron-secret" };
const unconfigured: CommunicationCronConfig = { token: null };

Deno.test("accepts the exact configured token", async () => {
  assertEquals(await verifyInternalCronToken(configured, "sched-cron-secret"), true);
});

Deno.test("rejects a wrong token", async () => {
  assertEquals(await verifyInternalCronToken(configured, "wrong-token"), false);
});

Deno.test("rejects a token that only differs in length (no early-exit false positive)", async () => {
  assertEquals(await verifyInternalCronToken(configured, "sched-cron-secre"), false);
  assertEquals(await verifyInternalCronToken(configured, "sched-cron-secretX"), false);
});

Deno.test("rejects a missing header (null)", async () => {
  assertEquals(await verifyInternalCronToken(configured, null), false);
});

Deno.test("rejects an empty-string header", async () => {
  assertEquals(await verifyInternalCronToken(configured, ""), false);
});

// FAIL CLOSED — the whole point of this module: an unset server-side secret
// must NEVER authorize, for ANY provided value, unlike the webhook's stub
// mode (which deliberately accepts everything when unconfigured for local
// dev). There is no equivalent escape hatch here.
Deno.test("FAIL CLOSED: unset server token never authorizes, even with a non-empty provided token", async () => {
  assertEquals(await verifyInternalCronToken(unconfigured, "sched-cron-secret"), false);
  assertEquals(await verifyInternalCronToken(unconfigured, "anything-at-all"), false);
});

Deno.test("FAIL CLOSED: unset server token + empty/null provided token also never authorizes", async () => {
  assertEquals(await verifyInternalCronToken(unconfigured, ""), false);
  assertEquals(await verifyInternalCronToken(unconfigured, null), false);
});

Deno.test("loadCommunicationCronConfig: unset env yields token=null (fail-closed by default)", () => {
  const prev = Deno.env.get("INTERNAL_CRON_TOKEN");
  Deno.env.delete("INTERNAL_CRON_TOKEN");
  try {
    assertEquals(loadCommunicationCronConfig(), { token: null });
  } finally {
    if (prev !== undefined) Deno.env.set("INTERNAL_CRON_TOKEN", prev);
  }
});

Deno.test("loadCommunicationCronConfig: empty-string env is treated as unset (token=null)", () => {
  const prev = Deno.env.get("INTERNAL_CRON_TOKEN");
  Deno.env.set("INTERNAL_CRON_TOKEN", "");
  try {
    assertEquals(loadCommunicationCronConfig(), { token: null });
  } finally {
    if (prev === undefined) Deno.env.delete("INTERNAL_CRON_TOKEN");
    else Deno.env.set("INTERNAL_CRON_TOKEN", prev);
  }
});

Deno.test("loadCommunicationCronConfig: reads a configured token from env", () => {
  const prev = Deno.env.get("INTERNAL_CRON_TOKEN");
  Deno.env.set("INTERNAL_CRON_TOKEN", "from-env-secret");
  try {
    assertEquals(loadCommunicationCronConfig(), { token: "from-env-secret" });
  } finally {
    if (prev === undefined) Deno.env.delete("INTERNAL_CRON_TOKEN");
    else Deno.env.set("INTERNAL_CRON_TOKEN", prev);
  }
});
