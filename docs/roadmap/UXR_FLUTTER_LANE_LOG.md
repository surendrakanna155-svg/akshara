# PROGRAM UXR — Flutter UI/UX Lane Log

**Lane:** branch `feature/uxr-flutter-remediation`, worktree `/Users/surendrakanna/Documents/Akshara_ERP-uxr` (off trunk `integration/w0-canonical` @ `aef2fbab`). Independent of the backend ICA lane; disjoint files (Flutter `lib/`+`test/` vs backend deno).

**Backlog SSOT (⚠ on the QPL branch / MAIN worktree `/Users/surendrakanna/Documents/Akshara_ERP`, NOT here):** roadmap §5.6 PROGRAM UXR + `docs/roadmap/UXR_FINDINGS_REGISTER.md` + audit `docs/audits/PRODUCT_EXPERIENCE_CERTIFICATION_AUDIT_2026-07-21.md`.

**Toolchain:** Flutter 3.44.1. Per-slice gate: `flutter analyze` → `flutter test` → `flutter test test/golden` (re-baseline intended visual changes with `--update-goldens`, eyeball each diff). Never trust piped exit code — read `+N -M`.

## DONE (committed on this branch)
- **I1 + B4** — parent OTP a11y (AutofillHints/Semantics/AutofillGroup) + production login copy cleanup (removed staging/demo-phone leakage; staff-OTP hint that showed the valid mock OTP). golden +70/-0.
- **G2 (P0)** — AI FAB raised clear of the center bottom-nav tab (was intercepting the center primary destination). Re-baselined 4 persona_shell goldens.
- **D2** — surfaced Exams in the schoolAdministration workspace (workspace.dart omitted AdminModule.exams). Re-baselined dark_admin_hub.
- **G6** — More sheet now applies SchoolBuildScope.isRouteHidden (parent PTM tile no longer → Access Denied).

## NEXT (Bucket-A, client-only, approved, independent)
E6 (dead taps/mis-wired chrome) · J6 (pull-to-refresh adoption) · D8 (bulk all-present/absent confirm+undo) · D5 (publish-results confirmation) · J5 (page transitions + iOS back-swipe, replace 287 NoTransitionPage) · **J1+J7** (honor Appearance setting + re-baseline goldens — highest churn, do last). Fast-follow: I3/I4 contrast · E1 AksharaDateField · G7/G8/G9 IA · J8/I6/D9 P2 polish · J4 tablet · G1 Communication nav-reachability.

## NEVER-CHANGE (board-protected)
persona-nav ≤4-primary+More · AB/ML/DB exam semantics · amber-queued money ceremony · token pipeline · honest-state · 48dp touch floors · parent-OTP login · hide-first.

## DEFERRED (not this lane)
ALL web (UXR-F1…F12, web a11y I2/I5, web sub-parts) = web lane OWNER-FROZEN (2026-07-17). Backend-dependent UXR (money A*, admissions/library C*, D3/D6/D7, E2/E3/E5, G4 spine, H* AI, K1/K3). Owner-gated OD batch (OD2 web F2 disable-only unfreeze, OD3 brand J2, OD4 student login, OD5 G10, OD6 K2, OD7 C8, OD8 A8). Honesty items B2/B3/B5/B7 → route through systemic UXR-B9 CI guard (+ICA-G4).
