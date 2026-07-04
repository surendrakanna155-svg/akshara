# Akshara ERP — Master Roadmap Reconciliation & Strategic Review
**Date:** 2026-06-24 · **Type:** Strategic direction review (not an implementation audit) · **Author:** Claude (Opus 4.8)

> This review challenges assumptions and recovers forgotten ideas. It is meant to **replace** the scattered
> roadmap/status docs as the single source of direction. Where it conflicts with older docs, this wins (it is newer).

---

## 0. THE ONE THING TO UNDERSTAND FIRST (read this before anything else)

**The audit and roadmap docs in `docs/` are stale. They describe a mock-only app that cannot go live. That is no longer true.**

Almost every planning doc (June 14–23) says the same thing: "Akshara is a route-complete, mock-first prototype; the #1 blocker is wiring a real backend; NO-GO for production." Those docs were written *before or alongside* the Live-Backend wiring batches (1–8c), which then went and did exactly the thing the docs called the #1 blocker.

What is actually live and spot-verified today (per the batch records and the running VPS at `akshara.veloraunisexsalon.com`):

| Capability | Doc status (stale) | Real status (now) |
|---|---|---|
| Real backend wired | ❌ "all mock" | ✅ Live Supabase on VPS, public URL |
| Login / OTP | ❌ "demo OTP only" | ✅ Real Fast2SMS OTP, rate-limited, allowlist |
| Student → attendance → exam → results → parent | ❌ "exam chain fake, #1 blocker" | ✅ Wired live & durable, verified |
| Fees → invoice → collection → receipt → parent | ❌ "handoff client-only" | ✅ Wired live & durable, verified |
| Module writes + RBAC (library/transport/hostel/HR/etc.) | ❌ "writes throw stubs" | ✅ Real, RBAC-enforced live |
| Unified student identity | ❌ "no unified identity (top red-team P0)" | ✅ Closed via operational student_id FKs (Batch 6) |
| Backups / monitoring / storage | ❌ "not started" | ✅ Encrypted nightly backups + restore-tested + watchdog |
| Real AI (copilot + parent insights) | ❌ "stub, no LLM" | ✅ Real Claude, safe fallback (needs API key on VPS) |
| Question paper intelligence | ❌ "fake, appends literal text" | ✅ Bank-first + deterministic solver + constrained AI, deployed |

**Implication:** We are far closer to a real pilot than the audits claim. But this creates a **new, sharper risk the old docs never name** — see §9. The old "we're all mock" framing is wrong; do not re-plan around it.

---

## SECTION 1 — ROADMAP HEALTH CHECK

**Is the roadmap still valid?** *Partially.* The **vision and module coverage are right.** The **status tracking is unreliable.**

**Is it outdated?** Yes, in two specific ways:
1. **It under-reports reality.** Live wiring (Batches 1–8c) closed most of what the roadmap lists as open "launch blockers." The roadmap never caught up.
2. **It over-reports reality in the opposite direction elsewhere.** "ERP 99.5% / 97-100 readiness / production-ready" was true *for the Flutter UI on mocks* and got read as "the product is done." Both errors come from the same root cause: **the docs conflate three different completion axes** — (a) UI built, (b) wired to live backend, (c) proven under real load. A feature can be 100/40/0 on those three and the roadmap reports a single blended "%".

**Does it reflect the current state of the codebase?** No. It lags the live-wiring batches by ~6–8 of the most important deliverables.

**Does it reflect the original vision?** Yes — the long-term vision (multi-school SaaS, AI-configured school OS, question intelligence, verticals) is intact and well-preserved across `FUTURE_VISION_*` docs.

**Assumptions no longer true:**
- "All data is mock / nothing persists." → False. Core loops persist live.
- "Exam chain is fake and is the #1 blocker." → The *marks→results→parent* chain is wired live. Question-*paper* generation is a separate, now-built feature.
- "No unified student identity." → Closed in Batch 6.
- "AI is a stub with no LLM." → Real Claude is wired; just needs the key provisioned.
- "Backups not started." → Live and restore-tested.

**Still true:**
- Real parent notifications (push/SMS/WhatsApp) are not connected.
- Everything verified live was verified by **spot checks**, not a full live-mode E2E suite. The ~109 Patrol journeys are all certified **in mock mode**.
- First-time student onboarding (bulk import UX + placeholders) is planned, not built.

### Roadmap score: **5.5 / 10**
- Vision/direction: 9/10 (genuinely strong, well-preserved)
- Status accuracy: 3/10 (stale both ways; can't be trusted to plan from)
- Prioritization clarity: 5/10 (good instincts in `FIRST_10_SCHOOLS_STRATEGY`, buried under 260 docs)
- Reconciliation discipline: 4/10 (too many overlapping "final" docs, none authoritative)

The fix is not more building — it's **collapsing the doc sprawl into one truthful tracker with three status columns (UI built / wired live / proven live).**

---

## SECTION 2 — IDEA RECOVERY

~148 distinct ideas exist across the docs. Full inventory is in the agent appendix; here are the **buckets that matter for direction**, with emphasis on **D (forgotten)**.

### A. Implemented & live (the real spine)
SIS, attendance, exams/marks→results, fees→receipts, admissions, HR/leave, library/transport/hostel/inventory/alumni writes, Director multi-school, RBAC, backups/monitoring, real Claude copilot + parent insights, question-paper intelligence (bank + solver + constrained AI), promotion/reshuffle/section-balancing, broadcast notifications (in-app), school memories, growth platform.

### B. Partially implemented (finish-or-cut decisions)
- AI copilot **live context wiring** (real Claude works; screen-context injection partial).
- Student **at-risk scoring** (UI done, engine is mock).
- **Concession → ledger** posting (collection works; ledger posting shallow).
- **Report card / receipt PDFs** live (mostly done; confirm under live mode).
- **Unified onboarding wizard** (captures data; doesn't yet provision year/roles/config automatically).
- **Translation framework** (~25% rollout).
- **WhatsApp / SMS** comms (designed, not wired).

### C. Planned, not started
QR/offline payments, AI parent-meeting summaries, school branding/white-label, dynamic widget platform, universal org builder, M15 theme polish, teacher schedule-swap, performance-based section assignment.

### D. FORGOTTEN / buried (the point of this exercise — recover these)
| Idea | Source | Why it matters | Verdict |
|---|---|---|---|
| **First-time student onboarding** (Excel template, section sizing, placeholder students, add-one) | IDEAS_BACKLOG 2026-06-24 + plan doc | **You cannot start a school without loading its students.** This is a literal Day-0 launch need and it's not in any milestone. | **Promote to P0.** |
| **Real push notifications (Firebase)** | NOTIFICATIONS plan | Schools pay to replace WhatsApp groups; in-app inbox alone won't be felt. Backend ready, phone app not wired. | **Promote to P1.** |
| **Poster/image broadcasts** | NOTIFICATIONS plan | Festival posters are *the* viral, delight feature for Indian principals. ~1 day. | **P2 quick win.** |
| **Principal holiday calendar** | NOTIFICATIONS plan | Mark a date → auto-notify everyone. Reuses broadcast infra. ~1.5–2 days. | **P2 quick win.** |
| **Live-mode E2E re-run** | Your own early report | The single most valuable test work; nothing currently *proves* the live backend holds under full journeys. | **Promote to P0 (verification gate).** |
| **Off-site backups / WAL-PITR / alert sinks** | IDEAS_BACKLOG Batch-7 follow-ups | RPO is ~24h and alerts are log-only. A pilot data-loss event would be fatal to trust. | **P1.** |
| **ANTHROPIC_API_KEY provisioning on VPS** | Batch 8 record | One server action stands between "AI is real in code" and "AI is real for schools." | **P0 if AI is in pilot scope (1 action).** |
| **Vice-Principal / delegation role** | Red-team audit | Real schools delegate; no role exists. | **P3.** |
| **Deployment model (Shared SaaS vs Dedicated VPS) choice at onboarding** | DEPLOYMENT plan | A real go-to-market + data-residency decision, not yet a roadmap item. | **P3 (decide before school #3).** |

---

## SECTION 3 — AI STRATEGY REVIEW (ranked by ROI)

| Initiative | Status | Pilot value | Long-term value | Effort left | ROI rank |
|---|---|---|---|---|---|
| **Parent insights (Claude prose, local language)** | ✅ Live, safe fallback | **High** — parents feel it immediately | High | ~0 (provision key) | **1** |
| **Copilot (principal/teacher) live context** | 🟡 Real Claude; context wiring partial | Medium-High | High | 2–5 d | **2** |
| **Question-paper intelligence** | ✅ Backend+UI deployed | Medium (teachers want it) | **Very High** (category moat) | UI polish + syllabus-boundary wiring | **3** |
| **At-risk student scoring** | 🟡 UI done, engine mock | Medium | High | Deterministic rules first (~2 wk) | **4** |
| **AI communication generator (WhatsApp/SMS drafts)** | 🟡 Partial | Medium | High | Tied to notifications work | **5** |
| **AI School Builder (generates UI per school)** | 📐 Design, **now unblocked** | Low (won't ship for pilot) | **Strategic (SaaS scale moat)** | Months | **6** |
| **Universal Org Builder / verticals AI** | 📐 Design, shelved | None | Strategic, later | Months | **7** |

**Are we spending AI effort in the right places?** **Yes, and unusually well.** The discipline of "bank-first, AI fills gaps only, teacher approves" (question intelligence) and "deterministic numbers, AI only rewrites prose" (parent insights) is exactly right — it makes AI *trustworthy*, which is what schools need. The one cheap miss: the **API key isn't provisioned**, so real AI isn't actually on for anyone yet. Fix that first.

**The trap to avoid:** pouring months into the **AI School Builder** (generate-the-whole-UI-from-an-interview) before the first cohort is live and paying. It's now unblocked (its four UX prerequisites are done per the master audit) — but "unblocked" ≠ "now." See §5.

---

## SECTION 4 — PRIORITY REASSESSMENT (replanned from scratch, reconciled to live reality)

### Priority 0 — Critical launch blockers (cannot run a real school without these)
| Item | Why P0 |
|---|---|
| **Live-mode E2E verification of the ~10 core journeys** | Everything "verified live" was spot-checked. Nothing *proves* the live backend survives full journeys at a school's volume. This is the real gate. |
| **First-time student onboarding** (Excel template + section sizing + placeholder students + add-one) | Day-0 requirement. No students → no school. Currently unbuilt. |
| **Production auth/PII final hardening** (kill any demo-OTP path, confirm rate limits/allowlist for real PII) | Mostly done (Batch 2); needs a final pass before real parent phone numbers enter. |
| **Provision `ANTHROPIC_API_KEY` on VPS** (if AI is in pilot scope) | One action; flips AI from "real in code" to "real for schools." |

### Priority 1 — Required for pilot *success* (school stays, doesn't just survive)
| Item | Why P1 |
|---|---|
| **Real parent notifications: push (Firebase) + SMS/WhatsApp** | The thing schools *pay for*. In-app inbox alone won't replace WhatsApp groups. |
| **Off-site backups + alert sinks** (S3/R2, webhook/SMS alerts) | One data-loss or silent-outage event kills pilot trust. RPO ~24h → ≤15min. |
| **Per-school feature flags / hide unused modules** | A day school shouldn't see hostel/transport/verticals. "Feels simple" = retention. |
| **Confirm report-card + receipt PDFs under live mode** | Parents judge you on the artifacts they can hold. |
| **Support + hypercare runbook** | First-cohort operations reality. |

### Priority 2 — High-value near-term (delight + differentiation)
| Item | Why P2 |
|---|---|
| **Question-paper UI polish + wire syllabus as hard boundary** | Backend is built; close the free-text-chapters liability and let teachers actually use it. |
| **Poster/image broadcasts** | ~1 day, high delight (festival posters). |
| **Holiday calendar** | ~1.5–2 days, reuses broadcast infra. |
| **Concession→ledger posting + finance export polish** | Closes the accountant's trust gap. |
| **Copilot live screen-context wiring** | Makes the AI feel "built for my screen." |

### Priority 3 — Post-launch improvements
At-risk scoring engine (real), Vice-Principal/delegation role, Director multi-school deepening, deployment-model (Shared vs Dedicated) productization, translation full rollout, teacher schedule-swap.

### Priority 4 — Long-term vision
**AI School Builder** (generates per-school UI), Universal Org Builder, verticals (salon/hospital/restaurant/hostel), dynamic widget platform, M15 theme, white-label. All correctly deferred. Build *after* 5–10 schools are live and paying.

---

## SECTION 5 — AI SCHOOL ONBOARDING AUDIT

**What exists:** A unified onboarding **wizard UI** (`/admin/onboarding/unified`): Profile → Curriculum → Fees → Branding → Modules → Review → Go Live, with hybrid local/Supabase persistence. Plus a **real student-import backend** (`/onboarding/imports/students/preview|commit|rollback`, parent OTP via `upsertUserByPhone`).

**What's missing:** Automatic go-live provisioning (seed academic year, roles, config from the wizard), the Excel template + section-sizing + placeholder-student UX, and the *AI* layer (interview → generated workspaces/nav/dashboards).

**Is it actually 25% complete?** **Yes, ~25% — but that number mixes two different things.** The *plain* onboarding (wizard + import) is ~60–70%. The *AI generation* layer is ~0–10% (design only). The "25%" is the blended figure.

**What remains:** (1) the student-data onboarding slice (~1.5 wk, split A/B/C — see below); (2) auto-provisioning saga; (3) the AI generation engine (months).

**Is it unblocked?** **Yes.** Its four stated prerequisites (Workspace Consolidation → Navigation → Mobile UX → Screen Consolidation) are marked done in the master audit. It is parked-and-ready, not lost.

### Should AI School Onboarding be prioritized ABOVE Question Paper Generation?
**No — but the question is now moot, and here's the nuance that matters:**

- **Question Paper Generation is already built and deployed** (Batches 8b/8c + curriculum seeding). It is not competing for build effort anymore — it's in "polish + validate usage" mode. So there's nothing to prioritize *above*.
- **The *plain* first slice of AI Onboarding (student data import + structure + placeholders) should be prioritized above almost everything** — it's a P0 Day-0 launch need.
- **The *AI* layer of onboarding (generate-the-UI) stays P4.** Building it now would be premature; you'd be personalizing an experience for schools you don't yet have.

**Evidence:** A school cannot begin without its students loaded (P0). A school *can* run a successful pilot with a perfectly good manual question-bank/paper flow (already shipped). Therefore: build the plain onboarding now; let AI pre-fill it later. Your own framing — "the AI interview fills the same structure step; build the plain version now, AI pre-fill later" — is exactly correct.

---

## SECTION 6 — QUESTION PAPER GENERATION REVIEW

**Is it overbuilt relative to launch needs?** **No.** The shipped Batch 8b core is lean (~1.3k LOC backend): deterministic blueprint solver + bank-first fill + constrained AI gap-fill (candidates only, teacher approves, publish-gated). That is disciplined, not bloated. The *risk* is the **next** phases (PYQ store, item analytics, Bloom tagging, foundation/competitive patterns) — those would be premature to build now.

**Value today:** Teachers build a reusable bank, generate papers with exact marks distribution, dedup duplicates, AI fills only gaps with approval. Real and usable.

**Value during pilot:** Compounds as the bank grows; gives you data on whether teachers actually adopt it (the key validation).

**Value after launch:** This is the **category moat** — owning syllabus + bank + exam + marks + analytics is something competitors don't do well.

### Recommendation: **B — Pause *further deepening* temporarily (ship and validate what exists).**
Not "pause the whole thing" (it's already shipped) and not "continue immediately deepening." Specifically:
1. **Ship the built version** to the pilot with the current UI.
2. **Wire syllabus as a hard boundary** (the one real liability — generation still takes free-text chapters). Small, P2.
3. **Stop before** PYQ/analytics/foundation-patterns until a pilot school proves teachers use the bank (target: >30% of paper content reused from bank). If adoption is low, the deeper investment is unjustified.

---

## SECTION 7 — PRODUCT STRATEGY (advising the founder)

**If I had to get the first 5 schools live and successful:**

**Build next (in order):**
1. **Live-mode E2E proof** of the core journeys — turn "spot-verified" into "proven."
2. **Student onboarding** — they can't start without it.
3. **Real notifications (push + SMS/WhatsApp)** — the thing they'll pay for.
4. **Off-site backups + alerts** — so one bad night doesn't end the pilot.
5. **Per-school flags / hide unused modules** — make it feel simple.

**Stop building:**
- Anything in verticals (salon/hospital/restaurant/hostel) — correctly shelved, keep it shelved.
- The AI School Builder *generation engine* — unblocked but not now.
- Further question-paper depth (PYQ/analytics/foundation patterns).
- New "final status / certification" docs. You have ~260 docs; the 261st won't help.

**Delay:**
- At-risk scoring engine, Vice-Principal role, Director deepening, translation full rollout, M15 theme.

**Remove from the roadmap entirely (or formally archive as "someday"):**
- Multi-industry verticals as a near/mid-term track (keep the shared-kernel code, drop it from the roadmap).
- White-label/branding as a priority item.
- The blended "% complete" metrics — replace with the 3-axis tracker.

**The strategic reframe (which `FIRST_10_SCHOOLS_STRATEGY` got right and the rest of the docs buried):** You do not have a feature problem. You have a **proof + focus + last-mile** problem. The backend is wired; now *prove it live, load the students, make parents feel the notifications, and hide the noise.*

---

## SECTION 8 — FINAL MASTER ROADMAP

### NOW (0–30 days) — "Prove it and open the door"
| Item | Business value | User impact | Effort | Dependency | Priority |
|---|---|---|---|---|---|
| Live-mode E2E of ~10 core journeys | De-risks the entire pilot | None direct (confidence) | 1–2 wk (shard across devices) | Live backend (done) | P0 |
| First-time student onboarding (template + structure + placeholders + add-one) | Enables Day-0 setup | Admin loads school in minutes | ~1.5 wk (A/B/C tracks) | Import backend (done) | P0 |
| Production auth/PII final pass | Legal/trust to hold real data | Safe login | 2–4 d | Batch 2 (done) | P0 |
| Provision `ANTHROPIC_API_KEY` | Turns AI on for real | Live parent insights/copilot | 1 action | VPS access | P0 |

### NEXT (1–3 months) — "Make them stay"
| Item | Business value | User impact | Effort | Dependency | Priority |
|---|---|---|---|---|---|
| Push + SMS/WhatsApp notifications | The paid value prop | Parents actually get alerts | 2–3 wk | Firebase + SMS vendor | P1 |
| Off-site backups + alert sinks | Survival insurance | Invisible (until it saves you) | 3–5 d | S3/R2 account | P1 |
| Per-school feature flags / hide modules | "Feels built for us" | Simpler app | 1 wk | — | P1 |
| Support/hypercare runbook + PDF confirm | Operable pilot | Reliable artifacts | 3–5 d | — | P1 |
| Question-paper syllabus boundary + UI polish | Differentiator usable | Teachers trust the bank | 1 wk | 8b/8c (done) | P2 |
| Poster broadcasts + holiday calendar | Delight, virality | Principals love it | 2–3 d each | Broadcast infra (done) | P2 |

### LATER (3–6 months) — "Deepen and delegate"
At-risk scoring engine (deterministic first), copilot live context everywhere, concession→ledger + finance exports, Vice-Principal/delegation role, Director multi-school deepening, translation rollout, deployment-model (Shared vs Dedicated) productization. *Priority P2–P3. Dependency: a stable first cohort.*

### FUTURE (6–18 months) — "Scale moat"
AI School Builder (per-school UI generation), Universal Org Builder, verticals, dynamic widgets, white-label, M15 theme, question-paper depth (PYQ/analytics/foundation). *Priority P4. Dependency: 5–10 paying schools.*

---

## SECTION 9 — BRUTAL HONESTY CHECK

**1. Are we building the right product?** **Yes.** A trust-first, governance-first school ERP with disciplined AI is the right product for the Indian market. The vision is sound and the live core is real.

**2. Are we spending time in the right areas?** **Mostly — with one systemic waste:** an enormous amount of effort goes into **documentation and re-certification** (~260 docs, many overlapping "final/certified" reports) and into **breadth** (39 modules, verticals) rather than **proving the live core and shipping the last mile** (onboarding, notifications). The build instincts are good; the *accounting* of progress is the weak point.

**Top 5 strategic mistakes we could make from here:**
1. **Re-planning around the stale "we're all mock" audits** and re-doing backend work that's already done.
2. **Believing the "99.5% / production-ready" framing** and launching without the live-mode E2E proof — then discovering a real-volume failure at a school.
3. **Building the AI School Builder now** because it's "unblocked," before a single school is live and paying.
4. **Launching without real notifications**, so schools don't feel the value they're paying for and churn.
5. **Adding a 261st status doc** instead of one truthful 3-axis tracker — keeping the team confused about what's actually done.

**Top 5 opportunities we should not miss:**
1. **You're ~3–4 weeks from a real pilot, not 3–4 months.** The hard backend work is done; act on that, don't re-litigate it.
2. **Question intelligence is a genuine moat** — already built. Validate adoption in the pilot and you have a real differentiator.
3. **Disciplined AI (deterministic + AI-on-top)** is a trust advantage competitors won't easily copy. Lead with it.
4. **The student-onboarding slice doubles as the AI School Builder's first concrete slice** — build it plain now, harvest it for the vision later. Two birds.
5. **Festival posters + holiday calendar** are cheap, viral delight features uniquely suited to Indian schools — disproportionate love for ~3–4 days of work.

**5. If I were product owner, the next 30 days:**
- Week 1: Provision the AI key. Stand up the 3-axis truth tracker (kill the doc sprawl). Lock the onboarding contract (columns + 2 endpoints). Start live-mode E2E shard setup.
- Weeks 1–2: Build student onboarding (Tracks A/B/C in parallel). Run core journeys in live mode; fix what breaks.
- Weeks 2–3: Final auth/PII pass. Stand up off-site backups + alert sinks. Begin notifications (push first).
- Week 4: Onboard **one** real, friendly school end-to-end on live mode. Watch it for a week. Fix on contact. *Then* talk about school #2–5.
- **Do not** start the AI School Builder, verticals, or question-paper depth this month.

---

## APPENDIX — Reconciliation note on the testing question
The ~109 Patrol journeys are **certified in mock mode only**. The highest-leverage test work is **re-running the ~10 core journeys in live mode** (the one thing no test currently proves), folding the new onboarding feature's live tests into that same push. Parallelize via device sharding (`agent_coordinator.py` is the right place) — 4 devices ≈ 4× faster. The onboarding build splits into three non-blocking tracks (A backend / B Flutter / C tests), ~1.5 wk wall-clock vs ~3 wk sequential.
