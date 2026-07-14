# PRC-A (Wave A) — Progress & First-Pass Capability Classification

**Wave:** PRC-A (Real School Operations Capability & Cross-Module Gap Audit) — the true current wave per [`RECON-2_EXECUTION_ORDER_CORRECTION.md`](RECON-2_EXECUTION_ORDER_CORRECTION.md).
**Authority:** `../AKSHARA_PRODUCT_REALITY_AND_CORRECTNESS_CERTIFICATION.md` (frozen) + `../roadmap/PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md` (502 reqs).
**Status:** 🔵 IN AUDIT — first-pass (existence/wiring) classification below. **⚠ This is a SCREEN-LEVEL EXISTENCE probe, not the full 13-step method** — "MISSING" (no code) is reliable; "PARTIAL/PROBABLY-WORKING" rows need the deeper UI→API→service→repo→DB + cross-module + dependency-chain trace before any WORKING/LIVE certification. No capability is ✅ without the full method + evidence (tracker state law).

**Execution note (2026-07-14):** the parallel PRC-A audit fleet (transport/finance dependency-chain · new-ops modules · owner-ideas reconciliation) was launched but repeatedly **failed on a transient network fault (`ENOTFOUND`)** mid-run. Foreground probing (resilient to the fault) produced the first-pass below. Resume the parallel fleet (or continue foreground) when the network stabilizes.

## First-pass classification (15 domains / 148 capabilities)

| Caps | Domain | First-pass | Evidence / next step |
|---|---|---|---|
| 1–30 | Transport enrolment/route/fleet/**Finance integration** | ⏳ DEEP-AUDIT | Backend + UI exist (routes/vehicles/drivers/allocations live; demand-raise wired). **The transport→finance fee/cost dependency-chain (Admission→…→Cost→Dashboard) MUST be traced end-to-end** — a partial/mock link anywhere ⇒ NOT LIVE. (agent had reached the demand/fee-structure dialog before the network fault.) |
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
