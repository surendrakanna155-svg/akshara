# Akshara ERP — Dual-Track Master Execution Plan (Production + Differentiation)
**Date:** 2026-06-24 · **Author:** Claude (Opus 4.8) · **Status:** Authoritative going-forward plan
**Basis:** Live audit of actual code (supabase/functions + lib), not the stale `docs/` status reports.

> This supersedes the "defer all differentiation to 6–18 months" stance in `MASTER_ROADMAP_RECONCILIATION_2026-06-24.md`. That review was right about reality but **too conservative about the moat**. The core finding here:
> **Most of Akshara's differentiation is already built. What remains for the moat is mostly the SAME last-mile work as launch — provision a key, flip a flag, persist a config, 1–2 day wiring jobs — not months of net-new engineering.** Production-readiness and differentiation are therefore *not* a trade-off. We run both.

---

## THE ONE-PARAGRAPH THESIS
The differentiation features are far more real than the docs claim. Per-school module gating (the heart of "feels built for my school") is ~85% done and is *also* the launch item "hide unused modules." Question Intelligence is deployed. Copilot + Parent Insights are real Claude code that only need an API key. Director multi-school aggregation is real and just flag-gated off. So the genuine choice is not "launch vs moat" — it's "recognize the cheap last-mile moat items (do them now, alongside launch) vs the real moonshots (Universal Org Builder, AI-generates-the-UI, Dynamic Widget engine, verticals — correctly deferred)."

---

## PART 1 — REALITY CHECK on the P4/P5/P6/P7 recommendation

**1. Sufficient for launch?** Necessary but not complete. The four-batch plan names the right buckets (write completeness, hardening, packaging, lint) but misstates the state and omits two true blockers. Code-verified:
- **Dead buttons: effectively 0.** `onAction: null` = 0 matches in `lib/`. The "14 cards" in `ROAD_TO_PRODUCTION_V1.md` are stale. ✅
- **Release defaults to MOCK.** `lib/core/config/environment.dart:59-67` — even `production` has `enableApiMode: false`; every module flag in `repository_config.dart` defaults `false`. There is no in-tree release flavor baking `ENABLE_API_MODE=true` + module flags + live VPS URL. A release build today shows mock data. **This is the #1 launch blocker and it's not in P4–P7 as written.**
- **Push notifications don't exist** (no `firebase_messaging`, no token registration; backend `sendPush` is a stub on the deprecated legacy FCM API). The paid value is missing.
- **Play packaging is the untouched scaffold:** debug-signed (`android/app/build.gradle.kts:34-40`), no `key.properties`, no R8/minify, stock placeholder icon, no privacy policy → Play rejects the .aab.
- **Live-mode E2E never run.** ~109 Patrol journeys are mock-mode only. Nothing proves the live backend under full journeys.
- **AI key not provisioned** → every AI surface returns safe stub.
- **Lint:** 103 issues, 0 errors, but **76 are in `lib/`** (P7's "all in test/" is wrong).

**2. Sufficient for differentiation?** **No** — and this is the user's correct instinct. P4–P7 is pure launch hygiene; it builds zero moat. Following it alone ships a *working* ERP that looks like everyone else's.

**3. Risk of "just another ERP"?** **Yes, if we ship P4–P7 and stop.** But the inverse risk is overcorrecting. The escape is precise: the cheap moat items below cost days, not months, and several are launch items in disguise. Do those. Don't chase the moonshots yet.

---

## PART 2 — DIFFERENTIATION AUDIT (code-verified % — ignore doc %s)

| # | Feature | Real impl % | Evidence | Missing | Effort left | Pilot value | Moat |
|---|---|---|---|---|---|---|---|
| 1 | **AI School Builder** (interview→provision) | Deterministic provisioning **90–100%**; AI-gen layer **0–5%** | `_shared/setup_wizard/*` + `_shared/onboarding/startup_onboarding_provision_service.ts` write real year/classes/sections/fees | The "AI generates UI/nav/dashboards" layer; module *gating* from interview | Provisioning: done. Gating slice: **~3–5 d**. AI-gen: months | Med (gating slice High) | **High** |
| 2 | **Per-school capability gating** (the real "feels custom" engine) | **~85%** | `lib/core/school_config/` registry gates admin nav (`admin_navigation_provider.dart:195`), KPIs, parent dashboard, copilot | Backend table+route (persists in-memory/SharedPrefs only); capability route-guard | **~1–3 d** | **High** | **High** |
| 3 | **Dynamic Widget Platform** | client ~80%, effective **~60%** | Real data-driven renderer `dynamic_widgets/dynamic_widget_runtime_screen.dart`; BUT client paths `/widgets/layouts/$role` ≠ server `/widgets/dashboard/layout` (404), no layout tables, prod dashboards static | Route contract fix + per-tenant layout persistence + wire real dashboards | **1–2 wk** | Low | Med |
| 4 | **Advanced AI Predictions** (at-risk) | engine **real ~60%**, NOT ML | `intelligence/student_risk_engine.ts` weighted formula over real attendance/homework/marks → `intel_student_risk_snapshots`; live endpoints exist | Teacher screen still reads a **mock** registry; some signals hardcoded (`communication_gaps=0`) | **1–2 d** to wire UI to live | Med | Med |
| 5 | **Multi-School Intelligence** | Director **~90%**; Platform-Intel **~10%** | Director: real org-scoped multi-school SQL (`director_repository.ts`, RBAC `'organization'` scope), gated off by `DIRECTOR_API_ENABLED`. Platform-Intel: **100% mock, no server routes exist** | Director: flip flag + metric-input UI + file export. Platform-Intel: whole backend | Director **~2–4 d**; Platform-Intel **1–2 wk** | Med | High |
| 6 | **AI Copilot** (principal/teacher) | **~85%** | `_shared/copilot/*` real Claude + safe stub, RBAC-gated, audited, context from real DB | Streaming/markdown; live screen-context wiring | **Key + hours** | Med-High | High |
| 7 | **Parent Insights** | **~88%** | `parent_insights_service.ts` deterministic numbers + `parent_insights_ai.ts` Claude rewrites **prose only** ("never change a number") | Just the key (works as deterministic without it) | **Key + hours** | **High** | High |
| 8 | **Question Intelligence** | solver ~70%, bank CRUD ~90% (**empty**), AI gap-fill ~85%, curriculum ~75%, **syllabus enforcement ~20%** | `_shared/education/*` bank-first→solver→constrained AI candidates→teacher/principal RBAC→**hard publish gate** (`education_repository.ts:567`) | Bank has **zero questions**; syllabus is free-text not a hard boundary | Syllabus boundary **~1–2 d**; bank = content; deploy+key | Med (rising) | **Very High** |
| 9 | **Resource Optimization** | **~30%** (client stub) | No backend route exists; client `aiInferencePipeline` mock | Entire backend | 1–2 wk | Low | Low |

### Ranked
- **By ROI (value ÷ effort):** Parent Insights → Copilot (both = the API key) → **Per-school capability gating** → At-risk UI wiring → Director flag-on → Question-Intelligence syllabus boundary.
- **By differentiation:** Question Intelligence → Per-school gating / AI School Builder → Multi-school (Director) → Copilot/Parent Insights → Dynamic Widgets.
- **By revenue potential:** Per-school gating + Notifications (retention/"feels built for us") → Question Intelligence (category moat, upsell) → Multi-school/Director (chain-operator deals) → AI Copilot (premium tier).

---

## PART 3 — WHAT MAKES AKSHARA UNIQUE (vs MyClassboard/Entab/Fedena/Teachmint/Classplus/CampusCare)

**Already built (defensible today):**
1. **Governed, trust-first AI** — deterministic numbers + AI only rewrites prose/fills gaps; mathematically-enforced publish gate (`education_repository.ts:567`). Competitors bolt on raw ChatGPT; this is the opposite and schools will feel the difference.
2. **Bank-first Question Intelligence** — blueprint solver guarantees exact marks distribution, AI confined to gaps, teacher/principal approval split. Owning syllabus+bank+exam+marks is a category competitors do poorly.
3. **Real multi-school org-scope aggregation** (Director) — genuine cross-school SQL with org-scoped RBAC, not a single-school dashboard relabeled.
4. **Parent insights in the parent's own language** with numbers that never lie.
5. **Per-school capability adaptation** — the app reshapes nav/KPIs/dashboards to what the school actually is.

**Partially built (close):**
6. **AI-configured onboarding** — real provisioning saga (year/classes/sections/fees/students) from a structured interview; the "AI feel" slice is days away.
7. **At-risk early-warning** from real attendance/homework/marks signals.
8. **Encrypted, restore-tested backups + watchdog** as a *productized* trust feature (Batch 7).

**Still only plans:**
9. **AI-generated per-school UI** (interview → bespoke workspaces) — the long-game moat.
10. **Universal Org Builder + verticals** (one kernel → school/salon/hospital/hostel) — strategic, not now.

---

## PART 4 — DUAL-TRACK ROADMAP

### TRACK A — PRODUCTION READINESS (100% real, Play-ready)
| # | Item | Priority | Effort | Depends on | Parallel? |
|---|---|---|---|---|---|
| A1 | **Live-as-default release flavor** (bake `ENABLE_API_MODE`+module flags+VPS URL; kill mock fallback in prod path) | P0 | 3–5 d | — | Foundational — do FIRST |
| A2 | Provision `ANTHROPIC_API_KEY` on VPS + redeploy `api` fn | P0 | 1 action | owner | Yes |
| A3 | Final auth/PII pass (confirm demo-OTP dead in prod, rate limits for real PII) | P0 | 2–4 d | A1 | Yes |
| A4 | **Live-mode E2E** of ~10 core journeys (shard via `agent_coordinator.py`) | P0 | 1–2 wk | A1 | After A1 |
| A5 | **Push notifications** (FCM client + token reg + real provider) + SMS/WhatsApp on events | P1 | 2–3 wk | Firebase+vendor | Yes |
| A6 | Write-completeness gaps: transport route-attendance, hostel leave-approval, perf reviews, recruitment + **fix HR leave-approve 404** (`hr_router.ts` missing routes) | P1 | 1–1.5 wk | — | Yes (per-module) |
| A7 | Off-site backups (S3/R2) + WAL/PITR + alert sinks | P1 | 3–5 d | bucket | Yes |
| A8 | **Play packaging**: release keystore, R8/minify, launcher icon, privacy policy URL, Data Safety, permissions | P1 | 1 wk | owner accts | Yes — isolated |
| A9 | Lint cleanup (76 lib/ + 27 test/) + crash reporting (Sentry) + version bump | P2 | 3–5 d | — | Last |

### TRACK B — DIFFERENTIATION (build the moat — cheap items now)
| # | Item | Priority | Effort | Depends on | Parallel? |
|---|---|---|---|---|---|
| B1 | **Productionize per-school capability gating** — add `school_configuration` table+route, repoint store off SharedPrefs, add capability route-guard, surface the wizard. *(= launch item "hide unused modules" AND the AI School Builder's first slice)* | **P1** | 1–3 d | A1 | Yes |
| B2 | **Copilot + Parent Insights live** — provision key (A2), smoke-test, flip flags, polish prose/markdown | **P1** | hours–2 d | A2 | Yes |
| B3 | **Question Intelligence: syllabus as hard boundary** (join curriculum, reject off-syllabus chapters) + UI polish | P2 | 1–2 d | deploy | Yes |
| B4 | **At-risk: wire teacher screen to live `/intelligence/risk/*`** + populate hardcoded signals | P2 | 1–2 d | A1 | Yes |
| B5 | **Director multi-school live** — flip `DIRECTOR_API_ENABLED`, add metric-input UI, real report export | P2 | 2–4 d | A1 | Yes |
| B6 | **Question bank seeding** (real questions per Grade-10 subject) — turns plumbing into the reuse moat | P2 | content, ongoing | B3 | Yes |
| B7 | First-time student onboarding polish (Excel template, file-picker, section-sizing, placeholders) | P1 | ~1.5 wk | — | Yes |
| — | **DEFER (P4):** AI-generates-UI engine, Universal Org Builder backend, Dynamic Widget engine, Platform-Intelligence backend, Resource Optimization, verticals, white-label, M15 theme | P4 | months | 5–10 live schools | — |

---

## PART 5 — PARALLEL EXECUTION MODEL (agents / worktrees)

**Hard rule: A1 (live-as-default) lands FIRST and alone.** It is the shared dependency for A3/A4 and every Track-B flag-flip, and it edits the highest-collision files (`environment.dart`, `repository_config.dart`, `repository_providers.dart`).

After A1 merges, run in isolated worktrees:

| Agent | Scope | Touches (collision zone) |
|---|---|---|
| **A — Live E2E** | A3, A4 (run journeys live, fix breaks) | test harness, scattered fixes |
| **B — Notifications** | A5 (FCM client, providers, event wiring) | `pubspec.yaml`, communication fns, `api/index.ts` |
| **C — Write completeness** | A6 (4 module writes + HR 404) | per-module fns + `api/index.ts` |
| **D — Packaging** | A8 (keystore, icon, R8, privacy) | `android/**` only — **zero collision** |
| **E — Capability gating** | B1 (table+route+guard+wizard) | `lib/core/school_config/`, migrations, `api/index.ts`, `lib/router/*_nav` |
| **F — AI activation** | A2, B2, B3, B4, B5 (key + copilot/insights/at-risk/director/syllabus) | flag flips, `_shared/{copilot,education,intelligence}`, `api/index.ts` |
| **G — Backups/observability** | A7 + Sentry | `deploy/**`, watchdog — isolated |

**Shared dependencies / collision risks & mitigations:**
- `supabase/functions/api/index.ts` (router registration) — touched by C, E, F. **Mitigation:** each agent adds its route block at a marked region; one serial integration pass merges them.
- **Migrations** — E, C, F each add files. **Mitigation:** assign non-overlapping timestamp prefixes up front; migrations are append-only so no content conflict.
- `pubspec.yaml` — only Agent B. Keep it that way.
- `environment.dart`/`repository_config.dart` — frozen after A1; flag *values* only flipped via dart-define (build config), not code edits, so B/E/F don't re-touch them.

**Recommended order:** A1 → (parallel wave: A,B,C,D,E,F,G) → serial router/migration integration → A9 lint+crash+version → A4 final live-E2E green → A8 publish.

---

## PART 6 — AI SCHOOL BUILDER: DEEP REVIEW & RECOMMENDATION

**1. What exists:** The *provisioning* engine is real and live — `provisionSchoolFromWizard()` (`_shared/setup_wizard/`) and the startup-onboarding saga write real academic year, classes, sections, subjects, fee structures, branding, and students. The recommendation engine (`buildSetupRecommendations`) is **deterministic rules/arithmetic — zero LLM.**

**2. What's missing:** (a) the *AI* layer (interview → generated workspaces/nav/dashboards) is design-only; (b) **the interview's `modules_enabled` answer is captured and stored but never consumed by navigation** — nav is static per-role files. This single missing wire is what separates "generic ERP" from "feels built for my school."

**3. Is it really P4/Future?** **The label is wrong because it bundles two things.** The *AI-generation* layer is correctly P4 (months, premature before paying schools). But the **module-gating slice is P1 and ~3–5 days** — and the gating *substrate already exists* in `lib/core/school_config/` (85% done). The vision doc itself says "dynamic navigation is largely a matter of gating already-built modules."

**4. Should it move up?** **Yes — the gating slice only.** Promote B1 to P1. It is simultaneously: the launch retention item ("hide unused modules"), the AI School Builder's first concrete slice, and a near-free harvest of work already done.

**5. Major sales feature?** **Yes, eventually** — "the ERP that reshapes itself to your school" is a real pitch. But sell the *gating* version now; the *AI-generated* version is the 6–18 month headline, built after the first cohort.

**Recommendation:** Build B1 now (gating, days). Keep the AI-generation engine and Universal Org Builder at P4. The student-onboarding slice (B7) doubles as the builder's data foundation. Two birds.

---

## PART 7 — FINAL RECOMMENDATION

**1. Build next (immediately):**
- **A1 live-as-default release flavor** (the true #1 blocker) + **A2 provision the AI key** (one action flips Copilot/Insights to real).

**2. Build in parallel (after A1, one wave):**
- Track A: live E2E (A4), notifications (A5), write gaps + HR 404 (A6), packaging (A8), backups (A7).
- Track B (the cheap moat): capability gating (B1), AI activation (B2), syllabus boundary (B3), at-risk wiring (B4), Director live (B5), onboarding polish (B7).

**3. Postpone (P4, after 5–10 paying schools):** AI-generates-UI engine, Universal Org Builder backend, Dynamic Widget engine, Platform-Intelligence backend, Resource Optimization, verticals, white-label, M15 theme, question-paper depth (PYQ/analytics).

**4. Stop:** new "final/certification" status docs (260+ already); chasing the Universal Org Builder / vertical packs; treating "Advanced AI Predictions" as ML (it's a transparent deterministic formula — fine, but don't over-promise); the Dynamic Widget runtime as a near-term dashboard replacement.

**5. Fastest paths:**
- **Pilot readiness (~3–4 weeks):** A1 → A2 → A3 → A4 → B1 + B2 + B7 → onboard one friendly school live.
- **Production readiness (~6–8 weeks):** + A5 (push) + A6 (writes) + A7 (backups) + A8 (packaging) + A9 (lint/crash).
- **Strategic differentiation (continuous, mostly free now):** B1 + B2 + B3 + B4 + B5 during the same window — because they're last-mile, not moonshots. The moonshots wait for revenue.

**The reframe:** You don't choose between launch and moat. The moat that matters for the *pilot* is already built — turn it on (key, flag, config, a few 1–2 day wires) while you finish launch hygiene. Reserve the genuine months-long builds (AI-generated UI, Org Builder, verticals) for after schools are live and paying. Production-readiness and differentiation run on the **same parallel wave**.
