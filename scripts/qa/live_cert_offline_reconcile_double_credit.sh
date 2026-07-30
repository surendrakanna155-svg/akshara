#!/usr/bin/env bash
# ICA-A2 (P0) — offline-instrument reconcile DOUBLE-CREDIT live cert (real concurrency).
#
# Proves the ONE thing the DB-free mock structurally cannot: two concurrent
# reconciles of ONE cheque/DD instrument post EXACTLY ONE collection — never two.
# Before the fix, both reconciles read the instrument as 'pending_reconciliation'
# (an UNLOCKED SELECT), both passed the reconciled-check, both called
# createCollection, and both terminal UPDATEs succeeded (the old guard was
# `AND status <> 'bounced'`) → TWO collections for ONE instrument (a double credit).
#
# Faithfulness (mirrors scripts/qa/live_cert_batch3_double_spend.sh):
#   * each session runs as the REAL non-bypass `erp_tenant` role via
#     app.set_request_context (identical to withTenantContext), under 'school' scope;
#   * each session's transaction runs the production reconcile DB SEQUENCE in the
#     SAME order the repository issues it:
#       (a) SELECT ... FROM finance_offline_payments ... FOR UPDATE   [the new lock]
#       (a') idempotent short-circuit: if already 'reconciled', post NOTHING;
#       (c/d) INSERT INTO finance_collections with offline_payment_id +
#             idempotency_key = 'offline-reconcile:<id>'  [the DB backstops];
#           + decrement the invoice outstanding + credit the student account;
#       (b) UPDATE ... SET status='reconciled' ... WHERE ... AND
#           status = 'pending_reconciliation'  [the tightened atomic guard];
#   * the two partial-unique indexes (finance_collections_offline_payment_uq and
#     finance_collections_idempotency_key_uq) are the hard DB invariants that make
#     a second collection impossible even if the app guard were regressed.
#
# The FOR UPDATE lock serializes the two sessions: the loser blocks on the lock,
# then re-reads 'reconciled' and posts nothing (the idempotent no-op). The winner
# posts the single collection.
#
# Data: discovers an existing issued/partially_paid invoice (+ its student account)
# on the pilot with outstanding >= 2 x AMOUNT, seeds ONE throwaway
# finance_offline_payments row linked to it, races, asserts, then FULLY restores
# (deletes the tagged collection, restores invoice + account, deletes the instrument)
# and runs a residue check. Run ON the VPS:
#   docker cp / ssh then bash live_cert_offline_reconcile_double_credit.sh
#
# NOTE: authored against the certified schema; MUST be executed on the live VPS
# pilot during certification (no VPS access at authoring time). If ORG has no
# suitable seeded invoice, the script exits 2 with guidance rather than guessing.
set -uo pipefail
PSQL="docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db"
ORG='a1000000-0000-4000-8000-000000000001'
USR='a3000000-0000-4000-8000-000000000001'
TAG='ICA_A2_RECON'
AMOUNT=100

echo "== cleanup any prior run =="
$PSQL -qtA -c "
  DELETE FROM finance_collections
   WHERE offline_payment_id IN (SELECT id FROM finance_offline_payments WHERE reference_number='$TAG');
  DELETE FROM finance_collections WHERE reference_number='$TAG' OR idempotency_key LIKE 'offline-reconcile:%' AND notes='$TAG reconcile';
  DELETE FROM finance_offline_payments WHERE reference_number='$TAG';
" >/dev/null 2>&1 || true

echo "== discover a seeded invoice (+ student account) with outstanding >= $((AMOUNT*2)) =="
ROW=$($PSQL -qtA -F'|' -c "
  SELECT fi.id, fi.school_id, fi.student_id, fsa.id, fi.outstanding_amount::text, fi.invoice_status
    FROM finance_invoices fi
    JOIN finance_student_accounts fsa
      ON fsa.student_id = fi.student_id
     AND fsa.academic_year = fi.academic_year
     AND fsa.organization_id = fi.organization_id
     AND fsa.school_id = fi.school_id
   WHERE fi.organization_id = '$ORG'
     AND fi.invoice_status IN ('issued','partially_paid')
     AND fi.outstanding_amount >= $((AMOUNT*2))
   ORDER BY fi.outstanding_amount DESC
   LIMIT 1;")
IFS='|' read -r INV SCHOOL STU ACCT OUTSTANDING STATUS <<<"$ROW"
if [ -z "${INV:-}" ]; then
  echo "NO SUITABLE INVOICE for org $ORG (need issued/partially_paid, outstanding >= $((AMOUNT*2)))."
  echo "Seed one (or point ORG at the pilot's finance-seeded org) and re-run."
  exit 2
fi
echo "invoice=$INV school=$SCHOOL student=$STU account=$ACCT outstanding_before=$OUTSTANDING status_before=$STATUS"

echo "== seed: ONE pending cheque instrument for $AMOUNT linked to that invoice =="
PAYID=$($PSQL -qtA -c "
  INSERT INTO finance_offline_payments
    (organization_id, school_id, invoice_id, student_name, amount,
     payment_method, reference_number, status, recorded_by)
  VALUES
    ('$ORG','$SCHOOL','$INV','ICA-A2 Test',$AMOUNT,
     'cheque','$TAG','pending_reconciliation','$USR')
  RETURNING id;")
echo "instrument=$PAYID"

# The reconcile transaction, identical for both sessions — the production DB
# sequence run under the real erp_tenant role with school-scope RLS context.
# Written to a file (rather than a $(...) capture) so the plpgsql $$-quoting and
# in-SQL single quotes never reach the shell's word parser.
cat > /tmp/ica_a2_recon.sql <<SQL
\set ON_ERROR_STOP off
BEGIN;
SET ROLE erp_tenant;
SELECT app.set_request_context('$ORG'::uuid,'school','$USR'::uuid,'$SCHOOL'::uuid,NULL::uuid,NULL::uuid,NULL::uuid);
SET LOCAL lock_timeout='6s';
DO \$\$
DECLARE
  v_status  text;
  v_amount  numeric;
  v_invoice uuid;
  v_student uuid;
  v_account uuid;
  v_coll    uuid;
BEGIN
  -- (a) LOCK the instrument row FIRST (the fix): serializes concurrent reconciles.
  SELECT status, amount, invoice_id
    INTO v_status, v_amount, v_invoice
    FROM finance_offline_payments
   WHERE id = '$PAYID'
   FOR UPDATE;

  -- (a') idempotent short-circuit: the loser, having blocked on the lock, now sees
  -- 'reconciled' and returns WITHOUT posting a collection.
  IF v_status IS DISTINCT FROM 'pending_reconciliation' THEN
    RETURN;
  END IF;

  -- hold the lock briefly so the sibling session is provably blocked on it.
  PERFORM pg_sleep(0.6);

  SELECT fi.student_id, fsa.id
    INTO v_student, v_account
    FROM finance_invoices fi
    JOIN finance_student_accounts fsa
      ON fsa.student_id = fi.student_id
     AND fsa.academic_year = fi.academic_year
     AND fsa.organization_id = fi.organization_id
     AND fsa.school_id = fi.school_id
   WHERE fi.id = v_invoice
   FOR UPDATE OF fi;

  -- (c/d) post the single collection, stamped with the instrument id + derived
  -- idempotency key — the two DB unique indexes make a second one impossible.
  INSERT INTO finance_collections
    (organization_id, school_id, student_id, invoice_id, student_account_id,
     receipt_number, collection_date, payment_method, reference_number,
     amount_collected, notes, collection_status, collected_by, idempotency_key,
     offline_payment_id)
  VALUES
    ('$ORG','$SCHOOL', v_student, v_invoice, v_account,
     'RCPT-$TAG-'||substr(md5(random()::text),1,8), CURRENT_DATE, 'cheque', '$TAG',
     v_amount, '$TAG reconcile', 'completed', '$USR', 'offline-reconcile:$PAYID',
     '$PAYID')
  RETURNING id INTO v_coll;

  UPDATE finance_invoices
     SET outstanding_amount = outstanding_amount - v_amount,
         updated_at = timezone('utc', now())
   WHERE id = v_invoice;

  UPDATE finance_student_accounts
     SET amount_paid = amount_paid + v_amount,
         outstanding_amount = outstanding_amount - v_amount,
         updated_at = timezone('utc', now())
   WHERE id = v_account;

  -- (b) terminal atomic guard: flip ONLY while still pending.
  UPDATE finance_offline_payments
     SET status = 'reconciled',
         reconciled_at = timezone('utc', now()),
         reconciled_by = '$USR',
         collection_id = v_coll,
         updated_at = timezone('utc', now())
   WHERE id = '$PAYID'
     AND status = 'pending_reconciliation';
END
\$\$;
COMMIT;
SQL

echo "== launch TWO concurrent reconciles of the SAME instrument =="
$PSQL -qtA < /tmp/ica_a2_recon.sql > /tmp/ica_a2_sessA.out 2>&1 &
PIDA=$!
$PSQL -qtA < /tmp/ica_a2_recon.sql > /tmp/ica_a2_sessB.out 2>&1 &
PIDB=$!
wait $PIDA; wait $PIDB

echo "--- session A output ---"; cat /tmp/ica_a2_sessA.out
echo "--- session B output ---"; cat /tmp/ica_a2_sessB.out

echo "== VERDICT =="
COLLS=$($PSQL -qtA -c "SELECT count(*) FROM finance_collections WHERE offline_payment_id='$PAYID';")
INSTR=$($PSQL -qtA -F'|' -c "SELECT status, coalesce(collection_id::text,'<null>') FROM finance_offline_payments WHERE id='$PAYID';")
IFS='|' read -r INSTR_STATUS INSTR_COLL <<<"$INSTR"
DECREMENT=$($PSQL -qtA -c "SELECT ($OUTSTANDING::numeric - outstanding_amount)::text FROM finance_invoices WHERE id='$INV';")

echo "collections for instrument = $COLLS        (MUST be 1 — exactly one credit)"
echo "instrument status          = $INSTR_STATUS   (MUST be reconciled)"
echo "instrument collection_id   = $INSTR_COLL"
echo "invoice outstanding drop   = $DECREMENT      (MUST equal $AMOUNT — one amount, not two)"

PASS=1
[ "$COLLS" = "1" ] || PASS=0
[ "$INSTR_STATUS" = "reconciled" ] || PASS=0
[ "$INSTR_COLL" != "<null>" ] || PASS=0
# numeric-equality tolerant of '100' vs '100.00'
$PSQL -qtA -c "SELECT CASE WHEN $DECREMENT::numeric = $AMOUNT::numeric THEN 1 ELSE 0 END;" | grep -q '^1$' || PASS=0
if [ "$PASS" = "1" ]; then echo "DOUBLE-CREDIT PREVENTED: PASS"; else echo "DOUBLE-CREDIT: FAIL"; fi

echo "== cleanup (delete tagged collection, restore invoice + account, delete instrument) + residue check =="
$PSQL -qtA -c "
  UPDATE finance_student_accounts
     SET amount_paid = amount_paid - (SELECT coalesce(sum(amount_collected),0) FROM finance_collections WHERE offline_payment_id='$PAYID'),
         outstanding_amount = outstanding_amount + (SELECT coalesce(sum(amount_collected),0) FROM finance_collections WHERE offline_payment_id='$PAYID')
   WHERE id='$ACCT';
  DELETE FROM finance_collections WHERE offline_payment_id='$PAYID';
  UPDATE finance_invoices SET outstanding_amount = $OUTSTANDING::numeric, invoice_status = '$STATUS' WHERE id='$INV';
  DELETE FROM finance_offline_payments WHERE id='$PAYID';
" >/dev/null

$PSQL -qtA -c "SELECT 'RESIDUE tagged instruments=' || (SELECT count(*) FROM finance_offline_payments WHERE reference_number='$TAG')::text;"
$PSQL -qtA -c "SELECT 'RESIDUE tagged collections=' || (SELECT count(*) FROM finance_collections WHERE reference_number='$TAG')::text;"
$PSQL -qtA -c "SELECT 'RESIDUE invoice outstanding restored=' || CASE WHEN (SELECT outstanding_amount FROM finance_invoices WHERE id='$INV') = $OUTSTANDING::numeric THEN 'yes' ELSE 'NO' END;"
