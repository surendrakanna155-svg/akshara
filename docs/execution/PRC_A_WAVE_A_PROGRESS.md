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
