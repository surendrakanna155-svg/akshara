# Curriculum Intelligence — Rollback Plan

**Date:** 2026-07-06 · Principle: **additive-only** changes make rollback = *disable/ignore*, never destructive down-migrations (see [`../audits/BACKWARD_COMPATIBILITY_PLAN.md`](../audits/BACKWARD_COMPATIBILITY_PLAN.md) §3).

---

## 1. Data lane (CI-A*/CI-B*)

| Failure | Rollback |
|---|---|
| Repository corruption / bad batch | The workspace is isolated (D-2) — delete the affected `downloads/incoming` batch; verified resources are immutable-by-convention; restore from the last `CHECKPOINTS.md` state. App entirely unaffected |
| Wrong/poisoned extraction dataset (B-waves) | Datasets are versioned files consumed only by explicit code-wave migrations; discard the dataset version; nothing downstream auto-consumes |
| License problem discovered post-download | Quarantine per spec (RESTRICTED state), record in LICENSE_REPORT, purge file, keep metadata tombstone (traceability without content) |

**Blast radius: zero** — the data lane cannot break the app by construction (no shared files).

## 2. Code lane (per wave)

| Wave | Rollback lever | Residual state after rollback |
|---|---|---|
| CI-C1 | Template-absent path = legacy behaviour, so: stop supplying `blueprint_template_id` (client flag) → system behaves exactly as certified. Worst case `git revert` the wave commit | `edu_blueprint_templates` table remains, unused (harmless) |
| CI-C2 | Expansion rows are additive: mark new template rows `status='archived'`/remove seed rows by board key; versioning columns nullable | Grade-10 seed untouched throughout |
| CI-C3 | Export version flag → v1 renderer; multi-set endpoint unpublished from client | set_code columns dormant |
| CI-C4 | Tagging assist behind flag; suggestions table ignored | nullable FKs remain |
| CI-C5 | Validation engine is advisory pre-publish: disable its gate flag → flow returns to human-moderation-only (certified path) | scores/revisions tables dormant |
| CI-C6 | Ingestion endpoint feature-flagged; candidates already respect the moderation gate, so even mid-failure nothing reaches the active bank | staged candidates can be bulk-rejected via existing moderation |
| CI-C7 | Gating default-allow: remove entitlement rows → everything open as today; profile = optional request field, omit it | profile config rows dormant |
| CI-C8 | Link table read-only to exam flow; drop usage from client | link rows harmless |
| CI-C9 | Sync is an external job over the workspace; stop the job | none in-app |
| CI-E1 | Dormant by definition — nothing to roll back (tables empty, zero surface) | — |

**Universal levers (in order):** 1) per-module client flag (`educationApiEnabled` pattern / new sub-flags) → 2) omit the new optional input (template/profile/set) → 3) `git revert` the single wave commit (waves are one commit unit by rule) → 4) leave additive schema in place (never down-migrate a deployed table on the pilot; document as dormant).

## 3. Deployment safety

- Migrations deploy via the established `/deploy` recipe + ledger; every wave's migration list recorded in the wave ledger row ([`MILESTONE_TRACKER.md`](MILESTONE_TRACKER.md)) so the exact revert set is always known.
- Live-cert (original 20) runs post-deploy per wave — a red case triggers immediate lever #1/#2 before diagnosis.
- The pilot's nightly backup (accepted ~24h RPO) covers catastrophic cases; nothing in this program stores money or identity data, so restore risk is bounded to education content.

## 4. Rollback drills

- CI-C1 exit includes one rehearsed rollback: generate with template → flip flag → verify legacy golden output same-session.
- CI-C6 exit includes bulk-reject drill of a staged candidate batch.
