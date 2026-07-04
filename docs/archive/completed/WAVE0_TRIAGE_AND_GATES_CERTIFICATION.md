# Wave 0 — Triage + Restore Gates — CERTIFICATION

**Status:** ✅ **COMPLETE**
**Date:** 2026-06-25
**Wave:** 0 of `docs/FINAL_COMPLETION_ROADMAP.md` (Prerequisite: triage + restore gates)
**Source of truth:** `docs/FINAL_COMPLETION_AUDIT.md` + `docs/FINAL_COMPLETION_ROADMAP.md`
**Release-review verdict:** **GO** (Engineering ✅ / QA ✅ / Release ✅ — non-deploying gates wave)
**Deploy:** **Not required** — no production edge function, migration, or runtime `lib/` behavior changed.

---

## 1. Scope

Wave 0 is the prerequisite wave: triage the `[verify-vs-deployed-edge]` findings against the live VPS, and restore the quality gates to green + CI-enforced so later waves can be certified cleanly. No feature work, no roadmap change, no new scope.

## 2. Items & evidence

| Item | Action | Result |
|------|--------|--------|
| **0.1** finance triage (STF-1..5, STF-4, INT-2, SUP-2) | Verify contested finance routes against the **deployed VPS edge** (`/opt/akshara/functions`). | Live edge `finance_router.ts` has the **same 16 routes** as source; `payments/offline`, `payments/qr`, `defaulters`, `/reports`, `/settings`, `/scholarships`, and `GET /finance/discounts` are **confirmed absent on production**. → findings are **real**, remain Wave-3 build items; `[verify-vs-deployed-edge]` tag resolved. |
| **0.2** TST-1 SIS asserts | Resolve the 10→11 mock-count drift. | `SIS-STU-PLH-0001` (`isPlaceholder`) is **intended** first-time-onboarding data (rendered specially in `sis_registry_screen.dart`). Asserts updated to 11 in `test/core/repositories/repository_test.dart:59` and `test/features/sis/sis_providers_test.dart:46`. |
| **0.3** TST-2 goldens | Regenerate 5 stale goldens after confirming intended. | Diff confirmed a localized intended design shift (dashboard bottom bar). Regenerated `parent_dashboard_390x844/428x926/834x1194`, `dark_parent_dashboard_390x844`, `dark_admin_hub_834x1194`. Only those 5 masters changed (no churn). |
| **0.4** SEC-7 / PRN-2 deno test | Make `approval_router_test.ts` runnable without live secrets. | Replaced the top-level `loadConfig()` with a **self-contained `AppConfig` literal** — no process-env mutation, so it cannot leak into sibling tests that gate on `SUPABASE_URL`. `tenant_isolation_*` correctly stay ignored. |
| **0.5** analyze cleanup | Restore the 0-issue bar. | **105 → 0** issues. `dart fix` sweep across 53 files (unused/duplicate imports, `prefer_const`, dead null-aware, `value:`→`initialValue:` for 8 deprecated `DropdownButtonFormField`) + 1 manual `if (!context.mounted) return;` guard for the lone `use_build_context_synchronously`. All behavior-preserving (verified by the green suite). |
| **0.6** TST-4 CI enforcement | Ensure CI enforces all three gates on PR. | CI already ran analyze + full `flutter test --coverage` (`flutter_ci.yml`→`scripts/qa/run_ci_gates.sh`) and `deno test` (`backend_staging.yml`). **Hardened** Gate 1 to `flutter analyze --fatal-infos` so the 0-issue bar is enforced and lint drift cannot recur. |

## 3. Gate results (verified by coordinator, 2026-06-25)

| Gate | Before (at audit) | After Wave 0 | Command |
|------|------|------|---------|
| `flutter analyze` | 105 issues | **0 — "No issues found!"** | `flutter analyze` (and `--fatal-infos` → exit 0) |
| `flutter test` | 2376 pass / 1 skip / **7 fail** | **2383 pass / 1 skip / 0 fail** | `flutter test --no-pub` (exit 0) |
| backend `deno test` | 662 pass / **1 fail** | **665 pass / 0 fail / 2 ignored** | `deno test --allow-all` (with typecheck, matches CI) |

## 4. Live VPS verification

- VPS control socket open; container `akshara-edge` **Up**, HTTP server serving (auth-gated 400, not down).
- Deployed edge source (`/opt/akshara/functions`) inspected directly to certify the 0.1 triage — finance route set confirmed real.
- **Nothing deployed** this wave → zero production change, zero rollback risk.

## 5. Continuous checks run

`flutter analyze` (0) · full `flutter test` suite incl. golden/widget/integration/security-RBAC/contract dirs (green) · backend `deno test` incl. tenant-isolation/RBAC/permission suites (green) · live-edge inspection (healthy). Patrol on-device journeys + live-backend E2E were **not** re-run — Wave 0 changed no app runtime behavior, and live-backend journey coverage (TST-3/TST-5) is explicitly scheduled for Wave 5.

## 6. Findings closed by this wave

1 High (TST-1) + 3 Medium (TST-2, TST-4, T-DRIFT) + 2 Low (SEC-7, PRN-2). Audit totals: ~92 → **~86 remaining** (Critical 2, High 20, Medium ~31, Low ~33). 0.1 confirmed (did not close) STF-1..5/STF-4/INT-2 as real Wave-3 items.

## 7. Files changed

- Tests: `test/core/repositories/repository_test.dart`, `test/features/sis/sis_providers_test.dart`, `test/golden/approval_center_golden_test.dart`, `supabase/functions/_shared/approval/approval_router_test.ts`
- Goldens: 5 master PNGs under `test/golden/goldens/`
- Lint sweep: 53 files under `lib/` and `test/` (behavior-preserving)
- CI: `scripts/qa/run_ci_gates.sh` (`--fatal-infos`)
- Docs: this cert + `FINAL_COMPLETION_AUDIT.md` + `FINAL_COMPLETION_ROADMAP.md`

## 8. Verdict

**Wave 0 CERTIFIED COMPLETE.** All exit criteria met. The product's quality gates are green and CI-enforced; the finance contract findings are verified real and correctly scheduled. **Next wave is Wave 1 (Stop silent data loss) — do NOT start automatically.**
