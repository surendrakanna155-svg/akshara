# W0 — Lane Convergence — CERTIFICATION

**Status:** ✅ **CONVERGED + VALIDATED (2026-07-20)**
**Canonical trunk:** `integration/w0-canonical` @ `42aa7322` (pushed to `origin`).
**Authorization:** Owner (2026-07-20) — "canonical baseline = deployed production head; preserve deployed ASIP; reconcile into one trunk; conflicts conservative, prefer production-certified; preserve certs/migration-order/audit/security/rollback/tenant-isolation; run the full validation + cert suite."

---

## What converged

One canonical trunk unifying every production-certified line:

| Line | Content | State going in |
|---|---|---|
| **base** (`feature/qp-content-readiness`) | full ERP + QIE + web | committed (W0.1) |
| **PRA** (`feature/erp-pra-remediation`) | 117 fixes / all 24 P0s | engineering-certified |
| **DRP** (`feature/data-reliability-platform`) | red-team R1–7 + P5 security + auth-RLS lockdown | **DEPLOYED to pilot** (baseline) |
| **ASIP** (`feature/asip-support-intelligence`) | AI Support Intelligence Platform | **PRODUCTION CERTIFIED** |

**Topology finding:** `integration/w0-trunk` already contained the deployed **DRP** baseline (0 commits missing), **PRA** (fully contained), and the ERP/QIE/web base + `web`(155)/`QIE`(90) — the DRP↔PRA↔base reconciliation was already done. The **only remaining line was ASIP**, so W0 completed by merging ASIP into that trunk.

## Conflict resolution (conservative, additive — nothing dropped)

10 files touched by the ASIP merge; 7 auto-merged; **3 resolved as additive unions**, preferring production-certified code on both sides:
- `lib/core/security/permissions.dart` — kept PRC-A/attendance permissions **and** added `viewSupport`/`manageSupport`.
- `pubspec.yaml` — kept attendance/face-ID deps **and** added `image_picker`/`package_info_plus`/`device_info_plus`.
- `pubspec.lock` — regenerated (`flutter pub get`) from the reconciled `pubspec.yaml` (lockfiles are never hand-merged).

## Migration reconciliation

Union is **monotonic, no collision** (order preserved): `…20260900000030` (PRA statutory-payroll) · `…000031` (learning-evidence spine) · then `20260920000000–…050` (ASIP). ASIP's band sits cleanly above the trunk head.

## Preservation verified (owner requirements)

- **DRP security preserved:** `session_validation.ts` RT-16/RT-17 present; `red_team_*` migrations present (×2). DRP is an ancestor of the trunk (no commits missing) → nothing reverted.
- **PRA P0s preserved:** identity router (`routeIdentity`), `ai_credit_wallet` + `storage_quota` migrations present.
- **ASIP preserved (deployed infra):** support module (17 files), `support_platform_mirror` migration, `routeSupport` — merged unchanged; the deployed pilot bind-mount + additive edge changes are untouched by this git-only convergence.
- **Migration order / audit history / tenant isolation / rollback:** intact — the trunk descends from the deployed DRP baseline; the merge is additive; no migration renamed/dropped.

## Validation suite (complete, all green)

| Check | Result |
|---|---|
| `deno check` edge app (ASIP + DRP + PRA compile together) | PASS |
| ASIP backend deno tests | 45/45 |
| `flutter analyze` (whole project) | **0 issues** |
| ASIP flutter widget tests | 6/6 |
| Web `npm run build` (incl. support console) | PASS |
| Web `npm test` | **147/147** |
| **ASIP live cert (post-convergence, test stack)** | **18/18** |

## Remaining — OWNER-GATED (not done here)

The convergence is **git-only + validated**; it does **not** re-point `main`/`production` or redeploy the converged trunk to prod (those are high-blast-radius steps the owner has not explicitly authorized, and the deployed pilot is intentionally left running the certified DRP+ASIP state). Remaining owner-authorized steps:
1. Re-point `main` / `production` (or cut a fresh `release/*`) to `integration/w0-canonical`.
2. Redeploy the converged trunk to the pilot (brings PRA's P0 fixes live) — the pilot edge is a **shared bind-mount** carrying the additive ASIP files; any redeploy must preserve them.
3. Prune decisions for the stale/experimental branches (`codex-wave5`, `feature/m15-theme`, `feature/scope-trim-school-build`, `wip/b7-onboarding`, `worktree-agent-*`, stale `main`/`production`).
