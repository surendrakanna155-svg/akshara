# Production Integrations — Environment Configuration

**Version:** 1.0 (v7.7)  
**Scope:** Razorpay, Communication (Twilio/SendGrid/FCM), OpenAI Copilot

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

- [ ] Razorpay dashboard webhook URL: `https://<project>.supabase.co/functions/v1/api/webhooks/razorpay`
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
| Push (FCM) | `FCM_SERVER_KEY` | `FCM_STUB_MODE=false` |

**Default:** Stub mode is `true` when credentials absent (`notification_provider_config.ts`).

### Production checklist

- [ ] Set all three stub flags to `false`
- [ ] Send test SMS to pilot admin phone
- [ ] Send test email to pilot admin inbox
- [ ] Send test FCM to pilot device token
- [ ] Verify `notification_deliveries` rows show `delivered` (not `stub_*` refs)
- [ ] Audit events emitted on broadcast/send

---

## OpenAI (AI Copilot)

| Secret | Purpose |
|--------|---------|
| `OPENAI_API_KEY` | Live LLM responses |
| `OPENAI_MODEL` | Optional override (default `gpt-4o-mini`) |

### Fallback behaviour (read-only)

When `OPENAI_API_KEY` is absent:

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
