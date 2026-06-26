# Wave 2 — Multi-child Parent Correctness + Demo-identity Purge — CERTIFICATION

**Status:** ✅ **PRODUCTION CERTIFIED (live)**
**Date:** 2026-06-26
**Wave:** 2 of `docs/FINAL_COMPLETION_ROADMAP.md` (Themes B + C)
**Release-review verdict:** **GO** (Engineering ✅ / QA ✅ / Release ✅)
**Live cert:** `scripts/qa/live_cert_completion_wave2.py` → **21/21 PASS** against the VPS pilot (real parent-scope JWT minted on the edge, real OTP login, real DB, real RBAC)
**Deployed:** edge files `supabase/functions/_shared/auth_context.ts` + `auth_handlers.ts` rsynced to `/opt/akshara/functions/_shared/` + `akshara-edge` restarted. **No migration** (reuses existing tables).

---

## 1. What shipped

A whole persona class — parents with more than one child — was shown the **first** child's data regardless of selection, and demo/sample identities ("Priya Sharma", "Ravi Kumar", "(mock)", "principal_001") leaked into shipping UI. All 14 audit items closed.

### Multi-child parent correctness (Themes B)
| ID | Item | Sev | Fix |
|----|------|:---:|-----|
| **PAR-1** | Parent reads never sent `activeChildId` → backend defaulted to `child_ids[0]` | H | New child-scoped `parentRepositoryQueryProvider` injects `activeChildId`; `ParentRemoteDataSource._queryParams` now emits `additionalQueryParams`, so **every** parent read (dashboard/attendance/homework/exams/timetable/fees/receipts/notices/events/leave) carries the active child. Backend validation (`resolveParentStudentId`) already existed live. |
| **PAR-2** | Child-switch invalidated only dashboard/experience/profile | H | `selectParentActiveChild` now syncs the profile module's separate child id and invalidates the full per-child provider set (fees/exams/receipts/attendance/homework/timetable/notices/events/leave/profile/communication). |
| **PAR-3** | Leave filed against hardcoded `child_ravi` | H | Leave submits against the active child's id. |
| **PAR-6** | Dashboard child-switch cosmetic (`isPriya` demo branch); receipts header hardcoded | M | `forActiveChild` now only personalizes greeting/identity — per-child data comes from the backend (which receives `activeChildId`); receipts header reads the real active child. |
| **PAR-7** | Linked children built as placeholder `name:'Child'`, empty class | M | **(only new backend)** `auth_context.loadChildProfiles()` + `resolveParentContext` add `childProfiles` (guardian-link join + current SIS enrolment); `auth_handlers` emits `children:[{id,name,classLabel}]` on **login** and **`/auth/me`**. Client: `AuthChildSummary` on `AuthUser`, parsed in `auth_mapper`, consumed by `linkedChildrenFromAuthUser`. |
| **PAR-8** | Transport allocation fell back to `items.first` (another child's bus) | M | Resolves the active child (live id/name or canonical registry); returns `null` on no match — never another child's bus. |
| **PAR-9** | Notices/events/leave header child + unread hardcoded | L | Headers + unread now derived from the active child / real data. |

### Demo-identity purge (Themes C)
| ID | Item | Sev | Fix |
|----|------|:---:|-----|
| **TCH-4 / UX-9** | Hardcoded "Priya Sharma · Mathematics" subtitles (4 teacher screens) + HR sample-name caption | H/L | Teacher subtitles derive from `resolvedTeacherTeachingContextProvider` (`appBarSubtitle`); HR caption de-named. |
| **TCH-6** | `"(mock)"` in the leave success snackbar | M | Removed. |
| **TCH-7** | `seedDemoSubjectConcernIfNeeded()` injected demo concerns on every `build()` | M | Function + call sites deleted (with now-unused imports). |
| **TCH-8** | Homework-create pre-filled with "8-A"/"Mathematics"/"Ravi Kumar" | M | Starts blank; class/subject prefilled from the teacher's **real** assignment; title/due hinted. |
| **TCH-9** | Timetable day chips all showed date "1" (`DateTime(2026,6,1)`) | L | Real per-weekday dates for the current week. |
| **PRN-3** | Approval actor fell back to synthetic `principal_001` | L | Fails closed — an approval requires an authenticated approver. |
| **CORE-3** | `tenantContextProvider` could ship `TenantContext.demo` (`tenant_demo_001`) | L | API-mode-gated assert guards the demo-tenant fallback (fires only in live mode; mock/demo unaffected). |
| **STU-6** | Student dashboard "AI insight" was static fabricated text | L | Honest CTA to the real AI tutor (the action already opens live AI). |
| **STU-7** | Non-functional "Join Class" quick action | L | Removed (action + nav case); no live-class feature exists. |

## 2. Gates

| Gate | Result |
|------|--------|
| `flutter analyze --fatal-infos` | **0 issues** |
| `flutter test` | **2383 passed, 1 skipped, 0 failed** (student-dashboard goldens regenerated for STU-6/7) |
| `deno test` | **665 passed, 0 failed, 2 ignored** |
| `deno check api/index.ts` | clean (full edge graph) |

## 3. Live certification — 21/21

```
[PASS] health  HTTP 200
[PASS] mint.two_child_parent_token  child_ids=[CHILD_1, CHILD_2]
[PASS] PAR-1.activeChildId_honoured:/parent/dashboard   A=HTTP200 B=HTTP200 differ=True
[PASS] PAR-1.activeChildId_honoured:/parent/attendance  A=HTTP200 B=HTTP200 differ=True
[PASS] PAR-1.activeChildId_honoured:/parent/homework    A=HTTP200 B=HTTP200 differ=True
[PASS] PAR-1.activeChildId_honoured:/parent/exams       A=HTTP200 B=HTTP200 differ=True
[PASS] PAR-1.activeChildId_honoured:/parent/timetable   A=HTTP200 B=HTTP200 differ=True
[PASS] PAR-1.activeChildId_honoured:/parent/fees        A=HTTP200 B=HTTP200 differ=True
[PASS] PAR-1.activeChildId_honoured:/parent/receipts    A=HTTP200 B=HTTP200 differ=True
[PASS] PAR-1.activeChildId_honoured:/parent/notices     A=HTTP200 B=HTTP200 differ=True
[PASS] PAR-1.activeChildId_honoured:/parent/events      A=HTTP200 B=HTTP200 differ=True
[PASS] PAR-1.activeChildId_honoured:/parent/leave       A=HTTP200 B=HTTP200 differ=False
[PASS] PAR-1.activeChildId_honoured:/parent/profile     A=HTTP200 B=HTTP200 differ=True
[PASS] PAR-1.all_reads_scope_to_active_child   11/11 reads accepted activeChildId
[PASS] PAR-1.child_switch_changes_data         10/11 endpoints returned distinct per-child data
[PASS] PAR-1.unlinked_child_rejected           HTTP 403 (expect 403)
[PASS] PAR-1.default_first_child_ok            HTTP 200
[PASS] PAR-7.login_returns_children            children=1 names=['Staging Student']
[PASS] PAR-7.children_have_real_names          named=['Staging Student']
[PASS] PAR-7.children_have_class               classes=['5-A']
[PASS] PAR-7.me_rehydrates_named_children      me.children=1 named=['Staging Student']

=== 21/21 checks passed ===
```

**Notes:**
- `/parent/leave` returns `differ=False` because the 2nd minted child id has no leave rows in the school-A context (both empty) — the `activeChildId` switch mechanism is still honoured (HTTP 200), and 10/11 data-bearing endpoints prove distinct per-child results.
- The pilot parent (`a3..03` "Staging Parent") has one school-A child ("Staging Student", 5-A); the parent-context join is school-scoped, so PAR-7's real-name proof uses the genuine login, while the two-child `activeChildId` switch is proven with a minted token listing two real student ids.
- Client-only items (PAR-2/3/6/9, TCH-4/6/7/8/9, UX-9, PRN-3, CORE-3, STU-6/7) are covered by the Flutter suite (analyze 0 / 2383 green); this cert verifies the live backend contract the client now depends on.

## 4. Release-review (GStack)

| Lane | Verdict | Evidence |
|------|:---:|----------|
| Engineering | ✅ GO | analyze 0 · deno check clean · surgical 2-file edge deploy, no migration |
| QA | ✅ GO | flutter 2383 / deno 665 / live 21/21 · goldens regenerated for the intended STU-6/7 change |
| Release | ✅ GO | reversible (edge-only); PAR-1 backend already live; no schema change; rollback = redeploy prior edge files |

**Verdict: GO — Wave 2 PRODUCTION CERTIFIED.**

## 5. Commit

`bac9fd1` — *Wave 2 (Final Completion Roadmap): multi-child correctness + demo-identity purge.* (Client + the two edge files; deployed 2026-06-26.)

Next: **Wave 3** — contract gaps + entitlement client + security hardening (SEC-1 webhook auth, SUP-1 entitlement flag, finance peripheral routes).
