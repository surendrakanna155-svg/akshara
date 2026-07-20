-- PRC-A Batch 3 — AI credit wallet (caps 37–43), owner decision #3.
--
-- OWNER LAW: "BUILD, but reconcile into ONE coherent model with the existing
-- spend-cap governance / entitlements / quotas / AI call logging / reservations.
-- No second competing quota system. Product usage units, NOT currency semantics.
-- Reservation/commit/release correctness; no double-consumption, negative-balance
-- races, or retry duplication."
--
-- HOW THAT IS HONOURED HERE — this migration deliberately adds NO new counter,
-- NO new gate, and NO second cap resolver. The AI domain already has exactly one
-- physical ledger (`ai_call_log`) and one atomic admission primitive
-- (`ai_call_reservations`, reserve → consumed | released). The wallet is a
-- PROJECTION over that same pair:
--
--     balance = SUM(ai_credit_entries.units)          -- what was granted
--             - SUM(ai_call_log.credits_debited)       -- what was committed
--             - SUM(pending ai_call_reservations.credits_reserved)  -- in flight
--
-- One grant source, one debit source, one in-flight source — all reconcilable
-- from rows that already exist. `ai_economics_service` / `ai_copilot_quota` own
-- no state (they are read-models over ai_call_log) and are untouched.
--
-- ENTITLEMENTS ARE THE WRONG AXIS and are deliberately NOT used: that system is a
-- headcount capacity-slab model (`LimitKind = students|schools`, plan columns +
-- named ResolvedSubscription fields). Consumable AI usage is a different axis and
-- already lives entirely in the ai_* tables. Routing the wallet through
-- entitlements would BE the "second competing quota system" the owner forbade.
--
-- UNITS, NOT CURRENCY: every column here is BIGINT integer "credits". The AI
-- domain's existing convention is integer micro-units (`estimated_cost_micros
-- BIGINT` + Math.trunc at every write boundary) — NOT the finance domain's
-- NUMERIC(12,2) currency. `credits_debited` sits ALONGSIDE
-- `estimated_cost_micros`, never replacing it, so provider-cost governance and
-- the purchased wallet stay independently reconcilable from ONE row.

-- ─── Grants: the only source of credit ───────────────────────────────────────
-- Append-only and signed: a top-up is positive, a correction/expiry is negative.
-- There is no UPDATE/DELETE grant — a wallet ledger that can be silently rewritten
-- is not a ledger. Reversing a mistake means writing a compensating row, which
-- keeps the audit trail intact.
CREATE TABLE ai_credit_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  -- Credits are purchased by the ORGANISATION, not per school: ai_call_log.school_id
  -- is nullable precisely because org-scoped surfaces (director / org-builder /
  -- onboarding) make AI calls with no school. A school-scoped wallet could not
  -- account for those calls at all.
  entry_type TEXT NOT NULL
    CHECK (entry_type IN ('top_up', 'adjustment', 'expiry')),
  units BIGINT NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  -- Provenance: who granted/adjusted, and the external reference (invoice/PO) if
  -- this was a purchase. Cap 43 (admin credit adjustment) is auditable or it is
  -- not a control.
  actor_id UUID,
  external_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- A top-up must add credit; an expiry must remove it. An 'adjustment' may go
  -- either way (that is its purpose) but may never be a no-op.
  CONSTRAINT ai_credit_entries_units_sign_check CHECK (
    (entry_type = 'top_up' AND units > 0)
    OR (entry_type = 'expiry' AND units < 0)
    OR (entry_type = 'adjustment' AND units <> 0)
  )
);

-- The balance projection reads every row for an org; this is the covering index.
CREATE INDEX idx_ai_credit_entries_org
  ON ai_credit_entries (organization_id, created_at DESC);

ALTER TABLE ai_credit_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_credit_entries FORCE ROW LEVEL SECURITY;

-- Org-wall read. Mirrors ai_call_reservations' org-scope policy: the wallet is an
-- org-level fact, and a school-scoped session still needs to read its own org's
-- balance for the gateway admit check to work at all.
CREATE POLICY ai_credit_entries_tenant_read ON ai_credit_entries
  FOR SELECT
  USING (organization_id = app_current_tenant_id());

-- INSERT is granted so a platform handler can write a top-up through the normal
-- tenant path. The RBAC gate (manageAiCredits) is the real control; this policy
-- is the tenant backstop.
CREATE POLICY ai_credit_entries_tenant_insert ON ai_credit_entries
  FOR INSERT
  WITH CHECK (organization_id = app_current_tenant_id());

-- SELECT, INSERT only — deliberately no UPDATE/DELETE. See the table comment.
GRANT SELECT, INSERT ON ai_credit_entries TO erp_tenant;

-- ─── Debits: an additive column on the EXISTING ledger ───────────────────────
-- Populated in the SAME INSERT as the call it records (recordAiCall), which is
-- itself savepointed. A debit written as a separate best-effort statement could
-- be lost after the call was served → served-but-undebited → free usage. Riding
-- the same statement makes debit and call atomically inseparable.
ALTER TABLE ai_call_log
  ADD COLUMN IF NOT EXISTS credits_debited BIGINT NOT NULL DEFAULT 0
    CHECK (credits_debited >= 0);

-- ─── In-flight: an additive column on the EXISTING reservation ───────────────
-- Reserve → consume|release already gives exactly-once accounting under
-- concurrency (single INSERT..SELECT admit under a pg_advisory_xact_lock, then a
-- status-guarded settle). Hanging reserved units on that same row means the
-- wallet inherits it rather than re-inventing it — and the existing 2-minute
-- PENDING_TTL sweep releases abandoned holds for free.
ALTER TABLE ai_call_reservations
  ADD COLUMN IF NOT EXISTS credits_reserved BIGINT NOT NULL DEFAULT 0
    CHECK (credits_reserved >= 0);

-- ─── Telemetry: name the new denial honestly ─────────────────────────────────
-- A wallet-denied call is NOT the same event as a spend-cap denial: one means the
-- school ran out of what it bought, the other means WE hit our own cost
-- governance. Collapsing them would make the cost panel lie about why users were
-- refused. Additive widen, exactly like 20260870.
ALTER TABLE ai_call_log DROP CONSTRAINT IF EXISTS ai_call_log_outcome_check;

ALTER TABLE ai_call_log ADD CONSTRAINT ai_call_log_outcome_check
  CHECK (outcome IN (
    'ok',
    'refused',
    'fallback_no_key',
    'fallback_rate_user',
    'fallback_rate_school',
    'fallback_spend_cap',
    'fallback_timeout',
    'fallback_error',
    'fallback_guard',
    'fallback_wallet_empty'
  ));

-- ─── RBAC ────────────────────────────────────────────────────────────────────
-- Granting credit is a PLATFORM act (we sell them), not something a school can do
-- for itself — otherwise the wallet is decorative. Viewing the balance is an org
-- concern (they need to know what they have left).
INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewAiWallet', 'AI', 'view', 'organization', 'View the organisation''s AI credit balance and ledger'),
  ('manageAiCredits', 'AI', 'manage', 'platform', 'Grant, adjust or expire an organisation''s AI credits (platform-only)')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'viewAiWallet'
FROM role_definitions rd
WHERE rd.slug IN (
  'superAdmin', 'organizationOwner', 'organizationAdmin', 'management'
)
ON CONFLICT DO NOTHING;

-- Platform-only. Deliberately NOT organizationOwner/organizationAdmin: a tenant
-- topping up its own wallet at will is the same as having no wallet.
INSERT INTO role_permissions (role_slug, permission_slug)
SELECT rd.slug, 'manageAiCredits'
FROM role_definitions rd
WHERE rd.slug IN ('superAdmin')
ON CONFLICT DO NOTHING;
