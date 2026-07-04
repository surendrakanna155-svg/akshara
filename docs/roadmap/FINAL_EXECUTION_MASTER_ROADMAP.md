# Akshara ERP — FINAL EXECUTION MASTER ROADMAP

**Status:** 🟢 **THE SINGLE AUTHORITATIVE ROADMAP** — the only execution plan from this point onward.
**Program Manager:** Fable (as CPM) · **Date:** 2026-07-03 · **HEAD:** `68f15cb` · **Executor:** Opus 4.8
**Consolidates (and supersedes as the forward plan):** `docs/audits/MASTER_EXECUTION_ROADMAP.md`, `docs/audits/FABLE_FINAL_ROADMAP.md`, and the Phase B/C/D of `docs/FINAL_QA_ROADMAP.md`.
**Source of truth inputs:** `docs/audits/00`–`11`, `docs/audits/AUDIT_FINDINGS_LEDGER.md`, `docs/strategy/*`, `docs/design/adaptive-ai/00`–`09` (Phase-3 implementation suite), `docs/engineering/eos/*`, owner decisions O1–O10 + freezes.
**Companions:** [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) (how it runs) · [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md) (the journal).

> **Governance (absolute):** every wave is EOS-gated. **No phase continues unless `/eos` returns PASS.**
> Frozen owner decisions (O1–O10, identity freeze, attendance-auth, English-first) are respected
> everywhere. Duplicates are merged to one authoritative task. Nothing is lost, nothing is orphaned.
> Traceability to audit findings is via `AUDIT_FINDINGS_LEDGER.md`.

---

## Legend

- **Priority:** 🔴 Critical · 🟠 High · 🟡 Medium · 🟢 Low
- **Status:** ✅ Already Complete · 🔵 In Progress · ⚪ Pending · ⏸ Deferred · 👤 Owner Decision · 🔮 Future Version
- **Category:** CODE · UI/UX · INFRA · DOCS · TEST · SEC · AI · PILOT · CERT
- **Complexity:** S (≤2d) · M (~1wk) · L (>1wk)
- **EOS gate:** the scope `/eos` must PASS before the task/wave is "done."

---

## 0. Progress dashboard

| Phase | Title | Priority | Status | Gate |
|---|---|---|---|---|
| **P0** | Truth · Documentation · Live Verification | 🔴 | 🔵 In Progress — **W1 Documentation Truth ✅ (2026-07-04)**; W2 Safety Fixes next | EOS PASS per task |
| **P1** | Remaining Backend & Code Fixes | 🟠 | ⚪ Pending | EOS PASS per wave |
| **P2** | UI / UX Improvements | 🟠 | ⚪ Pending | EOS PASS per wave |
| **P3** | Adaptive AI Implementation | 🟡 | ⚪ Pending | EOS PASS per wave |
| **P4** | Global Red Team Preparation | 🔴 | ⚪ Pending | Framework ready |
| **P5** | Red Team Fixes | 🔴 | ⚪ Pending | EOS PASS + live re-verify |
| **P6** | Pilot School Simulation | 🔴 | ⚪ Pending | PILOT-READY gate |
| **P7** | Production Certification | 🔴 | ⚪ Pending | GA gates PASS |
| **P8** | GA Readiness & Launch | 🔴 | ⚪ Pending | GA declared |

**Already-verified-live during the audit (do NOT restart):** tenant RLS isolation (QA-2/LV-11), edge uses `erp_tenant` NOBYPASSRLS (DB-2), entitlement enforcement ON (ENG-2/OPS-5), automated encrypted backups + monthly restore drill (LV-2/LV-8), watchdog running (LV-9), AI live via OpenRouter (AI-4 part), live DB password rotated (DB-1 live), `inventory_stock_valuations` WITH-CHECK fix. See ledger §A.

---

## PHASE 0 — Truth · Documentation · Live Verification  🔴 CRITICAL (gates everything)

*Make claims, docs, and the safety base match reality; prove the live legs. This must complete before Red Team (P4), Pilot (P6), and GA (P7/P8).*

### P0-DOC-1 · 🟠 · DOCS · Rewrite ProjectStatus to reality
- **Depends:** — · **Complexity:** S · **Status:** ✅ Complete (2026-07-04, P0·W1) · **Finding:** DOC-1
- **Outcome:** `ProjectStatus.md` reflects HEAD `68f15cb` (modules shipped, QA local-complete, live-verified items).
- **Evidence:** updated doc; git diff. **EOS gate:** DOCS scope PASS. **Done when:** no stale "not started" claims; HEAD + date correct.

### P0-DOC-2 · 🟠 · DOCS · Commit/track the documentation cleanup
- **Depends:** — · **Complexity:** S · **Status:** ✅ Complete (2026-07-04, P0·W1) · **Finding:** DOC-2
- **Outcome:** the ~600-file cleanup + PROJECT_INDEX/README/CLAUDE are committed & version-controlled.
- **Evidence:** clean `git status`. **EOS gate:** DOCS PASS. **Done when:** working tree coherent; start-here files tracked.

### P0-DOC-3 · 🟠 · DOCS · Roadmap reconciliation (this consolidation)
- **Depends:** — · **Complexity:** S · **Status:** ✅ Already Complete (this document + pointers) · **Finding:** DOC-3
- **Outcome:** ONE roadmap; old roadmaps point here. **Evidence:** this file + banners in `FINAL_QA_ROADMAP`/`FABLE_FINAL_ROADMAP`. **Done.**

### P0-DOC-4 · 🟠 · DOCS · Evidence-grade tracker + re-scope over-claims
- **Depends:** — · **Complexity:** M · **Status:** ✅ Complete (2026-07-04, P0·W1) · **Finding:** DOC-4, QA-1
- **Outcome:** tracker has an evidence-grade column (LIVE/LOCAL-LOGIC/CONTRACT/RENDER-MOCK/STAGED); "universal idempotency", "row_version universal", "237 Verified", "certified" re-scoped to evidence.
- **Evidence:** updated tracker + docs. **EOS gate:** DOCS PASS. **Done when:** no claim exceeds its evidence grade.

### P0-DOC-5 · 🟡 · DOCS · Fix stale architecture/debt docs + runbook dedup
- **Depends:** — · **Complexity:** S · **Status:** ✅ Complete (2026-07-04, P0·W1) · **Finding:** DB-9/DOC-5, DB-6/DOC-6, DOC-7
- **Outcome:** `TD-P0-01` + `AuditArchitecture` retention match reality; one canonical backup runbook.
- **Evidence:** updated docs. **EOS gate:** DOCS PASS. **Done when:** docs match implementation.

### P0-SEC-1 · 🟠 · SEC · Release fail-closed guard
- **Depends:** — · **Complexity:** M · **Status:** ✅ Complete (2026-07-04, P0·W2) · **Finding:** SEC-1, SEC-2
- **Outcome:** a `kReleaseMode` build refuses to run/auth unless `APP_ENV==production`; no debug-signing fallback.
- **Evidence:** build test proving dev-config release fails; signing config. **EOS gate:** SEC PASS. **Done when:** no insecure release build is possible.

### P0-SEC-2 · 🟠 · SEC · Encrypt the PII session snapshot
- **Depends:** — · **Complexity:** S · **Status:** ✅ Complete (2026-07-04, P0·W2) · **Finding:** SEC-3
- **Outcome:** session snapshot (phone/name/child) via encrypted secure storage, not plaintext prefs.
- **Evidence:** code + test; no PII in SharedPreferences. **EOS gate:** SEC PASS. **Done when:** PII at rest encrypted.

### P0-SEC-3 · 🟡 · SEC · Exclude mock/QA auth from release; guard demo-auth
- **Depends:** — · **Complexity:** S · **Status:** ✅ Complete (2026-07-04, P0·W2) · **Finding:** SEC-9, SEC-10
- **Outcome:** mock/QA auth compiled out of release (flavor); `ENABLE_DEMO_AUTH` production-guarded.
- **Evidence:** release-binary scan. **EOS gate:** SEC PASS. **Done when:** no demo/mock auth in a prod build.

### P0-INFRA-1 · 🟠 · INFRA · Off-site backup (3-2-1)
- **Depends:** — · **Complexity:** S · **Status:** ⚪ Pending · **Finding:** LV-3
- **Outcome:** `RCLONE_REMOTE` set + `rclone` installed + nightly encrypted push (script already off-site-ready).
- **Evidence:** off-site object listing after a nightly run; `offsite=true` in backup.log. **EOS gate:** OPS PASS. **Done when:** a backup exists off-box.

### P0-INFRA-2 · 🟠 · INFRA · WAL archiving / PITR
- **Depends:** 👤 RPO decision · **Complexity:** M · **Status:** ✅ Resolved — **owner accepted ~24h nightly RPO for the pilot (2026-07-04)**; WAL/PITR deferred to a post-pilot layer-2 upgrade · **Finding:** LV-1
- **Outcome:** ~~`archive_mode=on` + `archive_command` → RPO ≤15 min~~ → **owner-accepted RPO ≈ 24h** (nightly encrypted `pg_dump`, per `BACKUP_RESTORE_RUNBOOK.md §5`). WAL/PITR remains a tracked follow-up (not pilot-gating).
- **Evidence:** owner decision (this session); runbook §5 already documents the ≈24h RPO + WAL as follow-up. **EOS gate:** OPS PASS (RPO signed off). **Done when:** ~~PITR works~~ RPO signed off ✅.

### P0-INFRA-3 · 🟡 · INFRA · Wire watchdog alert delivery
- **Depends:** — · **Complexity:** S · **Status:** ⚪ Pending · **Finding:** LV-6
- **Outcome:** `ALERT_WEBHOOK_URL`/`ALERT_SMS_PHONES` set; a tripped check reaches a human.
- **Evidence:** delivered test alert. **EOS gate:** OPS PASS. **Done when:** alert observed at a human sink.

### P0-INFRA-4 · 🟢 · INFRA · Fix backup script `$1` warning
- **Depends:** — · **Complexity:** S · **Status:** ✅ Resolved in-repo (2026-07-04, P0·W2); live redeploy ⏳ deferred · **Finding:** LV-10
- **Outcome:** the `$1` bug (line 35) is already `"${1:-}"` in-repo; all backup scripts `bash -n` clean; remaining `$1` uses are inside always-called-with-args functions. The live warning was a **stale deployed script** — clears on the next (live-lane) redeploy of the current script.
- **Evidence:** `bash -n` clean on all 5 scripts; `git show HEAD:…:35` = `${1:-}`. **EOS gate:** OPS PASS. **Done when:** warning gone (repo ✅; live redeploy ⏳).

### P0-INFRA-5 · 🟡 · INFRA · Rotate DB password out of the migration
- **Depends:** — · **Complexity:** S · **Status:** ✅ Complete (2026-07-04, P0·W2) · **Finding:** DB-1/OPS-6
- **Outcome:** `20260610100000` no longer ships a credential literal — the `erp_tenant` password is read from the `erp.tenant_password` GUC (set from a secret at deploy) via dynamic SQL, with an obviously-non-secret dev-only fallback. Fresh provisioning is safe; the live role is unchanged (`IF NOT EXISTS` no-op; rotate via `ALTER ROLE`).
- **Evidence:** migration diff; **no credential literal remains in code** (grep). **EOS gate:** MIGRATION PASS. **Done when:** no credential literal in git ✅.

### P0-INFRA-6 · 🟠 · INFRA · Deploy-time `erp_tenant` assertion
- **Depends:** — · **Complexity:** S · **Status:** ✅ Code complete (2026-07-04, P0·W2); live assertion runs on next deploy ⏳ · **Finding:** DB-2
- **Outcome:** `probeTenantConnection` now returns `role` + `bypassRls`; the pure `assertEdgeTenantRole()` rejects any role ≠ `erp_tenant` or `rolbypassrls=true` (e.g. `service_role`); `/health/tenant-access` returns **503** on a wrong role and `production_launch_verify.sh` asserts it → **the deploy fails if the role is wrong**.
- **Evidence:** `tenant_db_test` +4 assertion tests; health/tenant tests 14/0; api entrypoint typechecks; verify-script `bash -n` clean. **EOS gate:** SEC PASS. **Done when:** deploy fails if the role is wrong (code ✅; live run ⏳ on the deferred live lane).

### P0-CODE-1 · 🟠 · CODE · Enforce finance `row_version`/409 (money lost-update)
- **Depends:** — · **Complexity:** M · **Status:** ✅ Complete (2026-07-04, P0·W2) · **Finding:** ENG-1
- **Outcome:** `finance_collections` cancel now reads + checks `expectedVersion` (early compare + atomic `AND row_version=$` UPDATE predicate) → **409 CONFLICT** carrying the current row (incl. `rowVersion`) so the reliability client resolves + retries. No migration (row_version already on `finance_collections` since 20260817000000); backward-compatible when `expectedVersion` omitted. (createCollection is INSERT + idempotency-key + `FOR UPDATE` — not a lost-update path; invoices/accounts use locked relative writes.)
- **Evidence:** `finance_collections_repository_test` +3 ENG-1 tests (stale version → CollectionConflictError, no money reversed; matching version OK; back-compat) — deno finance **136/0**, `deno check` clean, api entrypoint typechecks. **EOS gate:** RELIABILITY PASS. **Done when:** concurrent/stale edits can't silently overwrite money. ✅

### P0-CODE-2 · 🟠 · CODE · Hide backend-less/thin surfaces for pilot
- **Depends:** 👤 hide-list ✅ (owner: **hide all 8**, 2026-07-04) · **Complexity:** S · **Status:** ✅ Complete (2026-07-04, P0·W2) · **Finding:** ENG-3/MOD-4
- **Outcome:** the 8 backend-less surfaces (Workflow / Academic-Ops / Continuity / Platform-Intel / Platform-Ops / Multi-School-Ops / Verticals / White-Label) are **route-guarded OFF in a live build** when their API flag is off — new `isBackendLessSurfaceHidden()` gate wired into `ErpRouteGuard` (blocks deep-links → `AccessDeniedScreen`) and the management/SIS/control-center sub-navs (drops dead tabs). No-op in local/mock builds. (Alumni/Hostel scope = MOD-5/6 → P1-CODE-7/8, separate owner scope.)
- **Evidence:** `surface_backend_gate_test` (local visible · live+flag-off hidden across all 8 · live+flag-on visible · backed routes never hidden); `flutter analyze` 0. **EOS gate:** FEATURE PASS. **Done when:** no mock surface reachable in a prod build ✅.

### P0-TEST-1 · 🟠 · TEST · CI on the working branch
- **Depends:** — · **Complexity:** S · **Status:** ⚪ Pending · **Finding:** QA-3
- **Outcome:** CI runs on the branch (or a gated branch); first green run IDs captured.
- **Evidence:** committed run IDs. **EOS gate:** CI PASS. **Done when:** analyze+tests+coverage gate green in CI.

### P0-TEST-2 · 🟠 · TEST · Wire the 233-probe isolation suite into CI
- **Depends:** P0-TEST-1 · **Complexity:** M · **Status:** ⚪ Pending (isolation proven live once) · **Finding:** QA-2, QA-7(part)
- **Outcome:** `tenant_isolation_enforced_test.ts` runs against a throwaway tenant DB in CI.
- **Evidence:** green CI run of 233 probes. **EOS gate:** SECURITY PASS. **Done when:** isolation regression is guarded.

### P0-TEST-3 · 🟠 · TEST · Live-regression cron + 7-day-green clock
- **Depends:** P0-TEST-1 · **Complexity:** S · **Status:** ⚪ Pending · **Finding:** QA-3
- **Outcome:** nightly live-regression running; the 7-consecutive-day clock started.
- **Evidence:** cron logs; day-count. **EOS gate:** CI PASS. **Done when:** cron green and counting (GA prereq).

**PHASE 0 EXIT (EOS gate):** docs truthful; no over-claim; release fail-closed; off-site+WAL+alerts live; money row_version enforced; no mock surface reachable; CI green on branch; isolation suite in CI; cron clock started.

---

## PHASE 1 — Remaining Backend & Code Fixes  🟠 HIGH

*Finish the platform seams, close module gaps, execute the frozen enhancement backlog, make test coverage real. Parallelize by module (disjoint file ownership — never two implementation streams on the same module).*

| ID | Pri | Cat | Description | Depends | Cx | Status | Finding | Evidence / Done-when | EOS |
|---|---|---|---|---|---|---|---|---|---|
| **P1-CODE-1** | 🟠 | CODE | Reliability finish: mint `Idempotency-Key` for **all** mutations; marks "Save all" via `ReliableWriter`; drafts on marks+fee; boot/resume outbox flush; first-write `row_version` | P0 | L | ✅ | REL-1,2,3,4,5 | ✅ REL-1/4 `5908509`, REL-2 `66f9f35`, REL-3/5 `afd1106`; idempotency+draft+resume+first-write tests green; suite 3584 pass (2 known UX-7) | RELIABILITY PASS `afd1106` |
| **P1-CODE-2** | 🟡 | CODE | Reliability polish: transactional dequeue; read-cache TTL; store-fallback telemetry; connectivity ping + per-entity ordering | P1-CODE-1 | M | ✅ | REL-6,7,8,9 | ✅ `c0f450f`: crash-safe reclaim, 24h cache TTL, degraded-store banner, per-entity ordering + DNS reachability probe; +15 tests; suite 3599 pass (2 known UX-7) | RELIABILITY PASS `c0f450f` |
| **P1-CODE-3** | 🟡 | CODE | Backend hardening: stop raw `error.message` leak (154 sites); cap 4 unbounded bulk arrays; standardize error codes; 400→422; route-registry lint; forced-auth choke; audit retention/partitioning | P0 | L | ✅ | ENG-7(=SEC-6)/8(=SEC-11)/9/10/4/5, DB-6(code) | ✅ central leak fix `370028c`; 6 bulk caps; 18 val→422 `56e4942`; forced-auth 13/13 `3957fab`; taxonomy lint + audit-retention seam `b4bee40`; deno 2021 pass (0 new fails) | SECURITY+ARCH PASS `b4bee40` |
| **P1-CODE-4** | 🟠 | CODE | Identity finish: **change-phone flow (PLAT-4)**; append-only ledger triggers; student 2-table integrity; admission# dedup audit; cross-tenant SECURITY DEFINER in-DB authz; remaining `WITH CHECK` + ops `FORCE` | P0; 👤 PLAT-0 | L | ⚪ / 👤 | DB-3, DB-5, DB-7, DB-8, DB-10, DB-4(=SEC-7) | change-phone keeps UUID/PSID/links (Identity-Permanence invariant) | SECURITY+MIGRATION PASS |
| **P1-CODE-5** | 🟠 | CODE | HR payroll engine (salary structure + run/line-item generation; un-hide payroll); fix hardcoded `employeeId`; employee-code uniqueness | P0 | L | ✅ | MOD-2, MOD-3 | ✅ backend `56939bb` (engine + 409 `EMPLOYEE_CODE_TAKEN`, deno HR 85/0) + client `770ed00` (structure→generate→run UI, real employee picker, un-hidden behind `module.hr_payroll` 402); fresh-school flow test green; suite 3605 pass (2 known UX-7) | FEATURE PASS `770ed00` |
| **P1-CODE-6** | 🟡 | CODE | Cross-module Finance posting (library fines / hostel fees) — real posting or explicit out-of-Finance label | 👤 | M | 👤 | MOD-1 | fine/fee reaches ledger or is clearly labelled | FEATURE PASS |
| **P1-CODE-7** | 🟡 | CODE | Hostel — ship "residence-lite" or build leave/gate-pass + billing | 👤 | M–L | 👤 | MOD-6 | scope-decided + built/hidden | FEATURE PASS |
| **P1-CODE-8** | 🟢 | CODE | Alumni — graduation auto-population + Finance link, or keep hidden | 👤 | M | 👤 | MOD-5 | scope-decided + built/hidden | FEATURE PASS |
| **P1-PROD-0** | 🟠 | CODE | XCT foundations: shared export pipeline · reminder/scheduling rail · date pickers | P0 | L | ⚪ | XCT-1/2/3 | ≥3 real exports; ≥1 in-app reminder fires; date pickers | FOUNDATION PASS |
| **P1-PROD-1..21** | 🟠/🟡 | CODE | Frozen enhancement backlog waves C1–C21 (Finance recovery CRM, Exams fast-marks/tabulation, Academic registers+certs, Homework core, Transport fleet/fee, Inventory, Library, Communication, Principal/Director/Parent productivity). **Wave decomposition (normative):** the C0–C21 wave table + per-wave completion criteria in `docs/FINAL_QA_ROADMAP.md` §Phase C remain the authoritative grouping (retained for this purpose despite that file's superseded banner); item scope = the frozen backlog (rev 5) | P1-PROD-0; 👤 Appendix A | var | ⚪ / 👤 | PRODUCT_ENHANCEMENT_BACKLOG | per-wave completion criteria per the C-wave table | per-wave EOS PASS |
| **P1-PROD-22** | 🟠 | CODE | **Staff attendance (Face ID) Must-Before-GA track:** GA-1 geofence + anti-mock GPS + live-camera-face check-in/out per the frozen `docs/ATTENDANCE_AUTH_DESIGN_DECISION.md` (**re-implements** the superseded device-biometric O5 build; NEVER OS biometric/PIN) · GA-2 manual request/close (maker-checker, audited) · GA-3 principal real-time summary (+ TCH-9 "My Attendance", HR-6 muster = old wave C3). Frozen config GA-D1..D4 apply. **GA blocker** — pilot Stage 12 exercises it | P0; XCT-1 | L | ⚪ | Backlog §Must-Before-GA; attendance-auth freeze | check-in/out live on the corrected auth; manual flows audited; summary rolls up; no device-biometric path | FEATURE+SEC PASS |
| **P1-SEC-1** | 🟡 | SEC | Session-revoke live-proof; TLS cert pinning; root/jailbreak + optional biometric app-lock; apply Google-Cloud API-key app restrictions to the committed Firebase Android client key (audit 03 §5 hardening) | P0 | M | ⚪ | SEC-4,5,8 (+03 §5 prose) | revoke takes effect live; pinning; root signals; key restricted | SECURITY PASS |
| **P1-TEST-1** | 🟠 | TEST | Real-device Patrol E2E; commit live-cert artifacts; close 34 P0 + 23 P1 unverified; router tests for 41 routers; fresh lcov | P0-TEST | L | ⚪ | QA-4,5,6,7,8 | device E2E green; artifacts committed; rows Verified-live | CI+QA PASS |
| **P1-TEST-2** | 🟡 | TEST | Concurrent-load test the single edge isolate; fix hot N+1 report loops | P1 | M | ⚪ | ENG-6 | load numbers; no pool starvation | PERFORMANCE PASS |
| **P1-INFRA-1** | 🟡 | INFRA | Scale foundation (School Registry + migration-fleet-runner + read-replica/HA plan + PgBouncer + observability) — scheduled, **not pilot-gating** | 👤 pre-scale | L | ⏸ / 👤 | OPS-7, OPS-8 | registry + fleet runner + metrics live | OPS PASS |

**PHASE 1 EXIT:** platform seams finished; module gaps closed/hidden; backend hardened; coverage real; enhancement waves EOS-passed.

---

## PHASE 2 — UI / UX Improvements  🟠 HIGH  (from the Fable + prior UX audit; may overlap late P1)

| ID | Pri | Cat | Description | Depends | Cx | Status | Finding | Done-when | EOS |
|---|---|---|---|---|---|---|---|---|---|
| **P2-UX-1** | 🟠 | UI/UX | Tier 1 feel & trust pack: skeletons, pull-to-refresh, haptics, success views, offline freshness chip, copy/error-dictionary pass, draft-chip everywhere | P0 (draft infra) | M | ⚪ | UX-2/3, prior-Tier-1 | feedback layer live across surfaces | UX PASS |
| **P2-UX-2** | 🟠 | UI/UX | Tier 2 daily-task ergonomics: exception-grid attendance, inline marks/grading, generalized bulk-ops, cross-module Approvals Inbox, responsive `AksharaDataTable`, form-kit + keyboard/date sweep | P1-CODE-1 | L | ⚪ | UX-1/5, prior-Tier-2 | five daily tasks meet ergonomic targets | UX PASS |
| **P2-UX-3** | 🟡 | UI/UX | Tier 3 design-system enforcement: lints (no raw color/TextStyle), contrast checker in CI, persona-shell goldens | — | M | ⚪ | UX-4, prior-Tier-3 | DS lint blocks new violations | UX+CI PASS |
| **P2-UX-4** | 🟡 | UI/UX | Accessibility pass: WCAG contrast, screen-reader semantics, dynamic type, tap-targets | P2-UX-3 | M | ⚪ | EOS a11y gap | a11y checks pass | UX PASS |
| **P2-UX-5** | 🟢 | UI/UX | Dark-theme user toggle (code-complete) | — | S | ⚪ | UX-6 | toggle ships | UX PASS |

**PHASE 2 EXIT:** rerun the prior UX rubric → target ≥8/10.

---

## PHASE 3 — Adaptive AI Implementation  🟡 MEDIUM  (design: `docs/strategy/ADAPTIVE_AI_MASTER_BLUEPRINT.md` · **implementation-ready suite: `docs/design/adaptive-ai/00_ADAPTIVE_AI_DESIGN_INDEX.md`** — wave detail + EOS criteria in its doc 09)

| ID | Pri | Cat | Description | Depends | Cx | Status | Finding | Done-when | EOS |
|---|---|---|---|---|---|---|---|---|---|
| **P3-AI-1** | 🟠 | AI | **Cost/safety foundation (build first):** response + semantic cache · rate-limit + spend-cap · request timeout → deterministic fallback · no-key health signal · prompt-injection hardening · event-driven cache invalidation · memory tables | P0 | L | ⚪ | AI-1,2,3,4(res),5 | ≥90% impressions served with 0 model calls; spend-cap enforced; timeout fallback | AI PASS |
| **P3-AI-2** | 🟡 | AI | **Adaptive wave:** Priority Engine · per-persona routers (Teacher→Parent→Principal→Finance→Office→Director→Transport/Library/Inventory) · Recommendation Engine + accept/dismiss learning · dynamic role-aware dashboards on the Widget Platform · guarded draft-and-hold automation · rename deterministic "Intelligence"→"Analytics" | P3-AI-1; 👤 timing | L | ⚪ / 👤 | Adaptive-AI vision, AI-6 | dashboards adapt per school; per-persona AI live; cost bounded | AI PASS |

**P3 executes from the implementation-ready suite `docs/design/adaptive-ai/` (doc 09 is the wave contract).** P3-AI-1 = **W1** (foundation); P3-AI-2 = **W2** (adaptive); W3 = post-GA (P8-GA-5 register).

- **P3-AI-1 → W1 sub-waves (sequential; EOS AI gate each):** W1.1 Model-Gateway hardening (timeout+rate-limit+spend-cap+`ai_call_log`+no-key signal → closes AI-1, AI-3, AI-4) · W1.2 memory stores + `ai_response_cache` (RLS-isolated → AI-2 core) · W1.3 Context-Engine generalization + injection hardening (→ AI-5) · W1.4 Signal-Refinery `domain_events` consumer + event cache-invalidation + nightly recompute · W1.5 intent-fingerprint cache + Control-Center cost panel (N10). **W1 exit:** ≥90% impressions 0-model-calls; spend-cap demonstrated; isolation suite green on all `ai_*` tables.
- **P3-AI-2 → W2 sub-waves (order: engines → personas):** W2.0 Priority+Recommendation engines · W2.1 brief/digest platform · W2.2 Teacher · W2.3 Parent · W2.4 Principal · W2.5 Director · W2.6 Student · W2.7 ops-module worklists · W2.8 pgvector semantic cache · W2.9 truth-in-naming (AI-6).
- **⚠ Cross-phase dependencies (from doc 09 §0 — these move specific P1 items *before* the dependent P3 sub-wave):** W1.4 nightly jobs need **P1-PROD-0 / XCT-2**; homework intelligence needs **HWK-1**; fee-reminder ladders + recovery timing need **FIN-6**; transport compliance clock needs **TRN-2**; unified recovery-CRM scope needs **MOD-1 (👤)**; best-moment delivery + resend-to-unread need **COM-1**; Principal rollout (W2.4) needs the **P2 Principal-hub consolidation**; any live T3 behaviour needs the **P0 live-AI-key** verification.
- **Standing AI test assets (built in W1, run every AI wave):** injection corpus · determinism validator (T3 numbers == injected facts) · `ai_*` isolation probes · cost-regression (no surface ships below its tier) · fallback drills (no-key/timeout/over-cap/over-rate).

**PHASE 3 EXIT:** AI cost controls + cache live (AI-1..5 closed with tests); ≥90% zero-model-call impressions; per-school adaptivity evidenced; cost bounded under cap at pilot scale; AI-6 naming corrected.

---

## PHASE 4 — Global Red Team Preparation  🔴 CRITICAL  (framework: `docs/strategy/GLOBAL_RED_TEAM_FRAMEWORK.md`)

| ID | Pri | Cat | Description | Depends | Cx | Status | Done-when | EOS |
|---|---|---|---|---|---|---|---|---|
| **P4-RT-0** | 🔴 | TEST | Prepare the Red Team: freeze honest re-scoped claims (P0-DOC-4), stand up domain operators, seed attacks from the audit's confirmed+flagged risks, ready staging/throwaway tenants | Phases 0–3 substantially done | M | ⚪ | 12 domains scoped, operators + fixtures ready | READINESS PASS |
| **P4-RT-1** | 🔴 | TEST/SEC | Execute the 12-domain adversarial assault (security, isolation, money, AI abuse, UX, workflow, ops, DR, corruption, concurrency, performance, human-error); adversarially verify every finding; loop-until-dry | P4-RT-0 | L | ⚪ | verdict rendered; findings → P5 tasks | RED-TEAM verdict |

**PHASE 4 EXIT:** all 12 domains run; converged; every finding adversarially verified and severity-rated.

---

## PHASE 5 — Red Team Fixes  🔴 CRITICAL

| ID | Pri | Cat | Description | Depends | Cx | Status | Done-when | EOS |
|---|---|---|---|---|---|---|---|---|
| **P5-FIX-1** | 🔴 | CODE/SEC/INFRA | Close **every** Red-Team P0/P1 finding; re-verify each **live**; re-run the affected EOS category gates | P4-RT-1 | var | ⚪ | no open P0/blocking-P1; each fix live-re-verified | EOS PASS per fix |

**PHASE 5 EXIT:** Red-Team verdict flips to PASS.

---

## PHASE 6 — Pilot School Simulation  🔴 CRITICAL  (blueprint: `docs/strategy/PILOT_SCHOOL_SIMULATION_MASTER.md`)

| ID | Pri | Cat | Description | Depends | Cx | Status | Done-when | EOS |
|---|---|---|---|---|---|---|---|---|
| **P6-PILOT-1** | 🔴 | PILOT | Unattended full-year live sim (single + 3-school concurrent): all stages 0–16 per the blueprint, real auth/DB/RBAC/gateway; confirm money loop, isolation under concurrency, DR drill, alerts, no mock surface, AI cost controls | Phase 0 + Phase 1 + **P3-AI-1** (its done-when requires the AI cost controls) + Phase 5 | L | ⚪ | all stages green unattended; evidence committed | `QA-R-001/002` live PASS → **PILOT-READY** |

**PHASE 6 EXIT:** declare **PILOT-READY**.

---

## PHASE 7 — Production Certification  🔴 CRITICAL  (framework: `docs/strategy/PRODUCTION_CERTIFICATION_FRAMEWORK.md`)

| ID | Pri | Cat | Description | Depends | Cx | Status | Done-when | EOS |
|---|---|---|---|---|---|---|---|---|
| **P7-CERT-1** | 🔴 | CERT | Pass all GA gates (T/S/O/U/A/P/B/D) at their required evidence grade; complete `QA-R-012` Final Checklist with LIVE evidence; 7-day cron green; commercial prereqs decided | P6-PILOT-1 | L | ⚪ | every checklist item satisfied with LIVE evidence | `QA-R-012` PASS |

**PHASE 7 EXIT:** all gates PASS; production-certified.

---

## PHASE 8 — GA Readiness & Launch  🔴 CRITICAL

| ID | Pri | Cat | Description | Depends | Cx | Status | Finding/Source | Done-when | EOS |
|---|---|---|---|---|---|---|---|---|---|
| **P8-GA-1** | 🔴 | CERT | Final go/no-go: confirm no open P0/blocking-P1 project-wide; EOS ledger clean; sign-off | P7-CERT-1 | S | ⚪ | Prod-Cert §3 | go/no-go recorded | RELEASE PASS |
| **P8-GA-2** | 🟠 | DOCS | Commercial readiness pack: pricing, onboarding runbook, support process, legal suite confirmed | P7 | M | 👤 | B4/B5, O6/O10 | pack complete or owner-deferred | — |
| **P8-GA-3** | 🟠 | INFRA | Production launch: promote build; monitoring + alerting + backups + off-site confirmed on the production tenant(s); rollback proven | P8-GA-1 | M | ⚪ | OPS gates | live prod healthy; rollback tested | OPS PASS |
| **P8-GA-4** | 🟡 | DOCS | Declare **GA**; update ProjectStatus + roadmap progress + release notes; open post-GA monitoring cadence | P8-GA-3 | S | ⚪ | — | GA declared + recorded | DOCS PASS |
| **P8-GA-5** | 🟡 | — | Post-GA forward plan handoff: Phase-2 commercial (billing/quotas/white-label/GPS, O6/O8/O10), Consolidation wave (DOC-8), Assessment Intelligence Platform, scale machinery (P1-INFRA-1) | P8-GA-4 | — | 🔮/👤 | Ledger §D | forward backlog owner-scheduled | — |

**PHASE 8 EXIT:** **GA DECLARED**; post-GA forward plan handed to owner scheduling.

---

## Deferred / Future / Owner-Decision register (nothing lost)

- **👤 Owner Decisions (gate their tasks):** hide-list (P0-CODE-2) · RPO accept (P0-INFRA-2) · module scope Hostel/Alumni/Finance-posting (P1-CODE-6/7/8) · PLAT-0 non-student Public-ID (P1-CODE-4) · Appendix A ~26 items (P1-PROD-*) · Adaptive-AI timing (P3-AI-2) · Consolidation wave DOC-8 (P8-GA-5) · `APP_ENV=staging` intent (LV-5) · shared-box strategy (LV-4/OPS-4) · UX candidate batch (`docs/design/PRODUCT_EXCELLENCE_MASTER_PLAN.md` §6: premium-completion visual wave B5, Approvals-Inbox read-model, exam-workspace early slice, C1/C3/C5/C6 candidates, PAR-D4 action-inbox, Student/HR AI extensions).
- **⏸ Deferred (scheduled, not pilot-gating):** scale machinery (P1-INFRA-1).
- **🔮 Future Version (post-GA, owner-timed):** Phase-2 commercial (billing/quotas/marketplace/live-GPS/white-label tiers/custom-domain — O6/O8/O10) · Future Vision (verticals/franchise/geo-RFID-QR attendance/student-FaceID/website-builder/gate-pass/secure-CBT/app-biometric-lock — O1/O4/O9) · Assessment Intelligence Platform (Master Plan v3.0) · Phase-C deferred tail (`Ph2`/`Fut` enhancement items).
- **Out-of-scope:** re-enabling deferred verticals/experimental surfaces (O1/O3); re-auditing certified-unchanged work; frozen QW1–QW8 history.

---

## Traceability & dependencies (summary)

- **Every audit finding** → a task/disposition in `AUDIT_FINDINGS_LEDGER.md` → a task ID above.
- **Every strategy doc** → a phase: Adaptive AI Blueprint + the `docs/design/adaptive-ai/` suite (00–09) → **P3** (W1→P3-AI-1, W2→P3-AI-2, W3→P8-GA-5) · Pilot Sim → P6 · Red Team → P4/P5 · Prod Cert → P7 · `LONG_TERM_COMPETITIVE_STRATEGY.md` (Competitive) → steers all phases (esp. P3 + post-GA P8-GA-5). The suite's novel ideas N1–N12 map: cost-critical/foundational (N10 cost panel → W1.5) into W1/W2; consent/post-GA (N3/N5/N6-full/N7/N9) → W3/P8-GA-5.
- **Hard gates:** P0 gates P4/P6/P7/P8 · P0-TEST-1 gates P0-TEST-2/3 (and the 7-day clock gates P7) · P1-CODE-1 gates P2-UX-2 · P3-AI-1 gates P3-AI-2 **and P6** (pilot checks the AI cost controls) · P4→P5→P6→P7→P8 strictly sequential.
- **Execution order:** P0 fully → (P1 ∥ P2 ∥ P3-foundation) → P3-adaptive → P4 → P5 → P6 → P7 → P8.

*This is the only roadmap. All prior roadmaps are superseded as the forward plan and point here. Execution follows [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md); progress is journaled in [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md). No phase continues without an EOS PASS.*
