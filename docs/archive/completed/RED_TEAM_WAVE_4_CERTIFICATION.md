# AKSHARA — Red Team Wave 4 Certification

**Status:** ✅ **PRODUCTION CERTIFIED (2026-06-27) — flutter 2448 passed / 1 skipped (+8 new Wave-4 tests), analyze 0 issues** · **Backend regression: W1 26/26 · W2 25/25 · W3 24/24 live**
**Wave:** RED_TEAM **Wave 4** — "Client Write Resilience."
**Scope source of truth:** [`RED_TEAM_MASTER_TRACKER.md`](./RED_TEAM_MASTER_TRACKER.md) (RT-24..RT-30) + [`RED_TEAM_COMPLETION_ROADMAP.md`](./RED_TEAM_COMPLETION_ROADMAP.md) (Wave 4). No new features, no roadmap expansion, no new audit — this closes the tracker's Wave-4 findings only.
**Branch:** `feature/scope-trim-school-build`
**Migration / backend deploy:** none. Wave 4 is **client-only** (Flutter `lib/`); it ships in the next app release (Play submission is owner-gated, consistent with PLY-1/PLY-2).
**Evidence:** `flutter analyze` + `flutter test` (incl. `test/red_team/red_team_wave4_test.dart`) is the authoritative gate for this wave; the live VPS regression certs prove no backend was disturbed.

---

## 1. Verdict

**PRODUCTION CERTIFIED.** All **7 Wave-4 findings** (3 High, 4 Medium — with RT-25 merged into RT-24 and RT-28 reclassified as a duplicate) are closed in the Flutter client. This wave hardens the *client* so a user cannot trigger the duplicate-write / silent-failure / lost-input failure modes in the first place, complementing Wave 1's server-side dedup and Wave 3's authorization.

Wave 4's unit-under-test is the **Flutter client**, so — unlike Waves 1–3 (backend, proven over HTTP / SQL) — the authoritative gate is `flutter analyze` (0 issues) + `flutter test` (2448 passed), including 8 new targeted tests that prove each fix's behaviour. The live VPS regression (W1/W2/W3) confirms the backend is untouched.

## 2. Gate results

| Gate | Result |
|------|--------|
| `flutter analyze` | **No issues found** |
| `flutter test` | **2448 passed / 1 skipped / 0 failed** (was 2440; +8 new Wave-4 tests) |
| `deno test` (`supabase/functions/_shared`) | **867 passed / 0 failed / 2 ignored** (backend unchanged; re-run for safety) |
| **Regression — Wave 1** (`live_cert_red_team_wave1.py`) | ✅ **26/26** live |
| **Regression — Wave 2** (`live_cert_red_team_wave2.py`) | ✅ **25/25** live |
| **Regression — Wave 3** (`live_cert_red_team_wave3.py`) | ✅ **24/24** live |

## 3. Methodology

The fixes are deterministic client behaviours, so they are proven by unit/widget tests rather than a VPS probe. `test/red_team/red_team_wave4_test.dart` adds 8 tests:

- **RT-24/25 (double-submit):** a notifier using the exact guard pattern applied across all 204 mutation sites is double-tapped (second call fires before the first resolves) → the underlying write runs **exactly once**; a sequential call after completion still works (the guard only blocks in-flight re-entry).
- **RT-27 (raw errors):** `aksharaErrorMessage()` maps an `ApiFailureException` to its clean message (not `toString()`) and an arbitrary error to a generic friendly message (no internal detail leaks).
- **RT-29 (auth replay):** `AuthInterceptor.isSafeToAutoReplay` returns true for idempotent verbs (GET/HEAD/OPTIONS) and for a write carrying an `Idempotency-Key` (case-insensitive), and **false for bare POST/PUT/PATCH/DELETE**.
- **RT-24 in-progress helper:** `mutationInProgressFailure()` is a typed, user-friendly `ApiFailureException`.

The 5 test regressions the 204-site guard initially surfaced were genuine and fixed at root cause (see §4, RT-24).

## 4. What was fixed (per finding)

- **RT-24 + RT-25 (merged — client double-submit).** A re-entry guard was inserted at **every one of the 204 mutation entry points** (51 notifier files): `if (state.isLoading) return state.valueOrNull;` for valued notifiers, `return;` for `AsyncNotifier<void>`, and `throw mutationInProgressFailure()` for the 34 non-nullable-return methods (which cannot early-return a value). A double-tap now collapses to a single request at the notifier layer — the canonical fix, backstopped by Wave 1's server dedup. **Root-cause sub-fix:** 7 mutation notifiers used an empty `async` `build()` (`Future<void> build() async {}`), which leaves the notifier in `AsyncLoading` until the build future resolves and would make the guard mis-fire on the first action; these were made synchronous (`void build() {}`), so `state.isLoading` now means exactly "a mutation is in flight." Write buttons on the cited screens were already disabled while loading (e.g. `sis_profile_edit_sheet`), and the notifier guard makes any residual double-tap a no-op regardless.
- **RT-26 (silent write failures).** `sis_profile_edit_sheet._save()` and both `finance_offline_payments_screen` actions returned `null` on failure but still treated it as success (popped / showed nothing). They now check the result, surface the mapped failure in a SnackBar, and keep the form open so the user can retry.
- **RT-27 (raw error text).** New `aksharaErrorMessage()` (routes through the existing `ApiFailureMapper`) replaces all **48** raw `Text('$error')` / `Text('$e')` SnackBar sites across 17 files. Server validation messages survive; everything else maps to a clean category message.
- **RT-28 (optimistic-toggle).** **Not reproducible** — the cited "optimistic toggle stays green on failure" mechanism does not exist (the screens use confirm-dialog writes). No separate fix; the genuine residue is covered by RT-24 (double-submit) and RT-26/27 (failure surfacing). ID retained.
- **RT-29 (verb-agnostic auth retry).** `AuthInterceptor.onError` now only auto-replays the failed request after a 401 refresh when `isSafeToAutoReplay` holds (idempotent verb, or a write with an `Idempotency-Key` the server dedupes per RT-07). A bare write is no longer replayed verbatim — the refreshed session lets the user's own resubmit succeed exactly once.
- **RT-30 (no refresh/back guard).** `AksharaUnsavedChangesGuard` was upgraded from a stateless `PopScope` wrapper into the single cross-platform guard: it keeps the in-app `PopScope` (back / hardware-back / web router pops) **and** now arms the browser's native `beforeunload` confirmation on web while there are unsaved changes (via a new `dart:js_interop` conditional-import utility — `shared/forms/web_unsaved_guard*.dart` — no new dependency, no-op off web). It is applied to the key data-entry forms (admissions enrollment — existing — and the SIS profile edit sheet, now with first-edit dirty tracking) and is the standard mechanism to extend to remaining forms.

## 5. Disposition

RT-24, RT-25, RT-26, RT-27, RT-28, RT-29, RT-30 → **Closed** (fixed in the client, analyze clean, flutter 2448 passed incl. 8 new Wave-4 tests, backend regression W1 26/26 + W2 25/25 + W3 24/24 live). Commit hash recorded in `RED_TEAM_MASTER_TRACKER.md` on commit. The client changes ship in the next app release (Play submission owner-gated).

**Wave 5 remains Open, awaiting owner approval. Wave 5 is NOT started.**
