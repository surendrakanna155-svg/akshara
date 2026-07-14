# Deployment Checkpoint — 2026-07-14 · Pre-Freeze Hardening (PFH) migrations + edge

**Status:** ✅ COMPLETE & VERIFIED · **Operator:** autonomous (owner-authorized "complete any safely deployable pending pre-freeze hardening") · **Scope:** Akshara namespace only (Velora/n8n untouched)
**Context:** deploys the pre-freeze adversarial-hardening fixes that were blocked only by VPS access (RECON-2 reclassified this work as PFH, not P4 — the fixes are valid and preserved).

## 1. What was deployed
- **3 additive migrations** `20260879`–`20260881`: `20260879` waiver FK/CHECK hardening (RT-9-2 — `student_clearance_waivers` gained FK on student_id/maker_id/checker_id + `CHECK (checker_id<>maker_id)`), `20260880` `comm_broadcasts` search indexes (RT-11-6 — org/school btree + `lower(title)` trigram GIN), `20260881` `finance_invoices` `lower(invoice_number)` functional search index (RT-11-7).
- **8 edge backend files** (round-3 defect-class + perf fixes): the S1–S4 terminal-write guards (`inventory_finance` over-receipt · `inventory_distribution` replacement-fulfill · `payment` capture-once · `admissions` decision-pending), RT-6-1 exam-publish completeness (`exam_administration`), RT-4-1 parent-AI number guard (`parent_insights_ai`), waiver empty-actor SoD (`clearance_waiver`), RT-11-2 late-fee set-based accrual (`finance_late_fee`).
- *(The RT-5-3 branch/franchise gate is a Flutter client change — ships in the signed mobile build at P6, not the edge.)*

## 2. State transition
| | Before | After |
|---|---|---|
| Migration head | `20260878` | **`20260881`** |
| Edge `/health` version | `67f57ef2` (2026-07-14T12:32Z) | **`abb5b9f9`** (2026-07-14T16:40Z) |

## 3. Process (proven recipe)
1. **Backup:** `akshara-backup.sh manual` → `akshara_db_20260714T163650Z_manual.dump.enc` (encrypted, ledgered) + edge dir `cp -a` → `functions_bak_predeploy_20260714_prc-pfh`.
2. **Migrations:** staged to `/tmp`, applied each via `docker exec -i … psql -v ON_ERROR_STOP=1 -U supabase_admin -d akshara_db` (idempotent skip-if-applied), recorded each in `supabase_migrations.schema_migrations (version, name)`.
3. **Edge:** dry-run rsync (confirmed exactly the 8 files) → real rsync (no `--delete`, tests excluded) → `build_info.json` → `abb5b9f9` → `docker restart akshara-edge`.

## 4. Verification (all ✅)
- DB: head `20260881`; 4 waiver constraints live (`clearance_waiver_{student,maker,checker}_fk` + `clearance_waiver_sod_check`); 3 new indexes live (`idx_comm_broadcasts_org_school`, `idx_comm_broadcasts_title_trgm`, `idx_finance_invoices_school_number_lower`).
- Edge: `/health` version `abb5b9f9`; `/health/ready` `database:true`. Guard code live in deployed files — over-receipt `quantity_received + $2 <= quantity`, replacement `replacement_status='approved'`, payment `status <> 'captured'`, admissions `decision='pending'`, late-fee `unnest($3::uuid…)` all present.
- Edge startup logs clean (no error/exception); `root-n8n-1` Up 2 months (untouched).

## 5. Rollback (if ever needed)
- DB: restore `akshara_db_20260714T163650Z_manual.dump.enc`; migrations are additive (forward-fix preferred).
- Edge: `cp -a /opt/akshara/functions_bak_predeploy_20260714_prc-pfh/. /opt/akshara/functions/` + `docker restart akshara-edge`.

## 6. Roadmap impact
- All pre-freeze-hardening backend fixes + integrity/perf migrations are now **live on prod**. Repo head == deployed head again (`abb5b9f9` / `20260881`).
- This is **pre-freeze hardening**, not P4 (RECON-2). The canonical sequence continues at **PRC-A**.
