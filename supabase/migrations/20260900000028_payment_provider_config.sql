-- W3 Payment Provider Abstraction (Owner decision #7, FINAL · PRA-P0-02)
--
-- Per-school payment-gateway CHOICE. Schools pick their preferred provider; the
-- resolver (payment_provider_registry.ts) reads this table and maps the choice
-- onto a PaymentProvider implementation. When a school has NO row here the
-- resolver defaults to 'razorpay' — so this migration is additive and changes no
-- existing behaviour (an unconfigured estate keeps running Razorpay/stub).
--
-- Only NON-SECRET provider selection lives here. Gateway credentials
-- (RAZORPAY_KEY_ID / _SECRET / _WEBHOOK_SECRET) stay in the edge-function env /
-- secrets vault, NEVER in a tenant-readable table. `settings` carries only
-- non-secret display params (e.g. a manual provider's bank name / account label
-- shown to a parent for an offline transfer).
--
-- FAIL-CLOSED: `enabled=false` means the resolver throws rather than silently
-- falling back to a default gateway a school switched off. The CHECK on
-- `provider` is a DB-level guard that mirrors the code registry; the resolver
-- ALSO fails closed on any id it cannot map, so both layers refuse an unknown
-- provider — neither can turn an unconfigured gateway into a captured payment.
--
-- Migration number 20260900000028 is a free slot in the …015–028 band (…024–026
-- used by sibling W-lane worktrees; …027 reserved); clear of the Data-Reliability
-- / PRC 20260877–20260897 band so a later merge cannot collide.

CREATE TABLE IF NOT EXISTS payment_provider_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- The school's chosen provider id. Matches PaymentProvider.id AND
  -- payment_intents.gateway. DB-level guard mirrors the code registry; keep the
  -- two in sync when adding a provider.
  provider TEXT NOT NULL DEFAULT 'razorpay'
    CHECK (provider IN ('razorpay', 'manual')),
  -- FALSE = online payments switched off for this school (resolver fails closed).
  enabled BOOLEAN NOT NULL DEFAULT true,
  -- Non-secret display / routing params only. NEVER gateway credentials.
  settings JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- One provider choice per school.
  UNIQUE (organization_id, school_id)
);

CREATE TRIGGER payment_provider_config_updated_at
  BEFORE UPDATE ON payment_provider_config
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE payment_provider_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_provider_config FORCE ROW LEVEL SECURITY;

-- READ: a parent initiating a payment resolves the provider under PARENT scope,
-- and the webhook/admin paths read under SCHOOL scope. Both (same org+school)
-- may read; organization scope may read across its schools. Read-only config.
CREATE POLICY payment_provider_config_read ON payment_provider_config
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND (
      (app_current_scope() = 'parent' AND school_id = app_current_school_id())
      OR (app_current_scope() = 'school' AND school_id = app_current_school_id())
      OR app_current_scope() = 'organization'
    )
  );

-- MANAGE: only school scope (school admin / manageFinance) configures its own
-- school's provider choice.
CREATE POLICY payment_provider_config_manage ON payment_provider_config
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON payment_provider_config TO erp_tenant;
