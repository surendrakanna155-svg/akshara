# Akshara AI Support Intelligence Platform (ASIP) — Design & Governance

**Status:** 🟩 PRODUCTION CERTIFIED (2026-07-20) — both phases live on the pilot · **Author:** Opus 4.8 · **Date:** 2026-07-20 · Cert: `docs/SUPPORT_INTELLIGENCE_PLATFORM_CERTIFICATION.md`
**Branch / worktree:** `feature/asip-support-intelligence` (worktree `Akshara_ERP-asip`), based on `integration/w0-trunk` @ `31b6d02c`, base-verified.
**Migration band claimed:** `20260920000000` – `20260920999999` (strictly above all lane heads: main `…876`, DRP `…897`, PRA/trunk `…900000019`).
**Roadmap:** added as **PROGRAM ASIP** in `docs/roadmap/AKSHARA_CONSTITUTION_ALIGNED_MASTER_ROADMAP.md` (parallel lane, never gates the ERP; final integration depends on W0 convergence).

> **One standard, one gate.** This document is the ASIP interaction/architecture law; the **Engineering Constitution** + **`/eos`** decide "done." It rewrites nothing in the Constitution or the Adaptive-AI governance suite — it *inherits* their rails and applies them to platform support.

---

## 0. What ASIP is — and is not

**ASIP is the platform-support system** through which **customer schools report Akshara product issues to the Akshara Support Team**, and through which a very small support team investigates and resolves them at scale with AI assistance.

- It is **NOT** the school's internal Complaint / Grievance system (that is a school-domain feature).
- It is **NOT** the existing `control_center` Super-Admin fleet dashboard (which today shows a *read-only mock* `SupportTicket` list with no create/reply/attach/investigate).

**North-star flow:** School reports issue → platform auto-gathers technical evidence → AI investigates → support engineer reviews → resolution applied → school informed → platform learns.

**Product promise to the school:** the reporter provides only **Description + Screenshot (+ optional screen recording)**. Everything technical (tenant, user, role, module, screen, app version, device, timestamp, session, request/correlation IDs, relevant audit events, logs, API calls, workflow state, safe diagnostics) is collected **automatically**.

**Product promise to the support engineer:** never manually collect logs, screenshots, timestamps, repro steps or diagnostics — the platform prepares the complete investigation package; the engineer reviews AI findings, approves the action, communicates with the customer, and tracks resolution.

**Non-negotiable AI rule (inherited from Adaptive-AI doc 10 §12):** **AI assists; humans approve. No unrestricted autonomous production changes — ever.** AI reads evidence and drafts; a human support engineer decides and acts.

---

## 1. Reuse-first map — extend, never duplicate

Per AGENTS.md ("reuse existing abstractions — extend, do not duplicate") and Constitution LAW 9, ASIP builds **on** the platform primitives. It introduces **zero** new RBAC, Workflow, Audit, Notification, Attachment, Communication or Ticket engines.

| Capability ASIP needs | Reused primitive (canonical file) | How ASIP uses it |
|---|---|---|
| Edge routing | `supabase/functions/api/app.ts` chain-of-responsibility (`moduleRouters`) | new `_shared/support/support_router.ts` returns `Response\|null`, prefix `/support`, appended to the array |
| AuthN + session freshness | `_shared/permission_middleware.ts::authenticateRequest` | every handler funnels through it |
| RBAC | `_shared/permission_middleware.ts::requireAnyPermission` + new `support.*` permission slugs seeded into the existing RBAC tables | one permission engine; **no parallel authz** |
| Tenant isolation | `_shared/tenant_db.ts::withTenantContext` on the non-bypass `erp_tenant` role + RLS GUCs `app_current_tenant_id()/_scope()/_school_id()` | every school-side row org+school-scoped, `ENABLE`+`FORCE` RLS |
| Audit | `_shared/audit/audit_repository.ts::recordMutationAudit` / `recordServerAuditEvent` | every incident mutation audited |
| **Audit as evidence** | `_shared/audit/audit_repository.ts::listAuditEvents` (filtered, tenant-scoped) | evidence collector pulls the reporter's recent audit events |
| Attachments / storage | `_shared/storage/storage_service.ts` presign→PUT→confirm + new `support-incident-attachments` bucket | screenshots + screen recordings (net-new binary upload for ASIP) |
| Notifications | `_shared/communication/notification_service.ts::enqueueFromTemplate` + `notification_deliveries` | notify reporter on reply / status change |
| Conversation | `comm_*` message pattern (schema mirror) | school-visible ticket replies |
| Workflow / SLA / escalation | client `lib/core/workflow/workflow_engine.dart` + status machine | ticket lifecycle + escalation |
| Maker-checker (Phase 2 prod actions) | `_shared/approval/*` (`approval_requests`, SoD guards) | any support action that mutates a tenant requires an approval |
| **AI — the whole substrate** | `_shared/ai/model_gateway.ts::governedModelText` / `callModelGateway` (+ `ai_call_log`, `ai_response_cache`, `ai_semantic_cache_embeddings`, `embeddings_client.ts`, `output_guard.ts`) | **every** ASIP LLM call routes through the governed gateway: spend cap, rate limit, cache, timeout, output-guard, telemetry, deterministic fallback — for free |
| Client context capture | `lib/core/errors/error_reporting_service.dart`, `CorrelationIdInterceptor`, `AuditLogger` (200-event local ring), `DeviceSessionMetadata` | breadcrumb + correlation + session identity feed the incident snapshot |
| Client feature wiring | `interface → api/mock → provider → guarded GoRoute` recipe; `RbacModuleRegistry` ∩ `kErpRouteViewPermissions` (route→module) | new `support` client module |

**Genuinely net-new (does not exist anywhere) — built by ASIP:**
1. A **school-user-facing "Report an issue"** flow (submission + conversation).
2. A **binary upload pipeline on the client** (screenshot capture + screen recording + multipart/presigned PUT). *Today every client "attachment" is a metadata-only reference — there is no binary upload anywhere.*
3. **Runtime device / OS / app-version capture** + a **route/module + breadcrumb tracker** (the auto-diagnostics backbone).
4. The **incident evidence snapshot** + **deterministic AI Incident Package** assembly.
5. (Phase 2) **cross-tenant support intelligence** — clustering, dedup, RCA, KB, engineering handoff, and the support workspace.

---

## 2. Architecture — two principals, one hard tenant wall

ASIP spans two principal domains:

- **The reporting school tenant** (hundreds/thousands of them) — a normal ERP tenant. Reporters are ordinary tenant users, RLS-walled to their own org+school.
- **The Akshara Support Team** — a *cross-tenant* platform-internal principal that must triage/investigate incidents from **every** school.

**The load-bearing constraint (from backend recon):** the platform has a **hard org wall** — RLS everywhere is `organization_id = app_current_tenant_id()`, and the only RLS bypass (`service_role`) is reserved for auth/storage plumbing. **A cross-tenant "Akshara-internal" data-plane principal does not exist today.** How the support team sees across tenants is therefore a genuine architecture + production-safety decision (Part 7B lists *Tenant Isolation Failure* and *Permission Escalation* as automatic certification failures). → **Owner Decision A** (§6).

### 2.1 Phase split driven by that constraint

- **Phase 1 — School Incident Reporting + Automatic Evidence Capture (decision-INDEPENDENT).** Everything that lives inside the reporting tenant: report an issue, auto-collect the evidence snapshot, upload screenshot/recording, converse, and assemble a deterministic (AI-enriched) **Incident Package**. All standard org+school RLS. **No cross-tenant anything.** This is what ASIP builds and certifies first.
- **Phase 2 — Cross-tenant Support Intelligence + Workspace (decision-GATED on A & B).** Incident clustering/dedup/similar-incident, cross-tenant AI investigation, KB learning, engineering handoff, and the support engineer workspace.

> **Why evidence is a *snapshot*, in both possible cross-tenant models:** an incident must be reproducible and auditable at report-time; the support view must not silently change as the school mutates its data afterward. So Phase 1 freezes a **PII-minimized evidence snapshot** at report time regardless of how Phase 2 support access is ultimately wired — making Phase 1 safe to build now.

---

## 3. Phase 1 data model (school-tenant, `20260920000000+`)

All tables: `organization_id`+`school_id`, `ENABLE`+`FORCE` RLS with the school-scope policy, `erp_tenant` grants (append-only where noted), `set_updated_at()` trigger where mutable.

1. **`support_incident`** — the ticket. `id, organization_id, school_id, reporter_user_id, reporter_role, public_ref (SUP-XXExternal), title, description, category (enum, AI-suggestable), status (new|triaging|in_progress|awaiting_customer|resolved|closed), severity (sev1..sev4), module_key, screen_route, app_version, platform, device_model, os_version, session_id, correlation_id, first_seen_at, created_at, updated_at`. RLS: reporter sees own school's incidents; `support.view`/`support.manage` staff see the school's incidents.
2. **`support_incident_evidence`** — one JSONB snapshot per incident (append-only): `incident_id, kind (context|audit_events|api_calls|workflow_state|diagnostics), payload jsonb, collected_at`. PII-minimized by construction (`safe diagnostics`).
3. **`support_incident_attachment`** — `incident_id, kind (screenshot|screen_recording|log_export), storage_path, file_name, content_type, size_bytes, uploaded_by, created_at`. Bytes live in the `support-incident-attachments` Storage bucket (tenant-prefixed path).
4. **`support_incident_message`** — the conversation. `incident_id, sender_user_id, sender_kind (reporter|support|system), visibility (school_visible|internal_note), body, created_at`. `internal_note` rows are Phase-2 support-only (never returned to reporter scope; enforced by RLS + handler).
5. **`support_incident_event`** — the timeline (append-only): `incident_id, event_type (created|status_changed|assigned|escalated|evidence_collected|ai_analyzed|message_posted|resolved), actor_user_id, from_value, to_value, metadata jsonb, created_at`.
6. **`support_incident_ai_analysis`** — the AI Incident Package result (append-only, versioned): `incident_id, version, categorization jsonb, severity_suggestion, summary, likely_root_cause, suggested_next_steps jsonb, confidence, model, generated_at, approved_by, approved_at`. **`approved_*` are null until a human accepts** — AI output is never auto-applied.

The **AI Incident Package** returned to the API is assembled deterministically from evidence (1–5) and *optionally* enriched by a single governed model call (6); if the gateway declines (no key / rate / spend cap / timeout), the deterministic package is still complete.

---

## 4. Phase 1 API contract (`/support`, source of truth for the client)

All under the edge `api` function; all authenticated; envelope `{data,error}`.

| Method + path | Permission / scope | Purpose |
|---|---|---|
| `POST /support/incidents` | school scope (any authenticated tenant user) | create incident (title, description, client-context block) → returns incident + `public_ref` |
| `GET /support/incidents` | reporter: own; `support.view`: school | list my incidents (paginated) |
| `GET /support/incidents/:id` | reporter own / `support.view` | incident + evidence + attachments + messages + latest AI analysis |
| `POST /support/incidents/:id/attachments/presign` | reporter own | validate + presign upload URL for a screenshot/recording |
| `POST /support/incidents/:id/attachments/confirm` | reporter own | confirm an uploaded object → row |
| `POST /support/incidents/:id/messages` | reporter own / `support.manage` | post a school-visible reply |
| `POST /support/incidents/:id/collect-evidence` | `support.manage` (or auto on create) | run the evidence collector → snapshot rows |
| `POST /support/incidents/:id/analyze` | `support.manage` | assemble the AI Incident Package (deterministic + governed enrichment) |
| `POST /support/incidents/:id/status` | `support.manage` | transition status (audited timeline event) |

**Client context block** (posted on create; the client auto-fills, the user never types it): `{ app_version, platform, device_model, os_version, session_id, correlation_ids[], screen_route, module_key, breadcrumbs[], recent_api_calls[] }`. The server enriches it with tenant-side `listAuditEvents` (recent events for the reporter) + workflow/approval state, producing the evidence snapshot.

---

## 5. AI governance alignment (inherited, not reinvented)

ASIP's AI is **platform-support-facing** (audience = Akshara support engineers), a different audience from the school copilot, but it obeys the same rails (Adaptive-AI doc 10 §12):

1. **No AI on writes / money / approvals.** AI reads evidence + drafts findings; humans act (Phase-2 prod actions go through maker-checker `approval_requests`).
2. **Every model call through the governed gateway** (`governedModelText`) → spend cap, per-user/school rate limit, timeout, output-guard, `ai_call_log` telemetry, deterministic fallback. ASIP surfaces use a distinct `surface` id (`support_triage`, `support_rca`, …) for telemetry/economics.
3. **Deterministic-first.** Evidence collection, categorization heuristics, dedup fingerprints and clustering keys are deterministic; the LLM is the last-mile enrichment (narrative RCA, summary, suggested-fix drafting) — reached only when a rule/query can't answer.
4. **PII-minimization.** The evidence snapshot carries IDs + aggregates + safe diagnostics, not raw student PII; prompts inherit that minimization (doc 10 §4).
5. **Explainable + auditable + per-tenant-disableable.** Every AI analysis row records model + inputs digest; the existing per-tenant AI kill switch disables ASIP AI too (deterministic package still works).

---

## 6. Owner decisions gating Phase 2 (surfaced as a batch)

Phase 1 does **not** need these. Phase 2 (cross-tenant support intelligence + workspace) does. Recommendations given; **not** implemented until the owner confirms.

| # | Decision | Options | Recommendation |
|---|---|---|---|
| **A** | **Cross-tenant support access model** | (A1) Snapshot/mirror · (A2) cross-tenant principal | 🔒 **DECIDED (owner, 2026-07-20) → A1 snapshot/mirror.** |
| **B** | **Support workspace surface** | (B1) new web console (scoped unfreeze) · (B2) Flutter console · (B3) standalone app | 🔒 **DECIDED (owner, 2026-07-20) → B1 new web support console (scoped unfreeze of a distinct `/support-console` area; the frozen ERP viewer is untouched).** |

### 6.1 Phase 2 locked architecture (A1 mirror + B1 web console)

**The mirror domain (A1).** A dedicated **Akshara platform-support organization** (a fixed `PLATFORM_ORG` id). School-side incident writes call a `SECURITY DEFINER` bridge fn (`support.mirror_incident(...)`, `EXECUTE` to `erp_tenant`) that inserts a **PII-minimized** copy into `support_platform_incident` (+ children/evidence) scoped to `PLATFORM_ORG`. The mirror tables' RLS reads only when `app_current_tenant_id() = PLATFORM_ORG` — so a school session can **never** read the mirror, and a support session (a `PLATFORM_ORG` member with `platformSupport`) reads **only** the mirror, never a school tenant table. The definer fn is the **only** cross-boundary write; the org wall is otherwise intact (no `service_role` on the data plane, no cross-tenant RLS). Resolution flows back to the school incident through a second definer fn. **Live activation requires seeding `PLATFORM_ORG` + support principals — owner/deploy-gated** (like the live cert).

**Support-side (Phase 2) workstreams on the mirror:** list/triage all incidents · assign/escalate · internal notes · **clustering** (deterministic fingerprint = category+module+top-error+signals → shared incident; "investigate once, resolve many") · **AI investigation** (cross-incident RCA + KB search via the governed gateway, deterministic-first) · **KB learning** (resolved → articles) · **engineering handoff** (deterministic package export). Any support action that would mutate a school tenant goes through maker-checker `approval_requests`.

**Web console (B1):** a distinct `/support-console` area in the React app (scoped unfreeze), consuming the support-side `/support/platform/*` APIs. Desktop-first workspace: queue, incident view (evidence+timeline+AI diagnosis+conversation), assignment, escalation, resolution.

**ASIP-8 — Continuous Learning (KB).** Resolving an incident/cluster distils the resolution into a **`support_kb_article`** keyed by the **same deterministic cluster fingerprint** (`category|module|error-signature`) the clustering engine already computes — so "investigate once, resolve many" becomes "remember forever." The KB lives entirely inside the mirror domain (PLATFORM_ORG-scoped, identical RLS to `support_platform_incident`); both learn (on resolve) and recall (on investigate/detail) run under a support session, so **no `SECURITY DEFINER` bridge is introduced — the org wall is untouched**. Recall is **deterministic-first**: a new incident recalls a prior resolution by exact fingerprint (no embeddings), which the console surfaces proactively ("Similar resolved issues") and the AI investigation folds in — an exact match leads with the proven fix and raises the confidence floor to 80. An **optional** pgvector `support_kb_embedding` layer adds semantic similarity, created only behind a `pg_available_extensions` guard and reached only when `AI_EMBEDDINGS_API_KEY` is set — **fully dormant otherwise, exactly like the W2.8 semantic cache**. Console surface: a `/support-console/kb` browser + the incident-workspace recall panel. API: `GET /support/platform/kb[?q=]`, `GET /support/platform/kb/:id`.
| **C** (noted, not blocking) | **AI investigation cost owner** — ASIP support AI is billed to *Akshara*, not schools; needs its own spend cap/quota config | reuse `ai_settings` with a platform-support budget | default a conservative platform budget; owner tunes from `ai_call_log`. |

**Known production blocker (not an owner *decision*, a *gate*):** "PRODUCTION CERTIFIED" requires a **live N/N cert against the VPS pilot** (real auth/DB/RBAC) and a **deploy**, which is **owner-gated** (owner SSH control-master required; "my key alone isn't authorized") and depends on **W0 convergence** landing. Autonomous end-state for Phase 1 = built + `deno`/`flutter`/golden green + `/eos` PASS + docs + a live-cert script authored and ready; the live run + deploy await owner authorization.

---

## 7. Definition of done (per the Constitution)

Phase 1 is "done" only when: `/eos support` = PASS with **zero open P0** and **no Part 7B automatic-failure condition** (esp. tenant-isolation, permission-escalation, broken auth); Definition-of-Complete pillars met (security, a11y, i18n, perf, reliability, prod-readiness); evidence-based (not "tests pass"); tenant isolation + RBAC deny-paths + audit logging verified; no untracked mocks/stubs; and — for **PRODUCTION CERTIFIED** — a live N/N VPS cert (owner-gated). Change-control (roadmap Appendix C) records the ASIP rows.

---

## 8. Build log

- **2026-07-20** — Workstream created (isolated worktree, base-verified off `integration/w0-trunk`); reuse + governance recon complete; design fixed; Phase 1 build begins.
- **2026-07-20** — **Phase 1 backend complete + green.** 4 migrations (`20260920000000–…030`: incident core, evidence+AI, attachments+bucket, permissions; additive, ENABLE+FORCE org+school RLS, `erp_tenant` grants). Edge module `_shared/support/` (types, repository, evidence collector, incident-package assembler, service, handlers, router) wired into `api/app.ts`; extends `storage_service.ts` with a support-bucket presign helper. **32 deno tests pass**; full edge app type-checks clean (`deno check`). Live-cert `scripts/qa/live_cert_asip.py` authored (health · report+auto-evidence · deterministic AI package · RBAC deny · reporter-privacy · cross-school isolation · unauth · non-destructive cleanup) — **authored-and-ready; live N/N run pending owner deploy authorization + W0 convergence (production blocker, not a defect).** Hardening: reporter timeline hides support-internal events + internal notes.
- **2026-07-20** — **Phase 1 Flutter client complete + green.** Automatic context capture backbone (`incident_context_service` + route observer + Dio interceptor + telemetry buffer): app version (`package_info_plus`), device/OS (`device_info_plus`), platform, session id, current route→module (via `RbacModuleRegistry` ∩ route perms), correlation ids, breadcrumbs, recent API calls — reporter types none of it, every probe defensive. First real client binary-upload pipeline (presign→PUT→confirm, screenshot via `image_picker`; screen recording deferred per mission). Repository (interface/api/mock/mapper/wiring, `SUPPORT_API_ENABLED` gate) + 3 screens (Report / My Issues / Detail+conversation). `viewSupport`/`manageSupport` mirror the backend slugs; reporting is auth-gated for every persona. **`flutter analyze` 0 issues (whole project); `flutter test test/features/support` 6 passed.**
- **2026-07-20** — **Phase 2 backend complete + green (Owner Decisions A1 + B1 locked).** Mirror domain (migration `20260920000040`): `support_platform_incident/_evidence/_note` + `support_cluster`, RLS-scoped to a fixed `PLATFORM_ORG` (readable only by a platform-support session; a school session never matches). **3 SECURITY DEFINER bridges** (search_path-pinned, `REVOKE PUBLIC`, `EXECUTE` to `erp_tenant`): `mirror_incident`/`mirror_evidence` take the source org/school from the session GUC (never a parameter → a school can only mirror ITS OWN incident); `propagate_resolution` asserts the caller IS `PLATFORM_ORG` before writing back to a school incident. School create/status handlers mirror best-effort (own txn; never block a report). Support console API `/support/platform/*` (queue/detail/assign/support-status/escalate/notes) + **deterministic clustering** (category+module+error-signature fingerprint → shared cluster, auto-linked on first support view — "investigate once, resolve many") + **resolve one or a whole cluster** (propagates to every affected school) + **AI cross-incident investigation** (deterministic-first + governed gateway) + **deterministic engineering-handoff export**. **45 deno tests pass**; edge app type-checks clean. The resolution write-back also **notifies the reporter** ("school is informed") via the delivery queue (migration `20260920000050` extends the propagate bridge). **Remaining owner/deploy-gated:** `PLATFORM_ORG` + support-principal seed. Web support console (B1) under build.
- **2026-07-20** — **Phase 2 web support console complete + green.** `/support-console` (React, scoped unfreeze per B1 — additive, the frozen ERP viewer is untouched): queue (by support_status, cluster "N schools" badges) · incident workspace ("one place": evidence renderer + AI diagnosis + internal notes + assign/status/escalate/**resolve incl. resolve-whole-cluster** + engineering-handoff copy/download) · clusters list+detail. Gated on `platformSupport` (server also enforces → 403); demo/no-backend renders honest "awaiting backend" states — **no mock data** in the shipped path. Reuses the existing api client, react-query, router, permissions lib, Tailwind theme, UI components (no new npm deps). **`npm run build` PASS (tsc 0 + vite); `npm run test` 147/147 (9 new).**
- **2026-07-20 — ✅ DEPLOYED + PRODUCTION CERTIFIED (owner-authorized).** Branch pushed to `origin`; additive deploy onto the live pilot's deployed DRP head (897) — net-new `_shared/support/*` + a 2-line `app.ts` route registration + a `storage_service.ts` append (DRP untouched; VPS backups `*.asip-bak-*`). 6 migrations applied + ledgered on `akshara_db` (head → `20260920000050`); `PLATFORM_ORG` + 4 support principals seeded. Prod edge restarted, healthy, `/support/*` live + auth-gated, no regression. **Live cert `scripts/qa/live_cert_asip_vps.sh`: 18/18 on the test stack AND 18/18 production smoke** (real edge/DB/JWT/RBAC/AI, non-destructive, 0 residue) — all 9 owner smoke items. **Two real bugs were caught LIVE and fixed** (audit-evidence portability vs the DRP base; model-gateway transaction isolation). Cert doc: `docs/SUPPORT_INTELLIGENCE_PLATFORM_CERTIFICATION.md`. Owner tail: set real phone numbers on the 4 seeded support principals to enable OTP login (RBAC already wired).
- **2026-07-21 — ASIP-8 Continuous Learning (KB) built + green.** The last open roadmap item (ASIP-1…7 already PRODUCTION CERTIFIED). Migration `20260920000060` adds `support_kb_article` (PLATFORM_ORG-walled, same RLS as the mirror, `UNIQUE(platform_org_id, fingerprint)`, **no `SECURITY DEFINER`** — all writes are support-side) + a **defensive** `support_kb_embedding` (created only behind a `pg_available_extensions` guard; dormant without pgvector). New `_shared/support/support_kb_repository.ts` + `support_kb_service.ts` reuse the existing `clusterFingerprint`/`errorSignature`/`diagnosticsFromMirrorEvidence` and the governed `embedText` client (no new engines). Wired in: **resolve learns** (deterministic upsert in-tx; best-effort embed in its own tx), **investigate + incident-detail recall** prior resolutions (deterministic exact/related + optional semantic), and new `GET /support/platform/kb[?q=]` / `/kb/:id`. An exact fingerprint match leads the AI diagnosis with the proven fix and raises the confidence floor to 80 (`applyPriorResolutions`, pure + unit-tested). Web (B1 scoped unfreeze): `/support-console/kb` browser + a "Similar resolved issues" recall panel + prior-resolutions in the AI-diagnosis card. **Verification: 65 deno support tests (deno check clean) + 152 web tests + web build PASS + tsc clean.** Live-cert `live_cert_asip_vps.sh` extended to **23 checks** (learn-on-resolve · KB list · reporter-RBAC-deny · recall-exact-on-a-new-incident), made **hermetic** (cert-unique failing path ⇒ signature/cluster/KB article can't collide with real data and are fully removed at cleanup). **Owner/deploy-gated (NOT defects):** deploy migration `…060` + the live 23/23 run — identical gating to the rest of Phase 2.
- **2026-07-20 — FINAL internal EOS gate (ASIP Phase 1 + Phase 2 — backend + Flutter + web): CONDITIONAL PASS.** 0 open P0; **no Part 7B automatic-failure** live (tenant isolation preserved — org+school RLS + the mirror's `SECURITY DEFINER`-only cross-boundary bridge that takes source org from the session GUC; no permission escalation — one permission engine, deny-paths tested; no data loss — additive migrations, append-only evidence/timeline; no broken auth — every endpoint auth-gated; PII-minimized evidence + reporter-privacy hardened). Verification: **45 deno + 6 Flutter + 147 web tests pass**; `deno check` + `flutter analyze` + `tsc`/`vite build` all clean. **Remaining owner/deploy-gated (NOT defects):** the `PLATFORM_ORG` + support-principal seed, and the **live VPS N/N cert + deploy** (owner SSH control-master + W0 convergence). Screen-recording capture is deferred (optional per mission). **ASIP is engineering-complete; "PRODUCTION CERTIFIED" awaits the owner-gated live run.**
