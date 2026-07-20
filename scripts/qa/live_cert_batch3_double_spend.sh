#!/usr/bin/env bash
# PRC-A Batch 3 — AI credit wallet DOUBLE-SPEND live cert (real concurrency).
#
# Proves the ONE thing the fake DB structurally cannot: two concurrent AI-call
# admits against a wallet that can only afford ONE let EXACTLY ONE through. This
# is the core of owner decision #3 ("no double-consumption, negative-balance
# races, or retry duplication").
#
# Faithfulness: each session runs as the REAL non-bypass `erp_tenant` role via
# app.set_request_context (identical to withTenantContext), takes the SAME
# per-bucket advisory lock the production reserveOutOfBand takes
# (pg_advisory_xact_lock(hashtextextended(org||':'||coalesce(school,'org'),42))),
# and runs the VERBATIM production admit INSERT..SELECT from
# ai_call_reservations_repository.ts (rate/spend terms disabled via params so the
# WALLET term is the sole gate; wallet enforced; creditsRequired=3).
#
# Residue: a throwaway grant + the surviving hold are tagged and deleted at the
# end; a residue check asserts the org's wallet returns to 0. Run ON the VPS:
#   docker cp / ssh then bash live_cert_batch3_double_spend.sh
set -uo pipefail
PSQL="docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db"
ORG='a1000000-0000-4000-8000-000000000001'
USR='a3000000-0000-4000-8000-000000000001'
TAG='B3CERT_DS'

echo "== cleanup any prior run =="
$PSQL -qtA -c "DELETE FROM ai_call_reservations WHERE surface='$TAG'; DELETE FROM ai_credit_entries WHERE external_ref='$TAG';" >/dev/null

echo "== seed: grant a top_up of 5 credits (committed) — affords exactly ONE 3-credit call, not two =="
$PSQL -qtA -c "INSERT INTO ai_credit_entries(organization_id,entry_type,units,reason,external_ref) VALUES ('$ORG','top_up',5,'b3 double-spend cert','$TAG');"

# The admit transaction, identical for both sessions. VERBATIM production admit.
ADMIT=$(cat <<SQL
\set ON_ERROR_STOP off
BEGIN;
SET ROLE erp_tenant;
SELECT app.set_request_context('$ORG'::uuid,'organization','$USR'::uuid,NULL::uuid,NULL::uuid,NULL::uuid,NULL::uuid);
SET LOCAL lock_timeout='6s';
SELECT pg_advisory_xact_lock(hashtextextended('$ORG' || ':' || coalesce(NULL,'org'), 42));
INSERT INTO ai_call_reservations (
   organization_id, school_id, user_id, surface, estimated_cost_micros,
   credits_reserved
 )
 SELECT '$ORG'::uuid, NULL::uuid, NULL::uuid, '$TAG', 0::bigint, 3::bigint
  WHERE (0::int <= 0 OR NULL::uuid IS NULL OR (
          (SELECT count(*) FROM ai_call_log
            WHERE organization_id = '$ORG' AND school_id IS NOT DISTINCT FROM NULL
              AND user_id = NULL AND created_at >= now()
              AND outcome NOT IN ('fallback_no_key','fallback_rate_user','fallback_rate_school','fallback_spend_cap'))
        + (SELECT count(*) FROM ai_call_reservations
            WHERE organization_id = '$ORG' AND school_id IS NOT DISTINCT FROM NULL
              AND user_id = NULL AND status = 'pending' AND created_at >= now())
        ) < 0::int)
    AND (0::int <= 0 OR (
          (SELECT count(*) FROM ai_call_log
            WHERE organization_id = '$ORG' AND school_id IS NOT DISTINCT FROM NULL
              AND created_at >= now()
              AND outcome NOT IN ('fallback_no_key','fallback_rate_user','fallback_rate_school','fallback_spend_cap'))
        + (SELECT count(*) FROM ai_call_reservations
            WHERE organization_id = '$ORG' AND school_id IS NOT DISTINCT FROM NULL
              AND status = 'pending' AND created_at >= now())
        ) < 0::int)
    AND (0::bigint <= 0 OR (
          (SELECT coalesce(sum(estimated_cost_micros), 0) FROM ai_call_log
            WHERE organization_id = '$ORG' AND school_id IS NOT DISTINCT FROM NULL
              AND created_at >= now())
        + (SELECT coalesce(sum(estimated_cost_micros), 0) FROM ai_call_reservations
            WHERE organization_id = '$ORG' AND school_id IS NOT DISTINCT FROM NULL
              AND status = 'pending' AND created_at >= now())
        ) + 0::bigint <= 0::bigint)
    AND (NOT true OR (
          (SELECT coalesce(sum(units), 0) FROM ai_credit_entries
            WHERE organization_id = '$ORG')
        - (SELECT coalesce(sum(credits_debited), 0) FROM ai_call_log
            WHERE organization_id = '$ORG')
        - (SELECT coalesce(sum(credits_reserved), 0) FROM ai_call_reservations
            WHERE organization_id = '$ORG' AND status = 'pending')
        ) >= 3::bigint)
 RETURNING id;
SELECT pg_sleep(1.0);
COMMIT;
SQL
)

echo "== launch TWO concurrent admits (each wants 3 credits; only 5 are available) =="
echo "$ADMIT" | $PSQL -qtA > /tmp/b3_sessA.out 2>&1 &
PIDA=$!
echo "$ADMIT" | $PSQL -qtA > /tmp/b3_sessB.out 2>&1 &
PIDB=$!
wait $PIDA; wait $PIDB

echo "--- session A output ---"; cat /tmp/b3_sessA.out
echo "--- session B output ---"; cat /tmp/b3_sessB.out

echo "== VERDICT =="
HELD=$($PSQL -qtA -c "SELECT count(*) FROM ai_call_reservations WHERE surface='$TAG' AND status='pending';")
AVAIL=$($PSQL -qtA -c "SELECT (SELECT coalesce(sum(units),0) FROM ai_credit_entries WHERE organization_id='$ORG' AND external_ref='$TAG') - (SELECT coalesce(sum(credits_reserved),0) FROM ai_call_reservations WHERE organization_id='$ORG' AND surface='$TAG' AND status='pending');")
echo "pending holds tagged $TAG = $HELD  (MUST be 1 — exactly one admit won)"
echo "wallet available after      = $AVAIL  (MUST be 2 = 5 granted - 3 held)"
if [ "$HELD" = "1" ] && [ "$AVAIL" = "2" ]; then echo "DOUBLE-SPEND PREVENTED: PASS"; else echo "DOUBLE-SPEND: FAIL"; fi

echo "== cleanup (delete the tagged grant + surviving hold) + residue check =="
$PSQL -qtA -c "DELETE FROM ai_call_reservations WHERE surface='$TAG'; DELETE FROM ai_credit_entries WHERE external_ref='$TAG';" >/dev/null
$PSQL -qtA -c "SELECT 'RESIDUE tagged rows=' || ((SELECT count(*) FROM ai_call_reservations WHERE surface='$TAG') + (SELECT count(*) FROM ai_credit_entries WHERE external_ref='$TAG'))::text;"
$PSQL -qtA -c "SELECT 'RESIDUE org wallet balance=' || (SELECT coalesce(sum(units),0) FROM ai_credit_entries WHERE organization_id='$ORG')::text;"
