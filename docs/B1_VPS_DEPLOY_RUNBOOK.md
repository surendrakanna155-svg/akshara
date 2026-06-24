# B1 — Admissions CRM · VPS Production Deploy Runbook

**Status gate:** B1 = **Pending Production Certification** (code-complete + local-E2E-certified).
Only after §3 passes on the live host does B1 become Fully Complete.

**Host:** `46.28.44.46` · public `https://akshara.veloraunisexsalon.com` (routes at ROOT).
**`$STACK`** = the VPS dir holding `docker-compose.akshara.yml`.
**Branch/commit:** `feature/scope-trim-school-build` @ `c91b941`.

**Exact production footprint of B1 (nothing else):**
- 1 migration: `supabase/migrations/20260716000000_admissions_crm_activities_followups.sql`
- 5 edge files: `_shared/admissions/{admissions_handlers,admissions_mapper,admissions_repository,admissions_router}.ts` + `_shared/audit/mutation_audit_catalog.ts`

> Set these once in your shell: `HOST=root@46.28.44.46` and `STACK=<the stack dir on the VPS>`.

---

## 4. Production risks — read BEFORE migrating

1. **Migration-drift (unknown ledger state).** I cannot see the VPS ledger from here. Other batches' migrations (`20260715000000`, `20260715100000`) may or may not be applied. **Mitigation:** B1's migration is fully self-contained — it depends only on `organizations`, `schools`, `admissions_leads`, `set_updated_at()`, `app_current_tenant_id/scope/school_id()`, all live since the first admissions slice. So **apply only `20260716000000`** for B1; do NOT bundle other pending migrations into this deploy (they belong to their own batches + edge code). Step §0b prints the true ledger gap so you can confirm.
2. **Edge scope-creep.** A full `rsync --delete` of `functions/` would push *every* committed-but-undeployed edge change live (e.g. AI batches), widening the blast radius beyond B1. **Mitigation:** §2 syncs only the **5 B1 files** at the branch tip — self-consistent and B1-isolated.
3. **Live pilot data + brief edge restart.** Recreating `akshara-edge` is a ~1–3s blip; reads/writes resume on restart. **Mitigation:** off-peak + §0 backup first.
4. **Test-row pollution.** The live smoke (§3) creates a real lead + activities in the pilot DB (School A). Acceptable as test data, or clean up with §3b (needs `supabase_admin`; `erp_tenant` cannot DELETE).
5. **Ledger idempotency.** Must record `20260716000000` in `supabase_migrations.schema_migrations` so a future `migration up`/`db push` won't re-run it (§1).
6. **RLS / grants.** Same SQL verified locally (FORCE RLS + school-scope policy + `erp_tenant` SELECT/INSERT[/UPDATE]). §1 re-verifies on the live DB.

**Go/No-Go:** proceed only if §0 backup succeeded and §0b shows `20260716000000` is NOT yet applied.

---

## 0. Pre-flight + backup (MANDATORY)
```bash
HOST=root@46.28.44.46
STACK=/root/akshara         # <-- set to the real stack dir

# local: confirm the exact verified tip
git -C /Users/surendrakanna/Documents/Akshara_ERP rev-parse --short HEAD   # expect c91b941

# VPS: fresh encrypted backup BEFORE touching anything
ssh $HOST "cd $STACK/backup && ./akshara-backup.sh"
```

## 0b. Drift check — confirm what's already applied
```bash
ssh $HOST 'docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -c \
  "SELECT version FROM supabase_migrations.schema_migrations WHERE version >= '\''20260713000000'\'' ORDER BY version;"'
```
Expect `20260716000000` to be **absent**. (If `20260715000000` / `20260715100000` are also absent, that is fine — they are other batches; do **not** apply them as part of B1.)

## 1. Apply the B1 migration (apply → record → verify, atomic)
```bash
# copy migration up
scp /Users/surendrakanna/Documents/Akshara_ERP/supabase/migrations/20260716000000_admissions_crm_activities_followups.sql \
    $HOST:/tmp/b1.sql

ssh $HOST 'bash -s' <<'EOSSH'
set -euo pipefail
# apply as superuser, abort on any error
docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -v ON_ERROR_STOP=1 < /tmp/b1.sql
# record in ledger (single-quoted string literal)
docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -v ON_ERROR_STOP=1 -c \
  "INSERT INTO supabase_migrations.schema_migrations(version) VALUES ('20260716000000') ON CONFLICT DO NOTHING;"
# verify: both tables, FORCE RLS, one policy each, erp_tenant INSERT grant
docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -c \
  "SELECT relname, relrowsecurity AS rls, relforcerowsecurity AS force,
          (SELECT count(*) FROM pg_policies p WHERE p.tablename=c.relname) AS policies,
          has_table_privilege('erp_tenant','public.'||relname,'INSERT') AS erp_insert
   FROM pg_class c WHERE relname IN ('admissions_lead_activities','admissions_lead_follow_ups');"
rm -f /tmp/b1.sql
EOSSH
```
Expect both tables: `rls=t force=t policies=1 erp_insert=t`.

## 2. Deploy the 5 B1 edge files (B1-isolated) + recreate edge
```bash
cd /Users/surendrakanna/Documents/Akshara_ERP/supabase/functions
rsync -Raz \
  _shared/admissions/admissions_handlers.ts \
  _shared/admissions/admissions_mapper.ts \
  _shared/admissions/admissions_repository.ts \
  _shared/admissions/admissions_router.ts \
  _shared/audit/mutation_audit_catalog.ts \
  $HOST:$STACK/functions/

ssh $HOST "cd $STACK && docker compose -f docker-compose.akshara.yml up -d --force-recreate akshara-edge"
ssh $HOST "docker logs --tail 20 akshara-edge"   # expect 'Listening on ...', no boot error
```
> Full-sync alternative (only if you intend to push *all* pending edge changes live):
> `rsync -az --delete supabase/functions/ $HOST:$STACK/functions/` — see risk #2 first.

---

## 3. Live certification checklist (real auth + real production DB)
```bash
BASE=https://akshara.veloraunisexsalon.com
curl -fsS $BASE/health && echo            # gateway/edge up
curl -fsS $BASE/health/ready && echo      # database:true

# Full B1 loop, real auth via an ALLOWLISTED pilot phone (AUTH_OTP_PILOT_PHONES on the VPS):
API_BASE_URL=$BASE ADMIN_PHONE=<pilot_admin_phone> PARENT_PHONE=<pilot_parent_phone> \
  bash /Users/surendrakanna/Documents/Akshara_ERP/scripts/admissions_crm_b1_smoke.sh
```
**PASS criteria (all must hold):**
- [ ] `admin login` ok
- [ ] `create lead` ok
- [ ] `assign counselor` → counselor persisted
- [ ] `change stage` → stage persisted
- [ ] `add follow-up` → follow-up row returned
- [ ] `add note` / `log WhatsApp` / `log call` → activity rows of type note / whatsapp / call
- [ ] `lead detail returns persisted timeline + follow-up history` (≥5 activities incl. assignment+stageChange+note+whatsapp+call, ≥1 follow-up)
- [ ] `parent scope denied assign (403)`
- [ ] `cross-school lead read denied (404)`
- [ ] script prints **`Results: 11 passed, 0 failed`**

Optional DB confirmation of audit + persistence on the live host:
```bash
ssh $HOST 'docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -c \
  "SELECT event_type, count(*) FROM domain_events WHERE event_type LIKE '\''admissions.lead.%'\'' GROUP BY 1 ORDER BY 1;"'
```

## 3b. (Optional) remove the smoke test lead from the pilot DB
```bash
ssh $HOST 'docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -c \
  "DELETE FROM admissions_leads WHERE phone='\''9999900042'\'' AND parent_name='\''CRM Smoke Parent'\'';"'
# child activity/follow-up rows cascade via ON DELETE CASCADE.
```

---

## 5. Rollback procedure
- **Edge (instant, read-only mount):** restore the previous revision of the 5 files and recreate —
  ```bash
  cd /Users/surendrakanna/Documents/Akshara_ERP && git stash || true
  git checkout 8cbf55b -- supabase/functions/_shared/admissions supabase/functions/_shared/audit/mutation_audit_catalog.ts
  cd supabase/functions && rsync -Raz _shared/admissions/*.ts _shared/audit/mutation_audit_catalog.ts $HOST:$STACK/functions/
  ssh $HOST "cd $STACK && docker compose -f docker-compose.akshara.yml up -d --force-recreate akshara-edge"
  # then restore working tree: git checkout c91b941 -- supabase/functions ; git stash pop
  ```
- **Migration (additive — safe to drop):**
  ```bash
  ssh $HOST 'docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -v ON_ERROR_STOP=1 -c \
    "DROP TABLE IF EXISTS public.admissions_lead_activities CASCADE;
     DROP TABLE IF EXISTS public.admissions_lead_follow_ups CASCADE;
     DELETE FROM supabase_migrations.schema_migrations WHERE version='\''20260716000000'\'';"'
  ```
  No other module references these tables (the FKs point *from* them *to* `admissions_leads`), so dropping them cannot affect any other feature. Only post-deploy CRM timeline/follow-up rows are lost.
- **Full disaster restore:** `ssh $HOST "cd $STACK/backup && ./akshara-restore.sh <snapshot-from-§0>"`.

## 6. On success
- Re-run the local app against live (`scripts/run_live.sh`) and open a lead → confirm timeline/follow-ups load from the server, add a note, reload → it persists.
- Mark roadmap **B1 = Fully Complete (VPS-certified)** and tag `git tag -a b1-live -m "B1 Admissions CRM live on VPS" c91b941 && git push origin b1-live`.
