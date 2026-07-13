# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file the executor reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** the full history lives in the journal (`IMPLEMENTATION_PROGRESS.md` — incl. the RECON-1 catch-up block) and the roadmap §0/§0b. Headline state: **P2 ✅ · P1 non-gated lane ✅ (+GS-1..3) · P3-AI-1 ✅ CERTIFIED · P3-AI-2 🔶 hardening · K-1 KIE ✅ (local) · K-2 QP engine 🔶 hardening · prod deployed to `20260866` (2026-07-09) with live RLS zero-leak + backup GREEN.**

---

## ▶ CURRENT (post-RECON-1, 2026-07-10)

**RECON-1 ✅ COMPLETE (this commit)** — tracking reconciled to reality; derived progress **54.8%** (Wave Ledger §0b; ✅=1 · 🔶=0.5 · never estimated).

**Active waves (parallel, disjoint ownership — never two implementation agents on one module):**

1. **P3-AI-3 — W2 Hardening & Closure**: 🔶→**HARDENING EXIT MET 2026-07-11** (pending only P7 for 🟩).
   Full W2 surface landed: W2.0a/b · W2-GATE · W2.S · W2.2–2.6 · **W2.1** (briefs/digests, prewarm cron ops-gated) · **W2.7** (ops worklists + client deep-links) · **W2.8** (pgvector semantic cache, 3-layer dormant: guarded migration/runtime probe/env-gated embedder) · **W2.9** (truth-in-naming, closes AI-6) · full audit tail (atomic quota reservation A5 · injection fences A6 · cost-panel A2 · quick-action UX A3 · search pagination+categories A4 · teacher-exam scoping A1).
   Audit rounds: R2 (1 P0 + 4 P1 + 8 P2 → fixed) → R3 **clean** → new-batch R4 (1 P1 RBAC-cohort narrative + 1 P2 finance paging + 3 P3 → fixed `df47a768`) → R5 verify (all fixed; found P2 cron-cohort + P3 sweep-order → fixed `34ccbdbd`) → **R6 verify clean = 2nd consecutive clean round → EXIT**.
   Owner/ops residue on P0-LIVE-1 (not code): migrations `20260867`+…`20260876` deploy before W2 flag · pgvector provisioning + `AI_EMBEDDINGS_API_KEY` + Stage-2 name-swap threshold tuning · `INTERNAL_CRON_TOKEN` for brief-prewarm + drain crons.

1b. **P1-PROD-22 — Staff Face ID attendance**: 🔶→**HARDENING EXIT MET 2026-07-12** (pending only P7 + device residue for 🟩).
   Full build landed (slices 1–4, `3e46a87b`→`db4a6574`): enrollment backend (mig `20260877`) · unified server matcher (0.82 env-clamped, fail-closed) · Flutter device layer (geolocator anti-mock · mlkit blink-liveness · MobileFaceNet/tflite embedder, FAIL-LOUD until the model asset ships) · manual-request fallback end-to-end (list endpoint + staff CTA/dialog + approver queue + `approveStaffAttendance`).
   Audit rounds R1–R5 (7 P1 found+fixed: migration-abort · NaN fail-open · offline optimistic-lie→onlineOnly · dead prod 422-mapping · photo-swap still guard · client route guard · self-approval SoD + decide race); **R2+R3 clean → built-surface exit; R4 fixed; R5 verify clean → lane exit**.
   **Owner/device residue (⏳/👤, not code):** license-cleared `mobilefacenet.tflite` into assets/models/ (verify 192-d output shape) · on-device E2E run (design §8: iOS BGRA rows · EXIF-mirror tags · front-cam mirroring) · `FACE_MATCH_MIN_SIMILARITY` pilot tuning · mig `20260877` deploys with LIVE-1 batch.
   ⚠ ERP lane works in linked worktree `Akshara_ERP-drp` (shared-dir branch collisions ×2 on 2026-07-11).

1c. **SCE-1 — Student Clearance / No-Dues Engine**: 🔶→**MODULE COMPLETE 2026-07-12** (SHIP-ready; prod only via P7). Built slices 1–4 + per-slice audits + 2 final ship-gate audits (`3f020a84`→`bbd4e812`, both final audits 0 P0/P1): contributor-registry engine + per-lifecycle block-vs-warn policy → wired the live TC no-dues gate (authoritative finance NET, fail-closed) → dues-WAIVER maker-checker (SoD, single-use, immutable TC snapshot, revoke-deadlock escape) → client report/waiver/approver UI. **Honesty law:** Finance (authoritative, absorbs TRN-9 transport + inventory demands) + Inventory tracked; **Library (member-name keyed) + Hostel (mock) = `not_tracked`, surfaced never fabricated.** Block-vs-warn = data-driven `LIFECYCLE_POLICIES` (exit=finance-blocking preserving SIS-D1; progression=advisory), owner-flippable.
   **Status-endpoint bypass CLOSED 2026-07-12** (owner-approved): every transition to `transferred` — PATCH /status, PUT /students/:id, AND the TC engine — now enforces the shared no-dues gate (`enforceTransferClearance`, fail-closed, waiver-aware); verify-audit clean. **👤 STILL OPEN owner decision:** `graduated` is DELIBERATELY ungated — should bulk cohort graduation hard-block on dues like a transfer? (don't guess). **Other ledgered:** library/hostel flip to tracked when a real student-keyed ledger exists (no engine change) · mig `20260878` deploys with the LIVE-1 batch · (info) createStudent can INSERT a new student as transferred — no-dues creation, not a bypass.
1d. **P1-SEC-1 (runnable slice) — Biometric App Lock**: 🔶→**HARDENING EXIT MET 2026-07-13** (only the runnable portion of P1-SEC-1; other sub-items stay blocked/owner). Device biometric-only App Lock (no PIN fallback): cold-start lock, background→grace(15s)→re-lock, success-only unlock, enable-requires-biometric, appearance-settings toggle (`lib/core/security/app_lock/`, `lib/app/app.dart`). **Round-law R1–R4:** R1 fixed F1 **P0** (re-lock armed on the resume-handshake states → `paused`/`detached` only, via a pure predicate) + F2/F3 P1; **R2** found the F3 escape did **not** actually work — **P0-1**: the sign-out escape used `showDialog`, which THROWS in the `MaterialApp.router` builder (no Navigator ancestor) → permanent lock-out; fixed with an INLINE confirm (+ P1-1 privacy scrim, P2-1 phantom re-lock, P2-2 dead back-block removed, P3 stranded-UI); **R3** P2 earliest-background-mark (fail-open direction) + P3 polish; **R4 CLEAN** → 2 consecutive material-finding-free rounds → EXIT. `9606fc24`→`96a4c84b`; flutter FULL **+3956 ~1** · analyze 0 (verified via captured exit code — the `| tail` masking bug that hid a stale golden + 2 HR-test crashes was found & fixed here, `a6de664c`).
   **👤 LEDGERED follow-up (surface; not blocking):** the Dart privacy scrim cannot guarantee it paints before the OS app-switcher snapshot (iOS captures at `resignActive`) — full closure needs native **`FLAG_SECURE`** (Android) + iOS snapshot blur. **Owner decision:** global screenshot suppression (blocks ALL screenshots always) vs enable-toggled (only while App Lock is on)? (don't guess). **Other SEC-1 sub-items remain:** session-revoke live-proof (⏳ LIVE) · TLS cert pinning (⏳ prod cert) · root/jailbreak detection (device/plugin) · GCP Android key restriction (👤).
2. **K-2 — QP Engine Hardening Program** (Knowledge lane, `curriculum/**` — disjoint from ERP).
   Round status: audit (2 P0 + 4 P1) → R1–R9 → prod-readiness cert **GO (scoped)** → Phase-1 sanitizer hardening landed (`835f39e4`).
   Continue: OCR artifact cleanup · **deterministic template expansion** · **Blueprint Library (CBSE·AP·TS·NEET·JEE Main·JEE Advanced)** · graph-degree · recency · difficulty/Bloom · MCQ + gated-AI validation.
   **Exit = 2 consecutive clean independent audits → K-lane feature freeze (K-4 re-cert).** ⚠ In-flight uncommitted: `qpgen/templates.py` — land with its round.
4. **P0-LIVE-1 — Consolidated live checklist** (owner-provisioned): ① **AI migrations `20260867`+/`20260873` deploy — MUST precede the W2 release flag reaching any live build** · ② outbox drain · ③ COM-4 cron token · ④ reminder crons · ⑤ live `ai_*` probes · ⑥ off-site R2 creds · ⑦ alert delivery · ⑧⑨ CI + isolation-in-CI · ⑩ **7-day cron clock (calendar-critical — gates P7)**. Items ⑪⑫⑬ ✅ 2026-07-09.

**Then (strict order):** CFC-1 Code Freeze Checklist (10 items, evidence per item) → FREEZE-1 Feature Freeze → P4 → P5 → P6-VAL-1 → P6-PILOT-1 → P6-BETA-1 (5–10 real schools) → P7 → P8.

### 👤 Owner-decision batch (surface now; none pauses the active lanes)
- **P0-LIVE-1 provisioning:** R2 creds · `INTERNAL_CRON_TOKEN` · CI runner (starts the 7-day clock).
- **FREEZE-1 K-lane carve-out:** does K-2 block the ERP feature freeze, or run past it?
- **P6-BETA-1 cohort:** recruit 5–10 beta schools (timing + onboarding owner).
- **App Lock screenshot suppression (SEC-1 follow-up):** native `FLAG_SECURE`/iOS-blur — global (block ALL screenshots always) vs enable-toggled (only while App Lock is on)? (device-verified; not blocking the runnable slice).
- Identity cluster (P1-CODE-4) · module scope (P1-CODE-6/7/8) · PAR3-UPLOAD · PRI-4/5 scheduled-send · HWK-1/C6 basis re-check · A2 ratification · K-3 promotion timing.

### EOS gate (per active wave)
- **P3-AI-3 / K-2 rounds:** each round closes on its audit artifact + fixes + full regression (`flutter analyze` 0 · `flutter test` no NEW failures · `deno test`+`deno check` green for touched `supabase/**` · KIE/QP 196-test regression green, KB SHA-identical) — commit only after the round's EOS PASS.
- **Tripwires unchanged:** no behaviour/governance/money/RBAC/isolation regression; goldens deliberate; **never start the next wave with an open P0 or EOS BLOCKED.**
- **State law:** 🔶 waves are never reported complete; W2 and the QP engine graduate only at their hardening exits (and 🟩 only via P7).

### Regression required (per wave)
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures · K-lane: full engine+KIE regression, knowledge base unmutated.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) items run the moment the owner provisions them.
