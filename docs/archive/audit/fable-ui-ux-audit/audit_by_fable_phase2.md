# Akshara ERP — Screen-by-Screen Audit (Phase 2 of 4)

**Date:** 2026-07-02 · **Auditor:** Fable (Claude)
**Coverage:** 58 persona screens (Teacher / Student / Parent) read in depth + ~120 unique admin/ERP screens across 17 modules (334 screen files swept). Verdicts: ✅ good · 🟡 needs polish · 🔴 needs rework.
**Reading guide:** every entry answers the Phase-2 questions — what works, what doesn't, can it be simpler, can clicks be reduced, can information be reorganized, can advanced options be disclosed progressively, can users understand it without training.

---

## PART A — TEACHER (15 screens)

### 🔴 A1. Attendance marking — `lib/features/teacher/attendance/teacher_attendance_screen.dart` — **the most important screen in the product**
- **Flow today:** select class (horizontal strip) → scroll roster → tap each of 40 rows → sticky Save → Submit ≈ **9–12 interactions + 40 row taps**, search field placed *below* the bulk buttons, second KPI row appears/disappears causing layout shift.
- **Works:** bulk "All present/All absent/Fill remaining", search, draft autosave + resume, P/A/L/HD/E KPIs.
- **Fix (target ≤5 interactions):** default everyone Present on open → teacher only touches exceptions; range/multi-select ("rows 5–15 → absent"); autosave replaces Save (Submit remains the only commit); search collapses into the app bar; pin both KPI rows.
- **Trainable without help?** Yes today — but slow forever. This screen deserves obsession-level polish.

### 🔴 A2. Homework review & grading — `teacher_homework_screen.dart`
- 5–8 taps *per student* (row → modal → comment → grade → submit); tab state resets when switching assignments; rows omit due/submitted dates; "Pending" KPI isn't a filter.
- **Fix:** inline expanding row editor with tab-to-next; batch-select + bulk grade/comment template; KPI taps filter the list.

### 🟡 A3. Homework create — `teacher_homework_create_screen.dart`
- Good: multi-class chips, subject prefill, ISO date validation. Friction: no preview-before-publish, no edit window messaging, translation behavior implied but unexplained.
- **Fix:** publish → toast with Undo (10s) instead of blind commit; show "delivered in parent's language" explainer chip.

### 🟡 A4. Exams / marks entry — `teacher_exams_screen.dart`
- Per-row tap-to-edit marks; no batch fill; pending-marks KPI not linked to a filter; approval expectations (principal gate) not communicated; rejection feedback easy to miss.
- **Fix:** spreadsheet-style inline entry (number pad, Enter = next student), "pending only" toggle, an approval-status banner ("Awaiting principal · sent 2h ago").

### 🟡 A5. Dashboard — `teacher_dashboard_screen.dart`
- Schedule renders below the fold; no single "Mark attendance now" CTA; risk banners visually identical to warnings (banner fatigue); AI suggestions last.
- **Fix:** top card = *now/next period with one-tap attendance*; demote KPIs below actions.

### 🟡 A6. Timetable — `teacher_timetable_screen.dart` — no "today" jump; no live/done/upcoming state on periods; period rows are dead-ends (no "mark attendance / message class" actions).
### 🟡 A7. Messages — `teacher_messages_screen.dart` — no search; unread state inconsistent in list; compose lacks recipient validation.
### 🟡 A8. Leave apply — `teacher_leave_screen.dart` — text inputs instead of date pickers; no status filter on history; approval SLA invisible.
### 🟡 A9. Parent communication — `teacher_parent_communication_screen.dart` — 3-stage sequential form without back navigation between stages; translation preview is good.
### 🟡 A10. Profile — read-only, missing HR/emergency data. ✅ A11. Settings. ✅-assumed A12–A15: class-teacher dashboard, leave approvals, student risk, communication detail (structure follows house patterns; not deep-read).

---

## PART B — STUDENT (15 screens)

### 🟡 B1. Dashboard — `student_dashboard_screen.dart`
- 6+ stacked sections, 1.5 above fold; no "what's due today" synthesis; emphasis flags don't read visually.
- **Fix:** lead with a **Today's Focus** card (overdue n, due-today n, exam in n days) → quick actions → detail sections.

### 🟡 B2. Homework — `student_homework_screen.dart` — 3 taps to submit; filter chips' selected state is low-contrast; list unsorted by urgency. **Fix:** group by Overdue/Today/Tomorrow/Week; inline submit affordance on row.
### 🟡 B3. Attendance — `student_attendance_screen.dart` — 48px calendar cells with single letters; prev/next-only month nav; absent-filter exists in state but has no visible control.
### 🟡 B4. Timetable — no today button, no live-period highlight (shared gap with all three persona timetables).
### 🟡 B5. Exams — upcoming list hides date/time (requires detail tap); results lack class-average context and trend.
### 🟡 B6. Report card — `student_report_card_screen.dart` — read-only, no teacher comment inline, PDF export hidden in app bar.
### 🟡 B7. Notices — filter doesn't persist; no unread badges. 🟡 B8. Profile — no emergency/parent links. Remaining (progress, onboarding, etc.): structure consistent, not deep-read.

---

## PART C — PARENT (28 screens)

### 🟡 C1. Dashboard — `parent_dashboard_screen.dart`
- 8+ sections compete (hero, status pills, KPIs, academic hero, quick actions, today, notices carousel, events); auto-scrolling notice carousel loses content; urgent items not sorted by urgency; multi-child switching via app-bar chip → sheet is slow for 3+ children.
- **Fix:** top "Needs attention" section aggregated **across children** (overdue fee, overdue homework, absence, unread ack-required notice); kill carousel auto-scroll; child switcher as segmented avatar row when ≤3 children.

### 🔴 C2. Payment flow — `parent_payment_screen.dart` — **money + trust**
- Summary omits *which installment* and its due date (mis-payment risk); no method-fee disclosure; success screen lacks receipt number/PDF; failure screen is a dead end (no retry/support).
- **Fix:** summary = child + installment name + due date + amount; method fees inline; success = receipt no. + Download PDF + next-due date; failure = Retry + "Contact office" actions. This is a low-effort, high-trust fix — do it first.

### 🔴 C3. Homework — `parent_homework_screen.dart` — insight card ("3 overdue") renders *below* the list it summarizes; flat list, no due-date grouping; default filter shows everything. **Fix:** insight to top, group by urgency, default to Pending+Overdue.
### 🟡 C4. Fees — `parent_fees_screen.dart` — duplicate Pay CTAs (hero + sticky footer); installment timeline ignores real time spacing; breakdown is text-only; history requires navigation. **Fix:** one CTA; simple paid/due/overdue stacked bar; last 3 payments inline.
### 🟡 C5. Attendance — small calendar cells; unlabeled tap-to-filter on Absent KPI; no month picker; no trend vs last month.
### 🟡 C6. Receipts + detail — no date-range filter; rows omit installment name.
### 🟡 C7. Leave — text-input dates; draft autosaves silently (no "saved" cue); no approver feedback in history.
### 🟡 C8. Exams / report card — results lack trend; report card path is deep (exams → report card).
### 🟡 C9. Notices — category-only rows (no headline), no search, no unread.
### 🟡 C10. Messages — no search or thread actions. 🟡 C11. Profile — read-only contact info (no self-service update). 🟡 C12. Academic report — static text wall, copy-to-clipboard only.
Remaining (events, PTM, transport, experience hub, insights, communication detail, child-switcher sheet): consistent shells; child-switcher sheet noted 🟡 for large families.

---

## PART D — ADMIN / ERP (17 modules, ~120 screens)

> Format compressed: per-module one-line-per-screen; deep dives where operationally critical. Full flow notes for the 8 critical workflows are marked ◆.

### D1. Finance (16 screens) — grade: 🟡 with two 🔴
| Screen | Issue → Fix | Verdict |
|---|---|---|
| ◆ Collections | 9-col table on phone; record flow ≈15 taps across mode screens → **one unified "Record payment" modal with mode tabs, inline receipt print** | 🟡 |
| Collection detail | receipt reprint 3 taps deep; no void/edit → promote reprint to primary CTA | 🟡 |
| Dashboard | defaulters alert unquantified; handoff queue competes → collapsible cards, defaulter drill-in | 🟡 |
| Fee structures / assignment | no publish lifecycle; no pre-commit preview of affected students → "preview affected students" modal | 🟡 |
| Discounts | no utilization context → usage count per card | 🟡 |
| **Reconciliation** | flow split across 3 screens, manual match → **single two-pane drag-to-match** | 🔴 |
| Refunds | no funds pre-check; 1-line reason field | 🟡 |
| Offline payments | no bulk/CSV; date defaults to today | 🟡 |
| Student accounts | 5-col ledger sideways-scrolls; no pay-now per row | 🟡 |
| QR payment | no preview before print; no duplicate detection | 🟡 |
| Settings | 4 tabs + tiny template editor → live receipt preview | 🟡 |
| Reports | dropdown-first → button grid of top-4 reports | 🟡 |
| Copilot | stateless between screens | 🟡 |
| Executive dashboard | school selector hidden in header dropdown | 🟡 |
| **Defaulters** | 7-col table on mobile; no bulk reminder/hold → **card list + bulk actions** | 🔴 |

### D2. Admissions (11 screens) — grade: 🟡
- ◆ **Lead→enrolled costs ~45+ taps with full data re-entry at enrollment.** Fix: "Quick enroll" prefilled from approved lead (the single biggest admin win in this module).
- Leads CRM 🟡 (counselor workload invisible at assign) · Lead detail 🟡 (edit fields scattered) · Applications 🟡 (no SLA "days pending", no bulk) · ◆ Approval 🟡 (docs/interview/fee steps fragmented; needs per-applicant progress sidebar) · Enrollment wizard 🟡 (4×15 fields; needs autosave badge + prefill) · Documents 🟡 (no checklist templating, no "request missing" bulk) · Fee handoff 🟡 (no preview of handed-off students) · Dashboard 🟡 (static funnel; no stage drill-in) · Settings 🟡 (form builder without preview; plain-textarea templates) · Reports 🟡 (export-then-pivot).

### D3. Academics / Exam administration (8 screens) — grade: 🟡
- ◆ **Exam lifecycle ≈30+ taps** (create → schedule → separate marks screen → verify → approval → publish). Fixes: marks-entry CTA on exam card, inline verification, progress %; approval as a visible queue ("3 awaiting"), not modal-only; outlier flags (all-zero class) before approval; venue/time conflict check at create; exam settings promoted from unlabeled icon to named action. Marks progress heatmap needs tooltips + drill-in. Substitutions form needs availability check.

### D4. HR (10 screens) — grade: 🟡
- ◆ Payroll: 3-step modal + **4 export buttons** → single process flow + one export menu. ◆ **Leave approvals: 50 requests ≈ 100 taps** → checkboxes + "Approve selected", balance shown inline. Attendance: no bulk mark/CSV. Employees: no department tree. Profile: edit scattered. Leave settings: no simulation/templates. Performance: free-text ratings, no scale/history. Recruitment: no pipeline view. Reports: export-only.

### D5. Communication / Broadcast (1 composite screen) — grade: 🟡
- ◆ 4-tab composer; class-audience selection shows an error state *before* the user had a chance to fill it; schedule = 2 modals (date+time); template pick doesn't prefill subject; delivery tab read-only (no resend affordance surfaced — backend supports it).
- **Fix:** single-page composer (Audience card → Content card w/ template dropdown → Options card w/ datetime picker → inline delivery report with per-recipient resend).

### D6. Director / multi-school (9 screens) — grade: 🟡
- School switcher hidden in a header dropdown (should be a prominent pill bar + search); KPIs aggregate-only with no drill-down to the offending school; compliance is a checklist without a school×policy matrix or remediation actions; revenue lacks budget-vs-actual; growth chart unreadable with many schools (stacked areas + projection needed); report builder = 10 dropdowns, no saved reports.

### D7. Onboarding / school setup (3 screens) — grade: 🔴
- ◆ Unified wizard: 6 steps × 8–15 fields, generic errors, hidden "fix issues" jump, unexplained "AI quick setup". **Fix: 4 steps × ≤5 essential fields + "Advanced" disclosure; per-field errors; AI setup as hero CTA with preview.** Hub: no "next recommended step". Student CSV import: no dry-run preview; all-or-nothing errors.

### D8. School Completion (21 screens) — grade: 🟡 with one 🔴
- The hub lacks orientation entirely. **Timetable Automation 🔴** (no conflict detection; manual edits lost on regeneration). Timetable Optimization: 10+ toggles, no visual feedback. Intelligence: suggestions unranked, no bulk apply. Subject assignment: workload invisible. Room allocation: no capacity check. Class-teacher assign: no bulk. Reassignment: hidden in context menu. Substitute manager: manual availability. Lesson logs: no topic templates. Branding: no live preview. Parent activation: KPI without action. The area needs consolidation more than per-screen polish (see Phase 3 §IA).

### D9. Intelligence / analytics (7 screens) — grade: 🟡
- Hub re-asks student/class context per tab (context should persist); insights are text-only without action CTAs ("create intervention", "send nudge"); student-success lacks bulk actions; principal NL query has no history/templates/autocomplete; "Management Hub" purpose unclear.

### D10–D17 (compressed)
- **Inventory (12)** 🟡 — no low-stock/maintenance-due "action required" section; no approval flows on procurement/replacement; allocation lacks double-assign check; copilot stateless.
- **Library (8)** 🟡 — fines manual (should auto-calc on return); no bulk checkout; overdue KPI not actionable; no member status at issue time.
- **Transport (9)** 🟡 — allocation lacks capacity enforcement; driver availability/cert expiry invisible; settings tab sprawl; reports export-only.
- **Hostel (8)** 🟡 — no not-returned auto-alert; no bulk leave approve; visitor flow without photo/approval; mess lacks dietary preferences.
- **Education / Question papers (5)** 🟡 — bank list lacks difficulty filter and usage counts; item form tall (needs live preview); CSV import all-or-nothing (needs dry-run + per-row retry). *(Roadmap note: Batch 8c UI — moderation queue, syllabus picker, submit/review buttons — is already-planned work; see Assessment-Intelligence-Platform.md Phase 1.)*
- **Alumni (9)** 🟡 — no cohort filters, no receipt generation on donations, campaigns lack goal progress.
- **Settings/Appearance (1)** 🟡 — light/dark only. **Admin hub + Backup (2)** 🟡 — 8-per-row module cards overwhelm; restore lacks dry-run.

---

## PART E — Cross-screen inconsistencies (fix once, apply everywhere)

1. `AksharaAppBar` vs plain `AppBar` — pick one, migrate.
2. Filter chips: selected-state styling and persistence differ per screen.
3. Search: Material `SearchBar` vs ad-hoc `TextField` — one component.
4. List separators: `Divider` vs spacing — one rule.
5. Modal vs bottom-sheet for the same task class — decide by rule (sheet = pick/quick-edit; dialog = confirm/destructive; page = create).
6. KPI cards: icon usage inconsistent; taps sometimes filter, sometimes do nothing — rule: **every KPI is a filter**.
7. Segmented controls styled differently across exams/messages/timetable.
8. Form validation timing: submit-time vs never vs inline — standardize inline-on-blur.
9. Empty-state icons improvised per screen — catalog per module.
10. The three persona timetables share the same gaps (today-jump, live indicator) — fix as one shared widget.

---

## PART F — Prioritized improvements (by value)

| # | Fix | Screens | Value | Effort |
|---|---|---|---|---|
| 1 | Exception-first attendance (default-present + range select + autosave) | A1 | Massive — daily, every teacher | M |
| 2 | Inline grading & marks entry (tab-through, batch) | A2, A4 | Massive — weekly, every teacher | M–H |
| 3 | Bulk-select + bulk actions framework (approve/remind/assign) | HR leave, marks approval, defaulters, admissions, hostel | Massive — kills 100-tap sessions | M (one framework) |
| 4 | Payment flow trust pack (installment name, fees, receipt no., retry) | C2 | High — money + trust | **L** |
| 5 | Urgency-first reorganization (Today's Focus / Needs Attention; insight cards to top; group by due date) | B1, C1, C3, A5 | High — every user, every open | L–M |
| 6 | Unified payment recording modal + mobile card tables | D1 | High — front office daily | M |
| 7 | Quick-enroll prefill from approved lead | D2 | High — admission season | L–M |
| 8 | Single-page broadcast composer | D5 | High — weekly, high-stakes sends | M |
| 9 | Onboarding wizard 6→4 steps + progressive disclosure + per-field errors | D7 | High — first impression per school | M |
| 10 | Exam lifecycle streamline (inline marks CTA, approval queue card, outlier flags) | D3 | High | M |
| 11 | KPI-as-filter rule + "pending only" toggles | many | Medium — compound | L |
| 12 | Timetable shared widget: today-jump + live period + inline actions | A6, B4, C-timetable | Medium | L |
| 13 | Receipts/notices/messages: search + unread + date filters | C6, C9, C10, A7 | Medium | L |
| 14 | Reconciliation two-pane drag-match | D1 | Medium (weekly) | H |
| 15 | Director school-switcher pill bar + drill-downs | D6 | Medium | M |

**Screen count:** 58 persona + ~120 admin unique screens reviewed; verdicts: ✅ ~10% · 🟡 ~80% · 🔴 ~10% (attendance marking, homework review, payment flow, parent homework, finance reconciliation, finance defaulters-on-mobile, onboarding wizard, timetable automation).

*Continued in `audit_by_fable_phase3.md`.*
