# Web Track — Verified Gaps (Product Verification & Roadmap Sync)

The Unified Web Platform doubles as a **continuous ERP verification & gap-discovery
layer** (owner-locked, 2026-07-16). Every gap discovered while building a web page —
of ANY category — is recorded here as a **verified gap**, classified, prioritized,
and fed into the ERP roadmap / PRC program / Owner Ideas. **Nothing discovered is lost.**

**Categories:** `Bug` · `Missing Feature` · `Architecture` · `UX` · `API` · `Security`
· `Performance` · `Validation` · `RBAC` · `Report` · `Data Contract` · `Audit` · `Integration`.

**Two-way sync (owner-locked):** every gap here is ALSO an official ERP roadmap task
in [`WEB_DISCOVERED_ERP_TASKS.md`](WEB_DISCOVERED_ERP_TASKS.md) (ERP-WT-###). Neither
file may hold a gap the other doesn't. When the ERP lane ships the API, flip status
to 🟢 in BOTH and replace the Web page's interim state with the live wiring.

**Process:** discover while implementing → verify against source (`lib/**` for Flutter
behavior, `supabase/functions/**` for backend — never assumed) → log here AND as an
ERP-WT task → keep building the surrounding UI → disable only the blocked interaction
(render an honest state) → wire fully once the gap is resolved.

Priority: **P0** launch-blocking · **P1** core page blocked · **P2** enhancement.
Status: 🔴 open · 🟡 partial · 🟢 delivered.

| ID | Category | Pri | Status | Gap | Discovered by | Evidence / Notes |
|----|----------|-----|--------|-----|---------------|------------------|
| WEB-001 | API | P1 | 🟢 delivered | **School overview dashboard aggregation** — a single `GET /dashboard/overview` returning school-admin KPIs (students, attendance today, fees MTD, pending admissions), enrolment trend, fee-collection series, attendance-by-section, activity feed, pending approvals. | `/admin/dashboard` | Edge fn `supabase/functions/api/app.ts` routes only per-module + `/intelligence/*`; `/control-center/intelligence/dashboard` is the gated platform-operator layer (out of scope). No school-level aggregation endpoint exists. Page renders "Awaiting backend" until built. |
| WEB-007 | API | P1 | 🟢 delivered | **Finance student-accounts LIST endpoint** — `GET /finance/student-accounts` returns 404; only `/finance/student-accounts/{id}` and `/{id}/ledger` exist. The web Student Accounts page needs a paginated list. | Live validation (`/finance/student-accounts` → 404) | `finance_router.ts` has by-id + ledger only, no list handler. |
| WEB-008 | Bug | P2 | 🟢 delivered | **`GET /academics/exams/progress` returns 500** SERVER_ERROR on the pilot tenant. Marks-progress page blocked. | Live validation | Endpoint exists but throws; needs backend fix. |
| WEB-009 | Bug | P2 | 🟢 delivered | **`GET /school/pilot/dashboard` returns 500** INTERNAL_ERROR. Pilot dashboard blocked. | Live validation | Endpoint exists but throws; needs backend fix. |
| WEB-010 | API | P2 | 🟢 delivered | **Communication analytics endpoints** — `/communications/analytics/{summary,delivery,parent-adoption}` return 404; only `/communications/delivery/metrics` exists. School-completion comms-analytics + parent-activation pages point at delivery/metrics for now; the summary + parent-adoption analytics need exposing. | Live validation | `communication_router.ts` lacks the analytics set. |
| WEB-006 | API | P2 | 🟢 delivered | **Intelligence: Trust dashboard + AI-economics endpoints** — `/intelligence/trust` and `/intelligence/ai-economics` are not exposed (router has priorities/recommendations/risk/student-success/teacher-effectiveness/exam/homework/principal only). Web Trust and AI-Economics pages built, wired to the intended endpoints, rendering the awaiting-backend state. | `/intelligence/trust`, `/intelligence/ai-economics` | `intelligence_router.ts` lacks these two dashboards. |
| WEB-005 | API | P1 | 🟢 delivered | **SIS class-management workflow endpoints** — `/sis/promotion`, `/sis/reshuffle`, `/sis/section-balance` (bulk class-progression / section rebalancing) are not exposed; `/sis/academic-assignment` GET also absent (only options model). Web pages built as workflows over `/sis/students` rosters with the apply-action gated until these exist. | `/sis/promotion`, `/sis/reshuffle`, `/sis/section-balance`, `/sis/academic-assignment` | `sis_router.ts` exposes dashboard/students/transfers/enrollments/admissions-conversion only. |
| WEB-004 | API | P1 | 🟢 delivered | **Inventory stock ledger + stock approvals read API** — no `GET /inventory/stock` or `GET /inventory/stock/approvals` in the edge function, although stock governance (stock_movements ledger, maker-checker for value-reducing stock, valuations) exists in the DB per the INV batch. The web Stock and Stock-Approvals pages are built and wired to the intended endpoints; they render the awaiting-backend state until exposed. | `/inventory/stock`, `/inventory/stock/approvals` | `inventory_router.ts` exposes dashboard/assets/categories/allocations/maintenance/procurement/vendors/reports + intelligence, but no stock endpoints. |
| WEB-003 | Integration | P2 | ⏸ deferred (external) | **Live vehicle GPS tracking** — real-time bus positions/ETAs. Not implemented; the Flutter transport tracking screen uses `TransportTrackingPlaceholderData`. Web tracking page is the real UI shell awaiting the GPS integration (no simulated positions). | `/transport/tracking` | GPS is a Phase-2 item per project scope decisions. `/transport/tracking` endpoint returns placeholder data. |
| WEB-002 | Performance | P2 | 🟢 delivered | **Icon-font weight** — Material Symbols (Rounded) ships as a 4.6 MB variable font, downloaded on first paint. Needs glyph subsetting to the icon set actually used (or switch to per-icon SVGs) to protect first-paint budget. | Foundation build | `dist/assets/material-symbols-*.woff2` = 4,644 kB. Mirrors the "fast perceived performance" goal; not blocking, cached after first load. **(Web-side already mitigated: self-hosted subset 408 kB; this task is the ERP-lane view.)** |
| WEB-011 | Integration / Security | P1 | 🟢 delivered | **API CORS allow-list for the web origin** — the production edge functions do not return `Access-Control-Allow-Origin` for a browser origin, so the web SPA served from any origin other than the API's own cannot call it (all `fetch` fail with `net::ERR_FAILED` / CORS). Backend must (a) emit CORS headers (incl. `Authorization`, custom `X-Tenant-Id`/`X-School-Id`/`X-Api-Version`/`X-User-Id`, and `OPTIONS` preflight) for the approved web origin(s), **or** the web must be served same-origin behind the API gateway. | Final live UI cert — browser fetch from `localhost:4350` CORS-blocked; identical Node fetch (no CORS) returns 200 with rows. | **RESOLVED (verified live 2026-07-17):** the prod edge already applies `corsHeaders` to EVERY response via `withCors` + handles the `OPTIONS` preflight (`api/app.ts:90,253,271`). Live probe: OPTIONS + GET both return `Access-Control-Allow-Origin: *` and `Access-Control-Allow-Headers: authorization, …, x-tenant-id, x-school-id, x-api-version, …`. `*` is correct for a Bearer-token API (no cookies), so the SPA calls the API cross-origin today. Web-side same-origin proxy remains as a hardening option. |

## Live validation (2026-07-17, against production VPS `…/functions/v1/api`)

Authenticated with a pilot phone (dev-OTP returned in-app) and probed **128 GET
endpoints** the web pages consume. **76 returned 200 and matched the web contracts.**
Harness: `web/scripts/live_validate.mjs`.

**Web-path corrections found + FIXED in the web (were my wrong paths, NOT backend gaps):**
- Communication: `/broadcasts` → **`/communications/broadcasts/history`** (200, 13 items). Analytics → `/communications/delivery/metrics` (200).
- Timetable: `/timetables*` → **`/academic/timetables*`** (200). Substitutions now pass `?date=today`.

**403 MODULE_DISABLED (entitlement gating — NOT gaps):** hostel, inventory, alumni,
director are not in the pilot tenant's plan. The web now renders a "Module not enabled"
state (AsyncBoundary handles `MODULE_DISABLED`).

**422 VALIDATION_ERROR (endpoint exists, needs a query param — web refinement, not gaps):**
`/academic/timetables/summary` (academicYearId), `/attendance/register` (classId+date),
`/intelligence/homework-intelligence/plan` (classId), `/school/timetables/intelligence`
(params). Substitutions default-date fixed; others need in-page selectors (tracked as web polish).

## Verified PRESENT during web build (not gaps — recorded for traceability)

- ✅ `GET /sis/students` — `_shared/sis/sis_router.ts` → `handleListStudents`; response `envelope(listEnvelope(items, {page,pageSize,total,hasMore}))`. Web SIS registry wired to this real contract.
- ✅ `GET /sis/students/{id}` — student detail/profile (wire on SIS detail drawer open).
- ✅ Admissions module fully routed: `GET /admissions/{dashboard,leads,applications,approval-queue,documents,enrollments/pending,handoffs/approved,reports,settings,fee-structures,intelligence}` + lead/application write actions (`_shared/admissions/admissions_router.ts`). All 8 web Admissions pages wired. (Earlier "verify applications" flag CLEARED — it is routed at line 156.)
- 📝 Data-contract verification (not gaps — endpoints exist, DTO field alignment to confirm when wiring live): `/admissions/settings` (settings fields), `/admissions/approval-queue`, `/admissions/documents`, `/admissions/enrollments/pending` item shapes.
- ✅ Auth: `/auth/login`, `/auth/verify-otp`, `/auth/refresh`, `/auth/me`, `/auth/permissions`, `/auth/sessions/*`.
- ✅ Module roots routed: `/sis`, `/hr`, `/inventory`, `/library`, `/transport`, `/hostel`, `/alumni`, `/director`, `/predictions`, `/intelligence/*`, `/parent-insights`, `/growth`.

- ✅ HR module fully routed: `GET /hr/{dashboard,employees,attendance,leave,payroll,recruitment,performance,settings}` + reports endpoints + `/hr/payroll/run`, `/hr/leave/batch-decide` (`_shared/hr/hr_router.ts`). All 9 web HR pages wired. Note: `/hr` is entitlement-gated (`module.hr_payroll`).
- ✅ Finance module fully routed: `GET /finance/{dashboard,collections,student-accounts,fee-structures,fee-assignments,defaulters,refunds,discounts,reports,settings,invoices,...}` + write/maker-checker endpoints (`_shared/finance/finance_router.ts`). 9 core web Finance pages wired; 7 sub-screens (collection_detail, fee_assignment, reconciliation, offline_payments, qr_payment, executive_dashboard, copilot) pending.

## To verify next (as each module page is built)

- Finance, Admissions, HR, Academics/Exams, Attendance per-page endpoints + shapes.
- RBAC: the web nav uses an approximate role→module map (`web/src/lib/auth/roles.ts`) until `/auth/permissions` grants are wired — verify the live matrix matches and log any divergence (RBAC gap).
- Management / Director / Intelligence dashboard aggregations (likely overlap WEB-001).
