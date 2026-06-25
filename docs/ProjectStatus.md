# Akshara ERP — Project Status

**Last updated:** June 2026  
**Current version:** `v0.2-academic-mvp`  
**HEAD commit:** `42b7018`

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
> **P2 begins — B7 AI School Builder (Phase 1) is PRODUCTION CERTIFIED (2026-06-25):** an
> entitlement-gated AI pre-fill (`POST /onboarding/startup/ai-prefill`,
> `feature.ai_school_builder`, Professional+Enterprise) that turns a short founder brief into a
> complete, board-appropriate startup-onboarding proposal (classes, sections, fees, language,
> modules) on the certified onboarding foundation — deterministic baseline + Claude refinement
> with safe fallback, **non-destructive** (proposes only). Live smoke **10/10** (real auth +
> prod DB + real AI, `source=ai`). For current status see
> `docs/ROADMAP_RECONCILED_2026-06-24.md`, `docs/B7_AI_SCHOOL_BUILDER_CERTIFICATION.md`,
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
