# Akshara ERP — Product Excellence Master Plan

**Status:** 🟢 **THE SINGLE SOURCE OF TRUTH for all future UI/UX work before implementation begins.**
**Date:** 2026-07-03 · **HEAD:** `68f15cb` · **Author:** Fable (World-Class Product Polish phase, Phase 5 of 5)
**Combines:** `UI_UX_MASTER_CONSOLIDATION.md` (findings) · `WORLD_CLASS_UX_POLISH.md` (screen/workflow specs) · `../strategy/ADAPTIVE_AI_USER_EXPERIENCE.md` (AI experience) · `PREMIUM_DESIGN_SYSTEM_GUIDE.md` (system spec).
**Executes through:** `docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md` **only**. This plan fills the P2-UX-* / P3-AI-2 tasks with their exact content and nominates a small set of **👤 candidates** for owner minting. It adds nothing to the frozen `PRODUCT_ENHANCEMENT_BACKLOG.md` (rev 5) and creates no competing gate — every wave remains `/eos`-gated.

> **Doctrine:** evolution, not re-architecture. Every item below preserves business logic, providers,
> routing, RBAC/RLS and workflows; reuses existing components; and is view-layer unless explicitly
> tagged **[BACKEND]**. Every item improves at least one of: usability · efficiency · trust · delight ·
> enterprise readiness — anything that didn't was cut.

---

## 1. Priority bands

### BAND A — Quick Wins (days each; view-layer; disproportionate perceived quality)

| # | Item | Why it wins | Maps to | Spec |
|---|---|---|---|---|
| A1 | **Dark Premium toggle** (code-complete; validate contrast, ship) | "Low effort, real delight" (UX-6); premium signal | P2-UX-5 | Guide §4 |
| A2 | **Offline freshness chip** on money/attendance surfaces | Converts built reliability infra into *visible* trust (UX-3) | P2-UX-1 | Polish §3.5 |
| A3 | **Tabular numerals** on every KPI/table/receipt | Cheapest "feels professional" fix in a money product | P2-UX-1 | Guide §5 |
| A4 | **Pull-to-refresh everywhere** (1 screen has it today) | Table-stakes mobile grammar | P2-UX-1 | Polish §3.2 |
| A5 | **Exam admin gets a top-level nav entry** | Un-buries a flagship module (EXAM_WORKSPACE 🔴 discoverability) | P2-UX-2 slice | Polish §4 |
| A6 | **Kill decorative sparklines** (render real series or nothing) | Honesty > ornament; protects the "no fake data" brand | P2-UX-1 | M15.5 gap |
| A7 | **Success ceremony component** (`AksharaSuccessView`) on fee collect + attendance submit | The two highest-frequency moments get Stripe-grade closure | P2-UX-1 | Polish §3.4 |
| A8 | **Keyboard-type sweep, tranche 1** (money + phone + marks fields) | ~4% of 1,402 fields correct today; mechanical | P2-UX-2 / XCT-3 | Polish §5 |
| A9 | **Empty-state illustration rollout** to modules M15.5 missed | Kit already built; brand signature for free | P2-UX-1 | Polish §6 |
| A10 | **Doc banners:** demote System-A palettes, fix breakpoint/margin drift | Ends the two-design-systems confusion for every future contributor | P0-DOC housekeeping | Guide §1/§12 |

### BAND B — High Impact (the adoption-winning program; weeks)

| # | Item | Maps to | Spec |
|---|---|---|---|
| B1 | **Feel & trust pack** — skeletons via `ErpAsyncBody` migration (142 screens), haptic vocabulary, draft chips + PopScope, copy/error dictionary | **P2-UX-1** | Polish §3, Guide §9 |
| B2 | **The five daily tasks** — exception-grid attendance · spreadsheet-grade marks grid (shared by both entry chains) · fee counter ceremony · grading review mode · ergonomic targets as Gate U2 | **P2-UX-2** (dep: P1-CODE-1) | Polish §2 |
| B3 | **Cross-module Approvals Inbox** — one queue, swipe decisions, batch, maker-checker badging **[BACKEND: thin read-model candidate]** | **P2-UX-2** + 👤 candidate P1 task | Polish §2.3 |
| B4 | **Design-system enforcement** — lint set, contrast-in-CI, goldens; fold 12 ModuleScaffolds into one; KPI-card consolidation | **P2-UX-3** | Guide §8/§12 |
| B5 | **Premium-completion visual wave** — `#5B5BF0` palette, Inter, tinted shadows, canvas rules, white-label gradient derivation | 👤 owner-timed M15-pattern wave | Guide §2/§13 |
| B6 | **Accessibility AA pass** — five daily flows + parent app; dynamic type; semantics verification | **P2-UX-4** | Polish §7 |
| B7 | **Adaptive AI foundation** (cache/rate-limit/spend-cap/timeout/health signal) — not UX itself, but every AI experience depends on it | **P3-AI-1** [BACKEND, scheduled] | Blueprint §12 |

### BAND C — Medium Impact (sequenced after A/B; real value, not adoption-critical)

| # | Item | Maps to | Spec |
|---|---|---|---|
| C1 | **⌘K command palette** (web admin): navigate + PSID entity search + actions | 👤 candidate | Polish §4 |
| C2 | **Table density toggle** (row 52→40) for the clerk persona | P2-UX-2 rider | Polish §7 |
| C3 | **"Who changed this?" audit affordance** — long-press any governed value → existing audit drawer | 👤 candidate (backend real; UI compose) | Consolidation §7 |
| C4 | **Export center UX** for XCT-1 (queue, history, re-download) — replaces the dead-stub snackbar | P1-PROD-0 rider | Consolidation §7 |
| C5 | **Saved views / pinned filters** on heavy admin tables | 👤 candidate | Polish §1 (Linear lesson) |
| C6 | **First-run experience** — reframe the existing school-completion hub (20 screens) as a guided onboarding checklist with progress | 👤 candidate (reframe, no new screens) | Consolidation §7 |
| C7 | **Data-viz standards** (axis/tooltip/formatting/colorblind check) | P2-UX-3 rider | Guide §3 |
| C8 | **Notification anatomy unification** (one interruption grammar: notification = priority card) | lands with P3-AI-2 | Guide §10, AI-UX §2 |

### BAND D — Future Ideas (owner-timed; post-pilot or post-GA)

| # | Item | Gate |
|---|---|---|
| D1 | **Adaptive AI experience rollout** — briefs, priority feeds, adaptive dashboards per persona | P3-AI-2 (👤 timing; after P3-AI-1) — full design: `ADAPTIVE_AI_USER_EXPERIENCE.md` |
| D2 | **Student & HR AI extensions** (strict constraints; HR only after payroll is real) | 👤 Blueprint extension candidates (AI-UX §3.4/§3.10) |
| D3 | **UPI-native money loop** (intents/QR/auto-reconcile) | 👤 Tier-4 minting (strategy already endorses) |
| D4 | **Consolidation wave** — 14 overlapping surfaces, 3 principal dashboards, AI entry points | 👤 DOC-8 (P8-GA-5); exam slice pulled earlier via A5/B2 |
| D5 | **Per-school generated theming/workspaces** (AI School Builder vision on Widget-Platform + capability-gating rails) | Post-P3-AI-2; prerequisites unchanged |
| D6 | **Session/device management UX · status transparency page** | Phase-2 commercial leaning |
| D7 | Morning-brief digests via external channels (push/SMS/WhatsApp) | Owner-gated rail (XCT-2), unchanged |

---

## 2. Ideas never discussed before (introduced by this phase)

1. **One interruption grammar** — notifications, priority cards, and reminder banners share a single anatomy (fact → context → one action → why/dismiss), so the product interrupts in exactly one shape (C8/D1).
2. **Deterministic white-label gradient derivation** — school brand color → gradient + dark variant by formula with AA fallback; solves white-label × premium × dark with zero per-school design work (Guide §2).
3. **Density as a table property, not an app mode** — resolves "calm premium" vs "clerk density" without two design languages (C2).
4. **Adaptation etiquette** — rise/sink between sessions only; pins beat algorithms; "why is this here?" on every adaptive placement; cold-start = certified static defaults (AI-UX §4). This is the difference between "personal" and "creepy," and no competitor articulates it.
5. **The degradation ladder as UX contract** — users never see an AI error state; operators always see the health signal (AI-UX §2).
6. **Offline honesty as ceremony** — the amber "queued receipt" treated as a proud feature with its own visual state, not an apology (Polish §2.4).
7. **Evidence-first cards** — every AI-surfaced claim strips down to a deterministic fact line that stands alone (AI-UX §1.3) — an anti-hallucination *interface* pattern, not just a backend rule.
8. **Perceived-speed budget table** — codified skeleton/spinner/optimistic rules per wait class (Guide §6).

## 3. Innovations competitors lack → the moat

Indian school-ERP incumbents ship feature-ware with dated UX; global SIS is heavy and desktop-first (competitive strategy §1). The compounding differentiators this plan finishes:
- **Trust you can see:** receipt-gating, maker-checker badges, freshness chips, audit affordances — governance as UI (nobody in the segment shows this).
- **Five-task ergonomics at consumer-app quality** — adoption is won at the attendance grid, not the feature list.
- **Determinism-first adaptive AI at near-zero marginal cost** — briefs and priority feeds competitors literally cannot afford to copy at scale (Blueprint §7 economics).
- **Per-school adaptation without forking** — "built for my school" via config + memory + widgets, on rails that already exist.
Together: *easiest + most trustworthy + most adaptive* — the strategy's three durable things, delivered as interface.

## 4. What we deliberately do NOT recommend

No app localization (English-first, FINAL) · no chatbot-first AI, no LLM comms translation · no new verticals/peripheral breadth (hide-first O1/O3) · no re-architecture of navigation, routing, or state management · no parallel dashboard system (compose on the Widget Platform) · no feature-parity chase · no student-facing model calls without owner decision · no readiness checklist other than EOS.

---

## 5. Execution sequence (implementation-ready)

```
NOW (docs only — this phase)          : five documents saved; owner reviews candidate set (§6)
P0 (unchanged)                        : truth/safety/live-proof — no UX work before P0-CODE-2 hides mock surfaces
P1 tail ∥ P2 start                    : A-band quick wins (A1–A10) — most have no P1 dependency
P2 wave 1 = P2-UX-1 (B1, A2/A4/A6/A7/A9)
P2 wave 2 = P2-UX-2 (B2, B3-UI, A5/A8, C2)     ← hard dep: P1-CODE-1 (marks via ReliableWriter)
P2 wave 3 = P2-UX-3 (B4, C7) → P2-UX-4 (B6) → P2-UX-5 (A1 if not earlier)
Premium-completion wave (B5)          : 👤 timing; natural slot beside P2-UX-3
Phase-2 exit gate                     : prior UX rubric re-run ≥ 8/10 (unchanged)
P3-AI-1 (B7) → P3-AI-2 (D1)           : 👤 timing; AI-UX doc is the experience spec
P4–P8                                 : unchanged (Red Team → fixes → Pilot → Cert → GA); Gate U/A wording already matches this plan's targets
```
Constraints honored: agent file-ownership rule (per-wave disjoint modules) · every wave EOS-gated · no claim above evidence grade.

## 6. Owner decision batch (surfaced once, per the decision-queue rule)

1. Premium-completion wave timing (B5) — direction already approved 2026-06-20; this is *when*, not *whether*.
2. Approvals-Inbox thin read-model **[BACKEND]** (B3) — or UI-only per-module fallback.
3. Exam-workspace early slice (A5 + shared marks grid in B2) — pulls one piece of DOC-8 forward.
4. Candidate minting: C1 command palette · C3 audit affordance · C5 saved views · C6 first-run reframe.
5. PAR-D4 parent action-inbox — approving it as the parent priority feed avoids building it twice (AI-UX §3.2).
6. D2 Student/HR AI extensions — decision needed only at P3-AI-2 time.

## 7. Traceability matrix (Audit Finding → Roadmap → Implementation → Verification → EOS)

| Finding(s) | Consolidated | Roadmap task | Implementation artifact (spec §) | Verification | EOS gate |
|---|---|---|---|---|---|
| UX-2, Tier-1 #3 | C-ISS-2 | P2-UX-1 | Polish §3 skeletons/haptics/success | goldens + Patrol + rubric | UX PASS |
| UX-3, REL-3, UX-6 | C-ISS-3 | P2-UX-1/5 | Polish §3.5–3.6, Guide §4 | freshness chip visible on money surfaces; dark AA report | UX PASS |
| UX-1, UX-5, Tier-2 | C-ISS-1, C-ISS-12 | P2-UX-2 | Polish §2 five-task specs + §5 sweep | Gate U2 ergonomic targets measured | UX PASS |
| ENG-7/SEC-6, Tier-1 #5 | C-ISS-4 | P1-CODE-3 + P2-UX-1 | Guide §9 taxonomy + dictionary | zero raw enums in five flows (Gate U4) | SEC+UX PASS |
| UX-4, Tier-3; code-survey scaffold/async drift | C-ISS-7/8/9 | P2-UX-3 | Guide §8 mandates + §12 lints | lint blocks violations in CI | UX+CI PASS |
| EOS a11y gap | C-ISS-13 | P2-UX-4 | Polish §7 (WCAG 2.1 AA declared) | contrast CI + screen-reader pass | UX PASS |
| AI-1/2/3/4/5 | C-ISS-14 | P3-AI-1 | Blueprint §12 items 1–6 | ≥90% zero-call impressions; cap enforced | AI PASS |
| Adaptive vision, AI-6, C-ISS-10 | C-OPP-4 | P3-AI-2 | AI-UX §2–§4 + Blueprint §5/§9 | per-school divergence measured; rename shipped | AI PASS |
| EXAM_WORKSPACE 🔴/🟠, DOC-8 | C-ISS-5 | A5/B2 slice + 👤 D4 | Polish §2.2/§4 | one marks-entry component serves both chains | FEATURE+UX PASS |
| MOD-4/5/6, ENG-3 | C-ISS-6 | P0-CODE-2 (scheduled) | hide-first | no mock surface reachable | FEATURE PASS |
| Tier-1 #1, R1 pattern | C-ISS-15 | P2-UX-1/2 | Polish §2.4 trust pack | Gate U1 feedback layer LIVE | UX PASS |

Bidirectional completeness: every C-ISS/C-OPP from the consolidation has a row here or an explicit 👤/candidate disposition in §1; no finding was dropped.

---

*This plan is ready for autonomous execution under `AUTONOMOUS_EXECUTION_PLAN.md`: each band item names its roadmap task, spec section, dependencies, and EOS gate. Implementation begins only per the roadmap's phase order and owner approvals — nothing here authorizes starting early.*
