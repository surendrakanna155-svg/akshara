# Akshara ERP — Engineering & Architecture Audit

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Scope:** Flutter client architecture + Deno/Supabase backend architecture + code quality + scaling shape.
**Confidence:** High.

---

## 1. Executive summary

1. **The codebase is large, clean-compiling, and genuinely engineered — not a prototype.** ~289K Dart LOC (1,714 files, 47 feature modules) + ~144K TS LOC (647 edge files, ~51 routers) + 168 migrations. `flutter analyze` = **0 issues**. This is a real product.
2. **The old "mock backend" critique is now largely OBSOLETE for the core.** Backend handlers are real: **466 `withTenantContext` transactions + 1,095 `queryObject` calls**, no `ApiNotConnected`/`501` anywhere in `supabase/functions`. The "mock" lives entirely on the Flutter side as a dev/test fallback.
3. **Mock-vs-real is a build-time switch.** Every `*_API_ENABLED` flag in `lib/core/repositories/repository_config.dart` defaults `false` and is gated by a master `enableApiMode`. **Default (dev/test) = mock repos; the live build (`config/live_release.json`) flips ~40 flags on → real backend.** A release built *without* the live-config dart-defines silently runs on mocks (see Security audit — this is a real release-discipline risk).
4. **A handful of shipped UI surfaces have no backend and remain mock in production** (Workflow Automation, Academic Operations, Continuity, Platform Intelligence/Operations, Multi-School Ops, Verticals, White-Label). They render fake data or would 404. These are owner-deferred (hide-first per O1) but are currently *reachable* mock surfaces, not hidden ones.
5. **The backend is one Deno edge function, modular inside.** `api/app.ts` imports ~50 routers and dispatches in a fixed array order; each router self-guards on a path prefix. Clean separation *within* a single isolate — but a single shared-fate blast radius.
6. **Route matching is hand-ordered if-chains + regex (~358 literal + ~153 regex), and the ordering is load-bearing and fragile.** Literal routes must precede `/{id}` regexes or get swallowed; the code carries scar-tissue comments about exactly this.
7. **Two "universal" reliability claims are materially overstated** (detailed in the Data-Reliability audit): idempotency is inert without a client header (~4% real coverage), and `row_version`/409 conflict is enforced on **1 of 4** wired tables — the money table (`finance_collections`) has the column+trigger but **no handler checks it**.
8. **Design system is real and token-driven** (see UX audit) — exact-match color/type/spacing tokens live in production dashboards.

---

## 2. Findings

| ID | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| ENG-1 | **P1** | `row_version`/409 "universal concurrency" enforced on 1 of 4 tables; `finance_collections` has the guard column but no handler reads it → silent money lost-update | `migrations/20260817000000…:24-53`; enforcement only `exam_administration_repository.ts:568-571`; finance grep for `expectedVersion` = empty | Wire the version check into finance collection/refund updates, or drop the "universal" framing. |
| ENG-2 | **P1** | Server-side plan-gating (402) ships **OFF by default** (`ENTITLEMENT_ENFORCEMENT` env unset→false) while the client believes it's on | `entitlement_enforcement.ts`; `entitlement_middleware.ts:133`; client `live_release.json` `ENTITLEMENT_API_ENABLED:true` | Set `ENTITLEMENT_ENFORCEMENT=true` in the live `.env` before pilot, or document that plan-gating is intentionally dark. |
| ENG-3 | **P1** | ~8 shipped UI surfaces are backend-less and serve mock data / would 404 in production | `repository_config.dart` (Workflow/Academic-Ops/Continuity/Platform-Intel/Platform-Ops/Multi-School-Ops/Verticals/White-Label all `defaultValue:false`, absent from `live_release.json`) | Route-guard these OFF (hide, don't mock) for pilot, or wire minimal backends. A mock surface a real user can reach is worse than a hidden one. |
| ENG-4 | **P2** | Route dispatch correctness depends on manual registration order (literal-before-regex) | `finance_router.ts:194-201,219-222,261-268`; `app.ts:92-159` | Add a route-registry lint/test asserting no path is shadowed; or move to a trie/table matcher. |
| ENG-5 | **P2** | RBAC is enforced per-handler by convention (615 `authenticateRequest` sites), no framework-level forced choke point | `app.ts` routes straight to handlers; 0 current offenders found | Add a default-deny wrapper at `routeModuleRequest` (opt-out, not opt-in) + a CI check that every handler authenticates. |
| ENG-6 | **P2** | Single edge function = shared-fate; `POOL_SIZE=10` connections per isolate shared across all 50 modules | `index.ts:7`; `tenant_db.ts:16` | Load-test hot paths concurrently; monitor pool saturation; consider per-domain split if a module proves noisy. |
| ENG-7 | **P2** | 154 handlers leak raw `error.message` into client error envelopes (info disclosure) | `auth_handlers.ts:316,460,614`; `tenant_handlers.ts:75`; `app.ts:245,325` (+149 more) | Return fixed non-leaking messages for 5xx; keep detail in server logs only. |
| ENG-8 | **P2** | 4 bulk endpoints iterate request arrays with no size cap (DoS/resource-exhaustion) | `education_handlers.ts:244`; `finance_structures_repository.ts:71`; `finance_mapper.ts:133`; education paper items | Cap array length before the insert loop (audit_handlers already does this right at 100). |
| ENG-9 | **P3** | Non-standard per-module error codes (`GROWTH_ERROR`, `MEMORIES_ERROR`…) prevent generic client handling | `errorEnvelope` code histogram | Standardize a small closed error-code set; keep module detail in `message`. |
| ENG-10 | **P3** | 15 validation errors use HTTP 400 where 422 is correct | e.g. `attendance_handlers.ts:404` | Normalize to 422. |

---

## 3. Scaling shape (100 → 5,000 schools)

- **Sound for the pilot and small-scale (Verified/Likely):** lazy per-isolate connection pool, RLS via `set_request_context` inside a per-request transaction, no top-level awaits (clean cold start), bounded background fan-out (notification drain + parent fan-out are explicitly capped).
- **Structural watch-items at scale (Likely):**
  - **Single edge isolate** shares CPU + a 10-connection pool across every module — a hot/slow module (AI copilot, heavy report) can starve finance/attendance. Needs concurrent load testing before scale claims.
  - **Bounded-but-present N+1 loops** in the largest report/aggregation repos (`pilot_operations_repository.ts`, `exam_administration_repository.ts`, `hr_reports_repository.ts`, `student_360_service.ts`) — per-request scoped, so not unbounded, but the biggest rosters will be the slowest. Convert hot loops to set-based `= ANY($1)` SQL.
  - **Shared-DB RLS on one Postgres node** (see Deployment audit) — the multi-tenant model is sound, but it currently runs on a single container on a single VPS. Horizontal scale requires the "School Registry + migration fleet" that exists only as a design (`DEPLOYMENT_MODEL_AND_DR_PLAN.md`), not code.

---

## 4. Genuine strengths

- **Real end-to-end handlers**, repository-layered per module, parameterized SQL throughout. No backend stubs.
- **Defense-in-depth tenant isolation** — non-bypass `erp_tenant` role + per-request transaction context (see DB audit).
- **Consistent response envelope + observability** — every response (success and error) gets CORS + correlation-id + one structured log line with no bodies/tokens leaked.
- **Real maker-checker / separation-of-duties** (fee concession, refund, stock write-off) — computed by production code, not test theater.
- **Money-safe input guards** (`MAX_FIELD_LEN`, `MAX_INT_MAGNITUDE`) backed by DB CHECK constraints.
- **Clean compile, disciplined module structure, 47 cohesive feature modules.**

## 5. Unknowns

- Whether the Flutter API layer attaches `Idempotency-Key` to *all* mutations (it does not — see Data-Reliability audit; ~6 paths only).
- Whether `ENTITLEMENT_ENFORCEMENT=true` is actually set in the live VPS env (default is off).
- Real concurrent-pool behaviour under multi-module load (needs a load test; not readable from code).
- Exact endpoint count (~446 claimed; ~511 matcher branches counted, not de-duplicated).
