# Akshara ERP — Project Status

**Last updated:** June 2026  
**Current version:** `v0.2-academic-mvp`  
**HEAD commit:** `42b7018`

> **Pilot School Simulation — LIVE CERTIFIED (2026-06-27):** ran Akshara the way
> real customers do — Small Private (State), Large CBSE, ICSE and State-board
> schools; single-school organizations vs. multi-school trusts; the full dynamic
> module lifecycle (Inventory/Hostel/Library/Transport/HR/Alumni: enable → use →
> disable → re-enable, with **data never deleted on disable**); and a full month
> of operations — all against the live VPS pilot. **Live total 83/83**
> (`scripts/qa/live_cert_pilot_simulation.py` 41/41 + `live_cert_full_journeys.py`
> 25/25 + `live_cert_onboarding_dynamic_config.py` 17/17); analyze 0, flutter
> 2440/0, backend 857/0. Found, fixed and live-verified **one** genuine production
> bug: snapshot dashboards (Transport/Inventory/Hostel + Management/Control-Center)
> returned **404** for every school but the seeded demo pilot — they now return a
> clean **200 empty-state** when no snapshot row exists (5 edge handlers, no
> migration, deployed). See `docs/PILOT_SCHOOL_SIMULATION.md` +
> `docs/PILOT_SIMULATION_ROADMAP.md`. *(Legal & Compliance and GA certification
> not yet started — intentionally out of scope.)*
>
> **Onboarding & Dynamic Configuration PRODUCTION CERTIFIED (2026-06-27):** the
> first-time-school experience is now proven end-to-end — Akshara builds the right
> ERP per school and disabling a module removes it everywhere (and re-enabling
> restores it). Closed the systemic root cause (the founder's module choice never
> reached the runtime gate: onboarding wrote `schools.settings.modules_enabled`
> while gating reads `school_configuration.capabilities`) plus 12 gaps (G1–G12):
> go-live now derives + writes capabilities (G1) and a default subject/syllabus set
> (G8) idempotently (G9, find-or-create); the brief UI collects facilities (G2);
> the **backend now rejects school-disabled modules with 403 MODULE_DISABLED** (G3);
> dashboard/search/notifications honour disabled modules (G5/G6/G7); Organization
> Builder is reachable (backend emits `isChainOrganization`, G4); plus honesty
> polish (G10/G11/G12). The first real go-live (B7 only ever certified the
> propose-only AI prefill) surfaced and fixed three latent bugs — `schools` write
> needed a SECURITY DEFINER fn (migration `20260813000000`), and two CHECK-constraint
> violations (`syllabus.source`, `fee.status`). Live cert
> `scripts/qa/live_cert_onboarding_dynamic_config.py` **17/17** (real auth + DB +
> RBAC, isolated throwaway school, pilot untouched); Deno 102/102; analyze 0; tests
> green. See `docs/ONBOARDING_DYNAMIC_CONFIGURATION_CERTIFICATION.md`.
>
> **Live backend / pilot state (2026-06-25):** the self-hosted backend is live on the
> VPS (`akshara.veloraunisexsalon.com`). **The entire P1 (Revenue & Pilot Success) layer is
> PRODUCTION CERTIFIED and now INTEGRATION CERTIFIED end-to-end:** B1 Admissions CRM
> (2026-06-24), B2 Capability Gating (2026-06-25, enforcement on, pilot=Professional), B3
> Parent Insights, B4 AI Admissions Assistant, B5 WhatsApp surfaces, B6 Marketing Engine
> (all 2026-06-25). **P1 Integration Certification (2026-06-25):** the batches were verified
> to work together — Marketing→CRM→AI handoff, capability gating, parent insights, RBAC
> scope, WhatsApp readiness — live smoke **11/11** (`scripts/p1_integration_smoke.sh`). One
> real cross-batch gap was found and fixed: the Marketing→CRM convert handoff wrote a UUID
> owner, hiding marketing-sourced leads from the AI's assign next-best-action; the handoff
> now leaves leads unassigned.
>
> **P2 complete + P3 complete (2026-06-25):** all three P2 (moat) items — B7 AI School Builder,
> B8 Director Multi-School, B9 Advanced AI Predictions — are PRODUCTION CERTIFIED, and **both
> P3 (Platform Expansion)** items — **B10 Organization Builder** and **B11 Dynamic Widget
> Platform** — are now PRODUCTION CERTIFIED too. This completes every planned roadmap batch
> (B1–B11); only P4 (B12 Verticals, frozen until pilot validation) remains (details below).
>
> **B11 Dynamic Widget Platform PRODUCTION CERTIFIED (2026-06-25) — second P3 (Platform
> Expansion), final planned batch:** the role/vertical-pack dashboard contract the shipped Flutter
> `dynamic_widgets` UI consumes (data-source registry, layout versions, per-role layouts with tenant
> overrides). The older flat per-user dashboard layout already existed; the gap was the **rich
> role-scoped contract** — `GET /widgets/data-sources` (404, no handler), `GET /widgets/layouts/versions`
> (mis-routed), and `GET/PUT/POST /widgets/layouts/:role` (returned the wrong shape) — so the app was
> silently falling back to its in-app mock. Built **no-migration** on the existing
> `widget_platform_foundation` tables (`widget_registry`, `dashboard_layouts`): a backend pack catalog
> (`widget_pack_catalog.ts`, mirrors the client mock — 6 data sources + per-role/vertical-pack default
> layouts) and rich handlers (`widget_layout_handlers.ts`) that resolve the pack default or a persisted
> **tenant override** (stored in `dashboard_layouts` under `role:<role>`, `owner_user_id` NULL).
> RBAC-gated (`viewDynamicWidgets`/`manageDynamicWidgets`, school scope) — **no entitlement gate**, a
> school-level configurability feature matching the UI. The edge `erp_tenant` role lacks DELETE on
> `dashboard_layouts`, so save is UPDATE-first/INSERT-fallback and reset rewrites the row to the pack
> default (no DELETE). Flutter unchanged (`EVOLUTION_API_ENABLED` already on). Backend Deno 10/10,
> Flutter analyze clean + dynamic-widget tests 8/8. Live cert **16/16** (real school-JWT + prod DB +
> RBAC): data-sources registry, pack-default layout, override save (version bump + audit) + durable
> persist, versions reflect override, reset to default, RBAC 403 (manage/view/school-scope) + unauth
> 401, legacy registry intact, clean teardown. See `docs/B11_DYNAMIC_WIDGET_PLATFORM_CERTIFICATION.md`.
>
> **P2 — B7 AI School Builder (Phase 1) PRODUCTION CERTIFIED (2026-06-25):** an
> entitlement-gated AI pre-fill (`POST /onboarding/startup/ai-prefill`,
> `feature.ai_school_builder`, Professional+Enterprise) that turns a short founder brief into a
> complete, board-appropriate startup-onboarding proposal (classes, sections, fees, language,
> modules) on the certified onboarding foundation — deterministic baseline + Claude refinement
> with safe fallback, **non-destructive** (proposes only). Live smoke **10/10** (real auth +
> prod DB + real AI, `source=ai`).
>
> **B10 Organization Builder PRODUCTION CERTIFIED (2026-06-25) — first P3 (Platform Expansion):**
> the chains/trusts no-touch org-setup flow (vertical packs → 7-step interview with a real AI
> recommendation → config preview → real provisioning → job status), built as a backend to the
> already-shipped Flutter UI. New migration `20260727000000` — three tables (`org_builder_packs`
> catalog + four verticals; `org_builder_interview_drafts` with a client-supplied TEXT id;
> `org_builder_provisioning_jobs`), `view`/`manageOrganizationBuilder` perms, org-scope RLS
> (mirrors Director), Enterprise `feature.organization_builder` entitlement. New
> `_shared/organization_builder/` module: repository (create-on-demand drafts, pure `buildPreview`,
> **real synchronous provisioning** — six persisted step outcomes, draft → provisioned, no timers),
> real-Claude interview recommendations (safe fallback), handlers (auth → RBAC → org-scope →
> audit), router owning both contract prefixes (`/platform/org-builder/...` and
> `/platform/provisioning-jobs/:id`) and self-enforcing the entitlement. Flutter unchanged — flipped
> `ORGANIZATION_BUILDER_API_ENABLED` on; module stays chain-gated + Enterprise-gated at runtime.
> Backend Deno 3/3, Flutter analyze clean + 9/9 org-builder tests. Live cert **17/17**: gate denies
> the Professional pilot (402) → override enables → real org-scoped flow + real AI (137-char rec) +
> real provision (6/6 steps) + audit; RBAC 403 (manage/view/org-scope) + unauth 401; override
> restored. See `docs/B10_ORGANIZATION_BUILDER_CERTIFICATION.md`.
>
> **B9 Advanced AI Predictions PRODUCTION CERTIFIED (2026-06-25):** the first prediction models,
> shipped as one gated product — three school-scoped, data-grounded feeds: fee-default (finance
> invoices), admission-conversion likelihood (admissions funnel), and student-risk (reuses the
> certified intelligence engine). Each returns a deterministic list + an optional real-AI narrative
> (Claude, safe fallback). New `_shared/predictions/` module gated by the Enterprise
> `feature.ai_predictions` entitlement (per-deal override-grantable); per-endpoint RBAC
> (viewFinance/viewAdmissions/viewStudentRisk). No migration, no new permission slugs. Flutter
> `PredictionsScreen` at `/intelligence/predictions` + intelligence-hub launch tile. Live cert
> **11/11**: gate denies the Professional pilot (402) → override enables → real predictions on real
> data + real AI; RBAC + unauth + school-scope enforced. See `docs/B9_ADVANCED_AI_PREDICTIONS_CERTIFICATION.md`.
>
> **B8 Director Multi-School PRODUCTION CERTIFIED (2026-06-25):** polish for multi-branch sales
> on the certified Batch-6 Director backend — closed three honesty gaps: (A) a metric-input
> write path (`GET`/`POST /director/metric-inputs`, manage-gated, audited) so the chain owner
> can enter the figures with no operational source (marketing spend, operating expense,
> capacity), now feeding Margin / Marketing ROI / Capacity instead of permanent zeros; (B) a
> real board-pack export (`POST /director/reports/:id/export` returns a document built from live
> aggregates, rendered to a real PDF client-side); (C) a real-AI executive summary
> (`director_ai.ts`, deterministic baseline + Claude, safe fallback). No migration (Batch-6
> `director_metric_inputs` reused). Backend Deno tests 10/10, live cert **13/13** (real org-JWT
> + prod DB + RBAC + multi-school aggregation + real AI). For current status see
> `docs/ROADMAP_RECONCILED_2026-06-24.md`, `docs/B8_DIRECTOR_MULTI_SCHOOL_CERTIFICATION.md`,
> `docs/B7_AI_SCHOOL_BUILDER_CERTIFICATION.md`,
> `docs/P1_INTEGRATION_CERTIFICATION.md`, and `docs/B2_STATUS_LEDGER.md`.

---

## Release History

| Version | Tag | Scope | Status |
|---------|-----|-------|--------|
| v0.1 Foundation | `v0.1-foundation` | Theme, auth skeleton, initial parent dashboard/fees/attendance | ✅ Released |
| v0.2 Academic MVP | `v0.2-academic-mvp` | Parent PA-01–12, Teacher TA-01–07, Student ST-01–07 | ✅ Released |
| v0.3 Admissions MVP | — | AD-01 → AD-10 | 🔜 Planned |
| v0.4 Finance MVP | — | FN-01 → FN-11 | Planned |
| v0.5 Operations MVP | — | Transport, Hostel, Inventory | Planned |
| v0.6 Management MVP | — | MG-01 → MG-08 | Planned |
| v1.0 Production Release | — | Full platform + API + CI/CD | Planned |

---

## Completed Modules (v0.2)

### Mobile apps — feature-complete for academic MVP

| App | Screens | Routes | Providers | Tests |
|-----|---------|--------|-----------|-------|
| **Parent** | 13 + receipt detail | 14 | 11 | 12 files |
| **Teacher** | 8 | 9 (+ conversation) | 8 | 7 files |
| **Student** | 7 | 7 | 7 | 7 files |
| **Auth** | 3 | 3 | 1 | 2 files |
| **Notifications** | 1 | 1 | 1 | — |

### Totals

| Metric | Count |
|--------|-------|
| Feature screens | 32 |
| GoRouter route registrations | 36 |
| Riverpod provider files | 28 |
| Shared widgets | 12 |
| Test files | 31 |
| Tests passing | 130 |
| Analyzer issues | 0 |
| `lib/features/` Dart files | 136 |

---

## Remaining Modules (not started in Flutter)

| Module | Spec | Screens (per docs) | Platform |
|--------|------|-------------------|----------|
| Admissions | `Admissions.md` | AD-01 → AD-10 | Web primary |
| Finance | `finance.md` | FN-01 → FN-11 | Web primary |
| Management | `Management.md` | MG-01 → MG-08 | Web primary |
| HR | `HR.md` | HR-01 → HR-09 | Web primary |
| Transport | `Transport.md` | TR-01 → TR-09 | Web + mobile companion |
| Hostel | `Hostel.md` | — | Web |
| Marketing | `Marketing.md` | — | Web |
| Director | `Director.md` | — | Web |
| Library | `Library.md` | — | Web |
| Inventory | `Inventory.md` | — | Web |
| Alumni | `Alumni.md` | — | Web |
| Akshara Control Center | `AksharaControlCenter.md` | ACC-01 → ACC-12 | Web desktop |
| Academic (admin) | `Academic.md` | — | Web |
| Student SIS | `StudentSIS.md` | — | Web |
| Principal | `Principal.md` | — | Web |

### Mobile app gaps (within v0.2 apps)

- Parent: messages, bus tracking, report cards, certificates, language selection
- Teacher: dedicated notifications, AI copilot, class-teacher dashboard
- Student: fifth nav tab, homework submit/upload, join class, AI quiz

---

## Quality Status

```
flutter analyze  → 0 issues
flutter test     → 130/130 passing
git status       → clean working tree
```

---

## Architecture Summary

```
lib/
├── features/
│   ├── auth/           # Splash, login, OTP, session
│   ├── notifications/  # Shared notifications
│   ├── parent/         # 12 modules + shell
│   ├── teacher/        # 7 modules + shell
│   └── student/        # 7 modules + shell
├── router/             # GoRouter + role guards + navigation handlers
├── shared/widgets/     # 12 reusable Akshara widgets
└── theme/              # M3 design tokens
```

---

## Recommended Roadmap (v0.3 → v1.0)

See release notes in `docs/Releases/v0.2-Academic-MVP.md` for detailed next-phase analysis.

**Immediate next:** Admissions MVP — highest business value, unblocks SIS and Management KPIs.
