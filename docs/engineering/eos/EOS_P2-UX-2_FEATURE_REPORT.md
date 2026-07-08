# EOS Report — P2-UX-2 "the five daily tasks" (B2)

**Date:** 2026-07-08 · **Scope:** feature/screen (UX) · **Gate:** **PASS**
**Standard:** [AKSHARA_ENGINEERING_CONSTITUTION.md](../AKSHARA_ENGINEERING_CONSTITUTION.md) — Part 7B (Certification Engine) · Part 8 (EOS).
**Commits:** `88d76df1` · `723927b7` · `fb781751` · `fec526e5` (quick-win sub-waves, prior) · **`ce45cf87`** (fee counter §2.4) · **`b34f2116`** (Approvals Inbox §2.3) · **`87841013`** (attendance exception grid §2.1) · **`43c8f8df`** (shared marks grid §2.2/2.5).

This report is evidence-based and cites the Constitution by Part; it does not restate the rules.

---

## 1. Scope evaluated

P2-UX-2 makes the five highest-frequency daily tasks fast and trustworthy, discovery-first (most surfaces existed — verified, gaps closed, nothing rebuilt):

1. **Fee-counter advanced workflow (§2.4 remainder)** — PSID/name/class origination from the student-accounts search, real dues-breakdown prefill (killed the hardcoded `5000`), amber "queued receipt" offline ceremony.
2. **Approvals Inbox polish (§2.3)** — a **server-provided** maker-checker (`sodBlocked`) flag + badge + Approve-disable, swipe-to-decide, type-grouping + critical/newest sort, on-card decision facts.
3. **Attendance exception grid (§2.1)** — compact tap-cycle grid + single sticky present/absent/late summary bar (replacing the KPI cards).
4. **Shared spreadsheet-grade marks grid (§2.2/2.5)** — ONE shared kit (`lib/shared/marks_grid/`) rendered by **both** marks-entry chains.

---

## 2. Certification categories (Part 7B) — verdicts with evidence

| Category | Verdict | Evidence |
|---|---|---|
| Functional behaviour | **PASS** | Each surface driven by tests; existing behaviour preserved (attendance submit gate, teacher/admin save paths, money mutation, approvals decide). Full suite **3711 pass / 2 known UX-7 (0 new)**. |
| UI/UX | **PASS** | Consistent shared components: `AksharaSuccessView`/new `AksharaQueuedView`, approvals badge/swipe/grouping, `AttendanceExceptionGrid`, `marks_grid` kit. |
| RBAC (Part 4A) | **PASS** | Gates preserved: Collect-fee = `manageFinance`; approvals decide = `approvalPermissionForType` via `AksharaApproveAction` **and** swipe gated on `rbacServiceProvider.hasPermission`; attendance correction = `submitAttendanceCorrection`; exam marks = `manageExamMarks`. No permission widened. |
| Separation of duties (governance) | **PASS — strengthened** | Approvals SoD stays 100% server-side: `isSelfApproveDeniedType` is the single source (`approval_repository.ts`), `decideApproval` still 403s a self-approve. The client badge/disable/swipe-block only **read** the additive `sodBlocked` flag — no client re-derivation (per owner rule). deno approval **62/0** (+3 flag tests). |
| Reliability — drafts/sync (Part 4B) | **PASS** | REL-3 draft autosave intact for fee collection (`rel3_fee_collection_draft_test`) + admin marks (`rel3_marks_draft_autosave_test`) + attendance; offline fee collection stays `pendingSync` → honest amber card, **no fabricated receipt**. |
| Money safety (Part 5) | **PASS** | Finance = sole engine; no money-path logic changed. Dialog + QR amounts now reflect the real invoice outstanding / student balance (removed the magic `5000`); `createCollectionProvider` untouched. |
| Certified exam-marks path | **PASS** | Admin AB/ML/DB never-write-0, `row_version` REL-5, grace/moderation, Save-all, REL-3 draft all untouched — `exam_marks_entry_screen_test` + draft test green (46/… + 28). Teacher chain reuses its existing `saveTeacherExamMarkFromInput`/`updateExamMark` (Save-all just loops it — no new backend). |
| Testing (Part 6) | **PASS** | `flutter analyze` 0; +~40 new widget/unit tests; full suite regression-clean. |
| Accessibility | **PASS** | New tiles/dots/badges carry `Semantics` labels (exception tile, mark save dot, column stats, maker-checker badge). |
| Localization / white-label / offline / perf / security | **N/A (unchanged)** | UX polish; no new API contract (approval `sodBlocked` is an additive read field), migration, or config. |

---

## 3. Automatic-failure conditions (Part 7B) — all clear

data loss · security breach · **permission escalation** (SoD *strengthened*, not weakened) · tenant-isolation failure · critical crash · duplicate financial transaction (offline idempotency unchanged) · broken auth/sync · **critical regression** (0 new test failures) · failed backup verification · production blocker — **none triggered.**

---

## 4. Regression evidence

- `flutter analyze` → **0 issues** (lib + test).
- `flutter test` (full) → **3711 pass · 1 skip · 2 fail** — the 2 fails are the **pre-existing UX-7** (`TeacherDashboardScreen 360×640` overflow), a screen untouched this wave (tracked to a later P2-UX slice). **0 new failures.**
- `deno test supabase/functions/_shared/approval/` → **62/0** (+3 SoD-flag tests); `deno check` green.
- Goldens: **3 approval-center baselines regenerated deliberately** (on-card summary + type-group headers + critical sort). No other golden changed; the touched attendance/exams/finance-dialog surfaces have **no golden** (modals / no committed baseline).

---

## 5. Gate verdict

**PASS** — 0 P0 / 0 P1 (2 known pre-existing UX-7, unrelated). No behaviour or governance regression; the approvals SoD control is server-owned and strengthened; the certified exam-marks and money paths are intact. P2-UX-2 is **complete**; advance `NEXT_ACTIVE_WAVE` to **P2-UX-3**.
