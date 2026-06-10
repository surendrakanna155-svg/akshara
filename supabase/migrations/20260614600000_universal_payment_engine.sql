-- v7.0 Universal Payment Engine — Razorpay lifecycle tables

CREATE TABLE payment_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  student_id UUID NOT NULL,
  payer_user_id UUID NOT NULL,
  source_type TEXT NOT NULL,
  source_id TEXT NOT NULL,
  invoice_id UUID REFERENCES finance_invoices (id),
  amount INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  status TEXT NOT NULL DEFAULT 'pending',
  idempotency_key TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT payment_requests_status_check CHECK (
    status IN ('pending', 'initiated', 'captured', 'failed', 'cancelled')
  )
);

CREATE UNIQUE INDEX idx_payment_requests_source
  ON payment_requests (organization_id, source_type, source_id, payer_user_id);

CREATE UNIQUE INDEX idx_payment_requests_idempotency
  ON payment_requests (organization_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE TABLE payment_intents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  request_id UUID NOT NULL REFERENCES payment_requests (id),
  payer_user_id UUID NOT NULL,
  gateway TEXT NOT NULL DEFAULT 'razorpay',
  gateway_order_id TEXT,
  gateway_payment_id TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  amount INTEGER NOT NULL,
  payment_method TEXT,
  invoice_id UUID REFERENCES finance_invoices (id),
  collection_id UUID REFERENCES finance_collections (id),
  receipt_id UUID REFERENCES finance_receipts (id),
  refund_id UUID REFERENCES finance_refunds (id),
  idempotency_key TEXT,
  transaction_ref TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT payment_intents_status_check CHECK (
    status IN ('pending', 'initiated', 'authorized', 'captured', 'settled', 'failed', 'cancelled')
  )
);

CREATE UNIQUE INDEX idx_payment_intents_idempotency
  ON payment_intents (organization_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX idx_payment_intents_payer ON payment_intents (organization_id, payer_user_id, status);

CREATE TABLE payment_webhook_events (
  id TEXT PRIMARY KEY,
  organization_id UUID REFERENCES organizations (id),
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  processed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE TRIGGER payment_requests_updated_at
  BEFORE UPDATE ON payment_requests FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER payment_intents_updated_at
  BEFORE UPDATE ON payment_intents FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE payment_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_intents FORCE ROW LEVEL SECURITY;
ALTER TABLE payment_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_webhook_events FORCE ROW LEVEL SECURITY;

CREATE POLICY payment_requests_parent_scope ON payment_requests
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND payer_user_id = app_current_user_id()
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND payer_user_id = app_current_user_id()
    AND school_id = app_current_school_id()
  );

CREATE POLICY payment_requests_school_read ON payment_requests
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

CREATE POLICY payment_intents_parent_scope ON payment_intents
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND payer_user_id = app_current_user_id()
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    AND payer_user_id = app_current_user_id()
    AND school_id = app_current_school_id()
  );

CREATE POLICY payment_intents_school_read ON payment_intents
  FOR SELECT USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

CREATE POLICY payment_webhook_events_service ON payment_webhook_events
  FOR ALL USING (app_current_scope() IN ('school', 'organization'));

GRANT SELECT, INSERT, UPDATE ON payment_requests TO erp_tenant;
GRANT SELECT, INSERT, UPDATE ON payment_intents TO erp_tenant;
GRANT SELECT, INSERT ON payment_webhook_events TO erp_tenant;

-- Seed payment request for parent fee installment term_2 → School A invoice
INSERT INTO payment_requests (
  id, organization_id, school_id, student_id, payer_user_id,
  source_type, source_id, invoice_id, amount, status
) VALUES (
  'd0000000-0000-4000-8000-000000000010',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'a4000000-0000-4000-8000-000000000001',
  'a3000000-0000-4000-8000-000000000003',
  'fee_installment',
  'term_2',
  'b9000000-0000-4000-8000-000000000001',
  4200,
  'pending'
);

INSERT INTO payment_intents (
  id, organization_id, school_id, request_id, payer_user_id,
  gateway_order_id, status, amount, payment_method, invoice_id,
  idempotency_key, metadata
) VALUES (
  'd0000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000001',
  'd0000000-0000-4000-8000-000000000010',
  'a3000000-0000-4000-8000-000000000003',
  'order_probe_a',
  'initiated',
  4200,
  'upi',
  'b9000000-0000-4000-8000-000000000001',
  'probe.payment.intent.a',
  '{"label":"Payment Probe A"}'::jsonb
);

INSERT INTO payment_requests (
  id, organization_id, school_id, student_id, payer_user_id,
  source_type, source_id, amount, status
) VALUES (
  'd0000000-0000-4000-8000-000000000011',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'a4000000-0000-4000-8000-000000000002',
  'a3000000-0000-4000-8000-000000000003',
  'fee_installment',
  'term_2_b',
  4200,
  'pending'
);

INSERT INTO payment_intents (
  id, organization_id, school_id, request_id, payer_user_id,
  gateway_order_id, status, amount, payment_method, invoice_id,
  idempotency_key, metadata
) VALUES (
  'd0000000-0000-4000-8000-000000000002',
  'a1000000-0000-4000-8000-000000000001',
  'a2000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000011',
  'a3000000-0000-4000-8000-000000000003',
  'order_probe_b',
  'initiated',
  4200,
  'upi',
  NULL,
  'probe.payment.intent.b',
  '{"label":"Payment Probe B"}'::jsonb
);
