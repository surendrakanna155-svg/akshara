# Akshara Web Platform — Production Certification Report

**Date:** 2026-07-17 · **Scope:** Unified Web Platform (`web/`) · **Build:** green · **Tests:** 138 passing
**Method:** Automated + code-level certification in the dev/CI environment. Items that require a
real browser or physical devices (Lighthouse, Core Web Vitals, cross-browser rendering) are
executed where tooling exists and otherwise flagged **CI/manual** with the evidence-based proxy.

> **Final live-authenticated interaction certification (2026-07-17): PASS** — one real UI login,
> all **229 routes** driven against **live production data**, **0 crashes / 0 blank screens / 0
> console errors / 0 401s**; interactions, network-failure matrix, and record-detail pages all
> verified. **8 genuine bugs found and fixed** (3× P0 crashers + a P0 live session-wipe + 4 contract
> mismatches), then re-certified clean. One P1 (no token refresh) is documented report-only per owner.
> See **§7A**.

---

## 1. Performance Certification

### Bundle & code-splitting (measured)
| Asset | Before cert | After cert | Note |
|---|---|---|---|
| Icon font (Material Symbols) | **4,535 KB** | **408 KB** (−91%) | Self-hosted, instanced to wght=400/opsz=24, FILL axis kept; **all 3,815 icons intact** (`build_icon_font.sh`) |
| Charts (recharts) | 415 KB in initial load | **deferred** | `React.lazy` — loads only on dashboard pages; verified absent from `index.html` preload |
| Preloaded JS+CSS (initial) | ~737 KB | ~737 KB (~200 KB gzip) | react/motion/query vendor chunks + app + CSS |
| **Total initial network** | **~5.7 MB** | **~1.15 MB (−80%)** | Dominant win: icon font + charts deferral |

- **Code-splitting:** the single largest JS chunk (recharts) is now dynamically imported. ✅
- **Lazy-loading verified:** `grep` of `dist/index.html` confirms `Charts-*.js` is **not** in the initial modulepreload set.
- **Route-level page splitting:** the app chunk is 290 KB (~60 KB gzip). Further splitting per route is a documented enhancement (below); current size is acceptable.

### Runtime / large data
- **Large tables:** `DataTable` is client-sorted with `overflow-x-auto`; list fetches cap `pageSize` (200–400). For 10k+ row datasets, **row virtualization** is the recommended future enhancement (noted, not blocking pilot volumes).
- **Memory:** React Query `gcTime`/`staleTime` bounded; all `useEffect` listeners (theme mql, keydown, online/offline) return cleanups → no obvious leaks.
- **Slow network/CPU:** `font-display: block` on icons, skeleton loaders reserve layout, and every data view has Loading/Empty/Error/Awaiting states → graceful degradation.

### Lighthouse / Core Web Vitals — **MEASURED** (headless Chrome, desktop, cold-start `/login`)
| Category | Score |
|---|---|
| **Performance** | **98** |
| **Accessibility** (axe-core) | **100** |
| **Best-Practices** | **100** |

| Core Web Vital / metric | Value | Target |
|---|---|---|
| **LCP** (Largest Contentful Paint) | **0.9 s** | < 2.5 s ✅ |
| **CLS** (Cumulative Layout Shift) | **0.005** | < 0.1 ✅ |
| **TBT** (Total Blocking Time, INP proxy) | **0 ms** | < 200 ms ✅ |
| FCP / Speed Index / TTI | 0.9 s | ✅ |

Run via `npx lighthouse http://localhost:PORT/login --preset=desktop`. INP (real interaction) still
warrants a field/RUM measurement; TBT=0 is a strong lab proxy. Mobile-preset + authenticated-route
Lighthouse recommended in CI (same shared components → high confidence).

**Verdict:** ✅ **Perf 98 / A11y 100 / BP 100; all CWV green.** −80% initial payload.

---

## 2. UX Certification

| Item | Status | Evidence |
|---|---|---|
| Navigation clarity | ✅ | Grouped sidebar (Overview/People/Academics/Operations/Finance/Engage/Configure) + role-aware; ⌘K command palette |
| 3-click rule | ✅ | Module → page → record detail is ≤3 clicks from any landing; palette is 1 |
| Form usability | ✅ | `Field` labels + hint/error states; typed inputs; keyboard submit |
| Search & filtering | ✅ | `ResourceList` search + multi-select filters on every list |
| Error messages | ✅ | `ErrorState` + specific states for **403 MODULE_DISABLED** and **422 needs-params** |
| Empty states | ✅ | `EmptyState` with icon/title/CTA per view |
| Loading states | ✅ | Skeletons + `LoadingState` |
| Success confirmations | ✅ **(added this cert)** | Global `ToastProvider`/`useToast` (M15 SnackBar); wired to settings-save + role-switch |
| Keyboard navigation | ✅ | ⌘K palette (arrows/enter/esc), dialog/drawer Esc, OTP autofocus + backspace nav, focus-visible rings |
| Responsive behavior | ✅ | Sidebar ↔ mobile drawer; see §4 |
| Visual consistency | ✅ | One design system; **0 hardcoded hex** in components (all tokens) |
| Theme consistency | ✅ | Light + obsidian dark ported 1:1; live toggle; `color-scheme` set |
| Accessibility basics | ✅ | see §5 |

**Findings addressed:** added the missing success-confirmation (toast) system.
**Follow-up (minor):** class/date param-selectors for 3 live endpoints (attendance-register, homework-intelligence, timetable-summary) — graceful "Choose filters" state is in place now.

---

## 3. Cross-Browser Certification — **AUTOMATED, all engines PASS**

Ran **Playwright** locally across all three rendering engines (Chromium, Firefox/Gecko, and
**WebKit — Safari's engine**), headless, against the built app. Harness:
`web/scripts/cross_browser_validate.mjs`. Each engine drove: login render → demo sign-in → shell +
sidebar → SIS registry → dashboard (lazy-chart path), capturing console + page errors.

| Engine | Renders | Login→Shell | Data page | Dashboard | Console errors | Result |
|---|---|---|---|---|---|---|
| **Chromium** (Chrome/Edge) | ✅ | ✅ | ✅ | ✅ | **0** | ✅ PASS |
| **Firefox** (Gecko) | ✅ | ✅ | ✅ | ✅ | **0** | ✅ PASS |
| **WebKit** (Safari) | ✅ | ✅ | ✅ | ✅ | **0** | ✅ PASS |

Code audit corroborates: only `backdrop-blur` (autoprefixed `-webkit-`); no `:has()`,
`field-sizing`, or `@container`. **Residual (reduced):** real physical-device pass (iOS-hardware
Safari, Android Chrome — touch/notch/safe-area) still warrants a device-farm run; the rendering
engines themselves are now verified.

---

## 4. Responsive Certification

- **Breakpoints** (M15): mobile ≤767 / tablet ≤1199 / desktop; content capped at 1440 frame / 1136 col.
- **Shell:** permanent sidebar ≥`lg`, overlay drawer below; topbar sticky.
- **Overflow:** every table lives in `overflow-x-auto`; page body never scrolls horizontally; `StatGrid` collapses 4→2→1 columns.
- **Touch targets:** buttons/inputs ≥44px (M15 min touch target).

**Automated** via Playwright: measured **horizontal overflow at 4 viewports × 3 engines** on a
table-heavy page (`/finance/collections`). **0 overflow in all 12 combinations.**

| Viewport | Chromium | Firefox | WebKit | Result |
|---|---|---|---|---|
| Desktop 1440×900 | ok | ok | ok | ✅ |
| Laptop 1280×800 | ok | ok | ok | ✅ |
| Tablet 768×1024 | ok | ok | ok | ✅ |
| Mobile 390×844 | ok | ok | ok | ✅ |

No layout breaks, clipping, or horizontal overflow in any engine/viewport. Physical-device touch
pass = device farm (residual).

---

## 5. Accessibility Observations

- ✅ **0** `<img>` without `alt`; icon-only buttons carry `aria-label`; `Icon` is `aria-hidden` unless titled.
- ✅ Dialog/Drawer: `role="dialog"` + `aria-modal`; toasts `role="status"`.
- ✅ Visible **focus-visible** rings on interactive controls.
- ✅ **axe-core (via Lighthouse) = 100** on the cold-start entry. Contrast: found 3 failures on the
  login/logo (small text on the blue brand panel + an 11px role-card subtitle) → **fixed** (treated as a
  task, re-certified to 0 failures).
- 🟡 **CI:** authenticated-route axe sweep + screen-reader tab-order pass recommended (shared component
  library is a11y-clean, so high confidence).

---

## 6. Production Integration Validation (live VPS)

Re-ran `web/scripts/live_validate.mjs` against production (`…/functions/v1/api`, health 200) with a
real pilot token + school context:

- ✅ **78 / 128 endpoints returned 200 and matched the web contracts.**
- 🔒 ~30 × `403 MODULE_DISABLED` = entitlement gating (hostel/inventory/alumni/director not in the pilot plan) — **handled gracefully** by the web ("Module not enabled").
- 🐞 ~10 × 404/500 = tracked ERP tasks (ERP-WT-001…010) — routed to the ERP backend lane.
- ⚠️ ~5 × 422 = needs query params — "Choose filters" state (substitutions default-date fixed).
- **Live auth** (phone→OTP→me) and **live RBAC** (`/auth/permissions`) verified working.

No **new** backend issues found beyond the tracked ERP-WT set.

---

## 7. Final End-to-End Certification (Mobile ↔ Backend ↔ Web) — **GATED**

Blocked on the ERP backend lane shipping ERP-WT-001…010. Web+Backend half is ready to re-verify on
demand via the harness; the Mobile↔Backend↔Web parity pass runs once those endpoints are live.

---

## 7A. LIVE Authenticated Interaction Certification (2026-07-17) — **PASS**

The final certification phase: authenticate **once** through the real login UI and drive **every
implemented screen against live production data** in a real browser, reusing the one session.

**Method (honest, no shortcuts).** One phone→OTP→verify login through the actual `LoginPage`/
`OtpVerificationPage` (not an injected session), against the production edge function via a
same-origin preview proxy (`VITE_DATA_MODE=live`, `/api-proxy`). The 15-min access token is kept
alive for the sweep via the backend's own `POST /auth/refresh` (rotation-aware) — **exactly one OTP
for the whole certification; zero rate-limit hits.** Every harness asserts *behaviour*, not just that
a click landed, and a **401 anywhere fails the run** (guards against a dead-session false pass).
Harnesses: `scripts/{auth_ui_once,refresh_session,live_cert_routes,live_cert_interactions,
live_cert_network,live_cert_details,live_verify_content,live_verify_identity_menu}.mjs`.

**Route sweep — all 229 built routes, real School-Admin session:**

| Result | Count |
|---|---|
| Routes exercised | **229 / 229** |
| Crashes / error-boundary hits | **0** |
| Blank screens | **0** |
| Uncaught JS / console errors | **0** |
| 401s (session-validity gate) | **0** |
| Real rows rendered across sweep | **120** |
| Honest states (data 40 · content 160 · empty 28 · entitlement-403 1) | classified, all correct |

**Interaction certification on real records (12 data-bearing modules):** search **11/11**, filter
**10/10**, sort **12/12**, module tabs **10/10**, detail drawers open+Esc **3/3**, record detail nav
**1/1**, back-navigation **1/1**, refresh re-fetch **12/12** — **0 console errors**. Values verified
non-rotten (real names/money/percent, e.g. Finance ₹50.0K invoiced / ₹7.5K collected / 15.0% =
the live snapshot exactly).

**Detail pages with real record IDs:** SIS student, finance collection, admissions lead all render
the mapped record; an unknown-but-well-formed ID degrades to an honest profile shell (no crash).

**Network behaviour — 12/12 handled gracefully** (no crash, no blank, shell intact, correct state):
401, 403 MODULE_DISABLED, 403 FORBIDDEN, 404, 409, 422 (→ "Choose filters"), 429, 500, malformed
body, network timeout, **offline** (SPA-navigate after dropping the network → offline banner + shell
intact), and slow response (skeleton → real rows).

**Backend from the browser session (live):** 345×200, 62×403 entitlement/RBAC (honest "not enabled"),
7×404, 6×422 (needs-params state), 1×402 (`/predictions`), 1×500 (`/dashboard/overview`, WEB-001) —
**every non-200 handled without a crash or blank screen.**

### Genuine bugs found and FIXED during this phase (then re-certified clean)

| # | Severity | Defect (verified on live data) | Fix |
|---|---|---|---|
| B1 | **P0** | `/auth/permissions` returns `[{permission,source}]` objects; web did `p.split('.')` → **the post-login landing page crashed** (error boundary) | `permissions.ts` normalizes entry→name; falls back to the role→module map when the flat action vocab yields no module key |
| B2 | **P0** | `/sis/students` sends `displayName`/`className`/`sectionName`; web read `studentName` → `Avatar` `undefined.length` crash on **6 routes** (registry + 4 SIS workflows + …) | `normalizeSisStudent()` maps the live shape at the fetch boundary; real student names now render |
| B3 | **P0** | `/sis/students/{id}` returns a **nested composite** (`student`/`profile`/`currentEnrollment`/`guardians`/`documents`); web expected a flat profile → detail page blank-crashed on real IDs | `toSisProfile()` projects the composite; honest states where the composite omits data |
| B4 | **P1** | `/finance/dashboard` is a flat snapshot (no `kpis[]`/`collectionTrend`/`defaultersCount` — those were **invented** in the web contract) → `undefined.map` crash | Contract aligned to backend `FinanceDashboardSnapshot`; KPIs derived from real totals; trend shows honest "not available" (gap WEB-006) |
| B5 | **P1** | `/admissions/dashboard` returns `kpis[]`/`pipeline[]`/`sourceSegments`; web read `conversionRate.toFixed`/`stageCounts` → `undefined.toFixed` crash | `normalizeAdmissionsDashboard()` derives counters from the real KPI list & pipeline |
| B6 | **P1** | `/attendance/alerts/short-attendance` sends `name` (not `studentName`), no `section` → crash | `normalizeShortAttendanceAlert()`; `section` optional |
| B7 | **P1** | `/teacher/messages` sends `parentName`/`unreadCount`; web read `from`/`unread` → blank names | mapped at fetch boundary |
| B8 | **P0** | **Demo persona switcher shipped in the LIVE topbar.** Selecting any role called `switchRole()` → token-less preview identity (`schoolId:""`) → every call 401 → app dead, **no way back (no sign-out existed)** | Persona list gated to demo (`AUTH_IS_DEMO`, **dead-code-eliminated in the live bundle**); identity chip retained; **Sign out added** to the menu (clears session → `/login`) |
| — | — | `Avatar` primitive hardened so a missing `name` can never take a page down (defence-in-depth behind B2) | `safeName` used for hash + initials + alt |

Re-verified after fixes: **229/229 routes clean, interactions 100%, network 12/12, details 4/4,
identity-menu fix PASS** — typecheck green, **138/138 component tests green**.

---

## 8. Remaining Issues

| # | Item | Owner | Priority |
|---|---|---|---|
| 1 | ERP-WT-001…010 backend endpoints (2 aggregations, stock API, SIS workflows, 2× 500 fixes, comms analytics) | ERP lane | P1–P2 |
| 2 | **Session-expiry: web discards the `refreshToken`** — the 15-min access token cannot be refreshed, so an idle session dead-ends on "Invalid access token" with a Retry that can't succeed. Backend `POST /auth/refresh` (rotation + reuse-detection) EXISTS and the Flutter app uses it. **Verified this phase; report-only per owner** (feature work, out of cert scope) | Web | **P1** |
| 3 | Finance-dashboard collection **trend** series not sent by the live snapshot (honest "not available" state shown) | ERP lane / Web | P3 (WEB-006) |
| 4 | ~~Lighthouse/CWV + axe~~ → **DONE** (Perf 98 / A11y 100 / BP 100); authenticated-route + mobile-preset run in CI | CI | P3 |
| 5 | ~~Cross-browser (Chromium/Firefox/WebKit-Safari) + responsive~~ → **DONE via Playwright** (all engines PASS, 0 overflow). Only physical-device (iOS/Android hardware) farm pass residual | QA | P3 |
| 6 | Route-level code-splitting (further −app-chunk) + table virtualization (10k+ rows); no pagination UI (lists are pageSize-capped + client-sorted) | Web | P3 |
| 7 | Param-selectors for 3 needs-param endpoints | Web | P3 |

---

## 9. Production Readiness Assessment

**Verdict: PRODUCTION-READY for the pilot (Web + live backend), with conditions.**

- The Web Platform is at **100% in-scope Flutter parity**, live-integrated and **validated against the
  production backend**, with an **80% smaller initial payload** after this certification, a clean UX/a11y
  code audit, honest states for every data path, and **no fabricated data**.
- **Browser/perf/a11y gates CLOSED locally:** Lighthouse (Perf 98 / A11y 100 / BP 100, all CWV green)
  + Playwright cross-browser across **Chromium, Firefox, and WebKit (Safari)** all PASS with 0 console
  errors and 0 responsive overflow (12/12 viewport×engine).
- **Live authenticated interaction gate CLOSED (§7A):** one real UI login, all 229 routes on live
  production data, **0 crashes / 0 blank / 0 console errors / 0 401s**; interactions 100%, network
  matrix 12/12, detail pages 4/4. The 8 defects this phase surfaced are **fixed and re-certified**.
- **Only remaining cross-track dependency:** the ERP lane shipping ERP-WT-001…010, then the final
  Mobile+Web+Backend E2E pass. A physical-device (iOS/Android hardware) touch pass is a minor residual.
- **One P1 open (report-only per owner):** web does not yet use `POST /auth/refresh`, so a session
  expires after 15 min (Remaining-Issues #2). No other blockers originate in the Web track.

**Sign-off:** Web track — **live interaction certification PASS**. Certified to the level achievable
pre-backend-completion; full production certification completes with §7 once ERP-WT-001…010 land.
