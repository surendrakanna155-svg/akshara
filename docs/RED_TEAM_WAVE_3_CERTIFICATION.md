# AKSHARA — Red Team Wave 3 Certification

**Status:** ✅ **PRODUCTION CERTIFIED (2026-06-27) — live 24/24** · **Regression: Wave 1 26/26 · Wave 2 25/25**
**Wave:** RED_TEAM **Wave 3** — "Session & Authorization Enforcement."
**Scope source of truth:** [`RED_TEAM_MASTER_TRACKER.md`](./RED_TEAM_MASTER_TRACKER.md) (RT-16..RT-23) + [`RED_TEAM_COMPLETION_ROADMAP.md`](./RED_TEAM_COMPLETION_ROADMAP.md) (Wave 3). No new features, no roadmap expansion, no new audit — this closes the tracker's Wave-3 findings only.
**Branch:** `feature/scope-trim-school-build`
**Migration:** none (edge-function changes only).
**Deploy:** 7 edge files synced to `/opt/akshara/functions` on the VPS pilot and `akshara-edge` restarted (no DB migration).
**Live cert:** `scripts/qa/live_cert_red_team_wave3.py` → **24/24** against the live VPS pilot, using edge-minted scoped JWTs that reference **real `sessions` rows** and the **live membership `permissions_version`**, over HTTPS to `https://akshara.veloraunisexsalon.com`.

---

## 1. Verdict

**PRODUCTION CERTIFIED.** All **8 Wave-3 findings** (3 High, 2 Medium, 3 Low) are closed and verified on the live deployment. This wave is *enforcement hardening* on the hot auth path — it makes a stolen/revoked token and a demoted user lose access on the **very next request** instead of waiting out the 15-minute token TTL, and it puts the missing authorization gates on the payment, approval-cancel, audit-ingestion and "write-via-view-slug" routes, plus fails the Razorpay webhook closed.

It is **not** a separate "Security Certification" track — it fixes exactly the eight red-team findings RT-16..RT-23 and nothing more.

## 2. Gate results

| Gate | Result |
|------|--------|
| `flutter analyze` | **No issues found** (no Dart changed; gate re-run for safety) |
| `flutter test` | **2440 passed / 1 skipped / 0 failed** |
| `deno test` (`supabase/functions/_shared`) | **867 passed / 0 failed / 2 ignored** (+7 new `session_validation_test.ts`) |
| Live cert (`live_cert_red_team_wave3.py`) | ✅ **24/24** vs live VPS pilot |
| **Regression — Wave 1** (`live_cert_red_team_wave1.py`) | ✅ **26/26** (no RT-01..08 regressed) |
| **Regression — Wave 2** (`live_cert_red_team_wave2.py`) | ✅ **25/25** (no RT-09..15 regressed) |

The live cert is the authoritative gate.

## 3. Methodology — how the enforcement is actually proven

Wave 3's unit-under-test is the **edge authorization path**, so the cert is HTTP-based (like Wave 1) and runs against the **deployed** code. The key fidelity upgrade: a cert token now references a **real, live session row** and carries the **live membership `permissions_version`** — exactly what a genuine token does — so the new per-request check (RT-16/17) treats cert traffic identically to real traffic. The cert then drives each finding's exploit and its legitimate counterpart:

- **Revoke-then-call:** mint a live token → hit a protected endpoint (200) → set `sessions.revoked_at` → hit it again with the **same token** → **401**.
- **Demote-then-call:** mint a live token → 200 → bump `school_memberships.permissions_version` → same token → **401 `PERMISSIONS_STALE`** → restore the version (DB left unchanged).
- **Wrong-scope / wrong-permission** probes get a clean **403**; the legitimate scope/permission gets through (200, or a non-403 like 422 that proves the gate passed before validation).

Every fixture (seeded sessions, the test approval, ingested audit rows, the parent payment intent) uses dedicated `cf3…` ids and is cleaned up; the script is re-runnable and leaves the live DB untouched (verified: 0 orphans after the run).

## 4. Headline live evidence (post-deploy, 24/24)

| RT | Finding | Live proof |
|---|---|---|
| **RT-16** (High) | Logout/revoke ineffective ≤15 min | Valid token → `GET /approvals/pending` **200**; after `revoked_at` is set, the **same** token → **401 `SESSION_REVOKED`**. |
| **RT-17** (High) | Demotion ineffective ≤15 min (`permissions_version` dead) | Token at the live version → **200**; after the membership version is bumped, the **same** token → **401 `PERMISSIONS_STALE`**; a freshly-minted token at the new version → **200**. |
| **RT-18** (Med) | Entitlement enforcement env-flag default-off | `ENTITLEMENT_ENFORCEMENT=true` confirmed live on `akshara-edge` (deploy-precondition — see §6). |
| **RT-19** (Med) | Payment init/confirm auth-only | School scope → `POST /payments/intents/initiate` **403** and `/confirm` **403**; **parent** scope passes the gate (**201** in stub mode). Matches `payment_intents` RLS (parent-only writes, pinned to `payer_user_id`). |
| **RT-20** (High) | `cancel` bypasses approve permission (workflow DoS) | A school user **without** approval authority → `POST /approvals/{id}/cancel` **403** and the approval stays **pending**; a manager (`manageManagement`) → **200**. |
| **RT-21** (Med) | Audit batch ingestion auth-only (log injection) | A **parent** (relationship) scope → `POST /audit/events/batch` **403**; a **staff** (school) scope ingests a batch **200** (`acceptedCount=1`). |
| **RT-22** (Low) | Writes gated by *view* slugs | All three write routes reject a view-only token **403** and admit a manage-tier token (not 403): `promotions/{id}/track` (`manageAchievementPromotion`), `intelligence/.../parent-meeting-summary` (`manageLessonLogs`), `POST /approvals/audit` (`manageManagement`). |
| **RT-23** (Low) | Webhook signature bypassed in stub mode | A **forged** `X-Razorpay-Signature` → `POST /webhooks/razorpay` **403** — fail-closed even in stub mode (was accepted before). |

## 5. What was fixed (per finding)

- **RT-16 + RT-17** — new `_shared/session_validation.ts` (`assertSessionValid`) called inside `authenticateRequest` (the single chokepoint all 446 authenticated call-sites funnel through). It consults `sessions.revoked_at` (RT-16) and, for membership scopes, compares the token's `permissions_version` to the live `school_memberships` / `organization_memberships` row (RT-17). The decision logic is a pure, unit-tested function (`evaluateSessionState`). **Fail semantics:** definitive states (missing/revoked session, removed membership, stale version) → 401; an infrastructure lookup error throws → 500, so a transient DB blip never silently logs everyone out. The check is active in every real deployment (`loadConfig()` guarantees the service-client config) and is skipped only in DB-less unit tests. No runtime endpoint mutates roles today; demotions land via the DB/migration path, which already increments `permissions_version` (precedent: `20260627110000`), so a stale token is caught on its next request.
- **RT-18** — deploy-precondition (no code change). `ENTITLEMENT_ENFORCEMENT=true` is set on the live `akshara-edge` and asserted by the cert. The default stays OFF by deliberate design (safe "dark" deploys — see `entitlement_enforcement.ts`); the requirement is documented as a go-live checklist item for every environment.
- **RT-19** — `requirePaymentWriteScope` gate added to `handleInitiatePayment` / `handleConfirmPayment`: parent scope with a `school_id`. This mirrors the `payment_intents` RLS (only `parent` scope may write, pinned to `payer_user_id`; school scope is read-only) and turns a wrong-scope caller into a clean 403 instead of an RLS-driven failure.
- **RT-20** — `handleDecision` now loads the approval and authorizes **every** decision including `cancel`. Cancel requires approval authority for the type (or `manageManagement`), or being the original requester withdrawing their own request. The cancel path previously skipped the entire authorization block.
- **RT-21** — `handleAuditBatchUpload` now requires a **staff** scope (`school`/`organization`). Relationship users (parent/student) — the largest, least-trusted population and the "pollution" vector — can no longer write to the forensic trail. Accepted events remain server-pinned to the actor, tenant and school (defense in depth). The client upload queue already bounds retries, so a rejected relationship-scope upload degrades cleanly.
- **RT-22** — the three write routes that were gated by *read* slugs now require *manage* slugs: `handleTrackPromotion` → `manageAchievementPromotion`; `handleGenerateParentMeetingSummary` → `manageLessonLogs`; `handleRecordApprovalAudit` → `manageManagement`. (`POST /director/summary` was correctly excluded by the validation pass — it is read-only.)
- **RT-23** — the webhook signature check is decoupled from `stubMode`: an invalid/forged signature is now **always** rejected unless an operator explicitly sets `RAZORPAY_ALLOW_UNSIGNED=true` for local dev. Previously `if (!valid && !stubMode)` accepted any signature while stub mode was on (the default, and live on the pilot).

## 6. Deploy-precondition checklist (RT-18 / RT-23)

These items are **environment configuration**, verified live for the pilot and to be re-confirmed on every target deploy:

| Env var | Pilot value (confirmed live) | Required for |
|---|---|---|
| `ENTITLEMENT_ENFORCEMENT` | `true` | RT-18 — entitlement gates actually enforce |
| `RAZORPAY_STUB_MODE` / `RAZORPAY_KEY_ID` | stub on, no creds | RT-23 — no real money flows yet; **flip stub off + set creds before payments go live** |
| `RAZORPAY_ALLOW_UNSIGNED` | unset (→ false) | RT-23 — webhooks fail-closed in every non-dev environment |

## 7. Operational note — existing sessions after deploy

Because RT-17 now rejects a token whose `permissions_version` no longer matches the live membership, any pilot token minted **before** the most recent version bump (`20260627110000`) is rejected on its next request and the client transparently refreshes to a current token (refresh re-resolves the live version). This is the intended security behaviour — a one-time, transparent re-auth at most. Live sessions (not revoked) are unaffected; the Wave-1 regression (26/26) confirms legitimate authenticated traffic across finance/SIS/library/teacher still works through the new check.

## 8. Regression matrix (mandatory)

Per the engagement rules, before certifying Wave 3 the previously-certified waves were re-run live:

| Re-run | Result |
|---|---|
| **Wave 1** (`live_cert_red_team_wave1.py`, RT-01..08) | ✅ **26/26** — no regression |
| **Wave 2** (`live_cert_red_team_wave2.py`, RT-09..15) | ✅ **25/25** — no regression |

No previously-Closed RT issue regressed. Wave 1's mint helper was updated to seed a real session + embed the live `permissions_version` so its synthetic tokens satisfy the new RT-16/17 check — a faithfulness upgrade to the test harness, not a change to what it proves.

## 9. Disposition

RT-16, RT-17, RT-18, RT-19, RT-20, RT-21, RT-22, RT-23 → **Closed** (fixed, deployed to the live VPS pilot, live-certified 24/24, Wave-1 regression 26/26, Wave-2 regression 25/25). Commit hash recorded in `RED_TEAM_MASTER_TRACKER.md` on commit.

**Waves 4–5 remain Open, awaiting owner approval. Wave 4 is NOT started.**
