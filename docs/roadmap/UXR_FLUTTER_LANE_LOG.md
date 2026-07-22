# PROGRAM UXR — Flutter UI/UX Lane Log

**Lane:** branch `feature/uxr-flutter-remediation`, worktree `/Users/surendrakanna/Documents/Akshara_ERP-uxr` (off trunk `integration/w0-canonical` @ `aef2fbab`). Independent of the backend ICA lane; disjoint files (Flutter `lib/`+`test/` vs backend deno).

**Backlog SSOT (⚠ on the QPL branch / MAIN worktree `/Users/surendrakanna/Documents/Akshara_ERP`, NOT here):** roadmap §5.6 PROGRAM UXR + `docs/roadmap/UXR_FINDINGS_REGISTER.md` + audit `docs/audits/PRODUCT_EXPERIENCE_CERTIFICATION_AUDIT_2026-07-21.md`.

**Toolchain:** Flutter 3.44.1. Per-slice gate: `flutter analyze` → `flutter test` → `flutter test test/golden` (re-baseline intended visual changes with `--update-goldens`, eyeball each diff). Never trust piped exit code — read `+N -M`.

## DONE (committed on this branch)
- **I1 + B4** — parent OTP a11y (AutofillHints/Semantics/AutofillGroup) + production login copy cleanup (removed staging/demo-phone leakage; staff-OTP hint that showed the valid mock OTP). golden +70/-0.
- **G2 (P0)** — AI FAB raised clear of the center bottom-nav tab (was intercepting the center primary destination). Re-baselined 4 persona_shell goldens.
- **D2** — surfaced Exams in the schoolAdministration workspace (workspace.dart omitted AdminModule.exams). Re-baselined dark_admin_hub.
- **G6** — More sheet now applies SchoolBuildScope.isRouteHidden (parent PTM tile no longer → Access Denied).
- **E6** `80ad96ed` (F-163/F-164/F-128) — teacher dead taps: risk-banner Review (`student_risk_` prefix now routed to teacherStudentRisk), profile avatar → teacherProfile (was Home), notifications bell → new `/teacher/notifications` (was the parent route). analyze clean; teacher+router tests +71; golden +70 unchanged.
- **J6** `c990bbe3` (F-032) — pull-to-refresh on 10 high-value parent/student/teacher list/detail screens (RefreshIndicator + AlwaysScrollableScrollPhysics + invalidate the real provider). Deferred admin-scaffold surfaces. analyze clean; touched tests +337; golden +70 unchanged.
- **D8** `3c51cab7` (F-080) — bulk attendance All-present/All-absent now confirm-on-overwrite (only when marks exist) + snackbar Undo that restores the prior roster and re-arms autosave so the wiped state can't win the draft. analyze clean; attendance+cert +37; golden +70.
- **D5** `5a606e05` (F-077) — Publish-results now shows a summary confirm (class·subject·N students·M absent AB/ML/DB·K unmarked; K>0 prominent, never blocks) before the irreversible publish. Revocation window = backend-dependent (out of scope). analyze clean; exam_admin +47; golden +70.
- **J5** `a7e48fc6` (F-029) — restored push animations + iOS back-swipe: 245 drill-in routes NoTransitionPage→builder (default MaterialPage); 42 tab destinations kept instant (persona shell roots + primary bottom-nav tabs + admin module-landings). analyze clean; full flutter test 4131/0/1-skip; golden +70 unchanged.

## DESIGN SYSTEM V2 — Phase 2 (branded premium pass; SSOT `docs/design/DESIGN_SYSTEM_V2.md`)
J1+J7 are RESOLVED by DS V2 (owner escalated to a full unified design system, 2026-07-21). Phase 1 (unified persona theming that honors Appearance) committed `b912e308`. Phase 2 = strengthen persona identity across the chrome + premium component pass. Objective is no longer "make Light/Dark work" — it's "premium, modern, enterprise, cohesive" while preserving every certified flow.
- **P2-1 — Branded persona nav chrome** (DS V2 §7) — selected bottom-nav / rail / drawer item now reads in the **persona accent**: full-strength `primary` icon + label on a crisp accent-tinted **stadium** pill (16% bottom nav / 14% rail / 12% drawer), replacing the washed M3 `primaryContainer` pill + dark `onPrimaryContainer` icon that made personas look alike. Contrast asserted (3:1) in `navigation_bar_highlight_test.dart`. analyze clean; theme+nav+widget tests 164/0; golden re-baselined 4 persona shells, full suite 70/70.

## ⏸ OWNER-GATED (surfaced) — J1 + J7 (SUPERSEDED by DS V2 above)
**J1+J7** (F-002/F-008 — honor the Appearance setting + re-baseline goldens to production theming) is **entangled with the owner-gated OD3 "brand/theme authority" decision** (roadmap §5.6 UXR-OD3): making the toggle work requires designing the missing light/dark persona palettes, which the roadmap reserves for the owner (single identity vs. keep Stitch personas with added light/dark variants vs. persona-hue-over-M15). Surfaced to the owner as a genuine decision — NOT implemented autonomously (would be a unilateral brand call). Theming-related fast-follow (I3/I4 contrast, J8/I6 appearance polish) likely depends on the same decision.

## NEXT (fast-follow, client-only, mostly non-gated)
E1 AksharaDateField · G7/G8/G9 IA · J4 tablet · G1 Communication nav-reachability · D9 P2 polish. (I3/I4 contrast + J8/I6 appearance → hold for the OD3 theming decision.) Route honesty items B2/B3/B5/B7 → systemic UXR-B9 CI guard.

## NEVER-CHANGE (board-protected)
persona-nav ≤4-primary+More · AB/ML/DB exam semantics · amber-queued money ceremony · token pipeline · honest-state · 48dp touch floors · parent-OTP login · hide-first.

## DEFERRED (not this lane)
ALL web (UXR-F1…F12, web a11y I2/I5, web sub-parts) = web lane OWNER-FROZEN (2026-07-17). Backend-dependent UXR (money A*, admissions/library C*, D3/D6/D7, E2/E3/E5, G4 spine, H* AI, K1/K3). Owner-gated OD batch (OD2 web F2 disable-only unfreeze, OD3 brand J2, OD4 student login, OD5 G10, OD6 K2, OD7 C8, OD8 A8). Honesty items B2/B3/B5/B7 → route through systemic UXR-B9 CI guard (+ICA-G4).
