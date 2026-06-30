// QA-C-012 — Email / SendGrid channel BEHAVIOUR certification.
//
// No email test existed before this row. Certifies the email channel's DB-free
// attributes WITHOUT a live SendGrid call:
//
//   stub/delivery → in STUB mode the channel succeeds and returns an
//                   `email_stub_*` provider ref (the value persisted as
//                   `notification_deliveries.provider_ref` on 'sent') — audit
//                   evidence that the send was attempted/recorded,
//   recipient/template/destination → the SendGrid v3 request body it would POST
//                   carries `to` (recipient), `from` (sender), `subject`
//                   (rendered template subject) and the plain-text `body`. This
//                   is asserted by capturing `fetch` (swapped out — NO real
//                   network egress) with a fake API key,
//   fail-closed → an unconfigured live channel (no key / no from-email) returns
//                 an error and never sends.
//
// INFRA-BLOCKED (honestly marked): the live SendGrid HTTPS POST to
// api.sendgrid.com/v3/mail/send (real API key, real x-message-id receipt and
// inbox deliverability) is not exercisable in this lane. The request CONTRACT
// (url, auth header, payload) is certified here against a captured fetch; the
// real network leg runs on the live email lane.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { sendViaProvider, type DeliveryPayload } from "./notification_providers.ts";
import type { NotificationProviderConfig } from "./notification_provider_config.ts";

const RECIPIENT_EMAIL = "parent@example.com";
const FROM_EMAIL = "no-reply@akshara.school";

function emailPayload(): DeliveryPayload {
  return {
    channel: "email",
    recipientUserId: RECIPIENT_EMAIL,
    subject: "Fee receipt — Asha (Class 3A)",
    body: "Dear parent, we received ₹4,200 for Asha. Your receipt is in the app.",
  };
}

function baseConfig(): NotificationProviderConfig {
  return {
    sms: { stubMode: true, accountSid: null, authToken: null, fromNumber: null },
    email: { stubMode: true, apiKey: null, fromEmail: null },
    push: { stubMode: true, configured: false },
  };
}

// --- stub mode: delivery status + provider ref (audit) -----------------------

Deno.test("QA-C-012 email in stub mode succeeds with an email_stub provider ref (no network)", async () => {
  const result = await sendViaProvider(baseConfig(), emailPayload());
  assertEquals(result.success, true);
  assertEquals(result.error, null);
  assert(result.providerRef !== null);
  // the ref persisted as notification_deliveries.provider_ref when marked 'sent'.
  assert(result.providerRef!.startsWith("email_stub_"));
});

// --- live-shape (captured fetch, NO real egress): payload to/from/subject/body -

Deno.test("QA-C-012 SendGrid request carries to / from / subject / plain-text body", async () => {
  const original = globalThis.fetch;
  let capturedUrl: string | undefined;
  let capturedInit: RequestInit | undefined;
  globalThis.fetch = ((url: string | URL | Request, init?: RequestInit) => {
    capturedUrl = String(url);
    capturedInit = init;
    // SendGrid returns 202 Accepted with an x-message-id receipt header.
    return Promise.resolve(
      new Response(null, { status: 202, headers: { "x-message-id": "sg-msg-123" } }),
    );
  }) as typeof fetch;

  try {
    const cfg = baseConfig();
    cfg.email = { stubMode: false, apiKey: "SG.fake-key", fromEmail: FROM_EMAIL };
    const result = await sendViaProvider(cfg, emailPayload());

    // destination + auth
    assertEquals(capturedUrl, "https://api.sendgrid.com/v3/mail/send");
    const headers = capturedInit?.headers as Record<string, string>;
    assertEquals(headers.Authorization, "Bearer SG.fake-key");

    // payload: recipient, sender, rendered subject, plain-text body
    const sent = JSON.parse(String(capturedInit?.body)) as {
      personalizations: { to: { email: string }[] }[];
      from: { email: string };
      subject: string;
      content: { type: string; value: string }[];
    };
    assertEquals(sent.personalizations[0].to[0].email, RECIPIENT_EMAIL);
    assertEquals(sent.from.email, FROM_EMAIL);
    assertEquals(sent.subject, "Fee receipt — Asha (Class 3A)");
    assertEquals(sent.content[0].type, "text/plain");
    assertEquals(
      sent.content[0].value,
      "Dear parent, we received ₹4,200 for Asha. Your receipt is in the app.",
    );

    // delivery status: the x-message-id receipt becomes the provider ref.
    assertEquals(result.success, true);
    assertEquals(result.providerRef, "sg-msg-123");
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("QA-C-012 email subject defaults to 'Akshara ERP' when none is rendered", async () => {
  const original = globalThis.fetch;
  let capturedInit: RequestInit | undefined;
  globalThis.fetch = ((_url: string | URL | Request, init?: RequestInit) => {
    capturedInit = init;
    return Promise.resolve(new Response(null, { status: 202 }));
  }) as typeof fetch;

  try {
    const cfg = baseConfig();
    cfg.email = { stubMode: false, apiKey: "SG.fake-key", fromEmail: FROM_EMAIL };
    const payload = emailPayload();
    payload.subject = null; // some categories enqueue body-only
    await sendViaProvider(cfg, payload);
    const sent = JSON.parse(String(capturedInit?.body)) as { subject: string };
    assertEquals(sent.subject, "Akshara ERP");
  } finally {
    globalThis.fetch = original;
  }
});

// --- fail-closed when the live channel is unconfigured -----------------------

Deno.test("QA-C-012 live email channel fails closed when api key / from-email missing", async () => {
  const cfg = baseConfig();
  cfg.email = { stubMode: false, apiKey: null, fromEmail: null };
  const result = await sendViaProvider(cfg, emailPayload());
  assertEquals(result.success, false);
  assertEquals(result.providerRef, null);
  assert((result.error ?? "").includes("not configured"));
});
