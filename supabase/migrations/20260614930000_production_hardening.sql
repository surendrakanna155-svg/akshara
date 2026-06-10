-- v7.3 Production hardening — domain event retries + webhook metadata

ALTER TABLE domain_events
  ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_error TEXT;

CREATE INDEX IF NOT EXISTS idx_domain_events_retry
  ON domain_events (organization_id, status, next_retry_at)
  WHERE status IN ('pending', 'failed');

ALTER TABLE payment_webhook_events
  ADD COLUMN IF NOT EXISTS resolved_organization_id UUID REFERENCES organizations (id),
  ADD COLUMN IF NOT EXISTS resolved_school_id UUID REFERENCES schools (id);
