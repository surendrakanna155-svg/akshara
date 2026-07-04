# Akshara ERP — Audit Findings Traceability Ledger

**Owner:** Fable Final Independent Audit · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Purpose:** the completeness guarantee — **every finding** from reports `00`–`11` maps to **exactly one**
disposition: a Master-Roadmap task (`docs/audits/MASTER_EXECUTION_ROADMAP.md`), or one of
**Already-Fixed · Future-Enhancement · Owner-Decision · Out-of-Scope**. Nothing is lost.

**Legend — disposition:** `→ <TASK-ID>` = scheduled into that Master-Roadmap task · **FIXED** = resolved/verified during the audit · **OWNER** = needs an owner decision · **FUTURE** = deferred enhancement · **OOS** = out of scope. **Sev:** Critical / High / Medium / Low.

**Duplicates are merged** (noted `= <ID>`), so a finding seen in two reports resolves to one task.

---

## A. Already-Fixed / Verified-during-audit (no roadmap task needed)

| ID | Finding | Evidence it's resolved |
|---|---|---|
| ENG-2 / OPS-5 | Entitlement (402) plan-gating "ships OFF" | **FIXED** — `ENTITLEMENT_ENFORCEMENT=true` live (report 11 §2) |
| DB-2 | Edge must use `erp_tenant` not `service_role` (the #1 RLS control) | **FIXED/VERIFIED** — live DSN user = `erp_tenant`, `rolbypassrls=f` (report 11 §2). *Hardening task P0-INFRA-6 keeps it enforced.* |
| QA-2 / LV-11 | Cross-tenant RLS isolation never tested | **FIXED/VERIFIED** — live probe 7/7 read + 2/2 write PASS (report 11 §3b). *Regression task P0-TEST-2 wires the suite into CI.* |
| OPS-2 / LV-8 | "Restore never tested" | **FIXED/REFUTED** — monthly restore drill runs + passes (`drill SUCCESS: 184 tables`, report 11 §3) |
| LV-2 | "No automated backup" (initial false positive) | **REFUTED** — encrypted nightly backups run + succeed (report 11 §3) |
| LV-9 | Watchdog monitoring | **VERIFIED running** every 5 min, all green (report 11 §3) |
| AI-4 (part) | AI silently dead with no key | **PARTLY FIXED** — AI live via OpenRouter (report 11 §2). *Residual "no health signal" → P3-AI-1.* |
| DB (inventory hole) | `inventory_stock_valuations` WITH-CHECK gap | **FIXED pre-audit** (`20260839000000:32-44`) |
| LV-7 | "10 real schools" data-loss framing | **CORRECTED** — all 10 are demo/pilot tenants; no real data at risk (report 11 §3) |

---

## B. Findings → Master-Roadmap tasks

### Phase 0 — Foundation (Truth · Safety · Live Proof) — CRITICAL

| Finding(s) | Sev | Disposition |
|---|---|---|
| DOC-1 ProjectStatus stale | High | → **P0-DOC-1** ✅ Fixed 2026-07-04 (P0·W1) |
| DOC-2 doc cleanup uncommitted | High | → **P0-DOC-2** ✅ Fixed 2026-07-04 (P0·W1) |
| DOC-3 roadmap ≠ execution | High | → **P0-DOC-3** (this consolidation) ✅ |
| DOC-4 over-claims (idempotency/row_version/"237 Verified"/"certified") · QA-1 evidence-grade column | High | → **P0-DOC-4** ✅ Fixed 2026-07-04 (P0·W1) |
| DB-9 = DOC-5 (TD-P0-01 stale) · DB-6 = DOC-6 (audit-retention doc-only, doc side) | Med | → **P0-DOC-5** ✅ Fixed 2026-07-04 (P0·W1) — DB-6 code side remains → P1-CODE-3 |
| DOC-7 backup-runbook duplication | Low | → **P0-DOC-5** ✅ Fixed 2026-07-04 (P0·W1) |
| SEC-1 release default=dev · SEC-2 debug-signing fallback | High | → **P0-SEC-1** ✅ Fixed 2026-07-04 (P0·W2) |
| SEC-3 PII in plaintext SharedPreferences | High | → **P0-SEC-2** ✅ Fixed 2026-07-04 (P0·W2) |
| SEC-9 mock/QA code in release binary · SEC-10 ENABLE_DEMO_AUTH prod-guard | Med | → **P0-SEC-3** ✅ Fixed 2026-07-04 (P0·W2) — mock repo + QA-login route behind `kReleaseMode` const-branch (tree-shaken out of release + fail-closed); demo-auth prod-guarded via SEC-1 |
| LV-3 no off-site backup (= OPS-1 offsite half) | High | → **P0-INFRA-1** |
| LV-1 no WAL/PITR (= OPS-1 RPO half) | High | → **P0-INFRA-2** |
| LV-6 alert delivery unwired (= OPS-3) | Med | → **P0-INFRA-3** |
| LV-10 backup script `$1` bug | Low | → **P0-INFRA-4** |
| DB-1 = OPS-6 hardcoded DB password in migration (live-rotated; migration still ships default) | Med (was P0) | → **P0-INFRA-5** |
| DB-2 hardening (deploy-time assert erp_tenant) | High | → **P0-INFRA-6** |
| ENG-1 finance `row_version` guard inert (money lost-update) | High | → **P0-CODE-1** ✅ Fixed 2026-07-04 (P0·W2) — effective on `finance_collections` cancel (409 + current row) |
| ENG-3 = MOD-4 ~8 backend-less surfaces reachable-mock | High | → **P0-CODE-2** |
| QA-3 CI never ran on branch + live-regression cron not started | High | → **P0-TEST-1**, **P0-TEST-3** |
| QA-2 regression (233-probe suite into CI) · QA-7 (part) | High | → **P0-TEST-2** |

### Phase 1 — Remaining Roadmap Implementations — HIGH

| Finding(s) | Sev | Disposition |
|---|---|---|
| REL-1 idempotency ~4% · REL-2 marks-save bypass · REL-3 no drafts on marks+fee · REL-4 no boot-flush · REL-5 first-write concurrency | High | → **P1-CODE-1** |
| REL-6 no transactional dequeue · REL-7 read-cache no TTL · REL-8 silent in-memory fallback · REL-9 connectivity ping / entity ordering | Med | → **P1-CODE-2** |
| ENG-7 = SEC-6 error.message leak (154 sites) · ENG-8 = SEC-11 unbounded arrays (4) · ENG-9 error-code standardization · ENG-10 400→422 · ENG-4 route-order lint · ENG-5 forced-auth choke | Med | → **P1-CODE-3** |
| DB-3 phone-as-identity / change-phone flow (PLAT-4) · DB-5 append-only ledger triggers · DB-8 student 2-table integrity · DB-7 admission# dedup audit · DB-4 = SEC-7 cross-tenant SECURITY DEFINER authz · DB-10 remaining WITH CHECK + ops-backup FORCE | High | → **P1-CODE-4** |
| MOD-2 HR payroll engine (salary structure + run gen) · MOD-3 hardcoded `employeeId` · HR employee-code uniqueness | High | → **P1-CODE-5** |
| MOD-1 library/hostel/alumni Finance posting (real or labelled) | Med | → **P1-CODE-6** (+ OWNER on real-vs-label) |
| DB-6 (code side) audit retention/partitioning implementation | Med | → **P1-CODE-3** (backend) |
| ENG-6 single-isolate pool load test + N+1 hot loops | Med | → **P1-TEST-2** |
| SEC-4 session-revoke live-proof · SEC-5 cert pinning · SEC-8 root/jailbreak + app-lock | Med | → **P1-SEC-1** |
| QA-4 Patrol real-device E2E · QA-5 live-cert run artifacts · QA-6 close 34 P0+23 P1 unverified · QA-7 41 router tests · QA-8 fresh lcov | High | → **P1-TEST-1** |
| Existing frozen **PRODUCT_ENHANCEMENT_BACKLOG** Phase C waves (C0–C21: XCT foundations, FIN recovery CRM, EXM fast marks, ATT/SIS registers+certs, HWK, TRN, INV, LIB, COM, HR, PRI, DIR, PAR) | High/Med | → **P1-PROD-\*** (module waves; see roadmap) |

### Phase 2 — UI/UX Improvements — HIGH

| Finding(s) | Sev | Disposition |
|---|---|---|
| UX-2 feedback layer · UX-3 freshness chip · prior-audit Tier 1 | High | → **P2-UX-1** |
| UX-1 five daily-task friction · UX-5 keyboard/date sweep · prior-audit Tier 2 | High | → **P2-UX-2** |
| UX-4 design-system enforcement · prior-audit Tier 3 | Med | → **P2-UX-3** |
| Accessibility depth (EOS verification gap) | Med | → **P2-UX-4** |
| UX-6 dark-theme toggle | Low | → **P2-UX-5** |
| UX-7 (found 2026-07-04 during P0·W2 full-suite run) `TeacherDashboardScreen` **RenderFlex overflow at 360×640** (Phase-1 responsive + Phase-2 long-data stress tests fail; pre-existing, NOT introduced by W2) | Med | → **P2-UX-2/4** (daily-task ergonomics / a11y layout) — tracked, `test/features/mobile/dashboard_stress_test.dart` |

### Phase 3 — Adaptive AI & Product Intelligence — MEDIUM

| Finding(s) | Sev | Disposition |
|---|---|---|
| AI-2 no cache · AI-1 no rate-limit/spend-cap · AI-3 no request timeout · AI-4 (residual) no-key health signal · AI-5 prompt-injection hardening | High (cost/safety) | → **P3-AI-1** (foundation, build first) |
| Adaptive-AI vision (per-school adaptation, proactive role dashboards) | Med | → **P3-AI-2** |
| AI-6 "Intelligence" naming ≠ AI | Low | → **P3-AI-2** (or docs) |

### Phases 4–7 — Red Team → Fixes → Pilot → Prod-Cert — CRITICAL gates

| Finding(s) | Disposition |
|---|---|
| All P0/High confirmed risks re-tested adversarially on honest claims | → **P4-RT-1** |
| Every Red-Team finding | → **P5-FIX-1** |
| Full live pilot simulation (money loop, all modules, DR drill, alerts, no mock surface) | → **P6-PILOT-1** |
| `QA-R-012` Final Production Checklist + 7-day cron green + commercial prereqs | → **P7-CERT-1** |

---

## C. Owner-Decision (must resolve before the affected task runs)

| Item | Source | Blocks |
|---|---|---|
| Hostel scope — ship "residence-lite" (leave/gate-pass/billing) vs hide for pilot | MOD-6 | P1-CODE-7 |
| Alumni scope — graduation auto-population vs keep hidden | MOD-5 | P1-CODE-8 |
| Cross-module Finance posting (library fines / hostel fees) — real posting vs label out-of-Finance | MOD-1 | P1-CODE-6 |
| `APP_ENV=staging` on the live pilot backend — intentional? | LV-5 | P0-INFRA / pilot |
| Shared-box strategy (Akshara + velora-salon + n8n) — isolate before scale? | LV-4 / OPS-4 | P1-INFRA / scale |
| DR RPO acceptance — tighten to ≤15 min (WAL) vs accept ~24h for pilot | LV-1 / OPS-1 | P0-INFRA-2 — ✅ **RESOLVED 2026-07-04: owner accepted ~24h nightly RPO for pilot; WAL/PITR deferred post-pilot** |
| **Appendix A (~26 behaviour/policy items)** in PRODUCT_ENHANCEMENT_BACKLOG | backlog | P1-PROD module waves |
| Consolidation wave (14 overlapping surfaces) go/no-go | DOC-8 | Phase D |
| PLAT-0 non-student Public-ID scheme (parent/employee) | identity | P1-CODE-4 (partial) |
| Adaptive-AI wave timing (post-GA vision) | owner memory | P3-AI-2 |

---

## D. Future-Enhancement (deferred; sourced from frozen backlogs — not lost, just later)

| Item | Source |
|---|---|
| Scale machinery — School Registry + migration-fleet-runner + read-replica/HA + PgBouncer + observability | OPS-7, OPS-8 (pre-*scale*, not pre-pilot) → **P1-INFRA-1** *(scheduled but not pilot-gating)* |
| Phase-2 commercial: in-product billing, usage quotas, marketplace, live GPS bus tracking, white-label tiers, custom-domain | PRODUCT_COMMERCIAL_BACKLOG Queue 4 (O6/O8/O10) — **Phase D** |
| Future Vision: verticals (healthcare/salon/…), franchise, geo/RFID/QR attendance, student Face ID, website builder, gate-pass/visitor, secure CBT, app biometric lock | Queue 5 (O1/O4/O9) — **Phase D / never** |
| Phase C deferred tail (`Ph2`/`Fut` enhancement items: SIS-6, EXM-8, HWK-9/10, COM-6, LIB-6/7, INV-8, TCH-8, PAR-7/8) | PRODUCT_ENHANCEMENT_BACKLOG tail |
| Assessment Intelligence Platform (Master Plan v3.0) | 🔒 owner vision, post-pilot |

---

## E. Out-of-Scope (for this remaining-work plan)

| Item | Why |
|---|---|
| QW1–QW8 frozen certifications, tracker history | Historical/frozen; preserved, not modified |
| Anything requiring re-enabling deferred verticals/experimental surfaces | Contradicts North-Star O1/O3 (hide-first) |
| Re-auditing certified-and-unchanged areas | EOS rule #4 |

---

## F. Completeness check — every report accounted for

| Report | Finding IDs | All mapped? |
|---|---|---|
| 01 Engineering | ENG-1…10 | ✅ (ENG-2 FIXED; ENG-7/8 merged to SEC; rest → P0/P1) |
| 02 DB/Identity/RLS | DB-1…10 | ✅ (DB-2 FIXED; DB-9/6 → docs; rest → P0-INFRA-5 / P1-CODE-4) |
| 03 Security | SEC-1…11 | ✅ (SEC-6=ENG-7, SEC-7=DB-4, SEC-11=ENG-8 merged; rest → P0-SEC / P1-SEC) |
| 04 QA | QA-1…8 | ✅ (QA-2 FIXED-live; rest → P0-TEST / P1-TEST) |
| 05 Reliability | REL-1…9 | ✅ (→ P1-CODE-1/2) |
| 06 AI | AI-1…6 | ✅ (AI-4 part FIXED; rest → P3-AI-1/2) |
| 07 Product/Module | MOD-1…6 | ✅ (MOD-4=ENG-3; rest → P0-CODE-2 / P1-CODE-5/6/7/8 / OWNER) |
| 08 UX | UX-1…6 + prior Tiers 1–4 | ✅ (→ P2-UX-1…5; Tier 4 → Future/OWNER) |
| 09 Deploy/Ops | OPS-1…8 | ✅ (OPS-2/5 FIXED; OPS-6=DB-1; rest → P0-INFRA / P1-INFRA / OWNER) |
| 10 Docs | DOC-1…8 | ✅ (DOC-5=DB-9, DOC-6=DB-6; rest → P0-DOC / OWNER) |
| 11 Live VPS | LV-1…11 | ✅ (LV-2/7/8/9/11 FIXED/INFO; LV-1/3/6/10 → P0-INFRA; LV-4/5 → OWNER) |

**No finding is unaccounted for.** Master-Roadmap tasks reference back to these IDs; this ledger references forward to the tasks — bidirectional traceability.
