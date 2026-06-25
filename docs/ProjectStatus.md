# Akshara ERP — Project Status

**Last updated:** June 2026  
**Current version:** `v0.2-academic-mvp`  
**HEAD commit:** `42b7018`

> **Live backend / pilot state (2026-06-25):** the self-hosted backend is live on the
> VPS (`akshara.veloraunisexsalon.com`). Production-certified revenue/pilot batches:
> **B1 Admissions CRM** (2026-06-24) and **B2 Capability Gating / entitlement layer**
> (2026-06-25 — enforcement enabled, pilot org on Professional). The versioned table
> below tracks the older app-MVP milestones; for current batch status see the
> authoritative `docs/ROADMAP_RECONCILED_2026-06-24.md` and `docs/B2_STATUS_LEDGER.md`.

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
