# ASIP-8 — Production Readiness Report

**Date:** 2026-07-29 · **Lane:** worktree `Akshara_ERP-asip`, branch `feature/asip-support-intelligence`
**Commits:** `c2c370c0` (RC-1…RC-4 + partial RC-5) → `9bcdd71f` (RC-5 complete)
**Prior authority:** [`ASIP_FINAL_CERTIFICATION_AUDIT_2026-07-21.md`](ASIP_FINAL_CERTIFICATION_AUDIT_2026-07-21.md) · [`ASIP_REMEDIATION_REGISTER.md`](ASIP_REMEDIATION_REGISTER.md)

---

## Verdict

> ### 🟡 ENGINEERING-COMPLETE · **NOT PRODUCTION-CERTIFIED**
>
> All five mandatory pre-deployment conditions (RC-1…RC-5) are remediated and the
> full regression is green. **Production certification cannot be granted**, because
> the 23-check live certification has not been run — and, as established below, it
> **cannot** be run without first deploying ASIP-8, which is owner-gated.

---

## 1. Remediation status — all five conditions closed

| # | Audit ID | Condition | Status |
|---|---|---|---|
| RC-1 | P1-D | Migration version collides with the trunk | ✅ Remediated |
| RC-2 | P1-A | KB title not clamped → rolls back the school-facing resolution | ✅ Remediated |
| RC-3 | P1-B | `/support-status = resolved` is a divergent resolve path | ✅ Remediated |
| RC-4 | P1-C | `handlePlatformResolve` not idempotent | ✅ Remediated |
| RC-5 | P1-E | Best-effort mirror has no reconciliation | ✅ Remediated |

### What changed, and why it was wrong before

**RC-1** — `20260920000060_support_kb.sql` collided with the trunk's
`finance_recovery_minor_backfill`. Renumbered to **`20260920000210`**.
The register's recorded target ("≥ `…100`") was **stale**: the trunk had since
taken …100/110/130/140/160/170/180/190/200. The new slot was verified free across
every local branch (global maximum was `…000201`, on `integration/aip-onto-w0`).
ASIP-1..7's migrations were confirmed **byte-identical** on `release/v1.0-playstore`,
so exactly one file had to move.
The validation test now locates the migration by the `*_support_kb.sql` **suffix** —
hardcoding the version is precisely what made a necessary renumber break the test —
plus a guard that exactly one such migration exists, so a renumber can never
silently become a copy.

**RC-2** — `module_key` is client-supplied and bounded **nowhere**: no DB
constraint, no request validation. It flows into `clusterTitle()`, whose output is
written under `CHECK (char_length(title) <= 400)`. The clamp therefore lives in
`clusterTitle()` itself, covering both call sites rather than one.
Separately — and more seriously — KB learning ran **inside the resolve
transaction**, so that CHECK violation aborted `propagateResolution()`: the
incident stayed open and the school was never told, while the agent saw success.
Learning now runs in its own transaction *after* the resolve commits. The old
in-transaction comment claiming it "never blocks the resolution" was false.

**RC-3** — `/support-status` accepted `resolved` but writes only the mirror row:
no propagate, no notify, no learn. Now rejected 422 with a message pointing at the
resolve endpoint, expressed as the pure predicate `isSettableSupportStatus()` so
handler and test share one rule, and removed from the web console's dropdown.

**RC-4** — the notify bridge guards `resolved_at` but enqueues the reporter push
**unconditionally**, so resolving incident A and then resolving A's cluster sent a
second push and inflated the KB counters. Settled rows are now filtered out; a
re-resolve is a no-op returning count 0 with no propagation, notification or KB
delta.
⚠ `listClusterIncidentIds` is deliberately **retained** alongside the new
`listUnresolvedClusterIncidentIds` — they are **not** interchangeable. Cluster
*size* (investigation confidence, engineering handoff) must still count every
member. A wholesale import swap would have silently under-reported it; the type
checker caught this.

**RC-5** — four parts:
- `handleCollectEvidence` and `handleTransitionStatus` now run a **full** mirror
  reconcile. The latter previously did a header-only refresh, which registers a
  mirror row with *no evidence* when the create-time mirror had failed — leaving
  the console an incident it could not diagnose.
- **`POST /support/mirror/reconcile`** sweeps a bounded recent window. It
  re-mirrors rather than diffing, because a school session is RLS-walled out of
  the platform-support domain and cannot ask which rows are missing; the bridges
  are upserts, so the question is unnecessary. Auth is credentialed two ways —
  `x-internal-cron-token` (**fail-closed**, and the cron path must name an
  `organizationId` since a scheduler has no org), else a `manageSupport` JWT.
- `autoCluster` now **declines to cluster on an empty signature**. `errorSignature()`
  returns the literal `"none"` when there is nothing to key on, so the fingerprint
  collapsed to `category|module|none` and every evidence-less incident sharing a
  category and module landed in one cluster — inflating cluster size, the
  confidence derived from it, and the KB's `schools_seen`.
- The misleading comment claiming a mirror retry "can re-run via collect-evidence"
  is corrected. No such path existed.

---

## 2. Regression evidence

| Gate | Result |
|---|---|
| `deno check supabase/functions/_shared/support/*.ts` | **0 type errors** |
| `deno test supabase/functions/_shared/` | **2972 passed · 0 failed · 3 ignored** |
| New tests added across RC-1…RC-5 | **+11** |

New coverage: migration located by suffix and exactly-one guard · title clamped at
the CHECK bound · settable-status predicate incl. case-bypass · empty vs real
diagnostic signal and the fingerprint collapse motivating it · reconcile route auth
(401), method (405), `organizationId` requirement (422), and an explicit assertion
that an **unset `INTERNAL_CRON_TOKEN` fails closed** rather than opening the route.

---

## 3. ⛔ Why the 23-check live certification was NOT run

This is a hard blocker, not an omission.

**Measured live state** (read-only queries against `akshara-postgres` / `akshara_db`):

| Object | Live? |
|---|---|
| `support_incident` (ASIP-1) | ✅ present |
| `support_platform_incident` (ASIP-7 mirror) | ✅ present |
| `support_kb_article` (ASIP-8) | ❌ **absent** |
| `support_kb_embedding` (ASIP-8) | ❌ **absent** |

Applied migrations recorded in `supabase_migrations.schema_migrations` for the
`20260920` band: `…000000, …000010, …000020, …000030, …000040, …000050` — i.e.
**ASIP-1..7 exactly. ASIP-8 is not applied.**

**Two independent reasons the cert cannot run meaningfully today:**

1. **6 of the 23 checks require ASIP-8 tables that do not exist live** —
   `kb:learned`, `kb:list`, `rbac:reporter-kb`, `kb:second-incident`, `kb:recall`,
   and the KB half of `cleanup:non-destructive`. They would fail on a missing
   relation, not on a defect.
2. **The cert runs against the deployed edge container**, which serves the
   *previously deployed* bundle. It would therefore certify the code as it was
   **before** RC-1…RC-5, not the remediation just completed. A green result would
   be actively misleading.

Making the cert meaningful requires applying `20260920000210_support_kb.sql` and
deploying the current edge bundle. **That is a deploy, and deployment is
owner-gated** — so it was not done, and no partial or simulated cert was run in
its place.

---

## 4. What remains before ASIP-8 can be certified

Strictly ordered; all owner-gated at step 1.

1. **Owner authorises the deploy** into the unified ERP pilot deployment phase
   (per the register: do **not** deploy or activate ASIP-8 standalone).
2. Apply `supabase/migrations/20260920000210_support_kb.sql` to the live DB.
3. Deploy the current edge bundle so the live container carries RC-1…RC-5.
4. Run `scripts/qa/live_cert_asip_vps.sh <EDGE> <DB> <BASE_URL>` — all 23 checks.
   It is non-destructive by construction (cert-unique failing path
   `/cert-asip-vps/marks`, fully removed at cleanup).
5. On 23/23, mark ASIP-8 **PRODUCTION CERTIFIED** and fold into the canonical trunk.

**Fold-in note:** re-verify the migration ceiling immediately before fold-in.
`…000210` was free across all branches at the time of writing, but the trunk is
actively advancing — this is exactly how RC-1 arose, and how its recorded fix went
stale.

---

## 5. Scope boundaries honoured

- **No deploy. No push.** Both commits are local to `feature/asip-support-intelligence`.
- **No new features, no scope expansion** — every change traces to a numbered audit
  condition.
- The **16 P2 + 19 P3** backlog items from audit §5 remain unactioned; they do not
  gate certification and are scheduled separately.
- ASIP-1..7 remain **PRODUCTION CERTIFIED + LIVE**, not voided by this work.

---

## 6. Sign-off

| | |
|---|---|
| Engineering | ✅ Complete — RC-1…RC-5 remediated, regression green |
| Live certification | ⛔ **Not run** — blocked on an owner-gated deploy (§3) |
| Production certification | ⛔ **Not granted** |
| Deployment | ⛔ Owner-gated, not performed |
