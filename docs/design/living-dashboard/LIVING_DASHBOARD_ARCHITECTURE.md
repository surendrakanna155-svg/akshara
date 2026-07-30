# Living Dashboard — Architecture & Implementation Roadmap

**Status:** 🟡 Design proposal (no code) · **Date:** 2026-07-30
**Extends:** [`../adaptive-ai/04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md`](../adaptive-ai/04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md) (design-final, 2026-07-03)
**Wave alignment:** `09_IMPLEMENTATION_WAVES_AND_METRICS.md` → **W2.0** (Priority + Recommendation engines)
**LLM policy:** Tier‑1 only. The dashboard path must never call `callModelGateway` / `governedTextFor` / `governedModelText`.

> **Mission.** Turn the dashboard from a static collection of widgets into a dynamic,
> priority-driven workspace that continuously answers *"what should this user do next?"* —
> deterministically, explainably, with zero model calls.

---

## 1. What already exists (audited 2026-07-30)

The engine is **built and good**. This is not a greenfield project; it is a delta.

| Capability | Status | Location |
|---|---|---|
| Deterministic scorer (`urgency × impact × ageBoost × learnedWeight`, normalized 0–100) | ✅ pure, clock-free, 16 tests | `_shared/intelligence/priority/priority_engine.ts` |
| Typed item taxonomy + stable `itemKey` identity | ✅ | `priority_types.ts:11-25` |
| 20 candidate generators across 8 modules, each RBAC-gated | ✅ | `priority_sources.ts`, `ops_sources.ts`, `teacher_/parent_/student_sources.ts` |
| 7 personas, persona-isolated feeds (privacy by construction) | ✅ | `priority_feed_service.ts:126-132` |
| Learned weights from accept/dismiss/suppress | ✅ wired end-to-end | `ai_persona_memory_repository.ts:89-98` |
| Feed + recommendation + feedback routes | ✅ | `intelligence_router.ts:62-77` |
| Explainability (`reason` + `factorBreakdown`) | ✅ | `priority_engine.ts:134-157` |
| Feed UI with dismiss/suppress + score badge | ✅ on 5 dashboards | `lib/features/adaptive_ai/widgets/adaptive_priority_feed.dart` |
| **Order-sorted, RBAC-filtered, backend-resolved layout platform** | ✅ built, **siloed & unstyled** | `lib/features/dynamic_widgets/` |
| Per-user dashboard arrangement store | ✅ | `dashboard_layouts` (mig `20260622900000`) |
| Event outbox (157 event types) + Signal Refinery + fact signals | ✅ built | `signal_refinery.ts`, `ai_fact_signals` |
| Single scheduling rail (XCT‑2) + cron-token auth, cronned `*/5` | ✅ | `_shared/reminders/reminders_service.ts` |
| Per-item dismiss precedent with auto-resurface next day | ✅ | `operations_hub_item_actions` (mig `20260865000000`) |

**Reuse verdict: build almost nothing new at the engine layer.** The work is lifecycle, composition, liveness, and honesty.

---

## 2. Gaps — ranked by whether they block the mission

### 2.1 Blocking: the data is not honest yet

Certification `9587ce76` (2026-07-29) — **NOT CERTIFIED, nothing fixed**:

- **WIDGET‑001/002 (P0)** — parent and teacher dashboards render `.mock()` on **every cold open**, not merely on failure. `parentDashboardLoadingProvider` / `teacherDashboardLoadingProvider` are `StateProvider<bool>` defaulting to `false`, **never written outside tests**, so the skeleton path is dead code. A parent sees a fabricated child, `"₹4,200 due"`, `"Present · Marked 9:12 AM"`. A teacher sees `"9:02 AM · Geo+Face verified"` — a biometric assertion that never happened, on the record that feeds payroll.
- **WIDGET‑011 (P0)** — the principal's School Health Score falls back to hard-coded components and reports a confident **51** for a school with no data.
- **9 of 10 module dashboards** ship filter chips whose state the data fetch never reads.

The mission's first principle is *live data only* and *every decision must be traceable*. **A priority engine ranking fabricated inputs ranks confidently and is wrong**, and it makes the fabrication far harder to spot. This is Phase 0.

### 2.2 Structural: deadlines barely exist

The scorer's `urgency` factor is its strongest signal. But across **269 migrations, only 7 tables carry a real due-date/SLA column**:

`complaints.sla_due_at` · `director_compliance_items.due_date` · `finance_promises_to_pay.promise_date` · `growth_inquiries.follow_up_at` · `teacher_interventions.follow_up_at` · `edu_homework_assignments.due_date` · `gate_passes.scheduled_at`

**Every approval and maker-checker queue is deadline-free** — `approval_requests`, `stock_adjustments`, `finance_fee_reductions`, `student_clearance_waivers`, `staff_attendance_requests`, `mobile_leave_requests`, `attendance_corrections`. They have no `assignee` either (only `complaints` and `support_platform_incident` do).

Consequence: for most work items `urgency` degrades to a static `impactClass` constant. *"8 approvals ≥48h old"* — doc 04's headline principal recommendation — **cannot be computed today**.

### 2.3 Lifecycle: dismissal is destructive and permanent

- Dismissals live in **one unbounded JSONB array** (`ai_persona_memory.preferences.dismissedKeys`) — no timestamp, no actor, no expiry, no severity watermark, never pruned.
- `priority_engine.ts:213-215` **hard-filters dismissed keys before scoring** — the item is erased from the response, not hidden. A principal who dismisses "8 approvals overdue" never sees it again even at 40 approvals.
- **Snooze does not exist** anywhere in the repo (zero hits across `.sql`, `.ts`, `.dart`).
- No lifecycle states, no escalation of items, no reappearance rules.

### 2.4 Liveness: there is no transport

- **No Supabase client in the app at all** — no realtime, no WebSocket, no SSE. All `dio` → Edge Functions.
- **No `pg_notify`/`LISTEN`** in any migration. **No `pg_cron`.**
- **No polling of business data** anywhere.
- **App resume invalidates no read provider** — a dashboard left open across a background/resume is stale indefinitely.
- The offline read-cache silently serves **≤24h-old payloads with no UI signal**. `AksharaFreshnessChip` exists but is on 2 screens, neither a dashboard.
- **XMOD‑016 (P1): "Nine periodic jobs, zero schedulers."** `domain_events/process-pending` — the drain that feeds the Signal Refinery — **never runs**. Assume nothing periodic fires unless its cron line ships with it.

### 2.5 Composition: every dashboard is hardcoded

All **19** dashboards are static `Column(children: [...])`. Zero are data-driven. The ordering substrate (`dynamic_widgets`) exists but renders raw Material cards and no role dashboard uses it.

### 2.6 Smaller, real

- `ageBoost` is **permanently 1.0** — no generator sets `waitingDays`. One of four factors is inert; the UI's "recency ×1.0" can never change.
- `approval` and `opportunity` item types are declared but **produced by zero generators**.
- `/management/tasks` is a **stale JSONB snapshot**, never refreshed — not a usable source.
- Teacher **tablet** layout omits the adaptive feed entirely.
- Five ad-hoc deep-link resolvers; only the principal's is pure/testable.
- `copilotPendingNavigationContextProvider` is set at 4 sites and **never cleared** → stale context for the session.
- Copilot **never reads** `ai_persona_memory`; `screenContext` is sent (16 keys) but **never persisted**.

---

## 3. Architecture

### 3.1 Principle: score everything, then decide visibility

The single most important change. Today:

```
generate → filter out dismissed → score → sort → return
```

Proposed:

```
generate → score → sort → apply LIFECYCLE OVERLAY → partition {visible, hidden, snoozed}
```

Scoring every item regardless of lifecycle state is what makes the rest possible:
reappearance becomes decidable (we know the item's *current* score vs the score when it
was acted on), and Copilot restore becomes a filter change rather than a re-fetch.

### 3.2 New: per-item lifecycle store

One new table. Model the shape on `operations_hub_item_actions`, the RLS on `legal_acceptances_self`
(**per-user policy — do NOT add `app_current_scope() = 'school'`**; that clause is for school-shared
resources and is exactly the bug `20260873000000` had to fix).

```
dashboard_item_state
  id                UUID PK
  organization_id   UUID NOT NULL REFERENCES organizations(id)
  school_id         UUID REFERENCES schools(id)          -- nullable: org/director scope
  user_id           UUID NOT NULL
  item_key          TEXT NOT NULL                        -- joins to RawPriorityItem.itemKey
  item_type         TEXT NOT NULL                        -- approval|deadline|exception|follow_up|opportunity
  state             TEXT NOT NULL CHECK (state IN
                      ('new','urgent','acknowledged','snoozed',
                       'completed','expired','escalated','resolved'))
  snoozed_until     TIMESTAMPTZ                          -- NULL unless state='snoozed'
  wake_rule         JSONB NOT NULL DEFAULT '{}'          -- declarative; see 3.3
  score_at_action   INT                                  -- severity watermark
  due_at_action     TIMESTAMPTZ                          -- deadline watermark
  acted_at          TIMESTAMPTZ NOT NULL
  actor_id          UUID NOT NULL
  created_at, updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
  UNIQUE (organization_id, school_id, user_id, item_key)
```

It **absorbs and replaces** `ai_persona_memory.preferences.dismissedKeys` (migrated, then that key
is retired). `recommendation_feedback` counters stay where they are — learning is unchanged.

### 3.3 Reappearance — a pure, testable function

Preserves the engine's clock-free invariant by taking `nowIso` as a parameter, exactly as
the existing loader does.

```ts
export function resolveVisibility(
  item: ScoredPriorityItem,
  state: ItemLifecycleState | null,
  nowIso: string,
): { visible: boolean; reason: VisibilityReason }
```

Resurfaces when **any** holds:

| Rule | Condition | Mission clause |
|---|---|---|
| Snooze elapsed | `snoozed_until <= now` | "widget automatically returns" |
| Severity increased | `item.score >= state.score_at_action + ESCALATION_DELTA` | "severity increases" |
| Deadline crossed a band | `urgencyBand(item.dueInDays) > urgencyBand(state.due_at_action)` | "deadline approaches" |
| Terminal states never resurface | `state ∈ {completed, resolved}` → hidden until the item stops generating | "task remains incomplete" |
| Day-scoped acknowledge | `acknowledged` + `acted_at::date < today` | precedent: `operations_hub_item_actions` |

**No scheduler is required for wake-up.** Because visibility is resolved at read time against
`nowIso`, a snooze expires the moment the user next opens the dashboard. A tick is only needed if we
want to *push* a newly-urgent item — deferred to Phase 5. This deliberately avoids XMOD‑016's
"nine periodic jobs, zero schedulers" trap.

### 3.4 Composition — volatile strip over stable body

This resolves the direct conflict between the mission ("continuously recalculated, highest first")
and doc 04's anti-disorientation constraint ("at most one organic reposition per day; user pins
always win"). **Both are right, about different things.**

```
┌ PINNED ─────────────────────┐  user pins — never move
├ PRIORITY STRIP ─────────────┤  volatile: top-N live items, re-sorted every fetch
│  (score-ordered, swipeable) │  this is where "living" happens
├ MODULE WIDGETS ─────────────┤  stable: existing hardcoded sections,
│  (existing DSV2 widgets)    │  order from dashboard_layouts, ≤1 organic move/day
└─────────────────────────────┘
```

The strip may churn freely — it is explicitly a queue. The body stays where muscle memory expects it.
Nothing in the current visual design changes; the strip already exists as `AdaptivePriorityFeedSection`.

Module widgets migrate from hardcoded `Column` to the **existing** `dynamic_widgets` model
(`DynamicWidgetItem{order, size, permissions, drillDown, visible}` + `filterWidgetsByRbac`), with its
renderer re-skinned to DSV2 components. That is far less surgery than a greenfield composer.

### 3.5 Liveness

Ranked by cost/benefit given no transport exists today:

| Option | Verdict |
|---|---|
| **Resume-refresh + foreground interval invalidate** | ✅ **Recommended.** Deterministic, works on iOS, no new dependency, no backend change. Closes the "stale across resume" hole immediately. |
| FCM data-message → provider invalidate | ⚠️ Phase 5. Real on Android, **absent on iOS** (`GoogleService-Info.plist` missing, `firebase_options.dart` throws), and `FCM_STUB_MODE` defaults to `true`. Cannot be the primary. |
| Supabase Realtime / SSE | ❌ Greenfield; adds a client dependency and a second transport for data that changes on minutes-to-hours timescales. |

Paired with an honesty fix: surface `AksharaFreshnessChip` on dashboards, driven by the
`X-NIKSHA-Offline-Cache` header the interceptor **already sets and nothing reads**.

### 3.6 Copilot hand-off

Three additions, all deterministic:

1. `loadCopilotContext` gains a slot reading `dashboard_item_state` + persona memory — so Copilot knows what the user dismissed.
2. Persist `screenContext` into `ai_copilot_messages.metadata` **at insert** (the table has `GRANT SELECT, INSERT` only — no UPDATE — so write-at-insert is the only option).
3. A rehydration read path that returns hidden/snoozed items, bypassing the visibility partition. Cheap, because §3.1 keeps scoring them.

Copilot keeps using the model gateway for genuine reasoning. **The dashboard never calls it.**

---

## 4. Roadmap

Each phase is independently shippable and EOS-gated. Migration band starts at **`20260920000400`**
(head is `20260920000310`; leaves `…320`–`…390` for the in-flight bus-tracking lane).

| # | Phase | Scope | Done-when |
|---|---|---|---|
| **0** | **Truth** *(blocking)* | Kill `.mock()` on the parent/teacher loading path; wire loading/error providers or adopt the student `ErpViewState` pattern; honest-empty the School Health Score; remove or wire the dead filter chips | WIDGET‑001/002/011 closed with tests; no dashboard renders demo data on any path |
| **1** | **Lifecycle core** | `dashboard_item_state` migration + repo; `resolveVisibility` pure fn + tests; engine switches from pre-filter to post-score overlay; migrate `dismissedKeys`; snooze/ack/complete API | Dismissed item reappears when score crosses the delta; snooze expires at read time; determinism + purity tests still green |
| **2** | **Living feed UI** | Swipe-to-dismiss (`Dismissible`), snooze sheet (30m / tomorrow / today), promote-next animation, lifecycle state chips; fix teacher tablet omission; consolidate 5 deep-link resolvers into one pure resolver | Swipe removes + promotes next; snoozed item returns; every item taps through to its module |
| **3** | **Liveness & honesty** | Resume-refresh, foreground interval invalidate, `AksharaFreshnessChip` on dashboards wired to the existing cache header | Dashboard refreshes on resume; stale data is visibly labelled stale |
| **4** | **Composition** | Re-skin `dynamic_widgets` renderer with DSV2; priority strip + stable body; user pinning on `dashboard_layouts` | A role dashboard renders from layout data; pins never move; ≤1 organic reposition/day |
| **5** | **Copilot hand-off** | Persona-memory/lifecycle context slot; persist `screenContext`; dismissed-item rehydration; clear `copilotPendingNavigationContextProvider` | Dismiss a widget → ask Copilot → full context restored |
| **6** | **Deadline & coverage debt** | `due_at`/`sla_due_at` on the approval spine; wire `approval` + `opportunity` generators; populate `waitingDays` to make `ageBoost` live | `urgency` computed from real deadlines; "N approvals ≥48h old" exists; all four factors variable |

### Sequencing notes

- **Phase 0 is not optional.** It is the mission's own first principle.
- Phases 1→2 are the smallest slice that delivers the felt "living" behaviour.
- Phase 6 is where the scoring actually gets *good*; until then `urgency` is mostly a constant. It is last only because it touches many modules' schemas.
- **Do not add a third "what matters now" surface.** `lib/core/dai/dai_brief.dart` is a complete, deliberately-unwired brief composer whose header says *"Do not 'just hook it up'"* — rendering it alongside the adaptive feed would triple-surface pending approvals. Consolidation, not addition.

### Invariants that must survive every phase

Inherited from the existing test suite — these are load-bearing:

1. **Purity** — engine and generators do no I/O, read no clock (`nowIso` is injected).
2. **Determinism** — same inputs → same feed; stable `itemKey` tie-break.
3. **Explainability** — `rawScore` must equal the rounded product of the four published factors.
4. **Persona isolation** — per-student items never reach `director`; ops items never reach teacher/parent/student.
5. **Honest empty** — never fabricate urgency when a date is absent; never a zero that reads as a measurement.
6. **AI never executes** — `requiresConfirmation: true` on every action.
7. **Zero model calls on the dashboard path.**

---

## 5. Open decisions (owner)

| # | Decision | Recommendation |
|---|---|---|
| D1 | Liveness transport | Resume-refresh + foreground poll now; FCM later. Realtime: no. |
| D2 | Reorder stability | Volatile strip + stable body (§3.4) — honours both the mission and doc 04 |
| D3 | Phase 0 first? | Yes — fabrication P0s before any Living Dashboard work |
| D4 | Branch | Separate branch/worktree; `feature/bus-tracking-module` is active |
