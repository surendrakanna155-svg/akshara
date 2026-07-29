# Akshara ERP — Product Experience Certification Audit

**Date:** 2026-07-21
**Scope:** Web ERP · Android · iOS · Tablet — usability, workflows, IA, visual design, accessibility, AI experience (NOT code quality, NOT performance)
**Method:** Independent Product Review Board of **17 parallel expert reviewers** (10 specialist lenses, 6 role-based journey simulations, 1 competitive analyst), each auditing blind to the others. Evidence basis: route/screen/provider code traces, 70 rendered golden screenshots (390×844 / 428×926 / 834×1194, light + dark), backend contract checks, competitor research (Teachmint, Fedena, Entab, MyClassboard, NextERP). Every P0-severity claim was then **adversarially verified** by an independent refuter agent instructed to disprove it.
**Volume:** 250 raw findings → 56 P0 claims → 45 taken through adversarial verification (cross-reviewer dedup + a cap of 45; the 11 claims past the cap are duplicates of verified clusters or carry an explicit `unverified` marker in the roadmap register `docs/roadmap/UXR_FINDINGS_REGISTER.md`) → **15 confirmed P0 (13 unique defects), 29 downgraded (28 → P1, 1 → P2), 1 refuted.**
**Raw data:** full reviewer outputs preserved in the session workflow journal (`wf_bee4a4f0-868`); this report is the reconciled record.

---

## VERDICT

# ❌ NOT CERTIFIED — Significant UX Redesign Required

**Board vote: 11 × NOT CERTIFIED · 6 × CERTIFIED (moderate improvements required) · 0 × certified as-is.**

Precision matters about *what kind* of redesign: the board is near-unanimous that the **design system, mobile information architecture, and the three core teacher/finance interaction loops are certified-quality and must be preserved unchanged**. What blocks certification is not aesthetics — it is **completion and honesty**: simulated money flows that post real receipts, fabricated demo data rendered as live truth across primary journeys, a web platform that cannot execute a single business transaction while presenting enabled buttons, an admission funnel that cannot be resumed, and a student persona with no way to log in. Three areas (office money flows, admissions continuity, web action layer) genuinely require redesign, not polish.

---

## Scores (board averages, 1–10; each dimension scored only by reviewers who assessed it)

| Dimension | Score | Reading |
|---|---|---|
| **1. Overall UX** | **4.8 / 10** | Excellent skeleton, incomplete organs |
| **2. Mobile UX** | **5.9 / 10** | The strongest surface; held back by demo-data leakage and dead ends |
| **3. Web UX** | **3.6 / 10** | A polished read-only viewer, not yet an ERP |
| **4. Accessibility** | **5.5 / 10** | Top-decile Flutter foundation; web not keyboard-operable where it matters |
| **5. Workflow Efficiency** | **4.3 / 10** | Teacher loops world-class; office/money loops broken |
| **6. Visual Design** | **7.0 / 10** | The best dimension — real token discipline, designed dark mode |
| **7. AI Experience** | **4.3 / 10** | A governed, explainable lane undermined by a fake-inference lane |
| **8. Product Maturity** | **4.8 / 10** | Demo scaffolding still embedded in production paths |

### Per-reviewer votes

| Reviewer | Vote | Overall |
|---|---|---|
| Principal Product Designer | CERTIFIED-MODERATE | 6.5 |
| Senior UX Researcher | CERTIFIED-MODERATE | 6 |
| Mobile UX Specialist | CERTIFIED-MODERATE | 6 |
| Web UX Specialist | NOT CERTIFIED | 3.5 |
| Enterprise SaaS Designer | CERTIFIED-MODERATE | 6 |
| HCI Specialist | NOT CERTIFIED | 5 |
| Accessibility Specialist | CERTIFIED-MODERATE | 5.5 |
| School ERP Domain Expert | NOT CERTIFIED | 4.5 |
| QA Usability Reviewer | NOT CERTIFIED | 5 |
| AI Experience Reviewer | NOT CERTIFIED | 4 |
| Principal (journey) | NOT CERTIFIED | 4 |
| Teacher (journey) | NOT CERTIFIED | 5 |
| Parent (journey) | NOT CERTIFIED | 4 |
| Student (journey) | NOT CERTIFIED | 4 |
| Accountant (journey) | NOT CERTIFIED | 3 |
| Front Office (journey) | NOT CERTIFIED | 4 |
| Competitive Analyst | CERTIFIED-MODERATE | 6 |

Pattern worth noting: **every persona who simulated a real working day voted NOT CERTIFIED**; the specialists who audited structure and craft voted CERTIFIED-MODERATE. The architecture reviews well; the days don't complete.

---

## Executive Summary

Akshara is **two products wearing one skin** (a phrase three reviewers used independently).

The first product is genuinely excellent and ahead of every incumbent researched: a test-enforced 4-tab persona navigation contract, a real USER→ROLE→WORKSPACE→TASK hide-first model with five stacked gates, exception-first teacher attendance with draft autosave, spreadsheet-grade marks entry with AB/ML/DB semantics and an audited approval chain, honest offline "queued" ceremonies for money, top-decile design-token and dark-mode discipline, and an explainable, dismissible AI recommendation feed. The competitive analyst confirmed the incumbents' parent apps are their weakest surface (Entab ~3.3★ across 123k reviews; MyClassboard iOS ~2.5★) — Akshara's UX *architecture* would win this market.

The second product is what a real school hits within the first hour: a parent "Pay Now" that fabricates a gateway result and **posts a genuine receipt clearing real dues with no money moved**; a fee counter that can **post a payment against the wrong student's invoice** by default; an admission funnel held together by in-session memory **with a mock write-store in the live submit path**; an Admin Hub greeting the principal with **hardcoded fake stats presented as live**; parent screens silently falling back to a fictional child ("Ravi Kumar · 8-A"); a principal who **cannot send a circular from the phone** because the only compose screen is in an orphaned hub; a teacher who cannot mark a student **AB** on the phone in the top-priority Exams module; a student persona with **no login path**; and a web ERP in which **the only POST is login** — every "Collect fee", "Approve", "Save marks", "Add student" button is a dead control styled as a live one.

The board's conclusion: the failure mode is not design capability — it is that **demo-ware and production-ware coexist on the same certified surfaces with no boundary**. The project's own Product Reality Audit predicted exactly this ("never trust a prior cert"); the "229/229 routes" web certification measured render-reachability, not task-completability. Certification requires evicting the simulation layer from live paths, wiring or honestly disabling every dead affordance, and finishing three redesigns (fee counter, admissions continuity, web action layer). The foundation deserves to win; as shipped today, it cannot be certified.

---

## Top Strengths (unanimous or multi-reviewer)

1. **The persona navigation contract** — max 4 primary tabs + More sheet, single source of truth, test-enforced (`lib/shared/navigation/persona_nav.dart`). Cited by 9 reviewers as the correct mobile IA.
2. **Exception-first teacher attendance** — "All present" → tap exceptions → "Fill remaining present", draft autosave, correction requests. The domain expert: *"exactly how teachers work"*; competitive analyst: *"the clearest daily-workflow win over every incumbent."*
3. **Exam marks-entry ergonomics** — Enter/Tab focus chaining, per-cell save state, AB/ML/DB that never writes a spurious zero, row_version concurrency guard, phase-gated verify→approve→publish lifecycle (admin grid).
4. **Money honesty ceremonies** — amber "Payment queued — receipt issued once it syncs" vs green server-confirmed success; Resume/Discard draft recovery that never silently prefills a money amount; idempotency-keyed writes; mandatory typed reasons; audited DUPLICATE-stamped reprints.
5. **The five-layer hide-first gating stack** — SchoolBuildScope → backend-less surface gate → ChainScope → capability wizard → RBAC longest-prefix, enforced identically in nav filtering and route guarding. Out-of-scope verticals (salon/restaurant/healthcare/white-label) are genuinely unreachable in the school build — nav AND deep links.
6. **Design-token discipline** — primitives→semantic→ColorScheme pipeline, zero hardcoded hex across 297 screens, web mirroring the same tokens as CSS variables, designed (not inverted) dark mode, 70-image golden suite. Visual design scored 7.0 — the product *looks* world-class.
7. **Honest async-state doctrine** — loading/error-retry/empty grammar on mobile; web's AsyncBoundary hierarchy (awaiting-backend / module-disabled / needs-filters / empty) that refuses to fabricate business data.
8. **Governed AI lane** — Adaptive Priority Feed with visible "Why" + factor breakdown + Dismiss/Mute, never auto-executes; no-free-chat Parent Insights with language catalog and PDF disclaimer; real AI cost/cap transparency.
9. **Flutter accessibility foundation** — theme-level 48dp touch targets with lint tests, WCAG-computed on-colors, free text scaling with only two sanctioned dense-grid clamps, Semantics in the shared-widget layer.
10. **Locked-not-hidden entitlement UX** with WhatsApp upgrade CTA — tuned exactly right for the Indian school market.

## Top Weaknesses

1. **Demo-ware embedded in live paths** — the single systemic defect behind most P0s: mock payment providers, fabricated fallbacks, hardcoded stats/dates/IDs ('inv_1', 'term_2', 'class-8a-p1', '12 Jun 2026', 'Ravi Kumar', 'Route 12', ₹5,000) shipping on certified surfaces.
2. **The web action layer does not exist** — zero business mutations in `web/src`; dead primary CTAs across every module; "1:1 parity" documentation claims falsified at capability level.
3. **Office money flows fail at the counter** — wrong-invoice posting, unresumable admissions, yesterday unreconcilable, cheque/DD amounts falling into no bucket, year-2 re-billing structurally absent.
4. **Trust-destroying honesty gaps** — fake payment success, fake bus ETA, "staging server" copy on the production login, settings toast claiming "saved" without a write, fabricated "Accepted" legal chips, AI stub replies labeled "Live inference".
5. **Persona dead ends** — parent PTM tile → Access Denied; student login nonexistent; principal's circular unreachable; Exams missing from the admin workspace catalog; librarian's fine flow → Access Denied.
6. **Consistency fractures at the edges** — three brand identities stacked; Appearance setting a no-op; three contradictory validation behaviors; free-text dates/targets beside the excellent AksharaDateField pattern; no file/photo upload anywhere in an app whose flows ask for documents.

---

## Confirmed P0 Issues (adversarially verified — production-blocking)

Every item below survived an independent refutation attempt. Ordered by severity of consequence.

### Money integrity

**P0-1 · Parent "Pay Now" completes a simulated payment and posts a REAL receipt** *(3 reviewers independently; verifiers judged it understated)*
`lib/features/parent/payment/parent_payment_provider.dart:104-163` — the live-reachable production flow is `submitMockPayment()`: client-fabricated `txn_` reference, no gateway, then success screen + receipt. In the shipped stub-mode default, the backend **posts a genuine finance collection, issues a numbered APS receipt, and clears the invoice — real dues extinguished with zero money moved**. No sandbox disclosure exists anywhere in the payment UI; `/parent/payment` is NOT in the backend-less surface gate. Maps to tracked owner gap P0-02 (gateway SDK), but the interim mitigation (gate the route or disclose offline-only) is absent. *This is simultaneously the #1 competitive battleground journey (incumbents' weakest flow) and Akshara's most dangerous one.*

**P0-2 · Fee counter can post a payment against the wrong student's invoice**
`lib/features/finance/finance_workflow_actions.dart:728-762` — the Record-collection dialog builds its invoice picker from ALL school invoices (first 200), preselects `journeyInvoice ?? 'inv_1' ?? invoices.first`, and labels carry **no student name**. Opened from student A's account, it prefills A's balance while targeting an arbitrary invoice; the verifier confirmed the student-context header *actively reassures* the cashier while the target is wrong, and students beyond the first 200 invoices cannot be collected against at all. Default-path money mis-posting in the highest-frequency cashier workflow.

**P0-3 · Admission funnel cannot be resumed or safely interleaved; a mock store sits in the live submit path**
Admissions continuity lives only in in-session "journey context" memory — a clerk cannot resume a half-done admission tomorrow or interleave two families today — and `MockAdmissionsWriteStore` participates in the live submit path. The front desk's core multi-day workflow has no persistent spine.

### Data honesty on live surfaces

**P0-4 · Admin Hub landing hero shows hardcoded fake stats as live data**
The first screen a principal sees every morning: "1,248 Students · 96% Attendance · ₹4.2L Collected today" — constants presented as live truth in production.

**P0-5 · Parent screens silently render fabricated demo data on load/error**
Fees, dashboard, attendance, payment and profile fall back to a fictional child ("Ravi Kumar · 8-A", "Present", "₹4,200 due") while loading or on API failure — a parent can see another (fictional) child's dues as their own, or "Present" for an absent child.

**P0-6 · Attendance correction dialog ships a hardcoded date and a canned excuse**
Correcting a late arrival prefills date "12 Jun 2026" and reason "Biometric sync error — student was present" as free text — corrections silently file against a wrong date with a fabricated excuse unless the teacher notices.

### Broken core journeys

**P0-7 · Teacher marks entry cannot record AB on the phone** *(top-priority module)*
The teacher-side marks field is digits-only with no absent affordance — the mandated "absent = AB, never zero" rule (correctly implemented in the exam-admin grid) is impossible in the teacher flow, pressuring 0-entry that corrupts exam data.

**P0-8 · The principal cannot send a circular from mobile**
The only broadcast compose screen (`BroadcastAdminScreen`) lives inside the orphaned "School Completion" hub with **zero inbound navigation links**, and no Communication module exists in the 25-destination admin nav. The single most common principal communication task is unreachable on the product's primary platform.

**P0-9 · AI FAB sits directly over the middle bottom-nav tab, hijacking taps**
`copilot_bottom_nav_ai_slot.dart:22-32` — the 56px FAB is painted over slot 3 of 5 in all three consumer shells: parent **Fees**, teacher **Teach** (gateway to Exams), student **Schedule**. Default-on for all mobile personas; goldens confirm the rendered overlap; icon-taps open the AI sheet instead of navigating. Verified: no center slot is ever reserved; refutation failed on every axis.

### Student persona collapse

**P0-10 · No student login path exists in either client** — the backend fully supports student-scope OTP login, but neither login screen exposes any student entry; the front door only understands "parent's mobile number".
**P0-11 · Student dashboard/exam schedule is seed-frozen** — on a real tenant the home screen shows "--" attendance beside a tab with real records, zero homework beside real homework, and can never show really-scheduled exams; no admit card exists student-side though staff generate hall tickets. Plus: no logout on a shared-device persona.
**P0-12 · Web student portal is structurally dead** — 6 of 9 pages request response shapes the backend never sends (permanent empty states), and homework cannot be submitted on web.

### The web platform (reconciled severity — see dissent section)

**P0-13 · The web action layer is absent: a read-only shell presenting enabled controls** *(6 reviewers independently; verifier split 1×P0 / 4×P1 — reconciled as P0 for web GA, P1 for the current Flutter-only pilot)*
The only POST in `web/src` is login/OTP. Dead enabled CTAs on every core workflow: "Collect fee", "Add student", "New lead", "Create exam", "Apply for leave", "Approve/Reject" (Approval Center), "Send". Worst cases are actively deceptive: Exam **"Save marks" executes `setEdits({})` — silently discarding everything a teacher typed**; teacher attendance rows are wired to `onRowClick={() => {}}`; parent "Pay now" sets `location.hash = ''`; ModuleSettingsPage shows "Settings saved" **without any write**; the Legal page hardcodes "Accepted" chips; `web/PARITY_TRACKER.md`'s "100% parity / live-wired" claim is false at capability level. The backend is NOT the blocker — the POST routes exist.

---

## The Web Reality Gap — board reconciliation (conflicting opinions challenged)

Six reviewers independently reported "web is read-only" as P0. Adversarial verification split: four verifiers downgraded to P1 because (a) the live pilot's certified production surface is the Flutter app, which carries every mutation, (b) the web lane is owner-frozen after a deliberately view-scoped cert and reaches users only as an isolated-tenant review demo, and (c) many pages disclose "once the backend is connected". One verifier upheld P0: the lane was *live-certified* (229/229), the parity documentation claims capability it doesn't have, and dead buttons render enabled and fail silently.

**Board position:** both are right at different horizons. Relative to today's Flutter-only pilot: **P1**. For any web GA, commercial launch, sales demo of the web surface, or any claim of desktop support: **hard P0**. Two actions are not deferrable regardless of horizon: (1) the input-destroying "Save marks" and the fabricated "Settings saved"/"Accepted" states must be fixed or removed immediately — deceptive affordances, not missing features; (2) `PARITY_TRACKER.md` must be corrected to state view-only reality.

**Also challenged and resolved:**
- *"Fabricated AI meeting summaries are saved to real records"* — **REFUTED.** The production write path is fail-closed (`saveSummary` throws before persistence); fabricated summaries can only reach an in-memory mock repo in demo builds. Residual P2: the production "Generate AI Summary" button fails with no user feedback.
- *"A 6-period teacher can mark only one class per session"* — **downgraded.** Attendance is restricted to the class teacher's own class, so the cross-class scenario cannot occur; the real defect (P1) is the *second session of the same class*, which locks behind a false "submitted" banner — silently missing afternoon attendance for schools running twice-daily marking.
- *"Homework photo attachment impossible"* — downgraded to P2 as an absent feature, but the board notes it compounds P1-33 (no file picker exists anywhere) — collectively this is why "WhatsApp wins".

---

## P1 Issues (must fix before scale/GA — 126 raw + 28 downgraded P0s, grouped)

**Honesty & demo-data leakage (the systemic theme)**
1. Production login copy leaks internals: "OTP is verified by the staging server", "use a registered demo-school phone number" *(4 reviewers)*
2. Dashboard filter chips are placebo controls on 8+ modules — wired to nothing *(3 reviewers)*
3. Pay CTAs hardcode installment `term_2` regardless of dues; receipt IDs fabricated client-side *(3 reviewers)*
4. Transport shows hardcoded "Bus is approximately 8 minutes away" + dead "Refresh ETA"
5. QR payment defaults to fabricated invoice `inv_1` and magic ₹5,000; fee-structure dialog prefills demo money and hardcodes a Tuition category
6. Teacher exam insight hardcodes "Unit Test — Mathematics"; attendance live-mode defaults to mock `class-8a-p1`; hardcoded "Route 12/08" transport filters; hardcoded FY year chips
7. Web pages assert false state: settings "saved" toast with no write; Legal "Accepted" chips; homework page claiming it "posts to the live endpoint"

**Exams & academics**
8. Exams module missing from the Admin Hub cards and mobile admin bottom nav — `schoolAdministration` workspace omits `AdminModule.exams`; the "A5 un-bury" fix landed only on the desktop rail *(2 reviewers, golden-confirmed)*
9. Exam creation: free-text date/time with stale prefills ("15 Mar 2026", "Room 8A"), raw enum labels ("unitTest"), one dialog per class-section-subject — dozens of manual creations per series
10. Marks "Save all" silently skips out-of-range rows without identifying failing students; "Publish results" to parents is one tap, no confirmation
11. Web marks entry: see P0-13 — input-destroying Save

**Navigation & IA**
12. Parent "PTM" More-sheet tile → Access Denied (More sheet bypasses SchoolBuildScope filtering) *(4 reviewers)*
13. "School Completion" orphan cluster: ~20 academic-ops destinations (class-teacher assignment, subject assignments, timetable automation, broadcast) with zero inbound links on mobile
14. Orphan routes: Multi-School Portfolio, Branches, Backup & Restore, AI Content, Homework Intelligence, fee-assignment
15. Admin bottom-nav is declaration-ordered — Marketing outranks SIS/Exams for a principal; single-module staff land on the generic Admin Hub (with the fake-stats hero) instead of their workspace dashboard
16. Cashier's Collections buried in finance sub-nav overflow; 14-tab finance strip mixes daily tools with executive/AI surfaces
17. Mobile/web vocabulary divergence for the same teacher tasks ("Classes/Teach" vs "Attendance/Homework/Exams"); two competing student-detail destinations; web role→module scoping diverges from Flutter
18. Franchise vertical (owner-decided OUT) is only chain-gated, not build-hidden — 4 roles hold its permission

**Forms & input integrity**
19. Leave forms (teacher + parent): free-text dates with decorative calendar icons, hidden validation, silent failure — while `AksharaDateField` exists as the sanctioned pattern
20. Homework targets classes and students by free-typed strings instead of roster pickers *(3 reviewers)*
21. No file/photo upload exists anywhere — "attachments"/"documents" are typed filename strings (homework, leave, SIS documents, student submissions)
22. Student address displayed but not editable anywhere; SIS profile edit uses unvalidated free-text for DOB/gender/class/section
23. Three contradictory "required field" behaviors across modules; dialogs lose all input on outside tap or failure; refunds/concessions require typing raw internal IDs
24. Admissions "View" silently submits a draft application; no application detail screen exists; fee handoff silently applies the FIRST fee structure when none was chosen *(2 reviewers — the dropdown's onSelected is never wired)*

**Money operations (beyond P0s)**
25. Yesterday cannot be reconciled anywhere — daily summary hardwired to CURRENT_DATE; mode split computes cash+UPI only, so cheque/DD/card fall into no bucket and figures don't tie
26. Money amounts on web rendered as bare strings — no ₹, no Indian grouping
27. Year-2 operations structurally impossible: promotion/reshuffle gated off, no re-billing path for continuing students; transport allocation never raises the transport fee demand; TC dues-pending failure is a dead-end snackbar
28. Hard pageSize caps with no pagination — a 2,000-student school can never see 90% of its registry (web registry 200, collections 200, library dialogs 20)

**AI trust**
29. `EdgeAiProvider` fabricates responses locally while labeled "Live inference (akshara-edge-v1)… Based on current school data" — the ONLY AI path for teacher/parent/student personas
30. Production-reachable `/intelligence` dev harness can publish hand-typed AI "guidance" to the real parent hub (publish toggle defaulted ON); Teacher Assistant writes a hardcoded `student_1` intervention to the live backend
31. Quick-action prompts silently discarded (copilot opens empty); stub replies visually identical to real AI ("read-only stub" string is the only signal); no generation dates on parent insight PDFs; web "Copilot" is a first-class sidebar item resolving to a brochure page

**Accessibility**
32. Parent OTP login (the product's front door): unassociated labels, no `AutofillHints.oneTimeCode`/SMS retrieval on mobile; six anonymous inputs rejecting pasted codes on web
33. Web DataTable rows/sort headers mouse-only — keyboard users cannot open records on 8+ core list pages; web dialogs have no focus trap/initial focus/restore
34. Light-theme warning/tertiary text fails AA (3.07–3.74:1) on the small chip/badge labels where it's used; input boundaries ~1.2:1 on both platforms
35. Theme governance: persona shells hard-force brightness (teachers locked dark, parents locked light) making the Appearance setting a no-op; three stacked brand identities; declared Roboto/RobotoMono never bundled (iOS renders a different typeface)

**Platform behavior**
36. All ~280 routes use NoTransitionPage — zero push animations, iOS back-swipe dead app-wide
37. Tablet renders persona dashboards as a ~480px column pinned left with a third of the canvas blank *(5 reviewers, golden-confirmed)*; intelligence dashboard broken half-width on phones
38. Pull-to-refresh on only 4 of 297 screens; no session-expiry handling on web (error wall with no path to login); web demo "Explore by role" reachable in live builds
39. Child switching exists only on parent Home — every other screen strands a two-kid parent; web parent portal has no child switcher at all
40. Communication: mass broadcast sends with no confirmation and free-text class targeting; parent cannot start a conversation with the class teacher; reply failures silent; WhatsApp absent from the broadcast pipeline despite an admin WhatsApp-provider setup screen; no parent-facing online admission form *(competitive table-stakes)*
41. Front office: no role below full schoolAdmin can issue certificates (hide-first collapses for the clerk persona); librarian fine flow routes to Access Denied; lead search absent; "Lead created successfully ()" shown on failure

## P2 Improvements (68 — themes)

Chart colors rotating hue between themes · raw Material colors in intelligence · no first-run guidance on a 14-module admin surface · web unknown-URL renders "parity in progress" instead of 404 · IA duplication (Academics/Examinations identical page) · list/filter state not URL-persisted · "Configure" sprawl across five destinations · internal vocabulary leaks ("School Completion", phase4/phase5, "AD-05", "FN-02") · rejection-reason dialog discards context · inert "open in new" affordances · bottom-nav labels wrapping · no reduced-motion/skip-link on web · chart text alternatives missing on web · Aadhaar hard-required with no alternative path · residual "coming soon" tiles · teacher notification bell routed to the parent route · attendance tally omitting half-day/excused · "Scan ISBN" opening a typing dialog · no visitor log · student report card rendering "Average: 0.0%" with zero data · out-of-scope verticals remaining fully wired behind one compile-time flag *(6 reviewers flagged as latent risk — routes, permissions, copilot copy)* · no UPI AutoPay/recurring mandate (nascent differentiator) · tablet canvas under-use in switcher/hub.

---

## Recommended Redesigns (in priority order)

1. **Demo-data eviction program** — one build-level boundary (extend the web `IS_DEMO` gate doctrine to Flutter): no mock provider, fabricated fallback, or hardcoded ID/date/amount reachable in live mode, enforced by a lint/test sweep. This single program clears P0-1's ceremony, P0-4, P0-5, P0-6 and a dozen P1s.
2. **Interim payment honesty** — until gateway SDK P0-02 lands: put `/parent/payment` behind the backend-less surface gate, or convert to a disclosed "record offline payment / pay at school" flow. Never a fake success ceremony.
3. **Fee counter redesign** — student-first collection: invoice picker scoped to the selected student, labels always carrying student name + class, no global first-200 list, no `inv_1` fallback.
4. **Admissions continuity spine** — persistent draft applications with an application detail screen, resumable/interleavable by design; remove `MockAdmissionsWriteStore` from the live path.
5. **Web action layer program** — wire the existing backend POST routes into the existing (excellent) ResourceList/AsyncBoundary chassis, starting with Approval Center, fee collection, attendance, marks. Immediate interim pass: disable or remove every dead CTA and fix the two deceptive states; correct PARITY_TRACKER.
6. **AI honesty pass** — remove or clearly label the simulated EdgeAI lane; unship the `/intelligence` harness and hardcoded-write Teacher Assistant from production; one naming scheme for AI surfaces.
7. **Student persona completion** — login entry (backend already supports it), live dashboard data spine, admit card, logout.
8. **Exam series creation** — one series definition fanning out to class-section-subjects; AksharaDateField everywhere; human enum labels; AB affordance in the teacher marks field.
9. **Theme governance** — one brand authority; Appearance setting honored (persona hues as accents with light+dark variants); bundle the declared fonts.
10. **Communication completion** — broadcast reachable from admin nav (Communication module), confirmation + real targeting, WhatsApp channel in the pipeline.
11. **Tablet layout pass** — responsive persona dashboards using the finance dashboard's proven phone→tablet restructuring as the template.
12. **File/photo upload primitive** — one shared picker/upload component adopted by homework, leave, SIS documents, and student submissions.

## Things That Should Never Change (board-protected)

1. The PersonaNav ≤4-tabs + More contract and its enforcing test.
2. Exception-first attendance marking and its draft-autosave/correction loop.
3. Marks-grid ergonomics: focus chaining, AB/ML/DB non-zero semantics, row_version guard, audited grace/moderation.
4. The amber-queued vs green-confirmed money ceremony; Resume/Discard that never prefills money; idempotency keys; typed-reason cancellations; day-close locks; DUPLICATE-stamped reprints.
5. The five-layer hide-first gating stack and its nav+route dual enforcement.
6. The token pipeline, zero-hex discipline, designed dark mode, and the golden suite (extend with production theming — the goldens currently certify the Stitch-forced appearance).
7. The honest-state doctrine on both platforms (fix the wording, keep the refusal to fabricate).
8. Adaptive Priority Feed's explainability contract (Why + factors + Dismiss/Mute, never auto-execute); no-free-chat Parent Insights; fail-closed AI economics.
9. 48dp theme-level touch targets + lint tests; free text scaling with only the two sanctioned clamps; Semantics in the shared-widget layer.
10. Parent phone→OTP login model (students never need a phone); locked-not-hidden entitlements with WhatsApp CTA; warn-only duplicate-phone lead check; fail-closed TC dues gate.
11. Web: deep-linkable parametric routes, AsyncBoundary hierarchy, entitlement-aware error mapping, demo-gated RoleSwitcher, documented-port widget pattern.

## Competitive Position

Researched: Teachmint, Fedena, Entab CampusCare, MyClassboard, NextERP. The market's parent apps are its weakest surface (Entab ~3.3★/123k, MyClassboard iOS ~2.5★, Fedena "non-intuitive", Teachmint discontinued its fee module). **Akshara's UX architecture is ahead of every incumbent researched** — persona shells, attendance workflow, dark parity, state grammar. But Akshara currently loses exactly where the Indian buying decision is made: **money and messaging** — the parent payment journey is simulated (P0-1), WhatsApp is absent from the broadcast pipeline, and there is no online admission form. Fix the money/messaging spine and Akshara plausibly ships the best parent experience in the segment; UPI AutoPay mandates are an open differentiator no incumbent owns well.

## Path to Certification

| Gate | Required | Unlocks |
|---|---|---|
| **Gate 1 — Pilot trust** | P0-1…P0-9 (money integrity, demo-data eviction from live paths, circular reachability, AB entry, FAB relocation) | CERTIFIED — Moderate Improvements Required (mobile-only pilot) |
| **Gate 2 — Persona completeness** | P0-10…P0-12 (student access + data spine) + P1 groups: forms integrity, exams admin nav, accessibility front door, child switcher | CERTIFIED — Minor Improvements Recommended (mobile GA) |
| **Gate 3 — Web GA** | P0-13 (action layer) + web P1 groups (keyboard operability, pagination, session expiry, honest CTAs) | Full-platform certification |

**Certification will be re-evaluated against evidence, not claims — per this project's own Product Reality Audit standard, no prior certificate (including the 229/229 web route cert) is accepted as evidence of user-experience completeness.**

---

*Method note: findings without file:line or screenshot evidence were discarded; every P0 claim survived (or was corrected by) an independent adversarial verification pass with instructions to refute. One finding was refuted and removed; 29 were re-graded. Severity definitions: P0 = blocks/damages a core daily workflow or would embarrass in a sales demo; P1 = significant friction on a real workflow; P2 = polish/missed opportunity.*
