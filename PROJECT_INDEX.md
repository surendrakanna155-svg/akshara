# Akshara ERP — Project Index

> **Single start-here for any AI assistant or developer.** This is the top-level map of the
> repository: where the code lives, what the Source-of-Truth documents are, and where historical
> material is archived. For the full active-document list see [`docs/README.md`](docs/README.md).
> **Never read `docs/archive/` for current decisions** — it is history only.
>
> _Last updated: 2026-07-03 (Documentation Cleanup finalized). Branch: `feature/data-reliability-platform`._

Akshara is a mobile-first, multi-tenant **School ERP** — a Flutter app (iOS/Android) on a
Supabase/Postgres backend, self-hosted on a VPS for the pilot. The single engineering authority is
the **Engineering Constitution**, enforced automatically by the **EOS gate**.

---

## 1. Read in this order

| # | Read | Why |
|---|---|---|
| 1 | [`CLAUDE.md`](CLAUDE.md) | Project instructions + the mandatory EOS engineering gate (overrides defaults). |
| 2 | [`docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`](docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md) | The engineering law. Frozen — never rewrite/move. |
| 3 | [`docs/ProjectStatus.md`](docs/ProjectStatus.md) | Current state of the project. |
| 4 | [`docs/FINAL_QA_ROADMAP.md`](docs/FINAL_QA_ROADMAP.md) + [`docs/FINAL_QA_MASTER_TRACKER.md`](docs/FINAL_QA_MASTER_TRACKER.md) | The current roadmap and QA program. |
| 5 | [`docs/PRODUCT_ENHANCEMENT_BACKLOG.md`](docs/PRODUCT_ENHANCEMENT_BACKLOG.md) + [`docs/PRODUCT_COMMERCIAL_BACKLOG.md`](docs/PRODUCT_COMMERCIAL_BACKLOG.md) | Scope (product/commercial) source of truth. |
| 6 | [`docs/README.md`](docs/README.md) | The full active-document index (~204 docs, grouped). |
| 7 | The relevant module/architecture spec for your task | See §3.4 / §3.5. |

---

## 2. Project structure

```
Akshara_ERP/
├── PROJECT_INDEX.md              ← you are here (repo-wide start-here)
├── CLAUDE.md · AGENTS.md · PROJECT_CONTEXT.md · IDEAS_BACKLOG.md   governance / AI context
├── CLEANUP_REVIEW.md · CLEANUP_COMPLETION_REPORT.md                doc-cleanup audit trail
│
├── lib/                          Flutter app (Dart)
│   ├── main.dart · firebase_options.dart
│   ├── app/ · core/ · features/ · router/ · shared/ · theme/
├── supabase/                     Backend
│   ├── functions/ (api, _shared) edge functions (Deno/TypeScript)
│   ├── migrations/               Postgres schema (source of truth for DB)
│   └── config.toml
├── backend/                      backend README / pointer
├── openapi/                      API contracts
├── deploy/akshara-vps/           VPS deployment (Docker, gateway, monitoring, storage, backup)
│
├── test/ · patrol_test/          Flutter unit/widget tests · Patrol E2E tests
├── qa/                           QA harness (agents, protocols)
├── scripts/                      build / deploy / cert / perf scripts
├── config/ · assets/ · android/ · ios/            build config & platform shells
│
└── docs/                         ← all documentation (see §3 and docs/README.md)
    ├── README.md                 active-document index (authoritative)
    ├── engineering/              Constitution + gate policy + eos/ (highest authority)
    ├── (root)                    module/role specs, *Architecture.md, certs, decisions, SRS
    ├── Operations/ Testing/      runbooks/pilot guides · device/release testing guides
    ├── Vision/ design/ legal/    forward product tracks · design system · compliance
    ├── TechnicalDebt/            debt register items
    └── archive/                  ALL historical/superseded material (645 files) — history only
```

---

## 3. Source of Truth documents

### 3.1 Engineering standards (highest authority)
- [`docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`](docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md) — the law (Part 7B Certification Engine, Part 8 EOS). **Frozen.**
- [`docs/engineering/ENGINEERING_GATE_POLICY.md`](docs/engineering/ENGINEERING_GATE_POLICY.md) — gate policy.
- [`docs/engineering/eos/`](docs/engineering/eos/) — EOS run ledger (`EOS_RUN_LEDGER.md`), improvement backlog, per-wave EOS reports.
- Enforcement tooling: [`.claude/skills/eos/`](.claude/skills/eos/) (skill) · [`.claude/commands/eos.md`](.claude/commands/eos.md) (`/eos`). Companion skills: `gap-check`, `certify`, `deploy`, `release-review`.

### 3.2 Project context & AI instructions
- [`CLAUDE.md`](CLAUDE.md) · [`AGENTS.md`](AGENTS.md) · [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) · [`IDEAS_BACKLOG.md`](IDEAS_BACKLOG.md)

### 3.3 Status, roadmap & QA program
- [`docs/ProjectStatus.md`](docs/ProjectStatus.md) — current status.
- [`docs/FINAL_QA_ROADMAP.md`](docs/FINAL_QA_ROADMAP.md) — **the** current roadmap.
- [`docs/FINAL_QA_MASTER_TRACKER.md`](docs/FINAL_QA_MASTER_TRACKER.md) · [`docs/FINAL_QA_AUDIT.md`](docs/FINAL_QA_AUDIT.md) — current QA tracker/audit.
- Current platform work: [`docs/DATA_RELIABILITY_PLATFORM_DESIGN.md`](docs/DATA_RELIABILITY_PLATFORM_DESIGN.md), `…_PHASE0_PROGRESS.md`, `…_CERTIFICATION.md`.

### 3.4 Product scope (source of truth)
- [`docs/PRODUCT_ENHANCEMENT_BACKLOG.md`](docs/PRODUCT_ENHANCEMENT_BACKLOG.md) — 🔒 FROZEN rev 5.
- [`docs/PRODUCT_COMMERCIAL_BACKLOG.md`](docs/PRODUCT_COMMERCIAL_BACKLOG.md) — reconciled 5-queue backlog.

### 3.5 Architecture (canonical)
- [`docs/TechnicalArchitecture.md`](docs/TechnicalArchitecture.md) · [`docs/BackendArchitecture.md`](docs/BackendArchitecture.md) · [`docs/DatabaseArchitecture.md`](docs/DatabaseArchitecture.md) · [`docs/AuthArchitecture.md`](docs/AuthArchitecture.md) · [`docs/RBACArchitecture.md`](docs/RBACArchitecture.md) · [`docs/TenantArchitecture.md`](docs/TenantArchitecture.md) · [`docs/AuditArchitecture.md`](docs/AuditArchitecture.md) · [`docs/DeploymentArchitecture.md`](docs/DeploymentArchitecture.md)
- [`docs/ClientBackendAlignment.md`](docs/ClientBackendAlignment.md) · [`docs/DEPLOYMENT_MODEL_AND_DR_PLAN.md`](docs/DEPLOYMENT_MODEL_AND_DR_PLAN.md) · [`docs/PERFORMANCE_TARGETS.md`](docs/PERFORMANCE_TARGETS.md)
- ⚠ `docs/BACKUP_RESTORE_RUNBOOK.md` overlaps `docs/Operations/Backup-Runbook.md` + `Restore-Runbook.md` — canonical-runbook consolidation is a **pending owner decision**.

### 3.6 Module / role specifications
`docs/` root: Academic, Admissions, finance, HR, Library, Inventory, Transport, Hostel, Marketing,
Notifications, Reports, Alumni, Audit, Management, Director, Principal, Teacher, Student, StudentSIS,
Parent, AksharaControlCenter — plus reference inventories (`RouteInventory`, `PermissionCoverageInventory`,
`MobileScreenInventory`, `SharedWidgetInventory`).

### 3.7 SRS (source of truth)
- [`docs/Akshara_ERP_Master_SRS_Part_*.txt`](docs/) (Parts 1–20, incl. 11A–11E) + `Akshara_ERP_Master_Index_Guide.txt` + `Akshara_School_ERP_SRS_v1.txt` (26 files).

### 3.8 Certifications (current QA & release evidence)
Live evidence referenced by the roadmap/tracker/EOS ledger — kept active, not archived:
`QW1_CI_ENFORCEMENT`, `QW1_COMPLETION`, `QW1_PERSONA_RBAC_MONEY`, `QW2`–`QW8` completion certs,
`QA_R_008_SECURITY`, `STAFF_FACE_ID_ATTENDANCE`, `DATA_RELIABILITY_PLATFORM` (all `docs/*_CERTIFICATION.md`).

---

## 4. Important roadmaps
- **Current:** [`docs/FINAL_QA_ROADMAP.md`](docs/FINAL_QA_ROADMAP.md) (the only active roadmap).
- Forward product tracks: [`docs/Vision/ImplementationRoadmap.md`](docs/Vision/ImplementationRoadmap.md) · [`docs/Vision/FutureVision.md`](docs/Vision/FutureVision.md).
- Superseded roadmaps (history only): [`docs/archive/roadmap/`](docs/archive/roadmap/) (16 files).

---

## 5. Design documents
- Design system: [`docs/FlutterDesignSystem.md`](docs/FlutterDesignSystem.md) (implementation reference) · [`docs/design/VISUAL_DESIGN_SYSTEM.md`](docs/design/VISUAL_DESIGN_SYSTEM.md) (approved visual system).
- Forward product designs: [`docs/Vision/design/`](docs/Vision/design/) — incl. 🔒 [`Assessment-Intelligence-Platform.md`](docs/Vision/design/Assessment-Intelligence-Platform.md) (Master Plan v3.0, locked), Org-Builder v2, Dynamic-Widget-Platform, WhatsApp-Business, etc.
- Superseded design notes, figma-era mockups, prior Fable UI/UX audit: [`docs/archive/design/`](docs/archive/design/) · [`docs/archive/audit/fable-ui-ux-audit/`](docs/archive/audit/fable-ui-ux-audit/) (history only).

---

## 6. Engineering standards
See §3.1. The Constitution + EOS are the one standard and one gate. `/gap-check`, `/certify`,
`/deploy`, `/release-review` are subordinate tools the EOS orchestrates. Legal/compliance standards
live in [`docs/legal/`](docs/legal/) (15 docs: privacy, data-retention, children-data-consent, terms, etc.).

---

## 7. Decision records (frozen)
- [`docs/ATTENDANCE_AUTH_DESIGN_DECISION.md`](docs/ATTENDANCE_AUTH_DESIGN_DECISION.md) — staff attendance auth = GPS geofence + anti-mock + live-camera face (never device biometric).
- Additional frozen product/architecture decisions are embedded in the two backlogs (§3.4) and the
  Constitution (§3.1). Historical decision/audit trails: [`docs/archive/audit/`](docs/archive/audit/) · [`docs/archive/planning/`](docs/archive/planning/).

---

## 8. Archive locations (history only — never read for current decisions)
Index: [`docs/archive/README.md`](docs/archive/README.md). **645 files** in 8 buckets:

| Bucket | Files | Contents |
|---|---:|---|
| [`archive/completed/`](docs/archive/completed/) | 257 | Certifications, completion/milestone/wave/batch closures, per-version release notes (`releases/`). |
| [`archive/audit/`](docs/archive/audit/) | 218 | One-time audits, gap/truth/readiness reports, Red-Team records, per-version arch review (`architecture-review/`), superseded product audit (`still_pending.md`), prior Fable UI/UX audit, M15 visual-gap. |
| [`archive/design/`](docs/archive/design/) | 45 | Superseded design-system versions, figma-era + dashboard + parent-home mockups. |
| [`archive/qa/`](docs/archive/qa/) | 41 | Historical QA run reports, coverage/patrol artifacts, launch/smoke screenshots. |
| [`archive/planning/`](docs/archive/planning/) | 39 | Completed execution/build plans, shipped specs, F-phase API plans. |
| [`archive/temporary/`](docs/archive/temporary/) | 24 | Handoffs, progress snapshots, orchestration/process notes. |
| [`archive/roadmap/`](docs/archive/roadmap/) | 16 | Superseded roadmaps & reconciliations. |
| [`archive/migration/`](docs/archive/migration/) | 5 | F1–F5 per-phase migration notes. |

Recover any archived file with `git log --follow <path>`. Nothing was deleted.

---

## 9. Documentation operating rules
1. **`docs/README.md` is the active index; this file is the repo-wide map.** Keep both current.
2. **AI/agents read the active tree only** — never `docs/archive/` for current decisions.
3. **One living document per concern** — one roadmap, one status, one tracker, one backlog. Supersede in place; don't spawn dated copies.
4. **Certifications/completions/audits are born archived** — new closures go straight to `docs/archive/completed/` (or `/audit/`). *(The current QA-wave certs in §3.8 are the exception: they are active evidence linked from the live roadmap.)*
5. **Archive, never delete.** Use `git mv` so history follows the file.
