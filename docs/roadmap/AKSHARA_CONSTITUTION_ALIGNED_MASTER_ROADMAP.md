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

> **🟢 LIVE EXECUTION STATUS (2026-07-20):** **W0 ✅** converged trunk `main` = `release/w0-converged` (pushed; `production` untouched; VPS-verified; 3650/0 backend · 4110/0 flutter) — [`W0_CONVERGENCE_CERTIFICATE.md`](W0_CONVERGENCE_CERTIFICATE.md). **W1 ✅** canonical evidence ledger [`W1_CANONICAL_EVIDENCE_LEDGER.md`](W1_CANONICAL_EVIDENCE_LEDGER.md) (PRA 65/5/47/0 · PRC ~450/33/19). **W2 ✅** identity-core verify-cert (111/0). **W3 ✅** money-integrity verify-cert (504/0). **W4 🔶** clean caps 57 (grace/suspension enforcement) + 130 (free-periods) built+certified; remaining ~31 caps owner/architecture-gated — see [`POST_CONVERGENCE_WAVE_LOG.md`](POST_CONVERGENCE_WAVE_LOG.md). **🔒 OWNER DECISION PACK APPROVED 2026-07-20 → `OWNER_DECISION_PACK_2026-07-20.md` (15 decisions FINAL) — W3/W4/W5/W2/W9 bulk UNBLOCKED; parallel autonomous build in progress.** Prior per-branch/per-cert status superseded by the W1 ledger.

| Wave | Title | Constitution anchor | Gate | Status |
|---|---|---|---|---|
| **W0** | Lane Convergence & Repository Integrity | Part 14/16 (one platform, single source of truth, backward-compat) | RELEASE/DOCS | ✅ done (EOS COND-PASS; canonical re-baseline done) |
| **W1** | Re-baseline Reality Audit on the Converged Trunk | Part 15 (earned confidence; void prior certs) | EOS DOCS | ✅ done (canonical ledger) |
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

## 5.6 AUDIT-DRIVEN REMEDIATION PROGRAMS (single source of truth for post-audit fixes)

*This part holds the concrete remediation backlog produced by the platform's certification-audit sessions. Each audit contributes one PROGRAM with the same item structure so findings accumulate into one register and are executed together in a planned remediation phase. **Roadmap planning only — no item here has been implemented.***

**Item structure (used by every audit program below, and by future ones):**
- **ID** (stable, e.g. `ICA-A1`) · **Class** (Architecture / Engineering / Security / Database / Finance / Performance / Product / Operational) · **Priority** (P0/P1/P2) · **Trace** (audit finding: `CR-x` or report §) · **Feeds** (the existing wave that will absorb it).
- **Evidence** (`file:line` + what the code actually does — carried verbatim from the audit so no re-investigation is needed) · **Fix** (the concrete change) · **Done-when** (verifiable exit).

**Priority rubric (aligned to the PRA convention):** **P0** = active/ reachable correctness, security, or money-integrity defect in shipped code — fix before the surface is extended or re-deployed. **P1** = serious but gated / latent / scale-horizon — fix before the affected surface goes live or scales. **P2** = hygiene / defense-in-depth / consistency.

**Programs (extensible — one per audit):**
- **PROGRAM ICA** — *Interim Certification Audit* (ERP foundation, 2026-07-20) — **populated below.**
- **PROGRAM QIE-AUDIT** — *reserved* — to be populated from the QIE audit session using this exact structure.
- **PROGRAM UXR** — *Product Experience (UI/UX) Certification Audit* (Web/Android/iOS/Tablet, 2026-07-21) — **populated below** (fulfils the reserved PROGRAM UIUX-AUDIT slot); finding-level annex: [`UXR_FINDINGS_REGISTER.md`](UXR_FINDINGS_REGISTER.md).
- *(further audits append their own PROGRAM here.)*

---

### PROGRAM ICA — INTERIM CERTIFICATION AUDIT REMEDIATION 🔴

**Source:** [`docs/engineering/INTERIM_CERTIFICATION_AUDIT_2026-07-20.md`](../engineering/INTERIM_CERTIFICATION_AUDIT_2026-07-20.md) — 12 independent expert reviewers audited the **canonical trunk `integration/w0-canonical`** (the certified baseline); every Critical/High finding was adversarially verified against real code (7 CONFIRMED, 8 PARTIAL/re-severitied, 2 REFUTED). Verdict: **INTERIM CERTIFIED — Continue After Moderate Corrections.**

**Program laws:**
- **Nothing lost:** all 49 items below plus the verified-safe register (§ICA-VS) are recorded; deletion/merge/re-scope requires an APPENDIX C entry.
- **Trunk-scoped:** all `file:line` evidence is against the `integration/w0-canonical` worktree at audit time. **Re-verify each on the converged trunk (W0/W1) before fixing** — line numbers may shift; the defect logic is the durable part.
- **EOS-gated + race-pattern law:** every money-write fix must apply the project's Money-Integrity race pattern (`AND status='<pre>'` + throw-on-0-rows) and land with a regression guard. No ICA item is "done" without an EOS PASS on its slice.
- **These are corrections to *already-shipped/certified* code** — the PRA lesson holds: a prior cert or green test is not evidence; verify the actual logic.

#### ICA priority & wave index (all 49 items)

| ID | Item | Class | Pri | Trace | Feeds |
|---|---|---|---|---|---|
| **ICA-A1** | Money-unit `_minor` fragmentation → **live 100× understatement** in recovery dashboard | Finance / Data Model | **P0** | CR-1 | W3 |
| **ICA-A2** | Offline-instrument reconcile **double-credit race** (no row lock, wrong terminal guard) | Finance / Engineering | **P0** | CR-3 | W3 |
| **ICA-A3** | Receipt-number global UNIQUE **collision blocks a school's collections** | Finance / Data Model | P1 | CR-4 | W3 |
| **ICA-A4** | Universal idempotency wrapper **non-atomic / key-poisoning**, defeats money-safe backstop | Finance / Engineering | P1 | CR-6 | W3 |
| **ICA-A5** | Unsigned webhook accepts **forged capture** in stub mode → fraudulent paid receipt | Finance / Security | **P0** | CR-7 | W3 |
| **ICA-A6** | Payment tables INTEGER rupees vs finance NUMERIC(12,2) — **paise can't round-trip** | Finance / Data Model | P1 | §6/CR-1 | W3 |
| **ICA-A7** | Money-integrity guards verified only against mocks → add **real-Postgres concurrency tests** | Engineering / QA | P1 | §6 (T2) | W3/W10 |
| **ICA-B1** | Incomplete guardian-unlink RLS → **de-authorized guardian reads revoked child's records** | Security | **P0** | CR-2 | W2/W11 |
| **ICA-B2** | OTP returned in login response for **privileged pilot phones in production** | Security | P1 *(P0 before GA)* | §6 (S2) | W2/W11 |
| **ICA-B3** | SECURITY DEFINER onboarding/subscription fns have **no in-DB tenant/role guard** | Security | P1 | §6 (S1) | W2/W10 |
| **ICA-B4** | OTP stored as **unsalted SHA-256** of a 6-digit code (reversible on DB dump) | Security | P2 | §6 (S3) | W11 |
| **ICA-B5** | Internal health token compared with **non-constant-time** equality | Security | P2 | §6 (S4) | W10 |
| **ICA-B6** | `audit_events` INSERT policy doesn't bind **`school_id`** to caller scope | Security / Data Model | P2 | §6 (S5) | W2/W10 |
| **ICA-B7** | Support mirror bridge **trusts attacker-chosen incident id** on first insert | Security | P2 | §6 (S6) | W11 |
| **ICA-B8** | `handleRevokeSession` revokes refresh tokens **without an owner check** | Security | P2 | §6 (S7) | W2 |
| **ICA-B9** | `setRequestContext` before a `service_role` query is a **misleading no-op** | Security / Engineering | P2 | §6 (MT3) | W10 |
| **ICA-C1** | `attendance_records` (highest-volume table) has **no tenant/student index** | Performance | P1 | CR-5 | W10 |
| **ICA-C2** | Director/management dashboards recompute **all-time aggregates** synchronously, no cache | Performance | P1 | §6 (P1) | W10 |
| **ICA-C3** | `listAttendanceSessions` **unbounded** (no LIMIT/date), per-row count join | Performance | P1 | §6 (P2) | W10 |
| **ICA-C4** | `bulkAssignFeeStructure` **N+1 storm** (~9 queries × student in one txn) | Performance | P1 | §6 (P3) | W4/W10 |
| **ICA-C5** | Per-isolate connection pool has **no global ceiling** (needs pooler) | Performance / Operational | P1 | §6 (P4) | W10 |
| **ICA-C6** | Broadcast fan-out **silently truncates** recipients > 5,000 | Performance / Operational | P1 | §6 (P5) | W4/W10 |
| **ICA-C7** | Generic list store uses OFFSET + **uncached `count(*)`** per page | Performance | P2 | §6 (P6) | W10 |
| **ICA-D1** | Idempotency replay **ignores method/path fingerprint** → wrong-response replay | Engineering | P1 | §6 (E1) | W10 |
| **ICA-D2** | Copy-pasted `isUniqueViolation` / SAVEPOINT idioms → **extract shared DB kernel** | Engineering | P2 | §6 (E2) | W10 |
| **ICA-D3** | `request_idempotency` has **no retention/reaper** (unbounded growth + orphan rows) | Engineering / Operational | P2 | §6 (E3) | W10 |
| **ICA-D4** | CI merge gate runs **zero real-DB tests** (RLS/isolation env-gated, skipped) | Operational / QA | P1 | §6 (T1) | W10 |
| **ICA-D5** | Idempotency exactly-once tested only with in-memory FakeStore → **real atomic-claim test** | QA | P2 | §6 (T3) | W10 |
| **ICA-D6** | Approval SoD FakeDb has no status guard → **double-decide path untested** | QA | P2 | §6 (T4) | W10 |
| **ICA-D7** | Coverage gate is 60% line-only, **client-only** (backend + assertion-quality unmeasured) | QA | P2 | §6 (T5) | W10 |
| **ICA-E1** | No DB single-current-enrollment guarantee → concurrent enroll can leave **two `is_current`** | Data Model | P1 | §6 (D2) | W3/W10 |
| **ICA-E2** | Operational tables use **soft FKs** (no referential integrity / cascade) | Data Model | P2 | §6 (D3) | W10 |
| **ICA-E3** | **Inconsistent migration idempotency guards** (mixed `IF NOT EXISTS`) | Database | P2 | §6 (D4) | W10 |
| **ICA-F1** | Auth/RBAC as 656 copy-paste call sites, not middleware — **reinforces the W10 central chokepoint** | Architecture | P1 | §6 (A11) | W10 |
| **ICA-F2** | `students` identity table has **three writers, no owning service** (orphan rows) | Architecture | P1 | §6 (A7) | W2/W10 |
| **ICA-F3** | **God-files** (transport_write 1,953; pilot_operations 3,313; app_router.dart 3,056) | Architecture | P2 | §6 (A4) | W10 |
| **ICA-F4** | Order-dependent routing with greedy prefix guards → **prefix→router registry** | Architecture | P2 | §6 (A5) | W10 |
| **ICA-F5** | Two-tier JSONB/relational persistence with soft cross-module refs → **invariant + reconcile job** | Architecture | P2 | §6 (A6) | W10 |
| **ICA-F6** | `inventory_finance` HTTP surface **split across two routers** | Architecture | P2 | §6 (A8) | W10 |
| **ICA-F7** | Raw SQL in 25 handler files → move into **repository layer** | Engineering | P2 | §6 (A9) | W10 |
| **ICA-F8** | Dead no-op loop in finance_router + 44 **hot-path dynamic imports** | Engineering | P2 | §6 (A10) | W10 |
| **ICA-G1** | `domain_events` "outbox" **flips to published without dispatch** → decide bus vs log | Architecture / Product | P1 *(owner)* | §6 (A1) | W6 |
| **ICA-G2** | Entitlement enforcement **defaults OFF** → go-live gate + pre-flip plan audit | Operational / Product | P1 *(owner)* | §6 (A3) | W6 |
| **ICA-G3** | Role/permission catalog is **global (no tenant scope)** vs planned custom roles | Product | P1 *(owner)* | §6 (A2) | W2/W6 |
| **ICA-G4** | Client mock/real boundary **not fail-closed** → ASIP support shows **fabricated tickets** | Implementation / Product | P1 | §5 (Principal Arch) | W8 |
| **ICA-H1** | Term tabulation **drops same-subject exams** sharing a term label → wrong report cards/rank | Data Model / Product | P1 | §6 (DOM1) | W4/W5 |
| **ICA-H2** | TC asserts "all dues cleared" while **inventory advisory / library key-fragile** | Product | P1 | §6 (DOM2) | W4 |
| **ICA-H3** | Management attendance aggregate returns **0% (not null)** on zero denominator | Implementation | P2 | §6 (DOM3) | W4 |
| **ICA-H4** | Student-risk engine **fabricates optimistic 92%/85% defaults** (safeguarding blind spot) | Product | P1 | §6 (DOM4) | W5 |

---

#### Wave ICA-A — Finance Integrity (feeds **W3 Money & Data Integrity**) — 5×money-path + unit + test

> The core direct-collection path is verified sound (FOR UPDATE, status-guards, atomic receipt seq); these are the *peripheral* money paths and the money-unit layer. **Do before extending the finance domain** (installments, recovery, Tally map, payroll postings are all in flight in W3/EIP).

- **ICA-A1 — Money-unit `_minor` fragmentation → live 100× understatement** · Finance/Data Model · **P0** · CR-1
  - **Evidence:** `_minor` means BIGINT paise in recovery (`20260823000000_finance_recovery_crm.sql:65,116`) + concessions (`20260822000000_fee_concessions.sql:24`), but NUMERIC(12,2) **rupees** in installments/head-allocations (`20260827000000_finance_installments_head_allocations.sql:36,82-83`, migration comment lines 18-21 confirms rupee scale); a 3rd form is INTEGER whole rupees (`20260614600000_universal_payment_engine.sql:12,40`). **Live bug reproduced by the verifier:** `finance_recovery_repository.ts:437-440` sums `finance_collections.amount_collected` (NUMERIC **rupees**), labels it `recovered_this_month_minor`, then `handlers.ts:346,356,578-581` divides by 100 via `minorToRupees` → "recovered this month" and per-collector `amountRecovered` **understated 100×**; `attainmentPct` (`handlers.ts:359-360`) divides rupee-scale by paise-scale target. Input path `amountMinor` (`handlers.ts:46-50`) is a no-op that never scales the rupee text sent by `finance_recovery_actions.dart:224-227`.
  - **Fix:** standardize one money unit across `_shared/finance/` (recommend integer paise everywhere, matching the gateway boundary); rename the NUMERIC columns that are *not* minor units (`amount_minor`/`head_total_minor`/`head_paid_minor`); correct the recovery repository/handlers scaling; add a repository-level unit assertion and a cross-table test that fails if any `_minor` column is not BIGINT.
  - **Done-when:** recovery dashboard shows correct rupee figures against a seeded ledger; a schema test enforces the `_minor`=BIGINT invariant; EOS RELIABILITY PASS on the recovery slice.

- **ICA-A2 — Offline-instrument reconcile double-credit race** · Finance/Engineering · **P0** · CR-3
  - **Evidence:** `finance_offline_payments_repository.ts:224-293` — `getOfflinePayment` is a **plain unlocked SELECT** (`216-220`), then `status==='reconciled'` check (`241`), then `createCollection` (`258`), then terminal UPDATE guarded only by `AND status <> 'bounced'` (`281`) — **not** `AND status='pending_reconciliation'`. Two concurrent reconciles both read `pending`; against an invoice with outstanding ≥ 2× the amount, `createCollection`'s invoice `FOR UPDATE` guard (`amountCollected > outstanding`) rejects neither → **two collections booked for one cheque/DD**. No idempotencyKey passed (`258-268`) so the partial-unique replay index is inert. Only test uses a mock that ignores the guard and never counts posted rows (`qa_x_022_offline_reconcile_integrity_test.ts`).
  - **Fix:** `SELECT … FOR UPDATE` the instrument row before the reconciled-check; make the terminal UPDATE the atomic guard (`AND status='pending_reconciliation'` + throw-on-0-rows); add a unique constraint tying an instrument to ≤1 collection; add a concurrent live cert (two threads, outstanding ≥ 2× amount, assert exactly one collection).
  - **Done-when:** concurrent double-reconcile posts exactly one collection (live cert green); regression guard in place.

- **ICA-A3 — Receipt-number global UNIQUE collision blocks a school's collections** · Finance/Data Model · P1 · CR-4
  - **Evidence:** `finance_receipts.receipt_number` is `TEXT NOT NULL UNIQUE` with **no org/school scope** (`20260612500000_finance_slice4_collections.sql:30`); the sequence formats `${prefix}/${fiscalYear}/${seq}` with prefix default `"RCP"` and `seq` from a **per-(org,school,fiscal_year)** counter restarting at 1 — no discriminator in the string (`finance_collections_repository.ts:245-259`). Two schools sharing default prefix + fiscal year generate `RCP/2026-27/000001`; the second's first collection INSERT throws duplicate-key and the whole transaction rolls back → school cannot record its first payment (availability-isolation break). Gated behind opt-in receipt-sequencing (default off).
  - **Fix:** scope the UNIQUE to `(organization_id, receipt_number)` (or `(organization_id, school_id, receipt_number)`) and/or embed a school code in the formatted number; enforce distinct per-school prefixes at the settings layer.
  - **Done-when:** two schools in one org with default prefix both record collection #1; migration test asserts the scoped uniqueness. **Gate:** must land before receipt-sequencing is enabled for any multi-school org.

- **ICA-A4 — Universal idempotency wrapper non-atomic / key-poisoning** · Finance/Engineering · P1 · CR-6
  - **Evidence:** `idempotency_dispatch.ts` runs `claim()` (`:115`), the write (`dispatch()`→handler's own txn), and `store()` (`:146`) in **three separate transactions**; `store()` is outside try/catch. A crash or `store()` throw after the write commits leaves `response_payload IS NULL` → every retry hits `ON CONFLICT DO NOTHING` → permanent **409**, and a `store()` throw returns **500 for a committed payment**. Because the wrapper short-circuits at `claim()` before dispatch, its poisoned 409 **preempts the inner finance backstop** (`finance_collections_repository.ts:391-405`) — the generic layer defeats the money-safe layer. No TTL/reaper exists (verified: zero cleanup across migrations/functions; sole DELETE is `release()` for NULL rows, unreached on crash).
  - **Fix:** claim+write+store in one transaction (the generic entity-write path `module_write_handlers.ts` already does this), OR add a bounded in-flight TTL so a stale NULL-payload claim is re-claimable + a reaper; wrap `store()`; yield to the route's own replay on an in-flight row.
  - **Done-when:** a simulated crash between commit and store is recoverable on retry (no permanent 409, no 500-for-succeeded); EOS RELIABILITY PASS.

- **ICA-A5 — Unsigned webhook accepts forged capture in stub mode** · Finance/Security · **P0** · CR-7
  - **Evidence:** `verifyRazorpayWebhookSignature` returns `true` when `stubMode && signature===null` (`razorpay_client.ts:87-89`); `RAZORPAY_STUB_MODE` defaults `'true'` (`razorpay_config.ts:14-21`). Webhook route is public — `verify_jwt=false` (`config.toml:26`), no `authenticateRequest` (`payment_router.ts:19-21`); RT-23 guard `if(!valid && !allowUnsigned)` (`payment_handlers.ts:205-216`) never fires for a null signature. An authenticated parent who has an order id (returned by `initiatePayment`, `payment_service.ts:214`) POSTs an unsigned `payment.captured`; `processRazorpayWebhook` (`payment_service.ts:407-431`) writes a `finance_collection` + `finance_receipt` and marks captured — **zero real payment** (capped one/intent by the `status==='captured'` early-return; fresh randomUUID eventId bypasses the replay guard).
  - **Fix:** enforce webhook signatures independently of `stubMode` (bypass only under an explicit `RAZORPAY_ALLOW_UNSIGNED` dev flag), or refuse capture events while stub mode is on; never treat a null signature as valid.
  - **Done-when:** an unsigned capture POST is rejected on the pilot config; signed happy-path still passes. **Gate:** must land before the payment webhook route is exposed on any deployed build and before the live gateway (P0-02) is enabled.

- **ICA-A6 — Payment tables INTEGER vs finance NUMERIC(12,2) — paise can't round-trip** · Finance/Data Model · P1 · §6/CR-1
  - **Evidence:** `payment_requests.amount` / `payment_intents.amount` are INTEGER whole rupees (`20260614600000_universal_payment_engine.sql:15,39`); on capture the INTEGER intent amount is passed into the NUMERIC(12,2) collection (`payment_service.ts:316,422`). A fee installment carrying paise (₹1500.50) is truncated on the payment path. Latent while data is whole-rupee.
  - **Fix:** part of the ICA-A1 unit unification — store payment amounts as integer paise everywhere (convert at the gateway boundary as today) or use NUMERIC(12,2) in payment tables; add a guard rejecting fractional-rupee amounts on the integer path until unified.
  - **Done-when:** a paise-bearing installment round-trips through the payment path without truncation, or is explicitly rejected with a clear error.

- **ICA-A7 — Money-integrity real-DB concurrency tests** · Engineering/QA · P1 · §6 (T2)
  - **Evidence:** `finance_collections_repository_test.ts` / `finance_fee_reductions_repository_test.ts` run against a `MockDb` that pattern-matches SQL substrings and **re-implements the guard in JS** (e.g. `finance_fee_reductions_repository_test.ts:190`), so dropping `AND status='pending'` or `FOR UPDATE` from the real SQL would leave the tests green. The real concurrency is proven only by out-of-gate live certs (`live_cert_red_team_wave1.py`), which cover the direct-collection path but not cancel/version races or offline-reconcile.
  - **Fix:** add real-Postgres concurrency tests per money-mutating repository (create/cancel/refund/reconcile) that fire two concurrent guarded UPDATEs and assert exactly one wins (0-row throw on the loser); run in CI against an ephemeral/local DB.
  - **Done-when:** the money-race pattern is verified against real SQL in an always-on gate (ties to ICA-D4). *Co-requisite of ICA-A2/A4.*

#### Wave ICA-B — Security & Access-Control Hardening (feeds **W2 Identity / W11 Security**) — 9 items

- **ICA-B1 — Incomplete guardian-unlink RLS leak** · Security · **P0** · CR-2
  - **Evidence:** PRA-P1-02 added `AND status='active'` only to finance+enrollments (`20260900000012_guardian_active_link_rls_fix.sql:32`). **Five parent-facing read policies still gate on ANY guardian link, no status filter** (current definitions): `attendance_records_parent_student_read` (`20260706000000:37-41`), `exam_mark_entries_school` (`20260614830000:11-15`), `exam_remarks_access` (`20260629000000:42-46`), `homework_submissions_parent_read` (`20260836000000:76-80`), `intel_parent_guidance_parent_scope` (`20260802000000:36-40`). `app_current_parent_user_id()` (`20260609100000:177-183`) has no status restriction; the unlink writer sets `status='inactive'` (row retained). A guardian active for Child A but revoked for Child B in the same school reads Child B's attendance, exam marks, teacher remarks, homework, and AI guidance (RLS is the true boundary, independent of UI).
  - **Fix:** re-create the five policies verbatim with `AND status='active'` on every `student_guardians` sub-select (matching the canonical students policy `20260609100000:262-263`); add a **permanent guard test** scanning every parent-scope guardian sub-select for the active-status predicate (the homework-hardening migration already reintroduced this once).
  - **Done-when:** an inactive-link guardian gets 0 rows for the revoked child across all five surfaces; regression scanner green in CI.

- **ICA-B2 — OTP returned in login response for privileged pilot phones in production** · Security · P1 *(P0 before GA)* · §6 (S2)
  - **Evidence:** `auth_handlers.ts:102-106` `canReturnOtpInResponse` returns true when `config.otpPilotPhones.includes(phone)` with **no environment check** (only the dev-mode branch is env-gated); `handleRequestOtp` (`:336-344`) returns the plaintext OTP in the `/auth/login` JSON body. Source: `AUTH_OTP_PILOT_PHONES` (`config.ts:105`); these are owner/superadmin/support principals (per memory, used deliberately to avoid SMS cost). Anyone who knows a pilot phone number can complete login with no SMS possession.
  - **Fix:** gate the pilot-phone response path behind `environment!=='production'` (or a separate explicit flag) or deliver via a side channel; keep the allowlist empty of any real privileged phone.
  - **Done-when:** production login never returns an OTP in the body; **hard GA gate:** no owner/superadmin phone in the allowlist at GA.

- **ICA-B3 — SECURITY DEFINER onboarding/subscription fns lack in-DB guardrails** · Security · P1 · §6 (S1)
  - **Evidence:** `onboarding_ensure_school_membership(p_user_id,p_school_id,p_role)` is SECURITY DEFINER granted to `erp_tenant` with **no check** that `p_school_id` matches `app_current_school_id()/tenant` and **no role allowlist** (`20260615110000_onboarding_user_provisioning_fix.sql:42-80`); `onboarding_upsert_user_by_phone` updates users by phone **globally** with no tenant predicate (`:5-40`); `assign_organization_subscription` upserts a plan for **any org id passed in** with no in-function auth (`20260718000000_subscription_assignment_secdef.sql:18-70`). Safe today only because single app-layer callers gate them (`requirePermission`, server-derived ids).
  - **Fix:** add in-function assertions — verify `p_school_id` belongs to `app_current_tenant_id()` / matches `app_current_school_id()`, constrain `p_role` to an allowlist, and re-check a platform GUC/membership for the subscription fn (match the mirror-bridge pattern which derives scope from the session GUC).
  - **Done-when:** each DEFINER fn rejects a caller-supplied cross-tenant/out-of-allowlist argument at the DB layer.

- **ICA-B4 — OTP stored as unsalted SHA-256** · Security · P2 · §6 (S3)
  - **Evidence:** `auth_handlers.ts:315` `hashToken(otp)` where `hashToken` (`jwt.ts:101-107`) is plain unsalted SHA-256; a 6-digit OTP has 10⁶ preimages → reversible instantly from a DB dump (mitigated by single-use, 5-min TTL, attempt lockout).
  - **Fix:** HMAC the OTP under a server secret (JWT secret is available) or per-row salt. **Done-when:** a leaked `otp_hash` is not reversible without the server secret.

- **ICA-B5 — Internal health token non-constant-time compare** · Security · P2 · §6 (S4)
  - **Evidence:** `internal_health_auth.ts:21` compares with plain `!==` (short-circuits on first differing byte); guards `/health/tenant-access` etc. **Fix:** use the existing `timingSafeEqualHex`. **Done-when:** the health token compare is constant-time.

- **ICA-B6 — `audit_events` INSERT doesn't bind `school_id`** · Security/Data Model · P2 · §6 (S5)
  - **Evidence:** `20260614500000_audit_ingestion_domain_events.sql:74-78` WITH CHECK verifies only `organization_id = app_current_tenant_id()` + scope, no `school_id = app_current_school_id()` (contrast the SELECT policy and finance write policy). A school-scoped caller can mis-tag another school's audit row within its org (no cross-tenant impact; append-only preserved). **Fix:** add `AND (school_id IS NULL OR school_id = app_current_school_id())` to WITH CHECK. **Done-when:** an audit row can't be attributed to a non-active school.

- **ICA-B7 — Support mirror bridge trusts attacker-chosen incident id on first insert** · Security · P2 · §6 (S6)
  - **Evidence:** `20260920000040_support_platform_mirror.sql:208-254` — `app_support_mirror_incident()` derives org/school from GUC (good) but the INSERT (`236-244`) accepts a caller-supplied `p_incident` uuid with **no check that a school-side incident with that id exists/belongs to `v_org`**; UPDATE path is protected but a first-time INSERT of an arbitrary id is not (exploitation needs guessing an unguessable v4 uuid → minimal, but it's a DEFINER RLS-bypass path). **Fix:** add `EXISTS(SELECT 1 FROM support_incident WHERE id=p_incident AND organization_id=v_org)` before INSERT (matches `app_support_mirror_evidence`). **Done-when:** mirror only accepts incidents the caller's org owns.

- **ICA-B8 — `handleRevokeSession` revokes refresh tokens without owner check** · Security · P2 · §6 (S7)
  - **Evidence:** `auth_handlers.ts:694-702` — the sessions UPDATE is scoped `.eq('id',sessionId).eq('user_id',claims.sub)` but the following `refresh_tokens` UPDATE is scoped only `.eq('session_id',sessionId)` with no user_id constraint → a caller who knows another user's session UUID revokes that victim's refresh tokens (forced-logout DoS; low exploitability since session_id isn't exposed cross-user). **Fix:** constrain the refresh-token revoke to sessions with `user_id = claims.sub`. **Done-when:** revoking another user's session id is a no-op.

- **ICA-B9 — `setRequestContext` before a `service_role` query is a misleading no-op** · Security/Engineering · P2 · §6 (MT3)
  - **Evidence:** `request_context.ts:5-28` sets RLS GUCs via a PostgREST RPC on a `service_role` client; `handleMe` (`auth_handlers.ts:713`) calls it then `client.from("users")…`. The DB fn uses `set_config(...,true)` (transaction-local) but PostgREST runs each RPC/`.from()` as a separate transaction, so the context doesn't persist — and `service_role` bypasses RLS anyway. Safe only because the query is independently `.eq("id", claims.sub)` filtered; a future list query copying the idiom without an explicit filter would leak cross-tenant. **Fix:** remove the misleading `setRequestContext` on `service_role` clients, or route tenant data exclusively through `withTenantContext` (the non-bypass `erp_tenant` path); mark `service_role` clients as RLS-exempt so manual filters are mandatory. **Done-when:** no `service_role` tenant-data read relies on an inert GUC.

#### Wave ICA-C — Performance & Scalability (feeds **W10 Engineering Hardening**) — 7 items

> Weakest audited dimension (Scalability 62). Invisible at pilot scale; **gating before multi-school scale-out.** CR-5 is a one-line, high-leverage fix.

- **ICA-C1 — `attendance_records` missing tenant/student index** · Performance · P1 · CR-5
  - **Evidence:** `20260614800000_pilot_operations.sql:21-33` — only `PK(id)` + `UNIQUE(session_id, student_id)`; no index (across all 244 migrations) serves the hot predicates. Parent snapshot filters `student_id` (`pilot_operations_repository.ts:927-935`); director dashboard `GROUP BY school_id` on `organization_id` (`director_repository.ts:132-137`); management filters org+school (`management_aggregate_repository.ts:113-119`); the risk board runs a `LEFT JOIN LATERAL` **per active student** (`student_risk_repository.ts:57-72`, quadratic). Table grows students × school-days (~100M rows/yr @ 1,000 schools).
  - **Fix:** `CREATE INDEX idx_attendance_records_student ON attendance_records (organization_id, school_id, student_id)` + `(organization_id, school_id)`; re-EXPLAIN the three cited queries.
  - **Done-when:** the three queries use the index (EXPLAIN); risk-board no longer seq-scans. **Gate:** before multi-school scale-out.

- **ICA-C2 — Director/management dashboards recompute all-time aggregates** · Performance · P1 · §6 (P1)
  - **Evidence:** `director_repository.ts:88-146` fires six org-scoped GROUP BY scans per load; only admissions has a 90-day window; **attendance_records and exam_mark_entries are aggregated all-time** with no bound, no cache/materialized view; `management_aggregate_repository.ts:113-119` repeats the pattern per school. Combined with ICA-C1 the attendance sub-query is a full seq-scan-and-group.
  - **Fix:** bounded windows (current academic year / trailing period) for attendance + marks aggregates; back the org dashboard with a periodically-refreshed materialized view or cached snapshot table.
  - **Done-when:** dashboard cost is bounded by the current period, not lifetime history; a cache/matview amortizes repeat loads.

- **ICA-C3 — `listAttendanceSessions` unbounded** · Performance · P1 · §6 (P2)
  - **Evidence:** `attendance_sessions_repository.ts:38-52` — `SELECT s.*, count(ar.id) … LEFT JOIN attendance_records … GROUP BY s.id ORDER BY s.session_date DESC` with **no LIMIT/OFFSET, no date filter**; caller (`attendance_handlers.ts:110-121`) reads no page/limit param. (Verifier note: existing indexes blunt the join, so Medium not the original "un-indexed 100M-row scan.")
  - **Fix:** add pagination (page/pageSize, hard cap like the generic store's 100) + a default date window; compute `record_count` via an indexed sub-select or denormalized counter.
  - **Done-when:** the endpoint returns a bounded, paginated page with a date default.

- **ICA-C4 — `bulkAssignFeeStructure` N+1 storm** · Performance · P1 · §6 (P3)
  - **Evidence:** `finance_assignments_repository.ts:566-596` loops per student calling `assignFeeStructure` (`:480`), each ~7 sequential queries + a SAVEPOINT round-trip → a 60-student class ≈ 540 sequential round-trips in one long transaction holding row locks.
  - **Fix:** batch reads (`= ANY($ids)` for students/accounts/duplicates), do assignment/account inserts as multi-row INSERTs, reserve per-row SAVEPOINT only for the rare unique-violation race.
  - **Done-when:** whole-class assignment is a bounded number of set-based queries, not O(students).

- **ICA-C5 — Per-isolate connection pool has no global ceiling** · Performance/Operational · P1 · §6 (P4)
  - **Evidence:** `tenant_db.ts:16` `POOL_SIZE = 10` per **isolate**; `tenantPool()` (`20-30`) creates one Pool per edge isolate with no cross-isolate budget. Under a multi-school spike, total connections = 10 × isolate_count → can breach Postgres `max_connections` (the exact RT-35 cascade, now per-isolate-bounded but aggregate-unbounded); no PgBouncer/Supavisor evident.
  - **Fix:** front tenant connections with a transaction-mode pooler (PgBouncer/Supavisor) and/or lower `POOL_SIZE` with an explicit global budget sized to `max_connections` × expected concurrency.
  - **Done-when:** aggregate connection count is bounded under load; a pooler sits in front. **Gate:** before multi-school scale-out.

- **ICA-C6 — Broadcast fan-out silently truncates > 5,000 recipients** · Performance/Operational · P1 · §6 (P5)
  - **Evidence:** `communication_service.ts:42` `MAX_BROADCAST_RECIPIENTS=5000`; `:369,560` apply `slice(0, MAX)` before `enqueueDeliveriesBatch` — recipients past 5,000 are dropped with **no error/continuation**. The enqueue itself is an efficient single multi-row INSERT.
  - **Fix:** chunk the cohort into successive batched inserts (queued job) so all recipients enqueue, or surface an explicit partial-send error when the cohort exceeds the cap.
  - **Done-when:** a > 5,000-recipient broadcast either reaches everyone or fails loudly with a partial-result report.

- **ICA-C7 — Generic list store OFFSET + uncached `count(*)`** · Performance · P2 · §6 (P6)
  - **Evidence:** `entity_read_store.ts:92-110` runs a `count(*)` on every page then `ORDER BY id LIMIT $4 OFFSET $5`; pageSize is capped at 100 but deep OFFSET scans/discards preceding rows and the count re-scans per page. **Fix:** keyset/seek pagination (`WHERE id > $lastId ORDER BY id LIMIT n`) for large collections; return total only on the first page or via a cached/approximate count. **Done-when:** deep pages don't scan-and-discard; count isn't recomputed per page.

#### Wave ICA-D — Engineering Reliability & Test/CI (feeds **W10**) — 7 items

- **ICA-D1 — Idempotency replay ignores method/path fingerprint** · Engineering · P1 · §6 (E1)
  - **Evidence:** both idempotency impls persist method+path (`idempotency_dispatch.ts:186-190`; `module_write_handlers.ts:66-71`) but the replay SELECT reads only status_code+payload and **never compares** stored method/path to the incoming request (`idempotency_dispatch.ts:198-201`) → reusing one Idempotency-Key across two endpoints replays the wrong response or a spurious 409.
  - **Fix:** on a claim conflict, compare stored method+path (already persisted) to the current request and return 422/409 "key reused with a different request" instead of blindly replaying; optionally store+compare a body hash. **Done-when:** cross-endpoint key reuse is rejected, not mis-replayed.

- **ICA-D2 — Extract shared DB kernel (isUniqueViolation / SAVEPOINT)** · Engineering · P2 · §6 (E2)
  - **Evidence:** `isUniqueViolation` re-defined in 6 repositories (transport_write, transport_allocation_history, certificate_desk, admissions, pilot_operations, finance_assignments); SAVEPOINT/ROLLBACK-TO-SAVEPOINT idempotency-recovery duplicated (`finance_assignments_repository.ts:558-596` ≈ `transport_write_handlers.ts insertDemandIdempotent`); `db.ts` exposes only `createServiceClient`. Money-race recovery logic maintained in 5-6 places. **Fix:** extract `isUniqueViolation` + a `withSavepoint(...)` helper into the shared `db`/`tenant_db` kernel; consume everywhere. **Done-when:** one implementation of each idiom.

- **ICA-D3 — `request_idempotency` retention/reaper** · Engineering/Operational · P2 · §6 (E3)
  - **Evidence:** `20260814000000_red_team_wave1_transactional_integrity.sql` creates the table with a JSONB `response_payload` but **no TTL/partition/cleanup**; the only DELETE is `release()` for NULL rows. Completed rows + orphan NULL rows (aborted in-flight) grow unbounded under the DRP offline-replay load. **Fix:** scheduled prune (delete completed rows older than the client retry horizon, NULL rows older than a short in-flight timeout) or time-based partitions with auto-drop. *(Co-requisite of ICA-A4's TTL.)* **Done-when:** the table is bounded; orphan NULL rows self-heal.

- **ICA-D4 — CI merge gate runs zero real-DB tests** · Operational/QA · P1 · §6 (T1)
  - **Evidence:** the three DB-touching tests are env-gated and skipped in CI: `tenant_isolation_test.ts:12` (`!supabaseUrl||!serviceKey`), `tenant_isolation_enforced_test.ts:16` + `approval_isolation_probe_test.ts:71` (`!hasTenantUrl`); `backend_staging.yml:46` runs `deno test` with none of those env vars and no postgres service. RLS/cross-tenant + money-race guards never execute in the gate. **Mitigation exists (verifier):** `/health/tenant-access` runs the same 233-probe suite at runtime and is asserted by ~8 deploy/launch verification scripts, plus a `MIN_PROBE_COUNT=233` unit tripwire — so a leak is caught at deploy/health time, not PR time.
  - **Fix:** add a postgres service (or `supabase start`) to the validate job + DB env vars so isolation + money-race probes run on every PR, and **fail (not skip)** when the isolation env is absent in CI. **Done-when:** a green CI build means isolation + money-race were actually executed. *(Absorbs ICA-A7/D5/D6 into the same gate.)*

- **ICA-D5 — Idempotency real atomic-claim test** · QA · P2 · §6 (T3)
  - **Evidence:** every idempotency test injects an in-memory `FakeStore` (`idempotency_dispatch_test.ts:31-41`); the real `INSERT … ON CONFLICT DO NOTHING` claim is never executed; the "concurrent in-flight → 409" test runs sequentially, not concurrently. **Fix:** real-DB test firing two concurrent claims on one (org,key) asserting exactly one `claimed:true`; assert the unique constraint exists. **Done-when:** the ON-CONFLICT atomic-claim guarantee is verified against Postgres.

- **ICA-D6 — Approval SoD double-decide test** · QA · P2 · §6 (T4)
  - **Evidence:** `approval_separation_of_duties_test.ts` FakeDb echoes an 'approved' row for any decision UPDATE regardless of current status (`62-71`); no test decides an already-approved/rejected request, so a lost already-decided guard would pass green. **Fix:** seed `status:'approved'`/`'rejected'` and assert `decideApproval` rejects/no-ops. **Done-when:** re-decide on a value-gating approval is covered.

- **ICA-D7 — Backend coverage / assertion-quality gate** · QA · P2 · §6 (T5)
  - **Evidence:** `check_coverage_threshold.sh:20` `COVERAGE_MIN=60` parses `flutter test` lcov — **client-only line coverage**; the Deno backend (all finance/RBAC/tenant logic) is outside the measured surface, and line coverage ignores assertion quality. **Fix:** add backend coverage to the gate and track assertion quality (e.g. mutation-testing on finance/RBAC/tenant modules). **Done-when:** backend is measured and the gate reflects assertion strength, not just execution.

#### Wave ICA-E — Data Model Integrity (feeds **W3 / W10**) — 3 items

- **ICA-E1 — No DB single-current-enrollment guarantee** · Data Model · P1 · §6 (D2)
  - **Evidence:** `sis_student_enrollments` has `UNIQUE(student_id, academic_year)` but only a **non-unique** partial index for current rows (`20260613000000_sis_slice0_foundation.sql:86-88`); single-current is enforced only at app level by `clearCurrentEnrollmentsForStudent()` + INSERT (`sis_enrollments_repository.ts:319-345`, read-then-write, no lock); `getCurrentEnrollmentId` tolerates duplicates via `ORDER BY created_at DESC LIMIT 1`. Concurrent enroll/promote can commit two `is_current=true` rows under READ COMMITTED → report cards/rosters/certificates may pick the wrong placement.
  - **Fix:** add a partial `UNIQUE(student_id) WHERE is_current=true` so the DB converts the race into a caught 23505. **Done-when:** two concurrent current-enrollments can't both commit.

- **ICA-E2 — Soft FKs on operational tables** · Data Model · P2 · §6 (D3)
  - **Evidence:** `attendance_records.student_id`, `homework_submissions.student_id` (`20260614800000:26,61`), `comm_recipients.user_id` (`20260614700000:120`) are UUID NOT NULL with **no REFERENCES** (deliberate pattern `20260618000000_academic_soft_fk.sql`) → orphan rows possible, no ON DELETE. **Fix:** restore real FKs with explicit ON DELETE where decoupling isn't required; otherwise document the invariant + add periodic orphan-detection. **Done-when:** each soft-FK column either has a real FK or a documented invariant + orphan check.

- **ICA-E3 — Inconsistent migration idempotency guards** · Database · P2 · §6 (D4)
  - **Evidence:** some objects use `IF NOT EXISTS` (`20260900000000`) while core tables don't (`finance_collections`, `stock_movements`); within one migration `ADD COLUMN IF NOT EXISTS` is mixed with unguarded `ADD CONSTRAINT` (`20260830000000:14-24`). A partially-failed migration can't always be safely re-applied. (Ordering itself is clean — 244 monotonic files, zero dup timestamps.) **Fix:** apply `IF NOT EXISTS` / `DROP…IF EXISTS`-then-CREATE consistently, or wrap each migration transactionally all-or-nothing. **Done-when:** every migration is safely re-runnable.

#### Wave ICA-F — Architecture & Maintainability (feeds **W10**) — 8 items

- **ICA-F1 — Auth/RBAC as 656 copy-paste call sites (reinforces the W10 central chokepoint)** · Architecture · P1 · §6 (A11)
  - **Evidence:** dispatch (`api/app.ts:99-221`) enforces no auth; each handler self-calls `authenticateRequest`+`requirePermission`+`withTenantContext` (656 / 725 call sites across 132 handler files). Idempotency + entitlements ARE composition wrappers, so the pattern exists but isn't used for the highest-risk concern. **Verifier note (corrected to Low as a *bug*):** `withTenantContext` **requires typed `AccessTokenClaims`** (only produced by `authenticateRequest`), and the non-bypass `erp_tenant` RLS backstop means a mis-authored handler fails *closed* for tenant isolation — so it's a maintainability/consistency risk, not a live auth-bypass. **This is the same target as the existing W10 "central RBAC chokepoint" item — track ICA-F1 as reinforcing evidence, not a separate build.**
  - **Fix:** introduce an auth/tenant middleware wrapper (analogous to `withEntitlement`) composed once in `routeModuleRequest`; handlers declare only their required permission (removing 656 duplicated sites, using the existing `requireAnyPermission` primitive). **Done-when:** no route can be unauthenticated by omission (W10 exit criterion).

- **ICA-F2 — `students` identity table has three writers, no owning service** · Architecture · P1 · §6 (A7)
  - **Evidence:** three modules `INSERT INTO students` directly — `sis_students_repository.ts`, `admissions_repository.ts:1296`, `onboarding_user_provisioning.ts`. Admissions mints `STU-<random>` + admission-number inline (`:1294-1301`) and creates a base row with no PSID, while SIS allocates the canonical PSID via `allocatePublicStudentId`; the admissions race path knowingly leaves an orphan student row (`~:1338`). Identity rules enforced inconsistently by creator. **Fix:** introduce a single SIS-owned `createStudent()`/identity service that admissions + onboarding call, centralizing code/PSID/admission-number allocation + orphan cleanup. *(Aligns with the frozen Student Identity Architecture + W2 PLAT-0.)* **Done-when:** one owning service mints every student row.

- **ICA-F3 — God-file decomposition** · Architecture · P2 · §6 (A4)
  - **Evidence:** `transport_write_handlers.ts` 1,953; `admissions_handlers.ts` 1,806; `hr_write_handlers.ts` 1,666; `exam_administration_handlers.ts` 1,454; `pilot_operations_repository.ts` 3,313; `exam_administration_repository.ts` 2,749; client `app_router.dart` 3,056; `mock_finance_repository.dart` 3,450. Finance shows the per-concern counter-pattern done well. **Fix:** split along finance's per-concern boundary (~500-line soft ceiling). **Done-when:** the largest handler/repository files are decomposed by concern.

- **ICA-F4 — Prefix→router registry (order-dependent routing)** · Architecture · P2 · §6 (A5)
  - **Evidence:** dispatch is a linear scan over a hand-ordered ~66-router array (`app.ts:105-204`) whose ordering constraints live only in comments; greedy `startsWith` guards return **404 (not null)** on unmatched (`parent_router.ts:152-156`, `finance_router.ts`), so a new `/parent-*` router after `routeParent` is silently shadowed. **Fix:** move to an explicit prefix→router registry (map keyed on mount path, word-boundary aware) or have prefix-owning routers return `null` on unmatched; add a startup assertion detecting overlapping prefixes. **Done-when:** route ownership is declarative and ordering can't shadow siblings.

- **ICA-F5 — Two-tier JSONB/relational persistence invariant** · Architecture · P2 · §6 (A6)
  - **Evidence:** ~11 modules persist domain state as opaque JSONB `{module}_entities` (transport, hostel, library, inventory, alumni, parent, teacher, hr/leave, management, approval) while finance/admissions/sis/academic are relational; cross-module money refs are soft strings with no FK (`transport_write_handlers.ts:578` `String(demand.invoiceId ?? "")` → `finance_invoices`). **Verifier (corrected High→Low):** no hard-delete path for invoices/students exists (cancel-by-status only; `erp_tenant` has no DELETE on student tables) + app-level referential guards + single-transaction lockstep, so refs can't dangle today. **Fix:** document the JSONB↔relational invariant + a reconciliation job for every soft reference, or promote high-integrity JSONB modules (transport demands, library circulation, inventory stock) to relational tables with FKs. **Done-when:** every soft cross-module reference has a documented invariant + reconciliation, or a real FK.

- **ICA-F6 — `inventory_finance` single router** · Architecture · P2 · §6 (A8)
  - **Evidence:** inventory_finance READ routes live in `finance_router.ts:143-164`, WRITE routes in `inventory_router.ts:27,105`; no entry in `app.ts` moduleRouters — one domain split across two parents. **Fix:** give `inventory_finance` one router registered once in `app.ts`. **Done-when:** the domain has a single HTTP home.

- **ICA-F7 — Raw SQL in handler files → repository** · Engineering · P2 · §6 (A9)
  - **Evidence:** 25/148 handler files contain direct `queryObject/queryArray`/SQL bypassing the repository layer (e.g. `finance_collections_handlers.ts:98-109` a 4-table JOIN in `notifyParentOfReceipt`; `transport_write_handlers.ts:1362,1682-1696` queryObject + SAVEPOINT). **Fix:** move direct queries into the corresponding repository modules so handlers orchestrate and repositories own SQL. **Done-when:** handler files hold no raw SQL.

- **ICA-F8 — Dead code + hot-path dynamic imports** · Engineering · P2 · §6 (A10)
  - **Evidence:** `finance_router.ts:514-518` is a no-op loop that reads like UUID validation but validates nothing; 44 `await import()` sit in request hot paths (`mobile_read_handlers.ts` 16, `teacher_handlers.ts` 7, `finance_collections_handlers.ts:322` dynamic audit import). **Fix:** delete the no-op loop; convert hot-path dynamic imports to static top-of-file imports unless a measured cold-start reason justifies lazy loading. **Done-when:** no misleading dead code; no unjustified hot-path dynamic imports.

#### Wave ICA-G — Governance & Platform Seams (feeds **W6 / W8**) — 4 items (3 owner-gated)

- **ICA-G1 — `domain_events` "outbox" flips to published without dispatch** · Architecture/Product · P1 *(owner)* · §6 (A1)
  - **Evidence:** `domain_events_worker.ts:44-53` — `publishPendingDomainEvents` selects pending rows and the sole action per event is `UPDATE domain_events SET status='published'` with **no handler/consumer** between SELECT and UPDATE; the table has full outbox shape but no code consumes `status='published'` (only the AI Signal Refinery is invoked directly). "Published" means "row flipped," not "delivered." Roadmap items assuming a bus (sagas, webhooks, external notifications) have no subscriber seam.
  - **Owner decision:** is `domain_events` an **integration event bus** (add a subscriber-registry dispatch step, at-least-once with the existing retry) or an **internal signal log** (document it, remove bus assumptions)? **Feeds W6.** **Done-when:** the decision is recorded and the worker either dispatches to registered subscribers or is documented as a log.

- **ICA-G2 — Entitlement enforcement defaults OFF** · Operational/Product · P1 *(owner)* · §6 (A3)
  - **Evidence:** `entitlement_enforcement.ts:12-19` returns true only when `ENTITLEMENT_ENFORCEMENT=true`, defaulting OFF; `entitlement_middleware.ts:166-169` only enforces when the flag is on — so every 402 plan-gate + suspended-subscription block is **inert until an operator flips the env**, with no prod-config test on the ON path. **Fix/decision:** track the flip as an explicit go-live gate with a pre-flip audit that every live org has a real plan assigned, plus a CI/live smoke running the routers with `ENTITLEMENT_ENFORCEMENT=true` against seeded plans. **Feeds W6.** **Done-when:** the enforcement ON path is proven and the flip is a recorded go-live gate.

- **ICA-G3 — Role/permission catalog is global (no tenant scope)** · Product · P1 *(owner)* · §6 (A2)
  - **Evidence:** `20260608100000_rbac_foundation.sql:30-36` — `role_definitions` keyed by `slug` alone with `is_system BOOLEAN DEFAULT true` but **no organization/tenant column**; `role_permissions` + `school_membership_roles.role_slug` FK to that global catalog; the `is_system` flag implies custom roles were anticipated with nowhere to hold them. The SOP identity-governance roadmap (SOP-ID) points toward per-school custom roles → a later migration of `role_definitions`/`role_permissions` + every membership FK, or slug-collision risk.
  - **Owner decision:** are per-tenant custom roles in scope? If yes, add a nullable `organization_id` to `role_definitions`/`role_permissions` (NULL = system-global) and composite the membership FKs **before** the tables are widely depended on; if no, drop the `is_system` affordance. **Feeds W2/W6.** **Done-when:** the custom-role decision is recorded and the schema reflects it.

- **ICA-G4 — Client mock/real boundary not fail-closed → ASIP support shows fabricated tickets** · Implementation/Product · P1 · §5 (Principal Architect)
  - **Evidence:** `repository_providers.dart:137-374` selects `if (isModuleApiEnabled(...)) return ApiRepo; return MockXRepository();`; only auth has a `kReleaseMode` throw backstop (`auth_repository_providers.dart:57-67`, SEC-9); every other module flag defaults false (`repository_config.dart:37/43/47/116/121/235`). `config/live_release.json` **omits `SUPPORT_API_ENABLED`**, so `repository_providers.dart:371-374` returns `MockSupportRepository()` in the canonical live build and `mock_support_repository.dart:13/24` seeds fabricated incidents — the **certified-live ASIP** support module shows fake tickets and newly filed reports vanish in-memory. No `/support` entry in `surface_backend_gate.dart` either. **Verifier (PARTIAL→Medium):** bounded to the non-core support module; no persisted-data corruption; the converged trunk is not yet redeployed to the pilot (owner-gated) → latent in the next release build.
  - **Fix:** add `SUPPORT_API_ENABLED` to `config/live_release.json` (and audit every client-facing flag), apply the auth SEC-9 fail-closed pattern uniformly (any `Mock*Repository` construction throws in `kReleaseMode`), or invert release defaults to opt-OUT; add a test asserting the live config enables every module that has a Mock fallback. **Feeds W8.** **Done-when:** a missing flag breaks the release build instead of silently serving fabricated data; ASIP support is wired to the real backend. **Gate:** before the converged trunk is redeployed to the pilot.

#### Wave ICA-H — Domain Correctness (feeds **W4 Ops / W5 Assessment**) — 4 items

- **ICA-H1 — Term tabulation drops same-subject exams** · Data Model/Product · P1 · §6 (DOM1)
  - **Evidence:** `exam_administration_repository.ts:1427` keys the per-student result map on the **bare subject string** (`student.perSubject[r.subject] = …`, iterating `ORDER BY es.updated_at ASC` `:1392`); totals/percent/rank are computed from this deduped map (`:1439-1458`), ignoring `exam_id`/`exam_type`. Any two reportable exams sharing subject + term_label collapse to the last-updated one → for schools recording FA1/FA2/SA1 (or unit-test + terminal) under one term label, every session but the latest is silently excluded from totals/percentage/rank — **wrong report cards + wrong merit order, no error surfaced.**
  - **Fix:** key the tabulation on exam identity (`exam_id`/`exam_type`) not the subject string, OR enforce a DB invariant of one reportable exam per (subject, term_label, class) rejecting a second at mark-entry; make supplementary-replacement an explicit `supersedes` link, not update-order-inferred. **Done-when:** multiple same-subject exams in a term are correctly aggregated (or explicitly constrained).

- **ICA-H2 — TC asserts "all dues cleared" while inventory advisory / library key-fragile** · Product · P1 · §6 (DOM2)
  - **Evidence:** the TC gate resolves `resolveClearanceDecision(..., "transfer_certificate")` in mode `{failClosedOnBlocking:true, blockingContributorsOnly:true}` (`clearance_gate.ts:39`); for `transfer_certificate` only finance is blocking, inventory + library are advisory (`clearance_engine.ts:99`), so the inventory contributor (real owed rupees from `payment_requests` for `payment_pending` distributions, `clearance_contributors.ts:62-97`) is **never queried** — yet the PDF states "All dues have been cleared" (`sis_certificate_pdf_service.dart:172`). The library gate matches `payload->>'sisStudentId'` (`sis_certificates_repository.ts:285-303`) but the library contributor is registered `tracked:false` because loans/fines key by member **name**, not student UUID (`clearance_contributors.ts:99-108`) → a null read passes a student who may owe.
  - **Fix:** either gate inventory as blocking for `transfer_certificate` and reconcile library to a reliable student-UUID key (flip `tracked`), or caveat the certificate wording to the sources actually verified (fees only). **Done-when:** the TC's dues assertion matches what the gate actually verified.

- **ICA-H3 — Management attendance aggregate returns 0% (not null)** · Implementation · P2 · §6 (DOM3)
  - **Evidence:** the canonical module mandates null/"— no data" on a zero denominator, "NEVER 0" (`attendance_percentage.ts:24-26,80-81`), but `management_aggregate_repository.ts:132-139` returns `denominator > 0 ? Math.round(...) : 0` for the per-class value and `avgAttendancePercent` → an unmarked class shows a fabricated catastrophic 0%, dragging the school-wide average down. **Fix:** return null (render "—") on zero denominator and exclude null classes from the average denominator. **Done-when:** unmarked classes show "no data," not 0%.

- **ICA-H4 — Student-risk engine fabricates optimistic defaults (safeguarding blind spot)** · Product · P1 · §6 (DOM4)
  - **Evidence:** `student_risk_repository.ts:144` `attendancePercent = row.attendance_percent ?? 92;` and `:147` `homeworkCompletionRate = hw_total>0 ? … : 85;` — the canonical SQL returns NULL when nothing is marked, but the risk layer coerces absence into a high, low-risk value → a newly-enrolled or unmonitored student is scored low-risk (92%/85%) instead of flagged unknown, so the early-warning surface **silently misses exactly the students with no monitoring data.** (Rated P1 despite the audit's Low because it is safeguarding-adjacent and fail-*unsafe*.)
  - **Fix:** treat missing attendance/homework as unknown — exclude from the weighted score and surface a "no data" caveat rather than an optimistic constant. **Done-when:** a student with no data is flagged unknown/unmonitored, never low-risk-by-default.

#### ICA-VS — Verified-Safe register (do NOT action — recorded so they aren't re-raised)

- **VS-1 — Per-route RBAC coverage is real (claim REFUTED).** A 47-file per-domain `*_route_contract_test.ts` suite (QA-B-020 family) signs real JWTs and dispatches through the actual routers, asserting per-route that a token lacking the slug gets 403 and a holder passes (e.g. `qw4_transport_route_contract_test.ts`, `qw4_finance_route_contract_test.ts`; `qw6_access_denied_audit_test.ts` confirms a real 403 with the correct `requiredPermission`). RBAC drift *is* detectable. *(Residual, non-blocking: a router with **no** route-contract test is a possible coverage gap — fold a "every inventory route has a contract test" assertion into ICA-D4.)*
- **VS-2 — Main payment-webhook double-apply cannot occur (claim REFUTED).** `markIntentCaptured` (`payment_repository.ts:214-247`) is an atomic `UPDATE … WHERE id=$1 AND status<>'captured'` that throws-on-0-rows; both confirm and webhook call it after `createCollection` in the **same** `withTenantContext` transaction, so the losing concurrent capture rolls back its collection+receipt+outstanding-decrement. Two collections for one payment can't both persist on this path. *(The offline-reconcile path ICA-A2 and the unsigned-webhook path ICA-A5 are separate, real defects.)*
- **Preserve — do not rebuild (verified engineering-grade):** tenant-isolation mechanics (server-derived tenant_id, non-bypass `erp_tenant` role, FORCE RLS, transaction-local GUC, deploy assertion, mirror-bridge org wall); the core direct-collection money path (FOR UPDATE + status guards + atomic receipt sequence); auth hardening (HS256 pin, secret-length floor, per-request session/permission freshness, refresh rotation + reuse detection); AES-256-GCM vault; DB-enforced append-only ledgers; unified attendance %, exam absent-vs-zero, and clearance fail-closed semantics.

#### ICA owner-decision batch (raised by this program)

| # | Decision | Item | Gates |
|---|---|---|---|
| ICA-D1 | `domain_events` = integration bus (add dispatch) **or** internal log (document) | ICA-G1 | W6 |
| ICA-D2 | Per-tenant **custom roles** in scope? (add nullable `organization_id` before the FKs spread, or drop `is_system`) | ICA-G3 | W2/W6 |
| ICA-D3 | Entitlement-enforcement **flip timing** + pre-flip plan-assignment audit | ICA-G2 | W6 |
| ICA-D4 | OTP pilot-phone policy — **remove privileged phones now**, and confirm the GA gate to disable response-return in production | ICA-B2 | W2/W11 |

#### ICA → existing-wave absorption (execution happens inside the standing waves)

*PROGRAM ICA is a register, not a parallel execution track. Each item executes inside the wave it feeds, under that wave's EOS gate:*
- **W3 (Money & Data Integrity):** ICA-A1…A7, ICA-E1 — *do the P0s (A1/A2/A5) first; they are live/reachable.*
- **W2 (Identity) / W11 (Security):** ICA-B1…B9, ICA-F2 — *B1 (P0) with W2's identity work; B-mediums with W11's red-team pass.*
- **W10 (Engineering Hardening):** ICA-C1…C7, ICA-D1…D7, ICA-E2/E3, ICA-F1/F3…F8 — *C1 + C5 gate multi-school scale-out; F1 is the same target as W10's central-chokepoint item.*
- **W6 (Dynamic Platform Services):** ICA-G1/G2/G3 (owner-gated).
- **W8 (Web Parity):** ICA-G4 — *gate before trunk redeploy to pilot.*
- **W4 (Ops Completeness) / W5 (Assessment):** ICA-H1…H4.

---

### PROGRAM UXR — PRODUCT EXPERIENCE (UI/UX) CERTIFICATION AUDIT REMEDIATION 🔴

*(Fulfils the reserved **PROGRAM UIUX-AUDIT** slot.)*

**Source:** [`docs/audits/PRODUCT_EXPERIENCE_CERTIFICATION_AUDIT_2026-07-21.md`](../audits/PRODUCT_EXPERIENCE_CERTIFICATION_AUDIT_2026-07-21.md) — 17 independent parallel expert reviewers (10 specialist lenses · 6 role-journey simulations · 1 competitive analyst) audited Web + Android + iOS + Tablet from code traces, 70 rendered golden screenshots, backend contracts, and competitor research. 250 findings; every P0 claim adversarially verified (15 CONFIRMED P0 = 13 unique defects · 29 downgraded · 1 REFUTED). Verdict: **NOT CERTIFIED — Significant UX Redesign Required** (votes: 11 NOT / 6 MODERATE; every day-in-the-life persona voted NOT). Scores: Overall 4.8 · Mobile 5.9 · Web 3.6 · A11y 5.5 · Workflow 4.3 · Visual 7.0 · AI 4.3 · Maturity 4.8.

**Normative annex (finding-level SSOT):** [`docs/roadmap/UXR_FINDINGS_REGISTER.md`](UXR_FINDINGS_REGISTER.md) — all 250 findings **verbatim** (evidence `file:line`, impact, recommendation, reviewer), all 45 verification verdicts **with the verifiers' full reasoning** (V-01…V-45), and the 114-entry board-protected NEVER-CHANGE register (NC-01…NC-114). Work items below trace by `F-id`/`V-id`; implementers MUST read the traced register entries before fixing — they contain the exact code paths, mitigations, and aggravations, so no re-investigation is needed.

**Program laws:**
- **Nothing lost:** every one of the 250 findings maps to exactly one work item below (dupes merged with all F-ids preserved). Deletion/merge/re-scope requires an APPENDIX C entry. The annex register is part of this roadmap.
- **Working-tree-scoped evidence:** all `file:line` references are against `feature/qie-question-planning-layer` at audit time (2026-07-20/21) — re-verify on the converged trunk before fixing; the defect logic is the durable part.
- **NEVER-CHANGE protection law:** the board-certified patterns in annex PART 3 (persona-nav contract, exception-first attendance, marks-grid AB/ML/DB semantics, amber-queued money ceremony, five-layer hide-first gating, token pipeline, honest-state doctrine, AI explainability contract, 48dp/text-scale a11y floors, parent-OTP model, web deep-link/AsyncBoundary chassis…) may **not** be removed or weakened by any UXR fix. A "fix" that regresses an NC entry is a defect.
- **Unverified marker `(u)`:** 11 P0 claims fell past the 45-claim verification cap. 7 are duplicates/variants of verified clusters; 4 distinct ones (F-225/F-226/F-227 library-counter & lead-creation, F-228 web front-office) carry reviewer severity flagged **(u)** — adversarially re-verify at fix time before treating as P0.
- **Web severity law (board reconciliation, V-06/V-15/V-22/V-28/V-43):** "web is read-only" is **P1 relative to the current Flutter-only pilot** (Flutter carries every mutation; web lane owner-frozen, deployed only as an isolated review demo) but a **hard P0 gate for any web GA, sales demo of the web surface, or desktop-support claim**. Two sub-items are non-deferrable at ANY horizon (deceptive affordances, not missing features): the input-destroying web "Save marks" and the fabricated "Settings saved"/"Accepted" states (UXR-F2).
- **Parallel execution:** per owner direction (2026-07-21), UXR executes **inside the ERP remediation phase in parallel with the engineering programs** (ICA et al.) — same waves, same EOS gate per slice. UXR is a register, not a separate track. **Roadmap planning only — no item here has been implemented.**

#### UXR priority & wave index (100 work items covering all 250 findings; Class taxonomy: UX · UI · Workflow · Mobile · Web · Tablet · Accessibility · Product · IA · Forms · AI-UX · Trust/Honesty · Technical Debt · Docs)

| ID | Item | Class | Pri | Trace | Feeds |
|---|---|---|---|---|---|
| **UXR-A1** | Parent "Pay Now" simulates a gateway yet **posts a REAL collection + numbered receipt (clears dues, no money moved)** | Trust / Product / Mobile | **P0** | F-027 F-074 F-174 F-239 · V-02 V-03(hci) V-33(parent) | W3 |
| **UXR-A2** | Fee counter can **post payment against the wrong student's invoice** (global first-200 picker, no student names, `inv_1` fallback) | Workflow / Trust / Mobile | **P0** | F-101 F-223 · V-18 | W3 |
| **UXR-A3** | Pay CTAs hardcode installment `term_2`; receipt ids fabricated client-side | Trust / Mobile | P1 | F-178 F-241 | W3 |
| **UXR-A4** | QR/UPI counter collection: fabricated `inv_1` + magic ₹5,000, raw session dump, no student search | Workflow / Trust | P1 | F-119 F-114 F-245 | W3 |
| **UXR-A5** | Create-fee-structure dialog prefills demo money, hardcodes Tuition category, validates nothing | Forms / Trust | P1 | F-083 F-120 | W3 |
| **UXR-A6** | Yesterday unreconcilable — daily summary hardwired to CURRENT_DATE, no date param | Workflow / Product | P1 | F-215 | W3 |
| **UXR-A7** | Reconciliation mode split omits cheque/DD/card — figures don't tie, no "other" bucket | Workflow / Product | P1 | F-216 | W3 |
| **UXR-A8** | Year-2 operations structurally impossible: promotion gated off, no re-billing for continuing students | Product / Workflow | P1 | F-107 | W4 *(owner-adjacent)* |
| **UXR-A9** | Transport allocation never raises the transport-fee demand (TRN-9 unwired); hardcoded demo route filters | Product / Trust | P1 | F-106 | W4 |
| **UXR-A10** | TC dues-pending failure is a dead-end snackbar — no path to the dues/waiver resolution | Workflow / UX | P1 | F-108 | W4 |
| **UXR-A11** | Refund & concession creation require typing raw internal IDs + free-text student names | Forms / Workflow | P1 | F-081 | W3 |
| **UXR-A12** | Fee-collection amount accepts empty/zero/garbage client-side; failure recovery is two-step | Forms | P2 | F-123 | W3 |
| **UXR-B1** | Admin Hub hero shows **hardcoded fake stats as live data** ("1,248 Students · 96% · ₹4.2L") | Trust / Mobile | **P0** | F-146 F-234(landing) · V-29 | W1/W8 |
| **UXR-B2** | Parent money/attendance/dashboard/profile **silently render fabricated demo data** on load/error ("Ravi Kumar · 8-A") | Trust / Mobile | **P0** | F-175 F-242 · V-36 | W1/W8 |
| **UXR-B3** | Attendance-correction dialog ships hardcoded date "12 Jun 2026" + canned excuse "Biometric sync error" | Trust / Workflow | **P0** | F-160 F-076 · V-32 | W4 |
| **UXR-B4** | Production login copy leaks internals: "staging server", "demo-school phone number" | Trust / UX | P1 | F-015 F-152 F-182 F-194 F-243 · V-03 | W1/W8 |
| **UXR-B5** | Placebo filter chips on 8+ module dashboards + admissions; hardcoded FY year chips | Trust / UX | P1 | F-149 F-110 F-232 | W8 |
| **UXR-B6** | Transport shows hardcoded fake bus ETA ("~8 minutes away") with dead "Refresh ETA" | Trust / Mobile | P1 | F-177 · V-38 | W4 |
| **UXR-B7** | Live-mode teacher attendance defaults to mock `class-8a-p1` + misleading search empty-state | Trust / Workflow | P1 | F-166 | W4 |
| **UXR-B8** | Teacher exam insight hardcodes "Unit Test — Mathematics" regardless of actual exam | Trust | P1 | F-167 | W5 |
| **UXR-B9** | **Demo/live boundary guard (systemic):** one build-level kill-switch + lint/test sweep so no mock provider, fabricated fallback, or hardcoded ID/date/amount is reachable in live mode | Technical Debt / Trust | **P0 (program)** | audit §Redesign-1 · ties ICA-G4 | W1/W10 |
| **UXR-B10** | School health score is a fabricated composite (hardcoded weights, silent fallbacks) | Trust / Product | P2 | F-154 | W7 |
| **UXR-B11** | Phantom "2 unread" badge on receipt detail; demo-id routing in notice/event taps | Trust | P2 | F-186 F-187 | W8 |
| **UXR-B12** | Internal jargon leaks: "AD-05" copy, raw exception snackbars, web error states exposing API paths | UX / Trust | P2 | F-112 F-156 F-125 | W8 |
| **UXR-C1** | **Admission funnel not resumable/interleavable** — in-session journey context only; `MockAdmissionsWriteStore` in the live submit path | Workflow / Product / Trust | **P0** | F-104 · V-21 | W4 |
| **UXR-C2** | Admissions "View" **silently submits** a draft application; no application detail screen exists | Workflow / Trust | P1 | F-103 · V-20 | W4 |
| **UXR-C3** | Admissions→Finance fee handoff silently discards the clerk's fee-structure choice (onSelected never wired) → first structure applied | Workflow / Forms | P1 | F-072 F-109 · V-14 | W4/W3 |
| **UXR-C4** | Lead creation shows "Lead created successfully ()" **on failure**; accepts fully empty submissions | Forms / Trust | **P0 (u)** | F-227 | W4 |
| **UXR-C5** | No lead search on Leads screen — phone follow-ups page 20 rows at a time | Workflow | P1 | F-233 | W4 |
| **UXR-C6** | Library issue/return dialogs see only the loaded 20-row page — ISBN entry fails for a real catalog | Workflow / Mobile | **P0 (u)** | F-225 | W4 |
| **UXR-C7** | Library fine collection impossible — only "Waive" exists; "Finance FN-02" button → Access Denied | Workflow / IA | **P0 (u)** | F-226 | W4 |
| **UXR-C8** | No role below full schoolAdmin can issue certificates — clerk persona collapses hide-first | Product / IA | P1 *(owner)* | F-229 | W2/W4 |
| **UXR-C9** | Student address displayed but not editable anywhere — routine clerk task impossible | Workflow / Product | P1 | F-230 | W4 |
| **UXR-C10** | Front-office P2 tail: fake "Scan ISBN" promise · no visitor log/message-to-staff · unvalidated free-text SIS profile edit · Aadhaar hard-required with no alternative | Forms / Product | P2 | F-236 F-237 F-238 F-126 | W4 |
| **UXR-D1** | Teacher marks entry **cannot record AB** — digits-only field; absent students permanently "pending" (admin grid has AB/ML/DB; teacher path doesn't) | Workflow / Product | **P0** | F-161 · V-33 | W5 |
| **UXR-D2** | **Exams missing from admin workspace catalog** — no Admin Hub card, no mobile bottom-nav entry (`schoolAdministration` omits `AdminModule.exams`; "A5 un-bury" landed only on desktop rail) | IA / Product | P1 | F-014 F-058 · V-02 V-11 | W5/W8 |
| **UXR-D3** | Exam creation redesign: series-based fan-out (one series → class-section-subjects), real date pickers, human enum labels (kill "unitTest"/"15 Mar 2026"/"Room 8A" prefills) | Workflow / Forms | P1 | F-105 | W5 |
| **UXR-D4** | Marks "Save all" silently skips out-of-range rows; "N failed" never identifies which students | Forms / UX | P1 | F-121 F-086 | W5 |
| **UXR-D5** | "Publish results" to parents is one tap — no confirmation, no summary of what publishes | Workflow / Trust | P1 | F-077 | W5 |
| **UXR-D6** | Attendance same-class second-session lock: global submitted flag + false "submitted" banner (verifier-bounded scope: class-teacher's own class, 2nd session) | Workflow / Mobile | P1 | F-159 · V-31 | W4 |
| **UXR-D7** | No school-wide "today's attendance" view — principal's quick action lands on year-scoped analytics | Workflow / Product | P1 | F-148 | W4 |
| **UXR-D8** | "All absent/All present" bulk actions wipe an in-progress roster — no confirm, no undo | UX / Workflow | P1 | F-080 | W4 |
| **UXR-D9** | Attendance/academics P2 tail: sticky tally omits half-day/excused · phone-vs-tablet schedule-tap divergence · bulk actions top-of-screen (one-handed reach) | UX / Mobile | P2 | F-113 F-172 F-173 | W4 |
| **UXR-E1** | Date inputs: migrate ALL leave/exam forms to `AksharaDateField` — kill free-text dates with decorative calendar icons (silent-failure validation included) | Forms | P1 | F-028 F-117 F-118 | W4 |
| **UXR-E2** | Homework targeting: roster/class pickers instead of free-typed class labels + student names; add draft protection | Forms / Workflow | P1 | F-031 F-122 F-169 | W4/W5 |
| **UXR-E3** | **Shared file/photo upload primitive** (camera/gallery/file picker) adopted by homework, leave, SIS documents, student submissions — today every "attachment" is a typed filename string | Product / Forms | P1 | F-033 F-162(V-34→P2) F-196 F-231 | W4/W10 |
| **UXR-E4** | Interaction consistency: one validation grammar (3 contradictory "required" behaviors), dialogs must not lose input on outside-tap/failure, one create-record pattern across modules | UX / Forms | P1 | F-078 F-079 F-082 | W8/W10 |
| **UXR-E5** | Approval Center: confirmation/undo on one-tap Approve; detail-panel Approve must honor maker-checker disable; link approvals to the underlying record (payload text dead-end) | Workflow / Trust | P1 | F-075 F-151 | W4 |
| **UXR-E6** | Dead taps & mis-wired chrome: "Students requiring attention → Review" emits unhandled `student_risk_<id>`; profile avatar routes to Home; teacher bell routes to parent route | UX / Mobile | P1 | F-163 F-164 F-128 | W4 |
| **UXR-E7** | Forms P2 tail: rejection-reason dialog discards context · inert "open-in-new" receipt rows | UX | P2 | F-084 F-085 | W4 |
| **UXR-F1** | **Web action layer program** — wire existing backend POST routes into the existing ResourceList/AsyncBoundary chassis: fee collection, attendance marking, marks entry w/ lifecycle, Approval Center approve/reject, leads, homework, leave decisions, offline-payment reconcile/bounce, module settings PUT | Web / Product | **P0 (web-GA) / P1 (pilot)** | F-039 F-073 F-102 F-115 F-147 F-207 F-208 F-210 F-212 F-214 F-228(u) F-170 F-185 · V-06 V-15 V-19 V-22 V-28 V-43 V-44 | W8 |
| **UXR-F2** | **Immediate web honesty pass (non-deferrable):** fix/remove input-destroying "Save marks" (`setEdits({})`), no-op attendance `onRowClick`, no-op "Pay now" (`location.hash=''`), fake "Settings saved" toast, fabricated Legal "Accepted" chips, false "posts to live endpoint" caption; disable or remove every dead CTA until wired | Web / Trust | **P0** | F-040 F-041 F-042 F-043 F-116 F-211(u) · V-07 V-08 V-09 V-10 V-23 | W8 |
| **UXR-F3** | Web routes calling nonexistent endpoints / wrong response shapes → guaranteed dead pages: memories, parent-meetings, entitlements, Student Accounts, 4 finance tabs (Reconciliation/Executive/Copilot/Discounts) | Web / Technical Debt | P1 | F-046 F-209 F-213 | W8 |
| **UXR-F4** | Web pagination: hard caps with no controls (registry 200, collections 200, no date filter) — large schools can't see their data | Web / Workflow | P1 | F-044 F-220 | W8 |
| **UXR-F5** | Web session-expiry handling (error wall, no path to login) + demo "Explore by role" reachable in live builds (token-less broken session) | Web / Trust | P1 | F-047 F-048 | W8 |
| **UXR-F6** | Desktop keyboard productivity: operable DataTable rows/sort headers, dialog focus behavior, real entity search in ⌘K (today ~25 nav labels), counter workflow without mouse | Web / Accessibility / Workflow | P1 | F-045 F-049 F-221 · ties UXR-I5 | W8 |
| **UXR-F7** | Web reports & documents: 10 modules of permanently disabled report catalogs; no receipt print/share anywhere on web; parent "Download PDF" dead | Web / Product | P1 | F-053 F-212 F-219 | W8 |
| **UXR-F8** | Brochure InfoPages presented as finished pages — incl. top-level sidebar "Copilot" with disabled button (setup wizard, workflow, backup, school config) | Web / Trust / IA | P1 | F-052 F-060 F-139 · V-13 | W8/W7 |
| **UXR-F9** | Web workflow completeness tail: parent child-switcher absent · attendance 422 asks for filters that don't exist · defaulters page has no reminder/contact/filter/bulk · money rendered without ₹/Indian grouping/paise · 14-tab finance IA mixes daily+executive · web/Flutter role-scoping divergence | Web / Workflow / IA | P1 | F-051 F-050 F-218 F-217 F-222 F-066 | W8 |
| **UXR-F10** | **Documentation truth:** correct `web/PARITY_TRACKER.md` ("100% parity/live-wired" is false at capability level) + record the cert-scope law: route-render certs are NOT capability certs | Docs / Trust | P1 | F-224 · V-06 | W8 |
| **UXR-F11** | Web P2 tail: real 404 (not "parity in progress") · Academics/Examinations duplicate sidebar items · URL-persist list/filter state · 3-of-5 permanently empty student-profile tabs · "Configure" 5-way sprawl · management-grant nav gating quirk | Web / IA | P2 | F-054 F-055 F-056 F-057 F-069 F-024 | W8 |
| **UXR-F12** | **Web student portal structurally dead** — 6 of 9 pages request snapshot-shaped responses through list/KPI adapters that can never match the backend, and homework cannot be submitted on web at all | Web / Product | **P0** | F-193 · V-42 | W8/W5 |
| **UXR-G12** | Parent active-child context exists only on Home — every other mobile screen strands a two-kid parent (web has no switcher at all → UXR-F9) | UX / Mobile | P1 | F-179 | W8 |
| **UXR-G1** | **Circular/broadcast unreachable on mobile** — only compose screen lives in the orphaned "School Completion" hub; no Communication module in the 25-destination admin nav | IA / Workflow | **P0** | F-145 · V-28 | W4/W8 |
| **UXR-G2** | **AI FAB overlays the middle bottom-nav tab** (parent Fees, teacher Teach, student Schedule) — painted last, hit-tested first, default-on for all three personas; goldens confirm | UX / Mobile / AI-UX | **P0** | F-026 F-016 F-165 · V-04 | W7/W8 |
| **UXR-G3** | **No student login path in either client** (backend supports student_id OTP + scope switching; front door only understands parent phone) | Product / IA | **P0** *(owner: rollout story)* | F-191 · V-40 | W2 |
| **UXR-G4** | **Student data spine seed-frozen:** dashboard contradicts its own tabs on real tenants ("--" attendance, 0 homework, blank exam-reminder, no quick actions); exam schedule can never show real exams; "Class average" KPI frozen | Product / Trust | **P0** | F-190 F-192 F-201 · V-39 V-41 | W5 |
| **UXR-G5** | Student persona tail: **no logout** (shared-device fatal) · no admit card/hall ticket student- or parent-side (staff generate them) · borrowed library books invisible · "Class average" vs "Average" label contradiction | Product / UX | P1 | F-195 F-197 F-198 F-199 | W5/W4 |
| **UXR-G6** | Parent "PTM" More-sheet tile → Access Denied: More sheet bypasses SchoolBuildScope/surface-gate filtering — filter `MoreNavDestination` through the same gates as primary nav | IA / Mobile | P1 | F-001 F-017 F-061 F-176 F-240 · V-01 | W8 |
| **UXR-G7** | Orphaned navigation clusters: "School Completion" hub (~20 academic-ops destinations, zero inbound links) · Multi-School Portfolio/Branches/Backup/AI-Content/Homework-Intelligence orphan routes · Org-Builder "Setup wizard" → Access Denied | IA | P1 | F-059 F-067 F-068 · V-12 | W8/W9 |
| **UXR-G8** | Admin nav order & landings: declaration-ordered tabs put Marketing above SIS/Exams; single-module staff land on generic Admin Hub (with fake hero) instead of their workspace dashboard; cashier's Collections buried in overflow | IA / UX | P1 | F-063 F-022 F-065 F-234 F-064 | W8 |
| **UXR-G9** | Naming & IA coherence: "HR" vs "Employee Platform", three executive surfaces, five Configure entries; mobile/web teacher vocabulary divergence; two competing student-detail destinations; web-got-the-better-IA inversion; internal program names ("School Completion", phase4/5) | IA / UX | P1 | F-019 F-020 F-153 F-158 F-070 | W8 |
| **UXR-G10** | Scope-governance debt: franchise vertical only chain-gated (4 roles hold its permission — owner said OUT); salon/restaurant/healthcare/white-label latent behind one compile flag (routes+permissions+copilot copy) → execute the §8 quarantine/removal | Technical Debt / Product | P1 *(owner)* | F-062 F-012 F-025 F-071 F-111 F-124 F-143 F-189 F-206 | W0/W10 |
| **UXR-G11** | IA P2 tail: parent "Academics" tab lands on Attendance (label mismatch; homework/exams 2 taps deep) · student attendance orphaned (KPI-tap only, highlights wrong tab) · exams entry bypasses router; two report-card UIs · residual "coming soon" tiles on student/admin profiles (hide-first violation) · report card renders "Average: 0.0%" with zero data (no empty state) · no first-run guidance on 14-module admin · tablet rail/More drawer ignore workspace scoping | IA / UX | P2 | F-188 F-247 F-203 F-202 F-127 F-204 F-205 F-023 F-235 | W8 |
| **UXR-H1** | Simulated `EdgeAiProvider` fabricates AI responses **labeled "Live inference (akshara-edge-v1)… Based on current school data"** — the ONLY AI path for teacher/parent/student personas | AI-UX / Trust | P1 *(P0 posture if kept as-is at GA)* | F-129 · V-24 | W7 |
| **UXR-H2** | Production-reachable `/intelligence` dev harness can publish hand-typed AI "guidance" to the real parent hub (publish toggle default ON, prefilled "student_1") | AI-UX / Trust | P1 | F-131 · V-26 | W7 |
| **UXR-H3** | Teacher Assistant "Add intervention" writes a hardcoded `student_1` record to the live backend | AI-UX / Trust | P1 | F-132 · V-27 | W7 |
| **UXR-H4** | AI reply honesty: quick-action prompts silently discarded (copilot opens empty); stub/degraded replies visually identical to real AI ("read-only stub" string is the only signal); persona shell single-shot with meaningless dev toggle | AI-UX / UX | P1 | F-133 F-135 F-134 | W7 |
| **UXR-H5** | AI surface completion: copilot phone layout (220px sidebar + fixed 640px → ~170px chat) · prediction/finance-copilot rows are unexplained dead ends · Principal Command has no loading state/silent failure/no provenance · insight PDFs lack generation dates | AI-UX / UX | P1 | F-136 F-137 F-138 F-140 | W7 |
| **UXR-H6** | Parent dashboard AI overload: 4 overlapping AI/aggregation surfaces + the AI ball with indistinguishable value propositions | AI-UX / UX | P1 | F-021 F-181 | W7/W8 |
| **UXR-H7** | AI P2 tail: AI can't be turned off (settings only relocate it) · three "intelligence" hubs / two meanings of "Copilot" · out-of-scope verticals baked into copilot copy · Analytics-Hub KPI cards waste half the phone width · web Intelligence ships two permanently-dead tabs exposing internal gap IDs · Principal Command Center is prototype-grade noise (correctly hidden — keep it hidden until useful) · production "Generate AI Summary" fails silently (V-25 refuted-residual) | AI-UX / IA | P2 | F-141 F-142 F-143 F-144 F-018 F-157 · V-25 | W7 |
| **UXR-I1** | Parent OTP login accessibility (the product's front door): unassociated labels, meaningless '••••••' hint, no `AutofillHints.oneTimeCode`/SMS retrieval — every parent hand-types the OTP | Accessibility / Mobile | P1 | F-089 F-034 F-183 | W8 |
| **UXR-I2** | Web OTP entry: six anonymous inputs, no one-time-code autocomplete, pasted codes rejected | Accessibility / Web | P1 | F-093 | W8 |
| **UXR-I3** | Light-theme warning/tertiary text fails AA (3.07–3.74:1) on the 11-12px chip/badge labels where actually used — the contrast test misapplies the WCAG large-text floor to 12px | Accessibility / UI | P1 | F-090 | W8 |
| **UXR-I4** | Input field boundaries ~1.2:1 non-text contrast on both platforms/both themes (golden-confirmed) | Accessibility / UI | P1 | F-091 | W8 |
| **UXR-I5** | Web keyboard operability: DataTable rows/sort headers have no tabindex/role/key handling (list→detail blocked on 8+ core pages); dialogs/drawers have no focus trap/initial focus/restore | Accessibility / Web | P1 | F-088 F-092 · V-17 | W8 |
| **UXR-I6** | A11y P2 tail: reduced-motion (web none, Flutter 1 widget) · no skip-link · web charts lack text alternatives · weak focus ring + unannotated RoleSwitcher · fixed-height banners truncate at large text scale · uneven screen-level Semantics (entry/SIS thin) · 32px avatar/40px app-bar targets · teacher profile announced as "Parent profile" · near-AA marginal pairs | Accessibility | P2 | F-095 F-096 F-097 F-098 F-099 F-100 F-035 F-036 F-094 | W8 |
| **UXR-J1** | Persona shells hard-force Stitch theme+brightness — the Appearance setting is a no-op app-wide (teachers/students/admins locked dark, parents locked light) | UI / UX | P1 | F-002 | W8 |
| **UXR-J2** | Brand consolidation: three stacked identities (M15 blue · Premium indigo→violet · four Stitch persona primaries); web ships only M15 → same persona looks different per platform | UI / Product | P1 *(owner: brand authority)* | F-003 F-004 | W8 |
| **UXR-J3** | Declared Roboto/RobotoMono never bundled — iOS renders a different typeface; mono receipt style silently degrades | UI | P1 | F-006 | W8 |
| **UXR-J4** | Tablet layout pass: persona dashboards render as ~480px left-pinned column (⅓–½ canvas dead) across teacher/parent/student; portrait-tablet detail screens center-float; intelligence dashboard broken half-width on phones — use the finance dashboard's proven phone→tablet restructuring as the template | Tablet / UI | P1 | F-030 F-171 F-184 F-200 F-007 F-005 | W8 |
| **UXR-J5** | All ~280 routes use NoTransitionPage — zero push animations; **iOS back-swipe dead app-wide** | Mobile / UX | P1 | F-029 | W8 |
| **UXR-J6** | Pull-to-refresh on only 4 of 297 screens — adopt on all list/detail surfaces | Mobile / UX | P1 | F-032 | W8 |
| **UXR-J7** | Golden suite certifies an appearance production users never see (Stitch-forced vs settings-honoring) — re-baseline goldens on the production theming after UXR-J1 | Technical Debt / UI | P1 | F-008 | W8/W10 |
| **UXR-J8** | Visual P2 tail: chart hues rotate between light/dark · raw Material colors for risk semantics · tablet admin-hub half-empty canvas/grid near-misses · bare-spinner loading (skeletons on ~12 files) · no landscape strategy · bottom-nav labels wrap on phones · workspace-switcher tablet canvas | UI / Tablet | P2 | F-009 F-010 F-011 F-013 F-155 F-250 F-037 F-038 F-087 | W8 |
| **UXR-K1** | Broadcast compose quality: confirmation before mass send, empty-content validation, real class targeting (free-text today) | Workflow / Forms | P1 | F-150 | W4 |
| **UXR-K2** | WhatsApp as a channel in the core broadcast pipeline (admin provider setup screen exists; pipeline ignores it) — the market's table-stakes channel | Product / Workflow | P1 *(owner/provider)* | F-244 | W6 |
| **UXR-K3** | Parent↔teacher messaging: parent cannot START a conversation with the class teacher; reply failures silent (both directions); conversations open at the oldest message | Workflow / UX | P1 | F-180 F-168 | W4 |
| **UXR-K4** | Parent-facing online admission application/enquiry form (competitive table-stakes; every incumbent has one) | Product / Web | P1 | F-246 | W4/W8 |
| **UXR-K5** | Engagement P2/future tail: live transport tracking (web nav already promises a "Live Tracking" page — align promise with §8 scope) · UPI AutoPay/recurring mandate (open differentiator — §8 future) | Product | P2 | F-248 F-249 | §8 |

#### The confirmed P0 set — full implementation context (the audit's 13 unique P0 defects + the systemic demo/live guard program UXR-B9)

*(Read the traced V-entries in the annex before fixing — each verifier documented exact code paths, failed refutations, and aggravating factors.)*

- **UXR-A1 — Parent "Pay Now" posts a real receipt with no money moved** · **P0** · F-027/F-074/F-174/F-239 · V-02/V-03/V-33
  - **Evidence:** `lib/features/parent/payment/parent_payment_provider.dart:104-163` — live flow is `submitMockPayment()`: client-generated `txn_${millis}` ref, no gateway UI, then success + receipt. Route `/parent/payment` registered (`app_router.dart:371-377`), wired from Pay Now (`parent_navigation.dart:115-118`), **NOT in `surface_backend_gate.dart:22-40`** → reachable in live builds. Verifier: in shipped stub-mode default the backend **posts a genuine finance collection + numbered APS receipt and clears the invoice** — money-integrity corruption, not just fake UX. With `stubMode=false` the backend fail-closes, but the client has no SDK → every payment becomes a hard failure. Backend Razorpay layer awaits credentials (`payment_handlers.ts:199-210`).
  - **Fix:** interim (before P0-02 SDK): put `/parent/payment` behind the backend-less surface gate OR convert to a disclosed "pay at school / record offline payment" flow — never a success ceremony without money. Final: real gateway checkout per owner decision 4 (§7). Coordinate with **ICA-A5** (unsigned-webhook stub forgery) — same stub-mode cluster.
  - **Done-when:** no live-reachable path can produce a receipt or clear dues without a verified gateway capture; EOS PASS on the parent money journey.
- **UXR-A2 — Wrong-student invoice posting at the fee counter** · **P0** · F-101/F-223 · V-18
  - **Evidence:** `lib/features/finance/finance_workflow_actions.dart:728-762` — Record-collection dialog builds its picker from `financeInvoicesProvider` (ALL school invoices, page 1, pageSize 200 — `finance_invoices_provider.dart:16`), preselects `journeyInvoice ?? 'inv_1' ?? invoices.first`; labels ("INV-nnn · Term · ₹X due") carry **no student name**. From Student Accounts "Collect fee" (`finance_student_accounts_screen.dart:267-275`) only amount/label pass — the invoice list is never scoped to the student. Verifier: the student-context header + correct prefilled amount **actively reassure** the cashier while the target invoice is arbitrary; the amount posted is student A's balance regardless of invoice; students beyond the first 200 invoices can't be collected against at all.
  - **Fix:** student-first collection flow — picker scoped to the selected student's invoices, labels always `student · class · invoice · due`, no global fallback, no `inv_1`; block submission with zero scoped invoices (honest empty state).
  - **Done-when:** posting against another student's invoice is impossible from every entry point (Student Accounts, Collections, QR); regression test on picker scoping; EOS PASS.
- **UXR-B1 — Admin Hub fake-stats hero** · **P0** · F-146 · V-29 — hero renders hardcoded "1,248 Students · 96% Attendance · ₹4.2L Collected today" as live stats on the principal's landing (and greets single-module staff, F-234). **Fix:** live KPIs via existing management endpoints or remove the hero; no constant may render as a stat. **Done-when:** landing stats are server-derived or absent; lint guard from UXR-B9 covers the file.
- **UXR-B2 — Parent fabricated-data fallbacks** · **P0** · F-175/F-242 · V-36 — fees/dashboard/attendance/payment/profile fall back to "Ravi Kumar · 8-A" fixtures on load/error paths in the production build. **Fix:** delete demo fallbacks from live providers; honest loading/error/empty states (the app's own doctrine, NC-12/NC-86) everywhere. **Done-when:** no fabricated entity can render for a real session (guard test from UXR-B9).
- **UXR-B3 — Attendance-correction canned data** · **P0** · F-160/F-076 · V-32 — dialog prefills date "12 Jun 2026" + reason "Biometric sync error — student was present" as free text; corrections silently file wrong date/fabricated excuse. **Fix:** default date = the session being corrected (immutable context), reason starts empty with structured reason options; validation. **Done-when:** a correction can never carry an unedited canned excuse or wrong date.
- **UXR-B9 — Demo/live boundary guard (systemic program)** · **P0** — the one fix behind A1/B1/B2/B3/B5-B8: a single build-level demo gate (extend web's `IS_DEMO` doctrine to Flutter), no mock provider/fabricated fallback/hardcoded ID-date-amount reachable in live mode, enforced by a repo-wide lint/test sweep (grep-list seeded from F-ids: `inv_1`, `term_2`, `class-8a-p1`, `student_1`, "Ravi Kumar", "12 Jun 2026", "Route 12", ₹4.2L, ₹5,000…). Ties **ICA-G4** (fail-closed client mock/real boundary). **Done-when:** the sweep runs in CI and fails on any live-reachable fixture.
- **UXR-C1 — Admissions continuity spine** · **P0** · F-104 · V-21 — funnel state lives only in in-session "journey context"; `MockAdmissionsWriteStore` participates in the live submit path; a clerk cannot resume tomorrow or interleave two families today. **Fix:** persistent draft/application records server-side (status machine: draft→submitted→approved→enrolled), resume list on the admissions dashboard, mock store removed from live wiring; add the missing application-detail screen (UXR-C2 together). **Done-when:** kill the app mid-admission → resume from another device; two families interleaved without cross-contamination; no mock in the live path.
- **UXR-D1 — Teacher AB marks affordance** · **P0** · F-161 · V-33 — teacher-side marks field is digits-only; the mandated absent=AB-never-zero rule (frozen Exam Result Status design; NC-50) is impossible on the phone, pressuring 0-entry that corrupts exam data in the top-priority module. **Fix:** per-row status affordance (AB/ML/DB) in the teacher marks grid reusing the admin-grid semantics (`exam_marks_entry_screen.dart:641-664` pattern); keep the never-write-spurious-zero rule. **Done-when:** a teacher can mark AB one-handed; absent students are excluded from totals per the frozen design.
- **UXR-G1 — Circular unreachable on mobile** · **P0** · F-145 · V-28 — `BroadcastAdminScreen` exists only inside the zero-inbound-links "School Completion" hub; no Communication module in admin nav. **Fix:** first-class Communication destination in the admin workspace catalog + nav (with UXR-K1 compose-quality fixes); untangle from the orphan hub (UXR-G7). **Done-when:** principal reaches compose in ≤2 taps from the admin dashboard.
- **UXR-G2 — AI FAB tap hijack** · **P0** · F-026 · V-04 — `copilot_bottom_nav_ai_slot.dart:22-32` paints a 56px FAB over slot 3 of 5 (parent Fees, teacher Teach, student Schedule); painted last, hit-tested first; default `bottomNavCenter` for these roles (`ai_access_preferences_provider.dart:50-54`); goldens confirm the covered icon. **Fix:** reserve a real center slot in `PersonaBottomNav` (5th destination) OR move the FAB default off the nav bar; never overlay a populated destination; add a test asserting every primary tab's icon zone is tappable. **Done-when:** all primary tabs fully tappable with AI enabled; goldens re-baselined.
- **UXR-G3 — Student login path** · **P0** *(owner)* · F-191 · V-40 — backend supports student-scope OTP + scope switching; neither client exposes any student entry; no logout student-side (F-195) compounds shared-device use. **Fix:** student entry on the login screen per the frozen identity architecture (OTP still to parent phone; student never needs a phone) + logout; owner decides the rollout story (ties PLAT-0, §7 item 5). **Done-when:** a student can reach their shell on a shared device and log out; role-wall tests stay green (NC-91).
- **UXR-G4 — Student data spine** · **P0** · F-190/F-192/F-201 · V-39/V-41 — home dashboard is a seed-only snapshot with no production writer (contradicts its own tabs: "--" attendance beside real records, 0 homework beside real homework, blank exam-reminder card with no empty-guard, no quick actions); `upcomingExams`/`averagePercent`/`subjectScores` seed-frozen — really-scheduled exams can never appear. **Fix:** live aggregation for the student snapshot (or compose the dashboard from the same providers as the tabs); empty-guard the reminder card; live exam schedule feed. **Done-when:** on a real tenant the dashboard agrees with every tab; scheduled exams appear without seeds.
- **UXR-F2 — Web deceptive-affordance purge** · **P0 (non-deferrable at any horizon)** · F-040/041/042/043/116/211 — see index row; the board's web-severity law applies: these are active deceptions (data-destroying Save, fake success toasts, fabricated legal state), not missing features. **Done-when:** zero enabled controls that silently do nothing or lie about persistence anywhere in `web/src`; `PARITY_TRACKER.md` corrected (UXR-F10).
- **UXR-F12 — Web student portal structurally dead** · **P0** · F-193 · V-42 — 6 of 9 student pages request snapshot-shaped responses through list/KPI adapters that can never match what the backend sends → permanent empty states on live; no homework submission exists on web at all. **Fix:** align the student web pages to the real endpoints (or the same providers the mobile tabs use once UXR-G4's live spine lands) and add web homework submission, or remove the student web portal until it works — no permanently-dead pages behind a working login. **Done-when:** every routed student web page renders real tenant data or does not exist; homework submit works or is honestly absent from nav.

#### UXR-VS — Verified-safe / refuted / re-scoped register (do NOT re-raise at the wrong severity)

- **VS-1 — REFUTED: "Fabricated AI meeting summaries are saved to real parent-meeting records"** (F-130 · V-25). Production `ApiParentMeetingsRepository.saveSummary` **throws before any persistence** (fail-closed by design); fabricated summaries reach only the in-memory mock repo in demo builds. *Residual (filed as part of UXR-H7): the production "Generate AI Summary" button fails with zero user feedback.*
- **VS-2 — Web read-only severity reconciliation** (V-06/V-15/V-22/V-28/V-43/V-44): factual claim unanimous (only POST in `web/src` = auth; dead enabled CTAs across modules) — but P1 for the current Flutter-only pilot (Flutter carries every mutation; web lane owner-frozen, review-demo-only) and **P0 for any web GA/sales-demo/desktop claim**. Exception: UXR-F2's deceptive affordances are P0 now.
- **VS-3 — Teacher attendance lock re-scoped** (F-159 · V-31): "6-period teacher locks every class" cannot occur (attendance restricted to the class-teacher's own class). Real defect = **second session of the SAME class** locks behind a false "submitted" banner → silently missing afternoon attendance where schools mark twice daily. P1, not P0 — fixed as UXR-D6.
- **VS-4 — Homework photo attachment re-graded** (F-162 · V-34): absent feature, not broken flow → P2 as a standalone, but absorbed into the P1 shared upload primitive **UXR-E3** (with F-033/F-196/F-231 it is why "WhatsApp wins").
- **VS-5 — Board-verified strengths are protected:** the annex PART 3 NEVER-CHANGE register (NC-01…NC-114) has the same standing as ICA's "preserve — do not rebuild" list. Highlights: persona-nav ≤4+More contract · exception-first attendance · AB/ML/DB semantics · amber-queued money ceremony · Resume/Discard draft recovery · five-layer hide-first gating · token pipeline + designed dark mode · honest-state doctrine · AI explainability contract (Why/factors/Dismiss/Mute, never auto-execute) · 48dp floors · parent-OTP model · web deep-link/AsyncBoundary/entitlement-error chassis.

#### UXR owner-decision batch (raised by this program)

| # | Decision | Item | Gates |
|---|---|---|---|
| UXR-OD1 | **Interim parent-payment posture** until the gateway SDK (P0-02): gate `/parent/payment` off entirely **or** disclosed offline/pay-at-school mode | UXR-A1 | W3 |
| UXR-OD2 | **Web lane strategy:** build the action layer to true parity (scope + module order) **or** declare an explicit view-only web posture at GA — either way UXR-F2 honesty purge + F10 doc correction happen now | UXR-F1/F2/F10 | W8 |
| UXR-OD3 | **Brand/theme authority:** single identity (recommended: M15 blue, gradient as accent, Stitch hues → accent tokens with light+dark variants honoring the Appearance setting) | UXR-J1/J2 | W8 |
| UXR-OD4 | **Student login rollout + shared-device story** (ties PLAT-0 identity cluster, §7 item 5) | UXR-G3/G5 | W2 |
| UXR-OD5 | **Franchise + latent verticals quarantine timing** (§8 subtraction already mandated; franchise currently permission-granted to 4 roles) | UXR-G10 | W0/W10 |
| UXR-OD6 | **WhatsApp broadcast channel** — provider choice/cost + rollout (setup screen exists, pipeline ignores it) | UXR-K2 | W6 |
| UXR-OD7 | **Certificates issuing role** — new front-office permission vs delegated grant (hide-first currently collapses to full schoolAdmin) | UXR-C8 | W2/W4 |
| UXR-OD8 | **Year-2 re-billing + promotion enablement scope** (continuing-student billing is structurally absent) | UXR-A8 | W4 |

#### UXR → existing-wave absorption (execution happens inside the standing waves, in parallel with ICA per the remediation-phase law)

- **W1 (Re-baseline) / W10:** UXR-B9 demo/live boundary guard first — it multiplies every other honesty fix; B1/B2/B4 verified on the converged trunk.
- **W2 (Identity):** UXR-G3 (owner OD4) · C8 (OD7) — with the PLAT-0 cluster.
- **W3 (Money):** UXR-A1 (with ICA-A5, owner OD1) · A2 · A3–A7 · A11 · A12 — *A1/A2 before any finance surface is extended or demoed.*
- **W4 (Ops Completeness):** UXR-C1–C10 · B3/B6/B7 · D6–D9 · E1/E2/E5/E6 · G1+K1 · K3/K4 · A8–A10 (OD8).
- **W5 (Assessment/Exams):** UXR-D1–D5 · B8 · G4/G5 · E2(homework).
- **W6 (Platform Services):** UXR-K2 (OD6).
- **W7 (AI Consolidation):** UXR-H1–H7 · G2 (FAB, with W8) · B10.
- **W8 (Cross-Platform Cohesion — the natural home of this program):** UXR-F1–F11 (OD2) · G6–G9/G11 · I1–I6 · J1–J8 (OD3) · E3/E4 · B5/B11/B12.
- **W9 (Enterprise):** UXR-G7 (multi-school orphans).
- **W0/W10 (subtraction & guards):** UXR-G10 (OD5) · B9 · J7 · F10 cert-scope law.
- **Gate mapping (from the audit's Path-to-Certification):** Gate 1 "Pilot trust" = the 13 P0s minus web/student clusters → re-audit to CERTIFIED-MODERATE (mobile pilot). Gate 2 "Persona completeness" = G3/G4/G5 + forms/a11y/child-switcher P1 groups → CERTIFIED-MINOR (mobile GA). Gate 3 "Web GA" = F1 + web P1 groups. **Re-certification is evidence-based re-audit, not claims — route-render certs don't count (F10 law).**

---

## 5.7 PROGRAM D — CERTIFIED KNOWLEDGE BANK INTEGRATION & RETRIEVAL ENGINE 🟡 (Constitution Part 6/7/8 — Knowledge-Bank-first)

**Status:** 📋 **PLANNED — MANDATORY before large-scale production rollout.** Not started. Sequenced **immediately after QIE-remediation Program C** (Live cross-family re-certification) completes and a **non-empty certified bank** exists.

> **Naming / disambiguation (owner-decided 2026-07-22).** This program is tracked at the **product-roadmap level, deliberately *outside* the QIE-remediation A–E letter scheme**. Its label "PROGRAM D" is the owner's chosen product-program name; it is **distinct from** the QIE-remediation "Program D — Tier-1 Unfreeze (R6)" recorded in `docs/question-intelligence-quality/QIE_REMEDIATION_ENGINEERING_COMPLETION.md §9`. **Neither renumbers the other** — they share a letter by coincidence of two independent schemes. The frozen/owner-accepted QIE completion record is left untouched.

- **Why (evidence — read-only architecture audit, 2026-07-22).** The elaborate QIE certified-question machinery and the shipping ERP Education Suite are **two disconnected worlds**: grep for `qie|kie|qpl|certified.question` across `lib/ supabase/ web/` returns **zero hits**; the QIE certified bank `corpus.certified_bank()` (`curriculum/scripts/intelligence/kie/qie/factory/corpus.py:511`) exists but **no assembler consumes it** — its docstring names "the committed CONSUMER a downstream surface uses," and that surface does not exist. The QIE→ERP promotion contract is **designed but not built** (`docs/curriculum-intelligence/KIE_ARCHITECTURE.md §15`; R5-3). The strategic verdict: once the certified bank reaches production scale, **≈0% of normal teacher requests should require live AI** — the correct architecture is Knowledge-Bank-first retrieval + deterministic assembly, with AI confined to the offline factory. This program builds that.
- **Objective.** Connect the certified QIE question bank to the ERP Education Suite so the product becomes **Knowledge-Bank-first, not AI-first** — teacher paper requests are served by deterministic retrieval from certified content, never by live generation.

**Scope (7 workstreams).**
1. **QIE → ERP Promotion Pipeline** — implement & operate the R5-3 promotion contract: promote **only** `status='certified' AND certification_class='certified'` items into the ERP bank; **never** promote provisional / quarantined / rejected / expired. *(Implements the Program-A contract — see Dependencies.)*
2. **Certified Question Retrieval Engine (QRE)** — bank-first retrieval + deterministic paper assembly; **zero live-AI dependency** for normal teacher requests. *(Builds the missing consumer over `corpus.certified_bank`; reuses the deterministic selector `curriculum/scripts/intelligence/kie/qpgen/select.py`.)*
3. **Metadata Completion** — per-question **difficulty (measured, not declared/proxy), Bloom level, marks, knowledge-index linkage, concept-graph, exposure tracking, usage statistics** — all currently absent or unmeasured on the certified store.
4. **Near-Duplicate Detection** — prevent similar questions appearing in the same paper; maintain diversity across generated papers *(selection is concept-level dedup only today; no semantic near-dup check)*.
5. **Exposure Intelligence** — track which questions each student/class has already received; prefer unseen questions while honoring blueprint constraints *(no exposure/usage column exists in any store today)*.
6. **Retrieval Ranking** — select the best questions from millions of certified questions; ranking **deterministic and explainable**.
7. **ERP Integration** — replace manual-only Question Bank growth with certified QIE promotion; keep **manual authoring as an optional teacher feature** (the existing `edu_question_bank_items` manual path stays).

**Architecture Principle (LOCKED).**
```
Teacher Request → Certified Question Retrieval Engine → Certified Question Bank → Deterministic Paper Assembly
```
NOT
```
Teacher Request → Live AI Generation → Paper
```
AI is used **only** for: Offline Question Factory · Continuous Bank Expansion · Cross-family Certification (judge — never the sole certifier) · Long-term Knowledge Growth. **Normal teacher requests should require ≈ 0% live-AI calls once the certified bank reaches production scale.** Preserves locked decision **I9** ("runtime deterministic, AI-free" — `docs/question-intelligence-quality/CURRENT_VS_REQUIRED_ARCHITECTURE.md`) and the generator≠judge rule.

**Dependencies.**
- **Predecessor — QIE-remediation Program C** (live cross-family re-certification): a **non-empty certified bank** is the precondition; the ERP bank must not be fed an empty/uncertified source.
- **Prerequisite — QIE-remediation Program A · ERP Promotion Contract (R5-3)** *(owner-decided relationship, 2026-07-22)*: Program A ships the promotion **contract/design**; **PROGRAM D implements & consumes it**, then adds the retrieval engine, metadata, dedup, exposure and ranking on top. **Program A is not superseded.**
- ERP bank exists today: `edu_question_bank_items` (+ `edu_question_papers`/`_items`, with an `ai_candidate` provenance slot + dormant `trust_status`/concept seams) — `supabase/migrations/20260620000000_education_suite_foundation.sql`.
- Honors the **KIE v1.4 freeze** and "no prod promotion of curriculum/questions without owner OK."

**Relationship to existing waves/programs (no duplicate systems).** This is the concrete build home for the **W5** outcome "reconcile the two QI systems (one generator, one governance surface, one seam)" and the **EIP-14** integration-contract seam — **not a fork of them**. W5 delivers the ERP-side seams (bank content, item-analysis, owner-gated promotion); **PROGRAM D** delivers the retrieval engine + promotion execution + retrieval-grade metadata that make the seam Knowledge-Bank-first at production scale.

**Owner decisions required.** Approve Program C → PROGRAM D → rollout sequencing; approve the retrieval-grade metadata additions (measured difficulty, Bloom, exposure ledger) and their ERP migrations; ratify the "≈0% live-AI at request time" target as a production gate.

- **Completion.** ERP serves real certified content by deterministic retrieval; manual authoring optional; near-dup + exposure + explainable ranking live; live-AI on the teacher request path ≈ 0%.
- **Certification.** EOS FEATURE+AI PASS; promotion runs additively with certified invariants intact (RI-6 one product-visible bank; only-certified promoted); an explicit EOS gate on the seam.
- **Production-readiness (MANDATORY gate before large-scale rollout).** A teacher generates a full governed paper from certified bank content with **no live AI call**, exposure-aware and near-dup-free, at millions-scale.
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
Hard gates: **W0 and W1 precede everything.** Feature freeze precedes W11. W11→W12→W13 strictly sequential. K-lane and acquisition run parallel and never gate the ERP. **EIP-6 (Learning Evidence spine) + EIP-14 (integration contracts) gate all EIP consumer layers** — building persona intelligence before them = fabricated intelligence (the PRA-P0-21 failure mode). Device features (staff Face-ID) must land before W12 Pilot Stage 12. **PROGRAM D (§5.7 — Certified Knowledge Bank Integration & Retrieval Engine)** sequences **after QIE-remediation Program C**, **depends on Program A (R5-3)**, and is a **MANDATORY gate before large-scale production rollout** (Knowledge-Bank-first; ≈0% live-AI at request time).

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
| 12 | **PROGRAM ICA decisions** — `domain_events` bus-vs-log (ICA-G1) · per-tenant custom roles (ICA-G3) · entitlement-enforcement flip timing + pre-flip plan audit (ICA-G2) · OTP pilot-phone policy / GA gate (ICA-B2) | W6/W2/W11 | Raised by the Interim Certification Audit (§5.6 PROGRAM ICA) |
| 13 | **PROGRAM UXR decisions (UXR-OD1…OD8)** — interim parent-payment posture · web lane strategy (action layer vs view-only GA) · brand/theme authority · student login rollout · franchise/verticals quarantine timing · WhatsApp broadcast channel · certificates issuing role · year-2 re-billing scope | W3/W8/W2/W0/W6/W4 | Raised by the Product Experience Certification Audit (§5.6 PROGRAM UXR) |

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
| **Interim Certification Audit** — CR-1…CR-7 + all confirmed §6 recommendations, tech-debt, domain-correctness, test/CI + verified-safe register (49 items) | **PROGRAM ICA (§5.6)** | ICA-A…H absorb into W2/W3/W4/W5/W6/W8/W10/W11; nothing lost. Source: `docs/engineering/INTERIM_CERTIFICATION_AUDIT_2026-07-20.md` |
| **UI/UX audit findings** — all 250 findings of the Product Experience Certification Audit (13 confirmed P0 defects, P1/P2 clusters, 12 recommended redesigns, never-change register, refuted/re-scoped claims) | **PROGRAM UXR (§5.6)** + annex `UXR_FINDINGS_REGISTER.md` | UXR-A…K absorb into W0/W1/W2/W3/W4/W5/W6/W7/W8/W9/W10; nothing lost. Source: `docs/audits/PRODUCT_EXPERIENCE_CERTIFICATION_AUDIT_2026-07-21.md` |
| **QIE audit findings** (pending) | **PROGRAM QIE-AUDIT (§5.6, reserved)** | Same item structure; populate after that audit session |
| **Certified Knowledge Bank Integration & Retrieval Engine** (QIE→ERP, bank-first) — QIE→ERP promotion pipeline, Certified Question Retrieval Engine, retrieval-grade metadata, near-dup, exposure intelligence, deterministic ranking | **PROGRAM D (§5.7)** | Product-level (outside the QIE A–E letters); after QIE-remediation Program C; **depends on** Program A (R5-3); MANDATORY before large-scale rollout. Source: read-only QIE+Bank+Retrieval architecture audit 2026-07-22 |
| CFC-1 (10-item freeze checklist), FREEZE-1 | folded into **W10 exit + pre-W11 gate** | The freeze checklist becomes the entry gate to W11 |
| Verticals scope debt, phase4/5 naming, dual finance dashboards | **W0/W10 subtraction** | Remove/quarantine per North Star |
| Deferred/Future/Out-of-scope | **§8 register** | Preserved, owner-timed |

## APPENDIX B — SOURCE DOCUMENTS (authority chain)

1. **Supreme:** `docs/owner/AKSHARA_MASTER_PRODUCT_CONSTITUTION_v2.0.md`
2. **This roadmap** (single forward plan) · superseded-but-retained: `docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md` (+ its PRA register)
3. **Reality evidence:** the PRA register (117 items, `file:line`); `Akshara_ERP-pra/docs/roadmap/PRA_EXECUTION_LOG.md` (what's actually fixed); `PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md` (PRC 502 reqs); `PROGRAM_SOP_IDENTITY_AND_PLATFORM.md`; `docs/owner/OWNER_FUTURE_PLATFORM_IDEAS_AND_RECONCILIATION_QUEUE.md` (40 provider items); web `PARITY_TRACKER.md`/`WEB_PRODUCTION_CERTIFICATION.md`; the KIE v1.4 freeze package (local-only).
4. **Educational Intelligence architecture (PROGRAM EIP authority):** `docs/curriculum-intelligence/spec/ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION.md` (6,286 lines), `docs/curriculum-intelligence/spec/MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md`, `docs/curriculum-intelligence/proposals/AMENDMENT_A2_PER_STUDENT_PRACTICE_GENERATION.md`, the QIE handoff, and the ERP `_shared/intelligence/` + `_shared/education/` modules.
5. **Engineering gate:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` + `.claude/skills/eos/`.
6. **Audit-remediation source (PROGRAM ICA):** `docs/engineering/INTERIM_CERTIFICATION_AUDIT_2026-07-20.md` — 12-reviewer interim certification of the canonical trunk, findings adversarially verified against real code. Future audit programs (QIE) cite their own source docs here.
7. **Audit-remediation source (PROGRAM UXR):** `docs/audits/PRODUCT_EXPERIENCE_CERTIFICATION_AUDIT_2026-07-21.md` (17-reviewer Product Experience Certification: NOT CERTIFIED) + normative annex `docs/roadmap/UXR_FINDINGS_REGISTER.md` (250 verbatim findings F-001…F-250 · 45 verification verdicts V-01…V-45 · never-change register NC-01…NC-114).

## APPENDIX C — CHANGE-CONTROL LAW

No row in this roadmap or its recovered registers may be deleted, merged, re-scoped or weakened without a recorded justification here (date + reason + owner sign-off where a frozen decision or scope is affected). Deprecations must state what replaced them and why. The current code remains the authority for every status.

**Change log:**
- **2026-07-22** — Added **§5.7 PROGRAM D — Certified Knowledge Bank Integration & Retrieval Engine** (product-level; 📋 PLANNED / **MANDATORY before large-scale production rollout**), from the read-only QIE + Question-Bank + Retrieval architecture audit (2026-07-22). Records the **LOCKED** Knowledge-Bank-first architecture principle (*Teacher Request → Certified Question Retrieval Engine → Certified Question Bank → Deterministic Paper Assembly*; ≈0% live-AI at request time; AI confined to the offline factory / continuous expansion / cross-family certification) and 7 workstreams: promotion pipeline, retrieval engine (QRE), metadata completion, near-duplicate detection, exposure intelligence, deterministic ranking, ERP integration. **Owner decisions (2026-07-22):** tracked **outside** the QIE-remediation A–E letter scheme and **distinct from** the QIE-remediation "Program D — Tier-1 Unfreeze" (neither renumbers the other); **depends on — does not supersede —** the QIE-remediation "Program A — ERP Promotion Contract (R5-3)". Wired into §6 (sequencing) and APPENDIX A (recovery row). **No code changed — roadmap planning only.** No wave added or removed; no existing item weakened; the frozen/owner-accepted QIE completion record (`QIE_REMEDIATION_ENGINEERING_COMPLETION.md`) left untouched.
- **2026-07-21 (b)** — Populated **PROGRAM UXR** (fulfils the reserved PROGRAM UIUX-AUDIT slot) from `docs/audits/PRODUCT_EXPERIENCE_CERTIFICATION_AUDIT_2026-07-21.md`: 100 work items covering all 250 findings with verified traceability F-001…F-250 (UXR-A…K; 13 confirmed P0 defects with full inline evidence, P1/P2 clusters, unverified-claim markers), the UXR-VS refuted/re-scoped register, the UXR owner-decision batch (OD1–OD8 → §7 row 13), wave absorption (parallel with ICA inside the remediation phase), and the new normative annex `docs/roadmap/UXR_FINDINGS_REGISTER.md` carrying all 250 findings verbatim + 45 verification verdicts + the 114-entry NEVER-CHANGE protection register. Wired into APPENDIX A (UI/UX recovery row) and APPENDIX B (source 7). **No code changed — roadmap planning only.** No wave added or removed; no existing item weakened.
- **2026-07-21** — Added **§5.6 AUDIT-DRIVEN REMEDIATION PROGRAMS** with **PROGRAM ICA** (Interim Certification Audit Remediation): 49 work items (ICA-A…H) + a verified-safe register, drawn from `docs/engineering/INTERIM_CERTIFICATION_AUDIT_2026-07-20.md`, each with class/priority/evidence/fix/done-when/trace. Reserved PROGRAM QIE-AUDIT / UIUX-AUDIT placeholders for upcoming audits (same structure). Wired into §7 (owner decision 12), APPENDIX A (recovery rows), APPENDIX B (source 6). **No code changed — roadmap planning only.** ICA items absorb into existing waves W2/W3/W4/W5/W6/W8/W10/W11; nothing added a new wave or removed an existing item.
- **2026-07-20 — ASIP → 🟩 PRODUCTION CERTIFIED (owner-authorized deploy).** Owner approval executed: branch pushed; additive deploy onto the deployed pilot head; 6 migrations applied+ledgered on `akshara_db`; `PLATFORM_ORG`+support principals seeded; live cert 18/18 (test) + 18/18 (production smoke) — 2 real bugs caught live and fixed. ASIP-1…7 → PRODUCTION CERTIFIED. Cert: `docs/SUPPORT_INTELLIGENCE_PLATFORM_CERTIFICATION.md`. Owner tail: real phone numbers on the 4 seeded support principals.
- **2026-07-20 — ADDED §5.6 PROGRAM ASIP (AI Support Intelligence Platform).** Reason: net-new platform capability (customer schools report Akshara product issues to the Akshara Support Team) confirmed genuinely missing after reuse recon (only a read-only `control_center` mock existed). No existing row deleted/re-scoped/weakened — purely additive as an isolated parallel lane that never gates the ERP. Phase 1 (ASIP-1/2/3, within-tenant) is decision-independent and under build; Phase 2 (ASIP-4/5/6/7/8, cross-tenant) is **owner-gated** on Decision A (cross-tenant access model) + Decision B (support workspace surface — the frozen web viewer scope). Design authority: `docs/support-intelligence/ASIP_DESIGN.md`. Owner sign-off pending on Decisions A/B and on live-cert/deploy authorization.

---

*This is the single authoritative roadmap going forward. It is Constitution-driven, repository-aware, and recovers every prior open item. It does not begin implementation — execution starts only on owner instruction, wave by wave, under the standing EOS gate.*
