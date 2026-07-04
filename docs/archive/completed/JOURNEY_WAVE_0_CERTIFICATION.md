# AKSHARA — Journey Wave 0 Completion Certification

**Status:** ✅ **PRODUCTION CERTIFIED** (2026-06-26)
**Wave:** MODULE_JOURNEY_ROADMAP **Wave 0** — "Stop showing fake data as real" (live-config drift + demo fallbacks).
**Scope source of truth:** `docs/MODULE_JOURNEY_AUDIT.md` (issue IDs) + `docs/MODULE_JOURNEY_ROADMAP.md` (Wave 0). No new features, no roadmap expansion — this only closes the audit's Wave-0 findings.
**Release-review:** 🟢 **GO** (Engineering ✅ / QA ✅ / Release ✅).
**Live cert:** `scripts/qa/live_cert_journey_wave0.py` → **14/14** against the live VPS pilot (real OTP auth, real RBAC, real DB rows, real entitlement gate).

---

## 1. Verdict

**PRODUCTION CERTIFIED.** All 8 Wave-0 findings (1 Critical, 5 High, 1 Medium, 1 Low) are closed. The three quality gates are green, the three release-config flag flips are **live-certified** to surface real backend data (employee roster, inventory distribution) or correct entitlement gating (predictions), and the demo-fallback removals are proven by gates + code-level live-cert assertions. No backend or migration change was required — Wave 0 is entirely client + release-config.

**Headline trust win:** a real school can no longer be shown fabricated data presented as real — the Employee, Inventory-Distribution and AI-Predictions surfaces now hit their already-deployed live backends, and the Notifications / Finance / Student / Exams screens no longer substitute demo data ("Ravi Kumar", sample grades, "Arjun Patel" refund prefills, fake fee alerts) on empty/loading/error.

---

## 2. Gate results

| Gate | Result |
|------|--------|
| `flutter analyze` | **0 issues** |
| `flutter test` | **2389 passed / 1 skipped / 0 failed** |
| `deno test` | **680 passed / 0 failed / 2 ignored** |
| Live cert (`scripts/qa/live_cert_journey_wave0.py`) | **14/14** vs VPS pilot |

No regressions: the flutter/deno counts are identical to the pre-Wave-0 baseline.

---

## 3. Item-by-item closure

| ID | Module | Sev | What was wrong | Fix | Evidence |
|----|--------|-----|----------------|-----|----------|
| **MJ-C1** | Inventory | 🔴 Critical | Entire inventory-distribution sub-module ran on `MockInventoryDistributionRepository` in live builds — flag never in `live_release.json`/`run_live.sh`. | Added `INVENTORY_DISTRIBUTION_API_ENABLED=true` to `config/live_release.json` + `scripts/run_live.sh`. | Live: `GET /inventory/distribution/dashboard` + `/items` → 200 real UUID rows. |
| **MJ-H1** | AI Features | 🟠 High | Release build served `MockPredictionsRepository` — `PREDICTIONS_API_ENABLED` only in dev `run_live.sh`, not the canonical release manifest. | Added `PREDICTIONS_API_ENABLED=true` to `config/live_release.json`. | Live: `GET /predictions/fee-default` → 402 `PLAN_UPGRADE_REQUIRED(feature.ai_predictions)` — real B9 backend reached + correctly gated (not 404, not mock). Entitled path certified by B9. |
| **MJ-H2** | Staff | 🟠 High | Employee Platform showed `MockEmployeeRepository` roster — `EMPLOYEE_API_ENABLED` missing from `live_release.json`. | Added `EMPLOYEE_API_ENABLED=true` to `config/live_release.json` + `run_live.sh`. | Live: `GET /employees` + `/employees/dashboard` → 200 real UUID rows; dashboard total == list length. |
| **MJ-H3** | Notifications | 🟠 High | Live inbox injected a hardcoded 5-item demo `_fallbackInbox` (fake fee/bus/attendance alerts + fake unread badge) on empty/initial/error. | `_fallbackInbox` is now reachable only via `_mergedInbox()` in **non-API (mock/demo) builds**; the live (API) path resolves to real server items or the real in-app comm-store, and a real empty inbox stays empty. | `notifications_provider.dart` — `_seedInbox()` = `_useApi ? _commStoreInbox() : _mergedInbox()`; refresh success = `items.isEmpty ? _commStoreInbox() : items`; error = `_commStoreInbox()`. Live-cert static assert ✓. |
| **MJ-H4** | Finance | 🟡 Medium | Create Refund / Create Scholarship dialogs pre-filled a fictitious real-looking student ("Arjun Patel", `acct_1`, `₹5,000`, receipt `RCP-2026-0142`) — a money-write data-integrity hazard. | All prefills removed; fields start empty with guiding `hint:` text; required-field validation unchanged. | `finance_workflow_actions.dart` — no residual prefill literals. Live-cert static assert ✓. |
| **MJ-H5** | Student | 🟠 High | Every student screen drove loading/error/empty off manual `StateProvider`s that are never set true in production, so on a real backend error the student silently saw fabricated `StudentDashboardData.mock()` / "Ravi Kumar" data and the `AksharaErrorState`/retry never rendered. | Screens now OR the manual QA flags with the real `FutureProvider` `AsyncValue` (`isLoading = manual \|\| async.isLoading`, `hasError = manual \|\| async.hasError`); AppBar identity/badge guarded behind `async.hasValue`; retry now `ref.invalidate`s the future; provider fallbacks replaced with neutral `.empty()`. | 7 student screen+provider pairs (dashboard/exams/attendance/timetable/profile/homework/notices). `flutter test test/features/student_app` 33/33. |
| **MJ-H6** | Exams | 🟠 High | Parent **and** student exam screens substituted `ParentExamsData.mock()` / "Ravi Kumar" fake grades on a live fetch error, with no error state. | Same async-binding fix applied to `parent_exams_*` + `student_exams_*`; fallbacks → neutral `.empty()`; real errors now show `AksharaErrorState` + working retry. | `parent_exams_provider/screen`, `student_exams_provider/screen`. `flutter test test/features/parent` 67/67. |
| **MJ-L1** | Student | ⚪ Low | Homework header hardcoded "Ravi Kumar · 8-A" (no live identity source). | `studentHomeworkProvider` now sources `studentName`/`classLabel`/`unread` from the real `studentDashboardFutureProvider.value`; header hidden until identity resolves. | `student_homework_provider.dart`. |

---

## 4. What changed (no backend, no migration)

- **Release config:** `config/live_release.json` (+ `scripts/run_live.sh`) — three flag flips. These take effect in a fresh `flutter build --release --dart-define-from-file=config/live_release.json`.
- **Client (Flutter):** `notifications_provider.dart`; `finance_workflow_actions.dart`; 7 `student_app/**` screen+provider pairs; `parent/exams/**` provider+screen; `parent/attendance/attendance_models.dart` (added `.empty()` factory); one test updated to await the dashboard future before reading the homework header.
- **Backend / migrations:** **none.** All three newly-surfaced backends (Employee Platform, Inventory Distribution, B9 Predictions) were already deployed + certified; Wave 0 only stops the client showing mock instead of calling them.

## 5. Persistence & constraints

No new persistence. The newly-enabled reads hit existing tenant-scoped, RLS-enforced tables. Predictions stays behind the `feature.ai_predictions` entitlement (Enterprise) — the Professional pilot correctly receives a 402 upgrade gate rather than fabricated scores. The `.mock()` factories are retained but are now referenced **only** by the mock repositories (non-API builds), factory definitions, and tests — never by a production fallback path.

## 6. Out-of-scope residuals (correctly deferred, not Wave-0 blockers)

- `lib/features/parent/fees/fees_provider.dart` still falls back to `ParentFeesData.mock()` — this is the **parent-fees** persona, sequenced to a later journey wave (static-snapshot read modernization), not part of Wave 0's defined item set.
- Producing/signing the release APK and store submission remain **owner-gated** (existing Wave-5 PLY-1/PLY-2 custody items).

## 7. Live cert evidence

```
=== Journey Wave 0 cert: 14/14 checks passed ===
  [PASS] health  HTTP 200
  [PASS] real pilot OTP auth → school JWT
  [PASS] MJ-H2.employees/dashboard live  totalEmployees=2
  [PASS] MJ-H2.employees list = REAL UUID rows (not mock)  n=2
  [PASS] MJ-H2.dashboard total == real list length
  [PASS] MJ-C1.distribution/dashboard live
  [PASS] MJ-C1.distribution items = REAL UUID rows (not mock)  n=1
  [PASS] MJ-H1.predictions reaches real backend + entitlement gate (HTTP 402, feature.ai_predictions)
  [PASS] config.{EMPLOYEE,INVENTORY_DISTRIBUTION,PREDICTIONS}_API_ENABLED = true
  [PASS] MJ-H4.refund/scholarship dialogs carry no fake-student prefill
  [PASS] MJ-H3.live inbox = real/empty only (demo inbox is mock-build-only)
  [PASS] MJ-H5/H6/L1.student+exam providers carry no 'Ravi Kumar' fallback
```

Script: `scripts/qa/live_cert_journey_wave0.py` (real VPS, pilot OTP auth, read-only).

---

**Next:** Journey Wave 1 — "Data-integrity & money/identity correctness" — is **not** started (per the one-wave-at-a-time rule). Awaiting go-ahead.
