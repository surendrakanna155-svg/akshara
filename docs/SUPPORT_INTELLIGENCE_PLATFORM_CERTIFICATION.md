# Akshara AI Support Intelligence Platform (ASIP) — LIVE CERTIFICATION

**Status:** ✅ **PRODUCTION CERTIFIED (2026-07-20)**
**Roadmap:** PROGRAM ASIP (`docs/roadmap/AKSHARA_CONSTITUTION_ALIGNED_MASTER_ROADMAP.md` §5.6), ASIP-1…8. Design authority: `docs/support-intelligence/ASIP_DESIGN.md`.
**Live cert:** `scripts/qa/live_cert_asip_vps.sh` — **18/18 PASS** on the VPS **test** stack (`akshara-edge-test` / `akshara_tenant_test`) AND **18/18 PASS** as a **production smoke** against the live edge (`akshara-edge` / `akshara_db` / `https://akshara.veloraunisexsalon.com`). Real edge, real Postgres, real HS256 JWTs, real RBAC, real governed AI gateway. Non-destructive (probe tenant + marker + full cleanup; verified 0 residue).

---

## Scope & gap

New isolated parallel workstream: **customer schools report Akshara product issues to the Akshara Support Team**, investigated at scale with AI assistance. NOT the school's internal complaint system; NOT the `control_center` mock (which was a read-only stub). Reuse-first — **zero** new RBAC / Audit / Storage / Notification / Ticket engines; extends the platform primitives + the governed AI gateway.

## What was built

**Backend (edge module `supabase/functions/_shared/support/`, wired into `api/app.ts`):**
- **Phase 1 (within-tenant):** report incident (description + screenshot only) → automatic **PII-minimized evidence snapshot** (client context, breadcrumbs, recent API calls, the reporter's audit events, deterministic diagnostics — emails/phones masked, audit metadata dropped) → **deterministic-first AI Incident Package** (category/severity/root-cause/next-steps) via `callModelGateway` (spend-cap/rate/cache/timeout/telemetry/fallback; AI drafts, a human approves) → conversation + attachments (first real client binary-upload pipeline) + guarded status lifecycle. Reporter-privacy hardened (internal notes/AI activity never surface to the reporter timeline).
- **Phase 2 (cross-tenant, Owner Decision A1 — mirror):** a fixed `PLATFORM_ORG` (`a5100000-0000-4000-8000-000000000001`) receives a PII-min snapshot via **3 `SECURITY DEFINER` bridges** — `app_support_mirror_incident` / `app_support_mirror_evidence` take the source org/school from the **session GUC (never a parameter)**, so a school can only mirror its OWN incident; `app_support_propagate_resolution` asserts the caller **IS** `PLATFORM_ORG` before writing a resolution back (and enqueues the reporter's "resolved" notification). The mirror tables' RLS reads only when `app_current_tenant_id() = PLATFORM_ORG` → a school session can never read the mirror; support reads only the mirror, never a school tenant table. **Org wall intact.**
- **Support console API `/support/platform/*`** (`PLATFORM_ORG` + `platformSupport`): queue / detail / assign / support-status / escalate / notes + deterministic **clustering** ("investigate once, resolve many": category+module+error-signature fingerprint → shared cluster, auto-linked on first support view; resolve-a-cluster propagates to every affected school) + **AI cross-incident investigation** (deterministic-first + governed gateway) + deterministic **engineering-handoff** export.

**Clients:** Flutter `lib/features/support/` + `lib/core/observability/incident_*` (report + automatic context capture + upload + conversation). React `web/src/pages/support-console/` (Owner Decision B1 — scoped unfreeze; the frozen ERP viewer untouched).

**Migrations (band `20260920000000+`, additive, `ENABLE`+`FORCE` org+school RLS, `erp_tenant` grants):** `…000000` incident core · `…000010` evidence+AI · `…000020` attachments+bucket · `…000030` permissions · `…000040` platform mirror + bridges · `…000050` resolution-notify. Applied + **ledgered** on `akshara_db` (head → `20260920000050`).

## Live certification evidence (18/18, run 2026-07-20)

| Check | Result |
|---|---|
| report:create (`SUP-…`, HTTP 201) | PASS |
| report:auto-categorized (`permission_rbac` from the 403 signal) | PASS |
| evidence:auto-collected (all 5 kinds in the DB) | PASS |
| **mirror:incident-written** (SECURITY DEFINER bridge) | PASS |
| mirror:evidence-written (5) | PASS |
| **mirror:source-org-from-session (not forgeable)** | PASS |
| ai-package:assemble (`ai_enriched` — real model call on prod) | PASS |
| rbac:reporter-cannot-analyze (403) | PASS |
| rbac:reporter-cannot-see-console (403) | PASS |
| console:queue-lists-mirror | PASS |
| console:detail+auto-cluster | PASS |
| console:ai-investigate | PASS |
| console:engineering-handoff | PASS |
| console:internal-note | PASS |
| console:resolve | PASS |
| **resolve:propagated-to-school** | PASS |
| **resolve:school-notified** | PASS |
| cleanup:non-destructive (0 residue verified) | PASS |

This covers all 9 owner production-smoke items: school issue reporting · automatic evidence collection · AI Incident Package · cross-tenant mirror · support-console workflow · engineering handoff · incident clustering · school notification · resolution workflow.

## Persistence & constraints

- **`erp_tenant` no-DELETE** on the append-only support tables holds; the mirror bridges rely on the definer OWNER bypassing RLS — the pilot applies migrations as `supabase_admin` (superuser + BYPASSRLS, verified), so the bridges write correctly while `erp_tenant` (NOBYPASSRLS) reads stay RLS-enforced.
- **Deploy shape:** additive onto the deployed `data-reliability-platform` head (897) — net-new `_shared/support/*` + a 2-line `app.ts` route registration + a `storage_service.ts` append; DRP security/red-team code is untouched (backups on the VPS: `*.asip-bak-*`).
- **Support-staff accounts:** 4 principals (Support Admin/L1/L2/Engineer) seeded with **non-dialable sentinel phones** — RBAC-ready; the owner sets real phone numbers to enable OTP login, and adds staff by granting the `aksharaSupport` role on `PLATFORM_ORG`.

## Two live bugs found + fixed by certification (evidence the cert is real)

1. **Audit-evidence portability** — the collector imported a PRA-only `listAuditEvents` absent from the deployed DRP base (would crash the edge on load; caught by `deno check` pre-restart). Now queries `audit_events` directly, best-effort. (`fix(asip): make audit-evidence collection self-contained`.)
2. **Gateway transaction isolation** — the model-gateway call ran inside the analysis write-transaction; a gateway-side DB error aborted the transaction and failed `insertAnalysis`. Now the gateway runs in its own nested transaction. (`fix(asip): isolate the model-gateway call in its own transaction`.)

Both were caught **live** (not by unit tests) and fixed before production — exactly why the Constitution requires evidence-based live certification.
