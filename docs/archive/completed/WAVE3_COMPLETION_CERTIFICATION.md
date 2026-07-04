# Wave 3 — Contract Gaps + Entitlement Client + Security Hardening — PRODUCTION CERTIFICATION

**Date:** 2026-06-26
**Status:** ✅ **PRODUCTION CERTIFIED** — live **30/30** vs VPS pilot
**Roadmap:** `docs/FINAL_COMPLETION_ROADMAP.md` Wave 3 (Themes D + I + F)
**Cert script:** `scripts/qa/live_cert_completion_wave3.py`
**Release-review:** see §Release gate.

Real VPS (`https://akshara.veloraunisexsalon.com`) + real Postgres (`akshara_db`)
+ edge-minted JWTs (real RBAC) + real shared-secret HMAC webhook auth.

---

## What was closed (all 13 Wave 3 items)

| ID | Item | Result |
|----|------|--------|
| **SEC-1** | Auth on `POST /communications/delivery/webhook` | Shared-secret **HMAC-SHA256** over the raw body (`x-akshara-signature`); tenant derived from the matched delivery row via the service client (no hardcoded UUIDs). Added `external_id`/`delivered_at` columns + `'delivered'` status — the webhook **could never succeed before** (it queried non-existent columns). Audited. |
| **SUP-1** | Entitlement API client flag | `ENTITLEMENT_API_ENABLED: true` in `config/live_release.json`; entitlement API live (`GET /subscription`, `GET /plans`). |
| **SUP-2** | Super-admin org-plan-assignment | `PUT /platform/organizations/{id}/subscription` assigns a plan (superAdmin **200**, non-super **403**) — unblocked by SUP-1. |
| **STF-4** | `GET /finance/discounts` (read) | Live 200. |
| **STF-1** | Offline-payment record/list/reconcile | Live: record 201 → list contains it → reconcile 200 (migration `finance_offline_payments`). |
| **STF-2** | QR/UPI payment-session routes | Live: create 201 (pending + UPI payload) → get → confirm (migration `finance_qr_sessions`). |
| **STF-3** | defaulters/reports/settings | `GET /finance/defaulters` (real overdue + aging), `GET /finance/reports`, `GET`/`PUT /finance/settings` all live (migration `finance_settings`). |
| **STF-5** | Scholarship create/update | Live: create 201 → update 200 (migration `finance_scholarships`). |
| **INT-2** | Defaulters WhatsApp surface | Each `/finance/defaulters` row carries a real `guardianPhone` (primary guardian) — the shipped `WhatsAppContactButton` is now fed real numbers. |
| **SEC-2** | Audit communication mutations | `emitMutationAudit` on mark-read, mark-all-read, device-token register/unregister, webhook (verified: `deviceTokenRegistered` audit row lands). |
| **SEC-3** | Parent scope/child-ids check | `parent_experience` summary/refresh/printable reject a `studentId` not in `claims.child_ids` (403) for parent scope. |
| **SEC-5** | Audit `handleSaveStep` + `handleResetRoleLayout` | Both write paths now emit a mutation audit. |
| **SEC-4 / SEC-6** | Parent RLS + rbac inventory | Parent-scope SELECT RLS on `intel_parent_guidance_reports` (own children, published only); `rbac_route_inventory` extended with finance peripheral + predictions/director/org-builder/subscriptions/webhook/widgets, with a hardened validation test asserting they stay covered. |

---

## Live evidence (30/30)

```
health 200 · tokens minted (schoolAdmin/no-perm/superAdmin/parent)
STF-4 discounts 200
STF-1 offline record 201 / list contains / reconcile 200
STF-2 QR create 201 / get 200 / confirm 200
STF-3 defaulters 200 (kpis,agingBuckets,defaulters,aiInsight,aiActionLabel) / reports 200 / settings get+put 200
INT-2 defaulters carry guardianPhone
STF-5 scholarship create 201 / update 200
RBAC finance write denied w/o permission 403
SEC-1 webhook: unsigned 401 / wrong-sig 401 / valid-sig passes auth (404 not 401)
SEC-2 device-token register 201 + audit row present
SEC-3 unlinked studentId 403 / linked not-403
SUP-1 GET /subscription 200 / GET /plans 200
SUP-2 superAdmin assign 200 / non-superAdmin 403
SEC-4 parent-scope RLS policy present
=== 30/30 checks passed ===
```

## Gates

- `deno check supabase/functions/api/index.ts` (whole graph) — clean
- `deno test --allow-env --allow-read supabase/functions/_shared/` — **672 passed / 0 failed / 2 ignored** (baseline 665 + 7 new: 5 webhook-auth + 2 rbac-inventory)
- `flutter analyze` — **0 issues** (no Dart changed; only `config/live_release.json`)

## Deployment (live)

- **Edge:** 20 changed `supabase/functions/_shared/*` files synced to `/opt/akshara/functions`; `akshara-edge` recreated with `--no-deps` (dodges the pre-existing broken postgres healthcheck).
- **Migrations (forward-only, idempotent):** `20260801000000_finance_peripheral_routes.sql` (4 RLS tables) + `20260802000000_wave3_security_hardening.sql` (webhook columns/status + parent RLS) applied to `akshara_db`.
- **Secret:** `COMMUNICATION_WEBHOOK_SECRET` set in `/opt/akshara/.env.akshara` (SEC-1 enforcement ON; without it the webhook would run in stub-accept mode).
- Post-deploy smoke: `/health` 200, webhook 401 unsigned, `/finance/defaulters` 401 (route live, not 404).

## Notes / non-gaps

- The pilot org plan was (re)assigned `professional` during the SUP-2 check — matches the standing pilot plan; no change in effect.
- `erp_tenant` no-DELETE respected: all new tables grant SELECT/INSERT/UPDATE only; lifecycle via status flips.
- Owner-gated items remain out of scope for engineering (none in Wave 3).

## Release gate

`/release-review`: see commit. Engineering quality (gates green, conventions matched, additive blast radius), QA evidence (30/30 live N/N with real auth/DB/RBAC), and release safety (forward-only idempotent migrations, secret provisioned, edge recreate recipe) all satisfied → **GO**.
