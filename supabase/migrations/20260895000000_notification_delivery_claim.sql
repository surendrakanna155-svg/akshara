-- PRC P5 (red-team P4-RT-1 Round 1, finding #1) — make the notification delivery
-- drain concurrency-safe.
--
-- Red-team found: processDeliveryQueue did a plain `SELECT ... WHERE status='pending'`
-- with no per-row claim (unlike the sibling claimDueScheduledBroadcasts, which uses
-- FOR UPDATE SKIP LOCKED). Two overlapping drains for the same org (two broadcasts
-- seconds apart, or cron + a manual send) both fetched the SAME pending rows → every
-- recipient's SMS/push/WhatsApp sent TWICE (real provider $ per message) and, on a
-- terminal failure, escalation (Batch 6) fired twice, enqueuing duplicate follow-ups.
--
-- Fix: add a transient 'sending' status so the drain can atomically CLAIM each
-- delivery (pending → sending) before sending it; concurrent drains then get disjoint
-- claimed sets via FOR UPDATE SKIP LOCKED. ('sending' already exists on the sibling
-- comm_broadcasts status vocabulary — this aligns notification_deliveries with it.)

ALTER TABLE notification_deliveries
  DROP CONSTRAINT notification_deliveries_status_check;
ALTER TABLE notification_deliveries
  ADD CONSTRAINT notification_deliveries_status_check
    CHECK (status IN ('pending', 'sending', 'sent', 'failed', 'cancelled'));
