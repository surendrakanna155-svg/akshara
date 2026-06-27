# Legal Acceptance — Implementation Roadmap

This tracks the code that backs the in-app legal acceptance gate, what is done, and
what remains (mostly owner-gated). The gate is **fail-open**: it ships safely even
before the backend is deployed (users are never blocked unless the backend
positively reports outstanding policies).

## Done (this batch)

### Backend (Supabase / Deno)
- **Migration** `supabase/migrations/20260816000000_legal_policy_acceptance.sql` —
  `legal_acceptances` append-only table (org, school, user, role, scope, policy
  key/version, timestamp, IP, user-agent, device), RLS scoped to tenant + user,
  `GRANT SELECT, INSERT … TO erp_tenant`.
- **Catalog** `_shared/legal/legal_catalog.ts` — policy keys/versions + per-role
  required-policy logic + outstanding computation (the single source of truth for
  versions; keep in sync with the document headers and `CHANGELOG.md`).
- **Repository / handlers / router** `_shared/legal/legal_repository.ts`,
  `legal_handlers.ts`, `legal_router.ts` — `GET /legal/status`, `POST /legal/accept`
  (authenticated; records IP/device; emits audit + domain events).
- **Audit** `legalAudit.policyAccepted` added to `_shared/audit/mutation_audit_catalog.ts`.
- **Wiring** `routeLegal` registered in `api/index.ts`.
- **Tests** `_shared/legal/legal_catalog_test.ts` (8 tests, green); `deno check` clean.

### Flutter (client)
- **Feature** `lib/features/legal/` — models, remote data source, gate
  controller/providers (fail-open), and the `LegalAcceptanceScreen` (enforcement +
  review modes).
- **Routing** `RouteNames.legalAcceptance`; `legalGateRedirect()` chained after
  `_authRedirect` in `lib/router/app_router.dart`; `goRouterProvider` passes
  `readLegalBlocked` and wires `legalGateSyncProvider`; `RouterRefreshNotifier`
  listens to the gate.
- **Links** `lib/core/legal/legal_links.dart` extended to resolve any policy path
  against the configured host.
- **Profile** "Terms & Policies" review entry added to parent and teacher profiles.
- **Tests** `test/features/legal/legal_gate_test.dart` (14 tests, green) — proves the
  first-time gate, the accept→satisfied transition, fail-open, and the end-to-end
  router redirect. Full `flutter analyze` clean.

## Remaining — owner-gated (NOT release blockers for the app build itself)

1. **Fill placeholders** — complete every value in [PLACEHOLDERS.md](PLACEHOLDERS.md)
   and replace the bracketed tokens across `docs/legal/`.
2. **Legal review** — have a qualified lawyer review the document set before public
   release.
3. **Host the documents** — publish each policy at a public HTTPS URL under the
   configured host (`LegalLinks.policyHostBaseUrl`), matching the catalog `path`
   values (`/privacy`, `/terms/user`, `/terms/acceptable-use`, `/terms/institution`).
   The Privacy Policy URL must also match the Play Console field.
4. **Deploy the backend** — apply the migration and deploy the edge function to the
   VPS so `GET /legal/status` returns data. Until then the gate stays fail-open
   (no enforcement, no breakage). After deploy, the gate activates automatically.

## Optional follow-ups (small)

- Add the "Terms & Policies" review entry to the remaining role profiles
  (student/staff/director shells) — a one-line navigation row each.
- When the law requires stronger parental-identity verification (DPDP Rule 10),
  integrate a DigiLocker-style check; the catalog/flow are structured to extend.
