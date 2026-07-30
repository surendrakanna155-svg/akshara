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

### 2.1 ✅ CLOSED — the fabricated-data class

Certification `9587ce76` (2026-07-29 09:04) recorded WIDGET‑001/002/011 as open P0s and stated
"Nothing fixed". **That verdict was superseded the same day.** Commit `80a2cd8d`
*"fix(honest-state): one async contract replaces every fabricated-data fallback"* (2026-07-29 14:29,
ancestor of this branch) retired **twelve** register defects at once — CERT‑001/002/006,
JOURNEY‑001/007, WIDGET‑001/002/011, E2E‑005/011/012/021 — by fixing the *mechanism* rather than
twelve screens:

- Manual `*LoadingProvider` / `*ErrorProvider` flags are now only an **override on top of the real
  `AsyncValue`**, never the state itself. The skeleton path is live code again.
- `honestPayload<T>(state, neutralEmpty)` is the single sanctioned nullable→non-null bridge, and it
  takes a neutral `.empty()` shape. `MobileAsyncBody.fromState` treats a null payload as empty,
  never as data.
- `.mock()` factories survive **only behind the mock repositories** (`mock_parent_repository.dart`
  et al.) — unreachable when a real repository is resolved.
- WIDGET‑011: `_healthScore` is now `int?`. Both inputs must be present *and* parse as a real
  percentage, else the card renders "Not enough data yet". It also fixed a latent parser bug where
  a `collectionRate` of `₹12,45,000` parsed as `1245000` and pegged the ring at 100.

**Remaining from that cert (not blocking, carried into Phase 6):** WIDGET‑008 (P1) — 9 of 10 module
dashboards ship filter chips whose state the data fetch never reads.

> **Method note.** A certification verdict is a snapshot, not a standing fact. Re-verify against the
> working tree before acting on any register entry.

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
| **0** | **Truth** | ✅ **DONE before this lane opened** — closed by `80a2cd8d` (see §2.1). Verify only. | WIDGET‑001/002/011 closed; no dashboard renders demo data on any path |
| **1** | **Lifecycle core** | ✅ **DONE** (`88e67712`). `dashboard_item_state` migration + repo; `resolveVisibility` pure fn; engine inverted to score-then-overlay; `dismissedKeys` backfilled; snooze/ack/complete on the feedback route | Met. 28 backend tests; migration validated on real PG (re-runnable, RLS proven, constraints enforced) |
| **2** | **Living feed UI** | ✅ **DONE.** Swipe-to-dismiss, snooze sheet (30m / tomorrow / today), promote-next, "came back" badge, teacher-tablet feed fix | Met. 45 Flutter tests. **Deferred:** consolidating the 5 ad-hoc deep-link resolvers → Phase 4 (it is composition work, not lifecycle) |
| **3** | **Liveness** | ✅ **DONE** (`66b71747`). `LiveRefreshScope` + pure `LiveRefreshPolicy` on 5 dashboards (management, parent, teacher, student, director) | Refresh on resume + foreground tick, and provably NOT while offline/backgrounded. 15 tests |
| **3b** | **Freshness state** | ✅ **DONE.** Five honest states end-to-end: interceptor → `DataFreshnessRecorder` → pure `classifyFreshness` → chip on all 5 dashboards | Cached data can never render as live — proven end-to-end from a real interceptor cache replay. 19 tests |
| **4** | **Composition** | ✅ **Unified deep-link resolver** (5 drifted copies → 1 tested resolver) · ✅ **Pinning** (mig `…410`; pins outrank score, lifecycle AND terminal state; un-swipeable). ⚠️ **Scope call: the `dynamic_widgets` DSV2 conversion was NOT done — see below** | Pins float to top, survive a swipe, and are never auto-hidden. 25 routing + 7 pin backend + 3 pin widget tests |
| **5** | **Copilot hand-off** | Persona-memory/lifecycle context slot; persist `screenContext`; dismissed-item rehydration; clear `copilotPendingNavigationContextProvider` | Dismiss a widget → ask Copilot → full context restored |
| **6** | **Deadline & coverage debt** | `due_at`/`sla_due_at` on the approval spine; wire `approval` + `opportunity` generators; populate `waitingDays` to make `ageBoost` live | `urgency` computed from real deadlines; "N approvals ≥48h old" exists; all four factors variable |

### ✅ Phase 3b — freshness state (owner-prioritised, DONE)

Owner rule: *"The dashboard should never imply 'live' unless it can prove it.
Never present cached data as live."*

**Five states**, classified by a pure function of what the network layer actually
observed — not by connectivity, which answers a different question:

| State | Means | Tone |
|---|---|---|
| `live` | server fetch within 2 min | good |
| `recentlyRefreshed` | real server data, older | neutral |
| `cached` | replayed from the offline cache — **always shows its age** | warning |
| `offline` | nothing can refresh | warning |
| `refreshFailed` | connected, but the read failed | warning |

**The chain that was missing.** `OfflineReadCacheInterceptor` always knew whether
a body came off the wire or out of the cache — it set
`X-NIKSHA-Offline-Cache: <updatedAt>` and nothing ever read it. That knowledge
now leaves the network layer via `DataFreshnessRecorder`, which the interceptor
reports to on all three outcomes, and which surfaces read back through
`dataFreshnessProvider`.

**Load-bearing precedence rules** (each has a test):
1. A cache replay is `cached` **even while online, even one second old** —
   recency must never launder provenance. The body is old; when it was handed to
   us is irrelevant.
2. A cache observation carries the **cache entry's** timestamp, not the replay
   time — this is what stops a 23-hour-old payload reading as seconds old.
3. A failure while online is `refreshFailed`, not `offline` — blaming the network
   when the server is down misleads the user.
4. `live` outlasts the 90s poll interval, so the label does not flicker.

**Presentation:** the chip appears **only when the data is stale**. A permanent
"Live" badge is noise users learn to ignore — and would then miss the one time it
mattered — and rendering nothing in the healthy case means no dashboard layout or
golden changes for fresh data.

### Phase 4 scope call: the `dynamic_widgets` DSV2 conversion (owner decision)

Phase 4 as designed included re-skinning the siloed `lib/features/dynamic_widgets/`
renderer with DSV2 components and converting the 19 hardcoded dashboards to
render from layout data. **That part was deliberately not done**, and it is a
judgement call the owner should confirm rather than discover:

**Why not.** The mission's own constraints are *"Do not redesign the existing UI
unnecessarily"* and *"Preserve the current visual design"*. Converting 19 working,
tested, DSV2-styled dashboards to a data-driven renderer is a large, high-
regression-risk change whose entire user-visible benefit — priority-ordered
content — **is already delivered by the priority strip**, which is live on five
dashboards and now supports pins. The remaining gain is per-user reordering of
*static module widgets*, which doc 04 §5 deliberately caps at "≤1 organic
reposition per day" anyway. That is a lot of risk for an effect the design
already agreed to keep almost invisible.

**What was delivered instead** — the parts that change behaviour: pins that
outrank everything, and one resolver where there were five.

**If the owner wants the full conversion**, it is a clean standalone wave: the
model (`DynamicWidgetItem.order`, `filterWidgetsByRbac`, `RoleDashboardLayout`,
tenant overrides, versioning) already exists and is RBAC-correct; the work is
re-skinning `_DynamicWidgetTile` with DSV2 and migrating dashboards one at a
time behind their existing golden tests.

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

| # | Decision | Status |
|---|---|---|
| D1 | Liveness transport | ✅ Owner chose resume-refresh + foreground poll (Phase 3). FCM later; Realtime: no. |
| D2 | Reorder stability | Volatile strip + stable body (§3.4) — honours both the mission and doc 04 |
| D3 | Phase 0 first? | ✅ Moot — already closed by `80a2cd8d` (§2.1) |
| D4 | Branch | ✅ `feature/living-dashboard`. ⚠️ See §6 — a branch did not isolate the lanes. |

---

## 6. Lane contamination (open, owner-frozen)

A parallel bus-tracking session commits in the **same working directory**, so a
branch alone did not isolate the lanes — only a worktree would have. Two commits
mix both lanes:

- `7c1b209a` — bus-tracking work + this design doc. On **both** branches.
- `89dafc97` — bus-tracking work + 5 Living Dashboard files. On
  `feature/living-dashboard` **only**, so that lane's own P0 content is currently
  off its branch.

**Owner ruling (2026-07-30): freeze. No rebase, reset, force-push, or amend.**
Cleanup happens after both workstreams finish. Until then every commit in this
lane must be staged by explicit path and its staged diff verified to contain zero
`transport/` or `bus` paths. Nothing is lost; the history is just muddled.
