import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { exportPKCS8, generateKeyPair, importPKCS8 } from "npm:jose";

import {
  _resetFcmTokenCache,
  buildFcmV1Payload,
  fcmProjectId,
  fcmV1Configured,
  loadFcmServiceAccount,
} from "./fcm_v1_client.ts";

const SERVICE_ACCOUNT_ENV = "FCM_SERVICE_ACCOUNT_JSON";

async function fakeServiceAccountJson(): Promise<string> {
  const { privateKey } = await generateKeyPair("RS256", { extractable: true });
  const pem = await exportPKCS8(privateKey);
  return JSON.stringify({
    type: "service_account",
    project_id: "akshara-erp",
    private_key: pem,
    client_email: "fcm@akshara-erp.iam.gserviceaccount.com",
    token_uri: "https://oauth2.googleapis.com/token",
  });
}

Deno.test("not configured without the service-account env", () => {
  Deno.env.delete(SERVICE_ACCOUNT_ENV);
  _resetFcmTokenCache();
  assertEquals(fcmV1Configured(), false);
  assertEquals(loadFcmServiceAccount(), null);
  assertEquals(fcmProjectId(), null);
});

Deno.test("parses a raw JSON service account", async () => {
  Deno.env.set(SERVICE_ACCOUNT_ENV, await fakeServiceAccountJson());
  const sa = loadFcmServiceAccount();
  assertEquals(sa?.projectId, "akshara-erp");
  assertEquals(sa?.clientEmail, "fcm@akshara-erp.iam.gserviceaccount.com");
  assertEquals(fcmV1Configured(), true);
  assertEquals(fcmProjectId(), "akshara-erp");
  // the embedded PEM is a valid RS256 private key (accepted by jose)
  await importPKCS8(sa!.privateKey, "RS256");
  Deno.env.delete(SERVICE_ACCOUNT_ENV);
});

Deno.test("accepts a base64-encoded service account", async () => {
  const json = await fakeServiceAccountJson();
  Deno.env.set(SERVICE_ACCOUNT_ENV, btoa(json));
  assertEquals(loadFcmServiceAccount()?.projectId, "akshara-erp");
  Deno.env.delete(SERVICE_ACCOUNT_ENV);
});

Deno.test("rejects malformed / incomplete service accounts", () => {
  Deno.env.set(SERVICE_ACCOUNT_ENV, "{not json");
  assertEquals(loadFcmServiceAccount(), null);
  Deno.env.set(SERVICE_ACCOUNT_ENV, JSON.stringify({ project_id: "x" }));
  assertEquals(loadFcmServiceAccount(), null);
  Deno.env.delete(SERVICE_ACCOUNT_ENV);
});

Deno.test("buildFcmV1Payload uses v1 message shape with string data", () => {
  const payload = buildFcmV1Payload({
    token: "DEVICE_TOKEN",
    title: "Fee due",
    body: "₹4,200 due 15 Jun",
    data: { route: "/parent/fees", category: "fee", notification_id: "abc" },
  }) as { message: Record<string, unknown> };

  const msg = payload.message;
  assertEquals(msg.token, "DEVICE_TOKEN");
  assertEquals(msg.notification, { title: "Fee due", body: "₹4,200 due 15 Jun" });
  assertEquals(
    (msg.data as Record<string, string>).route,
    "/parent/fees",
  );
  // android high-priority + apns sound present for reliable delivery
  assertEquals((msg.android as Record<string, unknown>).priority, "HIGH");
  assertEquals(typeof msg.apns, "object");
});
