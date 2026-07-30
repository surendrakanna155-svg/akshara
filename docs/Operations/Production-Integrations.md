# Production Integrations — Environment Configuration

**Version:** 1.1 (corrected 2026-07-28 against the code that actually reads these vars)  
**Scope:** Razorpay, Communication (Twilio/SendGrid/FCM), AI Copilot

> **Correction note.** Three variable names in v1.0 were wrong, and every one of
> them failed *silently* — the operator sets the documented name, nothing reads
> it, the feature stays stubbed, and no error is raised. Names below were
> verified by grepping `Deno.env.get(...)` across `supabase/functions/`.

---

## Razorpay (Universal Payment Engine)

| Secret | Purpose |
|--------|---------|
| `RAZORPAY_KEY_ID` | Live/test key ID |
| `RAZORPAY_KEY_SECRET` | API secret for order creation |
| `RAZORPAY_WEBHOOK_SECRET` | HMAC verification for webhooks |
| `RAZORPAY_STUB_MODE` | Set `false` in production when keys present |

**Live mode:** `loadRazorpayConfig()` sets `stubMode: false` when key ID + secret exist and `RAZORPAY_STUB_MODE` is not `true`.

### Webhook verification checklist

- [ ] Razorpay dashboard webhook URL: `<POLICY/API HOST>/webhooks/razorpay` — the edge API is served at the ROOT of the VPS host (see `lib/core/config/environment.dart`), NOT at a hosted-Supabase `/functions/v1/` path. There is no hosted Supabase project in the production path.
- [ ] Events enabled: `payment.captured`, `payment.failed`
- [ ] `RAZORPAY_WEBHOOK_SECRET` matches dashboard secret
- [ ] Staging smoke: create order → pay in test mode → webhook creates finance collection (v7.3.2 path)
- [ ] Signature rejection test: POST webhook with invalid signature returns 401/403
- [ ] Tenant resolution: `payment_intents.gateway_order_id` populated before webhook

### Signature validation

- Payment confirm: `verifyRazorpayPaymentSignature()` (live HMAC)
- Webhook: `verifyRazorpayWebhookSignature()` (live HMAC)
- Stub mode accepts `stub_payment_signature` / null signature — **must be disabled in production**

---

## Communication Hub

| Channel | Secrets | Stub flag |
|---------|---------|-----------|
| SMS (Twilio) | `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_NUMBER` | `SMS_STUB_MODE=false` |
| Email (SendGrid) | `SENDGRID_API_KEY`, `SENDGRID_FROM_EMAIL` | `EMAIL_STUB_MODE=false` |
| Push (FCM) | `FCM_SERVICE_ACCOUNT_JSON` | `FCM_STUB_MODE=false` |

**Default:** Stub mode is `true` when credentials absent (`notification_provider_config.ts`).

### Production checklist

- [ ] Set all three stub flags to `false`
- [ ] Send test SMS to pilot admin phone
- [ ] Send test email to pilot admin inbox
- [ ] Send test FCM to pilot device token
- [ ] Verify `notification_deliveries` rows show `delivered` (not `stub_*` refs)
- [ ] Audit events emitted on broadcast/send

---

## AI Copilot (Anthropic, or OpenRouter)

The backend does **not** call OpenAI. `OPENAI_API_KEY` / `OPENAI_MODEL` are read
by nothing — setting them leaves the copilot stubbed with no error.

| Secret | Purpose |
|--------|---------|
| `AI_PROVIDER` | `anthropic` (default) or `openrouter` |
| `ANTHROPIC_API_KEY` | Live LLM responses when `AI_PROVIDER=anthropic` |
| `ANTHROPIC_MODEL` | Optional override (default `claude-opus-4-8`) |
| `OPENROUTER_API_KEY` | Live LLM responses when `AI_PROVIDER=openrouter` |
| `AI_MODEL` | Routed model for OpenRouter (default `anthropic/claude-sonnet-4-6`) |

See `deploy/akshara-vps/.env.akshara.example` for the authoritative block.

### Fallback behaviour (read-only)

When no key is set for the active provider:

- Copilot returns **stub assistant replies** built from ERP context bundle
- System prompt enforces read-only policy (no mutation claims)
- Response metadata includes `stub: true`
- UI shows stub banner in orchestrator output

**Production recommendation:** Configure API key for pilot schools requiring live LLM; document stub mode as acceptable fallback for ops-only deployments.

---

## Internal health (v7.7)

| Secret | Purpose |
|--------|---------|
| `INTERNAL_HEALTH_TOKEN` | Required header `x-internal-health-token` for `/health/tenant-access` and `/health/operations` |

In `APP_ENV=production`, sensitive health endpoints return **403** until this secret is configured.

---

## Supabase secrets deploy example

```bash
supabase secrets set \
  APP_ENV=production \
  RAZORPAY_STUB_MODE=false \
  RAZORPAY_KEY_ID=... \
  RAZORPAY_KEY_SECRET=... \
  RAZORPAY_WEBHOOK_SECRET=... \
  SMS_STUB_MODE=false \
  TWILIO_ACCOUNT_SID=... \
  TWILIO_AUTH_TOKEN=... \
  SENDGRID_API_KEY=... \
  FCM_SERVER_KEY=... \
  OPENAI_API_KEY=... \
  INTERNAL_HEALTH_TOKEN=...
```
