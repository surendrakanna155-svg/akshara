# Akshara ERP — UI/UX Master Report & Prioritized Action Plan

**Date:** 2026-07-02 · **Auditor:** Fable (Claude)
**Sources:** `audit_by_fable_phase1.md` (product audit) · `audit_by_fable_phase2.md` (screen-by-screen, ~180 screens) · `audit_by_fable_phase3.md` (redesign strategy) · `audit_by_fable_phase4.md` (innovation)
**Sequencing note:** the current engineering roadmap (module completion → red-team → pilot) is not displaced by this plan; Tier 1 items are small enough to ride along, Tiers 2–4 are the post-pilot product-excellence program. All new capabilities (Tier 4) are backlog candidates for the owner to mint — the backlog remains the single source of truth.

---

## The verdict in three sentences

Akshara's UX **foundation outclasses its UX**: persona shells, a real token system, offline infrastructure, and approval governance are stronger than typical school ERPs — but the five highest-frequency workflows (attendance, marks, grading, approvals, fee collection) carry the most friction, the design system is unenforced across the long tail, and the feedback layer (skeletons, haptics, refresh, undo) is absent. **Overall: 5.5/10 today; the path to 8+ requires no re-architecture** — it requires ergonomic obsession on daily tasks, enforcement of what already exists, and action-first information design. The differentiators are already in the codebase (offline honesty, governance visibility, deep links) — they're built, just not *shown*.

---

## The master plan — highest impact first

### TIER 1 — "Feel & trust" pack (low effort · product-wide effect · can ride along current roadmap)

| # | Action | From | Why first |
|---|---|---|---|
| 1 | **Payment-flow trust pack**: installment name + due date in summary, method fees, receipt no. + PDF on success, retry/support on failure | P2-C2 | Money + trust; lowest effort : impact ratio in the entire audit |
| 2 | **Keyboard-type sweep**: correct `keyboardType` on ~1,402 numeric/phone/email fields | P1 §6 | Every keystroke, every user, every day; mechanical fix |
| 3 | **Feedback layer**: haptics on commits (0→std), pull-to-refresh on lists (1→std), skeletons on async screens (0→std), success views for payment/marks-submit | P3-R7 | The perceived-quality gap vs consumer apps parents use daily |
| 4 | **Urgency-first reorder**: insight/overdue cards to top; group homework by Overdue/Today/Week; default filters to pending | P2-C3/B2/C1 | Screen-reshuffles, no new logic; every open benefits |
| 5 | **Copy pass**: finish error dictionary (~30% raw enums), kill ALL-CAPS labels, terminology lock, empty states get actions | P3-R10 | Cheapest premium-feel upgrade available |
| 6 | **Freshness chip**: render the already-flagged offline-cache state — "As of 09:12 · offline" on money/attendance surfaces | P3-R8 | Converts invisible infrastructure into visible trust; prevents stale-data decisions |
| 7 | **PopScope + draft-chip**: dirty-state guards on form screens (4→~50); surface the existing autosave as "Draft saved · 12:41" | P1 §3 | Stops silent work loss |

### TIER 2 — The workhorses (medium effort · the adoption battle)

| # | Action | From | Target |
|---|---|---|---|
| 8 | **Exception-grid attendance**: default-present, touch-exceptions-only, range select, autosave-not-save, anomaly check | P3-R2 | 40-student class in ≤5 interactions (from ~50) |
| 9 | **Inline marks entry & grading**: spreadsheet ergonomics, tab-through, number pads, batch fill, pending-only toggle | P3-R2 | 50% faster marks/grading throughput |
| 10 | **Bulk-operations framework**: select-mode + bulk actions on every operable list (leave approvals, defaulters, admissions, moderation) | P2-F3 | 50 leave approvals: 100 taps → 3 |
| 11 | **Approvals Inbox**: one cross-module queue (marks, leave, papers, refunds, outpass) with age/SLA, bulk approve, requester-side status mirror | P3-R3 | Principal's #1 job gets a home |
| 12 | **Responsive table contract**: one AksharaDataTable — dense+sortable ≥768px, auto card-list <768px; migrate collections/defaulters/ledgers first | P3-R5 | Kills the worst mobile pattern |
| 13 | **Form kit + 5-field doctrine**: inline validation, autofocus, submit-guards, Advanced-section disclosure; apply to worst five forms (onboarding wizard 6→4 steps, enrollment, broadcast, exam create, leave) | P3-R6 | Untrained-clerk usability |
| 14 | **Unified payment-recording modal** (mode tabs, inline receipt) + quick-enroll-from-lead prefill | P2-F6/F7 | Front-office daily speed |

### TIER 3 — Structure & system (the compounding layer)

| # | Action | From |
|---|---|---|
| 15 | **Design-system enforcement**: lints (no raw colors/TextStyle/off-scale spacing) error-on-new-code; migration sweep (172 TextStyles, ~186 colors, 21→6 spacings); contrast checker in CI; persona-shell golden baselines; StatusChip = icon+label (kill color-only) | P3-R11 |
| 16 | **Today homes (full)**: action-layer + pulse-layer for all four personas | P3-R1 |
| 17 | **Deep-linked notifications + quick-action layer**: every push lands on its record; per-persona FAB/app-shortcuts; ⌘K command palette on desktop admin | P3-R4 |
| 18 | **Admin IA surgery**: School-Completion 21 screens → Setup / Timetable Studio / Daily Ops; one settings surface per module; Intelligence context persistence + action CTAs; Director pill-bar + drill-downs | P3-R9 |
| 19 | **List-virtualization sweep**: 161 non-builder ListViews → builders + pagination affordances | P1 §9 |
| 20 | **KPI-as-filter rule** + shared timetable widget (today-jump, live-period, inline actions) | P2-F11/F12 |

### TIER 4 — New capabilities (owner to mint into backlog; post-pilot)

| # | Idea | Priority (from Phase 4) |
|---|---|---|
| 21 | UPI-native payments: intent links, dynamic QR, webhook auto-receipt & auto-reconcile | P1 |
| 22 | Morning Brief (role-scoped daily pulse, deterministic-first) | P1 |
| 23 | Parent weekly digest (deterministic catalog, existing channels) | P1 |
| 24 | Student 360 (aggregate profile from global search) | P1 |
| 25 | Actionable notifications (approve/acknowledge from push) | P1 |
| 26 | Period-aware attendance prompts · Day-Close ritual · Anomaly guards · Setup Health Score | P2 |
| 27 | Undo platform + record history · Saved views & report subscriptions · Family pay-together | P2 |
| 28 | Explain-this-number · Voice capture · PTM slot booking | P3 |

---

## Impact × Effort at a glance

```
IMPACT
  ▲
  │  #8 attendance grid        #21 UPI pack
  │  #9 inline marks           #22 Morning Brief
  │  #10 bulk framework        #11 Approvals inbox
  │  #16 Today homes           #24 Student 360
  │─────────────────────────────────────────────
  │  #1 payment trust  #2 keyboards   #15 DS enforcement
  │  #3 feel layer     #4 urgency     #18 IA surgery
  │  #5 copy  #6 freshness  #7 guards #17 deep links
  │─────────────────────────────────────────────
  │  #12 tables  #13 forms  #14 office │ #19 lists  #20 KPI rule
  └──────────────────────────────────────────────▶ EFFORT
        LOW                MEDIUM              HIGH
   (Tier 1 = low-effort/high-impact: do first, in any order)
```

## Measures of success

| Metric | Today (audit) | Target |
|---|---|---|
| Interactions to mark a 40-student class | ~50 | ≤5 |
| Taps to grade one submission | 5–8 | ≤2 |
| Taps to approve 50 leaves | ~100 | ≤3 |
| Fields with keyboard hints | ~4% | 100% |
| Screens with skeleton loading | 0 | all async |
| Pull-to-refresh coverage | 1 screen | all lists |
| Raw error enums reachable in UI | ~30% | 0 |
| Raw TextStyle / hardcoded colors on new code | unenforced | lint-blocked |
| Push notifications that deep-link | ~0 | 100% |
| Empty states with a next action | ~14% | 100% |
| Product experience score (Phase 1 rubric) | 5.5/10 | 8/10 |

## Governance of this plan

- Tier 1 items are individually small; each ships through the standard EOS gate like any change.
- Tier 2–3 constitute a **Product Excellence (UX) wave** — recommend running it as a named wave with the same certification discipline as QW1–QW8, after the current pilot track.
- Tier 4 items enter `docs/PRODUCT_COMMERCIAL_BACKLOG.md` / `PRODUCT_ENHANCEMENT_BACKLOG.md` only by owner decision (backlog is frozen at rev 5).
- Re-audit checkpoint: rerun the Phase-1 rubric after Tier 2 completes; expect ≥7/10 before investing in Tier 3's IA surgery.

---

*End of master report. Full evidence and per-screen detail in the four phase reports alongside this file.*
