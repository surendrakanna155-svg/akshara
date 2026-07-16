# DEPLOY CHECKPOINT — PRC-A batch (2026-07-16)

**Host:** `46.28.44.46` (⚠ SHARED prod — velora-salon / n8n / redis also live here; untouched).
**Source:** `feature/data-reliability-platform` @ `c3dd9951` (worktree `Akshara_ERP-drp`).
**Owner decision applied:** deploy migrations + edge, **skip vault activation** — `VAULT_ENC_KEY` deliberately NOT provisioned.

## Discipline: backup → migrate → deploy → health → live probe

### 1. Backup (pre-deploy, verified)
- `/root/backups/prc_a/akshara_db_predeploy_20260716_030639.sql` — 2.0 MB, complete dump.
- `/root/backups/prc_a/edge_functions_predeploy_20260716_030639.tgz` — 1.4 MB, full pre-deploy edge tree (rollback artifact).

### 2. Migrations — `20260881000000` → **`20260887000000`**
Applied as **`supabase_admin`** (owns all 228 public tables). ⚠ `postgres` is NOT the owner — the first attempt as `postgres` failed `must be owner of table` / `permission denied for schema public`. Each migration ran `--single-transaction` **together with its ledger INSERT**, so a failed DDL could never leave a ledger row claiming it applied. The three failed attempts left **nothing** applied and **nothing** ledgered.

| Version | Name | Result |
|---|---|---|
| 20260882000000 | platform_db_role | ✅ ledgered — creates role `erp_platform` |
| 20260883000000 | fee_structure_class_binding | ✅ ledgered |
| 20260884000000 | certificate_requests | ✅ ledgered (8 perms/grants) |
| 20260885000000 | gate_passes | ✅ ledgered (4) |
| 20260886000000 | complaints | ✅ ledgered (7) |
| 20260887000000 | student_health | ✅ ledgered (6) — creates role `healthStaff` |

**Schema verified live:** 9 new tables, **all `rls=t` AND `forced=t`**, each with policies (`complaint_events` 4 · `complaints` 5 · `gate_passes` 5 · `sis_certificate_requests` 5 · `student_care_alerts` 3 · `student_health_access_log` 2 · `student_health_incidents` 3 · `student_medication_administration_log` 2 · `student_medication_authorizations` 3). Roles `erp_platform` + `healthStaff` present. **12/12** new permission slugs seeded.

### 3. Edge
`rsync --delete` → `/opt/akshara/functions` (volume-mounted to `/app`; `deno run -A --no-lock api/index.ts`), then `docker restart akshara-edge`. All 4 new modules present (107 module dirs, was 103). Clean boot, `Listening on http://0.0.0.0:8000/`.

### 4. Health + live route contract — **the real edge is `127.0.0.1:3000`**
⚠ **Host `:8000` is gunicorn — a DIFFERENT tenant's service on this shared box.** An initial probe against `localhost:8000` returned HTML/400 for everything; that was not our service. `akshara-edge` maps `8000/tcp → 127.0.0.1:3000`. **Probe `:3000`, never `:8000`.**

| Probe | Result |
|---|---|
| `GET /health` · `/health/ready` | **200** — system health NOT shadowed by the `/student-health` module |
| `GET /certificate-requests` · `/gate-passes` · `/complaints` · `/student-health/incidents` · `/student-health/access-log` | **401** — route exists + auth enforced |
| `POST /gate-passes` | **401** — mutating route auth-gated |
| `GET /student-health/nope` | **404** — unmatched inside prefix is a definitive 404, not a null fallthrough |
| level-50 errors since restart | **0** |

## ✅ CERTIFIED LIVE by this deploy
1. **Money P0 #1 — account resolution** (`4bc1046b`). Pre-deploy probe on real `akshara_db` (`scripts/qa/live_probe_money_p0_account_resolution.sql`, `BEGIN…ROLLBACK`): OLD join `fsa.fee_assignment_id = fi.fee_assignment_id` → **0 rows** (defect reproduced); NEW join `student_id + academic_year` → **1 row** (fix confirmed). Post-rollback residue: `students=0 structures=0 invoices=0`.
2. **Immutable logs actually enforced** (live-probe #4). `SET ROLE erp_tenant` (the real non-bypass app role): `UPDATE student_medication_administration_log` → **permission denied**; `DELETE student_health_access_log` → **permission denied**; `DELETE complaint_events` → **permission denied**; `SELECT` allowed. Grants are `INSERT,SELECT` only. Previously provable only by source inspection.
3. **Batch 2 route contract** — see the table above.
4. **RT-15 defence intact.** `erp_tenant` still holds **NO** grants on `platform_secret_vault`; the new `erp_platform` role holds `INSERT,SELECT,UPDATE`. The platform path did not weaken the tenant wall.

## 🔓 Deliberately NOT done (owner decision)
- **`VAULT_ENC_KEY` NOT provisioned** — verified unset on the edge. The AES vault therefore **fails closed**: store/rotate/reencrypt refuse. **Caps 44–49 remain PARTIAL, honestly.** No fake-encrypted secrets exist, which is the point of the fix. `/health/providers` → 200 (endpoint healthy; the vault itself is inert).

## ⏳ STILL UNCERTIFIED — needs authenticated live sessions (next)
1. **RLS tenant isolation** on the 9 new tables — cross-tenant/cross-school reads actually blocked.
2. **Parent/guardian scoping** — a parent sees only their own child's rows (`student_guardians` subquery).
3. **`teacherTeachesStudent`** — the live 3-way UNION (roster §section-FK ∪ roster §text-labels ∪ timetable incl. substitutes), + the `sis_student_enrollments.section_id` NULL soft-FK edge.
4. **`healthStaff` role → JWT `claims.permissions`** end-to-end.
5. **Partial-unique constraints** (`uq_gate_passes_open_slot`, cert-desk open-request guard) — the constraint-violation catch matches an error string never triggered against real Postgres.
6. **Money P0 #2 — `cancelInvoice` lockstep** — needs a concurrent authenticated exercise of the guarded status write + account release.

These need real auth (`/certify`), not DB-level probes. **Do not claim Batch 2 CERTIFIED until they pass.**

## Rollback
```
# edge
tar xzf /root/backups/prc_a/edge_functions_predeploy_20260716_030639.tgz -C /opt/akshara && docker restart akshara-edge
# db (full restore — destructive; migrations are forward-only)
docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db < /root/backups/prc_a/akshara_db_predeploy_20260716_030639.sql
```

## Known residue (pre-existing, not introduced here)
295 `*_test.ts` files sit under `/opt/akshara/functions` from earlier deploys. They are never imported by `api/index.ts`, so they never execute. `--exclude='*_test.ts'` protects them from `--delete` too, which is why they persist. Untidy, harmless; left consistent with prior deploys rather than silently changed.
