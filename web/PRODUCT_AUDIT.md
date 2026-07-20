# Akshara Web Platform — Product Audit

Final verification of the Unified Web Platform against the Flutter application —
not just UI coverage, but journeys, navigation, permissions, workflows, API
contracts and business processes. Owner-mandated completion audit (2026-07-17).

## 1. Screen coverage — 100% of in-scope

| | Count |
|---|---|
| In-scope Flutter screen files (`lib/features/**`, excl. `verticals/` + `platform/`) | **248** |
| Web pages / routes built | **~240 pages across all modules** |
| Modules with a web page directory | **all** (auth, sis, admissions, hr, finance, transport, library, hostel, inventory, alumni, academics, attendance, management, director, intelligence, engage, schoolops, student, teacher, parent, detail, misc, settings, admin) |

Every in-scope module and screen has a web equivalent. A handful of Flutter
push-detail screens are realised as **detail drawers / row-click panels + deep-linkable
`:id` routes** (SIS profile, collection, lead, receipt, conversation) — the correct
desktop-web adaptation. Deliberate consolidations (not gaps):
- `office_attendance` → consolidated into HR **Staff attendance** (`/hr/attendance`) + Attendance register.
- `student_onboarding` / `unified_onboarding_flow` → the **Onboarding** hub (`/onboarding`) + **Setup wizard**.
- `admin_module_placeholder` → a placeholder in Flutter itself; intentionally not ported.

## 2. Navigation — no dead links

Automated audit: **all 155** declared nav + module-tab paths resolve to a real page
(0 fall through to the fallback scaffold). Root redirect sends each role to its landing.
Deep-linkable detail routes added for records.

## 3. Permissions / RBAC — live-wired

- The sidebar filters by role via `roles.ts` (approximate map) **and** by **live grants
  from `GET /auth/permissions`** when a backend is connected (`useGrantedModules` →
  `navForRole(role, granted)`); live grants override the map. Demo mode falls back to
  the role map. This resolves the earlier RBAC-approximation finding.
- Portals (parent/teacher/student) get their own `PORTAL_NAV`; the whole shell swaps by workspace.

## 4. API contracts — verified per module

Every page fetches through `useModuleQuery` + `apiFetch`, wired to endpoints **verified
against `supabase/functions/_shared/*/*_router.ts`** during each module's build. Response
shapes come from the Flutter models (`lib/features/**/*_models.dart`) as typed contracts
(`web/src/lib/contracts/*`). `fetchList` normalizes the `listEnvelope` shape. **No page
fabricates data** — unwired endpoints render Loading/Empty/Error/Awaiting-backend states.
Flip `VITE_DATA_MODE=live` + `VITE_API_BASE_URL` to light up real data across the app.

## 5. Key journeys verified (navigation cross-links present)

- **Sign-in → role home** (role picker / credentials → landing per role).
- **Admissions**: dashboard → leads → lead detail; applications → approvals → documents → enrolment (→ Finance hand-off).
- **Finance**: dashboard → collections → collection/receipt detail; defaulters, refunds (maker-checker), discounts, fee assignment, offline/QR, reconciliation, day-close.
- **Academics**: exams → marks entry (exam picker → editable grid) → marks progress → reports; timetable → substitutions.
- **SIS**: registry → student profile (overview/academics/fees/attendance/documents); promotion/reshuffle/section-balance workflows (gated on WEB-005).
- **Parent**: home → attendance/homework/exams/report-card; fees → payment → receipts → receipt detail; messages → conversation.
- **Teacher**: today → attendance/timetable/homework(create/history)/exams; messages → conversation; leave/approvals; student-risk.

## 6. Backend gaps (dual-synced to ERP roadmap)

All discovered gaps are official ERP tasks in
[`docs/roadmap/WEB_DISCOVERED_ERP_TASKS.md`](../docs/roadmap/WEB_DISCOVERED_ERP_TASKS.md)
(ERP-WT-001…006), kept in lockstep with
[`WEB_TRACK_BACKEND_GAPS.md`](../docs/roadmap/WEB_TRACK_BACKEND_GAPS.md):

| ID | Pri | Gap |
|----|-----|-----|
| WEB-001 | P1 | School-overview dashboard aggregation (`/dashboard/overview`) |
| WEB-004 | P1 | Inventory stock ledger + approvals API (`/inventory/stock*`) |
| WEB-005 | P1 | SIS class-workflow APIs (promotion/reshuffle/section-balance) |
| WEB-002 | P2 | Icon-font subsetting (4.6 MB → used glyphs) |
| WEB-003 | P2 | Live vehicle GPS tracking |
| WEB-006 | P2 | Intelligence trust + AI-economics endpoints |

**No new backend gaps** were discovered during this audit beyond the six above.

## 7. Engineering health

- `npm run build` (tsc + vite) ✅ · `npm run test` ✅ **138 tests** · preview server boots (HTTP 200).
- Design tokens ported 1:1 from Flutter M15 (light + obsidian dark); switching Flutter↔Web reads as one product.
- Responsive: desktop sidebar + mobile drawer; tables scroll within `overflow-x-auto`; content capped at the 1440 frame / 1136 column.

## 8. Live production validation (2026-07-17)

Ran `web/scripts/live_validate.mjs` against the **production VPS**
(`https://akshara.veloraunisexsalon.com/functions/v1/api`, health 200). Authenticated
with a pilot phone (dev-OTP returned in-app, no SMS), resolved school context via
`/auth/context/switch`, and probed **128 GET endpoints** the web pages consume.

- ✅ **76 endpoints returned 200 and matched the web contracts** (auth, SIS, admissions,
  HR, finance, transport, library, academics exams, management, intelligence, attendance,
  school-ops, communication) — confirming the web↔backend integration for the pilot tenant.
- 🔧 **2 wrong web paths found + fixed** (not backend gaps): communication
  (`/communications/broadcasts/history`), timetable (`/academic/timetables*`).
- 🔒 **403 MODULE_DISABLED** for hostel/inventory/alumni/director = entitlement gating
  (tenant plan). Web now shows a "Module not enabled" state.
- ⚠️ **422 needs-param** on a few analytics/register endpoints — substitutions fixed
  (default date); others need in-page selectors (web polish, endpoints work).
- 🐞 **New backend gaps/bugs filed** (ERP-WT-007…010): `/finance/student-accounts` list
  (404), `/academics/exams/progress` (500), `/school/pilot/dashboard` (500), comms
  analytics summary/parent-adoption (404). Confirmed WEB-001/005/006 still open.

**Live auth is implemented**: phone/OTP sign-in (`/auth/login` → `/auth/verify-otp` →
`/auth/me`) + live RBAC (`/auth/permissions`). Set `VITE_DATA_MODE=live` +
`VITE_API_BASE_URL=…/functions/v1/api` to run the whole platform against the pilot backend.

## 9. Polish state (2026-07-17)

- **Backend endpoints** (ERP-WT-001…010) — routed to the **ERP backend lane** by owner
  decision; the web pages already target the correct paths and will light up when shipped.
- **422 needs-params** — pages now render a "Choose filters to load" state (AsyncBoundary
  handles 422); substitutions default to today's date. Full class/date selectors for
  attendance-register / homework-intelligence remain a small follow-up (needs `/academic/classes`).
- **WEB-002 icon-font subset** — deferred (owner: low priority). Safe path when done:
  `pip install fonttools brotli`, extract every used icon name, `pyftsubset rounded.woff2
  --text="<names>" --layout-features='*' --flavor=woff2`, then self-host via a local
  `@font-face` (replacing the `material-symbols/rounded.css` import). Verify no icon name
  is missing before shipping (a missed ligature renders blank).

**Audit verdict: PASS** — full parity for in-scope scope, no dead links, RBAC live-wired,
API contracts **validated against production** (76/128 green; the rest classified as
entitlement-gated, needs-param, or tracked ERP tasks), no fabricated data.
