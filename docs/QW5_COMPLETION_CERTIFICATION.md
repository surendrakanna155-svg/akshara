# QW5 — Secondary / Advanced / Verticals Journeys · COMPLETION CERTIFICATION

**Date:** 2026-06-30 · **Branch:** `feature/data-reliability-platform`
**Gate:** Engineering Operating System (`/eos`) per [`engineering/ENGINEERING_GATE_POLICY.md`](engineering/ENGINEERING_GATE_POLICY.md).
**Companion:** [`FINAL_QA_MASTER_TRACKER.md`](FINAL_QA_MASTER_TRACKER.md) · [`FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md) · [`PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md).

---

## Verdict

> **EOS gate: PASS** for all locally-verifiable QW5 work. The wave is **CONDITIONAL at the program
> level** pending **1 Partial** row (live platform-ops backend) and **1 Blocked** row (deferred by
> owner decision to QW8). **No locally-fixable P0/P1 remains** — every P2 row that could be proven on
> local hardware is, and the two that could not are honestly marked, not forced.

**QW5 row status (14-row wave): 12 Verified · 1 Partial · 1 Blocked.**

Authoritative sweep on local hardware:
- **Flutter** `flutter test` → **2905 passed / 0 failed** (1 skipped) — up +31 from QW4's 2874, no regression.
- `flutter analyze` → **0 issues**.
- **11 new test files** + **1 additive feature wire-up** (student report-card export) + **1 new QA key**.

---

## Backlog cross-check FIRST (the wave's defining discipline)

Per the owner's standing instruction, **every row was compared against
[`PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md) and `still_pending.md` BEFORE any
test was written.** A 5-agent read-only discovery pass classified each P2 journey as REAL /
READ-ONLY / MOCK / PHASE-2-DISABLED. Three rows collided with a feature gap or a locked roadmap
decision and were **escalated to the owner for a decision instead of being assumed** — the owner's
rulings are baked into the wave:

| Row | Collision | Owner decision (2026-06-30) | How QW5 honoured it |
|---|---|---|---|
| **QA-J-046** backup→restore | User-facing Restore has **no backend** (UI-only); the real build is already a Must-Before-GA item. | **Defer to QW8 `QA-R-009`.** | Marked **Blocked (feature)**; nothing built in the P2 wave. |
| **QA-J-056** white-label apply | Platform white-label API is **OFF live / empty stubs** — `manageWhiteLabelPlatform` removed from every role (O10, Phase 2). | **Re-scope to certify GA-ready School Branding.** | Tested `PUT /school/branding` (`manageSchoolBranding`, real persistence); Phase-2 platform boundary pinned. |
| **QA-J-011** student report-card download | View real, but the student-app **export button was never wired** (parent app had it). | **Wire the student export button now.** | Added the action reusing the SHARED `AksharaReportExportService` (parity, no new pipeline). |

No new product behaviour was introduced beyond the one owner-approved wire-up.

---

## Approach

QW5 covers the lower-risk P2 journeys once the core was locked. Two proof shapes were used, matching
the established QW2 discipline (prove the gate the real mutation uses; cite persistence from existing
e2e suites) plus QW3-style widget pumps where a row is genuinely display-only:

- **Authorization-gate proofs** (deterministic, against the real `MutationPermissionRegistry` /
  `RolePermissionMatrix` / `EntitlementResolver`) for the verb-and-persona rows: 018, 023, 031, 045,
  050, 051, 056, 065, 067. Each asserts the holder is authorized **and** the unrelated/lower personas
  are denied, including three anti-escalation separations (refund-approve ≠ manageFinance; teacher
  drafts-but-cannot-publish an achievement; a director-portal permission holder is still
  entitlement-gated).
- **Widget render proofs** for the display rows: 006 (transport route/stop/vehicle renders + empty
  state + Phase-2 boundary) and 011 (export action visibility + dispatch).
- **Cited coverage** for 007 (mark-read persistence already proven by
  `qw4_notifications_persistence_test`).

| Batch | Rows | Result |
|---|---|---|
| 1 — Parent/Student display + report-card export | 006, 007, 011 | 3 V (006/011 new tests; 007 cited) |
| 2 — Teacher intervention + HR recruitment/performance | 018, 023 | 2 V (authz) |
| 3 — Finance refund verb-negative + room/syllabus | 031, 045 | 2 V |
| 4 — Director board-pack + entitlement lock + alert-ack + School Branding | 050, 051, 055, 056 | 3 V · 1 Partial |
| 5 — Import under schoolAdmin + achievement multi-channel | 065, 067 | 2 V |

EOS gate run after every batch (analyze clean + scope green) → all PASS.

### Notable proofs
- **Verb anti-escalation (refund)** — `finance/approveRefund` is the dedicated `approveRefunds` verb,
  not `manageFinance`; a principal (broad perms) is denied it (`QA-J-031`).
- **Entitlement lock over permission** — a `manageDirectorPortal` holder is still masked off when the
  plan lacks `module.multi_branch` → `PlanLockedModuleView` upgrade view, not a 403 (`QA-J-051`).
- **Create vs publish separation** — a teacher may draft an achievement (`manageAchievementPromotion`)
  but cannot approve/publish it (`approveAchievementPromotion`); schoolAdmin holds the full chain
  (`QA-J-067`).
- **Honest per-channel scoping** — the achievement publish fan-out is real for in-app (4 apps) +
  website, but WhatsApp is a share-deeplink (Phase 1) and Facebook/Instagram are `pending_connection`
  (Phase 2); asserted as-is via `publisher_test.ts`, not faked (`QA-J-067`).

---

## The one feature change (owner-approved)

- **Student report-card download** (`QA-J-011`) — `student_report_card_screen.dart` gains an export
  action in the app bar (`additionalActions`), gated on a published `studentReportCardProvider` card,
  calling the **same** `AksharaReportExportService.shareReportCardPdf` the parent app already uses.
  New QA key `studentReportCardExportButton`. Additive, parity-driven, no new export pipeline.
  `qw5_student_report_card_export_test` — 3/3 green.

---

## Remaining QW5 rows — honestly blocked / partial

- **`QA-J-055` · Partial — platform alert acknowledge.** The acknowledge gate CONTRACT
  (`platform_operations/acknowledgeAlert` → `managePlatformOperations`) is asserted, and the gate is
  pinned as held by **no role**. The live acknowledge persistence round-trip is **infra-blocked**:
  `managePlatformOperations` was deliberately removed from all roles and the platform-operations
  backend is **unseeded server-side** (`GET /platform-operations/observability` is 404 live —
  `role_permissions.dart` SA-1/MJ-L5). Belongs to a live-platform-ops lane, not a headless unit test.
- **`QA-J-046` · Blocked — backup→restore.** Deferred to **QW8 `QA-R-009`** by owner decision. Backup
  is real (`ops_backup_runs` ledger + nightly encrypted dumps + `/health/backup`); the user-facing
  **Restore has no backend** and its real build + DR drill is a Must-Before-GA item, out of scope for
  a P2 quality wave.

These two join the program's existing live-infra lane; no locally-verifiable P0/P1 remains.

---

## Bottom line

Every QW5 P2 journey that can be proven on local hardware now is — **12/14 Verified**, with 1 Partial
(gate contract green; live platform-ops round-trip infra-blocked) and 1 Blocked (owner-deferred to
QW8). The wave's real value was **discipline over volume**: a mandatory backlog cross-check caught two
rows colliding with locked roadmap decisions (backup-restore, white-label) and a feature gap
(student download) **before** any code was written, each routed to the owner for a decision rather
than assumed. The result wires exactly one owner-approved feature (student report-card export),
re-scopes one row to its GA-ready slice, and marks the genuinely-blocked work honestly.
**QW5's locally-verifiable scope is COMPLETE.**
