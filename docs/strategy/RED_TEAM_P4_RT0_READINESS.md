# P4-RT-0 — Global Red Team · Readiness Pack

**Date:** 2026-07-14 · **Phase:** P4 (opened at FREEZE-1) · **Framework:** [`GLOBAL_RED_TEAM_FRAMEWORK.md`](GLOBAL_RED_TEAM_FRAMEWORK.md)
**Purpose:** the P4-RT-0 deliverable — freeze the honest claims the assault attacks, scope all 12 domains with perspective-diverse operators, refresh the attack seeds for the **post-W2 / post-freeze surface**, and ready the fixtures/tenants. **Done-when (roadmap):** *12 domains scoped, operators + fixtures ready, seeds current → READINESS PASS.* Execution of the attacks is **P4-RT-1** (next wave).
**Freeze posture:** RT-0 is scoping/readiness only (no production code). RT-1/P5 fixes are freeze-compatible by class (security/bug/regression/perf/quality). Any feature-shaped remediation routes to P8-GA-5.

---

## 1. Honest-claims baseline (frozen — the Red Team attacks THESE, not marketing)

The assault must start from what the project actually claims, so nothing is "re-discovered from scratch" and no inflated claim slips through. Frozen baseline as of tip `533a0437`:

| Area | The honest claim (what we assert works) | Source of truth |
|---|---|---|
| Tenant isolation | RLS enforced on `erp_tenant` (NOBYPASSRLS); single-session verified 233/233 zero-leak live (2026-07-09). **Concurrent + crafted-scope case is UNPROVEN → a primary RT target.** | `TRACK_B_RLS_LIVE_EVIDENCE.md`, `tenant_db.ts` |
| Money integrity | Maker-checker on fee reductions/concessions/waivers; `row_version` optimistic lock; Finance is the sole payment engine; library/hostel are `not_tracked` (never posted). | SCE-1 + finance certs; honesty sweep `67ee36e9` |
| Adaptive AI (W2) | Deterministic-first; 5-gate firewall (Domain→RBAC→Deterministic→Cache→W1 gateway); persona feeds RBAC-scoped; copilot quota + **atomic reservation (A5)**; **injection fences (A6)** on brief/parent sources; cost-panel bound. | `docs/ADAPTIVE_AI_W1_CERTIFICATION_REPORT.md`, W2 audit rounds R2–R6 |
| Face ID (PROD-22) | Server matcher fail-closed (`!(score>=t)`, NaN-safe); geofence + anti-mock + blink liveness; manual-request SoD (approver ≠ requester); model asset device-residue. | Staff Face ID hardening exit (2026-07-12) |
| Clearance (SCE-1) | TC no-dues gate fail-closed on authoritative finance NET; waiver maker-checker (SoD, single-use, immutable snapshot, revoke escape); every `transferred` writer gated. | SCE-1 dual ship-gate audits (2026-07-12) |
| App Lock (SEC-1) | Device-biometric-only; cold-start lock; background→grace(15s)→re-lock; success-only unlock. **Native FLAG_SECURE + iOS-blur = device-residue (NOT yet in the tree).** | SEC-1 R1–R4 exit (2026-07-13) |
| Ops/DR | Nightly encrypted backup healthy + restorable; **off-site is LOCAL-ONLY (R2 unprovisioned) — a known P1-class gap.** 7-day cron clock not started. | `DEPLOY_CHECKPOINT_20260714_LIVE1.md` |

**Standing honest residuals the RT must NOT re-file as new findings** (already tracked): off-site backup gap; Face-ID model asset + on-device E2E; FLAG_SECURE native impl; root/jailbreak detection; TLS cert pinning; workflow-trigger no-op in prod (module gated off); academic-ops path mismatch (gated off); pgvector dormant.

---

## 2. Domain scope + operator assignment (perspective-diverse; model-tiered per [[model-tier-selection-preference]])

12 domains, each an independent operator that does not see another's angle until synthesis (multi-modal sweep). Adversarial verifier is a **second, distinct** operator prompted to *refute*.

| # | Domain | Primary lens | Operator model | Verifier model |
|---|---|---|---|---|
| 1 | Security (authn/authz/escalation) | attacker | opus | opus |
| 2 | Multi-tenant isolation (concurrent + crafted scope) | hostile tenant | opus | opus |
| 3 | Money integrity (dup/lost/maker-checker bypass) | fraud | opus | opus |
| 4 | AI abuse (injection/leak/cost) | prompt attacker | opus | opus |
| 5 | UX failures (lost work / stale / raw error) | careless user | sonnet | sonnet |
| 6 | Workflow failures (half-done critical flows) | interrupt | sonnet | sonnet |
| 7 | Operational (backups/alerts/health/jobs) | ops-on-a-bad-day | sonnet | haiku |
| 8 | Disaster recovery (restore/RTO/off-site) | DR | sonnet | haiku |
| 9 | Data corruption (partial write / bad migration / constraint gap) | integrity | opus | sonnet |
| 10 | Concurrency (double-submit / dual-cashier / replay) | race | opus | sonnet |
| 11 | Performance (rosters/marks/dashboards/search/AI fan-out) | load | sonnet | haiku |
| 12 | Human error (mis-tap / wrong field / skipped step) | fat-finger | sonnet | sonnet |

*Money, security, isolation, AI-abuse, corruption, concurrency get opus on both sides — highest blast radius. Ops/DR/perf verification can drop to haiku (mechanical reproduce).*

---

## 3. Refreshed attack seeds — POST-W2 / post-freeze surface (NEW since the 2026-07-03 framework)

The framework §2 playbook stands; these seeds ADD the surfaces built since (each anchored to real code so RT-1 reproduces, not guesses).

### Domain 1 · Security — new surfaces
- **Persona feed scope-resolution** (`intelligence/priority/priority_handlers.ts:41-55`): the persona param decides which scope the caller must hold (`parent→requireParentSelfScope`, `student→requireStudentSelfScope`). Attack: request `?persona=principal` / `?persona=director` with a teacher or parent JWT; request `?persona=finance` as a non-finance admin. Expect 403; prove no data returns on the deny path.
- **Waiver maker-checker permission split** (`clearance/clearance_waiver_route_contract_test.ts`): `manageSis` = maker (raise), `approveClearanceWaiver` = checker (queue/decide/revoke). Attack: hold only `manageSis`, try to `decide`/`revoke`; hold only the slug as parent/student. Expect 403 each.
- **Face-ID enroll/verify** (`/staff-attendance/enroll-face`, `/staff-attendance/manual-requests`): attack self-enroll for another staff, enroll during an active manual-request, approve one's own manual request (SoD).

### Domain 2 · Isolation — new surfaces
- **Universal Search cross-tenant** (`search/search_repository.ts`, `search_ranking.ts`): craft `organization_id`/`school_id` in the query or ride a director multi-school token; assert results never include another org/school; test the `pg_trgm` name index path under a crafted prefix.
- **AI call log / reservations org-scope** (`ai/ai_call_reservations_repository.ts`, `ai/ai_call_log_repository.ts`): can tenant A read/deplete tenant B's reservation rows? Concurrent reserve across two tenants must not bleed.
- **Persona feed data-scoping** (`intelligence/priority/*_sources.ts`): principal/director summaries must stay within the caller's school/org even when the aggregate query fans out.

### Domain 3 · Money — new surfaces
- **Clearance NET authority** (SCE-1): can a waiver be consumed twice (single-use)? can a revoke race a decide? does the TC gate read a stale finance NET? does `transferred` via PUT `/students/:id` bypass `enforceTransferClearance` (the closed P0 — re-verify it stays closed)?

### Domain 4 · AI abuse — new surfaces (highest-refresh area)
- **Prompt injection on EVERY AI entry point:** brief/digest free text (`intelligence/briefs/brief_service.ts` — A6 fences), parent guidance sources (`intelligence/priority/parent_sources.ts`), copilot prompt orchestrator (`copilot/copilot_prompt_orchestrator.ts`), communication generator (`intelligence/communication_generator.ts`). Seed: school/student names + free-text fields carrying `ignore previous instructions…`, scope-escape (`list all schools`), and data-exfil probes. Assert the fences hold and determinism-first blocks fabricated numbers.
- **Cost exhaustion / quota (A5):** loop copilot requests to exhaust spend; race two requests against ONE remaining reservation (`ai/ai_copilot_quota.ts`, `ai/ai_call_reservations_repository.ts`) — the atomic reservation must not oversell; force a no-key path and confirm honest degradation (not a silent fabricated answer).
- **Model gateway** (`ai/model_gateway.ts`): timeout/hang handling; ensure a failed LLM call never falls back to a mock served as real (CFC-1 item-2 invariant, under live-error conditions).

### Domains 5–6 · UX / Workflow — new surfaces
- App Lock: kill mid-entry while locked; sign-out escape in the `MaterialApp.router` builder (the R2 P0 — re-verify the inline confirm still works, no Navigator-ancestor throw); background→snapshot before the Dart scrim paints (device-residue, expect a documented gap not a regression).
- SCE-1 workflow: interrupt between waiver-approve and TC-issue; Face-ID: interrupt between capture and enrollment persist.

### Domains 7–11 · Ops/DR/Corruption/Concurrency/Perf — new surfaces
- Ops: the 12 new migrations `20260867–20260878` applied live — assert no constraint gap, RLS present on all 5 new tables (`ai_call_log`, `ai_call_reservations`, `ai_persona_memory`, `staff_face_enrollments`, `student_clearance_waivers`).
- Perf: persona feed + universal search under a 5k-roster tenant; copilot fan-out; the `search_scale_indexes` under load.
- Concurrency: dual-approve a single waiver; double-submit a face enrollment; concurrent persona-feed reads during a write.

---

## 4. Fixtures & tenant plan

- **Read-only / rolled-back on live** (`akshara_db`) for non-destructive probes; **destructive tests on `akshara_tenant_test`** (the faithful mirror) ONLY. Never mutate prod; never touch velora-salon/n8n/redis.
- **SSH:** control-master socket is down (key-only auth refused). RT-1 live legs need the owner to re-establish it (`ssh -fN -M -S ~/.ssh/akshara-cm.sock -o ControlPersist=12h root@46.28.44.46`) — until then, public health probes + `akshara_tenant_test`-via-owner + local `deno test` isolation-probe suites cover the offline-reproducible seeds.
- **Isolation probe harness already exists:** `supabase/functions/_shared/tenant_isolation_probes.ts` (+ the 233-probe live evidence) — RT-1 extends it for the concurrent/crafted-scope case rather than rebuilding.
- **Local-runnable seeds** (no VPS): all RBAC route-contract tests, injection-fence unit attacks, quota/reservation race (fake-db), matcher fail-closed, App Lock predicate tests. These run in RT-1 without owner provisioning.

---

## 5. Adversarial-verification protocol (framework §4, restated for this run)
1. Each candidate finding gets exact reproduction (`file:line` or live command + output), crafted input, observed vs expected, severity (§3 matrix), blast radius.
2. A **second distinct operator** attempts to REFUTE it; default to "refuted" unless independently reproduced.
3. Confirmed findings → severity → a P5-FIX task. Loop-until-dry: two consecutive rounds surface nothing new.
4. "Should be exploitable" is NOT evidence — reproduce or drop.

---

## 6. Readiness verdict

| Done-when criterion | Status |
|---|---|
| 12 domains scoped | ✅ §2 |
| Operators assigned (perspective-diverse, model-tiered) | ✅ §2 |
| Attack seeds current for the post-W2/post-freeze surface | ✅ §3 (anchored to real code) |
| Honest-claims baseline frozen | ✅ §1 |
| Fixtures/tenants ready (with the SSH caveat surfaced) | ✅ §4 |

**P4-RT-0 READINESS: PASS** (with one owner dependency flagged for the live legs — re-establish the SSH control-master; the local-runnable seed set proceeds regardless). **→ P4-RT-1** (12-domain assault, round law) is cleared to begin.
