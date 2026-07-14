# Deployment Checkpoint — 2026-07-14 · P0-LIVE-1 migration + edge deploy

**Status:** ✅ COMPLETE & VERIFIED · **Operator:** autonomous (owner-authorized) · **Scope:** Akshara namespace only (Velora/n8n/Redis/MySQL untouched)
**Authorization:** owner directive 2026-07-14 — "audit… if everything required for a safe deployment is satisfied, proceed autonomously with the complete migration/deployment workflow."

---

## 1. What was deployed

- **12 additive migrations** `20260867` → `20260878`:
  - AI/W2 (`20260867`–`20260876`): `ai_call_log` (+ org-scope, guard-outcome), `ai_memory_and_cache`, `ai_persona_memory_all_scopes`, `ai_call_reservations`, `ai_semantic_cache` (pgvector-guarded, dormant), search indexes (`search_student_name_index`, `search_staff_admissions_indexes`, `search_scale_indexes` — `pg_trgm` self-installed).
  - Face-ID (`20260877`): `staff_face_enrollments` (embedding = plain `REAL[]`, no pgvector needed).
  - SCE-1 (`20260878`): `student_clearance_waivers` (+ seeded lifecycle-policy rows).
- **Edge code** refreshed to commit **`9bbf8630`** (`feature/data-reliability-platform` HEAD) — brings SCE-1, Face-ID, latest W2 and the honesty-sweep fixes live on the self-hosted edge (`akshara-edge`, Deno `functions/api`, bind-mounted `/opt/akshara/functions`).

## 2. State transition

| | Before | After |
|---|---|---|
| Migration count | 185 | **197** |
| Migration head | `20260866` | **`20260878`** |
| Edge `/health` version | `2568ff9b` (built 2026-07-09) | **`9bbf8630`** (built 2026-07-14T10:22:16Z) |

## 3. Process (proven-safe, reversible)

1. **Backup (2 rollback points):** manual encrypted `akshara-backup.sh manual` → `/opt/akshara/backup/store/akshara_db_20260714T101332Z_manual.dump.enc` (sha256 recorded, `ops_backup_runs` ledger row) + plaintext `pg_dump | gzip` → `/opt/akshara/backups/predeploy_20260714_101400.sql.gz`.
2. **Migrations:** staged the 12 files to `/opt/akshara/migrations_pending_20260714`, applied each as `supabase_admin` on `akshara_db` with `ON_ERROR_STOP=1` (idempotent skip-if-applied; halt-on-first-error), recorded each in `supabase_migrations.schema_migrations (version, name)` per existing convention. `CREATE INDEX CONCURRENTLY` in 2 migrations → applied without a transaction wrapper.
3. **Edge:** backed up `/opt/akshara/functions` → `functions_bak_predeploy_20260714_1015` (7.4M), rsynced current `supabase/functions/` (466 files, tests/cruft excluded, no `--delete`), `docker restart akshara-edge`, regenerated `_shared/build_info.json` with the deployed SHA + restart, `NOTIFY pgrst 'reload schema'`.

## 4. Verification (all ✅)

- DB: `197 migrations · head 20260878`; new tables `ai_call_log`, `ai_call_reservations`, `ai_persona_memory`, `staff_face_enrollments`, `student_clearance_waivers` present.
- Edge: `/health` → ok, version `9bbf8630`; `/health/ready` → `database:true`.
- New routes live (did not exist in the 2026-07-09 build): `POST /staff-attendance/enroll-face` → 401, `/staff-attendance/manual-requests` → 401, `/sis/students/:id/clearance` → 401 (auth-gated, exist). `/sis/students` → 401 without token.
- Isolation: `root-n8n-1` Up 2 months (untouched); all 5 akshara containers healthy.
- pgvector semantic cache applied its **guarded dormant** path (pgvector unprovisioned by design).

## 5. Rollback (if ever needed)

- **DB:** restore `predeploy_20260714_101400.sql.gz` (plaintext) or the encrypted `.dump.enc` into `akshara_db`. Migrations are additive, so forward-fix is usually preferable to restore.
- **Edge:** `rsync`/`cp` `functions_bak_predeploy_20260714_1015` → `/opt/akshara/functions` + `docker restart akshara-edge`.

## 6. Roadmap impact — what this unblocks

- **P0-LIVE-1 ① (AI migrations deploy — MUST precede the W2 flag reaching a live build): ✅ DONE.** Also lands the Face-ID (`20260877`) and SCE-1 (`20260878`) migrations that were riding LIVE-1.
- **CFC-1 item 8 (migration head == deployed head): ✅ GREEN** — repo head `20260878` == deployed head `20260878`.
- **CFC-1 item 5 (W2 flag deploy-sequenced via LIVE-1 ①): prerequisite MET** — the W2 migrations are deployed, so the flag→build sequencing constraint is satisfied.

## 7. Residuals (owner-provisioning / non-blocking — pre-existing LIVE-1 items)

- **Off-site backup not configured** — `RCLONE_REMOTE` unset → backups are **local-only** (3-2-1 incomplete). Needs owner-provisioned R2/rclone creds. Nightly encrypted backup runs & is healthy (`ops_backup_runs` success through 2026-07-14).
- **pgvector unprovisioned** → W2.8 semantic cache stays dormant (deterministic + LLM paths unaffected; `OPENROUTER_API_KEY` present). Provision `vector` + re-run `20260876` to enable — optional.
- **LIVE-1 remaining:** `INTERNAL_CRON_TOKEN` + reminder/prewarm crons, CI runner + isolation-in-CI, alert delivery, **7-day cron clock** (calendar-critical, gates P7). All owner-provisioning.
- **W2 client release flag** is a mobile-build concern, not a VPS one (the edge now serves the W2 endpoints).
