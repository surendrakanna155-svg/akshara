# Fresh Session Handoff — 2026-07-14

**Branch:** `feature/data-reliability-platform` (ERP lane, worktree `Akshara_ERP-drp`) · **Tip:** `68f8bb26` · **Tree:** CLEAN · **Remote:** pushed & current (`origin/feature/data-reliability-platform`).
**Read this + [`../roadmap/NEXT_ACTIVE_WAVE.md`](../roadmap/NEXT_ACTIVE_WAVE.md) (⏸ PARKED marker) first. Recovery-first — recover, don't recreate.**

---

## 1. Current project state
- ERP implementation lanes are all at their hardening exits: **P3-AI-3 (W2)**, **P1-PROD-22 (Face ID)**, **SCE-1 (Clearance)**, **P1-SEC-1 (Biometric App Lock)** — all done.
- **P0-LIVE-1 ① (prod migration+edge deploy) landed 2026-07-14** (see below).
- **CFC-1 (Code Freeze Checklist): ERP-side ≈8/10.** Green: items 1 (TODO/FIXME), 2 (mock-in-prod, Trust-Hub gated), 3 (fake/stub APIs), 4 (debug-in-release), 6 (commented-out), 7 (temp-bypass), **8 (migration head==deployed — GREEN after the deploy)**; item 5 (W2 flag sequencing) prerequisite met. **Remaining: items 9 (clean tree ALL lanes) + 10 (no open P0/P1 anywhere) — CROSS-LANE (curriculum + K-2), not ERP.**
- Parallel **K-2 (QP/QIE Knowledge lane)** runs in the main worktree (`Akshara_ERP` → `feature/qp-content-readiness`, **local-only, 836+ commits, uncommitted work**). **Do NOT touch `curriculum/**` or that branch.**

## 2. Completed this session
- **P1-SEC-1 Biometric App Lock** — 4-round hardening exit; found the real P0 (sign-out escape threw in the `MaterialApp.router` builder → inline confirm) + recents scrim + earliest-mark fix.
- **Unmasked the `flutter test | tail` bug** (a red suite reported green) + fixed the HR-screen SharedPreferences crash.
- **CFC-1 pre-clearing** items 1/3/4/6/7 + item 2 Trust-Intelligence-Hub deep-link violation (mock cross-school data) gated & regression-locked.
- **6-item owner-decision batch (approved):** CODE-8 Alumni hidden, CODE-7 Hostel residence-lite, CODE-6 out-of-Finance labels, PAR3 reference-only, graduated keep-ungated, CODE-4 PSID/change-phone deferred.
- **False-"posts to Finance" honesty sweep** across HR/transport/alumni/hostel + chart subtitles (CODE-6 defect class; final grep 0).
- **Pushed the ERP branch to origin** (443 commits) — was local-only.
- **🚀 P0-LIVE-1 prod deploy** (owner-authorized) — full details in [`DEPLOY_CHECKPOINT_20260714_LIVE1.md`](DEPLOY_CHECKPOINT_20260714_LIVE1.md).

## 3. Current production / VPS state
- **VPS** `46.28.44.46` (`srv1023946`), Akshara namespace, isolated from Velora/n8n/Redis/MySQL (untouched — `root-n8n-1` Up 2 months).
- **DB `akshara_db`:** migration head **`20260878`** (197 applied); new tables `ai_call_log`, `ai_call_reservations`, `ai_persona_memory`, `staff_face_enrollments`, `student_clearance_waivers` present with RLS created by their migrations.
- **Edge `akshara-edge`:** code **`9bbf8630`**, `/health` ok, `/health/ready` `database:true`; SCE-1/Face-ID/W2 routes live (401 auth-gated).
- **Backups:** nightly encrypted backup healthy (through 2026-07-14); 2 fresh predeploy rollback points on disk. ⚠ **Off-site is NOT configured** (`RCLONE_REMOTE` unset → LOCAL-ONLY, violates 3-2-1) — needs owner R2/rclone creds.
- **pgvector** unprovisioned → W2.8 semantic cache dormant by design (LLM path works — `OPENROUTER_API_KEY` present).
- ⚠ **SSH control-master (`~/.ssh/akshara-cm.sock`) has since dropped** — re-establish (the `ssh -fN -M -S … -o ControlPersist=12h root@46.28.44.46` command) before any further VPS work.

## 4. Remaining roadmap status
- **Next gate = CFC-1 → FREEZE-1.** ERP-side items are ≈8/10; the only remaining CFC gates (9 clean-all-lanes, 10 no-open-P0/P1) require the **K-2 hardening exit** (parallel lane) and/or an **owner FREEZE-1 K-lane carve-out**.
- **Then (strict order):** FREEZE-1 → P4 (Red Team) → P5 (fixes) → P6-VAL-1 → P6-PILOT-1 → P6-BETA-1 → P7 (Prod Cert) → P8 (GA). All sequenced after CFC-1/FREEZE-1 — do NOT start early.
- **No ERP implementation work is currently runnable** — verified per-item (N+1 already clean, router coverage substantial, CODE-4 DB/RLS live-gated, PRI-4/5 built [scheduled-send needs cron], A2/K-3 Knowledge-lane).

## 5. Exact next starting point
**Await EITHER the K-2 hardening exit OR the owner's FREEZE-1 K-lane carve-out decision.** When either lands:
1. Run the **CFC-1 gate** — all 10 items in one sweep on one commit, evidence per item under `docs/engineering/eos/`. ERP-side 1–8 already green; item 9 (clean tree) needs the curriculum lane committed; item 10 (no open P0/P1) needs the K-2 exit (or carve-out).
2. On CFC-1 PASS → declare **FREEZE-1** (feature freeze) → begin **P4-RT-0** (Red Team prep).
- If the owner instead opens **LIVE-1 provisioning** (R2/cron/CI/7-day clock), those live items become runnable independently (they gate P7, not CFC-1).

## 6. Owner decisions still pending
1. **FREEZE-1 K-lane carve-out** (the gating one): does K-2 block the ERP feature freeze, or does freeze proceed carving out the K-lane? — determines whether CFC-1→FREEZE-1 can run now for ERP.
2. **P0-LIVE-1 provisioning:** off-site R2/rclone creds (backup is local-only) · `INTERNAL_CRON_TOKEN` + reminder/prewarm crons · CI runner + isolation-in-CI · **7-day cron clock** (calendar-critical — gates P7).
3. **pgvector provisioning** (optional) → enables the W2.8 semantic cache (re-run `20260876`).
4. **P6-BETA-1 cohort** — recruit 5–10 real beta schools (timing/onboarding).
5. Minor residuals (non-gating): identity DB/RLS hardening timing (CODE-4 live parts) · PRI-4/5 scheduled-send (needs the cron) · HWK-1/C6 · A2 ratification · K-3 promotion timing.
