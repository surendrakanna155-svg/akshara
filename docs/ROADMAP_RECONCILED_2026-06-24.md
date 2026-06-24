# Akshara — Authoritative Roadmap (Reconciled, 2026-06-24)

> This document **supersedes** the earlier (June) vision-based roadmap. It is
> evidence-based, built only from the completed audits + live certifications
> (no new audit was run):
> Project State Audit · Marketing & Admissions Engine Audit · Admissions CRM &
> Lead-Follow-up Audit · Live Certification reports · B7 Onboarding certification
> · AI activation + 25/25 live-journey certification.

---

## 1. Executive summary — what changed from the June roadmap and why

**The June roadmap was vision-led.** It assumed the next four big differentiators were
**AI School Builder, Organization Builder, Dynamic Widget Platform, and Verticals** — all
treated as "to be built."

**The audits + live certifications change the picture in one decisive way:** the features
that actually form the competitive moat — **AI (Copilot + Parent Insights + an admissions
assistant persona), WhatsApp, Communications, Memories, Branding, Broadcasts, Approvals,
the Admissions funnel, Enrollment conversion, and Parent engagement — are already LIVE and
reusable.** And the two revenue engines are nearly finished: **Marketing Engine ≈ 70%**,
**Admissions CRM ≈ 65–70%**.

**Therefore the priority inverts:** the fastest path to pilot success and first paying
schools is **completing the near-done revenue features and shipping the already-live AI**,
not starting months-long platform bets. The four "June differentiators" are **deferred**:
they are 5–15% complete, multi-month efforts, and (Org Builder / Verticals) have no backend
today — they would 404 if switched on. They become bets we make *after* the pilot proves
the core, funded by real revenue, validated by real school feedback.

**Net change:** roadmap moves from *"build new platforms to differentiate"* → *"finish the
2 revenue engines + harvest the already-built AI moat; defer the platform bets."*

---

## 2. Feature scorecard

Current % uses accepted audit facts + this session's live certifications. Effort = remaining
engineering to a shippable, pilot-grade state. Value/Differentiation are H/M/L.

| Feature | Current % | Business Value | Differentiation | Effort Remaining | Priority |
|---|---|---|---|---|---|
| **Admissions CRM** | 65–70% | **High** (converts inquiries → enrolments = revenue) | Med-High | ~2–3 wk | **P1** |
| **Marketing Engine** | 70% | **High** (fills top of funnel) | **High** (rare in school ERPs) | ~2–4 wk | **P1** |
| **AI Admissions Assistant** | ~60% (reuses live Copilot `admissions` persona + funnel data) | **High** | **High** | ~1–2 wk | **P1** |
| **Parent Insights** | ~80% (LIVE, real Claude) | **High** (engagement / retention) | **High** | ~1 wk polish | **P1** |
| **Capability Gating** | ~85% (merged, A1) | **High** (enables tiered pricing / packaging) | Med | ~1 wk | **P1** |
| **AI Copilot** | ~85% (LIVE, verified real output) | Med-High | **High** | ~1 wk polish (streaming/UX) | **P2** |
| **Director Multi-School** | ~80% (LIVE, RBAC, audited) | Med (chains = bigger deals; pilot is single-school) | **High** | ~1–2 wk | **P2** |
| **Advanced AI Predictions** | ~25–30% (client stub; no backend route) | Med-High | **High** | ~6–10 wk | **P2/P3** |
| **AI School Builder** | ~10–15% | Med (onboarding accelerator) | **High** (vision) | ~8–12 wk | **P3** |
| **Organization Builder** | ~10% (no backend — OFF in live config) | Low for pilot (single school) | Med | ~6–10 wk | **P3** |
| **Dynamic Widget Platform** | ~5–10% | Low-Med (pilot) | High (long-term) | ~10–16 wk | **P3/P4** |
| **Verticals** | ~0–5% (frozen) | Low pre-validation | High (long-term TAM) | 12+ wk | **P4** |

---

## 3. Re-ranking rationale (A pilot-value · B revenue · C differentiation · D effort)

- **A. Pilot-school value:** a pilot needs to *convert the inquiries it already has* and
  *keep parents engaged*. That points at **Admissions CRM, Parent Insights, AI Admissions
  Assistant, WhatsApp/Comms (done)** — not at platform builders.
- **B. Revenue impact:** first cheques are signed on **admissions/enrolment outcomes** and
  **tiered packaging**. → **Admissions CRM, Marketing Engine, Capability Gating** rank top.
- **C. Differentiation:** the moat is **already shipped** (AI Copilot, Parent Insights,
  WhatsApp ecosystem, Broadcasts, Branding, Approvals). The job is to *surface and polish*
  it, which is cheap, not to build new moats from scratch.
- **D. Engineering effort:** the top-ranked items are **days-to-weeks** (60–85% done); the
  June differentiators are **months** (5–15% done) and partly backend-less. Effort-adjusted
  value overwhelmingly favours finishing the near-done revenue + AI features.

---

## 4. Hidden wins (already 60–90% — shippable in days/weeks, not months)

These are the highest-leverage items: large value, small remaining effort.

1. **Parent Insights (~80%, LIVE)** — real Claude already wired; needs surfacing/polish. *~1 wk.*
2. **AI Copilot (~85%, LIVE)** — verified returning real output this session; needs UX/streaming polish. *~1 wk.*
3. **Capability Gating (~85%)** — unlocks **tiered pricing** (a revenue lever) almost immediately. *~1 wk.*
4. **AI Admissions Assistant (~60%)** — the Copilot already has an `admissions` persona; point it at the funnel/CRM data. *~1–2 wk.*
5. **Admissions CRM (65–70%)** — finish the lead-follow-up loop + pipeline stages + conversion tracking (WhatsApp/Comms already done and reusable). *~2–3 wk.*
6. **Marketing Engine (70%)** — campaigns + lead capture on top of the live Broadcasts/Branding/Comms. *~2–4 wk.*
7. **Director Multi-School (~80%, LIVE)** — ready for multi-branch sales conversations with light polish. *~1–2 wk.*

> Reusable building blocks already live (do NOT rebuild): WhatsApp deep-link ecosystem,
> Communications, Broadcasts, Memories, Branding, Approvals, Admissions funnel, Enrolment
> conversion, Parent engagement, AI client (Copilot + Insights).

---

## 5. Revised roadmap (P0–P4)

**P0 — Launch blockers** *(owner-gated; currently PAUSED at owner's instruction)*
- Privacy-policy finalization (legal details), upload keystore, Play Console + data-safety,
  parent-SMS activation at pilot onboarding. *No engineering blockers remain — the app is
  live-certified; these are owner/business actions.*

**P1 — Immediate revenue features** *(finish the near-done engines + harvest AI)*
- Admissions CRM completion (follow-up loop, pipeline, conversion tracking).
- Marketing Engine MVP (campaigns, lead capture).
- AI Admissions Assistant (Copilot `admissions` persona on funnel data).
- Parent Insights polish + Capability Gating finalize (enables tiered pricing).

**P2 — Differentiation features** *(polish the shipped moat; widen deals)*
- AI Copilot UX/streaming polish.
- Director Multi-School polish (multi-branch sales).
- Advanced AI Predictions — scope + first model (e.g., fee-default / enrolment likelihood).

**P3 — Platform bets** *(only after pilot validation + revenue)*
- AI School Builder · Organization Builder · (start of) Dynamic Widget Platform.
- Note: Org Builder needs a backend before any UI is meaningful.

**P4 — Long-term vision** *(frozen until the core is validated)*
- Verticals · full Dynamic Widget Platform.

---

## 6. Sequencing decisions (explicit answers)

**Q1. Should Admissions CRM be completed before Marketing Engine?**
**Yes — CRM first.** Both are ~70% and share the live WhatsApp/Comms/Broadcast plumbing, but
CRM sits at the **revenue end** (convert inquiries the pilot already has). A pilot with a
half-built marketing top-of-funnel still converts via CRM; a pilot generating leads it can't
systematically follow up wastes them. Finish CRM's follow-up/conversion loop, then build the
Marketing Engine MVP that feeds it. (They can overlap on shared components, but CRM lands first.)

**Q2. Should Marketing Engine MVP be built before AI School Builder?**
**Yes — unambiguously.** Marketing Engine is 70% done (weeks) and drives revenue; AI School
Builder is ~10–15% (months) and is a vision bet. Evidence-based prioritization ships the
near-done revenue engine first.

**Q3. Should Dynamic Widgets and Organization Builder remain deferred?**
**Yes — keep deferred (P3).** Both are 5–10% complete, multi-month, low pilot value, and have
no live backend (Org Builder is OFF in `config/live_release.json` precisely because it would
404). Revisit only after pilot revenue justifies a platform investment.

**Q4. Should Verticals remain frozen until after pilot validation?**
**Yes — frozen (P4).** Verticals multiply surface area before the core school product is
validated by paying customers. Unfreeze only once the pilot proves retention + the first
paying schools define which vertical is worth the TAM bet.

---

## 7. Recommended execution order — next 90 days

*Engineering track (P0 owner-gated items run in parallel whenever the owner unpauses them).*

**Weeks 1–3 — Convert what we already have**
- Admissions CRM: lead-follow-up loop, pipeline stages, conversion tracking (reuse live WhatsApp/Comms).
- Parent Insights polish + Capability Gating finalize (turn on tiered packaging).

**Weeks 3–6 — Harvest the AI moat (cheap, high-diff)**
- AI Admissions Assistant (Copilot `admissions` persona → funnel/CRM data).
- AI Copilot UX/streaming polish.
- Drop `WhatsAppContactButton` into the remaining surfaces (admissions leads, fee defaulters,
  transport, vendors, alumni) — one-line reuse, no backend work.

**Weeks 6–10 — Fill the funnel**
- Marketing Engine MVP (campaigns + lead capture on live Broadcasts/Branding).
- Director Multi-School polish for multi-branch sales conversations.

**Weeks 10–12 — Set up the next moat**
- Scope + first **Advanced AI Predictions** model (fee-default or enrolment-likelihood) on real pilot data.
- Pilot retrospective → decide whether any P3 platform bet graduates.

**Deferred (not in 90 days):** AI School Builder, Organization Builder, Dynamic Widget
Platform (P3); Verticals (P4).

---

### One-line summary
*Finish the two revenue engines (CRM → Marketing) and ship the already-live AI; defer the
four "June differentiators" until the pilot pays for them.*
