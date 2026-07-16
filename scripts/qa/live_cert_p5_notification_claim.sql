-- PRC P5 (red-team #1) — notification delivery CLAIM concurrency LIVE CERT.
-- ROLLBACK-safe, as the real erp_tenant role. Proves the exactly-once claim +
-- the status-guarded marks that stop double-send / double-escalation.
--
-- Run: docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -f - < this
\set ON_ERROR_STOP off

\echo ==================== BEGIN (all seed rolled back) ====================
BEGIN;
CREATE TEMP TABLE r(ord int, probe text, verdict text, evidence text);
GRANT INSERT, SELECT ON r TO erp_tenant;

\set orgA '''a1000000-0000-4000-8000-000000000001'''
\set schA '''a2000000-0000-4000-8000-000000000001'''
\set usr  '''a3000000-0000-4000-8000-000000000001'''

SET ROLE erp_tenant;
SELECT app.set_request_context(:orgA::uuid, 'school', :usr::uuid, :schA::uuid, NULL, NULL, NULL);

-- Seed 4 pending deliveries (recipients d7…01..04), one with max_retries=1 for the terminal test.
INSERT INTO notification_deliveries (organization_id, school_id, recipient_user_id, channel, category, rendered_body, status, max_retries) VALUES
 (:orgA::uuid, :schA::uuid, 'd7000000-0000-4000-8000-000000000001', 'push', 'x', 'b', 'pending', 3),
 (:orgA::uuid, :schA::uuid, 'd7000000-0000-4000-8000-000000000002', 'push', 'x', 'b', 'pending', 3),
 (:orgA::uuid, :schA::uuid, 'd7000000-0000-4000-8000-000000000003', 'push', 'x', 'b', 'pending', 3),
 (:orgA::uuid, :schA::uuid, 'd7000000-0000-4000-8000-000000000004', 'push', 'x', 'b', 'pending', 1);

-- ── PROBE 1 — claim #1 grabs all 4 due rows and flips them to 'sending' ──────
WITH c AS (
  UPDATE notification_deliveries SET status='sending', updated_at=timezone('utc',now())
   WHERE id IN (
     SELECT id FROM notification_deliveries
      WHERE organization_id=:orgA::uuid
        AND ((status='pending' AND (next_retry_at IS NULL OR next_retry_at<=timezone('utc',now())))
             OR (status='sending' AND updated_at < timezone('utc',now()) - ('10 minutes')::interval))
        AND recipient_user_id::text LIKE 'd7000000%'
      ORDER BY created_at LIMIT 50 FOR UPDATE SKIP LOCKED)
   RETURNING 1
)
INSERT INTO r
SELECT 1, 'a drain CLAIMS the due deliveries (pending → sending) via the atomic claim',
  CASE WHEN cnt = 4 THEN 'PASS' ELSE 'FAIL' END,
  'claim #1 grabbed = '||cnt::text||' rows (expect 4)'
FROM (SELECT count(*) AS cnt FROM c) x;

-- ── PROBE 2 — a concurrent second drain claims ZERO of the same rows (exactly-once) ──
WITH c AS (
  UPDATE notification_deliveries SET status='sending', updated_at=timezone('utc',now())
   WHERE id IN (
     SELECT id FROM notification_deliveries
      WHERE organization_id=:orgA::uuid
        AND ((status='pending' AND (next_retry_at IS NULL OR next_retry_at<=timezone('utc',now())))
             OR (status='sending' AND updated_at < timezone('utc',now()) - ('10 minutes')::interval))
        AND recipient_user_id::text LIKE 'd7000000%'
      ORDER BY created_at LIMIT 50 FOR UPDATE SKIP LOCKED)
   RETURNING 1
)
INSERT INTO r
SELECT 2, 'a second concurrent drain claims NONE of the already-claimed rows (exactly-once)',
  CASE WHEN cnt = 0 THEN 'PASS' ELSE 'FAIL' END,
  'claim #2 grabbed = '||cnt::text||' rows (expect 0 — all now sending, none pending)'
FROM (SELECT count(*) AS cnt FROM c) x;

-- ── PROBE 3 — markDeliverySent is guarded: sends once, a repeat is a no-op ───
DO $$
DECLARE tgt uuid; first_mark int; second_mark int;
BEGIN
  SELECT id INTO tgt FROM notification_deliveries
   WHERE organization_id='a1000000-0000-4000-8000-000000000001'
     AND recipient_user_id='d7000000-0000-4000-8000-000000000001';
  WITH m AS (UPDATE notification_deliveries SET status='sent', sent_at=timezone('utc',now())
              WHERE id=tgt AND status='sending' RETURNING 1) SELECT count(*) INTO first_mark FROM m;
  WITH m AS (UPDATE notification_deliveries SET status='sent'
              WHERE id=tgt AND status='sending' RETURNING 1) SELECT count(*) INTO second_mark FROM m;
  INSERT INTO r VALUES (3, 'markDeliverySent guard: exactly one mark wins, the repeat is a no-op',
    CASE WHEN first_mark=1 AND second_mark=0 THEN 'PASS' ELSE 'FAIL' END,
    'first mark='||first_mark::text||' second='||second_mark::text||' (expect 1 then 0)');
END $$;

-- ── PROBE 4 — terminal failure fires ONCE → escalation can't double-fire ─────
DO $$
DECLARE tgt uuid; first_term int; second_term int;
BEGIN
  SELECT id INTO tgt FROM notification_deliveries
   WHERE organization_id='a1000000-0000-4000-8000-000000000001'
     AND recipient_user_id='d7000000-0000-4000-8000-000000000004';  -- max_retries=1
  WITH m AS (UPDATE notification_deliveries SET status='failed', retry_count=1, last_error='x'
              WHERE id=tgt AND status='sending' RETURNING id) SELECT count(*) INTO first_term FROM m;
  WITH m AS (UPDATE notification_deliveries SET status='failed', retry_count=2, last_error='x'
              WHERE id=tgt AND status='sending' RETURNING id) SELECT count(*) INTO second_term FROM m;
  INSERT INTO r VALUES (4, 'terminal transition fires ONCE (escalation cannot double-fire)',
    CASE WHEN first_term=1 AND second_term=0 THEN 'PASS' ELSE 'FAIL' END,
    'first terminal='||first_term::text||' second='||second_term::text||' (expect 1 then 0)');
END $$;

-- ── PROBE 5 — orphan recovery: a delivery stuck 'sending' past the lease is reclaimable ──
-- INSERT a synthetic orphan directly with an old updated_at (the BEFORE-UPDATE
-- set_updated_at trigger fires only on UPDATE, so it can't overwrite an INSERT —
-- in production the lease ages naturally from the claim's updated_at).
DO $$
DECLARE reclaimed int;
BEGIN
  INSERT INTO notification_deliveries (organization_id, school_id, recipient_user_id, channel, category, rendered_body, status, updated_at)
  VALUES ('a1000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001',
          'd7000000-0000-4000-8000-000000000005','push','x','b','sending', timezone('utc',now()) - ('20 minutes')::interval);
  WITH c AS (
    UPDATE notification_deliveries SET status='sending', updated_at=timezone('utc',now())
     WHERE id IN (
       SELECT id FROM notification_deliveries
        WHERE organization_id='a1000000-0000-4000-8000-000000000001'
          AND status='sending' AND updated_at < timezone('utc',now()) - ('10 minutes')::interval
          AND recipient_user_id='d7000000-0000-4000-8000-000000000005'
        FOR UPDATE SKIP LOCKED)
     RETURNING 1
  ) SELECT count(*) INTO reclaimed FROM c;
  INSERT INTO r VALUES (5, 'orphan recovery: a delivery stuck ''sending'' past the lease is reclaimable',
    CASE WHEN reclaimed=1 THEN 'PASS' ELSE 'FAIL' END,
    'reclaimed after lease = '||reclaimed::text||' (expect 1 — no message stranded by a crashed drain)');
END $$;

RESET ROLE;
\echo ==================== RESULTS ====================
SELECT ord, verdict, probe, evidence FROM r ORDER BY ord;
SELECT CASE WHEN count(*) FILTER (WHERE verdict<>'PASS')=0
            THEN '✅ ALL '||count(*)::text||' PROBES PASS'
            ELSE '❌ '||count(*) FILTER (WHERE verdict<>'PASS')::text||' FAILED' END AS gate
FROM r;

ROLLBACK;
\echo ==================== ROLLED BACK (zero residue) ====================
SELECT 'RESIDUE deliveries' AS probe, count(*) AS rows FROM notification_deliveries WHERE recipient_user_id::text LIKE 'd7000000%';
