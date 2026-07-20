# ERP Roadmap — Tasks Discovered by the Web Platform Track

**Official ERP implementation tasks** surfaced by building the Unified Web Platform
(the Web track doubles as a continuous ERP verification layer, owner-locked
2026-07-16). Each item here is a real backend/product task for the ERP lane, not
just documentation. It stays **synchronized** with the Web-side discovery log
[`WEB_TRACK_BACKEND_GAPS.md`](WEB_TRACK_BACKEND_GAPS.md): the Web tracker records
where it was found + the interim UI state; this file is the ERP work item.

**Lifecycle:** discovered (Web) → logged here as an ERP task with priority →
ERP lane implements the API/feature → Web tracker updated + the interim state
replaced with the live wiring → status flips to 🟢 in both files.

Priority: **P0** launch-blocking · **P1** core page blocked · **P2** enhancement.
Status: 🔴 not started · 🟡 in progress · 🟢 delivered.

> **Owner decision (2026-07-17):** these tasks are routed to the **ERP backend lane**
> (its own worktree) — the web track does NOT implement backend from here. This file is
> the handoff. The web pages are already built + live-validated; when the ERP lane ships
> an endpoint, flip its status 🟢 here + in `WEB_TRACK_BACKEND_GAPS.md` and the web page
> lights up with no further web change (it already targets the correct path). Then run
> priority #4: final Mobile + Web + Backend E2E verification.

| ERP task | Web gap | Pri | Status | Module | What to build | Reason / owner notes |
|----------|---------|-----|--------|--------|---------------|----------------------|
| ERP-WT-001 | WEB-001 | P1 | 🟢 | Dashboard / Analytics | `GET /dashboard/overview` returning school-admin KPIs (students, attendance today, fees MTD, pending admissions), enrolment trend, fee-collection series, attendance-by-section, activity feed, pending approvals. | The web admin landing page (`/admin/dashboard`) has no single aggregation endpoint. Only per-module + `/intelligence/*` exist. Compose server-side or add a BFF aggregation. Likely reused by management/director/intelligence dashboards. |
| ERP-WT-002 | WEB-002 | P2 | 🟢 | Web platform / perf | Subset the Material Symbols icon font to used glyphs (or ship per-icon SVGs). | 4.6 MB icon font hurts first-paint. Web-track-only build task (no ERP-backend change). |
| ERP-WT-003 | WEB-003 | P2 | ⏸ | Transport | Live vehicle GPS tracking API + device integration (real-time positions, ETAs, stop progress). | GPS is Phase-2 per scope. Flutter transport tracking is a placeholder too. Web tracking page is a ready shell awaiting this. |
| ERP-WT-007 | WEB-007 | P1 | 🟢 | Finance | Add `GET /finance/student-accounts` (paginated list of student fee accounts). Only by-id + ledger exist. | Web Student Accounts list; found by live validation (404). |
| ERP-WT-008 | WEB-008 | P2 | 🟢 | Academics | Fix `GET /academics/exams/progress` — returns 500 on the pilot tenant. | Marks-progress page; live validation 500. |
| ERP-WT-009 | WEB-009 | P2 | 🟢 | School setup | Fix `GET /school/pilot/dashboard` — returns 500. | Pilot dashboard; live validation 500. |
| ERP-WT-010 | WEB-010 | P2 | 🟢 | Communication | Expose comms analytics: `/communications/analytics/{summary,parent-adoption}` (delivery metrics exist at `/communications/delivery/metrics`). | School-completion comms analytics + parent activation; live validation 404. |
| ERP-WT-006 | WEB-006 | P2 | 🟢 | Intelligence | Expose `GET /intelligence/trust` (AI trust/governance dashboard) and `GET /intelligence/ai-economics` (AI cost/token economics). | Web dashboards built; no endpoints in `intelligence_router.ts`. Low priority (analytics surfaces). |
| ERP-WT-005 | WEB-005 | P1 | 🟢 | SIS | Expose SIS class-management workflow endpoints: `/sis/promotion` (bulk year-end promotion), `/sis/reshuffle` (move students between sections), `/sis/section-balance` (rebalance sections), and `GET /sis/academic-assignment`. | Core registrar workflows with UI built (roster + gated apply). No backend endpoints exist yet in `sis_router.ts`. |
| ERP-WT-004 | WEB-004 | P1 | 🟢 | Inventory | Expose `GET /inventory/stock` (consumable stock ledger: on-hand, reorder, valuation) and `GET /inventory/stock/approvals` (maker-checker value-reducing stock changes). | Stock governance (stock_movements ledger, maker-checker, valuations) exists in the DB per the INV batch but has no read API in the edge function. Web Stock + Stock-Approvals pages are built and wired, awaiting these endpoints. |
| ERP-WT-011 | WEB-011 | P1 | 🟢 | Platform / Edge (API gateway) | Decide + implement browser access for the web SPA: emit CORS headers (`Access-Control-Allow-Origin` for approved web origin(s), allow `Authorization` + `X-Tenant-Id`/`X-School-Id`/`X-Api-Version`/`X-User-Id`, handle `OPTIONS` preflight) **or** serve the web same-origin behind the API gateway. | Final live UI cert: browser fetch from a different origin is CORS-blocked (`net::ERR_FAILED`); Node fetch (no CORS) returns 200 with rows. Web already added a same-origin dev/preview proxy + relative-base client resolution, so a same-origin `/api` deployment works now; production origin policy is the ERP-lane decision. |

> Note: this file lives in `docs/roadmap/` and is the canonical ERP-side view of
> web-discovered work. Keep it and `WEB_TRACK_BACKEND_GAPS.md` in lockstep — never
> let a discovered gap exist in only one place.
