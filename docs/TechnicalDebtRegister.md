# Akshara ERP — Technical Debt Register

**Version:** 1.0  
**Last updated:** June 2026  
**Source audits:** v1.5–v2.7 ArchitectureReview documents

---

## Summary

| Priority | Open | In Progress | Resolved (v2.7) |
|----------|-----:|------------:|----------------:|
| P0 | 3 | 0 | 2 |
| P1 | 8 | 0 | 5 |
| P2 | 12 | 0 | 3 |
| P3 | 6 | 0 | 0 |
| **Total** | **29** | **0** | **10** |

---

## P0 — Production Blockers

| ID | Issue | Impact | Effort | Owner | Status |
|----|-------|--------|--------|-------|--------|
| TD-P0-01 | No server-side RBAC / tenant RLS | Authorization bypass via direct API | 4–6 wks (backend) | Agent D + Backend | Open |
| TD-P0-02 | Audit events not ingested server-side | Compliance gap; no tamper-evident trail | 2–3 wks | Agent D + Agent A | Open |
| TD-P0-03 | 8 ERP modules throw `ApiNotConnectedException` when API flags enabled | Cannot enable stub modules in staging | 8–12 wks (rollout) | Agent A | Open |
| TD-P0-04 | ~~Plaintext token storage~~ | Credential theft on rooted devices | — | Agent D | **Resolved v2.7** |
| TD-P0-05 | ~~No JWT claim validation client-side~~ | Invalid tokens attached to requests | — | Agent D | **Resolved v2.7** |

---

## P1 — High Priority

| ID | Issue | Impact | Effort | Owner | Status |
|----|-------|--------|--------|-------|--------|
| TD-P1-01 | Parent/teacher/student apps use inline mocks — no repository layer | Mobile cannot connect to live API | 6–8 wks | Agent C | Open |
| TD-P1-02 | No pagination in repository interfaces | Performance collapse at 5k+ rows | 3–4 wks | Agent A | Open |
| TD-P1-03 | No OpenAPI contract validation against staging | DTO drift from backend | 2 wks | Agent A + Agent E | Open |
| TD-P1-04 | manage* permissions not wired on all mutation routes | UX-only RBAC on some screens | 1–2 wks | Agent D | Open |
| TD-P1-05 | Audit upload uploader throws `UnimplementedError` until backend wired | Queue grows without drain | 1 wk | Agent D | Open |
| TD-P1-06 | Cross-module handoff (Adm→Fin→SIS) partially untested under dual-API | Integration regressions | 1 wk | Agent E | Open |
| TD-P1-07 | Demo auth paths remain for parent/teacher/student personas | Mock OTP bypass in non-API mode | 2 wks | Agent D | Open |
| TD-P1-08 | ~1,600 Riverpod providers — broad rebuild fan-out | UI jank on low-end devices | 3–4 wks | Agent B | Open |
| TD-P1-09 | ~~No refresh token reuse detection~~ | Token theft undetected | — | Agent D | **Resolved v2.7** |
| TD-P1-10 | ~~Permission sync service missing~~ | Stale permissions after role change | — | Agent D | **Resolved v2.7** |
| TD-P1-11 | ~~Audit local-only ring buffer~~ | Events lost at cap | — | Agent D | **Partial v2.7** (queue ready) |
| TD-P1-12 | ~~Client-only permission cache without version tracking~~ | Downgrade attacks | — | Agent D | **Resolved v2.7** |
| TD-P1-13 | Non-virtualized DataTables (~40 instances) | Scroll jank on large lists | 2–3 wks | Agent B | Open |

---

## P2 — Medium Priority

| ID | Issue | Impact | Effort | Owner | Status |
|----|-------|--------|--------|-------|--------|
| TD-P2-01 | 11 duplicate `*ModuleScaffold` widgets (~2,200 LOC) | Maintenance burden | 2 wks | Agent B | Open |
| TD-P2-02 | Mock repositories ignore tenant scoping | Wrong data in multi-tenant demo | 1 wk | Agent A | Open |
| TD-P2-03 | `ControlCenterGuard` defined but unused | Dead code | 0.5 d | Agent D | Open |
| TD-P2-04 | Failed refresh / 401 may not force logout in all paths | Stale sessions | 1 wk | Agent D | Open |
| TD-P2-05 | No E2E / Patrol tests | No full-path automation | 3–4 wks | Agent E | Open |
| TD-P2-06 | Large mock seed data (admissions mock 1,250+ LOC) | Slow hot reload | 1 wk | Agent A | Open |
| TD-P2-07 | SIS bulk assignment upload placeholder | Incomplete workflow | 1 wk | Agent B | Open |
| TD-P2-08 | Finance refund reject workflow missing | Incomplete refund lifecycle | 1 wk | Agent B | Open |
| TD-P2-09 | Refund evidence multipart upload deferred | No receipt attachment | 1 wk | Agent A | Open |
| TD-P2-10 | SIS audit event types deferred | Incomplete SIS audit trail | 0.5 wk | Agent D | Open |
| TD-P2-11 | PaginationDto parsed but unused in UI | Wasted API payload | 1 wk | Agent B | Open |
| TD-P2-12 | `allowAnonymous: true` on Dio for demo tenant headers | Unauthenticated API calls | 0.5 wk | Agent D | Open |
| TD-P2-13 | ~~No denied-access audit on manage guards~~ | Missing security telemetry | — | Agent D | **Resolved v2.7** |
| TD-P2-14 | ~~No audit event categorization~~ | Poor compliance filtering | — | Agent D | **Resolved v2.7** |
| TD-P2-15 | ~~No correlation ID on audit events~~ | Cannot trace request chains | — | Agent D | **Resolved v2.7** |

---

## P3 — Low Priority / Nice-to-Have

| ID | Issue | Impact | Effort | Owner | Status |
|----|-------|--------|--------|-------|--------|
| TD-P3-01 | 11 ERP modules use duplicate KPI row widgets | Visual inconsistency | 1 wk | Agent B | Open |
| TD-P3-02 | No dark mode theme tokens | UX limitation | 2 wks | Agent B | Open |
| TD-P3-03 | Scripts in `scripts/` are one-off migration tools | Clutter | 0.5 d | Agent G | Open |
| TD-P3-04 | `flutter_secure_storage` iOS Keychain accessibility not audited | Edge-case credential access | 0.5 d | Agent D | Open |
| TD-P3-05 | Provider graph not documented per module | Onboarding friction | 1 wk | Agent F | Open |
| TD-P3-06 | No performance benchmarks in CI | Regressions undetected | 2 wks | Agent E | Open |

---

## Debt Paydown Priority (Recommended Order)

1. **v2.8** — OpenAPI staging validation + audit upload backend wiring (TD-P0-02, TD-P1-03, TD-P1-05)
2. **v2.9** — HR + Transport live read APIs (TD-P0-03 partial)
3. **v3.0** — Mobile repository layer (TD-P1-01)
4. **v3.1** — Pagination + virtualized lists (TD-P1-02, TD-P1-13)
5. **v3.2** — Server RBAC/RLS validation (TD-P0-01)
6. **v4.0** — Multi-tenant SaaS production (all P0 cleared)

---

## Update Protocol

After every release, Agent F must:

1. Mark resolved items with release version
2. Add new debt discovered in audit docs
3. Re-prioritize based on production readiness impact
4. Update summary counts at top of this document
