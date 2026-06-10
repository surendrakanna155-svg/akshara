# Production Security Checklist

**Version:** 1.0 (v7.7)

---

## Authentication

- [ ] `APP_ENV=production` on Edge Function
- [ ] `AUTH_OTP_DEV_MODE=false` in production
- [ ] Flutter `disableDemoAuth=true` (production `Environment`)
- [ ] JWT secret ≥ 32 chars, rotated quarterly
- [ ] Refresh token reuse detection enabled (client v2.7+)

## Authorization

- [ ] Server handler RBAC on all write routes
- [ ] RLS FORCE on tenant tables (`erp_tenant` NOBYPASSRLS)
- [ ] Tenant isolation probes **213/213** pass
- [ ] Client route guards match server permission slugs (33 permissions)

## Network

- [ ] API base URL uses HTTPS only (`requireTls` in production)
- [ ] CORS limited to known origins (review Supabase + CDN)
- [ ] Internal health endpoints require `x-internal-health-token`

## Audit & compliance

- [ ] Audit batch ingestion live (`POST /audit/events/batch`)
- [ ] Mutation audit on admissions/finance/SIS/academic/payment (v7.3.2)
- [ ] Denied-access audit events on route guards

## Integrations

- [ ] Razorpay webhook HMAC verified in live mode
- [ ] No stub payment signatures accepted in production
- [ ] Communication stub flags disabled when going live

## Operational

- [ ] Penetration test completed or scheduled
- [ ] Secrets not in repository
- [ ] Backup + restore runbooks reviewed
- [ ] Incident response contact list filled

## Build gates (CI)

- [ ] `flutter analyze` = 0
- [ ] `flutter test` all passing
- [ ] Deno `_shared/` tests passing
- [ ] Probe count validation tests expect **213**
