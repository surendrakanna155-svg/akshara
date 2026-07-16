#!/usr/bin/env bash
# PRC-A Batch 5 — webhook replay guard LIVE CERT (real concurrency).
#
# Proves the money-integrity claim the fake DB cannot: two CONCURRENT deliveries
# of the SAME Razorpay webhook event process it EXACTLY ONCE. Runs the VERBATIM
# production statement from recordWebhookEvent (INSERT … ON CONFLICT (id) DO
# NOTHING RETURNING id) as the REAL erp_tenant role via app.set_request_context,
# in two concurrent backends. Tagged row deleted afterward; residue asserted 0.
# Run ON the VPS.
set -uo pipefail
PSQL="docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db"
ORG='a1000000-0000-4000-8000-000000000001'
USR='a3000000-0000-4000-8000-000000000001'
EVT='B5CERT_EVT_dup'

echo "== cleanup any prior run =="
$PSQL -qtA -c "DELETE FROM payment_webhook_events WHERE id='$EVT';" >/dev/null

# Identical for both sessions — the VERBATIM production replay guard.
GUARD=$(cat <<SQL
\set ON_ERROR_STOP off
BEGIN;
SET ROLE erp_tenant;
SELECT app.set_request_context('$ORG'::uuid,'organization','$USR'::uuid,NULL::uuid,NULL::uuid,NULL::uuid,NULL::uuid);
INSERT INTO payment_webhook_events (
   id, organization_id, event_type, payload,
   resolved_organization_id, resolved_school_id
 ) VALUES ('$EVT', '$ORG', 'payment.captured', '{}'::jsonb, '$ORG', NULL)
 ON CONFLICT (id) DO NOTHING
 RETURNING id;
SELECT pg_sleep(0.8);
COMMIT;
SQL
)

echo "== launch TWO concurrent deliveries of the SAME event =="
echo "$GUARD" | $PSQL -qtA > /tmp/b5_sessA.out 2>&1 &
PIDA=$!
echo "$GUARD" | $PSQL -qtA > /tmp/b5_sessB.out 2>&1 &
PIDB=$!
wait $PIDA; wait $PIDB

echo "--- session A returned id ---"; grep -c "$EVT" /tmp/b5_sessA.out
echo "--- session B returned id ---"; grep -c "$EVT" /tmp/b5_sessB.out

echo "== VERDICT =="
WINNERS=$(( $(grep -c "$EVT" /tmp/b5_sessA.out) + $(grep -c "$EVT" /tmp/b5_sessB.out) ))
ROWS=$($PSQL -qtA -c "SELECT count(*) FROM payment_webhook_events WHERE id='$EVT';")
echo "sessions that CLAIMED the event (RETURNING a row) = $WINNERS  (MUST be 1)"
echo "rows persisted for the event                       = $ROWS      (MUST be 1)"
if [ "$WINNERS" = "1" ] && [ "$ROWS" = "1" ]; then echo "REPLAY DEDUP: PASS (processed exactly once)"; else echo "REPLAY DEDUP: FAIL"; fi

echo "== cleanup + residue =="
$PSQL -qtA -c "DELETE FROM payment_webhook_events WHERE id='$EVT';" >/dev/null
$PSQL -qtA -c "SELECT 'RESIDUE event rows=' || count(*)::text FROM payment_webhook_events WHERE id='$EVT';"
