# Staging Validation Checklist

**Version:** 1.0 · **Release:** v4.3  
Use before enabling API flags in staging.

## Tenant Isolation

- [ ] `flutter test test/security/tenant/` — all passing
- [ ] All ERP remote datasources propagate `tenantId` query param
- [ ] Auth/audit modules use shared Dio `TenantInterceptor` headers
- [ ] Mock repos return empty data for unknown tenants
- [ ] Cross-tenant manual smoke: login tenant A, verify no tenant B data

## RBAC

- [ ] `flutter test test/security/rbac/` — all passing
- [ ] Control Center accessible only to Super Admin role
- [ ] Finance admin cannot approve refunds without `approveRefunds`
- [ ] Server permission sync validated against staging `/auth/permissions`
- [ ] **Server-side RBAC/RLS enforced on backend** (required for production)

## Audit

- [ ] `flutter test test/integration/audit/` — all passing
- [ ] Audit batch upload succeeds against staging endpoint
- [ ] Queue drain verified after logout / session events
- [ ] Audit health monitor reports healthy with empty queue

## OpenAPI Contract

- [ ] Run staging gate: `flutter test --dart-define=STAGING_CONTRACT_TESTS=true`
- [ ] Admissions, Finance, SIS dashboards validate against OpenAPI
