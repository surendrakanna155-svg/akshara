# PRC-A (Wave A) — Progress & First-Pass Capability Classification

**Wave:** PRC-A (Real School Operations Capability & Cross-Module Gap Audit) — the true current wave per [`RECON-2_EXECUTION_ORDER_CORRECTION.md`](RECON-2_EXECUTION_ORDER_CORRECTION.md).
**Authority:** `../AKSHARA_PRODUCT_REALITY_AND_CORRECTNESS_CERTIFICATION.md` (frozen) + `../roadmap/PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md` (502 reqs).
**Status:** 🔵 IN AUDIT — first-pass (existence/wiring) classification below. **⚠ This is a SCREEN-LEVEL EXISTENCE probe, not the full 13-step method** — "MISSING" (no code) is reliable; "PARTIAL/PROBABLY-WORKING" rows need the deeper UI→API→service→repo→DB + cross-module + dependency-chain trace before any WORKING/LIVE certification. No capability is ✅ without the full method + evidence (tracker state law).

**Execution note (2026-07-14):** the parallel PRC-A audit fleet (transport/finance dependency-chain · new-ops modules · owner-ideas reconciliation) was launched but repeatedly **failed on a transient network fault (`ENOTFOUND`)** mid-run. Foreground probing (resilient to the fault) produced the first-pass below. Resume the parallel fleet (or continue foreground) when the network stabilizes.

## First-pass classification (15 domains / 148 capabilities)

| Caps | Domain | First-pass | Evidence / next step |
|---|---|---|---|
| 1–30 | Transport enrolment/route/fleet/**Finance integration** | ✅ DEEP-AUDIT DONE → **mostly PARTIAL/MISSING** | See detail below. WORKING/LIVE: routes/stops (7), drivers (19), compliance tracking+reminders (18), delay-notify (28), **TRN-9 income seam** (real+idempotent). **The expense/cost half does NOT exist; the cost/dashboard/reports are STATIC SEED served as live** ⇒ every downstream financial metric NOT LIVE (PRC-A-D). |
| 31–36 | Storage quota | ❌ **MISSING** | No `storage_quota`/limit-enforcement code found. Candidate for pre-freeze roadmap placement. |
| 37–43 | AI credit wallet | ❌ **MISSING (as a wallet)** | `ai/ai_economics_service.ts` + `ai_copilot_quota.ts` track cost/quota, but no credit-**wallet**/top-up/balance model. Deep-audit vs the requirement; likely PARTIAL→MISSING. |
| 44–49 | Central AI provider keys | ⏳ DEEP-AUDIT | `ai/ai_settings.ts` + `anthropic_client.ts` (env-key based). "Central managed provider-key layer" (per-tenant/rotating) may be PARTIAL. |
| 50–57 | SaaS plan-limit **runtime enforcement** | ✅→VERIFY | Full `entitlements/` module (`entitlement_enforcement.ts`, `_limits`, `_middleware`, `_resolver`, `_repository`, `_router` + tests) — looks substantially built. Deep-audit that limits are actually **enforced at runtime** on the hot paths. |
| 58–65 | Syllabus progress capture | ⏳ DEEP-AUDIT / likely PARTIAL | `intelligence/teacher_effectiveness_service.ts` exists; no dedicated `syllabus_progress` capture found. Verify whether teachers can record syllabus/lesson completion. |
| 66–75 | Fee-structure bulk assignment | ⏳ DEEP-AUDIT | Finance fee-assignment exists; verify BULK assignment across a class/cohort. |
| 76–81 | Marketing-AI production wiring | ⏳ DEEP-AUDIT (likely owner-gated) | `promotion/` (publisher/captions) exists; production wiring likely needs paid provider creds ⇒ **owner-gated**. |
| 82–89 | Facebook/Instagram production integration | ⏳ likely **OWNER-GATED** | Needs real Meta app creds/review — classify owner-gated, don't build blind. |
| 90–100 | Cross-module cost intelligence | ⏳ DEEP-AUDIT | Depends on transport/AI/inventory cost feeds being real (dependency rule). |
| 101–108 | **Complaint / ticket system** | ❌ **MISSING** | No backend dir, no migration, no `lib/features` module. Genuinely-missing current-scope capability. |
| 109–118 | **Early pickup / gate pass** | ❌ **MISSING** | No gate-pass/early-pickup/visitor backend (the hostel visitor feature is the separate CODE-7-hidden one). Genuinely-missing. |
| 119–127 | **Health / infirmary** | ❌ **MISSING** | Only the system `/health` endpoint exists — no student health/infirmary module. Genuinely-missing. |
| 128–135 | Staff workload intelligence | ⏳ DEEP-AUDIT | Verify vs existing HR/timetable/effectiveness data. |
| 136–148 | Certificate request desk | ⏳ PARTIAL | TC engine exists (`sis/sis_certificates_repository.ts` + handlers, tenant-RLS'd) but a general **certificate-REQUEST desk** (parent/staff request → approve → issue, multiple cert types) is likely broader → PARTIAL. |

## Genuinely-missing current-scope capabilities (candidates for pre-freeze roadmap placement — pending deep-audit confirmation)
1. **Complaint / ticket system** (101–108) — no code.
2. **Early pickup / gate pass** (109–118) — no code.
3. **Health / infirmary** (119–127) — no code.
4. **Storage quota** (31–36) — no enforcement.
5. **AI credit wallet** (37–43) — cost tracked, no wallet/balance model.
6. **Certificate request desk** (136–148) — TC engine only; request-desk workflow likely missing.

*(These are the pre-freeze implementation candidates. Owner-gated: marketing-AI/social production integration (paid providers). The owner-future-ideas queue overlaps heavily with the infra rows (31–57) + provider abstractions — its reconciliation lane will dedupe against these.)*

## Next steps (PRC-A continuation)
1. Deep-audit (full 13-step method) the transport→finance dependency chain (highest-risk: real money) + the ⏳ rows.
2. Complete the owner-future-ideas reconciliation (classify all ~35 items; dedupe vs these caps + existing provider abstractions).
3. Confirm the genuinely-missing modules, **place them into the roadmap** at their correct pre-freeze position, and implement (extend existing architecture, never duplicate; RBAC + tenant isolation per new table).
4. Full regression + EOS PASS per fix batch → PRC-A exit → PRC-B.

---

## PRC-A DEEP-AUDIT FINDINGS — Transport + Finance integration (caps 1–30) — 2026-07-14

**Architecture:** one JSONB entity store `transport_entities` (`entity_type` discriminator). Entity CRUD (route/vehicle/driver/allocation/stop/attendance) is LIVE + tenant-RLS'd + correct RBAC (`viewTransport`/`manageTransport`). **The dashboard/tracking/reports/occupancy KPIs are STATIC SEED snapshots served verbatim, never recomputed.** Ships behind `TRANSPORT_API_ENABLED` (default **false** → mock unless the pilot build sets it — verify).

**WORKING/LIVE:** cap 7 (routes/stops, race-safe RMW) · 19 (drivers, unique licence/ISO expiry/delete-guard) · 18-tracking (TRN-2/TRN-8 compliance ISO-validate + expiry scan + staff digest) · 28-notify (delay broadcast → parents) · **TRN-9 income seam** (`handleRaiseTransportDemand` → Finance `assignFeeStructure` → per-year account + invoice; idempotent + race-tested; honors the TRN-9 owner decision).

**CONFIRMED GAPS (prioritized):**
- **🔴 P0 — real-money over-billing (caps 4 + 9):** `handleRemoveStudentTransport` (`transport_write_handlers.ts:338-379`) **hard-deletes** the allocation (`writeStore.remove:358`) and makes **NO** finance call; there is only a demand-**raise** endpoint (no cancel). → a student who stops transport keeps an **open transport invoice** (over-billing) AND their allocation history is destroyed. Fix: soft-stop with effective date + cancel/void the future fee (reuse the finance cancel path); preserve the row.
- **🟠 P1:** cost-per-student / income-vs-expense / principal dashboard are **static mock** served as live (caps 12/13/30 — incl. "₹84K Fuel — Finance integration placeholder") · fleet **maintenance + fuel + expense sub-domain entirely MISSING** (14–17) so the cost side can never be real · **no driver/bus→route write path** (20+8; `assignedDriverId`/`assignedBus` unreachable from the app → capacity guard silently disabled for in-app routes) · **no effective-date architecture** (5/6/23 — changes overwrite/delete history, mid-month proration impossible) · **admission→transport-enrolment not propagated** (2 — forces duplicate manual entry) · transport-requirement is **binary yes/no** only (3 — no own/parent-pickup enum) · fee **not derived** from route/stop/distance/one-way-two-way (10).
- **🟡 P2 / device-gated:** GPS is a pure placeholder (24–27, hardware-gated) · ships mock-by-default (`TRANSPORT_API_ENABLED=false` — verify the pilot enables it).

**Verdict:** transport CRUD is real, but a real school **cannot** run the full transport operation inside Akshara — expense/cost domain absent, dashboards static, over-billing on stop, no effective dates, admission duplicate-entry. **Highest-value fix order:** (1) P0 fee-revoke-on-stop, (2) expense/maintenance sub-domain + live cost recompute, (3) driver/bus→route write path, (4) effective-date model, (5) admission→transport propagation.
*(This is a substantial multi-wave build; the P0 is the urgent isolated fix. Full detail in the audit transcript.)*

---

## PRC-A DEEP-AUDIT FINDINGS — Infra/entitlements + new-ops modules — 2026-07-14

**Entitlements/plan-limits (50–57):** `ENTITLEMENT_ENFORCEMENT=true` confirmed LIVE; `withEntitlement` wraps 11 module routers (`app.ts:99-140`). **WORKING/LIVE:** school limits (55), feature-entitlement gating (56, 402/403). **PARTIAL:** only 2 of ~6 limit dimensions exist (`LimitKind = students|schools`) — student-slab (52 partial), no staff/user (54). **MISSING:** storage limits (51/31–36 — `storage_service.ts` only per-file validation, no cumulative tracking, no `storage_quota` table, no plan storage column), SMS limits (53). AI limits (52) = a flat W2 quota, not plan-tiered. **PARTIAL/WRONG UX (real gap):** grace/suspension (57) — `status` (`grace|suspended`) is stored + returned but **never read** by the entitlement gate → a suspended org is NOT blocked server-side. *(No billing/renewal by deliberate scope-lock.)*

**New-ops modules — CONFIRMED MISSING (grep false-positives ruled out) + implementation scope (reuse existing architecture, never duplicate):**
| Caps | Module | Status | Scope (reuse) |
|---|---|---|---|
| 136–148 | **Certificate request desk** | **PARTIAL** (issuance engine `sis_certificates_repository.ts` is production-grade) | Missing = the **request→approve** layer in front. New `sis_certificate_requests` table + reuse the **F2 approval framework** (`approval_orchestrator`/`approval_type_handlers`, new type `certificateRequest`) → on approve, call the *existing* `issueCertificate`/`issueTransferCertificate`. New: "fee certificate" type (finance pull). RBAC: `requestStudentCertificate` + `approveCertificateRequest`. **← smallest + highest-value (BUILD FIRST).** |
| 109–118 | Early pickup / gate pass | **MISSING** | New `gate_passes` table + reuse F2 approval + QR/OTP (mirror `finance_qr_repository.ts` create/confirm/expiry) + guardian-scoped RLS (`20260866`). No security-guard role → reuse `officeStaff`. |
| 101–108 | Complaint / ticket | **MISSING** | New `complaints` + `complaint_events` tables (org+school RLS like `student_clearance_waivers`), assign→SLA→resolve, vendor FK (`inventory_vendors`) + expense link, photo via `storage_service`. RBAC: `raiseComplaint`/`manageComplaints`/`viewComplaintsPrincipal`. |
| 119–127 | Health / infirmary | **MISSING** | New `student_health_incidents` + `student_medication_authorizations` + immutable `..._administration_log`. ⚠ **OWNER DECISION needed (cap 127 privacy/RBAC model)** before table design → gate this module on that. Parent notify reuses `communication_service`. |

**Build order (audit recommendation):** **Cert-desk → gate-pass → complaints → health (owner-gated on the privacy model).** Cert-desk reuses the certified issuance engine + F2 orchestrator with only a thin request/approval wrapper + 1 table + 2 permissions — minimal new surface, high daily-frequency value.

---

## PRC-A DEEP-AUDIT FINDINGS — AI wallet / central keys / marketing-social / cost intelligence (37–49, 76–100) — 2026-07-14

**🔴 P1 SECURITY (buildable now, but DEPLOY is owner-gated on a key):** **cap 45 — provider-key "encryption" is FAKE.** `vault/vault_service.ts:34-35` `encryptCredential = btoa(...)` — **Base64, not encryption**; provider API keys (Anthropic/OpenRouter/…) are stored in `platform_secret_vault.encrypted_payload` as reversible base64, while the UI claims "Encrypted at rest." The correct pattern already exists in `social/social_token_crypto.ts` (AES-256-GCM via `crypto.subtle`). **Fix:** replace with AES-256-GCM (async; callers `storeSecret`/`rotateSecret`/`checkSecretHealth`/`resolveAiConfig` are already async), backward-compatible reads (legacy base64 `key_version=1` + new `v2:` AES), secure-by-default (refuse to store without a key). **⚠ OWNER/DEPLOY DEPENDENCY:** prod must set a `VAULT_ENC_KEY` (32-byte) + re-encrypt existing base64 secrets (rotate). → roadmap as the #1 pre-freeze security fix.

**AI credit WALLET (37–43): mostly MISSING.** There is a monthly **spend cap** (governance, resets on the 1st) + rate limits + real per-school usage aggregation (39 LIVE, 42 LIVE, 38 PARTIAL) — but **no purchasable/decrementing wallet balance, no top-up (41), no low-balance alert dispatch (40), no admin credit adjustment (43)**. If a commercial AI-wallet product is wanted → new ledger table + top-up/adjust endpoints (current model is a governance backstop, not a wallet). *(Product-scope owner decision: is a wallet in current scope, or is the spend-cap model sufficient for pilot?)*

**Central AI keys (44–49):** 44 (central mgmt) + 49 (school isolation) **LIVE**. 46 (rotation), 48 (health): backend exists, **no Flutter UI trigger**. **47 (failover): `resolveFailoverSecret` is DEAD CODE (zero callers)** — automatic provider failover doesn't happen; only manual enable/disable.

**Marketing/social (76–89):** text caption generation + approval workflow + publish-history **LIVE**; **image/poster generation MISSING → OWNER-GATED** (needs a paid image-gen provider + hosting, honestly stubbed today). Social backend (OAuth + AES-256-GCM tokens + real Graph API + dry-run) is **production-grade but has NO Flutter client screen** (buildable now, no external dep); **live publish = OWNER-GATED** (Meta App Review + `META_APP_ID/SECRET/SOCIAL_TOKEN_ENC_KEY`). Token refresh/expiry (84), reconnect (85), scheduled publish (86): MISSING.

**Cross-module cost intelligence (90–100): mostly MISSING.** Production payload hardcodes `expenseBreakdown: []`; no budget/asset/event-cost modules; transport/fleet costs mock-only (ties to the transport expense-domain gap). Inventory costs (95) is the one real input. → depends on the transport expense-domain build + a cost-aggregation layer.

## Owner-level decisions surfaced by PRC-A (do not resolve autonomously)
1. **Health-data privacy/RBAC model** (cap 127) — shapes the health-module table/RLS design; gate the health module on this.
2. **`VAULT_ENC_KEY` provisioning + secret re-encryption** — required to deploy the provider-key AES-GCM security fix.
3. **AI credit-wallet product scope** — build a real wallet, or is the spend-cap governance model sufficient for pilot?
4. **Meta App Review + credentials** (live FB/IG publish) and an **image-generation provider** (AI posters) — paid/external, classify owner-gated.
5. **Marketing ad-spend ledger** — only if the school buys paid channels (not currently scoped).

---

## OWNER-FUTURE-IDEAS RECONCILIATION — COMPLETE (40 items) — 2026-07-14
**Verdict: the queue is largely already-handled — NOT a big pile of missing work.** Of 40 items: **IMPLEMENTED** (push/email/WhatsApp/AI-provider-config/secrets-vault/entitlement-flags/report-export/audit-framework/approval-engine/analytics-client/tenant-isolation — 2,3,5,13,19,26,33,34,36,37,38); **PARTIALLY IMPLEMENTED but adequate/provider-tied** (payment/storage/PDF/SMS-OTP/identity/data-import/policy-settings — 1,4,7,10,12,16,28,35); **COVERED BY PRC** (date-engine 31 + money-engine 32 = PRC-B; plan-limits 27/36 = PRC-A); **ALREADY ROADMAPPED** (OCR 6 = K-lane); **OWNER-GATED / POST-GA** (GPS 14, maps 15, white-label/website 17, backup-offsite 18, eSign 20, translation 30, public-API 40); **REJECTED** (biometric devices 9 — attendance-auth decision); **NOT-REQUIRED-YET by their own rules** (search 21, job-queue 22, scheduler 23, FSM 39).

**CURRENT-SCOPE GENUINELY MISSING (only 4 — the pre-freeze reconciliation candidates):**
1. **Item 11 — Accounting/Tally export adapter** (GL/tax mapping export off the report-export service) → Finance-domain roadmap item, **low urgency**, zero current coverage.
2. **Item 24 — Communication channel orchestrator** — the real one: `whatsapp_providers.ts` exists but is **stranded in `school_completion`, unreachable from the main Communication channel switch** (`sms|email|push` only) + no escalation/fallback policy. → wire WhatsApp into the channel enum + escalation layer. **Concrete + valuable.**
3. **Item 25 — Shared webhook HMAC/replay framework** (extract the duplicated Razorpay/comms HMAC verify) → infra-hardening, low urgency (before the next external webhook).
4. **Item 29 — Malware/content scanning on uploads** (extend `validateUpload` extension/MIME/size with AV scanning for homework/certs/admissions docs) → security-hardening.

*(These 4 → roadmap-place at their canonical positions; none is urgent-blocking. The full 40-row table is in the reconciliation transcript.)*

---

---

## PRC-A DEEP-AUDIT FINDINGS — Academics/HR: syllabus (58–65) · fee-bulk (66–75) · staff-workload (128–135) — 2026-07-14

**🔴 P0 — Fee concession/scholarship award SILENTLY doesn't reduce fees (cap 71 — financial-honesty bug).** The user-reachable award path (`lib/features/finance/finance_workflow_actions.dart:335-410` → `approval_type_handlers.ts:170-196`, `payableApplied:false`) **never touches `finance_student_accounts`/invoices** — yet the UI banner (`finance_discounts_screen.dart:56-58`) **falsely claims it "reduces their fee for real."** The CORRECT money-safe maker-checker engine (`finance_fee_reductions_repository.ts`, routes `finance_router.ts:431-448`) is fully built + certified but has **ZERO Flutter callers (dead code)**. **Fix (no new backend):** rewire the client to the fee-reductions endpoints with a real student picker; retire the broken `feeConcession` approval effect. **← highest-value contained fix (reuses a certified engine).**

**🔴 P0 — No bulk/class-wide fee-structure assignment (caps 66/69).** Every assignment is one student at a time via the admissions-handoff queue (`finance_assignments_repository.ts` — all paths take one `student_id`). Fix: `POST /finance/fee-assignments/bulk` (class/section → one txn reusing `assignFeeStructure`) + a bulk screen.

**🟠 P1:** fee structures have **no real class/section binding** (67 — "Class range" is just the free-text `description`; blocks bulk + class-transfer) · **syllabus daily-capture UI is a non-functional demo** (58–61 — hardcoded fields; "mark complete" sends a fabricated `topic_id` that fails the FK) · **the entire School-Completion hub (~20 screens incl. syllabus) has ZERO inbound navigation** (only a typed URL). Syllabus homework-link (62) + photo-evidence (63) MISSING.

**WORKING/LIVE:** academic-year fee structures (68) · transport-fee integration (72, TRN-9) · **staff-workload class/subject load (129), uneven-workload detection (134), principal visibility (135)** — workload intelligence is one of the *strongest* groups (real data, honest empty states, RBAC'd, in-nav). **MISSING within it:** free-periods (130), substitution burden (131), non-teaching/exam/event duties (132/133), department dimension.

**P2/P3:** structure revisions don't propagate arrears to billed students (75) · mid-year admission bills full annual fee, no proration (73 — confirm intent) · syllabus "days-pending" alert is a hardcoded 7, not computed (65) · no distinct HOD role.

---

## ✅ PRC-A Wave-A AUDIT COMPLETE (5/5 lanes) — classification pass
All 148 capabilities classified + owner-ideas (40) reconciled. **This is the classification pass, NOT certification** — no capability is ✅ WORKING/LIVE without its confirmed fix + regression (tracker state law).

### Confirmed P0/P1 — pre-freeze fix priority (highest-value / most-contained first)
| # | Finding | Sev | Contained? | Owner dep? |
|---|---|---|---|---|
| 1 | **Fee concession award is a silent no-op** (UI claims fee reduced; it isn't) — rewire client to the certified `finance_fee_reductions` engine | P0 | ✅ client rewire, reuses certified engine | none |
| 2 | **Transport stop → over-billing** (fee not revoked + history hard-deleted) | P0 | needs a finance-cancel path | none |
| 3 | **No bulk fee-structure assignment** (one-at-a-time only) | P0-ops | new bulk endpoint + screen | none |
| 4 | **Provider-key "encryption" is fake Base64** (`vault_service.ts`) → AES-256-GCM (reuse `social_token_crypto`) | P1-sec | code contained | **VAULT_ENC_KEY (owner) + re-encrypt** |
| 5 | Fee structures lack real class/section binding (blocks bulk + class-transfer) | P1 | migration + wiring | none |
| 6 | School-Completion hub (incl. syllabus capture) unreachable + capture UI non-functional | P1 | nav + form wiring | none |
| 7 | grace/suspension entitlement status stored but never enforced | P1 | contained | (policy check) |

### Missing modules (build order — all reuse existing architecture)
**Cert-desk (136–148, PARTIAL, smallest — reuses F2 + issuance engine) → gate-pass (109–118) → complaints (101–108) → health (119–127, ⚠ owner privacy model first).** Plus infra: AI-credit-wallet (owner scope), storage-quota, cross-module cost-intelligence (depends on transport expense-domain).

### Owner-future-ideas (40) — only 4 genuinely-missing, low-urgency: Item 11 Tally-export · **Item 24 WhatsApp-stranded-from-channel-switch** · Item 25 shared-webhook-HMAC · Item 29 upload-malware-scan.

### Owner-level decisions to surface (do NOT resolve autonomously)
Health-data privacy/RBAC model · VAULT_ENC_KEY provisioning + secret re-encryption · AI credit-wallet product scope (wallet vs spend-cap) · Meta App Review + credentials (live FB/IG) + AI image-generation provider (paid) · mid-year fee proration policy (73).

---

# 🔧 PRC-A FIX PHASE — started 2026-07-15

## 🔓 All 5 surfaced owner decisions are now LOCKED (owner directive 2026-07-15) — build, do not re-ask
1. **Health/infirmary** — BUILD NOW with strict need-to-know least-privilege RBAC. No blanket teacher access; appropriate health staff + explicitly authorised leadership only; teachers get the minimum actionable info for a legitimate care workflow. Tenant isolation + audit on sensitive reads/writes. No health detail via generic search/notifications/analytics/logs/broad profile surfaces. Full operational module, not tables + a placeholder.
2. **VAULT_ENC_KEY** — implement AES-256-GCM now on the proven substrate; provision the key via existing deploy authority; never commit/log/expose it; migrate existing secrets with rollback evidence.
3. **AI credit wallet** — BUILD, but reconcile into ONE coherent model with the existing spend-cap governance / entitlements / quotas / AI call logging / reservations. No second competing quota system. Product usage units, NOT currency semantics. Reservation/commit/release correctness; no double-consumption, negative-balance races, or retry duplication.
4. **Meta social + AI poster** — complete ALL internal product work now (workflow, provider abstraction, authz, tenant boundaries, approval/governance, scheduling/retry/idempotency, failure handling, audit/history, UI + real backend wiring, provider-contract tests). Isolate ONLY the external activation step. Never fake live publishing or external certification. Poster engine must be provider-neutral behind a canonical image-gen interface + per-tenant reusable brand/marketing profile + minimum-relevant-asset selection + a canonical media-prep policy (validate → malware pipeline → inspect dims → normalise orientation → dimension-aware resize → efficient encode; never blind-send a 200MB file; don't destroy clarity). Poster stays the canonical Akshara artifact; social = delivery destination only.
5. **Mid-year admission fee proration** — configurable school policy (full annual | prorate-from-month | other policy-safe existing behaviour). Never one hardcoded universal rule. Applied policy visible to authorised users; overrides keep actor/reason/timestamp/audit. Deterministic; no floating-point money errors.

## ✅ Fixed + committed (each with regression tests; full backend tree green)
| Commit | Cap | Fix |
|---|---|---|
| `4bc1046b` | **NEW** (not in the audit) | **P0 — account resolution broken for every invoice after a student's FIRST fee structure of the year.** `finance_student_accounts` is `UNIQUE (student_id, academic_year)` but its `fee_assignment_id` is frozen at the FIRST assignment, while TRN-9 get-or-create reuses that account for later structures. All 4 money joins keyed `fsa.fee_assignment_id = fi.fee_assignment_id` → **0 rows for a transport invoice**: payment not collectible, late fee **silently never accrued** (under-billing), concession rejected 422. Re-keyed to the real business key (`student_id + academic_year`). |
| `4bc1046b` | **NEW** (not in the audit) | **P0 — `cancelInvoice` left the money owing.** Account `total_fee`/`outstanding_amount` are STORED aggregates that nothing re-derives; cancel only flipped `invoice_status` ⇒ false defaulter + **blocked no-dues/TC gate** (`sis_certificates_repository` reads it fail-closed). Now releases the unpaid remainder in lockstep + adds the missing status guard (the old read was TOCTOU ⇒ concurrent double-cancel double-released). |
| `9d1a3c48` | 45 | **P1-sec — provider secrets really encrypted (owner #2).** AES-256-GCM (fresh IV/encryption, fails closed, `v2:` versioned + backward-compatible legacy reads), idempotent re-encryption backfill wired at `POST /control-center/vault/reencrypt`. Key is a deploy-time secret, never in the repo. |
| `fb39dfcc` | **71** | **P0 — the fee concession/scholarship award now really reduces the fee.** The reachable path never even reached the repository (fabricated `concession_<ts>` id → `payableApplied:false` approval effect, or an in-memory store). Rewired the client onto the certified invoice-scoped `finance_fee_reductions` maker-checker; checker surface (approve/reject/reverse) added; the lying banner corrected; the no-op path retired (`submitForApproval` now has zero callers). |
| `a7f3a1f3` | **4/9** | **P0 — stopping transport now revokes the fee and keeps the history.** Was a hard-DELETE with NO finance call (history destroyed + invoice left open). Now soft-stops with an effective date, cancels the linked invoice through Finance (releasing the account), and releases the demand `dedupeKey` — without which a re-enrolment would match the old demand as "idempotent" and raise NO fee (a free ride). A PAID invoice is skipped + reported (refund is Finance's call). |

## ⚠ New findings from the fix phase (reclassifications — dependency rule PRC-A-D-01/03)
- **Caps 44–49 are NOT `WORKING/LIVE` — the platform secret vault is UNREACHABLE in production.** `platform_secret_vault` has **no grant to `erp_tenant`** + FORCE RLS + a `deny_all` policy (deliberate RT-15 defence, migration `20260815`, recorded from a LIVE probe). But every vault handler *and* `resolveAiConfig` run through `withTenantContext`, which is by design the non-bypass `erp_tenant` role ⇒ store/rotate/health/reencrypt all fail `permission denied`, and `resolveAiConfig` **silently swallows it via SAVEPOINT/ROLLBACK and falls back to the `ANTHROPIC_API_KEY` env** (documented in its own comment). The Control-Center provider panel is decorative. **There is no platform/service DB helper — only `tenant_db.ts`.** → Fix = a platform-scoped DB path (a granted `erp_platform` role + an explicit RLS allow policy, or SECURITY DEFINER fns) used ONLY by superadmin-gated platform handlers. **Never grant `erp_tenant`** (that would undo RT-15). The AES fix is correct but dormant until this lands. **Reclassify 44/49 from LIVE → PARTIAL/MOCK pending this.**
- **⚠ Certification-integrity caveat:** the backend fake DB **pattern-matches SQL strings and never evaluates JOINs**, so the account-resolution defect was structurally invisible to the suite — which is exactly how the fee-reductions engine shipped "certified" with a broken join. **Treat "certified" on any JOIN-dependent money path as UNPROVEN until live-probed on real Postgres** (`/certify`). Live verification of the 2nd-structure money fixes is a required deploy step, not optional.

## Next in the fix phase
Vault platform-DB path (makes 45 + 44–49 real) → bulk fee assignment (66/69, in progress) → class/section binding (67) + configurable proration (73, owner #5) → School-Completion hub nav + syllabus capture (58–65) → grace/suspension enforcement (57) → then the missing modules (cert-desk → gate-pass → complaints → health) → AI wallet + storage quota → marketing/poster/social → WhatsApp/webhook-HMAC/Tally → transport expense domain + cost intelligence → PRC-A exit (EOS) → PRC-B.

---

# 🔨 PRC-A BATCH 2 — BUILD COMPLETE (2026-07-16) · EOS: CONDITIONAL PASS · **NOT CERTIFIED**

**Commits:** `675998aa` (backend) · `c17fb326` (audit + RBAC inventory) · `ace06ea0` (Flutter clients) · `69fd2e6c` (routes + nav + health handler/router tests).
**Gates:** backend **3343 passed / 0 failed / 3 ignored** (baseline 2990) · `deno check` clean · Flutter **+4068 / ~1** (baseline +4007) · `flutter analyze` **0**.

| Caps | Module | Was | Now |
|---|---|---|---|
| 136–148 | Certificate request desk | PARTIAL | request→approve layer in front of the **existing certified** issuance engine (new `sis_certificate_requests` + F2 `certificateRequest`); new **"fee"** cert type on a real finance pull |
| 109–118 | Gate pass / early pickup | MISSING | `gate_passes` + F2 `gatePass`; single-use OTP/QR (`crypto.getRandomValues`, **hashes only**, constant-time compare, TTL `scheduled_at+4h`); OTP dispatched to the guardian, never in a response or the persisted approval effect |
| 101–108 | Complaint / internal issue | MISSING | `complaints` + append-only `complaint_events`; deterministic `(category,severity)` SLA table; enforced legal-transition table |
| 119–127 | Health / infirmary | MISSING | owner decision #1 as strict need-to-know; new `healthStaff` role; immutable administration + access logs |

## Health RBAC as built (owner decision #1) — teachers get NO clinical surface
`manageStudentHealth` → `healthStaff` ONLY · `administerStudentMedication` → `healthStaff` ONLY (a separate gate from manage, proven by test) · `viewStudentHealthRecord` → `healthStaff` + `principal` + `vicePrincipal` ONLY (**not** teacher/classTeacher/coordinator/officeStaff/schoolAdmin/management/superAdmin/org admins) · `viewStudentCareAlert` → teaching roles, carrying **no clinical detail**, narrowed server-side to students the caller actually teaches (roster §section-FK ∪ roster §text-labels ∪ timetable incl. substitutes) and **failing CLOSED** when unresolvable. A teacher cannot reach `/student-health` at all.

## 🔴 Two P0s found DURING the batch and fixed before shipping (neither ever deployed)
1. **Phantom Transfer Certificate.** The cert-desk approval effect caught `NoDuesPendingError` / `InvalidStudentStatusTransitionError` to report a friendly `blocked_dues` (reasoning by analogy from `case "refund":`). But the TC engine throws BOTH from **after** it has burned a sequential serial and inserted the issue row (`sis_certificates_repository.ts:525` waiver-consume race, `:560` prior-status guard) — those throws **are** the rollback that prevents a duplicate legal document. Catching them committed a phantom TC: burned serial, issue row present, no clearance snapshot, student never flipped, request reporting `blocked_dues`. The two throw sites are indistinguishable by type, so type-based catching cannot be made safe → the one recoverable gate (real dues) is now **pre-checked** via the same waiver-aware `clearance_gate` the engine uses, and every engine throw propagates and fails closed. **The fake DB cannot model rollback, so no unit test could ever have caught this** — it passed 235 tests.
2. **A permission gate that could never open.** Gate-pass wrapped its raise FAB / verify action / cancel in `AksharaManageAction` → `ManagePermissionGuard` → `hasManagePermission` == `isManagePermission(p) && hasPermission(p)`, and `isManagePermission` is literally `p.name.startsWith('manage')` (`mutation_permission_validator.dart:19`). `requestGatePass`/`verifyGatePass`/`approveGatePass` match neither `manage*` nor `approve*` ⇒ **failed closed for every caller**; three affordances were dead UI. Now plain `hasPermission`. ⚠ **The naming convention is load-bearing and invisible at the call site** — the cert-desk agent hit this independently and documented it; the gate-pass agent did not.

## Also fixed
- **gate-pass writes were unaudited** — caught by QA-R-008 when the routes were registered in `RBAC_ROUTE_INVENTORY`. "Who released this child at the gate" is the module's whole point. Now `moduleEntityAudit` on raise/verify/cancel, inside the same transaction as the guarded write.
- **`requireSchoolOperationalScope` (~98 call sites, EVERY module)** hardcoded *"Admissions operational data requires school scope"* — a copy-paste artifact. A Student Health caller was told about Admissions, and that wrong domain was captured verbatim in the 403 body, request log and access-denied audit. Never a security bug; actively misleading in the trail for the most sensitive domain. Now domain-neutral + optional label; no test asserted the old string.
- Migration numbering: `20260884` was "queued" for caps 62/63 in the handoff but referenced **nowhere** in the repo. Batch 2 takes `20260884`–`20260887` **contiguously**; caps 62/63 get a fresh higher number when built (a gap would make them sort behind already-applied migrations).

## ✅ BATCH 2 — LIVE CERTIFIED (2026-07-16). All 6 owner-required probes PASS.

Deployed (`fefcede1`, prod `20260881`→`20260887`), then every remaining item certified against **real Postgres** as the **real `erp_tenant` role**, using `app.set_request_context(...)` — byte-identical to what `withTenantContext` does in production, so RLS is genuinely evaluated, not simulated. All probes ran inside `BEGIN…ROLLBACK`.
Reproducible artifacts: [`live_probe_money_p0_account_resolution.sql`](../../scripts/qa/live_probe_money_p0_account_resolution.sql) · [`live_cert_batch2_rls_parent_scoping.sql`](../../scripts/qa/live_cert_batch2_rls_parent_scoping.sql) · [`live_cert_batch2_teacher_scoping.sql`](../../scripts/qa/live_cert_batch2_teacher_scoping.sql) · [`live_cert_batch2_rbac_constraints_money_p0_2.sql`](../../scripts/qa/live_cert_batch2_rbac_constraints_money_p0_2.sql)

| # | Owner-required probe | Verdict | Exact evidence |
|---|---|---|---|
| 1 | **RLS tenant isolation** | **PASS** | org B context reading org A's clinical rows → **0** `student_health_incidents`, **0** `student_care_alerts`. **Control:** org A context reading its OWN row → **1** (proves the isolation probe is not a vacuous false-pass). |
| 2 | **Parent/guardian scoping** | **PASS** | ParentA (`scope=parent`, `app.parent_user_id=ParentA`): own child's alert = **1**; the OTHER parent's child's alert = **0**. |
| 3 | **teacherTeachesStudent** | **PASS** | Verbatim production SQL. Teacher DOES teach StudentA → **1 link** (care alert allowed). Teacher does NOT teach StudentB → **0 links** ⇒ **fails CLOSED**. |
| 4 | **healthStaff resolution** | **PASS** | `role_permissions[healthStaff]` = `administerStudentMedication, manageStudentHealth, viewStudentCareAlert, viewStudentHealthRecord` (4 = the designed set). `manageStudentHealth` → **healthStaff ONLY**. `administerStudentMedication` → **healthStaff ONLY** (a genuinely separate gate). **0** teaching/admin roles hold `viewStudentHealthRecord`. |
| 5 | **Unique constraints** | **PASS** | Postgres raised `unique_violation` on the 2nd open pass: `duplicate key value violates unique constraint "uq_gate_passes_open_slot"`; and on the 2nd open request: `"uq_sis_certificate_requests_open"`. Both exception-trapped, so PASS is explicit. |
| 6 | **Money P0 #2 — cancelInvoice lockstep** | **PASS** | Verbatim production statements. Account outstanding **8000.00 → 0.00**, `total_fee` → **0.00** (without lockstep the student stays a FALSE DEFAULTER and their no-dues/TC gate stays blocked). **Double-cancel guard:** 1st cancel matched **1** row, 2nd matched **0** ⇒ the release cannot be applied twice (the old unguarded read was TOCTOU). |

Plus, certified at deploy time: **money P0 #1** (OLD join → **0 rows** = defect reproduced; NEW join → **1 row** = fix confirmed) · **immutable logs genuinely enforced** (as `erp_tenant`, Postgres refused UPDATE of the medication administration log and DELETE of the health access log + complaint timeline — *permission denied*) · **route contract** (`/health` still 200 ⇒ not shadowed by `/student-health`; all 5 routes 401; unmatched-in-prefix 404) · **RT-15 intact** (`erp_tenant` holds NO grants on `platform_secret_vault`).

**Probe residue on prod: `students(0) users(0) orgs(0) classes(0) structures(0) invoices(0) care_alerts(0)`** — every probe rolled back cleanly. *(Three `ZZ …` students dated 2026-06-23 exist from a prior session's test data — verified NOT mine.)*

⚠ **One correction, recorded honestly:** an earlier assertion "healthStaff resolves to exactly 3 permissions" reported FAIL. That was **the probe's error, not a code defect** — the design (and the migration) deliberately grants a 4th, `viewStudentCareAlert`, because health staff author the care alerts they read. Expectation corrected; the security-critical half (clinical perms are healthStaff-only) passes independently.

### ⇒ EOS GATE RE-RUN: **PASS**. Batch 2 = **LIVE CERTIFIED**.
Part 7B — *Mandatory Certification Rules* is now satisfied: critical workflows are verified and required permissions are verified, on real Postgres. No open P0. No automatic-failure condition.

### Still open (does NOT block Batch 2 certification — tracked)
- **Caps 44–49 remain PARTIAL by owner decision** — `VAULT_ENC_KEY` deliberately unprovisioned; the AES vault fails closed. No fake-encrypted secrets exist.
- Residue: no parent-facing UI · parent cannot self-cancel · no complaint reassignment · 295 stale `*_test.ts` in the prod edge tree (pre-existing, never executed).

---

## (superseded) EOS GATE at BUILD close: **CONDITIONAL PASS** — Merge/QA only. **BLOCKED at Staging/Pilot/Production.**
No Part 7B *Automatic Failure Condition* triggered; **no open P0**; no critical regression. But Part 7B — *Mandatory Certification Rules* is not satisfiable today:
- **"Critical workflows are unverified"** — raise→approve→issue, gate verify, and the care-alert journey have never run against real Postgres.
- **"Required permissions are unverified"** — code-level gates are proven (103 handler/router tests); **RLS is not**. The fake DB pattern-matches SQL and evaluates **neither JOINs nor RLS**, which is precisely how the fee-reductions engine once shipped "certified" with a broken join.

⇒ **Batch 2 BUILD = complete. Batch 2 CERTIFICATION = NOT DONE.** Do not claim LIVE/CERTIFIED from these green tests.

## ✅ LIVE-POSTGRES PROOF — money P0 #1 (account resolution) CERTIFIED 2026-07-16

**VPS restored.** Ran the first item that the fake DB structurally could not judge. Probe is committed + reproducible: [`scripts/qa/live_probe_money_p0_account_resolution.sql`](../../scripts/qa/live_probe_money_p0_account_resolution.sql) (real `akshara_db`, seeded tuition+transport structure→assignment→account→invoice chain for one student, all inside `BEGIN … ROLLBACK`).

**Result on real Postgres:**
| Join | Rows | Verdict |
|---|---|---|
| **OLD** `fsa.fee_assignment_id = fi.fee_assignment_id` | **0** | **P0 REPRODUCED** — the transport invoice resolves to NO account ⇒ payment not collectible, late fee silently never accrues (under-billing), concession 422 |
| **NEW** `student_id + academic_year` | **1** | **FIX CONFIRMED** — the transport invoice resolves to the student's account |

Prod schema independently confirms the premise: `finance_student_accounts` is `UNIQUE (student_id, academic_year)` with `fee_assignment_id NOT NULL` — ONE account per student-year, its `fee_assignment_id` frozen at the FIRST assignment, while TRN-9 reuses that account for later structures.
**Residue check after ROLLBACK: `students=0 structures=0 invoices=0`** — nothing persisted; prod untouched.
⇒ **Cap: money P0 #1 = CERTIFIED (live).** The defect was real, and the fix is real — now proven by Postgres, not by a mock.

### 🔒 P1 — the live-probe list (VPS is now UP; these remain UNPROVEN until run)
⚠ The 6 pending migrations (`20260882`–`20260887`, incl. **two new DB roles** `erp_platform` + `healthStaff`) and the PRC-A edge bundle are **NOT deployed** — prod is at `20260881`. Batch 2's tables do not exist on prod, so items 1–6 below cannot be probed until that deploy happens. **Deploy to SHARED prod is owner-gated** (see the deploy note at the end of this section).
1. RLS tenant isolation on all Batch 2 tables (org/school predicates actually block cross-tenant reads).
2. Parent/guardian scoping via the `student_guardians` subquery — a parent sees only their own child's certificate requests / gate passes / complaints / health rows.
3. `teacherTeachesStudent` — the live 3-way UNION over roster/section-labels/timetable, incl. the `sis_student_enrollments.section_id` NULL soft-FK edge.
4. Immutability of `student_medication_administration_log` + `student_health_access_log` at the GRANT/RLS level (today proven only by source/migration text inspection).
5. `healthStaff` role + its 3 grants resolving end-to-end through live `role_permissions` → JWT → `claims.permissions`.
6. Partial-unique constraints (`uq_gate_passes_open_slot`, the cert-desk open-request guard) — the constraint-violation catch matches an error string never triggered against real Postgres.
7. **Money P0 #2 — `cancelInvoice` lockstep** (`4bc1046b`): still uncertified. Unlike #1 it is not a pure JOIN-semantics question — it needs the FIXED edge deployed to exercise the guarded status write + the account release under concurrency. → certify in the deploy wave.
   *(Money P0 #1 — account resolution — is now **CERTIFIED live**; see the section above.)*

### 🚧 Deploy gate — needs an owner decision before prod
Prod is at `20260881`; local is at `20260887`. Pending: **6 migrations** (`20260882` platform DB role · `20260883` fee-structure class binding · `20260884`–`20260887` Batch 2) **creating two new DB roles** (`erp_platform`, `healthStaff`), plus the whole PRC-A edge bundle (money-path changes incl. the fee-concession rewire, transport-stop revoke, bulk assign, AES vault, proration, + the 4 Batch 2 modules). This is a **shared** production host (velora-salon / n8n / redis also live here — never touch).
**Known deploy dependency:** the AES vault path **fails closed** without `VAULT_ENC_KEY` provisioned in the prod edge env; deploying it unprovisioned would break storing/rotating provider secrets. Owner decision #2 authorised the key — it must be **set at deploy time**, and existing base64 secrets re-encrypted via `POST /control-center/vault/reencrypt`, with rollback evidence.

### Honest residue (not fixed, deliberately not hidden)
- **No parent-facing UI** for cert-requests / gate-pass / complaints. The API supports parent scope and RLS allows parent SELECT+INSERT, but no parent screen exists.
- **Parent cannot self-cancel** a request they raised (cert-desk + gate-pass): parent RLS is SELECT+INSERT only, so only staff can cancel. Matters most for gate-pass, where an approved pass carries a live 4h credential the requester cannot revoke. Fix = a narrow parent UPDATE policy (`USING` own-child ∧ `raised_by`=self ∧ status∈(pending,approved), `WITH CHECK status='cancelled'`) + relaxing the handler's school-scope gate.
- **Complaints**: no reassignment endpoint once assigned; vendor-attach folds into a `commented` event (no `vendor_attached` enum value); photo upload declares `photo_path` optimistically before the client PUT completes (pre-existing pattern, inherited from admissions-documents).
- **Storage quota still absent** (caps 31–36) — complaint photos are validated per-file but not counted against any cumulative quota.

---

# 🔨 PRC-A BATCH 3 — AI CREDIT WALLET (caps 37–43, owner decision #3)

Owner law: "BUILD, but reconcile into ONE coherent model with the existing spend-cap
governance / entitlements / quotas / AI call logging / reservations. No second competing
quota system. Product usage units, NOT currency semantics. Reservation/commit/release
correctness; no double-consumption, negative-balance races, or retry duplication."

**Commits:** `5df4282e` (wallet CORE — projection over the existing ledger + admit clause) · `0294f10f` (Wallet HTTP APIs) · this doc/cert.

## Design (honours owner #3 — no second system)
The wallet owns NO counter. Balance is a PROJECTION over rows that already exist:
`available = SUM(ai_credit_entries.units) − SUM(ai_call_log.credits_debited) − SUM(pending ai_call_reservations.credits_reserved)`.
Enforcement is a FOURTH AND-term inside the SAME atomic INSERT..SELECT admit clause in
`ai_call_reservations_repository.ts`, under the existing `pg_advisory_xact_lock` — not a
new gate. Entitlements deliberately NOT used (headcount-slab axis ≠ consumable AI axis).
Ships DARK (`AI_WALLET_ENFORCEMENT` default OFF) so deploying can't 0-balance-deny every org.

## APIs (`0294f10f`)
- `GET /ai-wallet` — balance + health + ledger (**viewAiWallet**, org-level).
- `POST /ai-wallet/grant` — top_up | adjustment | expiry (**manageAiCredits**, superAdmin ONLY — a tenant topping up its own wallet = no wallet). Audited via `moduleEntityAudit("aiWallet.credit_granted")` in the same tenant txn as the insert. No UPDATE path (reversal = compensating row).
- Backend **3375 passed / 0 failed / 3 ignored** (was 3364). `deno check` + `deno lint` clean.

## ✅ DEPLOYED — 2026-07-16 (prod `20260887` → `20260888`)
Backup → migrate (as `supabase_admin`, `--single-transaction` with the ledger INSERT) →
`rsync --delete --exclude='*_test.ts'` edge → `docker restart akshara-edge` → health.
Schema verified live: `ai_credit_entries` **rls=t forced=t**, 2 policies, `erp_tenant`
grant = **INSERT,SELECT only** (no UPDATE/DELETE), `credits_debited`/`credits_reserved`
columns present, `outcome` CHECK widened with `fallback_wallet_empty`, `manageAiCredits`
→ **superAdmin only**, `viewAiWallet` → management/organizationAdmin/organizationOwner/superAdmin.
Route contract on `127.0.0.1:3000`: `/ai-wallet` **401**, `/ai-wallet/grant` **401**,
`/ai-wallet/nope` **404**, `/health` **200** (not shadowed), level-50 errors **0**.

## ✅ LIVE CERTIFIED — 2026-07-16. All 6 probes PASS on real Postgres.
Reproducible: [`live_cert_batch3_ai_wallet.sql`](../../scripts/qa/live_cert_batch3_ai_wallet.sql) · [`live_cert_batch3_double_spend.sh`](../../scripts/qa/live_cert_batch3_double_spend.sh). Both as the REAL `erp_tenant` role via `app.set_request_context` (identical to `withTenantContext`); ROLLBACK / tagged-delete so prod is untouched.

| # | Probe | Verdict | Evidence |
|---|---|---|---|
| 1 | **Double-spend prevention** (the core claim) | **PASS** | Two CONCURRENT admits (verbatim production INSERT..SELECT + the same `pg_advisory_xact_lock(hashtextextended(org||':'||coalesce(school,'org'),42))`) against a wallet of 5 credits, each wanting 3. Session A → 1 reservation id; Session B → **0 rows** (A's committed hold made balance 5−3=2 < 3). **Exactly 1** pending hold survived; available = **2**. The fake DB cannot evaluate this. |
| 2 | **Balance projection** | **PASS** | `granted=85 debited=30 reserved=20 available=35` on the EXACT `readWalletBalance` SQL. A **consumed** reservation of 50 was correctly NOT counted (only `status='pending'` is in-flight). |
| 3 | **RLS org-isolation** | **PASS** | org B context reading org A's credit rows → **0**. Control: org A → **3** (probe not vacuous). |
| 4 | **DB sign CHECK** | **PASS** | `top_up<0`, `expiry>0`, `adjustment=0` all rejected by `ai_credit_entries_units_sign_check` (3/3). |
| 5 | **Append-only immutability** | **PASS** | As `erp_tenant`: UPDATE and DELETE on `ai_credit_entries` both `permission denied` (2/2). A ledger you can silently rewrite is not a ledger. |
| 6 | **Zero residue** | **PASS** | After every probe: `ai_credit_entries=0`, tagged rows=0, org wallet balance back to **0**. Prod untouched. |

⇒ **Batch 3 (backend/data-plane) = LIVE CERTIFIED.** No open P0. Ships DARK (enforcement OFF) — flipping `AI_WALLET_ENFORCEMENT=true` needs only an edge restart, once real balances are granted.

> **⚠ INFRA BLOCKER (2026-07-16, AFTER Batch 3 cert) — RESOLVED same day:** the VPS SSH control-master briefly died after Batch 3's certification; the owner re-established the tunnel and Batch 4 was then deployed + certified (below). Batch 3 was unaffected (certified before the outage).

---

# 🔨 PRC-A BATCH 4 — STORAGE QUOTA (caps 31–36)

The audit found uploads are validated PER FILE but there is NO cumulative tracking,
NO storage_quota table, NO plan storage column — an org can accumulate unlimited
storage one acceptable file at a time. Batch 4 adds the cumulative half, mirroring
the live-certified Batch 3 wallet.

**Commits:** `2c745d5d` (backend) · this doc/cert · (Flutter Control Center panel — separate).

## Design (honours "no second limit system")
Usage is a PROJECTION over an append-only signed ledger (`storage_usage_entries`:
upload +bytes, delete −bytes, usage = SUM) — never a mutable counter. The limit
lives in the EXISTING plan-limit system (`subscription_plans.max_storage_bytes`,
threaded through `resolveSubscription` alongside the student/school slabs).
Enforcement is SOFT check-then-act, identical to `enforceStudentLimit` (money needs
the wallet's atomic admit; bytes do not — a small transient over-quota is accepted
by design), fail-OPEN on error. Ships DARK behind `STORAGE_QUOTA_ENFORCEMENT`
(default off) **and** all plan limits NULL — two independent brakes.

## Wiring
`GET /storage/quota` (viewStorageQuota) → usage/limit/available/health/enforced.
Enforcement at the memories presign (the dominant media consumer); recording on
confirm in a SEPARATE best-effort txn (a failed INSERT aborts a Postgres txn — it
must never roll back the media row). Admissions/complaints adopt the same two
functions (`enforceStorageQuota`/`recordStorageUsage`) as a documented fast-follow.
Backend 3394 / 0 / 3 ign (was 3375).

## ✅ DEPLOYED — 2026-07-16 (prod `20260888` → `20260889`)
Backup → migrate (`supabase_admin`, `--single-transaction` with ledger INSERT) →
rsync edge → restart → health. Verified live: `storage_usage_entries` **rls=t
forced=t**, 2 policies, `erp_tenant` grant **INSERT,SELECT only**,
`subscription_plans.max_storage_bytes` present (all 4 plans **NULL = unlimited**),
`viewStorageQuota` → management/organizationAdmin/organizationOwner/superAdmin.
Route contract on `127.0.0.1:3000`: `/storage/quota` **401**, `/storage/nope`
**404**, `/health` **200**, `STORAGE_QUOTA_ENFORCEMENT` **unset (dark)**, level-50 **0**.

## ✅ LIVE CERTIFIED — 2026-07-16. 6/6 probes PASS on real Postgres.
Reproducible: [`live_cert_batch4_storage_quota.sql`](../../scripts/qa/live_cert_batch4_storage_quota.sql) (real `erp_tenant` via `app.set_request_context`, ROLLBACK, zero residue).

| # | Probe | Verdict | Evidence |
|---|---|---|---|
| 1 | **Usage projection (signed SUM)** | **PASS** | Two uploads (+1, +2 MiB) and a delete (−0.5 MiB) → `used_bytes = 2621440` (2.5 MiB). The delete is correctly subtracted — the fake DB cannot evaluate this SUM. |
| 2 | **RLS org-isolation** | **PASS** | org B reading org A's usage rows → **0**. Control: org A → **3**. |
| 3 | **delta<>0 CHECK** | **PASS** | a zero-delta ledger row rejected by `storage_usage_entries_delta_nonzero` (1/1). |
| 4 | **Append-only immutability** | **PASS** | as `erp_tenant`, UPDATE and DELETE both `permission denied` (2/2). |
| 5 | **Plan storage-limit round-trip** | **PASS** | `max_storage_bytes` set to 5 GiB reads back through the plan query (the value `resolveSubscription` feeds the soft check). |
| 6 | **Zero residue** | **PASS** | `storage_usage_entries=0`, no plan carries a limit after ROLLBACK. Prod untouched. |

**NOT claimed:** atomic concurrency. Enforcement is SOFT check-then-act (matches the
student/school slabs by design); there is no atomic guarantee to certify, so none is
asserted. The soft decision (`withinStorageQuota`, incl. grace) is unit-tested; its
DB inputs (projection + plan limit) are now live-proven.

⇒ **Batch 4 (backend/data-plane) = LIVE CERTIFIED.** No open P0. Ships DARK — flipping
`STORAGE_QUOTA_ENFORCEMENT=true` + setting per-plan `max_storage_bytes` (an edge
restart) activates it, once usage has been metering for real.

## State distinction (certification discipline)
- **IMPLEMENTED + DEPLOYED + LIVE CERTIFIED:** ledger, projection, RLS, immutability,
  delta constraint, plan-limit, GET API, dark enforcement + memories wiring.
- **IMPLEMENTED (client), not certified-live:** the Flutter Control Center storage
  panel + the memories-confirm `sizeBytes` echo (client — verified by analyze/tests).
- **Honest residue / fast-follow:** admissions/complaints upload metering (same two
  functions, not yet wired); a server-authoritative object stat (usage currently
  trusts the client-declared size, consistent with the existing per-file cap);
  low-storage ALERT dispatch (health is exposed via the API, no notification yet).

---

# 🔨 PRC-A BATCH 5 — WEBHOOK HMAC HARDENING + ATOMIC REPLAY GUARD (owner-idea 25)

The shared webhook-HMAC framework the audit flagged, plus two REAL money-path defects
found while extracting it. **Code-only — no migration.**

**Commit:** `4bdda08b` (backend + this cert).

## Two defects fixed on the Razorpay money path
1. **Timing-unsafe signature comparison (P1-sec).** `razorpay_client.ts` verified BOTH
   the webhook signature and the payment-confirmation signature with a plain
   `expected === signature`. A `===` short-circuits at the first differing byte — an
   attacker can time the response to learn how many leading bytes of a forged
   signature are correct and rebuild a valid one byte-by-byte. On the webhook that
   authorises a payment capture, that is a money-integrity hole. Now constant-time.
2. **Check-then-act replay guard (TOCTOU).** `recordWebhookEvent` did
   SELECT-then-INSERT: two concurrent deliveries of the SAME webhook could both see
   zero rows and both process the event (e.g. credit a payment) twice; the loser's
   bare INSERT also raised a PK violation → 500 → provider retry. Now ONE atomic
   `INSERT … ON CONFLICT (id) DO NOTHING RETURNING id`.

New canonical `_shared/webhook_hmac.ts` (constant-time `verifyHmacSha256Hex`); razorpay
+ communication now use it (comms' two private copies deleted; gate_pass left — it is
certified and its copy serves OTP, not webhooks). Backend **3402 / 0 / 3 ign** (+8);
payment + communication **138 / 0**.

## ✅ DEPLOYED — 2026-07-16 (edge only; no schema change)
Edge backed up → rsync → restart → health. `/webhooks/razorpay` **200** (acks; verify
gates processing internally — unchanged), `/communications/delivery/webhook` **401**,
level-50 **0**.

## ✅ LIVE CERTIFIED — 2026-07-16.
Reproducible: [`live_cert_batch5_webhook_replay.sql`](../../scripts/qa/live_cert_batch5_webhook_replay.sh).

| Claim | Verdict | Evidence |
|---|---|---|
| **Atomic replay dedup under real concurrency** | **PASS** | Two CONCURRENT backends run the VERBATIM production `INSERT … ON CONFLICT (id) DO NOTHING RETURNING id` as real `erp_tenant` for the SAME event id: **exactly one** claimed it (Session A returned the id, Session B returned **0 rows**); **1** row persisted. The fake DB cannot evaluate this. Residue **0**. |
| **Constant-time HMAC verify** | **unit-certified** | 8 verifier tests (correct/tampered/wrong-secret/normalised/length-safe) + 138 payment/comms tests confirm accept/reject is behaviour-preserving. The constant-time property is verified by code (the compare folds every byte, no early return) — a single-probe timing measurement is not a meaningful live test, so none is claimed. |

⇒ **Batch 5 = LIVE CERTIFIED** (atomic replay) + **HMAC hardening shipped** (unit-certified, behaviour-preserving). No open P0.

## Residue
gate_pass_crypto keeps its own `timingSafeEqualHex` (certified Batch 2 code, serves
OTP/QR not webhooks) — consolidating it is a low-value follow-up, deliberately not
churning a certified module.

## State distinction (certification discipline)
- **IMPLEMENTED + DEPLOYED + LIVE CERTIFIED:** wallet core, admit-clause double-spend safety, HTTP APIs, RBAC, audit, RLS, constraints, immutability — all proven on prod Postgres.
- **IMPLEMENTED, not yet certified-live:** the Flutter Control Center wallet panel (client UI — ships in a release build, not the edge; verified by `flutter analyze`/widget tests, not a Postgres probe).
- **Honest residue:** cross-org top-up (a platform superAdmin crediting an ARBITRARY other org) needs an act-as-org tenant context this codebase lacks — deliberately out of scope, not faked; low-balance ALERT dispatch (cap 40) computes `walletHealth` but is not yet wired to a notification channel; storage-quota (31–36) still absent.

---

# 🔨 PRC-A BATCH 6 — COMMUNICATION CHANNEL ORCHESTRATOR (owner-future-idea 24)

WhatsApp promoted to a **first-class channel** in the canonical notification
pipeline + a **per-school escalation/fallback** policy. Extends existing
architecture; introduces no competing delivery path.

**Commits:** `deece450` (backend + tests) · cert (this section).

## The stranded-provider problem the audit flagged
A real msg91/gupshup provider (`school_completion/whatsapp_providers.ts`) existed
but was reachable ONLY through a synchronous `communication_bridge_service` that
wrote to a SEPARATE analytics table (`communication_delivery_events`) — never the
canonical `notification_deliveries` ledger (queue + retry + broadcasts + reports).
The main channel switch only accepted `sms|email|push`; there was no escalation
anywhere.

## Design (reuse, never duplicate)
- `NotificationChannel += 'whatsapp'`; `sendViaProvider` routes it to the EXISTING
  `sendWhatsAppMessage` with the EXISTING per-school `whatsapp_provider_configs`.
  No new send code. Unconfigured school → honest "not configured" failure (never a
  fabricated "sent", GAP-P1-9). The provider config IS the activation gate — ships
  effectively dark, no extra flag.
- `processDeliveryQueue` threads the per-school WhatsApp config (cached) and, on a
  **TERMINAL** failure (retries exhausted), consults the school escalation policy
  to enqueue a fresh delivery on the next channel in the chain — linked by
  `escalated_from` + `escalation_depth` (chain-length loop bound). **No policy →
  no escalation → pre-Batch-6 behaviour preserved byte-for-byte.**
- Pure `communication_escalation.ts` (position-based, never backwards; depth-guarded;
  chain validation) — exhaustively unit-tested.
- Migration `20260890`: both channel CHECKs += `whatsapp`; `escalated_from` +
  `escalation_depth` on `notification_deliveries`; RLS'd `communication_channel_policies`
  (org+school, chain-vocabulary CHECK, no DELETE grant — retire via `is_active`).
- Channel-policy CRUD (`GET/PUT /communications/channel-policy`) reuses the EXISTING
  `manageCommunications` permission — no new slug.

## ✅ DEPLOYED — 2026-07-16 (prod `20260889` → `20260890`, edge)
Backup (DB 34438 lines + edge 1.5M) → migration applied as `supabase_admin
--single-transaction` with its ledger INSERT → `rsync --delete --exclude='*_test.ts'`
(exactly the 9 Batch-6 files, 0 deletions) → `docker restart akshara-edge` (clean
boot). Schema verified live: ledger `20260890`, both channel CHECKs carry `whatsapp`,
policy table `rls=t forced=t`, both new columns present, erp_tenant grants =
INSERT/SELECT/UPDATE (no DELETE). Route contract on `127.0.0.1:3000`: `/health` **200**,
`GET`+`PUT /communications/channel-policy` **401** (route exists + auth-gated),
`/channel-policy/nope` **404**, level-50 since restart **0**.

## ✅ LIVE CERTIFIED — 2026-07-16. 9/9 probes PASS on real Postgres.
Reproducible: [`live_cert_batch6_whatsapp_escalation.sql`](../../scripts/qa/live_cert_batch6_whatsapp_escalation.sql).
All probes ran as the REAL `erp_tenant` role via `app.set_request_context(...)`
inside `BEGIN…ROLLBACK`; residue asserted 0 after.

| # | Claim | Verdict |
|---|---|---|
| 1 | channel CHECK accepts `whatsapp` as a first-class channel | **PASS** |
| 2 | channel CHECK rejects an unknown channel | **PASS** |
| 3 | RLS: a sibling school cannot see another school's policy | **PASS** |
| 4 | RLS: a different tenant cannot see the policy | **PASS** |
| 5 | RLS control: the owning school sees its own policy | **PASS** |
| 6 | chain-vocabulary CHECK rejects an un-routable channel | **PASS** |
| 7 | **escalation enqueues the next channel (sms) on TERMINAL failure** with `escalated_from` linkage + `escalation_depth=1` (verbatim production enqueue/fail/enqueue SQL — the fake DB cannot evaluate this) | **PASS** |
| 8 | append-only: `erp_tenant` cannot DELETE a policy | **PASS** |
| 9 | backward compatible: no policy row → escalation disabled | **PASS** |

⇒ **Batch 6 = LIVE CERTIFIED.** No open P0. Backend `deno` **3417/0/3ign** (+15).

## State distinction (certification discipline)
- **IMPLEMENTED + DEPLOYED + LIVE CERTIFIED:** the WhatsApp channel routing,
  escalation policy (RLS, chain-vocab CHECK, append-only), and the escalate-on-
  terminal-failure enqueue — all proven on prod Postgres.
- **IMPLEMENTED, not yet certified-live:** the escalation TS orchestration
  (`processDeliveryQueue`/`computeEscalationTarget`) is unit-tested (15 tests) and
  type-checked; the live cert proves the DB half it emits.
- **Honest residue (documented, not hidden):** (1) no Flutter Control Center
  channel-policy panel yet (client UI, fast-follow — the API is fully usable).
  (2) WhatsApp recipient **phone resolution** is not done in the drain — it reuses
  `recipient_user_id` exactly as the existing SMS path does; a real msg91/gupshup
  send needs a phone lookup (a shared pre-existing gap across SMS+WhatsApp, not
  introduced here). (3) the school_completion synchronous WhatsApp bridge is left
  intact for its own onboarding-analytics screen (backward compat); the canonical
  path is now the pipeline. (4) live external WhatsApp send stays provider-gated
  (msg91/gupshup creds) — cert proves ROUTING + escalation, not the third-party API.

---

# 🔨 PRC-A BATCH 7 — TALLY ACCOUNTING EXPORT (owner-future-idea 11)

A Tally-importable Receipt-voucher export off the CERTIFIED `finance_collections`
ledger + a per-school ledger-name map. Read-only; never mutates finance.

**Commits:** `60fd5069` (backend + tests) · cert (this section). Migration **`20260891`**.

## Design (honest scope)
- Each completed collection → ONE Tally Receipt voucher: Dr `<cash/bank by payment
  method>` (deemed-positive, negative amount), Cr `<fee income ledger>` (positive) —
  correct, balanced double-entry, XML-escaped (injection-safe).
- **No per-collection head split exists** in the schema (head-wise paid amounts live
  only at the INVOICE level in `finance_invoice_head_allocations`), so the export
  credits a single configurable Fee Income ledger rather than fabricating per-receipt
  per-head precision. Head-level GL is deliberately out of scope — documented, not faked.
- Pure generator `finance_tally_export.ts` (Tally ENVELOPE, method→ledger routing,
  escaping, empty-set safe) — 9 unit tests. `finance_tally_ledger_map` (RLS'd, ledger-
  name CHECK, no DELETE grant). Reuses `viewFinance` (export) / `manageFinance` (config).
- `GET /finance/reports/tally-export?from=&to=&format=` (`?format=xml` → downloadable
  file, else JSON envelope + voucher count) · `GET/PUT /finance/tally-ledger-map`.

## ✅ DEPLOYED — 2026-07-16 (prod `20260890` → `20260891`, edge)
Backup → migration as `supabase_admin --single-transaction` with ledger INSERT →
rsync (exactly the 5 Batch-7 files, 0 deletions) → restart (clean). Schema live:
ledger `20260891`, `finance_tally_ledger_map` `rls=t forced=t`, erp_tenant grants
INSERT/SELECT/UPDATE (no DELETE). Route contract `127.0.0.1:3000`:
`GET /finance/reports/tally-export`, `GET`+`PUT /finance/tally-ledger-map` all **401**;
errors since restart **0**.

## ✅ LIVE CERTIFIED — 2026-07-16. 9/9 probes PASS on real Postgres.
Reproducible: [`live_cert_batch7_tally_export.sql`](../../scripts/qa/live_cert_batch7_tally_export.sql).
Probes ran as the REAL `erp_tenant` role via `app.set_request_context(...)` inside
`BEGIN…ROLLBACK`; residue 0. Uses School A's EXISTING collections (the join is what
the fake DB never evaluates — the same blind spot that let the fee-reductions engine
ship "certified" with a broken join, PRC-A-D-04).

| # | Claim | Verdict |
|---|---|---|
| 1 | export query joins collections→invoices, returns only completed receipts (1 voucher on real data) | **PASS** |
| 2 | status filter drops cancelled/refunded/partially_refunded (June total=7, completed=1) | **PASS** |
| 3 | RLS: a different tenant cannot export another org's collections | **PASS** |
| 4–6 | RLS: ledger-map isolation — sibling school 0, other tenant 0, owning school 1 | **PASS** |
| 7 | ledger-name CHECK rejects a blank ledger | **PASS** |
| 8 | append-only: `erp_tenant` cannot DELETE a map | **PASS** |
| 9 | backward-safe: unconfigured school → no map row → generator uses defaults | **PASS** |

⇒ **Batch 7 = LIVE CERTIFIED.** No open P0. Backend `deno` **3426/0/3ign** (+9).
**Honest residue:** no Flutter export UI yet (client fast-follow — the API is usable);
head-level GL out of scope (data model lacks a per-collection head split); the actual
IMPORT into a live Tally instance is the school's external step (the ERP integration
point — a correct, well-formed export — is certified).

---

# 🔨 PRC-A BATCH 8 (slice 1) — TRANSPORT EXPENSE DOMAIN + LIVE COST RECOMPUTE (caps 14–17)

The cost side of transport, off a REAL relational ledger — and the death of the
static-mock cost served as live. Multi-slice; this first slice ships the ledger +
cost recompute + kills the fake fuel KPI.

**Commits:** `69f5b30e` (backend + tests) · cert (this section). Migration **`20260892`**.

## The defect
The transport fleet fuel/maintenance/expense sub-domain did NOT exist, and the
dashboard `Fuel Cost (MTD) = ₹84K — Finance integration placeholder` KPI was a
STATIC SEED literal served verbatim to real pilot users (`config/live_release.json`
sets `TRANSPORT_API_ENABLED=true`). Every downstream cost figure was un-real.

## Design (reuse the architecture, not a table)
- `transport_expenses` is a RELATIONAL ledger (typed numeric columns for aggregation),
  NOT crammed into the JSONB `transport_entities` store — because a cost ledger needs
  SUM-by-category/date. Reuses the EXACT `transport_entities` RLS shape + erp_tenant
  grants. `status recorded|void`, no DELETE grant (void, not delete — auditable).
- `handleDashboard` now recomputes the `fuel` KPI from the ledger (MTD); no data →
  honest `₹0` / "No fuel expense recorded", never a fabricated figure. Other KPIs and
  the empty-state contract unchanged.
- `GET /transport/cost-summary` = real income-vs-expense: recorded expenses (total +
  by category) vs. the EXISTING transport income seam (`finance_invoice_head_allocations`
  where `fee_head LIKE 'transport:%'`, verified NUMERIC rupees — same unit, no scaling).
- Void uses the money-integrity terminal-write-guard (`status='recorded'` + throw-on-0-rows).
  Reuses `viewTransport`/`manageTransport` — no new slug.

## ✅ DEPLOYED — 2026-07-16 (prod `20260891` → `20260892`, edge)
Backup → migration `--single-transaction` + ledger INSERT → rsync (exactly the 5
Batch-8 files, 0 deletions) → restart (clean). Schema live: `transport_expenses`
`rls=t forced=t`, grants INSERT/SELECT/UPDATE (no DELETE). Route contract
`127.0.0.1:3000`: `GET /transport/cost-summary`, `GET`+`POST /transport/expenses`
all **401**; errors since restart **0**.

## ✅ LIVE CERTIFIED — 2026-07-16. 11/11 probes PASS on real Postgres.
Reproducible: [`live_cert_batch8_transport_expenses.sql`](../../scripts/qa/live_cert_batch8_transport_expenses.sql).
Probes ran as the REAL `erp_tenant` role via `app.set_request_context(...)` inside
`BEGIN…ROLLBACK`; residue 0.

| # | Claim | Verdict |
|---|---|---|
| 1 | cost recompute: SUM by category correct (5000/1500/6500) | **PASS** |
| 2 | month-to-date fuel recompute = 5000 (replaces the ₹84K placeholder) | **PASS** |
| 3–4 | category CHECK rejects unknown; amount CHECK rejects ≤0 | **PASS** |
| 5 | **void terminal-guard: 1 then 0 — no concurrent/repeat double-void** | **PASS** |
| 6 | a voided expense drops out of the recorded cost total (2000/3500) | **PASS** |
| 7–9 | RLS isolation: sibling school 0, other tenant 0, owning school 3 | **PASS** |
| 10 | **cross-module income JOIN** (head_allocations→invoices, `transport:%`) resolves on real Postgres (0/0 — School A has no transport heads, but the join the fake DB can't evaluate executes) | **PASS** |
| 11 | append-only: `erp_tenant` cannot DELETE an expense | **PASS** |

⇒ **Batch 8 slice 1 = LIVE CERTIFIED.** No open P0. Backend `deno` **3432/0/3ign** (+6).
The "static mock served as live" cost defect is fixed for the fuel KPI + cost-summary.
**Remaining transport-domain slices (not this batch):** the `snapshot_reports.fuelTrend`
+ `snapshot_occupancy` are still static seed; per-vehicle/route cost rollups; richer
expense types (odometer fuel logs); driver→route write path; effective-date model; and
a Flutter expense-entry UI. Tracked for subsequent slices.
