# Deployment Checkpoint — 2026-07-14 · P4-RT-1 round-1 money/document-integrity fixes (edge)

**Status:** ✅ COMPLETE & VERIFIED · **Operator:** autonomous · **Authorization:** owner GO (2026-07-14, in-session go/no-go) · **Scope:** Akshara namespace only (Velora/n8n/Redis untouched)

## 1. What was deployed
Edge code refreshed `9bbf8630` → **`67f57ef2`** — a **surgical 3-file** update (the P4-RT-1 round-1 fixes, `d5255c62`), **no migration**:
- `_shared/finance/finance_refunds_repository.ts` — RT-3-1/F1 **P0**: terminal `AND refund_status='pending'` guard on approve + reject.
- `_shared/finance/finance_collections_repository.ts` — RT-3-2/F2 **P1**: unconditional `AND collection_status <> 'cancelled'` on cancel.
- `_shared/sis/sis_certificates_repository.ts` — RT-10-1 **P1**: terminal `AND status = $5` guard on the TC transfer write.

## 2. State transition
| | Before | After |
|---|---|---|
| Edge `/health` version | `9bbf8630` (built 2026-07-14T10:22Z) | **`67f57ef2`** (built 2026-07-14T12:32Z) |
| Migration head | `20260878` | `20260878` (unchanged — edge-only deploy) |

## 3. Process (proven recipe, reversible)
1. **Backup:** `akshara-backup.sh manual` → `akshara_db_20260714T122950Z_manual.dump.enc` (encrypted, ledgered) + `cp -a /opt/akshara/functions` → `functions_bak_predeploy_20260714_rt1` (7.9M).
2. **Dry-run rsync** confirmed exactly 3 files change (no test files, `--exclude` tests/snapshots/md, no `--delete`).
3. **rsync** the 3 files → `/opt/akshara/functions`, regenerated `_shared/build_info.json` (SHA `67f57ef2`), `docker restart akshara-edge`.

## 4. Verification (all ✅)
- `/health` → ok, version `67f57ef2`; `/health/ready` → `database:true`.
- Money routes auth-gated: `/finance/refunds` → 401, `/finance/collections` → 401.
- **Guard code live in the deployed files:** `refund_status = 'pending'` ×3 · `collection_status <> 'cancelled'` ×1 · `AND status = $5` ×1.
- Edge startup logs clean (no error/exception); requests serving 200/401 as expected.
- Isolation: `root-n8n-1` Up 2 months (untouched); `akshara-edge` freshly restarted.

## 5. Rollback (if ever needed)
- Edge: `cp -a /opt/akshara/functions_bak_predeploy_20260714_rt1/. /opt/akshara/functions/` + `docker restart akshara-edge`. (Or `git checkout 9bbf8630 -- supabase/functions` and re-rsync.)
- DB unaffected (no migration). Predeploy DB dump `...122950Z_manual` on disk regardless.

## 6. Roadmap impact
- The live edge now enforces the round-1 money/document-integrity guards → the P0 refund double-approve + 2 P1s are **closed on prod**. (Exposure had been nil — the financial tables are empty on this fresh pilot — but the guards are now live before any real financial usage.)
- **Still pending (next window):** RT-9-2 waiver FK/CHECK migration (P2, latent); RT-4-1 parent_insights AI number-guard (P2); the data-bearing isolation positive probe + live money-race re-verify once the pilot generates data. Off-site backup (R2 creds) + 7-day cron clock remain owner-provisioned LIVE-1 items.
