# Batch 2 — Real, Safe Login (deployed & verified)

Date: 2026-06-23. Live edge: **https://akshara.veloraunisexsalon.com**.

## What changed
Login was previously "dev-OTP for everyone" (code returned in the response, no
real SMS, no rate limiting). Batch 2 makes it production-safe:

1. **Real SMS delivery** via Fast2SMS. New module
   `supabase/functions/_shared/sms_provider.ts` (provider-agnostic; Fast2SMS
   implemented). Default route `q` (Quick SMS — works without DLT/website
   verification). `otp` and `dlt` routes are supported for when Fast2SMS
   verification / DLT registration is completed.
2. **Rate limiting** on `/auth/login`. Pure logic in
   `supabase/functions/_shared/otp_rate_limit.ts`:
   - per-phone resend cooldown (`OTP_RESEND_COOLDOWN_SECONDS`, default 60s) → `429 OTP_COOLDOWN` + `Retry-After`
   - per-phone window cap (`OTP_MAX_REQUESTS_PER_PHONE`, default 5/hr) → `429 OTP_RATE_LIMITED`
   - per-IP window cap (`OTP_MAX_REQUESTS_PER_IP`, default 20/hr) → `429 OTP_IP_RATE_LIMITED`
3. **No OTP leak for the public.** Code is returned in the response **only** for
   allowlisted pilot phones (`AUTH_OTP_PILOT_PHONES`) or when `AUTH_OTP_DEV_MODE=true`
   outside production. Global dev mode is now **off** on the VPS.
4. **Audit fields** on `otp_requests`: `ip_address` + `delivery_channel`
   (migration `20260703000000_otp_request_rate_limit_fields.sql`, additive/nullable).

## VPS config (in /opt/akshara/.env.akshara, chmod 600 — secrets never in git)
```
AUTH_OTP_DEV_MODE=false
AUTH_OTP_PILOT_PHONES=+919876543210,+919550055155   # seed + owner
OTP_RATE_WINDOW_SECONDS=3600
OTP_MAX_REQUESTS_PER_PHONE=5
OTP_MAX_REQUESTS_PER_IP=20
OTP_RESEND_COOLDOWN_SECONDS=60
SMS_PROVIDER=fast2sms
SMS_PROVIDER_API_KEY=<fast2sms key>
FAST2SMS_ROUTE=q
```
**Deploy note:** changing `.env.akshara` requires `docker compose up -d
--force-recreate akshara-edge` — a plain `restart` does NOT reload env_file.

## Verified live (2026-06-23)
- Pilot number (`+919876543210`) → OTP in response → verify-otp → access token. ✅
- Real number (`+919550055155`, when non-pilot) → `delivery_channel=sms`, no code
  in response, real SMS delivered. ✅
- Immediate resend → `429 OTP_COOLDOWN`, `Retry-After: 51`. ✅
- No-token read → `401`. Velora + Akshara health → `200` (no regression). ✅
- IP captured from `X-Forwarded-For` (Nginx) into `otp_requests.ip_address`. ✅

## Still open (next steps)
- Fast2SMS **website verification** unlocks the branded `otp` route; **DLT
  registration** (sender id + template) unlocks the highest-deliverability `dlt`
  route (bypasses DND). Flip `FAST2SMS_ROUTE` + set sender/template envs when ready.
- Server-side permission checks on **mutations** (writes) — Batches 3–5.
- Tests: `sms_provider_test.ts`, `otp_rate_limit_test.ts` (18 unit tests green).
