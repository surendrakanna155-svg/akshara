# NIKSHA OS — Release Candidate Execution Log

**Branch:** `release/v1.0-playstore` (worktree `/Users/surendrakanna/Documents/Akshara_ERP-release`)
**Session start:** HEAD `062774ab` · **Started:** 2026-07-28
**Purpose:** resumable state for the RC drive. Update as work lands.

---

## Verified baseline (measured this session, not inherited)

| Gate | Result |
|---|---|
| Full suite at session start | **4316 passed · 1 skipped · 0 failed** (exit 0) |
| `flutter analyze` at session start | **13,008 errors** — all inside `build/ios/SourcePackages/**` |
| `flutter analyze` after fix | **No issues found** |
| Release AAB | **builds** — 132.1 MB (dominated by BUNDLE-METADATA: debug symbols + ~42 MB ProGuard map) |
| Real per-device size | **57.9 MB arm64-v8a** · 50.0 MB armeabi-v7a (via `--split-per-abi`) |
| Emulator available | `emulator-5554`, Android 16 (API 36), 1080×2400 @ 420dpi |

> The AAB was built with a **throwaway keystore generated outside the repo** purely to
> prove the R8/minify/bundle path works. It is not a publishing key and was never
> committed. `android/key.properties` is gitignored; delete it after use.

---

## Landed (committed)

| Commit | What |
|---|---|
| `357f465b` | Analyzer excludes vendored/generated trees; legal site generator + fail-closed publish gate; nginx vhost |
| `f0fcd707` | Startup: 2s splash floor → 400ms; Firebase init moved past `runApp`; prefs/store parallelised; image cache capped at 48MB |
| `3a75e8c5` | VPS deployment runbook (new); wrong env-var names corrected; `PLACEHOLDERS.md` repaired |
| `389cd437` | Play listing rewritten for NIKSHA OS; feature graphic 1024×500 generated |
| `48c21e3f` | Product `CHANGELOG.md` (did not exist) |
| `7ce99473` | Brand rename finished across 15 tester/school-facing docs |
| `83eee524` | Docs index: runbook indexed, stale deploy docs labelled inline |

---

## Audit findings register (6 read-only audits, all evidence-backed)

Severity as reported by the audit; ✅ = remediated this session.

### P0
1. ✅ **`/student-health` RBAC inversion** — a student could open the school-wide
   medical console; staff who hold the permission were bounced to `/admin`.
2. ✅ **Five routes with no auth gate and no RBAC gate** — `/certificate-requests`,
   `/gate-passes`, `/complaints`, `/staff-360/:employeeId`, `/sync-center`.
   Root cause: `RouteNames.adminErpRoutes` drifted out of sync with
   `kErpRouteViewPermissions`; both gates key off the former, so the routes failed
   OPEN. No test asserted the two agreed — an invariant test now does.
3. ✅ **Hardcoded "Unit Test — Mathematics"** in the teacher class-average insight —
   every teacher of every subject saw the same fabricated exam/subject.
4. ✅ **Student praised for unmeasured performance** — "Strong performance across
   subjects" shown to a student with zero published marks.
5. ✅ **Status-chip text failed WCAG AA** in 5 tone/scheme pairs, and the contrast
   test asserted the 3.0 large-text floor for what is 11px normal text.
6. ✅ **Hosted privacy policy stale, broken and placeholder-riddled** — the URL a
   Play reviewer clicks. Pre-rename, a version behind, raw `**` on screen, and 3 of
   4 acceptance-gate policies not hosted at all.
7. ✅ **2-second splash floor on every cold start** (`Future.wait` takes the max).

### P1 (remediated)
- Pre-`runApp` blocking: Firebase awaited for a post-frame-only result; two
  independent storage inits serialised.
- Image decode with no budget — 100MB default cache on 2GB devices; OOM class.
- Marks entry mounted 40–60 live `TextField`s with no recycling; `MediaQuery.of`
  in a per-cell widget rebuilt the whole grid on every keyboard-animation frame.
- Error states rendered as facts: "No messages sent to this parent yet" on a failed
  fetch (drives duplicate parent contact); "No day closed yet" on a money screen.
- Raw `DioException` text incl. internal endpoint URLs on the day-one import screen.
- Honest state: 0% class average, "Average: 0.0%", "0% of annual fees paid",
  "0 Leave days left" — all unmeasured values rendered as measured.
- Day-one empty states: headed sections rendering zero-height holes on the HR, SIS,
  Finance and Admissions dashboards; empty class roster mislabelled as a failed search.
- Tap targets under 48dp; section titles clipping above ~1.6× text scale.
- Teacher "More" tiles that silently bounced; AI Assistant back button trap;
  Create Homework losing the draft on system back; dead global-search entries.
- Syllabus auto-generate button vanished entirely on catalog error.

### Reported, NOT actioned (deliberate)
- **`web/` React app brand drift** (title, favicon, theme-color, 8 copy strings).
  The web UI lane is **owner-frozen**; the app ships to nobody and is not the
  release target. Enumerated in the audit; left for the owner to unfreeze.
- **Simulated AI pipeline** (`EdgeAiProvider` synthesises text locally and labels it
  "Live inference"; `StubAiProvider` replies say "(context-aware stub)"). The main
  Copilot chat is NOT affected — `AI_COPILOT_ENABLED=true` in `config/live_release.json`
  routes it to the real backend, verified. Secondary surfaces (AI content,
  resource optimisation, parent-meeting summaries) still use the simulated pipeline.
  Not fixed because it is AIP architecture and out of RC scope; flagged as P2.
- **`TeacherExamsData.classAveragePercent`** remains non-nullable in `exam_models.dart`;
  the UI now reads a nullable provider instead. Cosmetic residue, not user-visible.
- **`ParentFeesData` money fields** remain non-nullable in `fees_provider.dart`, so
  absence and a measured zero are indistinguishable at that layer. The presentation
  layer treats `annualAmount <= 0` as "not published". Consequence: a genuine
  zero-fee student (full scholarship) would read as "not published".

---

## Execution queue (remaining, in dependency order)

1. **Land the last remediation waves** — a11y, router/RBAC, day-one empty states.
2. **Regenerate goldens ONCE**, centrally. Multiple lanes changed shared visuals
   (`color_tokens.dart` amber600→amber700, `akshara_navigation.dart` 40→48dp tap
   targets, `akshara_section_header.dart`). Per-lane regen would bake other lanes'
   unfinished work into a baseline that reads as certified. Do not delegate this.
3. **`flutter analyze --fatal-infos`** — that is CI's actual bar (`scripts/qa/run_ci_gates.sh`
   Gate 1), stricter than plain analyze.
4. **Full regression** — expect ≥4316 plus the ~40 tests the waves added.
5. **Add `test/router/route_gate_invariants_test.dart` to CI Gate 3**, next to
   `route_protection_inventory_test.dart`, so the RBAC invariant is enforced on every PR.
6. **Build profile APK + install on emulator** — real device smoke test across personas.
7. **Capture Play screenshots** at **1080×2160** (`adb shell wm size 1080x2160`, reset
   after). The emulator's native 1080×2400 is 2.22:1 and violates Play's rule that
   the long side be at most twice the short side.
8. **RC certification report + EOS gate.**

---

## Assumptions

- Screenshots are captured from a **profile** build with `QA_AUTOMATION=true`, which
  enables the 13 one-tap QA personas and mock data. A **release** build cannot be
  used: `Environment.guardForRelease` refuses to start unless `APP_ENV=production`
  AND `ENABLE_API_MODE=true`, i.e. against a live backend we do not have credentials
  for. Screenshots therefore show the real UI with demo data — stated openly in
  `docs/release/screenshots/README.md`.
- "Akshara" is left untouched wherever it is an identifier (`com.akshara.erp`,
  `akshara_erp`, `deploy/akshara-vps/`, container and DB names) or a historical
  record (archives, dated audits, past certifications).

---

## Risks

| Risk | Severity | Note |
|---|---|---|
| **Upload keystore password may be lost** | HIGH | `~/akshara-upload-keystore.jks` exists, but `android/key.properties` — which the old listing said held the password — does not exist in any checkout on this machine. Free to fix now (regenerate); terminal after a first upload without Play App Signing. |
| Policy host is an unrelated business's domain | HIGH | `akshara.veloraunisexsalon.com`. Reads as a phishing redirect to a parent. Owner-blocked on the domain purchase. |
| Legal pack publish-blocked | HIGH | 9 owner tokens unfilled. Play requires a working privacy contact; DPDP requires a named Grievance Officer. |
| VPS SSH access is owner-bound | MEDIUM | Control-master socket belongs to the owner; no other key is authorised. Single point of failure for every deploy. |
| RPO ≈ 24h, no WAL/PITR | MEDIUM | Accepted for pilot. `DeploymentArchitecture.md` still claims 5-min RPO; now labelled stale. |
| Shared VPS | MEDIUM | Also runs unrelated production workloads. Never run host-wide docker/package commands. |
| Concurrent-agent compile races | LOW | Several transient red runs during parallel remediation resolved on retry. Treat any single red run in a multi-agent tree with suspicion; re-run before believing it. |

---

# SESSION OUTCOME (2026-07-28)

## Final verified gates — merged tree, measured not inherited

| Gate | Result |
|---|---|
| `flutter analyze --fatal-infos` (CI Gate 1's real bar) | **No issues found** |
| Full suite | **4375 passed · 1 skipped · 0 failed** (baseline 4316; waves added 59) |
| Goldens | **178 / 178** |
| Release AAB | **builds** (132.2 MB; real arm64 download **57.9 MB**) |
| Release signing fail-closed | **verified both ways** — signs with a keystore, REFUSES without one |
| App on device | **boots, signs in, navigates** — Android 16 / API 36 |

## Commits

`357f465b` analyzer gate + legal site generator · `f0fcd707` startup perf ·
`3a75e8c5` VPS runbook + env-var fixes + PLACEHOLDERS repair · `389cd437` store
listing + feature graphic · `48c21e3f` changelog · `7ce99473` brand completion ·
`83eee524` docs index · `b1d7811a` CI gate widened · `bae87080` six remediation
lanes · `02aabd53` reliability durability fix · `30cfd7a1` admin-hub layout

## Found ONLY by running the app on a device

Neither of these could be caught by any test in the suite. Both are recorded
because they are the argument for keeping a device in the loop:

1. **Undecryptable reliability store → permanent silent loss of durability.**
   The encrypted drafts/outbox DB could not be decrypted, so the app fell back
   to in-memory — and because the bad file stays on disk, it did so on EVERY
   subsequent launch. Reachable in production via Android auto-backup (app data
   restores; keystore keys deliberately do not). Fixed by rebuilding the store
   when — and only when — this launch had to mint a new key, plus
   `allowBackup="false"` to stop it at the source.
2. **Admin Hub wasted ~46% of the principal's home screen.** Module cards were a
   hardcoded 220dp inside a Wrap; at ~411dp phone width two never fit, so every
   row held one card beside a dead gutter. No golden caught it because the
   admin-hub goldens render at 834dp, where three fit and it looks deliberate.

## Remaining engineering work (not owner-blocked)

1. **7 more store screenshots.** One captured; Play needs ≥2. Procedure and the
   recommended order are in `docs/release/screenshots/README.md`. Stopped rather
   than ship a mid-animation frame.
2. **Admin Hub card interior is sparse** now that cards are full-width — the
   icon/label/Open column leaves the right half empty. Correct, not broken; a
   horizontal layout for the one-column case would finish it.
3. **`MoreNavSheet` filters only on hidden-route scope, never role/permission**
   (`lib/shared/navigation/persona_nav.dart:212-213`). The two specific dead
   tiles are fixed; the class of bug is not.
4. **`TeacherExamsData.classAveragePercent` / `ParentFeesData` money fields**
   remain non-nullable in their models, so absence and a measured zero are
   indistinguishable at that layer. The UI compensates. Consequence worth
   knowing: a genuine zero-fee student reads as "not published".
5. **`web/` React brand drift** — owner-frozen lane, ships to nobody. Enumerated
   but deliberately untouched.
6. **Simulated AI pipeline** labels locally-synthesised text "Live inference" on
   secondary surfaces. The main Copilot is unaffected (verified:
   `AI_COPILOT_ENABLED=true` routes it to the real backend).

## Owner-blocked — the true stop line

Buy the domain · register the company · name a Grievance Officer · Play Console
account + identity verification · keystore password (see risk table above) ·
Razorpay merchant onboarding · production secrets · live VPS deploy.
