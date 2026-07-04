# EOS → Constitution Map

A **thin index**, not a copy. It maps each thing the EOS evaluates to the
Constitution Part and section that *owns the rule*. The EOS reads the real text
there and applies that section's **Acceptance Criteria** and **Failure
Conditions**. Reference these names — do not restate the rules here or in reports.

Source of truth:
[docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md](../../../docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md).
Cite by **Part + section heading** (stable), never by line number (shifts).

## Constitution parts (top level)

| Part | Title |
|------|-------|
| 1 | Engineering Philosophy, Foundation & Core Principles |
| 2A | Engineering Architecture & Code Philosophy |
| 2B | Code Quality, Standards & Maintainability |
| 3A | UI & User Experience Certification |
| 3B | Feature Behaviour & End-to-End Certification |
| 4A | Security & RBAC Certification |
| 4B | Reliability, Offline, Sync & Data Protection |
| 4C | Data Governance, Privacy & Compliance |
| 5A | Performance & Scalability Certification |
| 5B | Resilience, Operations & Continuous Improvement |
| 6A | Testing & QA Engineering |
| 6B | Product Validation & Pilot Certification |
| 6C | Release Engineering & DevOps Certification |
| 7A | Engineering Governance & Decision Framework |
| 7B | **Certification Engine** (levels, categories, evidence, pass/fail, severity, gates, score) |
| 8 | **Engineering Operating System (EOS)** — this skill's specification |

## The 20 certification categories → owning Part(s)

Categories are enumerated in **Part 7B — Certification Categories**. For each,
evaluate against the listed sections' Acceptance Criteria + Failure Conditions.

| # | Category | Owning Part(s) | Key sections to apply |
|---|----------|----------------|-----------------------|
| 1 | Architecture | 2A | Clean Architecture · Separation of Concerns · Dependency Direction · Anti-Patterns · Architecture Acceptance Criteria / Failure Conditions |
| 2 | Code Quality | 2B | SOLID · Naming/Function/Class Rules · Code Duplication · Magic Values · Code Smells · Maintainability KPIs · Acceptance / Failure |
| 3 | Feature Behaviour | 3B | Every Feature/Workflow Must Be Certified · CRUD · Business Rule · State · Navigation · Data Integrity · Cross-Module · Regression Certification |
| 4 | User Experience | 3A | Every Interactive Component Verified · Every Screen Certified · Form/Search/Filter/Sort Certification · Empty/Loading/Error/Success Standards · User Journey Certification |
| 5 | Accessibility | 3A | UI Design Principles · Visual Consistency · Responsive Behaviour · UX Acceptance / Failure (+ 6A — Localization/Accessibility testing where evidence lives) |
| 6 | Localization | 3B (Multi-Language Behaviour) + 6A (Localization Testing) | Multi-Language Behaviour · Localization Testing |
| 7 | Security | 4A | Authentication/Authorization · Tenant Isolation · API Security · Input Validation · Sensitive Data · OWASP · Session/File-Upload Security · Audit Logging · Security Acceptance / Failure |
| 8 | RBAC | 4A (RBAC Certification) | RBAC Certification · Multi-Role Certification · Authorization Certification |
| 9 | Performance | 5A | UI/Backend/Database/Search/File/Sync Performance · Memory · Performance Acceptance / Failure |
| 10 | Reliability | 4B | Reliability Philosophy · Draft Persistence · Autosave · Crash/Connectivity Recovery · Reliability Acceptance / Failure |
| 11 | Offline Behaviour | 4B (Offline Philosophy) | Offline Philosophy · Operation Policy · Queue Behaviour |
| 12 | Synchronization | 4B (Sync Engine) | Sync Engine · Retry · Conflict Resolution · Idempotency · Synchronization Verification |
| 13 | Communication | 3B (Communication Behaviour) + 6A (Communication Testing) | Communication Behaviour · Notification Certification · Communication Testing |
| 14 | Analytics | 6B + 8 (Inputs/Continuous Learning) | Success Metrics · Continuous Learning · (Part 8 Inputs: Analytics, Crash Reports) |
| 15 | White Label | 3B (White-Label Behaviour) + 6A (White-Label Testing) | White-Label Behaviour · White-Label Testing |
| 16 | Scalability | 5A (Scalability) + 5B | Scalability Verification · Load/Stress/Endurance Testing · Capacity Planning |
| 17 | Testing | 6A | Testing Pyramid · Definition of Test Coverage · Unit/Widget/Integration/E2E/Patrol/Regression/Security/Reliability/Performance/Localization/Communication/White-Label/AI Testing · Certification |
| 18 | Documentation | 2B (Documentation) + 7A (Documentation Standards) | Documentation · Documentation Standards · ADRs |
| 19 | Production Readiness | 5B + 6C + 6B | Operational Readiness · Release Lifecycle · Deployment Verification · Rollback · Smoke Testing · Monitoring · Production Readiness Review |
| 20 | Commercial Readiness | 6B | Pilot School Certification · Real Workflow Validation · UAT · Usability · Success Metrics · Acceptance / Failure |

Also governed by **Part 4C — Data Governance, Privacy & Compliance** (data
ownership/lifecycle/classification, soft/permanent delete, backup/restore,
import/export, retention) — fold into Security (7), Reliability (10), and
Production Readiness (19) as applicable.

## Part 8 detection checklist → where it lives

The EOS's *detection* responsibilities come straight from **Part 8**:

- **Inputs** — Part 8 *Inputs* (what to analyze).
- **Continuous Analysis** — Part 8 *Continuous Analysis* (missing/incomplete
  features, broken/untested workflows, missing tests/docs, arch violations,
  perf regressions, security risks, a11y/l10n/white-label/offline/sync/
  notification gaps, reliability risks, tech debt, deprecated/unused/dead code,
  large files/classes, duplicate logic, broken deps, config problems).
- **Automatic Detection** — Part 8 *Automatic Detection* (missing buttons/
  navigation/screens/dialogs/menus/forms/validations/permissions and missing
  role/API/widget/Patrol/backend/manual tests, missing pilot/production
  validation).
- **Engineering Health** — Part 8 *Engineering Health* (per-pillar + overall
  health scores).
- **Gap Discovery fields** — Part 8 *Gap Discovery* (Description · Evidence ·
  Severity · Business Impact · Engineering Impact · Recommended Solution ·
  Estimated Effort · Priority · Dependencies · Suggested Owner). Use these as
  the required fields for every gap the EOS reports.
- **Prioritization** — Part 8 *Prioritization* (Critical/High/Medium/Low/Nice;
  by User/Data/Security/Production risk + Business/Engineering value).
- **Automatic Roadmap** — Part 8 *Automatic Roadmap* (group related work,
  respect dependencies, never recommend an unsafe order).
- **Release Decision** — Part 8 *Release Decision* (the 7 release states).

## Certification engine knobs → Part 7B

- **Certification Levels** (8 states) — *Certification Levels*.
- **Certification Scope** (function → … → commercial release) — *Certification Scope*.
- **Evidence Requirements** — *Evidence Requirements*.
- **Mandatory Certification Rules / Pass Conditions** — same-named sections.
- **Automatic Failure Conditions** (data loss, security breach, permission
  escalation, tenant-isolation failure, critical crash, duplicate financial
  transaction, broken auth/sync, critical regression, missing backup
  verification, production blocker) — *Automatic Failure Conditions*.
- **Severity P0–P3** — *Certification Severity*; **Release Rules** (any open P0
  blocks) — *Release Rules*.
- **Engineering Gates** (Merge → QA → Staging → Pilot → Production → Commercial)
  — *Engineering Gates*.
- **Engineering Score** (scores guide, never approve) — *Engineering Score*.

## Maintenance note

If the Constitution adds a Part or renames a section, update only this file and
(if a new category appears) the table above — the skill body and companion docs
should not need to change. See [MAINTENANCE.md](MAINTENANCE.md).
