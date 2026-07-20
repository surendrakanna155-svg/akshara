# AKSHARA ERP — CONSTITUTION-ALIGNED MASTER ROADMAP

**Status:** 🟢 **THE SINGLE AUTHORITATIVE ROADMAP** going forward.
**Supreme authority:** [`docs/owner/AKSHARA_MASTER_PRODUCT_CONSTITUTION_v2.0.md`](../owner/AKSHARA_MASTER_PRODUCT_CONSTITUTION_v2.0.md) (the Product Constitution). Where this roadmap and the Constitution conflict, the Constitution wins.
**Author:** Opus 4.8 · **Date:** 2026-07-20 · **Method:** built from a fresh, evidence-based repository audit (not by continuing the prior roadmap blindly).
**Supersedes as the forward plan:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) and every prior roadmap. Those remain valid as **historical + traceability sources**; nothing in them is discarded — §APPENDIX A maps every open item into a wave here so nothing is lost.
**Governance:** every wave is **EOS-gated** (per `CLAUDE.md` / the Engineering Constitution). *Implementation-complete ≠ Production-certified.* No wave is "done" without an EOS PASS; production certification (🟩) is granted only at the final certification wave.

> **This document is a roadmap, not an implementation guide, and not code.** It defines direction, sequencing, dependencies, risks and completion/certification/production criteria. Per-item implementation detail lives in the cited source registers (PRA register, PRC tracker, SOP spec, owner queue), which already carry `file:line` evidence and per-item done-when. This roadmap orchestrates them into one Constitution-aligned plan.

---

## 0. HOW THIS ROADMAP WAS BUILT (audit method)

The Constitution (Part 1, Part 14) requires: *inspect the existing implementation first; reuse and extend before replacing; avoid duplicate systems; base decisions on the current code, not on memory, chat history, docs, or roadmap percentages.* This roadmap was produced exactly that way:

1. The entire Constitution (16 parts) was read and internalized.
2. The repository was audited from **current code** across five lanes in parallel — backend (`supabase/functions`, 772 TS files, 232 tables), Flutter mobile (`lib`, 1,739 files), web (`web/src`, 229 routes), curriculum/KIE/QIE (`curriculum/`), and the full roadmap/execution/certification doc corpus.
3. Findings were cross-checked against the frozen **Product Reality Audit (PRA)** register (117 code-verified gaps) and the **unpushed PRA-remediation** branch.
4. The old roadmap's every open/deferred/pending item was recovered and mapped forward (§APPENDIX A).

**Governing rules for all execution under this roadmap (from the Constitution + owner queue Golden Rule):**
- **Current source code is the authority** — never memory, chat history, roadmap percentages, or prior certifications. Prior "certified" claims are treated as **void until re-verified on the converged trunk** (the PRA proved 24 P0s hid inside "certified" modules).
- **Inspect before change; extend before replace; never create a duplicate system.** If a capability already exists, stop — do not rebuild it.
- **Nothing is lost.** No recovered item is deleted, merged, re-scoped or silently dropped without a recorded justification (§APPENDIX C).
- **EOS gate per wave/commit.** CONDITIONAL PASS only with P1s tracked; BLOCKED = fix before advancing.

---

## 1. RECOMMENDATION ON THE CONSTITUTION'S LOCATION

**Recommendation: keep it where it is — `docs/owner/AKSHARA_MASTER_PRODUCT_CONSTITUTION_v2.0.md` — do not move it.**

Rationale: `docs/owner/` is already the semantic home for the two highest-authority owner-authored documents (the Constitution and the Owner Future-Platform-Ideas Queue). It correctly signals *ownership and supreme authority*, and co-locates the Constitution with the owner reminder queue it governs. A move to `docs/constitution/` would provide no functional benefit and would break inbound references across the doc corpus, contradicting the Constitution's own **backward-compatibility** principle (Part 14/16). If a dedicated directory is ever desired for discoverability, prefer a **pointer file** (`docs/constitution/README.md` → the owner path) over relocating the source of truth. This roadmap treats the `docs/owner/` copy as canonical.

---

## 2. AUDIT VERDICT — WHERE AKSHARA ACTUALLY IS

**One sentence:** the *engineering* is genuinely strong and mostly real; the *product* is incomplete in nameable, concentrated ways; and the biggest problem is not in any module — it is that **the real product is scattered across three divergent, unmerged git branches, so no single trustworthy trunk exists today.**

### 2.1 What is genuinely strong (preserve — do not rebuild)
Per the Constitution's "preserve production-ready work / reuse over duplication":
- **Backend architecture** — modular Deno monolith; **DB-enforced tenant isolation via a non-bypass `erp_tenant` role + RLS** (212 tables RLS-enabled, 315 policies) with a deploy-time role assertion; **unified audit** (one catalog, one writer, domain-events outbox, 403-denial sink); coherent **single identity model** (`organizations→schools→users`) and **single canonical student model** (`students` + 1:1 `student_profiles`); near-zero TODO/FIXME debt.
- **Mobile client** — Riverpod + go_router (308 routes); a real **offline-sync engine** (SQLCipher store, outbox, conflict resolver, idempotency, draft autosave); a mature **design system** (22 theme-token files + 71 shared `Akshara*` components); a first-class **USER→ROLE→WORKSPACE→TASK** workspace model (exactly the Constitution's Part 4 IA); ~3,420 tests.
- **Identity/auth engine** — server-side RBAC (not UI-only), live session-revoke chokepoint, per-school RLS with no cross-tenant IDOR found in the PRA.
- **KIE Knowledge Foundation v1.4** — **2,023 certified concepts, frozen and immutable** (fingerprint `e3a146f3…`); a clean, deterministic-first, well-governed knowledge lane, fully isolated from the ERP.

### 2.2 The reality gaps (what this roadmap must close)
1. **VCS fragmentation (the #1 structural risk).** `main`/`production` are stale. Three divergent unmerged lines carry different real work:
   - `feature/qp-content-readiness` *(current)* — full ERP + QIE + web; its roadmap doc still lists P4–P7 as "pending."
   - `feature/erp-pra-remediation` — current **+14 clean commits** fixing the 117 PRA gaps (fast-forwardable).
   - `feature/data-reliability-platform` — **diverged** (136 ahead / 96 behind); already ran red-team Rounds 1–7, P5 security fixes, auth-table RLS lockdown (migration `20260897`, live-certified), web-gap APIs, a 14-dimension security cert. **This is the branch deployed to the live pilot.**
   - Migration series are split across lanes (`…0876` / `…0877–0897` / `…0900000015–019`). No integrated trunk contains PRA fixes **+** red-team/security **+** QIE. This violates the Constitution's "one connected platform / single source of truth / backward compatibility" **at the repository level**, and makes every status claim per-branch and untrustworthy.
2. **QIE data-loss risk (P0 continuity).** The newest, highest-value QIE work — the Decision-C split-lane (`…/kie/qie/knowledge/` and `…/kie/qie/factory/`) — exists **only on local disk**: one dir is *silently gitignored* (a data-pattern accidentally matches a code dir), the other is untracked. The **KIE v1.4 freeze package and `kie.db` are also local-only**, so the frozen foundation is **not reproducible from git alone**. A stray `git clean` in this shared worktree loses it.
3. **Product-reality gaps (117 PRA items) — remediated-but-unmerged.** The engines are well built; what is broken is **lifecycle (nothing can un-do an onboarding), shadow/duplicate implementations where the ungoverned one wins, demo scaffolding load-bearing in production, and asserted-but-fake integrations.** The `erp-pra-remediation` branch fixed all 24 P0s + most P1s; a clearly-tracked tail remains (owner/hardware/large-build).
4. **Stubbed-but-looks-done surfaces (verified in current-branch code):** online payments (Razorpay stub-mode default, no SDK); education/homework "AI generation" persists placeholder text as real homework; copilot silently degrades to a canned `akshara-stub`; the **web app has no write layer at all** (a read-only viewer with a fake "Settings saved" toast); staff GPS/face + transport GPS tracking are device-placeholder.
5. **Structural weaknesses vs the Constitution:** auth/RBAC enforced **per-handler by convention** (no central chokepoint — a forgotten guard is an open route; the QW4-INV-OR OR→AND collapse bug shipped before); **AI-module sprawl** (≥11 backend + 3 mobile surfaces vs the Constitution's "intelligence is one platform capability, not isolated modules"); 3 `service_role` RLS-bypass paths; coarse scope-only RBAC on search/payment/hostel; `student_entities` read-model drift; **two parallel "Question Intelligence" systems** (curriculum QIE + ERP-native education); out-of-scope **verticals** (salon/restaurant/healthcare/accommodation) still shipped and maintained against the North Star.
6. **Certification trust is broken.** The PRA found P0s inside QW1–8/Gap-Sweep "certified" modules ⇒ prior certs are not production evidence. This *is* the Constitution's Part 15 principle: *certification = earned confidence; implementation-complete ≠ production-ready.*

---

## 3. STANDING CONSTRAINTS (frozen — honored by every wave)

These are non-negotiable inputs; no wave may violate them without a recorded owner decision:
- **KIE Knowledge Foundation v1.4 is IMMUTABLE** (2,023 concepts, `e3a146f3…`). QIE builds on the freeze; **no discovery reopening and no foundation mutation** unless new external source material is deliberately introduced (which becomes a new version, leaving v1.4 intact).
- **Student Identity Architecture (frozen):** Public Student ID `<SCHOOL_CODE>-<NNNN>`; UUID is the only PK; student phone never required; student login = OTP-to-parent.
- **Attendance-Auth (frozen):** staff attendance = GPS geofence + anti-mock + live-camera face; **never** device biometric/PIN (OS biometric is app-login only).
- **English-first (frozen):** no full app localization; only parent-facing comms localize via a deterministic catalog.
- **North-Star scope exclusions:** salon/restaurant/healthcare/accommodation/franchise/white-label and live-GPS/RFID/QR boarding and student Face-ID are **out** (Phase-2/Future/never per owner decisions).
- **Pending owner decisions are NOT pre-assumed** — notably **D1 (Smart OMR)**, which would reverse the frozen Assessment decision, and **D2 (SOP placement)**. Items depending on them are parked at 👤 (§7).

---

## 4. THE WAVE MODEL (Constitution-aligned)

The waves are organized around the Constitution's own architecture (Identity → School Operating Platform → Student360/QIE/Assessment → Dynamic Platform → Search → Intelligence → Enterprise → Design/UX → Engineering → Quality), sequenced by dependency and risk. Legend for status: ✅ done · 🔶 built, hardening · 🟩 production-certified (final wave only) · ⚪ pending · 👤 owner-gated · ⏸ deferred · 🔮 future.

| Wave | Title | Constitution anchor | Gate |
|---|---|---|---|
| **W0** | Lane Convergence & Repository Integrity | Part 14/16 (one platform, single source of truth, backward-compat) | RELEASE/DOCS |
| **W1** | Re-baseline Reality Audit on the Converged Trunk | Part 15 (earned confidence; void prior certs) | EOS DOCS |
| **W2** | Identity, Lifecycle & Governance | Part 2/3 | SECURITY+MIGRATION |
| **W3** | Money & Data Integrity | Part 15 (data integrity) | RELIABILITY |
| **W4** | Core School-Operations Completeness | Part 5 (can a real school operate entirely inside Akshara?) | FEATURE+EOS |
| **W5** | Assessment · Student360 · QIE Integration — **entry wave into PROGRAM EIP** | Part 6/7/8 | FEATURE+AI |
| **EIP** | **Educational Intelligence Platform** (14 workstreams — the "educational brain") — *spans W5→post-GA; parallel to ERP waves* | Part 6/7/8/11 | FEATURE+AI+CERT |
| **W6** | Dynamic Platform Services & Provider Abstraction | Part 9/10 + owner queue | FEATURE+ARCH |
| **W7** | Platform Intelligence Consolidation | Part 11 | AI |
| **W8** | Cross-Platform Cohesion (Web parity · A11y · i18n · Design) | Part 4/13 | UX+CI |
| **W9** | Enterprise, Multi-School & Data Ownership | Part 12 | FEATURE+SECURITY |
| **W10** | Engineering Hardening (central RBAC · observability · scale · CI) | Part 14 | ARCH+OPS |
| **W11** | Security & Reliability Certification (Red Team → fixes → live) | Part 14/15 | RED-TEAM+OPS |
| **W12** | Final Validation · Pilot · Beta Schools | Part 15/16 | VAL/PILOT/BETA |
| **W13** | Production Certification & GA | Part 15/16 | GA (only 🟩 grant) |
| **K** | Knowledge Lane (QIE on frozen v1.4) — *parallel, never blocks ERP* | Part 7 | K-gates |

**Execution order:** **W0 → W1** are hard prerequisites (nothing is trustworthy until they complete). Then **W2 · W3 · W4** are the product-correctness core and run largely in parallel under disjoint file ownership (much of them is *verify-the-merged-fix*, not new build). **W5–W10** are the Constitution build-out. **W11 → W12 → W13** are the strictly-sequential certification runway. **K** and the acquisition lane run in parallel throughout and never gate the ERP.

---

## 5. THE WAVES IN DETAIL

Each wave carries the full template the owner requested: **Why · Outcome · Inspect-first · Dependencies · Risks · Completion criteria · Certification criteria · Production-readiness criteria.** Recovered items are listed with their source IDs so nothing is lost.

---

### W0 — Lane Convergence & Repository Integrity 🔴 CRITICAL (gates everything)

- **Why (Constitution Part 14/16):** the platform must be "one connected system / single source of truth," and evolution must "preserve existing value / backward compatibility." Today that is violated at the VCS level: three divergent branches, stale `main`/`production`, split migration series, and the highest-value QIE work uncommitted. No later wave can be trusted until there is one integrated trunk.
- **Outcome:** ONE canonical, integrated trunk that contains the PRA fixes + the data-reliability/red-team/security work + the QIE lane; a single reconciled migration head; `main`/`production` re-baselined to reflect reality; the QIE Decision-C work safely committed and the frozen foundation backed up off-repo.
- **Inspect first:** `git worktree list`; the merge-base/divergence between `qp-content-readiness`, `erp-pra-remediation` (ff, +14), `data-reliability-platform` (diverged 136/96); the four `worktree-agent-*` branches (450–463 ahead — triage: salvage or prune); the exact deployed head on the VPS (what is actually live); `curriculum/.gitignore:54` (the code-vs-data pattern bug).
- **Sub-waves:**
  - **W0.1 — QIE preservation (do first; freeze-safe).** Commit the uncommitted Decision-C **code** (`…/kie/qie/knowledge/`, `…/kie/qie/factory/`); fix the `.gitignore` so the *code* dir is tracked while *data* stays ignored; back up the frozen `kie.db` / v1.4 package **off-repo** (owner-approved location). *This mutates no foundation content — it protects it.* Recovers **QIE-RISK-1/2/3** (QieAudit).
  - **W0.2 — Trunk reconciliation.** Fast-forward-merge `erp-pra-remediation`; then perform a real reconciliation merge of `data-reliability-platform` (resolve the divergence — red-team/security migrations vs PRA-fix migrations); reconcile the migration series into one monotonic head; declare the integrated branch canonical.
  - **W0.3 — Baseline + prune.** Re-point `main`/`production` (or a fresh `release/*`) at the converged, re-verified trunk; triage/prune stale `worktree-agent-*` and abandoned branches with a recorded decision each.
- **Dependencies:** none (this is the entry gate). Needs owner input only for the off-repo backup location and confirmation of the deployed head.
- **Risks:** the DRP↔PRA divergence merge is non-trivial (overlapping backend files, two migration series) → conflict/regression risk; a bad merge could resurrect a fixed P0 or drop a security fix. Mitigation: merge under isolation (worktree), full regression (deno + flutter + goldens) before declaring canonical, and a per-P0 spot re-verification.
- **Completion criteria:** one branch builds green (deno `deno check` + tests, `flutter analyze` + tests, goldens), contains every PRA fix + every DRP security/red-team fix + the QIE lane, with a single migration head; `main`/`production` reflect it; QIE code committed and foundation backed up.
- **Certification criteria:** EOS RELEASE-scope PASS on the converged trunk; a documented "convergence certificate" listing every merged lane, the reconciled migration head, and a per-P0 re-verification table.
- **Production-readiness criteria:** repo head == intended deployed head; a clean redeploy from the converged trunk passes the existing `production_launch_verify.sh` smoke on the pilot.

---

### W1 — Re-baseline Reality Audit on the Converged Trunk 🔴 CRITICAL

- **Why (Constitution Part 15):** certification is *earned confidence*, and the PRA proved prior certs hid P0s. After convergence the whole tree is new; every status must be re-established once, on the single trunk, replacing fractured per-branch tracking.
- **Outcome:** ONE evidence-graded status ledger (LIVE / LOCAL-LOGIC / CONTRACT / RENDER-MOCK / MISSING per capability) for the converged trunk; a deduped reconciliation of **PRA (remediated)** vs **PRC (planned, 502 reqs)** vs any new findings — so W2–W10 never re-audit a fixed path or skip a real one.
- **Inspect first:** re-run the PRA P0/P1 spot-checks against the converged code (are the shadow routes gone? is payment fail-closed? does revoke exist?); diff the PRC-A 148-capability list and PRC-B 12 invariant categories against what the PRA remediation already closed.
- **Dependencies:** W0.
- **Risks:** re-audit fatigue / re-doing settled work → mitigate by *verify-first* (the PRA remediation log is the map of what's already fixed; only re-verify, don't re-build).
- **Completion criteria:** a single status ledger committed; PRC scope deduped against PRA remediation with an explicit "already-closed / still-open / new" disposition per requirement.
- **Certification criteria:** EOS DOCS PASS; no capability claimed above its evidence grade.
- **Production-readiness criteria:** n/a (this is an audit/tracking wave; it gates the build waves).

---

### W2 — Identity, Lifecycle & Governance 🔴 (Constitution Part 2/3)

- **Why:** the Constitution makes identity **the foundation** — one persistent platform identity, Mobile→OTP→auto-resolution, least-privilege, full auditability, and lifecycle continuity (a membership must be revocable; a guardian link removable; history preserved). The PRA's #1 theme is that *the lifecycle engine to un-do onboarding does not exist*.
- **Outcome:** access can be revoked; guardians can be added/removed; multi-school users get a real selector (never a silent `.limit(1)`); OTP uses a CSPRNG; every identity event is audited with creator≠approver ownership fields; change-phone preserves the Identity-Permanence invariant.
- **Inspect first:** most of this is already **fixed on `erp-pra-remediation` S2** (revoke, guardian add/remove, refresh child-set, officeStaff permissions, `/auth/context/switch` chokepoint, `permissions_version`) — so this wave is **verify-merged (W0) + finish the tail**, not rebuild. Confirm against `session_validation.ts`, `auth_context.ts`, `permission_resolver.ts`.
- **Recovered items:** PRA-P0-01; PRA-P1-01…07, P2-34; SOP-ID-1 ✅ / ID-2 / ID-3 / ID-4 / ID-5; P1-CODE-4 (change-phone, PLAT-4, append-only ledger, admission# dedup, cross-tenant SECURITY DEFINER authz); Admissions SoD (P0-13).
- **Dependencies:** W0, W1. **Owner-gated:** PLAT-0 identity cluster; full multi-school switcher scope (D2).
- **Risks:** identity changes touch auth/RLS everywhere → high blast radius; a wrong revoke sweep could lock out real users. Mitigate with the existing session-chokepoint tests + red-team forced-auth suite.
- **Completion:** revoke + guardian lifecycle + multi-school selector + CSPRNG OTP + identity audit events all merged and green; frozen Student Identity Architecture honored.
- **Certification:** EOS SECURITY+MIGRATION PASS; identity-event audit coverage proven; no bypass of the session chokepoint.
- **Production-readiness:** a terminated staff member loses access next request, live; a multi-school parent selects a school; OTP is unpredictable — all verified on the pilot.

---

### W3 — Money & Data Integrity 🔴 (Constitution Part 15)

- **Why:** "the platform must protect the correctness, consistency, completeness and traceability of institutional data" and never show materially wrong numbers. The PRA found the money loop broken in several places (fabricated receipts, unguarded refund/cancel races, fake payroll→Finance posting).
- **Outcome:** every rupee has a verifiable trail; no double-apply of a delta; online payments either persist a real receipt or fail closed; concessions/refunds/cheque-bounce/library/transport all reach the ledger truthfully.
- **Inspect first:** largely **fixed on `erp-pra-remediation` S1/S7** (payment fail-closed both ends, refund/cancel status-guards mirroring `finance_fee_reductions_repository.ts:421`, cheque register, gapless receipt series, real payroll→Finance posting, hard-negative-stock). Verify-merged + finish the owner/large-build tail. Confirm the recurring race pattern (`AND status='<pre>'` + throw-on-0-rows) is applied at every terminal money write.
- **Recovered items:** PRA-P0-02/03/04/24; P1-08/09/10/11/37/38; P2-10/16/30-with-P1-54; the new race findings N-15/M-1, N-16/M-2.
- **Dependencies:** W0, W1. **Owner-gated:** **P0-02 real payment-gateway SDK** (external paid provider — choose Razorpay/… + credentials); **P1-35 statutory payroll** (large compliance build — PF/ESI/PT/TDS, needs a statutory-config source); P1-CODE-6 cross-module finance posting scope.
- **Risks:** payment SDK integration is the single highest-stakes external dependency; statutory payroll is a large per-state build. Both are owner/scheduling gated — the client is already fail-closed so no money is silently mishandled meanwhile.
- **Completion:** all money-integrity P0/P1 verified-merged; the race pattern is universal at terminal writes; gateway SDK integrated (post owner decision) or explicitly fail-closed and labelled.
- **Certification:** EOS RELIABILITY PASS; a full financial-flow regression (collect → refund → cancel → cheque-bounce → reconcile) with concurrency; live money-moving E2E on the pilot.
- **Production-readiness:** a real online payment persists a verified receipt; no concurrent double-apply reproducible; statements reconcile across ledger/summary/export.

---

### W4 — Core School-Operations Completeness 🟠 (Constitution Part 5)

- **Why:** the Constitution's central test — *"can a real school complete its full daily operation entirely inside Akshara without Excel, WhatsApp, paper, duplicate entry, or disconnected handoffs?"* This wave = **PRC Wave A (148 capabilities / 15 domains)** ∪ the operational PRA P0/P1s ∪ the old enhancement-backlog tail, deduped.
- **Outcome:** timetable reaches every app; exam results publish; annual promotion works; comms actually deliver (DLT-compliant, multi-channel, route-scoped); transport assigns vehicles + raises fees; certificates carry board-mandated fields + void/reprint; library has accession + lost-book; inventory/asset registers are writable; HR/payroll run with LOP and statutory depth.
- **Inspect first:** timetable/exams/promotion/comms/transport are mostly **fixed on `erp-pra-remediation` S3/S5/S6/S7** — verify-merged. The PRC-A domains (complaint/ticket, gate-pass, health/infirmary, certificate-request-desk, syllabus progress, fee-structure bulk assign, storage quota, AI credit wallet, SaaS plan-limit enforcement, staff workload) are **still to build/complete** — this is the bulk of new operational work.
- **Recovered items:** PRA operational P0s (05,06,07,08,09,10,11,13,14,15,16,17,18,19,20,22,23) + P1s (12–50 operational subset); **PRC-A-001…148**; old C-wave tail (C3/C6/HWK-1); tracked deploy toggles (`ACADEMIC_API_ENABLED`+`ACADEMIC_OPERATIONS_API_ENABLED`, DLT SMS templates); device features **P0-15 real GPS/face adapters** and transport GPS (hardware/Phase-2).
- **Dependencies:** W0–W3. **Owner-gated:** P1-CODE-7 Hostel scope · P1-CODE-8 Alumni scope · P1-41 library accession scheme · P0-15 device-build scope · P1-34 leave accrual · complaint/health/gate-pass module scopes (PRC-A owner sign-offs).
- **Risks:** largest wave; breadth-vs-depth trap (PRC's own law: never confuse feature breadth with correctness); cross-module dependency traps (a dashboard metric is only correct if its whole data lifecycle is). Mitigate with PRC-A's 13-step method + dependency rule.
- **Completion:** every PRC-A capability classified with evidence and every verified gap fixed + regression-tested; a real school can run a full day per persona with no external tool.
- **Certification:** EOS FEATURE PASS per domain; PRC-A exit (full affected regression + EOS) — **feeds W11/W12**.
- **Production-readiness:** end-to-end journeys proven on the pilot (admission→enrolment→attendance→assessment→report→comms→certificate) with real data.

---

### W5 — Assessment · Student360 · QIE Integration 🟡 (Constitution Part 6/7/8)

- **Why:** assessment must feed learning intelligence; Student360 is *the* educational intelligence layer; QIE is the "educational brain." The Constitution demands these be *one connected system*, and forbids *duplicate systems* — but two "Question Intelligence" implementations exist today (curriculum QIE + ERP-native `education`).
- **Outcome:** the ERP question bank has real content (not placeholder generation); the certified QIE bank can flow into the ERP as `ai_candidate` provenance through existing review/approval governance (owner-gated promotion); item-analysis/question-heatmap activates the dormant `edu_student_item_responses` spine; Student360 gains repeated-weakness concept history; assessment results enrich Student360/Teacher/Parent intelligence.
- **Inspect first:** the **integration seam already exists but terminates in the K-lane** (`kie/qie/qp_bridge.py`); the ERP-native bank has an `ai_candidate` provenance slot ready. Reconcile the two systems per "no duplicate systems": the curriculum QIE is the *generator/certifier*; the ERP `education` module is the *bank/paper governance surface* — wire them, do not merge or fork. Honor the **KIE v1.4 freeze** and "no prod promotion of curriculum/questions without owner OK."
- **Recovered items:** SOP-F4 (extend evaluation workflow) / F5 (question heatmap — activate dormant spine) / F6 (timed online exams) / F7 (repeated-weakness in Student360); education real-content generation (replace `generateStubHomeworkContent`/`generateStubRemark`); PRA-P1-26/27/28/29 (QP module reachability, empty bank, marks-short publish, answer-key leak); K-3 promotion bridge (owner-timed).
- **Dependencies:** W0, W4; **K-lane** (frozen v1.4). **Owner-gated:** **D1 Smart OMR** (SOP-F1/F2/F3 — reverses frozen Assessment decision; do NOT build until confirmed); K-3 promotion timing; Assessment Intelligence Platform build timing.
- **Risks:** reviving OMR (D1) contradicts a frozen decision — parked until owner confirms; QIE qualitative lane cannot be deterministically certified (structural — keep the OCR/answer-key grounding lane); promotion must not import unverified content into live assessment.
- **Completion:** the two QI systems are reconciled (one generator, one governance surface, one seam); real bank content; heatmap live; Student360 weak-concept live.
- **Certification:** EOS FEATURE+AI PASS; QIE→ERP promotion runs additively with certified invariants intact and an explicit EOS gate on the seam (none exists today).
- **Production-readiness:** a teacher generates a governed paper from real bank content; item-analysis reflects real responses; owner-approved before any live promotion.

> **W5 is the *entry wave* into the full Educational Intelligence Platform.** The complete educational-intelligence vision — Exam DNA, Blueprint/Planning, Verification Pipeline, Daily Practice, Certified Solution Intelligence, Learning Evidence, and the Student/Teacher/Parent/Principal/Revision/Reasoning/Concept intelligence layers — is the dedicated **PROGRAM EIP** below (§5.5). W5 delivers the ERP-side seams (bank content, item-analysis, QIE promotion) that EIP builds on.

---

### W6 — Dynamic Platform Services & Provider Abstraction 🟡 (Constitution Part 9/10 + owner queue)

- **Why:** the Constitution wants *reusable platform services* (approvals, search, filters, certificates, saved views, notifications, exports) and *configuration as a platform capability* — and the owner's 40-item queue is almost entirely **provider-abstraction layers** (payment, OCR, SMS/OTP, maps, secrets vault, feature flags, date/money rules engines, backup storage, eSign, job-queue, cron, translation…). "Extend existing engines; never fork a parallel module."
- **Outcome:** dynamic approval engine (configurable types/routing/multi-level, keep SoD); dynamic certificate builder (templates + custom types); smart saved/reusable filters + advanced search across modules and **web parity**; provider-abstraction layers so external vendors are swappable behind clean seams; the secret vault actually works (fix P1-54 **and** its base64 encryption P2-30 together).
- **Inspect first:** these are mostly **extend, not build** — `approval_orchestrator` (real, fixed enum → make dynamic), certificate engine (4 fixed types → template builder), Universal Search (6/12 categories, Flutter-only → breadth + web parity + saved searches), the vault (dead code → grant + real encryption). Reconcile each owner-queue item against current code first (owner Golden Rule) — many already exist partially.
- **Recovered items:** SOP-F8/F9/F10/F11/F12; owner queue Items 6–40 (provider layers), each reconciled against current code before any build; PRA-P1-53 (audit-log read UI), P1-54+P2-30 (vault), P1-55 (tenant data export), P1-50 (email/report scheduling), P1-49 (real report exports); saved-view/filter primitives.
- **Dependencies:** W0, W2 (RBAC), W3 (money rules engine ties to finance). **Owner-gated:** D2 (SOP placement); each owner-queue item needs the Golden-Rule reconciliation → owner approval before build.
- **Risks:** the owner queue is a *reminder*, not a backlog — building without reconciliation risks duplicating existing capability (explicitly forbidden). Mitigate: every item passes Current-Code → Evidence → Reconciliation → Owner-Approval before implementation.
- **Completion:** dynamic approval/certificate/filter/search extensions shipped on existing engines with zero duplicate modules; provider seams in place where reconciliation proved a gap.
- **Certification:** EOS FEATURE+ARCH PASS; vault + encryption shipped together (never a live secret-exposure window).
- **Production-readiness:** a school configures an approval flow / certificate template / saved search and it works live on web + mobile with consistent behavior.

---

### W7 — Platform Intelligence Consolidation 🟡 (Constitution Part 11)

- **Why:** "intelligence is a platform capability, not a collection of independent AI tools" and must be evidence-driven, explainable, human-centered, governed, and cost-bounded. Today it is real but **sprawled** across ≥11 backend + 3 mobile surfaces, can silently degrade to a canned stub, and has one governance hole (embeddings bypass the gateway).
- **Outcome:** one governed AI gateway is the *sole* model path (extend the existing compiler-enforced gateway); the ≥11 backend + 3 mobile AI surfaces are consolidated/rationalized behind it; embeddings route through the gateway (P1-46); AI is explainable + cost-capped; deterministic results are never delegated to a model; truth-in-naming (deterministic "Intelligence" → "Analytics", AI-6).
- **Inspect first:** the W2 adaptive-AI work is **built + partially certified** (W1 CERTIFIED; W2 🔶 hardening) — this wave = finish the hardening loop + consolidate, not restart. The gateway already exists and is compiler-enforced for `callClaude`; extend that boundary to embeddings and the copilot/adaptive_ai/core-ai surfaces.
- **Recovered items:** P3-AI-2 tail (W2.1 briefs, W2.7 ops worklists, W2.8 pgvector, W2.9 naming), P3-AI-3 hardening loop, PRA-P1-46 (embeddings), P2-21 (domain-gate ordering), copilot stub honesty; deploy of the undeployed AI migrations (`20260867`+/`20260873`) — sequencing guard vs the W2 release flag.
- **Dependencies:** W0 (migrations converged/deployed), W1. Cross-deps from the AI blueprint (nightly jobs need the scheduling rail; homework intelligence needs real homework content from W5).
- **Risks:** silent degradation to `akshara-stub` is env/quota-dependent, not code-state — must be surfaced honestly; consolidation could regress a working persona feed. Mitigate with the standing AI test assets (injection corpus, determinism validator, isolation probes, cost-regression, fallback drills).
- **Completion:** one gateway is the sole model + embedding path; surfaces consolidated; naming corrected; hardening loop exits (repeated audits find no meaningful issues).
- **Certification:** EOS AI PASS; ≥90% zero-model-call impressions; spend-cap + fallback demonstrated; `ai_*` isolation green.
- **Production-readiness:** per-persona AI live under cap at pilot scale; no ungoverned/unlogged model or embedding call.

---

### W8 — Cross-Platform Cohesion: Web Parity · A11y · i18n · Design 🟠 (Constitution Part 4/13)

- **Why:** "Web, Android and iOS should feel like the same product; business behavior consistent across every client." Today the **web app is a read-only viewer with no write layer** — not workflow parity. Plus the Constitution's accessibility + design-system + progressive-disclosure standards.
- **Outcome:** the web app becomes a *functional* ERP (real create/update/approve/collect/mark/apply flows) with server-authoritative RBAC (never re-implement governance client-side), token refresh, and honest states (kill the fake "Settings saved" toast, demo-mode-blank default); a WCAG accessibility pass; design-system enforcement lints; consistent business behavior across clients.
- **Inspect first:** the web has 229 read-only routes + a clean API/contract layer to extend — **extend the shell to writes, don't rebuild**. The mobile design system + RBAC model are the reference; web must inherit server-side gating, not copy client-side hiding. Reconcile the three disagreeing web gap registers into one.
- **Recovered items:** web write layer (the entire functional web ERP); web token refresh (`/auth/refresh` exists, unused); "Settings saved" fake toast fix; repurposed-endpoint KpiPages; ERP-WT web-track tail; P2-UX-1…5 (feel/ergonomics/DS-enforcement/**a11y**/dark-theme — a11y still open); parent offline read cache (P2-26); web ERP-WT-003 (live GPS — Phase-2/deferred).
- **Dependencies:** W0, W2 (RBAC), W4 (the workflows to mirror). 
- **Risks:** building web writes without server-authoritative RBAC repeats the "governance in the client" anti-pattern; scope is large (every mutation). Mitigate: web calls the same governed backend endpoints as mobile; no new business logic client-side.
- **Completion:** web supports the core mutations per persona with server-side RBAC + token refresh; a11y pass; DS lints block new violations; one reconciled web gap register.
- **Certification:** EOS UX+CI PASS; web live-cert extended from render-only to **workflow** cert; cross-client behavior-parity tests.
- **Production-readiness:** a user completes a real transaction (collect fee / approve admission / mark attendance) on web against the pilot with correct RBAC and persistence.

---

### W9 — Enterprise, Multi-School & Data Ownership 🟠 (Constitution Part 12)

- **Why:** the platform must support multi-campus/group operation with clear organizational boundaries, data ownership, and consolidated reporting — "future growth extends the platform, not replaces it."
- **Outcome:** add-a-school-to-an-existing-org is a product feature (not an engineer's SQL); Org Builder provisions a *branch* (shared `organization_id`) not a disconnected tenant; cross-branch student transfer preserves history; tenant-wide data export on exit; the audit log is readable in-product.
- **Inspect first:** Director consolidation is real and correctly org-filtered (preserve). The gaps are the write/lifecycle side (P1-51 add-school, P1-52 branch-vs-tenant, P2-28 branch transfer, P2-29 Control-Center masking, P1-55 export, P1-53 audit read). Verify what erp-pra-remediation touched.
- **Recovered items:** PRA-P1-51/52/55, P2-27/28/29; P1-53 audit-log read UI; multi-school SOP-ID-3 ties in; Enterprise analytics.
- **Dependencies:** W0, W2 (identity/multi-school), W6 (export adapter, audit read UI).
- **Risks:** branch-vs-tenant is an architectural correctness issue (RLS + Director key on `organization_id`) — a wrong model silently splits a customer into two. Mitigate with cross-org consolidation tests.
- **Completion:** add-branch works in-product; branches roll up to the parent Director dashboard; cross-branch transfer preserves history; data export works.
- **Certification:** EOS FEATURE+SECURITY PASS; consolidated reporting verified across ≥2 branches; export completeness verified.
- **Production-readiness:** a group provisions branch #2 in-product and sees it consolidated live; a school can extract its data on exit.

---

### W10 — Engineering Hardening 🟠 (Constitution Part 14)

- **Why:** the Constitution demands reliability, security-throughout, observability, and least-privilege as *structural* properties — not conventions. Today auth/RBAC is per-handler by convention (a forgotten guard = open route), 3 `service_role` paths bypass RLS, RLS covers ~91% of tables, and CI does not gate the branch.
- **Outcome:** a central auth/RBAC chokepoint (structural guarantee, e.g. registry-driven or middleware-enforced) so no route can be unauthenticated by omission; RLS coverage completed; `service_role` paths hardened with proven manual tenant scoping; CI green-gating the trunk (analyze + tests + isolation probes + live-regression cron); observability; tech-debt register refreshed.
- **Inspect first:** the OR→AND `requireAnyPermission` primitive exists (use it); the forced-auth + isolation test suites exist (extend to enforce centrally); CI workflows exist but don't gate — wire them.
- **Recovered items:** central RBAC chokepoint (backend risk #2); RLS completion (20 tables); `service_role` hardening (risk #6); coarse scope-only RBAC on search/payment/hostel (risk #7); `student_entities` read-model drift (risk #8); P0-TEST-1/2/3 (CI + isolation-in-CI + 7-day clock); P1-TEST-1/2 (device E2E, load, N+1); P1-INFRA-1 scale foundation (⏸ not pilot-gating); TechnicalDebtRegister refresh; the stale-doc reconciliations.
- **Dependencies:** W0. Runs parallel to W4–W9. **Owner-gated:** CI runner provisioning; scale machinery timing.
- **Risks:** retrofitting a central gate across ~50 routers is invasive → do it registry-first with the forced-auth suite as the safety net.
- **Completion:** central gate enforced; RLS complete; CI gates the trunk; `service_role` paths tenant-proven; tech-debt register current.
- **Certification:** EOS ARCH+OPS PASS; forced-auth + isolation suites green in CI; load numbers within targets.
- **Production-readiness:** no route reachable without auth by omission; CI blocks regressions; the 7-day live-regression clock runs (gates final cert).

---

### W11 — Security & Reliability Certification (Red Team → Fixes → Live) 🔴 (Constitution Part 14/15)

- **Why:** institutional trust depends on demonstrated security + reliability, verified adversarially and live.
- **Outcome:** a converged, current red-team pass (the DRP lane already ran Rounds 1–7 + P5 fixes — **reconcile and re-run on the converged trunk with refreshed seeds for the post-W2 AI / multi-school / QIE surface**); every P0/blocking-P1 closed and live-re-verified; the full live checklist (off-site backup, alert delivery, crons, isolation-in-CI, AI-migration deploy sequencing) green.
- **Inspect first:** do not discard the DRP red-team work — merge it (W0) and extend, don't restart. The 12-domain framework + seeds exist.
- **Recovered items:** P4-RT-0/RT-1, P5-FIX-1 (reconciled with the DRP branch's Rounds 1–7 + P5); P0-LIVE-1 (13-item live checklist; ⑪⑫⑬ done); P1-SEC-1 (session-revoke live, TLS pinning, root/jailbreak, key restrictions); DR/backup (off-site 3-2-1, WAL/PITR post-pilot per owner RPO decision).
- **Dependencies:** W0–W10 substantially complete + **feature freeze** (no new features from here). Owner-gated: live provisioning (R2 creds, cron token, CI runner).
- **Risks:** a red-team finding can re-open earlier waves (variable by design); the round law forbids declaring victory on one clean pass.
- **Completion:** repeated rounds stop finding meaningful issues; every finding fixed + live-re-verified; live checklist green; 7-day clock counting.
- **Certification:** RED-TEAM verdict PASS + EOS per fix.
- **Production-readiness:** live isolation/backup/alert/cron all proven on the pilot; no open P0/blocking-P1 anywhere.

---

### W12 — Final Validation · Pilot · Beta Schools 🔴 (Constitution Part 15/16)

- **Why:** production readiness must be *earned* through full-system validation, an internal pilot, and real-school beta before GA.
- **Outcome:** all persona journeys + cross-role/cross-school workflows validated (rounds until clean); an unattended full-year pilot sim (single + 3-school concurrent, stages 0–16) green; 5–10 real beta schools stable with feedback triaged to closure.
- **Recovered items:** P6-VAL-1, P6-PILOT-1 (Stage 12 exercises staff Face-ID — its device-build/fallback must be landed in W4), P6-BETA-1 (👤 cohort recruitment).
- **Dependencies:** W11 exit. **Owner-gated:** beta cohort recruitment.
- **Risks:** beta feedback re-opens fixes; device features (Face-ID) must be pilot-ready.
- **Completion:** one clean validation round; pilot stages green unattended; beta cohort stable, all beta P0/P1 closed.
- **Certification:** VAL PASS → PILOT-READY → BETA PASS.
- **Production-readiness:** real schools run daily on Akshara with no regressions.

---

### W13 — Production Certification & GA 🔴 (Constitution Part 15/16 — the only place 🟩 is granted)

- **Why:** the Constitution's end state — an enterprise-grade, trusted platform, certified on live evidence.
- **Outcome:** all GA gates pass at their evidence grade; 7-day live-regression green; go/no-go recorded; production launch (VPS deploy, migration head == deployed head, smoke, monitoring, cron, backup incl. off-site, security, performance, **cost + AI-quota**, rollback proven); GA declared; post-GA forward plan handed to owner scheduling.
- **Recovered items:** P7-CERT-1, P8-GA-1…5 (incl. commercial pack 👤, and the post-GA forward register: Phase-2 commercial billing/quotas/white-label/GPS, Assessment Intelligence Platform, scale machinery).
- **Dependencies:** W12 exit.
- **Completion / Certification / Production-readiness:** every GA checklist item satisfied with LIVE evidence; **🟩 Production Certified granted**; GA declared.

---

### K — Knowledge Lane (QIE on frozen v1.4) 🟡 — *parallel, never blocks the ERP*

- **Why (Constitution Part 7):** QIE is the educational brain; it builds on the **immutable** v1.4 foundation. Per owner: builds on the freeze; no discovery reopening.
- **Outcome:** continue the Decision-C split-lane (structured/numeric via the AI candidate factory certified deterministically by sympy; qualitative via the OCR/answer-key-grounding lane) toward paper-servability targets — **on the frozen foundation**.
- **Inspect first:** honor v1.4 immutability; the committed state trails the local state (reconcile per W0.1). The integration into the ERP is W5 (owner-gated promotion), not here.
- **Recovered items:** K-2 QP hardening tail (templates/blueprints/OCR/validation), K-4 re-cert, K-3 promotion (owner-timed, not GA-gating); the QIE §7 generation tail (Biology negative-lane, more batches, depth-4/5 chains, notation breadth, SI units); the Decision-C pre-scaling checklist (concept-quality gate, subject re-derivation, saturation measurement, `parse_unit` fix, senior-book spine); adopt-Decision-C owner confirmation.
- **Dependencies:** none on the ERP (parallel). **Owner-gated:** Decision-C adoption; K-3 promotion timing.
- **Risks:** the P0 continuity risk (W0.1) is the top one; qualitative lane can't be deterministically certified (structural).
- **Completion / Certification:** K-lane freeze via 2 consecutive clean independent audits; v1.4 never mutated.

---

## 5.5 PROGRAM EIP — EDUCATIONAL INTELLIGENCE PLATFORM 🟡 (Constitution Parts 6 · 7 · 8 · 11)

*The Constitution's "educational brain": the QIE → Assessment → Learning-Evidence → Student360 → persona-intelligence → adaptive-learning stack. This program elevates the strategic educational-intelligence vision — previously compressed into W5 — into 14 dedicated, first-class workstreams so nothing discussed is omitted. It spans W5 → post-GA and runs parallel to the ERP waves under disjoint ownership.*

**Architecture authority (reconcile against — never duplicate):** [`docs/curriculum-intelligence/spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md`](../curriculum-intelligence/spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md) (6,286 lines), [`docs/curriculum-intelligence/spec/MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md`](../curriculum-intelligence/spec/MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md), the QIE handoff, the KIE v1.4 freeze, and the ERP `_shared/intelligence/` + `_shared/education/` modules. Several of these 14 already exist in part — **certify what is built, complete what is partial, build only what is genuinely missing** (owner Golden Rule).

**Program laws (mandatory):**
- **Builds on the frozen KIE v1.4** (2,023 concepts + concept graph, immutable) — no discovery reopening, no foundation mutation.
- **Deterministic-first & explainable (Constitution Part 11):** a deterministic result is **never** delegated to a model — AI may *explain* a result, never *invent* it. Where a family-certified deterministic path exists, no runtime AI (Amendment A2 invariant **I9**).
- **Extend, never fork:** EIP extends `education` (bank/paper), `intelligence/` (persona services), the QIE lane (generation/verification), and the KIE graph (concepts). **No parallel/duplicate module.** The two existing "Question Intelligence" systems are reconciled in W5 (one generator, one governance surface, one seam) before EIP scales.
- **Evidence-based:** every intelligence claim traces to verified learning evidence; **live promotion of the Assessment Intelligence Platform remains owner-timed** (the LOCKED post-pilot decision is honored) — but the program is now **roadmapped, not omitted**.

### The stack = the integration architecture (this answers capability #14 directly)

```
        ┌────────────────────────  FROZEN KIE v1.4 (concepts + concept graph, immutable)  ───────────────────────┐
        ▼                                                                                                          │
 [EIP-1] Exam DNA / QDI ─► [EIP-2] Blueprint & Planning ─► (QIE factory: generate) ─► [EIP-3] Verification ─► CERTIFIED ITEM
                                                                                                        │           │
                                                                              [EIP-5] Certified Solution Intelligence (visual)
                                                                                                        │
 CERTIFIED ITEM+SOLUTION ─► [EIP-4] Daily Practice · OMR · Online Exams · Homework ──────────┐          │
                                                                                             ▼          ▼
                                            ┌──────────────  [EIP-6] LEARNING EVIDENCE PLATFORM (the spine)  ──────────────┐
                                            │  every interaction → evidence: attempts·time·confidence·hints·revision·result │
                                            └───────────────────────────────┬──────────────────────────────────────────────┘
                                                                            ▼
        ┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐
        ▼                       ▼                          ▼                         ▼                              ▼
 [EIP-7] Student        [EIP-8] Teacher          [EIP-9] Parent          [EIP-10] Principal        [EIP-11/12/13] Adaptive:
 Learning Intelligence  Intelligence             Intelligence            Intelligence               Revision · Reasoning · ConceptFlow
        │                                                                                                          ▲
        └──────────────────────── concept mastery + weakness + KIE graph feed back ────────────────────────────────┘
```
**Integration law (EIP-14):** each layer must **emit a typed evidence/intelligence contract into the next** — no layer is a terminal dead-end. EIP is certified only when the *chain* is proven end-to-end (a practice attempt becomes evidence becomes mastery becomes a teacher insight becomes a revision path), never module-by-module in isolation.

### The 14 workstreams

Each carries: **State** (✅ certify / 🔶 complete / ⚪ build) · **Extends** (reuse target) · **Phases** · **Verification** · **Certification** · **Integration in→out**. Priority: **P0** = foundational enabler · **P1** = high value · **P2** = net-new depth.

| ID | Workstream | State (evidence) | Pri |
|---|---|---|---|
| **EIP-1** | **Exam DNA Intelligence** — prev-paper DNA extraction, weightage intelligence, concept frequency, concept combinations, difficulty & archetype distribution, **pattern evolution across years** | 🔶 **PARTIAL** — QIE lane has `archetypes.py`, `qdi.py`, `mine.py`, `profiles.py`, `compositions.py`, `capability_report.py`, `benchmark.py` (QDI = design patterns mined from real JEE/NEET papers w/ anti-copying shingle gate). Missing: productized weightage/frequency/archetype *distributions* + cross-year *evolution* as queryable intelligence | P1 |
| **EIP-2** | **Question Blueprint / Planning Layer** — deterministic planning, blueprint schema, certified planning rules, **planning before generation** | 🔶 **PARTIAL** — QIE `planner.py`/`plan_specs.py`/`plan_controls.py`/`brief.py` (Decision-C: "QIE = planner + constraint system + judge"); ERP `education_blueprint_solver.ts` (real, golden-tested) + CBSE sectioned templates (dormant, PRA-P2-24). Complete + activate the dormant templates | P1 |
| **EIP-3** | **Independent Verification Pipeline** — independent solution verification, mathematical (sympy) + scientific verification, ambiguity detection, duplicate detection, certification gates | ✅ **STRONG / deep-in-execution** — sympy 96.6% agreement, `math_structure.py`/`relations.py`, notation recovery (41 relations certified/8 controls), adversarial controls per batch, independent blind-auditor agents, dedup + certification gates. **Certify + productize as a reusable pipeline** | P1 |
| **EIP-4** | **Intelligent Daily Practice System** — daily practice generation, personalized practice, difficulty & concept progression, weakness-based practice | ⚪ **PLANNING** — **Amendment A2** (owner-approved *direction*, ratification pending): deterministic per-student practice/DPP, **family-level certification (D-7)** + **zero-runtime-AI (I9)**; `dpp_stage.py` seed exists. Ratify A2 → build on the certified item bank + EIP-6 evidence | P1 |
| **EIP-5** | **Certified Solution Intelligence** — step-by-step explanations, **visual learning: SVG/Flutter-rendered diagrams, flow diagrams, concept maps, formula visualizations, interactive learning cards**, wrong-option analysis, misconception explanation, multiple explanation styles by student level | ⚪ **CONTENT in-flight / VISUAL missing** — QIE "solution construction (Stage 5)" built but model-capacity-blocked; **no visual/SVG/Flutter solution renderer, wrong-option/misconception layer, or multi-style engine exists** (grep confirms). Solutions are plain-text today. Net-new build | **P1★** |
| **EIP-6** | **Learning Evidence Platform** — every interaction (practice, homework, OMR, exams) → evidence, capturing time-taken, confidence, attempts, hint-usage, revision history | ⚪ **DORMANT spine** — `edu_student_item_responses` exists but has **zero callers** (its migration is literally `..._dormant_response_trust_exposure_seed.sql`); no time/confidence/hint/attempt capture. **This is the foundational enabler for EIP-7…13** | **P0** |
| **EIP-7** | **Student Learning Intelligence** — concept mastery, weakness detection, learning progression, readiness prediction, personalized recommendations | 🔶 **PARTIAL** — `intelligence/student_success_service.ts` + `student_risk_engine.ts` real; concept-mastery/weakness coarse (SOP-F7 repeated-weakness open). Complete depth on EIP-6 evidence + KIE graph | P1 |
| **EIP-8** | **Teacher Intelligence** — class misconceptions, teaching gaps, intervention suggestions, group recommendations, learning analytics | 🔶 **PARTIAL** — `intelligence/teacher_success_service.ts` + `homework_intelligence_service.ts` real; misconception/teaching-gap depth missing. Complete on EIP-6 | P1 |
| **EIP-9** | **Parent Intelligence** — learning health, study behaviour, consistency, improvement trends, concept mastery | 🔶 **PARTIAL** — `intelligence/parent_guidance_generator.ts` + `parent_insights` real (⚠ the P0-21 fabrication bug fixed on the remediation branch — must serve **real** evidence, never defaulted). Complete honestly on EIP-6 | P1 |
| **EIP-10** | **Principal Intelligence** — school/department/teacher analytics, assessment quality, school-improvement recommendations | 🔶 **PARTIAL** — `intelligence/principal_intelligence_service.ts` + management/director dashboards real; dept/teacher/assessment-quality analytics shallow. Complete on EIP-6 | P1 |
| **EIP-11** | **Adaptive Revision Intelligence** — AI-generated revision paths, bridge concepts, prerequisite revision, personalized revision scheduling | ⚪ **MISSING** (KIE concept graph `phase6_graph.py` = the prerequisite substrate). Build a revision-path engine over the graph + EIP-6 mastery | P2 |
| **EIP-12** | **Reasoning Intelligence** — thinking-path reconstruction, decision trees, expert reasoning, reasoning timeline, "explain **how to think**, not only what is correct" | ⚪ **MISSING** (net-new, novel). Deterministic-derived reasoning traces over certified items + KIE graph; AI narrates, never invents the reasoning | P2 |
| **EIP-13** | **Concept Intelligence** — ConceptFlow Engine, interactive concept cards, reusable concept explanations, **Flutter-native visual learning (no dependency on traditional video)** | ⚪ **MISSING as product** (KIE concept graph = substrate; no concept-card UI). Build Flutter-native ConceptFlow cards keyed to certified concepts | P2 |
| **EIP-14** | **Product Integration** — every layer feeds intelligence into the next; explicit integration contracts, not isolated features | ⚪ **the binding law** — define + enforce the typed evidence/intelligence contracts between every layer (the stack diagram above); certify the end-to-end chain | **P0** |

### EIP execution shape (per-workstream template applied program-wide)

- **Why (all):** the Constitution mandates assessment feeds learning intelligence (Part 8), Student360 is *the* educational intelligence layer (Part 6), QIE is the knowledge brain (Part 7), and intelligence is one governed, explainable, evidence-driven platform capability (Part 11) — not isolated AI features.
- **Inspect first (all):** reconcile every workstream against current code + the two master specs before building; certify EIP-3 and the partial persona services; **do not rebuild** the QIE verification pipeline, the blueprint solver, or the intelligence services.
- **Phases (program-level):**
  1. **Phase 0 — Foundation:** EIP-6 (evidence spine) + EIP-14 (integration contracts) — *these gate all consumers.* Ratify Amendment A2 (EIP-4).
  2. **Phase 1 — Manufacturing, certified:** certify EIP-3; complete EIP-1/EIP-2; reconcile the two QI systems (W5).
  3. **Phase 2 — Content value:** EIP-5 (certified visual solutions) + EIP-4 (daily practice) on the certified bank + evidence spine.
  4. **Phase 3 — Consumers:** complete EIP-7/8/9/10 on real evidence.
  5. **Phase 4 — Adaptive (net-new, post-pilot-timed):** EIP-11/12/13.
- **Dependencies:** frozen KIE v1.4 (K-lane) · W5 (ERP seams) · W7 (governed AI gateway — all EIP model use routes through it) · W3 (AI credit wallet / cost). **Owner-gated:** Assessment Intelligence Platform live-promotion timing (LOCKED — post-pilot); Amendment A2 ratification; D1 (OMR) for OMR-sourced evidence.
- **Risks:** (a) scaling consumers before EIP-6 exists = fabricated intelligence (the exact PRA-P0-21 failure — an intelligence layer that *defaults* values and narrates them as real); (b) duplicating the QIE verification/blueprint that already exists; (c) qualitative lane cannot be deterministically certified (keep the OCR/answer-key-grounding lane); (d) delegating deterministic results to a model. Mitigations: EIP-6/EIP-14 first; verify-first; deterministic-first law; the standing QIE adversarial-control + blind-audit regime.
- **Verification (program):** end-to-end chain proof — a practice attempt (EIP-4) writes evidence (EIP-6) that moves a mastery score (EIP-7) that raises a teacher misconception flag (EIP-8) that seeds a revision path (EIP-11); every certified item passes EIP-3; every solution renders visually with wrong-option/misconception (EIP-5); no intelligence value is ever defaulted/fabricated.
- **Certification:** each workstream EOS FEATURE+AI PASS; a dedicated **EIP certification** proving the integration contracts (EIP-14) hold end-to-end and that **AI never invents a deterministic result**; the QIE→ERP promotion seam has an explicit EOS gate (none exists today).
- **Production-readiness:** on the pilot, a real student's practice/exam/homework produces real evidence that drives real, explainable, non-fabricated Student/Teacher/Parent/Principal intelligence, with certified visual solutions — owner-approved before any live Assessment-Intelligence promotion.

---

## 5.6 PROGRAM ASIP — AI SUPPORT INTELLIGENCE PLATFORM 🟩 **PRODUCTION CERTIFIED (2026-07-20)** (Constitution Parts 6 · 7B · 8) — *parallel lane, never gated the ERP*

> ✅ **LIVE on the pilot.** Both phases deployed additively onto the deployed head + **live cert 18/18 (test) + 18/18 (production smoke)** — cert `docs/SUPPORT_INTELLIGENCE_PLATFORM_CERTIFICATION.md`. Only owner tail: set real phone numbers on the 4 seeded support principals to enable OTP login.

*The platform-support system through which **customer schools report Akshara product issues to the Akshara Support Team**, and through which a very small support team investigates and resolves at scale with AI assistance. **NOT** the school's internal Complaint system; **NOT** the read-only `control_center` mock. Added 2026-07-20 under the Appendix-C change-control law as a first-class isolated parallel workstream (worktree `Akshara_ERP-asip`, branch `feature/asip-support-intelligence`, base `integration/w0-trunk`, migration band `20260920000000+`). Design authority: [`docs/support-intelligence/ASIP_DESIGN.md`](../support-intelligence/ASIP_DESIGN.md).*

**Architecture authority (reconcile against — never duplicate):** the platform primitives — `api/app.ts` edge router, `_shared/permission_middleware.ts` (RBAC), `_shared/tenant_db.ts` (tenant RLS), `_shared/audit/*`, `_shared/storage/*`, `_shared/communication/*`, `_shared/approval/*`, and the **governed AI gateway** `_shared/ai/model_gateway.ts` — plus the client `lib/core/{errors,audit,workflow,communication,notifications}`. ASIP introduces **zero** new RBAC/Workflow/Audit/Notification/Attachment/Communication/Ticket engines.

**Program laws (mandatory):**
- **Reuse-first (AGENTS.md / LAW 9):** extend the primitives above; the only net-new is the school-facing report flow, a client binary-upload pipeline, runtime device/route/breadcrumb capture, and the incident/evidence/AI-package model.
- **AI assists; humans approve (Adaptive-AI doc 10 §12):** AI reads evidence + drafts; a human support engineer decides. **No unrestricted autonomous production changes** — any Phase-2 support action that mutates a tenant goes through maker-checker `approval_requests`.
- **Deterministic-first & PII-minimized:** evidence collection, categorization, dedup fingerprints and clustering keys are deterministic; the LLM (via the governed gateway) is last-mile enrichment only. The evidence snapshot carries IDs + safe diagnostics, never raw student PII.
- **Tenant isolation is absolute:** Phase 1 is 100% within-tenant (standard org+school RLS). Cross-tenant support access is **owner-gated** (Decision A) precisely because Part 7B lists *Tenant Isolation Failure* + *Permission Escalation* as automatic certification failures.

### The two-phase split (driven by the hard org wall)

The platform has no cross-tenant data-plane principal today (RLS is unconditionally `organization_id = app_current_tenant_id()`). So ASIP splits on that seam:

| ID | Workstream | State (evidence) | Pri |
|---|---|---|---|
| **ASIP-1** | **School Incident Reporting** — report an issue with only Description + Screenshot (+ optional recording); `public_ref`; my-incidents; conversation | 🟩 **PRODUCTION CERTIFIED (Phase 1)** — backend + Flutter client; 32 deno + 6 flutter tests, analyze 0; live-cert owner-gated. Reuses storage presign, communication, audit, RBAC | **P1** |
| **ASIP-2** | **Automatic Evidence Capture** — client auto-collects app version/device/OS/session/route/module/correlation-ids/breadcrumbs/recent-API-calls; server enriches from `listAuditEvents` + workflow/approval state → PII-minimized evidence snapshot | 🟩 **PRODUCTION CERTIFIED (Phase 1)** — net-new client capture backbone + first real binary upload pipeline; PII-minimized snapshot; reuses `ErrorReportingService`/`CorrelationIdInterceptor`/`AuditLogger` | **P1** |
| **ASIP-3** | **AI Incident Package** — deterministic assembly of all evidence + governed LLM enrichment (categorization, severity suggestion, summary, likely root cause, suggested next steps); **human-approve** before any use | 🟩 **PRODUCTION CERTIFIED (Phase 1)** — deterministic-first; routes through `callModelGateway` (spend cap/rate/cache/timeout/telemetry/fallback); complete even when the model declines | **P1** |
| **ASIP-4** | **Incident Clustering / Dedup / Similar-incident** — "many schools, one incident": shared-incident detection, link affected tickets, investigate once/resolve many | 🟩 **PRODUCTION CERTIFIED (Phase 2)** — deterministic fingerprint (category+module+error-signature) → shared cluster, auto-linked; resolve-cluster propagates to every school. (Semantic/pgvector similarity = future depth.) | P1 |
| **ASIP-5** | **AI Support Investigation** — root-cause analysis, log summarization, suggested fixes, KB search, previous-incident matching | 🟩 **PRODUCTION CERTIFIED (Phase 2)** — cross-incident investigation, deterministic-first + governed gateway; explainable; human-approves | P1 |
| **ASIP-6** | **Support Workspace** — one place: ticket, conversation, evidence, timeline, AI diagnosis, suggested resolution, internal notes, assignment, escalation, resolution | 🟩 **PRODUCTION CERTIFIED (backend + web console)** — `/support/platform/*` API (45 deno tests) + React `/support-console` (B1 scoped unfreeze; build PASS, 147 web tests). Live activation owner/deploy-gated | P1 |
| **ASIP-7** | **Engineering Handoff** — generate a complete Engineering Incident Package (all investigation evidence) so engineers begin fixing immediately | 🟩 **PRODUCTION CERTIFIED (Phase 2)** — deterministic export of environment + reproduction + evidence + notes + cluster breadth | P2 |
| **ASIP-8** | **Continuous Learning** — resolved incidents feed a knowledge base that improves future diagnosis/recommendations | ⚪ **build (Phase 2)** — KB over `ai_response_cache`/embeddings; learns from resolutions | P2 |

### ASIP execution shape

- **Why (Constitution Parts 6/7B/8):** a very small team must support hundreds/thousands of schools; the platform, not the engineer, must prepare the complete investigation package; support is an evidence-based, governed, auditable capability — not ad-hoc email.
- **Inspect first:** reuse the primitives (recon complete in `ASIP_DESIGN.md` §1); do **not** duplicate any engine; extend the frozen web viewer only via a scoped owner-unfreeze (Decision B).
- **Phases:** **Phase 1** = ASIP-1/2/3 (within-tenant; buildable + certifiable now). **Phase 2** (owner-gated on A & B) = ASIP-4/5/6/7/8.
- **Dependencies:** governed AI gateway (W7) for all model use; storage/communication/approval primitives; **W0 convergence** for final integration/deploy. **Decisions A + B → 🔒 DECIDED (owner, 2026-07-20): A1 mirror + B1 web console (scoped unfreeze).** Remaining **owner/deploy-gated:** the `PLATFORM_ORG` + support-principal seed and the live-cert + deploy authorization.
- **Risks:** (a) a cross-tenant principal that breaks the org wall = Part 7B auto-fail → mitigate with the snapshot/mirror model + maker-checker on prod actions; (b) leaking raw PII into evidence/prompts → PII-minimized snapshot by construction; (c) autonomous AI applying a fix → forbidden; humans approve.
- **Verification:** deno handler tests (create/evidence/analyze/RLS deny-path/tenant-isolation), Flutter widget + golden tests (report UI, my-incidents, conversation), a live-cert script (`scripts/qa/live_cert_asip.py`) authored and ready.
- **Certification:** `/eos support` FEATURE+SECURITY PASS (zero P0, no Part 7B auto-fail, tenant-isolation + RBAC deny-paths + audit verified); **PRODUCTION CERTIFIED** on a live N/N VPS run (owner-gated).
- **Production-readiness:** on the pilot, a school user reports an issue with a screenshot, the evidence snapshot + deterministic AI package assemble automatically, and a support principal sees the full investigation package — with tenant isolation intact and every mutation audited.

---

## 6. DEPENDENCY & SEQUENCING SUMMARY

```
W0 Convergence ─► W1 Re-baseline ─►┬─► W2 Identity ────────────┐
                                    ├─► W3 Money/Data ──────────┤
                                    └─► W4 Ops-Completeness ────┼─► W11 Security/RT ─► W12 VAL/Pilot/Beta ─► W13 GA (🟩)
   W5 Assessment/QIE ──────────────────────────────────────────┤        ▲
   W6 Dynamic Platform Services ────────────────────────────────┤        │ (feature freeze before W11)
   W7 AI Consolidation ─────────────────────────────────────────┤        │
   W8 Web Parity/A11y/i18n ─────────────────────────────────────┤        │
   W9 Enterprise/Multi-School ──────────────────────────────────┤        │
   W10 Engineering Hardening (∥ throughout) ────────────────────┘        │
   K  Knowledge Lane (∥ throughout, never blocks) ───────────────────────┘
   EIP Educational Intelligence Platform (enters at W5; EIP-6+EIP-14 first; spans → post-GA, owner-timed promotion)
        └─ Phase0 evidence-spine ─► Phase1 certified-manufacturing ─► Phase2 practice+visual-solutions ─► Phase3 persona-intel ─► Phase4 adaptive (post-pilot)
```
Hard gates: **W0 and W1 precede everything.** Feature freeze precedes W11. W11→W12→W13 strictly sequential. K-lane and acquisition run parallel and never gate the ERP. **EIP-6 (Learning Evidence spine) + EIP-14 (integration contracts) gate all EIP consumer layers** — building persona intelligence before them = fabricated intelligence (the PRA-P0-21 failure mode). Device features (staff Face-ID) must land before W12 Pilot Stage 12.

---

## 7. OWNER DECISION BATCH (consolidated — each gates only its own item)

| # | Decision | Gates | Note |
|---|---|---|---|
| 1 | **W0 convergence approvals** — off-repo backup location; confirm the live deployed head; prune/keep the `worktree-agent-*` branches | W0 | Highest priority — unblocks everything |
| 2 | **D1 — Smart OMR (SOP-F1/F2/F3)** | W5 | Reverses frozen Assessment decision — **do not build until confirmed** |
| 3 | **D2 — SOP placement/sequencing** | W2/W5/W6 | Where SOP items sit relative to certification |
| 4 | **Payment gateway choice + credentials (P0-02 SDK)** | W3 | External paid provider; client already fail-closed |
| 5 | **PLAT-0 identity cluster** (change-phone, Public-ID rollout C5/ADM-D3, admissions SoD) | W2 | |
| 6 | **Module scope:** Hostel (P1-CODE-7) · Alumni (P1-CODE-8) · cross-module Finance posting (P1-CODE-6/MOD-1) | W3/W4 | |
| 7 | **Library accession numbering scheme (P1-41)** · **staff real-device build scope (P0-15)** · **statutory payroll schedule (P1-35)** · **leave accrual (P1-34)** | W3/W4 | Owner data-model / hardware / large-build |
| 8 | **K-3 QIE→ERP promotion timing** · **Decision-C formal adoption** | W5/K | Not GA-gating |
| 8b | **PROGRAM EIP:** Amendment A2 ratification (per-student practice/DPP) · **Assessment Intelligence Platform live-promotion timing** (currently LOCKED/post-pilot) · EIP-11/12/13 net-new build timing | EIP | Roadmapped now; live promotion owner-timed |
| 9 | **Beta cohort recruitment (5–10 real schools)** | W12 | |
| 10 | **Live provisioning:** R2 creds · `INTERNAL_CRON_TOKEN` · CI runner (starts the 7-day clock) · FREEZE K-lane carve-out · RPO/WAL post-pilot | W10/W11 | |
| 11 | **Owner queue Items 6–40** (provider-abstraction layers) | W6 | Each reconciled against current code before build (Golden Rule) |

---

## 8. DEFERRED / FUTURE / OUT-OF-SCOPE REGISTER (nothing lost)

- **⏸ Deferred (scheduled, not GA-gating):** scale machinery (P1-INFRA-1); WAL/PITR (owner-accepted ~24h RPO for pilot); K-3 promotion.
- **🔮 Future (post-GA, owner-timed):** Phase-2 commercial (billing/quotas/marketplace/live-GPS/white-label tiers/custom-domain); Assessment Intelligence Platform (Master Plan v3.0); the owner-queue provider layers not reconciled as pre-GA gaps.
- **Out-of-scope (North Star, honestly disclaimed today):** salon/restaurant/healthcare/accommodation/franchise/white-label; live-GPS/RFID/QR boarding; student Face-ID. **Action for W0/W10:** the *shipped-but-out-of-scope* verticals code (mobile `lib/features/verticals/*`, ~32 files + routers) should be **quarantined/removed** as scope debt (hidden today, but built/tested/maintained against the North Star) — a subtraction, per the Constitution's "success is not measured by module count."

---

## APPENDIX A — RECOVERY MAP (every old-roadmap open item → its new home)

*Nothing is lost. Every open/deferred/pending item from `FINAL_EXECUTION_MASTER_ROADMAP.md`, the PRA register, the PRC tracker, the SOP spec, the tech-debt register, the web-track, and the owner queue is placed below.*

| Old item(s) | New home | Notes |
|---|---|---|
| PRA-P0-01, P1-01…07, P2-34; SOP-ID-1…5; P1-CODE-4 (PLAT-0); Admissions SoD | **W2** | Mostly fixed on `erp-pra-remediation` S2 → verify-merged + tail |
| PRA-P0-02/03/04/24, P1-08/09/10/11/37/38, P2-10/16/30, N-15/16 | **W3** | S1/S7 fixes → verify-merged; payment SDK + statutory payroll owner-gated |
| PRA operational P0s (05–23) + P1s (12–50 ops); PRC-A-001…148; C3/C6/HWK-1; device P0-15 | **W4** | S3/S5/S6/S7 fixes verify-merged; PRC-A domains new build |
| SOP-F4/F5/F6/F7; education stub-content; PRA-P1-26/27/28/29; K-3 | **W5** | Reconcile the two QI systems; D1 owner-gated; **entry into PROGRAM EIP** |
| **Educational Intelligence vision** — Exam DNA, Blueprint/Planning, Verification Pipeline, Daily Practice (Amendment A2), Certified Visual Solutions, Learning Evidence Platform, Student/Teacher/Parent/Principal Intelligence, Adaptive Revision, Reasoning Intelligence, ConceptFlow, cross-layer integration | **PROGRAM EIP (§5.5)** | 14 workstreams EIP-1…14; certify EIP-3 (built), complete the partials, build the missing (EIP-5/6/11/12/13); EIP-6+EIP-14 first |
| SOP-F8/F9/F10/F11/F12; owner-queue Items 6–40; PRA-P1-49/50/53/54/55, P2-30 | **W6** | Extend existing engines; reconcile each owner item first |
| P3-AI-2 tail (W2.1/2.7/2.8/2.9), P3-AI-3 hardening, AI-6, PRA-P1-46, P2-21 | **W7** | Finish hardening + consolidate; deploy AI migrations |
| Web write layer, token refresh, ERP-WT tail, P2-UX-1…5 (a11y open), P2-26 | **W8** | Web = read-only viewer today → make functional |
| PRA-P1-51/52/55, P2-27/28/29, P1-53 | **W9** | Multi-school branch vs tenant; export; audit read |
| Central RBAC gate, RLS completion, service_role hardening, P0-TEST-1/2/3, P1-TEST-1/2, P1-INFRA-1, tech-debt register | **W10** | Structural engineering hardening + CI |
| P4-RT-0/RT-1, P5-FIX-1, P0-LIVE-1, P1-SEC-1, DR/backup | **W11** | Reconcile with DRP-branch Rounds 1–7 + P5 (already done — merge, don't restart) |
| P6-VAL-1, P6-PILOT-1, P6-BETA-1 | **W12** | Pilot Stage 12 needs Face-ID landed (W4) |
| P7-CERT-1, P8-GA-1…5 | **W13** | Only place 🟩 is granted |
| K-2/K-4, K-3, QIE §7 tail, Decision-C pre-scaling checklist | **K (parallel)** | v1.4 immutable |
| QIE uncommitted Decision-C code + foundation backup | **W0.1** | P0 continuity |
| CFC-1 (10-item freeze checklist), FREEZE-1 | folded into **W10 exit + pre-W11 gate** | The freeze checklist becomes the entry gate to W11 |
| Verticals scope debt, phase4/5 naming, dual finance dashboards | **W0/W10 subtraction** | Remove/quarantine per North Star |
| Deferred/Future/Out-of-scope | **§8 register** | Preserved, owner-timed |

## APPENDIX B — SOURCE DOCUMENTS (authority chain)

1. **Supreme:** `docs/owner/AKSHARA_MASTER_PRODUCT_CONSTITUTION_v2.0.md`
2. **This roadmap** (single forward plan) · superseded-but-retained: `docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md` (+ its PRA register)
3. **Reality evidence:** the PRA register (117 items, `file:line`); `Akshara_ERP-pra/docs/roadmap/PRA_EXECUTION_LOG.md` (what's actually fixed); `PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md` (PRC 502 reqs); `PROGRAM_SOP_IDENTITY_AND_PLATFORM.md`; `docs/owner/OWNER_FUTURE_PLATFORM_IDEAS_AND_RECONCILIATION_QUEUE.md` (40 provider items); web `PARITY_TRACKER.md`/`WEB_PRODUCTION_CERTIFICATION.md`; the KIE v1.4 freeze package (local-only).
4. **Educational Intelligence architecture (PROGRAM EIP authority):** `docs/curriculum-intelligence/spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md` (6,286 lines), `docs/curriculum-intelligence/spec/MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md`, `docs/curriculum-intelligence/proposals/AMENDMENT_A2_PER_STUDENT_PRACTICE_GENERATION.md`, the QIE handoff, and the ERP `_shared/intelligence/` + `_shared/education/` modules.
5. **Engineering gate:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` + `.claude/skills/eos/`.

## APPENDIX C — CHANGE-CONTROL LAW

No row in this roadmap or its recovered registers may be deleted, merged, re-scoped or weakened without a recorded justification here (date + reason + owner sign-off where a frozen decision or scope is affected). Deprecations must state what replaced them and why. The current code remains the authority for every status.

### Change records

- **2026-07-20 — ASIP → 🟩 PRODUCTION CERTIFIED (owner-authorized deploy).** Owner approval executed: branch pushed; additive deploy onto the deployed pilot head; 6 migrations applied+ledgered on `akshara_db`; `PLATFORM_ORG`+support principals seeded; live cert 18/18 (test) + 18/18 (production smoke) — 2 real bugs caught live and fixed. ASIP-1…7 → PRODUCTION CERTIFIED. Cert: `docs/SUPPORT_INTELLIGENCE_PLATFORM_CERTIFICATION.md`. Owner tail: real phone numbers on the 4 seeded support principals.
- **2026-07-20 — ADDED §5.6 PROGRAM ASIP (AI Support Intelligence Platform).** Reason: net-new platform capability (customer schools report Akshara product issues to the Akshara Support Team) confirmed genuinely missing after reuse recon (only a read-only `control_center` mock existed). No existing row deleted/re-scoped/weakened — purely additive as an isolated parallel lane that never gates the ERP. Phase 1 (ASIP-1/2/3, within-tenant) is decision-independent and under build; Phase 2 (ASIP-4/5/6/7/8, cross-tenant) is **owner-gated** on Decision A (cross-tenant access model) + Decision B (support workspace surface — the frozen web viewer scope). Design authority: `docs/support-intelligence/ASIP_DESIGN.md`. Owner sign-off pending on Decisions A/B and on live-cert/deploy authorization.

---

*This is the single authoritative roadmap going forward. It is Constitution-driven, repository-aware, and recovers every prior open item. It does not begin implementation — execution starts only on owner instruction, wave by wave, under the standing EOS gate.*
