# M15 Theme Modernization Readiness

**Program:** M15 — Theme Modernization (visual tokens only)  
**Date:** 2026-06-16  
**Prerequisite:** `docs/FINAL_TRUTH_AUDIT.md` · `docs/DOCUMENTATION_SYNC_REPORT.md`  
**Vision:** `docs/Vision/FutureVision.md` §N · **Registry:** FV-M15-01

---

## Verdict: **READY TO BEGIN**

M15 may start safely **after** acknowledging RC stabilization rules and scoping work to visual tokens only.

| Prerequisite | Status |
|--------------|--------|
| Functional completeness (M1–M14) | ✅ |
| Patrol certification | ✅ 88/88 |
| `flutter test` green | ✅ 1688 passed |
| Truth audit complete | ✅ `FINAL_TRUTH_AUDIT.md` |
| RC lock awareness | ⚠️ See §1 |

---

## 1. RC lock & program boundary

`AKSHARA_V1_RC_LOCK.md` declares **STABILIZATION MODE** — no new features, milestones, or architecture changes until pilot feedback.

**M15 is allowed when:**

- Scope is **strictly** colors, typography, glass styling, shadows, card styling, KPI styling, chart palette, navigation rail appearance, dialog appearance
- **No** workflow, business logic, route, screen structure, or repository changes
- Golden + Patrol re-run after token changes
- Changes land on a dedicated branch (e.g. `feature/m15-theme`) — not mixed with pilot hotfixes

**M15 is NOT:**

- UX modernization (`AKSHARA_UX_MODERNIZATION_PLAN.md` — spacing, density, layout hierarchy)
- A redesign or screen restructuring program

---

## 2. M15 scope (in scope / out of scope)

### In scope

| Area | Target files (primary) |
|------|------------------------|
| Colors | `lib/theme/app_colors.dart`, `lib/theme/color_schemes.dart`, semantic tokens |
| Typography | `lib/theme/app_typography.dart`, `textTheme` in `app_theme.dart` |
| Glass styling | New token layer on `AksharaSurfaceCard` / shell backgrounds |
| Shadows & elevation | `app_theme.dart` `elevation`, card themes |
| Card styling | `lib/shared/widgets/akshara_surface_card.dart`, `akshara_kpi_card.dart` |
| KPI styling | `akshara_kpi_card.dart`, `management_kpi_row.dart` |
| Chart palette | Chart color constants used in finance/management dashboards |
| Navigation rail | Admin shell rail theme in `app_theme.dart` + admin scaffolds |
| Dialog appearance | `dialogTheme`, `alertDialogTheme` in `app_theme.dart` |

### Out of scope (hard stop)

- Route changes (`lib/router/`)
- Provider / repository / mutation logic
- RBAC or permission changes
- New screens or widget layout restructuring
- Patrol key changes (unless unavoidable — requires QA review)
- Business workflow or form field changes

---

## 3. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Golden test mass failure | **High** | Update goldens in dedicated commit; 21 ERP/mobile dashboard goldens |
| Patrol screenshot regression | **Medium** | `screenshot_validation_test.dart` — re-run full 88-suite batch |
| KPI hit-target regression | **High** | Recent RC fixes (`akshara_kpi_card.dart` InkWell drill keys) — do not remove interactive wrappers |
| White-label override breakage | **Medium** | Test `WhiteLabelThemeConfig` path in `app_theme.dart` |
| Contrast / a11y regression | **Medium** | Run existing text-scale stress tests (`dashboard_stress_test.dart`) |
| Mixing M15 with UX layout program | **Medium** | Enforce token-only PR review checklist |
| RC lock violation perception | **Low** | Document M15 as post-cert visual polish, not new capability |

---

## 4. Impacted shared widgets

Primary surfaces (theme consumers):

| Widget | Path | M15 impact |
|--------|------|------------|
| `AksharaKpiCard` | `lib/shared/widgets/akshara_kpi_card.dart` | Colors, shadow, radius, typography |
| `AksharaSurfaceCard` | `lib/shared/widgets/akshara_surface_card.dart` | Glass, elevation |
| `AksharaInsightCard` | `lib/shared/widgets/akshara_insight_card.dart` | Accent, border |
| `AksharaAppBar` | `lib/shared/widgets/akshara_app_bar.dart` | AppBar theme |
| `AksharaStatusChip` | `lib/shared/widgets/akshara_status_chip.dart` | Semantic colors |
| `AksharaPeriodPill` | `lib/shared/widgets/akshara_period_pill.dart` | Fill/stroke tokens |
| `AksharaSectionHeader` | `lib/shared/widgets/akshara_section_header.dart` | Type scale |
| `AksharaQuickActionCard` | `lib/shared/widgets/akshara_quick_action_card.dart` | Card + icon tint |
| `AksharaErrorState` / `AksharaEmptyState` | shared widgets | Semantic colors |
| `AksharaAnalyticsPanel` | charts wrapper | Chart palette |
| Copilot dock | `lib/features/copilot/dock/copilot_floating_dock.dart` | FAB + panel chrome |

**Shell surfaces:** `admin_content_scaffold.dart`, mobile persona shells, director tab scaffold.

---

## 5. Golden test impact

| Suite | File | Viewports | Expected action |
|-------|------|-----------|-----------------|
| Parent dashboard | `test/golden/parent_dashboard_golden_test.dart` | 390×844 | Re-baseline |
| Teacher dashboard | `test/golden/teacher_dashboard_golden_test.dart` | 390/428/834 | Re-baseline |
| Student dashboard | `test/golden/student_dashboard_golden_test.dart` | 390×844 | Re-baseline |
| ERP dashboards | `test/golden/erp_dashboards_golden_test.dart` | 390/428/834 × 4 dashboards | Re-baseline (~12 images) |

**Count:** 21 golden images referenced in `AKSHARA_V1_RC_LOCK.md`.

**Process:**

```bash
flutter test test/golden/ --update-goldens
# macOS only for skipped golden if applicable
flutter test test/golden/  # verify clean
```

**Note:** 1 golden test skipped on non-macOS — document platform for golden updates.

---

## 6. Patrol impact

| Suite category | Risk | Suites |
|----------------|------|--------|
| KPI drill-down | **High** | `management_kpi_drill_e2e_test` |
| Enrollment wizard layout | **Medium** | `admissions_e2e_journey_test` (sticky actions) |
| Screenshot validation | **High** | `screenshot_validation_test` |
| Copilot dock visibility | **Medium** | `copilot_dock_e2e`, `ai_access_settings_e2e` |
| Trust/platform intelligence | **Low** | AI content keys stable post-RC |

**Required after M15 token pass:**

```bash
flutter analyze          # 0 issues
flutter test             # all pass
bash qa/patrol/run_erp_coverage.sh  # FULL mode — 88 suites
```

**Optional fast gate during iteration:**

```bash
ERP_COVERAGE_MODE=fast bash qa/patrol/run_erp_coverage.sh
```

---

## 7. Rollout strategy

### Phase 0 — Preparation (1 day)

1. Branch `feature/m15-theme` from `release/v1.0-preprod` @ `114fc5b`
2. Snapshot current goldens (tag or commit hash reference)
3. Define token delta doc against `docs/DesignSystem.md` §4–7

### Phase 1 — Core tokens (2–3 days)

1. Update primitive → semantic color mapping
2. Update `ThemeData` in `app_theme.dart` (light + dark)
3. Typography scale alignment
4. Run `flutter analyze` + unit tests

### Phase 2 — Shared components (2–3 days)

1. `AksharaKpiCard`, `AksharaSurfaceCard`, insight/quick-action cards
2. Dialog + navigation rail themes
3. Chart palette constants
4. Re-run widget tests touching shared widgets

### Phase 3 — Validation (2 days)

1. Update goldens (dedicated commit: `test(m15): rebaseline dashboard goldens`)
2. Full Patrol 88/88
3. Vertical stress tests (`vertical_dashboard_stress_test.dart` — 37 tests)
4. UX stress (`dashboard_stress_test.dart`)

### Phase 4 — Sign-off

1. M15 completion report (tokens changed, goldens, Patrol run ID)
2. No registry/roadmap feature additions
3. Merge to RC branch only after 88/88 Patrol green

---

## 8. Success criteria

| Criterion | Target |
|-----------|--------|
| `flutter analyze` | 0 issues |
| `flutter test` | All pass (goldens updated intentionally) |
| Patrol full mode | 88/88 |
| Workflow regressions | 0 |
| RBAC / route inventory | Unchanged |
| Pilot-blocking defects | 0 |

---

## 9. Dependencies & blockers

| Item | Blocks M15? |
|------|:-----------:|
| Pilot feedback | No — M15 is parallel visual work |
| Backend RLS | No |
| Smart School Patrol gap | No — separate QA backlog |
| UX modernization plan | No — intentionally separate |

**No Flutter functional blocker prevents M15 start.**

---

## Related documents

- `docs/FINAL_TRUTH_AUDIT.md` — truth baseline
- `docs/DesignSystem.md` — token specification
- `docs/AKSHARA_UX_MODERNIZATION_PLAN.md` — out of M15 scope
- `docs/AKSHARA_V1_RC_LOCK.md` — stabilization rules
- `docs/PATROL_FINAL_CERTIFICATION.md` — certification baseline
