-- PRC-A Batch 6 — Communication Channel Orchestrator: WhatsApp as a first-class
-- channel + per-school escalation/fallback (owner-future-idea 24).
--
-- The audit found: a real WhatsApp provider (msg91/gupshup) already exists in
-- school_completion/whatsapp_providers.ts, but it is STRANDED — the canonical
-- notification pipeline (`notification_deliveries` queue + processDeliveryQueue
-- drain, which every broadcast/report/read-tracking keys off) only accepts
-- 'sms'|'email'|'push'. WhatsApp was reachable ONLY through a synchronous
-- school_completion bridge that writes to a SEPARATE analytics table
-- (communication_delivery_events), never the real ledger — no queue, no retry,
-- no fallback. There is also NO escalation policy anywhere.
--
-- DESIGN — reuse, never duplicate:
--   * WhatsApp becomes a real value of NotificationChannel; the drain routes it
--     to the EXISTING sendWhatsAppMessage provider with the EXISTING per-school
--     whatsapp_provider_configs. No new provider, no new send code.
--   * Escalation is a per-school ORDERED channel chain. When a delivery fails
--     TERMINALLY (retries exhausted, status→'failed'), the drain enqueues a
--     fresh delivery on the NEXT channel in the chain after the failed one,
--     linked by escalated_from and bounded by escalation_depth (< chain length,
--     so it always terminates). No policy row → NO escalation: existing
--     behaviour is preserved byte-for-byte (backward compatible).
--   * WhatsApp ships effectively dark: an unconfigured school's provider is
--     'stub' → sendWhatsAppMessage returns success:false ("not configured"),
--     never a fabricated "sent" (GAP-P1-9). Configuring msg91/gupshup activates
--     it — the config IS the gate, no extra feature flag.

-- ─── 1. WhatsApp is now a first-class channel ────────────────────────────────
ALTER TABLE notification_templates
  DROP CONSTRAINT notification_templates_channel_check;
ALTER TABLE notification_templates
  ADD CONSTRAINT notification_templates_channel_check
    CHECK (channel IN ('sms', 'email', 'push', 'whatsapp'));

ALTER TABLE notification_deliveries
  DROP CONSTRAINT notification_deliveries_channel_check;
ALTER TABLE notification_deliveries
  ADD CONSTRAINT notification_deliveries_channel_check
    CHECK (channel IN ('sms', 'email', 'push', 'whatsapp'));

-- ─── 2. Escalation provenance on the delivery ledger ─────────────────────────
-- escalated_from: the delivery whose terminal failure spawned this one (NULL for
-- a primary send). A self-referential audit trail, not a mutable counter.
-- escalation_depth: hop count from the primary (0 = primary). The drain refuses
-- to escalate at depth >= chain length, so the chain is a hard loop bound.
ALTER TABLE notification_deliveries
  ADD COLUMN IF NOT EXISTS escalated_from UUID REFERENCES notification_deliveries (id);
ALTER TABLE notification_deliveries
  ADD COLUMN IF NOT EXISTS escalation_depth INTEGER NOT NULL DEFAULT 0;

-- ─── 3. Per-school escalation policy ─────────────────────────────────────────
-- One ordered chain per school. escalation_chain is an ORDERED list of channels;
-- on a channel's terminal failure the drain moves to the element AFTER it. The
-- containment CHECK keeps the chain within the known channel vocabulary so a
-- typo can never enqueue an un-routable delivery. is_active=false disables
-- escalation without deleting the configured chain.
CREATE TABLE communication_channel_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  escalation_chain TEXT[] NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT communication_channel_policies_chain_nonempty
    CHECK (array_length(escalation_chain, 1) >= 1),
  CONSTRAINT communication_channel_policies_chain_vocab
    CHECK (escalation_chain <@ ARRAY['sms', 'email', 'push', 'whatsapp']::text[])
);

CREATE UNIQUE INDEX idx_communication_channel_policies_school
  ON communication_channel_policies (organization_id, school_id);

CREATE TRIGGER communication_channel_policies_updated_at
  BEFORE UPDATE ON communication_channel_policies FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE communication_channel_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_channel_policies FORCE ROW LEVEL SECURITY;

-- School-scoped manage, mirroring notification_deliveries_school_manage: a school
-- session sees and edits only its own school's policy; cross-school/cross-tenant
-- rows are invisible.
CREATE POLICY communication_channel_policies_school_manage ON communication_channel_policies
  FOR ALL USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  ) WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

-- No DELETE: a policy is retired via is_active=false, keeping the configured
-- chain as an audit record (consistent with the append-only bias across PRC-A).
GRANT SELECT, INSERT, UPDATE ON communication_channel_policies TO erp_tenant;

-- ─── 4. RBAC ─────────────────────────────────────────────────────────────────
-- Reuse the EXISTING manageCommunications permission (already guards template
-- management + the delivery-queue processor) — the channel policy is the same
-- communication-admin concern, so no new permission is minted.
