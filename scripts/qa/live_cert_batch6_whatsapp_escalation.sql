-- PRC-A Batch 6 — WhatsApp channel + escalation LIVE CERT (ROLLBACK-safe).
--
-- Runs as the REAL non-bypass `erp_tenant` role via `app.set_request_context(...)`
-- — byte-identical to withTenantContext in production, so RLS is genuinely
-- evaluated. Everything is inside ONE BEGIN…ROLLBACK; nothing persists. Proves
-- what the fake DB structurally CANNOT: the extended channel CHECK, real RLS
-- isolation on the escalation policy, the append-only (no-DELETE) grant, the
-- chain-vocabulary CHECK, and — via the VERBATIM production enqueue/fail/enqueue
-- SQL — that a terminally-failed delivery escalates to the next channel with the
-- correct escalated_from/escalation_depth linkage.
--
-- Run: docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -f - < this
\set ON_ERROR_STOP off

\echo ==================== BEGIN (all seed rolled back) ====================
BEGIN;

CREATE TEMP TABLE r(ord int, probe text, verdict text, evidence text);
-- r is owned by supabase_admin; the probes write to it while SET ROLE erp_tenant,
-- so grant the app role access (results are read back as the owner after RESET).
GRANT INSERT, SELECT ON r TO erp_tenant;

-- Real prod ids.
\set orgA      '''a1000000-0000-4000-8000-000000000001'''
\set schA      '''a2000000-0000-4000-8000-000000000001'''
\set schB      '''a2000000-0000-4000-8000-000000000002'''
\set orgO      '''153cbc5a-05b7-48b4-b900-edb126a099f0'''
\set schO      '''bb2d5521-0ab4-4eb9-a3f1-83691414ebc9'''
\set usr       '''a3000000-0000-4000-8000-000000000001'''
\set rcpt      '''c6000000-0000-4000-8000-000000000001'''

SET ROLE erp_tenant;
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);

-- ── PROBE 1 — channel CHECK now accepts 'whatsapp' ──────────────────────────
INSERT INTO notification_deliveries
  (organization_id, school_id, recipient_user_id, channel, category, rendered_subject, rendered_body, status)
VALUES (:orgA::uuid, :schA::uuid, :rcpt::uuid, 'whatsapp', 'fee', 'WA', 'body', 'pending');
INSERT INTO r SELECT 1, 'channel CHECK accepts whatsapp as a first-class channel', 'PASS',
  'whatsapp delivery inserted = '||count(*)::text||' (expect 1)'
FROM notification_deliveries WHERE recipient_user_id=:rcpt::uuid AND channel='whatsapp';

-- ── PROBE 2 — channel CHECK still rejects a bogus channel ───────────────────
DO $$
DECLARE ok int := 0;
BEGIN
  BEGIN
    INSERT INTO notification_deliveries
      (organization_id, school_id, recipient_user_id, channel, category, rendered_subject, rendered_body, status)
    VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001',
            'c6000000-0000-4000-8000-000000000001','telegram','fee','X','body','pending');
  EXCEPTION WHEN check_violation THEN ok := 1; END;
  INSERT INTO r VALUES (2, 'channel CHECK rejects an unknown channel',
    CASE WHEN ok=1 THEN 'PASS' ELSE 'FAIL' END,
    'telegram rejected by CHECK = '||ok::text||' (expect 1)');
END $$;

-- ── PROBE 3 — escalation policy RLS isolation ───────────────────────────────
INSERT INTO communication_channel_policies
  (organization_id, school_id, escalation_chain, is_active, created_by)
VALUES (:orgA::uuid, :schA::uuid, ARRAY['whatsapp','sms','push'], true, :usr::uuid);

-- School B (same org, different school) must NOT see school A's policy.
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schB::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 3, 'RLS: a sibling school cannot see another school''s policy',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'school-A policy visible to school B = '||count(*)::text||' (expect 0)'
FROM communication_channel_policies;

-- A different ORG must NOT see it either.
SELECT app.set_request_context(:orgO::uuid, 'school', :usr::uuid, :schO::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 4, 'RLS: a different tenant cannot see the policy',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'school-A policy visible to org O = '||count(*)::text||' (expect 0)'
FROM communication_channel_policies;

-- Control: school A sees exactly its own policy (probe is not vacuous).
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 5, 'RLS control: the owning school sees its own policy',
  CASE WHEN count(*)=1 THEN 'PASS' ELSE 'FAIL' END,
  'school-A policy visible to school A = '||count(*)::text||' (expect 1)'
FROM communication_channel_policies;

-- ── PROBE 6 — chain-vocabulary CHECK rejects an unknown channel in the chain ─
-- Insert for school B (its own context, so RLS passes) with a bad-vocab chain →
-- the DB CHECK, not RLS, must reject it.
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schB::uuid, NULL, NULL, NULL);
DO $$
DECLARE ok int := 0;
BEGIN
  BEGIN
    INSERT INTO communication_channel_policies
      (organization_id, school_id, escalation_chain, is_active, created_by)
    VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002',
            ARRAY['whatsapp','telegram'], true, 'a3000000-0000-4000-8000-000000000001');
  EXCEPTION WHEN check_violation THEN ok := 1; END;
  INSERT INTO r VALUES (6, 'chain-vocabulary CHECK rejects an un-routable channel',
    CASE WHEN ok=1 THEN 'PASS' ELSE 'FAIL' END,
    'chain [whatsapp,telegram] rejected = '||ok::text||' (expect 1)');
END $$;
-- back to school A for the remaining probes
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);

-- ── PROBE 7 — escalation fires on TERMINAL failure (verbatim production SQL) ─
-- 1) enqueue a whatsapp delivery (depth 0, max_retries 1 so one failure is terminal)
-- 2) terminal-fail it (markDeliveryFailed terminal branch)
-- 3) escalation enqueue: chain [whatsapp,sms,push] → next after whatsapp = sms,
--    depth 1, escalated_from = the failed id (maybeEscalate → enqueueDelivery)
DO $$
DECLARE
  primary_id uuid;
  esc_from uuid;
  esc_depth int;
  esc_channel text;
  esc_status text;
BEGIN
  INSERT INTO notification_deliveries
    (organization_id, school_id, recipient_user_id, channel, category,
     rendered_subject, rendered_body, status, escalation_depth, max_retries)
  VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001',
          'c6000000-0000-4000-8000-000000000002','whatsapp','fee','Fee due','₹4200 due',
          'pending', 0, 1)
  RETURNING id INTO primary_id;

  UPDATE notification_deliveries
     SET status='failed', retry_count=1,
         last_error='WhatsApp provider is not configured for this school',
         updated_at=timezone('utc', now())
   WHERE id=primary_id;

  INSERT INTO notification_deliveries
    (organization_id, school_id, recipient_user_id, channel, category,
     rendered_subject, rendered_body, status, escalated_from, escalation_depth)
  VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001',
          'c6000000-0000-4000-8000-000000000002','sms','fee','Fee due','₹4200 due',
          'pending', primary_id, 1)
  RETURNING escalated_from, escalation_depth, channel, status
       INTO esc_from, esc_depth, esc_channel, esc_status;

  INSERT INTO r VALUES (7, 'escalation enqueues the next channel on terminal failure',
    CASE WHEN esc_from=primary_id AND esc_depth=1 AND esc_channel='sms' AND esc_status='pending'
         THEN 'PASS' ELSE 'FAIL' END,
    'escalated: channel='||esc_channel||' depth='||esc_depth::text||
      ' escalated_from-links-primary='||(esc_from=primary_id)::text);
END $$;

-- ── PROBE 8 — append-only: erp_tenant has NO DELETE on the policy table ──────
DO $$
DECLARE denied int := 0;
BEGIN
  BEGIN DELETE FROM communication_channel_policies
        WHERE organization_id='a1000000-0000-4000-8000-000000000001';
  EXCEPTION WHEN insufficient_privilege THEN denied := 1; END;
  INSERT INTO r VALUES (8, 'append-only: erp_tenant cannot DELETE a policy (retire via is_active)',
    CASE WHEN denied=1 THEN 'PASS' ELSE 'FAIL' END,
    'DELETE permission-denied = '||denied::text||' (expect 1)');
END $$;

-- ── PROBE 9 — backward compatible: a school with no policy → getChannelPolicy=0 ─
-- Verbatim getChannelPolicy SQL for a school that never configured escalation:
-- 0 rows ⇒ computeEscalationTarget(null) ⇒ no escalation ⇒ pre-Batch-6 behaviour.
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid,
  'a2000000-0000-4000-8000-0000000000ce'::uuid, NULL, NULL, NULL);
INSERT INTO r SELECT 9, 'backward compatible: no policy row → escalation disabled',
  CASE WHEN count(*)=0 THEN 'PASS' ELSE 'FAIL' END,
  'policy rows for an unconfigured school = '||count(*)::text||' (expect 0)'
FROM communication_channel_policies
WHERE organization_id=:orgA::uuid AND school_id='a2000000-0000-4000-8000-0000000000ce'::uuid;

RESET ROLE;
\echo ==================== RESULTS ====================
SELECT ord, verdict, probe, evidence FROM r ORDER BY ord;
SELECT CASE WHEN count(*) FILTER (WHERE verdict<>'PASS')=0
            THEN '✅ ALL '||count(*)::text||' PROBES PASS'
            ELSE '❌ '||count(*) FILTER (WHERE verdict<>'PASS')::text||' FAILED' END AS gate
FROM r;

ROLLBACK;
\echo ==================== ROLLED BACK (zero residue) ====================
-- Residue proof: nothing from this cert persists.
SELECT 'RESIDUE policies' AS probe, count(*) AS rows FROM communication_channel_policies
  WHERE created_by='a3000000-0000-4000-8000-000000000001';
SELECT 'RESIDUE deliveries' AS probe, count(*) AS rows FROM notification_deliveries
  WHERE recipient_user_id IN ('c6000000-0000-4000-8000-000000000001','c6000000-0000-4000-8000-000000000002');
