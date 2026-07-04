# Akshara ERP — UI/UX Master Consolidation

**Status:** 🟢 Design knowledge consolidation — the merged, de-duplicated record of everything the project already knows about its UI/UX.
**Date:** 2026-07-03 · **HEAD:** `68f15cb` · **Author:** Fable (World-Class Product Polish phase, Phase 1 of 5)
**Inputs consolidated:** all of `docs/design/*`, `docs/audits/00–11 + AUDIT_FINDINGS_LEDGER.md`, `docs/strategy/*`, `docs/FlutterDesignSystem.md`, `docs/MobileScreenInventory.md`, and a read-only survey of the implemented Flutter UI (`lib/theme/`, `lib/shared/`, `lib/features/`).
**Companions (produced in this phase):** `WORLD_CLASS_UX_POLISH.md` · `../strategy/ADAPTIVE_AI_USER_EXPERIENCE.md` · `PREMIUM_DESIGN_SYSTEM_GUIDE.md` · `PRODUCT_EXCELLENCE_MASTER_PLAN.md`

> **Governance:** This is a design artifact, not an execution plan and not a readiness checklist (the EOS
> is the only gate). It adds **no** items to the frozen `docs/PRODUCT_ENHANCEMENT_BACKLOG.md` (rev 5).
> Every consolidated finding maps to the single authoritative roadmap
> `docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md` (P2-UX-*, P3-AI-*, P1-*, P0-*) or is explicitly
> marked **OWNER** / **candidate**. Frozen owner decisions (O1–O10, identity freeze, attendance-auth,
> English-first, determinism-first AI, hide-first) are respected throughout.

---

## 1. The corpus, ruled — what is authoritative, what is superseded

Every existing UI/UX/design/audit document, with a single authority verdict so no future work re-reads the wrong file.

| Document | Role | Verdict |
|---|---|---|
| `docs/design/VISUAL_DESIGN_SYSTEM.md` ("Premium School OS") | Visual direction: indigo `#5B5BF0`, gradients, mesh, glass, monoline motifs, dark premium | **AUTHORITATIVE for look** (owner-approved 2026-06-20) |
| `docs/design/DesignSystem.md` + `FigmaDesignSystemBuildGuide.md` + `docs/FlutterDesignSystem.md` | Component anatomy, breakpoints, dialog/table/nav specs, a11y rules (M3 "Enterprise Blue" system) | **STRUCTURAL REFERENCE** — anatomy stands; its blue palette & 400-weight type direction is superseded by Premium |
| `docs/design/DESIGN_SYSTEM_V1.md` | Snapshot of the *implemented* token/component set; declares `lib/theme/` + `lib/shared/widgets/` code SSoT | **AS-BUILT BASELINE** (pre-M15.5) |
| `docs/design/M15.5_PREMIUM_TRANSFORMATION_REPORT.md` | What of Premium actually shipped (mesh, watermark, glass KPI, sparkline; ~72% visual parity) | **AS-BUILT DELTA** (most recent) |
| `docs/design/M15_THEME_MODERNIZATION_READINESS.md` | M15 go/no-go process record | HISTORICAL (executed) |
| `docs/design/EXAM_WORKSPACE_DESIGN.md` | Exam surface consolidation design; richest per-screen UX issue log | **AUTHORITATIVE for exam UX direction** (unimplemented) |
| `docs/design/Finance_Module_Specification.md` | Finance screen IA/layout/interaction spec (classic palette) | STRUCTURAL REFERENCE (IA valid; palette superseded) |
| `docs/design/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` | Assessment platform v1 design | **SUPERSEDED** by `docs/Vision/design/Assessment-Intelligence-Platform.md` v3.0 — do not plan from it |
| `docs/design/FUTURE_VISION_AI_SCHOOL_BUILDER.md` | Per-school generated experience vision | AUTHORITATIVE VISION — DO NOT BUILD NOW; prerequisites = consolidation/nav-simplification |
| `docs/design/FUTURE_VISION_MASTER_INDEX.md` / `FUTURE_VISION_PRESERVATION_AUDIT.md` | June-2026 capability trackers | HISTORICAL/STALE (reference deleted registries; superseded by frozen backlog) |
| `docs/MobileScreenInventory.md` | Mobile frame catalog + mobile UX rules | STRUCTURAL REFERENCE |
| `docs/audits/08_UX_DESIGN_RECONCILIATION_AUDIT.md` (+ archived 2026-07-02 UI/UX audit Tiers 1–4) | The UX findings of record: UX-1…UX-6, Tier 1–3 program ~90% open, rubric 5.5/10 | **AUTHORITATIVE for UX findings** |
| `docs/audits/00/06/07` + `AUDIT_FINDINGS_LEDGER.md` | Master verdicts, AI-1…6, MOD-1…6, disposition ledger | AUTHORITATIVE for findings/traceability |
| `docs/strategy/ADAPTIVE_AI_MASTER_BLUEPRINT.md` | Adaptive AI architecture (P3) | AUTHORITATIVE — the UX layer on top of it is `../strategy/ADAPTIVE_AI_USER_EXPERIENCE.md` |
| `docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md` | The ONLY execution plan (Phases 0–8) | AUTHORITATIVE for sequencing |

**Rule going forward:** for *look* read VISUAL_DESIGN_SYSTEM + `PREMIUM_DESIGN_SYSTEM_GUIDE.md`; for *component anatomy* read the DesignSystem family; for *what is actually built* read `lib/theme/` + `lib/shared/widgets/`; for *findings* read audit 08 + the ledger; for *when* read the final roadmap. Nothing else is load-bearing.

---

## 2. The one systemic discovery this consolidation adds

**Three different primary colors currently coexist** — and none of the documents knew about all three:

| Source | Primary |
|---|---|
| `docs/design/DesignSystem.md` §4 / `docs/FlutterDesignSystem.md` §3 (spec) | `#1565C0` |
| `lib/theme/color_tokens.dart` (shipped code, `blue800`) | `#1A56DB` |
| `docs/design/VISUAL_DESIGN_SYSTEM.md` (owner-approved direction) | `#5B5BF0` (+ gradient `#6366F1→#8B5CF6`) |

The same triple-drift pattern applies to status colors, radii, shadows, and heading weights (see
`PREMIUM_DESIGN_SYSTEM_GUIDE.md` §2 for the full reconciliation table). Additionally the code has a
**motion token system** (`lib/theme/motion.dart`: 80/120/180/240 ms + curves) and a **complete
obsidian dark palette** that no design document specifies. Documentation and implementation have
diverged in *both* directions. The Premium Design System Guide (Phase 4 companion) is the single
reconciliation; token edits are currently a 4-file documentation change plus code — that
duplication itself is a defect (see C-ISS-7).

---

## 3. Recurring issues — merged and de-duplicated

Each consolidated issue carries a stable ID (`C-ISS-n`), its merged sources, and its disposition in the authoritative roadmap. These IDs are used by all four companion documents.

| ID | Consolidated issue | Merged sources | Disposition |
|---|---|---|---|
| **C-ISS-1** | **The five daily tasks carry the most friction** (attendance, marks entry, grading, approvals, fee collection): no exception-grid attendance, no inline marks ergonomics, bulk-ops only partially generalized, no cross-module approvals inbox | UX-1 · prior-audit Tier 2 #8/#9/#10/#11 · master audit §6.4 | **P2-UX-2** |
| **C-ISS-2** | **Feedback layer absent**: 0 skeletons, 1 pull-to-refresh, no haptics, no success views — despite `Feedback/Skeleton` being fully specced in the Figma guide since v1 | UX-2 · prior Tier 1 #3 · FigmaGuide Steps 18–20 (spec existed, never built) | **P2-UX-1** |
| **C-ISS-3** | **Built-but-invisible infrastructure**: offline read-cache exists but no freshness chip; dark theme code-complete but locked to `ThemeMode.light`; `DraftAutosaveMixin` on only 2 of 4 pilot-critical screens; sparklines render decorative seed data | UX-3, UX-6, REL-3 · M15.5 gaps · code survey (`theme_mode_provider.dart` default light) | **P2-UX-1** (chip, drafts) · **P2-UX-5** (dark) · P1-CODE-1 (drafts backend) |
| **C-ISS-4** | **Raw machine copy reaches users**: 154 handlers leak raw `error.message`; ~30% raw error enums in UI; no error-writing standard, taxonomy, or microcopy guide anywhere in the corpus | ENG-7/SEC-6 · prior Tier 1 #5 · design-doc gap #5/#7 | **P1-CODE-3** (backend) + **P2-UX-1** (copy/error-dictionary) |
| **C-ISS-5** | **Surface sprawl & duplication**: two full marks-entry chains; 3 result viewers; 3 notions of "report card"; 3 principal-dashboard surfaces; multiple AI entry points; 14 overlapping surfaces catalogued; exam admin unreachable from any top-level menu | EXAM_WORKSPACE_DESIGN (all 6 findings) · MOD/07 overlap note · DOC-8 | 👤 **OWNER Consolidation wave (DOC-8 → P8-GA-5)**; exam-workspace slice proposed for earlier pull-in — see `WORLD_CLASS_UX_POLISH.md` §4 |
| **C-ISS-6** | **Reachable mock/thin surfaces erode trust**: ~8 backend-less surfaces, Alumni, Hostel billing/leave, HR payroll | ENG-3/MOD-4/MOD-5/MOD-6 · Preservation-audit "mock LLM / display-only" rows | **P0-CODE-2** (hide-first) · P1-CODE-5/6/7/8 |
| **C-ISS-7** | **Design-system dual authority + doc↔code token drift**: two contradictory documented systems, three shipped primaries (§2), tokens duplicated across 4 docs, no versioning/deprecation governance | design-doc digest §2 · code survey | **`PREMIUM_DESIGN_SYSTEM_GUIDE.md`** (reconciliation) + **P2-UX-3** (enforcement) |
| **C-ISS-8** | **Scaffold/app-bar fragmentation** *(new — from code survey)*: 12 near-duplicate per-feature `*_module_scaffold.dart` used by 137 screens; 117 screens use raw `AppBar(...)` vs 46 on shared `AksharaAppBar`; hand-rolled `Card`/`Container` styling in dashboards (worst: `dynamic_dashboard_screen.dart`) | code survey §3 | **P2-UX-3** (fold into DS enforcement: one `ModuleScaffold`, lint the rest) |
| **C-ISS-9** | **Async-state wrapper adoption is partial** *(new — from code survey)*: shared `ErpAsyncBody`/`MobileAsyncBody` exists but only ~22 files use it; 142 feature files hand-roll `AsyncValue.when()`, so loading/empty/error consistency depends on per-screen discipline | code survey §4 | **P2-UX-1** (skeleton rollout rides a sweep onto the shared wrapper) |
| **C-ISS-10** | **Persona dashboards are static while the Dynamic Widget Platform sits unused beside them**: all ~31 role dashboards are hand-composed widget trees; the audited widget-registry/dashboard-layout platform powers only `evolution/dynamic_dashboard_screen.dart` | code survey §5 · Blueprint §9 (requires composition on the Widget Platform) | **P3-AI-2** (dashboard composition) — no UI rebuild before it |
| **C-ISS-11** | **Desktop clerk persona underserved**: admin web = "responsive mobile screens on a big canvas"; no command palette, dense tables, or keyboard-first flows | audit 08 §4 | **P2-UX-2** (dense-table part) · candidate items in `PRODUCT_EXCELLENCE_MASTER_PLAN.md` |
| **C-ISS-12** | **Keyboard/input affordances**: ~4% of ~1,402 fields have correct keyboard hints; free-text date fields (e.g. `hr_workflow_actions.dart:80`) | UX-5 · prior Tier 1 #2 · XCT-3 | **P2-UX-2** + **P1-PROD-0** (date pickers) |
| **C-ISS-13** | **Accessibility depth unproven**: 311 `Semantics` usages and 48dp targets are real, but no declared WCAG level, no text-scaling clamp/layout guidance, contrast not in CI, screen-reader flows unverified | P2-UX-4 finding (EOS gap) · design-doc gap #6 · code survey §4 | **P2-UX-4** (after P2-UX-3) |
| **C-ISS-14** | **AI degradation & naming honesty**: no-key silent degradation has no user/operator signal; deterministic "Intelligence" surfaces overstate AI | AI-4 (residual), AI-6 | **P3-AI-1** (health signal) · **P3-AI-2** ("Intelligence"→"Analytics") |
| **C-ISS-15** | **Payment-flow trust pack missing**: fee counter works but lacks the confirmation/receipt/success ceremony money deserves (offline receipt-gating exists and is correct — it just isn't *celebrated*) | prior Tier 1 #1 · REL R1 pattern | **P2-UX-1** (success views) + **P2-UX-2** (fee flow ergonomics) |

**Explicitly resolved duplicates:** ENG-3 = MOD-4 · SEC-6 = ENG-7 · prior-Tier-1 #6 = UX-3 · prior-Tier-1 #3 = UX-2 · dark-mode "P2 placeholder" (3 docs) = UX-6 = M15.5 "obsidian gap" — all merged above.

---

## 4. Recurring strengths — the protect list (do not "improve" these away)

1. **Token-driven design system, live in production** — zero hard-coded hex colors across `lib/features/`; 425 files on `AksharaSpacing`; white-label-ready (master audit "what NOT to change" #5).
2. **Determinism-first AI over a real data spine** — advisory-only, never on write paths, deterministic parent-comms catalog. This is the moat's safety half; every polish idea must preserve it.
3. **Offline honesty** — receipt minted only on server confirm ("pending sync"), encrypted outbox, global `SyncBanner`, Sync Center, draft autosave + crash-resume on attendance. Rare, genuinely differentiating; the UX job is to make it *visible*, not to change it.
4. **Honest empty states and no dead buttons** on shipped surfaces (audit 07 §4) — plus a full Empty/Error/Loading component trio already institutionalized.
5. **Governance visibility** — maker-checker on money/stock, approval queues, audit drawers. Enterprise trust competitors lack.
6. **Structural consistency constants** — 48px touch targets, 8pt grid, shared shells, `PersonaBottomNav` ≤4 tabs + More, responsive card-fallback for tables.
7. **Regression safety net around visual change** — goldens, Patrol suites, `dashboard_stress_test.dart`; M15/M15.5 proved reskins can ship without logic changes.
8. **Consolidate-don't-add ethos** — USER→ROLE→WORKSPACE→TASK; Exam Workspace "reuse 1, add 0"; hide-first North Star.

---

## 5. Recurring opportunities — merged

| ID | Opportunity | Sources | Where it lands |
|---|---|---|---|
| C-OPP-1 | Convert built infrastructure into **visible trust** (freshness chip, dark toggle, draft chips, sync ceremony) — cheapest perceived-quality wins in the corpus | UX-3/6, audit 08 §3 | P2-UX-1/5 · `WORLD_CLASS_UX_POLISH.md` §3 |
| C-OPP-2 | **Generalize the bulk-ops pattern** already shipped (PRI-1 batch approve, HR leave batch) to every list | Tier 2 #10 "Advanced; generalize" | P2-UX-2 |
| C-OPP-3 | **Cross-module Approvals Inbox** — one queue for principal/management decisions | Tier 2 #11 · PAR-D4 (parent variant, OWNER) | P2-UX-2 · Adaptive-AI priority feed later composes onto it (Blueprint §6) |
| C-OPP-4 | **Per-school adaptive experience** on existing rails (Widget Platform + capability gating + School Profile) — "built for my school" without forking | AI School Builder vision · Blueprint §9 · C-ISS-10 | P3-AI-2 · `ADAPTIVE_AI_USER_EXPERIENCE.md` |
| C-OPP-5 | **Monoline illustration & premium atmosphere rollout** across all module empty states (M15.5 built the kit; coverage is partial) | M15.5 gaps · VISUAL_DESIGN_SYSTEM §7 | P2-UX-1 (rides skeleton/empty sweep) |
| C-OPP-6 | **AI-in-the-chrome** — center-docked AI action, suggestion bar, insight cards already have components and 4 access modes; unify entry points instead of multiplying them | DESIGN_SYSTEM_V1 AI components · C-ISS-5 | P3-AI-2 + Consolidation (DOC-8) |
| C-OPP-7 | **UPI-native money loop** (intents/QR/auto-reconcile) — named high-value near-term by the competitive strategy | prior Tier 4 #21 · strategy §4 | 👤 OWNER to mint (post-pilot Tier 4 pattern) |
| C-OPP-8 | **Morning Brief / digests / Student-360 / actionable notifications** — Tier 4 candidates that become the Adaptive-AI presentation layer rather than standalone features | prior Tier 4 · Blueprint §5/§10 | P3-AI-2 (do NOT build twice) |

---

## 6. Missing UX knowledge — topics no document covers

These are *specification* gaps (not necessarily build gaps). The Phase 4 guide fills #1–#6; the rest are catalogued for the master plan.

1. **Motion & animation system** — code has tokens (`motion.dart`); no doc specifies choreography, page transitions, or micro-interactions. *(filled: Premium Guide §6)*
2. **Dark mode component spec** — palette exists, mapping/contrast validation doesn't. *(Premium Guide §4)*
3. **Offline/sync-state UX spec** — one line in the whole corpus for the project's biggest differentiator. *(Premium Guide §8 + Polish §3)*
4. **Error content & microcopy standard** — taxonomy, tone, destructive-action copy, formatting of ₹/dates/IDs (PSID display rules exist only in the identity freeze). *(Premium Guide §9)*
5. **Perceived-speed rules** — when skeleton vs spinner vs optimistic update; loading budgets. *(Premium Guide §6)*
6. **Notification anatomy** — grouping, badge semantics, in-app center vs push, snackbar queuing. *(Premium Guide §10)*
7. **Data-viz standards beyond a palette** — axis/tooltip/legend behavior, number formatting, chart empty/loading states, color-blind validation.
8. **Forms depth** — validation timing, input masking (phone/₹), autocomplete, steppers beyond one wizard line.
9. **Permissions-denied UX** — hidden-vs-disabled doctrine beyond one tooltip rule (matters more once capability-gating hides modules per school).
10. **Print/PDF design standard** — receipts, report cards, certificates are core outputs with no template system.
11. **First-run / empty-tenant experience** — ironic given the AI School Builder vision; today a fresh school sees generic emptiness.
12. **Web enterprise affordances** — hover catalog, keyboard shortcuts, deep-link/multi-tab rules, global search behavior (`SearchTrigger 360w` is the only mention).
13. **Density modes** — "calm and airy" premium direction vs data-heavy clerk reality; no reconciling rule.
14. **White-label × premium-gradient × dark-mode interplay** — three theming systems with no collision rule.
15. ~~RTL~~ — **descoped** by English-first (FINAL 2026-06-30); parent-comms catalog is text-only. Recorded so nobody re-opens it.

---

## 7. Missing enterprise experiences — what "best in class" has that Akshara lacks

Benchmarked against Linear/Stripe/Notion/Atlassian-grade products; each mapped to where it already lives, or flagged as a **candidate** (minted only via the master plan → owner, never silently):

| Experience | Status in corpus | Lands in |
|---|---|---|
| Cross-module Approvals Inbox | Known (Tier 2 #11) | P2-UX-2 |
| Command palette / universal search (⌘K) | Absent (C-ISS-11) | Candidate — master plan §High-Impact |
| Saved views / filters / pinned reports | Absent | Candidate |
| Export center (real exports + history) | Backend = XCT-1 (P1-PROD-0); no UX spec | Polish §5 (UX for XCT-1 — no new backend) |
| Notification center with action buttons | Tier 4 "actionable notifications" | P3-AI-2 presentation layer |
| Audit trail as a user-facing feature ("who changed this?") | Backend real; UX = one drawer spec | Candidate (high trust value, low cost) |
| Keyboard-first data entry (marks/attendance grids) | Part of Tier 2 #8/#9 | P2-UX-2 |
| Session/device management for users | SEC-4 adjacent; no UX | Candidate (Phase-2 leaning) |
| Status/health transparency ("all systems normal") | Watchdog exists (ops-only) | Candidate |
| In-product onboarding checklists per school | School-completion hub exists (20 screens!) — never framed as guided onboarding | Candidate — reframe, don't rebuild |

---

## 8. Traceability spine

Every consolidated item traces: **Audit finding → this doc's C-ID → Roadmap task → Implementation → Verification → EOS gate.** Example rows (full mapping lives in `PRODUCT_EXCELLENCE_MASTER_PLAN.md` §6, the implementation-ready plan):

- UX-2 + Tier-1 → **C-ISS-2** → `P2-UX-1` → skeleton/haptic/success components in `lib/shared/widgets/` → golden + Patrol + rubric re-run → UX PASS.
- Code-survey scaffold fragmentation → **C-ISS-8** → `P2-UX-3` (DS lint + one scaffold) → migration sweep → lint blocks regressions → UX+CI PASS.
- Blueprint §9 + C-ISS-10 → `P3-AI-2` → persona dashboards composed on Widget Platform → per-school layout divergence measured → AI PASS.

**Verification rule inherited from the audits:** no claim above its evidence grade (LIVE / LOCAL-LOGIC / CONTRACT / RENDER-MOCK / STAGED); the Phase-2 exit remains "re-run the prior UX rubric → ≥8/10"; Gate U (U1–U5) of the Production Certification Framework is the final UX proof — this document introduces **no competing gate**.

---

*End of consolidation. Next: `WORLD_CLASS_UX_POLISH.md` (Phase 2) applies world-class benchmarks to every screen family on top of these C-IDs.*
