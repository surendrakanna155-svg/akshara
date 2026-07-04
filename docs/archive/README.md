# Akshara ERP — Documentation Archive

> Completed, superseded, duplicate and historical documents. **Nothing here is deleted** — files were relocated with `git mv` (history preserved; recover any file with `git log --follow`).

> **Do not use anything in this archive for current planning or decisions.** The authoritative current set is indexed in [`../README.md`](../README.md).

> _Archived in the 2026-06-27 Documentation Cleanup (592 files), reconciled on **2026-07-03** with 53 further historical items (superseded product audit, prior Fable UI/UX audit, figma-era mockups, visual-gap screenshots, root launch/smoke screenshots). **Total archived files: 645** (+ this index). See [§ Post-2026-06-27 additions](#post-2026-06-27-additions--2026-07-03-reconciliation)._


## Buckets

| Folder | Files | Contents |
|---|---:|---|
| [`roadmap/`](roadmap/) | 16 | Superseded roadmaps and roadmap-reconciliation snapshots. The **current** roadmap is `docs/FINAL_QA_ROADMAP.md` (active). |
| [`qa/`](qa/) | 41 | Historical QA run reports, coverage inventories, patrol/test-run artifacts, and root launch/smoke screenshots (`screenshots/`). The **current** QA tracker is `docs/FINAL_QA_MASTER_TRACKER.md` (active). |
| [`audit/`](audit/) | 218 | One-time audits, gap inventories, truth/readiness reports and the Red-Team engagement records. Includes `architecture-review/` (per-version API/architecture audit history), the superseded product audit (`still_pending.md`), the prior Fable UI/UX audit (`fable-ui-ux-audit/`), and the M15 visual-gap audit (`m15-visual-gap/`). |
| [`planning/`](planning/) | 39 | Completed execution plans, build plans, strategy notes, backlogs and specs whose work has shipped. Includes the F-phase API analysis/execution plans. |
| [`design/`](design/) | 45 | Design notes, figma-era screen mockups, and superseded design-system versions for features that have since shipped. Includes dashboard mockups (`mockups-uiux/`) and parent-home mockups (`mockups/`). |
| [`migration/`](migration/) | 5 | Per-phase data/schema migration notes for shipped backend phases (F1–F5). |
| [`completed/`](completed/) | 257 | Certifications, completion reports, milestone/wave/batch closures, live-backend build logs, and the full per-version release-notes history (`releases/`). |
| [`temporary/`](temporary/) | 24 | Handoffs, weekly/overnight/cycle progress reports, process/orchestration notes, status snapshots and one-off scratch reports. |


## roadmap/  (16 files)

Superseded roadmaps and roadmap-reconciliation snapshots. The **current** roadmap is `docs/FINAL_QA_ROADMAP.md` (active).

- `AKSHARA_FINAL_ROADMAP.md`  ·  _was_ `docs/_archive/AKSHARA_FINAL_ROADMAP.md`
- `BackendRoadmap.md`  ·  _was_ `docs/_archive/BackendRoadmap.md`
- `FINAL_COMPLETION_ROADMAP.md`  ·  _was_ `docs/FINAL_COMPLETION_ROADMAP.md`
- `FigmaImplementationRoadmap.md`  ·  _was_ `docs/_archive/FigmaImplementationRoadmap.md`
- `MASTER_ROADMAP_RECONCILIATION_2026-06-24.md`  ·  _was_ `docs/MASTER_ROADMAP_RECONCILIATION_2026-06-24.md`
- `MODULE_JOURNEY_ROADMAP.md`  ·  _was_ `docs/MODULE_JOURNEY_ROADMAP.md`
- `ONBOARDING_COMPLETION_ROADMAP.md`  ·  _was_ `docs/ONBOARDING_COMPLETION_ROADMAP.md`
- `OPERATIONAL_REMEDIATION_ROADMAP.md`  ·  _was_ `docs/_archive/OPERATIONAL_REMEDIATION_ROADMAP.md`
- `PATROL_EXPANSION_ROADMAP.md`  ·  _was_ `docs/_archive/PATROL_EXPANSION_ROADMAP.md`
- `PILOT_SIMULATION_ROADMAP.md`  ·  _was_ `docs/PILOT_SIMULATION_ROADMAP.md`
- `PRODUCTION_BACKEND_ROADMAP.md`  ·  _was_ `docs/_archive/PRODUCTION_BACKEND_ROADMAP.md`
- `RED_TEAM_COMPLETION_ROADMAP.md`  ·  _was_ `docs/RED_TEAM_COMPLETION_ROADMAP.md`
- `ROADMAP_RECONCILED_2026-06-24.md`  ·  _was_ `docs/ROADMAP_RECONCILED_2026-06-24.md`
- `ROADMAP_REVIEW.md`  ·  _was_ `docs/_archive/ROADMAP_REVIEW.md`
- `ROAD_TO_PRODUCTION_V1.md`  ·  _was_ `docs/ROAD_TO_PRODUCTION_V1.md`
- `Roadmap.md`  ·  _was_ `docs/_archive/Roadmap.md`

## qa/  (36 files)

Historical QA run reports, coverage inventories, patrol/test-run artifacts. The **current** QA tracker is `docs/FINAL_QA_MASTER_TRACKER.md` (active).

- `ACTION_COVERAGE_MATRIX.md`  ·  _was_ `docs/QA/ACTION_COVERAGE_MATRIX.md`
- `FINAL_COMPLETION_TEST_AUDIT.md`  ·  _was_ `docs/QA/FINAL_COMPLETION_TEST_AUDIT.md`
- `FINAL_COVERAGE_REPORT.md`  ·  _was_ `docs/QA/FINAL_COVERAGE_REPORT.md`
- `PATROL_EXPANSION_PLAN.md`  ·  _was_ `docs/QA/PATROL_EXPANSION_PLAN.md`
- `PATROL_MASTER_INVENTORY.md`  ·  _was_ `docs/QA/PATROL_MASTER_INVENTORY.md`
- `PHASE3_COVERAGE_INVENTORY.md`  ·  _was_ `docs/QA/PHASE3_COVERAGE_INVENTORY.md`
- `TEST_COVERAGE_BASELINE.md`  ·  _was_ `docs/QA/TEST_COVERAGE_BASELINE.md`
- `UNTESTED_ACTIONS_REPORT.md`  ·  _was_ `docs/QA/UNTESTED_ACTIONS_REPORT.md`
- `agent_execution_plan.md`  ·  _was_ `docs/QA/agent_execution_plan.md`
- `autonomous_backlog.md`  ·  _was_ `docs/QA/autonomous_backlog.md`
- `autonomous_progress.md`  ·  _was_ `docs/QA/autonomous_progress.md`
- `ci_validation_report.md`  ·  _was_ `docs/QA/ci_validation_report.md`
- `coverage_audit_v18.7.md`  ·  _was_ `docs/QA/coverage_audit_v18.7.md`
- `cycle4_report.md`  ·  _was_ `docs/QA/cycle4_report.md`
- `e2e_journey_gap_analysis.md`  ·  _was_ `docs/QA/e2e_journey_gap_analysis.md`
- `final_completion_progress.md`  ·  _was_ `docs/QA/final_completion_progress.md`
- `final_completion_summary.md`  ·  _was_ `docs/QA/final_completion_summary.md`
- `final_summary.txt`  ·  _was_ `qa/patrol/reports/phase1_verification/final_summary.txt`
- `full_regression_report.md`  ·  _was_ `docs/QA/full_regression_report.md`
- `intel_02_completion_report.md`  ·  _was_ `docs/QA/intel_02_completion_report.md`
- `intel_04_completion_report.md`  ·  _was_ `docs/QA/intel_04_completion_report.md`
- `intelligence_continuation_progress.md`  ·  _was_ `docs/QA/intelligence_continuation_progress.md`
- `journey_implementation_readiness.md`  ·  _was_ `docs/QA/journey_implementation_readiness.md`
- `module_coverage_v18_6.md`  ·  _was_ `qa/reports/module_coverage_v18_6.md`
- `overnight_progress.md`  ·  _was_ `docs/QA/overnight_progress.md`
- `overnight_summary.md`  ·  _was_ `docs/QA/overnight_summary.md`
- `p0_4_completion_report.md`  ·  _was_ `docs/QA/p0_4_completion_report.md`
- `p0_5_completion_report.md`  ·  _was_ `docs/QA/p0_5_completion_report.md`
- `p0_6_completion_report.md`  ·  _was_ `docs/QA/p0_6_completion_report.md`
- `phase1_patrol_verification.md`  ·  _was_ `docs/QA/phase1_patrol_verification.md`
- `pre_p0_4_checkpoint.md`  ·  _was_ `docs/QA/pre_p0_4_checkpoint.md`
- `pre_p0_5_checkpoint.md`  ·  _was_ `docs/QA/pre_p0_5_checkpoint.md`
- `rerun_summary.txt`  ·  _was_ `qa/patrol/reports/phase1_verification/rerun_summary.txt`
- `summary.txt`  ·  _was_ `qa/patrol/reports/pre_m15_cert/20260616_231340/summary.txt`
- `v18.8_readiness_assessment.md`  ·  _was_ `docs/QA/v18.8_readiness_assessment.md`
- `vision_completion_progress.md`  ·  _was_ `docs/QA/vision_completion_progress.md`

## audit/  (195 files)

One-time audits, gap inventories, truth/readiness reports and the Red-Team engagement records. Includes `architecture-review/` — the per-version API/architecture audit history.

- `AI_ENTRYPOINT_AUDIT.md`  ·  _was_ `docs/AI_ENTRYPOINT_AUDIT.md`
- `AI_INTELLIGENCE_AUDIT.md`  ·  _was_ `docs/AI_INTELLIGENCE_AUDIT.md`
- `AKSHARA_VISION_GAP_ANALYSIS.md`  ·  _was_ `docs/AKSHARA_VISION_GAP_ANALYSIS.md`
- `API_PARITY_AUDIT.md`  ·  _was_ `docs/API_PARITY_AUDIT.md`
- `CLAUDE_MASTER_AUDIT.md`  ·  _was_ `docs/CLAUDE_MASTER_AUDIT.md`
- `CLAUDE_MASTER_AUDIT_ROOT_hardening-status.md`  ·  _was_ `CLAUDE_MASTER_AUDIT.md`
- `EXAM_SECURITY_AUDIT.md`  ·  _was_ `docs/EXAM_SECURITY_AUDIT.md`
- `EXPORT_PARITY_AUDIT.md`  ·  _was_ `docs/EXPORT_PARITY_AUDIT.md`
- `FINAL_COMPLETION_AUDIT.md`  ·  _was_ `docs/FINAL_COMPLETION_AUDIT.md`
- `FINAL_GAP_INVENTORY.md`  ·  _was_ `docs/FINAL_GAP_INVENTORY.md`
- `FINAL_TRUTH_AUDIT.md`  ·  _was_ `docs/FINAL_TRUTH_AUDIT.md`
- `FULL_REGRESSION_REPORT.md`  ·  _was_ `docs/FULL_REGRESSION_REPORT.md`
- `m15-visual-gap/M15_VISUAL_GAP_REPORT.md`  ·  _was_ `docs/audit/m15-visual-gap/M15_VISUAL_GAP_REPORT.md` _(2026-07-03: reunited with its `screenshots/` — see Post-2026-06-27 additions)_
- `MOBILE_FIRST_AUDIT.md`  ·  _was_ `docs/MOBILE_FIRST_AUDIT.md`
- `MODULE_JOURNEY_AUDIT.md`  ·  _was_ `docs/MODULE_JOURNEY_AUDIT.md`
- `MVP_Stabilization_Checklist.md`  ·  _was_ `docs/MVP_Stabilization_Checklist.md`
- `ONBOARDING_DYNAMIC_CONFIGURATION_AUDIT.md`  ·  _was_ `docs/ONBOARDING_DYNAMIC_CONFIGURATION_AUDIT.md`
- `OPERATIONAL_GAP_MASTER_TRACKER.md`  ·  _was_ `docs/OPERATIONAL_GAP_MASTER_TRACKER.md`
- `OWNER_DASHBOARD_AUDIT.md`  ·  _was_ `docs/OWNER_DASHBOARD_AUDIT.md`
- `PERFORMANCE_REVIEW.md`  ·  _was_ `docs/_archive/PERFORMANCE_REVIEW.md`
- `PERFORMANCE_REVIEW_FINAL.md`  ·  _was_ `docs/_archive/PERFORMANCE_REVIEW_FINAL.md`
- `PILOT_READINESS_AUDIT.md`  ·  _was_ `docs/PILOT_READINESS_AUDIT.md`
- `PILOT_READINESS_REPORT.md`  ·  _was_ `docs/PILOT_READINESS_REPORT.md`
- `PLAY_STORE_AND_NOTIFICATIONS_READINESS.md`  ·  _was_ `docs/PLAY_STORE_AND_NOTIFICATIONS_READINESS.md`
- `PRE_PRODUCTION_GAP_REPORT.md`  ·  _was_ `docs/PRE_PRODUCTION_GAP_REPORT.md`
- `PRODUCTION_HARDENING_REPORT.md`  ·  _was_ `docs/PRODUCTION_HARDENING_REPORT.md`
- `PRODUCTION_READINESS_FINAL.md`  ·  _was_ `docs/PRODUCTION_READINESS_FINAL.md`
- `PROJECT_HEALTH_AUDIT.md`  ·  _was_ `docs/_archive/PROJECT_HEALTH_AUDIT.md`
- `QUESTION_INTELLIGENCE_PLATFORM_AUDIT.md`  ·  _was_ `docs/QUESTION_INTELLIGENCE_PLATFORM_AUDIT.md`
- `REAL_SCHOOL_OPERATIONS_AUDIT.md`  ·  _was_ `docs/REAL_SCHOOL_OPERATIONS_AUDIT.md`
- `REAL_WORLD_SCHOOL_AUDIT.md`  ·  _was_ `docs/REAL_WORLD_SCHOOL_AUDIT.md`
- `RED_TEAM_DEFECT_CLASSIFICATION.md`  ·  _was_ `docs/RED_TEAM_DEFECT_CLASSIFICATION.md`
- `RED_TEAM_MASTER_TRACKER.md`  ·  _was_ `docs/RED_TEAM_MASTER_TRACKER.md`
- `RED_TEAM_OPERATIONAL_AUDIT.md`  ·  _was_ `docs/RED_TEAM_OPERATIONAL_AUDIT.md`
- `RED_TEAM_REPRODUCTION_REPORT.md`  ·  _was_ `docs/RED_TEAM_REPRODUCTION_REPORT.md`
- `RED_TEAM_VALIDATION_REPORT.md`  ·  _was_ `docs/RED_TEAM_VALIDATION_REPORT.md`
- `UI_UX_AUDIT_REPORT.md`  ·  _was_ `docs/UI_UX_AUDIT_REPORT.md`
- `UX_STABILIZATION_FINAL.md`  ·  _was_ `docs/UX_STABILIZATION_FINAL.md`
- `UX_STABILIZATION_REPORT.md`  ·  _was_ `docs/UX_STABILIZATION_REPORT.md`
- `WORKFLOW_VERIFICATION_REPORT.md`  ·  _was_ `docs/WORKFLOW_VERIFICATION_REPORT.md`
- `WORKSPACE_ARCHITECTURE_AUDIT.md`  ·  _was_ `docs/WORKSPACE_ARCHITECTURE_AUDIT.md`
- `WORKSPACE_STABILIZATION_REPORT.md`  ·  _was_ `docs/WORKSPACE_STABILIZATION_REPORT.md`

### `audit/architecture-review/` — 153 files (historical, summarised)

Representative entries: `ArchitectureReview.md`, `Branch-Consolidation-Audit.md`, `FINAL_PLATFORM_AUDIT.md`, `FINAL_PRODUCTION_AUDIT.md`, `FINAL_UX_AUDIT.md`, `FINAL_WORKFLOW_AUDIT.md`, `RC-Readiness-Review.md`, `v0.5-Audit.md`, … (+145 more).

## planning/  (39 files)

Completed execution plans, build plans, strategy notes, backlogs and specs whose work has shipped. Includes the F-phase API analysis/execution plans.

- `AKSHARA_DUAL_TRACK_MASTER_PLAN.md`  ·  _was_ `docs/AKSHARA_DUAL_TRACK_MASTER_PLAN.md`
- `AKSHARA_IMPLEMENTATION_BACKLOG.md`  ·  _was_ `docs/AKSHARA_IMPLEMENTATION_BACKLOG.md`
- `AKSHARA_MASTER_FEATURE_REGISTRY.md`  ·  _was_ `docs/AKSHARA_MASTER_FEATURE_REGISTRY.md`
- `AKSHARA_UX_MODERNIZATION_PLAN.md`  ·  _was_ `docs/AKSHARA_UX_MODERNIZATION_PLAN.md`
- `ARCHITECTURE_FREEZE_RECOMMENDATION.md`  ·  _was_ `docs/ARCHITECTURE_FREEZE_RECOMMENDATION.md`
- `BACKEND_ARCHITECTURE_DECISION.md`  ·  _was_ `docs/BACKEND_ARCHITECTURE_DECISION.md`
- `BACKUP_RECOVERY_ARCHITECTURE.md`  ·  _was_ `docs/BACKUP_RECOVERY_ARCHITECTURE.md`
- `BACKUP_RESTORE_ARCHITECTURE.md`  ·  _was_ `docs/BACKUP_RESTORE_ARCHITECTURE.md`
- `BACKUP_RESTORE_RUNBOOK.md`  ·  _was_ `docs/BACKUP_RESTORE_RUNBOOK.md`
- `EXAMS_BUILD_PLAN.md`  ·  _was_ `docs/EXAMS_BUILD_PLAN.md`
- `F2_APPROVAL_API_ANALYSIS.md`  ·  _was_ `docs/F2_APPROVAL_API_ANALYSIS.md`
- `F2_APPROVAL_API_EXECUTION_PLAN.md`  ·  _was_ `docs/F2_APPROVAL_API_EXECUTION_PLAN.md`
- `F3_SIS_360_API_ANALYSIS.md`  ·  _was_ `docs/F3_SIS_360_API_ANALYSIS.md`
- `F3_SIS_360_API_EXECUTION_PLAN.md`  ·  _was_ `docs/F3_SIS_360_API_EXECUTION_PLAN.md`
- `F4_EXAM_API_ANALYSIS.md`  ·  _was_ `docs/F4_EXAM_API_ANALYSIS.md`
- `F4_EXAM_API_EXECUTION_PLAN.md`  ·  _was_ `docs/F4_EXAM_API_EXECUTION_PLAN.md`
- `F5_ATTENDANCE_API_ANALYSIS.md`  ·  _was_ `docs/F5_ATTENDANCE_API_ANALYSIS.md`
- `FIRST_10_SCHOOLS_STRATEGY.md`  ·  _was_ `docs/FIRST_10_SCHOOLS_STRATEGY.md`
- `FIRST_TIME_STUDENT_DATA_ONBOARDING_PLAN.md`  ·  _was_ `docs/plans/FIRST_TIME_STUDENT_DATA_ONBOARDING_PLAN.md`
- `FOUR_MILESTONE_EXECUTION_REPORT.md`  ·  _was_ `docs/FOUR_MILESTONE_EXECUTION_REPORT.md`
- `INTEL_03_ROLE_ARCHITECTURE.md`  ·  _was_ `docs/INTEL_03_ROLE_ARCHITECTURE.md`
- `M-D3_ANALYSIS.md`  ·  _was_ `docs/M-D3_ANALYSIS.md`
- `M-D4_ANALYSIS.md`  ·  _was_ `docs/M-D4_ANALYSIS.md`
- `M-D4_EXECUTION_PLAN.md`  ·  _was_ `docs/M-D4_EXECUTION_PLAN.md`
- `M14_PRODUCT_EVOLUTION_PLAN.md`  ·  _was_ `docs/M14_PRODUCT_EVOLUTION_PLAN.md`
- `MASTER_RECOMMENDATION_REPORT.md`  ·  _was_ `docs/MASTER_RECOMMENDATION_REPORT.md`
- `MULTI_AGENT_EXECUTION_PLAN.md`  ·  _was_ `docs/MULTI_AGENT_EXECUTION_PLAN.md`
- `NOTIFICATIONS_POSTERS_HOLIDAYS_PLAN.md`  ·  _was_ `docs/NOTIFICATIONS_POSTERS_HOLIDAYS_PLAN.md`
- `PHASE_A_EXECUTION_PLAN.md`  ·  _was_ `docs/PHASE_A_EXECUTION_PLAN.md`
- `PHASE_D_EXECUTION_PLAN.md`  ·  _was_ `docs/PHASE_D_EXECUTION_PLAN.md`
- `QUESTION_PAPER_FOUNDATION_MASTER_PLAN.md`  ·  _was_ `docs/plans/QUESTION_PAPER_FOUNDATION_MASTER_PLAN.md`
- `RED_TEAM_REMEDIATION_PLAN.md`  ·  _was_ `docs/_archive/RED_TEAM_REMEDIATION_PLAN.md`
- `RED_TEAM_REMEDIATION_REPORT.md`  ·  _was_ `docs/_archive/RED_TEAM_REMEDIATION_REPORT.md`
- `UI_UX_AUDIT_BACKLOG.md`  ·  _was_ `docs/UI_UX_AUDIT_BACKLOG.md`
- `WEEK1_EXECUTION_REPORT.md`  ·  _was_ `docs/WEEK1_EXECUTION_REPORT.md`
- `WEEK2_EXECUTION_REPORT.md`  ·  _was_ `docs/WEEK2_EXECUTION_REPORT.md`
- `WEEK3_EXECUTION_REPORT.md`  ·  _was_ `docs/WEEK3_EXECUTION_REPORT.md`
- `WEEK4_EXECUTION_REPORT.md`  ·  _was_ `docs/WEEK4_EXECUTION_REPORT.md`
- `WEEK5_EXECUTION_REPORT.md`  ·  _was_ `docs/WEEK5_EXECUTION_REPORT.md`

## design/  (20 files)

Design notes, figma-era screen mockups, and superseded design-system versions for features that have since shipped.

- `ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md`  ·  _was_ `docs/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md`
- `DESIGN_SYSTEM_V1.md`  ·  _was_ `docs/DESIGN_SYSTEM_V1.md`
- `DesignSystem.md`  ·  _was_ `docs/DesignSystem.md`
- `EXAM_WORKSPACE_DESIGN.md`  ·  _was_ `docs/EXAM_WORKSPACE_DESIGN.md`
- `FUTURE_VISION_AI_SCHOOL_BUILDER.md`  ·  _was_ `docs/FUTURE_VISION_AI_SCHOOL_BUILDER.md`
- `FUTURE_VISION_MASTER_INDEX.md`  ·  _was_ `docs/FUTURE_VISION_MASTER_INDEX.md`
- `FUTURE_VISION_PRESERVATION_AUDIT.md`  ·  _was_ `docs/FUTURE_VISION_PRESERVATION_AUDIT.md`
- `FigmaDesignSystemBuildGuide.md`  ·  _was_ `docs/FigmaDesignSystemBuildGuide.md`
- `Finance_Module_Specification.md`  ·  _was_ `docs/Finance_Module_Specification.md`
- `M15.5_PREMIUM_TRANSFORMATION_REPORT.md`  ·  _was_ `docs/M15.5_PREMIUM_TRANSFORMATION_REPORT.md`
- `M15_THEME_MODERNIZATION_READINESS.md`  ·  _was_ `docs/M15_THEME_MODERNIZATION_READINESS.md`
- `PA-01-ParentDashboard-M.md`  ·  _was_ `docs/figma-screens/PA-01-ParentDashboard-M.md`
- `PA-02-ParentAttendance-M.md`  ·  _was_ `docs/figma-screens/PA-02-ParentAttendance-M.md`
- `PA-03-ParentFees-M.md`  ·  _was_ `docs/figma-screens/PA-03-ParentFees-M.md`
- `README.md`  ·  _was_ `docs/figma-screens/README.md`
- `SCREEN_CONSOLIDATION_REPORT.md`  ·  _was_ `docs/SCREEN_CONSOLIDATION_REPORT.md`
- `ST-01-StudentDashboard-M.md`  ·  _was_ `docs/figma-screens/ST-01-StudentDashboard-M.md`
- `TA-01-TeacherDashboard-M.md`  ·  _was_ `docs/figma-screens/TA-01-TeacherDashboard-M.md`
- `UX_MODERNIZATION_REPORT.md`  ·  _was_ `docs/UX_MODERNIZATION_REPORT.md`
- `Universal-Organization-Builder.md`  ·  _was_ `docs/Vision/design/Universal-Organization-Builder.md`

## migration/  (5 files)

Per-phase data/schema migration notes for shipped backend phases (F1–F5).

- `F1_AUTH_MIGRATION.md`  ·  _was_ `docs/F1_AUTH_MIGRATION.md`
- `F2_APPROVAL_MIGRATION.md`  ·  _was_ `docs/F2_APPROVAL_MIGRATION.md`
- `F3_SIS_360_MIGRATION.md`  ·  _was_ `docs/F3_SIS_360_MIGRATION.md`
- `F4_EXAM_MIGRATION.md`  ·  _was_ `docs/F4_EXAM_MIGRATION.md`
- `F5_ATTENDANCE_MIGRATION.md`  ·  _was_ `docs/F5_ATTENDANCE_MIGRATION.md`

## completed/  (257 files)

Certifications, completion reports, milestone/wave/batch closures, live-backend build logs, and the full per-version release-notes history (`releases/`).

- `AKSHARA_V1_FINAL_SIGNOFF.md`  ·  _was_ `docs/AKSHARA_V1_FINAL_SIGNOFF.md`
- `AKSHARA_V1_RC_LOCK.md`  ·  _was_ `docs/AKSHARA_V1_RC_LOCK.md`
- `AKSHARA_V1_RELEASE_CANDIDATE.md`  ·  _was_ `docs/AKSHARA_V1_RELEASE_CANDIDATE.md`
- `B10_ORGANIZATION_BUILDER_CERTIFICATION.md`  ·  _was_ `docs/B10_ORGANIZATION_BUILDER_CERTIFICATION.md`
- `B11_DYNAMIC_WIDGET_PLATFORM_CERTIFICATION.md`  ·  _was_ `docs/B11_DYNAMIC_WIDGET_PLATFORM_CERTIFICATION.md`
- `B1_ADMISSIONS_CRM_CERTIFICATION.md`  ·  _was_ `docs/B1_ADMISSIONS_CRM_CERTIFICATION.md`
- `B1_VPS_DEPLOY_RUNBOOK.md`  ·  _was_ `docs/B1_VPS_DEPLOY_RUNBOOK.md`
- `B2_CAPABILITY_GATING_SPEC.md`  ·  _was_ `docs/B2_CAPABILITY_GATING_SPEC.md`
- `B2_PREFLIGHT_REVIEW.md`  ·  _was_ `docs/B2_PREFLIGHT_REVIEW.md`
- `B2_STATUS_LEDGER.md`  ·  _was_ `docs/B2_STATUS_LEDGER.md`
- `B2_STEP2_CERTIFICATION.md`  ·  _was_ `docs/B2_STEP2_CERTIFICATION.md`
- `B2_STEP3_CERTIFICATION.md`  ·  _was_ `docs/B2_STEP3_CERTIFICATION.md`
- `B2_STEP4_5_CERTIFICATION.md`  ·  _was_ `docs/B2_STEP4_5_CERTIFICATION.md`
- `B2_STEP4_6_CERTIFICATION.md`  ·  _was_ `docs/B2_STEP4_6_CERTIFICATION.md`
- `B2_STEP4_CERTIFICATION.md`  ·  _was_ `docs/B2_STEP4_CERTIFICATION.md`
- `B2_STEP5_CERTIFICATION.md`  ·  _was_ `docs/B2_STEP5_CERTIFICATION.md`
- `B3_PARENT_INSIGHTS_CERTIFICATION.md`  ·  _was_ `docs/B3_PARENT_INSIGHTS_CERTIFICATION.md`
- `B4_AI_ADMISSIONS_ASSISTANT_CERTIFICATION.md`  ·  _was_ `docs/B4_AI_ADMISSIONS_ASSISTANT_CERTIFICATION.md`
- `B5_WHATSAPP_CONTACT_SURFACES_CERTIFICATION.md`  ·  _was_ `docs/B5_WHATSAPP_CONTACT_SURFACES_CERTIFICATION.md`
- `B6_MARKETING_ENGINE_CERTIFICATION.md`  ·  _was_ `docs/B6_MARKETING_ENGINE_CERTIFICATION.md`
- `B7_AI_SCHOOL_BUILDER_CERTIFICATION.md`  ·  _was_ `docs/B7_AI_SCHOOL_BUILDER_CERTIFICATION.md`
- `B7_ONBOARDING_LIVE_CERTIFICATION.md`  ·  _was_ `docs/B7_ONBOARDING_LIVE_CERTIFICATION.md`
- `B8_DIRECTOR_MULTI_SCHOOL_CERTIFICATION.md`  ·  _was_ `docs/B8_DIRECTOR_MULTI_SCHOOL_CERTIFICATION.md`
- `B9_ADVANCED_AI_PREDICTIONS_CERTIFICATION.md`  ·  _was_ `docs/B9_ADVANCED_AI_PREDICTIONS_CERTIFICATION.md`
- `BATCH_A_COMPLETION_REPORT.md`  ·  _was_ `docs/BATCH_A_COMPLETION_REPORT.md`
- `DEPLOY_WAVE1.md`  ·  _was_ `deploy/akshara-vps/DEPLOY_WAVE1.md`
- `ERP_FINAL_COMPLETION_PLAN.md`  ·  _was_ `docs/ERP_FINAL_COMPLETION_PLAN.md`
- `FCM_PUSH_HTTP_V1_CERTIFICATION.md`  ·  _was_ `docs/FCM_PUSH_HTTP_V1_CERTIFICATION.md`
- `FINAL_PILOT_CLOSURE_REPORT.md`  ·  _was_ `docs/FINAL_PILOT_CLOSURE_REPORT.md`
- `FULL_LIVE_JOURNEY_CERTIFICATION.md`  ·  _was_ `docs/FULL_LIVE_JOURNEY_CERTIFICATION.md`
- `FUTURE_VISION_RECONCILIATION.md`  ·  _was_ `docs/_archive/FUTURE_VISION_RECONCILIATION.md`
- `GOVERNANCE_COMPLETION_REPORT.md`  ·  _was_ `docs/GOVERNANCE_COMPLETION_REPORT.md`
- `HOLIDAY_PUBLISHER_PHASE1_CERTIFICATION.md`  ·  _was_ `docs/HOLIDAY_PUBLISHER_PHASE1_CERTIFICATION.md`
- `INTEL_03_COMPLETION_REPORT.md`  ·  _was_ `docs/INTEL_03_COMPLETION_REPORT.md`
- `JOURNEY_WAVE_0_CERTIFICATION.md`  ·  _was_ `docs/JOURNEY_WAVE_0_CERTIFICATION.md`
- `JOURNEY_WAVE_1_CERTIFICATION.md`  ·  _was_ `docs/JOURNEY_WAVE_1_CERTIFICATION.md`
- `JOURNEY_WAVE_2_CERTIFICATION.md`  ·  _was_ `docs/JOURNEY_WAVE_2_CERTIFICATION.md`
- `JOURNEY_WAVE_3_CERTIFICATION.md`  ·  _was_ `docs/JOURNEY_WAVE_3_CERTIFICATION.md`
- `JOURNEY_WAVE_4_CERTIFICATION.md`  ·  _was_ `docs/JOURNEY_WAVE_4_CERTIFICATION.md`
- `JOURNEY_WAVE_5_CERTIFICATION.md`  ·  _was_ `docs/JOURNEY_WAVE_5_CERTIFICATION.md`
- `LEGAL_COMPLIANCE_CERTIFICATION.md`  ·  _was_ `docs/LEGAL_COMPLIANCE_CERTIFICATION.md`
- `LIVE_BACKEND_BATCH2_SAFE_LOGIN.md`  ·  _was_ `docs/LIVE_BACKEND_BATCH2_SAFE_LOGIN.md`
- `LIVE_BACKEND_BATCH3_CORE_LOOP.md`  ·  _was_ `docs/LIVE_BACKEND_BATCH3_CORE_LOOP.md`
- `LIVE_BACKEND_BATCH4_MONEY_LOOP.md`  ·  _was_ `docs/LIVE_BACKEND_BATCH4_MONEY_LOOP.md`
- `LIVE_BACKEND_BATCH5_MODULE_WRITES_RBAC.md`  ·  _was_ `docs/LIVE_BACKEND_BATCH5_MODULE_WRITES_RBAC.md`
- `LIVE_BACKEND_BATCH6_DIRECTOR_AND_IDENTITY.md`  ·  _was_ `docs/LIVE_BACKEND_BATCH6_DIRECTOR_AND_IDENTITY.md`
- `LIVE_BACKEND_BATCH7_STORAGE_BACKUPS_MONITORING.md`  ·  _was_ `docs/LIVE_BACKEND_BATCH7_STORAGE_BACKUPS_MONITORING.md`
- `LIVE_BACKEND_BATCH8B_QUESTION_INTELLIGENCE.md`  ·  _was_ `docs/LIVE_BACKEND_BATCH8B_QUESTION_INTELLIGENCE.md`
- `LIVE_BACKEND_BATCH8_REAL_AI.md`  ·  _was_ `docs/LIVE_BACKEND_BATCH8_REAL_AI.md`
- `LIVE_BACKEND_WIRING_BATCH1.md`  ·  _was_ `docs/LIVE_BACKEND_WIRING_BATCH1.md`
- `M14_COMPLETION_REPORT.md`  ·  _was_ `docs/M14_COMPLETION_REPORT.md`
- `M15_CERTIFICATION_REPORT.md`  ·  _was_ `docs/M15_CERTIFICATION_REPORT.md`
- `MASTER_MILESTONE_TRACKER.md`  ·  _was_ `docs/MASTER_MILESTONE_TRACKER.md`
- `MILESTONE_10_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_10_COMPLETION_REPORT.md`
- `MILESTONE_11_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_11_COMPLETION_REPORT.md`
- `MILESTONE_12_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_12_COMPLETION_REPORT.md`
- `MILESTONE_13_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_13_COMPLETION_REPORT.md`
- `MILESTONE_1_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_1_COMPLETION_REPORT.md`
- `MILESTONE_2_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_2_COMPLETION_REPORT.md`
- `MILESTONE_3_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_3_COMPLETION_REPORT.md`
- `MILESTONE_4_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_4_COMPLETION_REPORT.md`
- `MILESTONE_6_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_6_COMPLETION_REPORT.md`
- `MILESTONE_7_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_7_COMPLETION_REPORT.md`
- `MILESTONE_8_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_8_COMPLETION_REPORT.md`
- `MILESTONE_9_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_9_COMPLETION_REPORT.md`
- `MILESTONE_COMPLETION_REPORT.md`  ·  _was_ `docs/MILESTONE_COMPLETION_REPORT.md`
- `ONBOARDING_DYNAMIC_CONFIGURATION_CERTIFICATION.md`  ·  _was_ `docs/ONBOARDING_DYNAMIC_CONFIGURATION_CERTIFICATION.md`
- `P1_INTEGRATION_CERTIFICATION.md`  ·  _was_ `docs/P1_INTEGRATION_CERTIFICATION.md`
- `PATROL_BATCH_01_CERTIFICATION.md`  ·  _was_ `docs/PATROL_BATCH_01_CERTIFICATION.md`
- `PATROL_BATCH_02B_CERTIFICATION.md`  ·  _was_ `docs/PATROL_BATCH_02B_CERTIFICATION.md`
- `PATROL_BATCH_02_CERTIFICATION.md`  ·  _was_ `docs/PATROL_BATCH_02_CERTIFICATION.md`
- `PATROL_CERTIFICATION_REPORT.md`  ·  _was_ `docs/PATROL_CERTIFICATION_REPORT.md`
- `PATROL_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PATROL_FINAL_CERTIFICATION.md`
- `PATROL_RECERTIFICATION_PLAN.md`  ·  _was_ `docs/PATROL_RECERTIFICATION_PLAN.md`
- `PERFORMANCE_CERTIFICATION_REPORT.md`  ·  _was_ `docs/PERFORMANCE_CERTIFICATION_REPORT.md`
- `PHASE_D_M1_COMPLETION_REPORT.md`  ·  _was_ `docs/PHASE_D_M1_COMPLETION_REPORT.md`
- `PHASE_D_M1_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_D_M1_FINAL_CERTIFICATION.md`
- `PHASE_D_M2_COMPLETION_REPORT.md`  ·  _was_ `docs/PHASE_D_M2_COMPLETION_REPORT.md`
- `PHASE_D_M2_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_D_M2_FINAL_CERTIFICATION.md`
- `PHASE_D_M3_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_D_M3_FINAL_CERTIFICATION.md`
- `PHASE_D_M4_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_D_M4_FINAL_CERTIFICATION.md`
- `PHASE_D_M5_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_D_M5_FINAL_CERTIFICATION.md`
- `PHASE_D_M6_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_D_M6_FINAL_CERTIFICATION.md`
- `PHASE_D_M7_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_D_M7_FINAL_CERTIFICATION.md`
- `PHASE_F1_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_F1_FINAL_CERTIFICATION.md`
- `PHASE_F2_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_F2_FINAL_CERTIFICATION.md`
- `PHASE_F3_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_F3_FINAL_CERTIFICATION.md`
- `PHASE_F4_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_F4_FINAL_CERTIFICATION.md`
- `PHASE_F5_FINAL_CERTIFICATION.md`  ·  _was_ `docs/PHASE_F5_FINAL_CERTIFICATION.md`
- `PILOT_SCHOOL_SIMULATION.md`  ·  _was_ `docs/PILOT_SCHOOL_SIMULATION.md`
- `PILOT_SIGNOFF_REPORT.md`  ·  _was_ `docs/PILOT_SIGNOFF_REPORT.md`
- `PRE_M15_CERTIFICATION_REPORT.md`  ·  _was_ `docs/PRE_M15_CERTIFICATION_REPORT.md`
- `PRIOR_ARCHIVE_NOTE.md`  ·  _was_ `docs/_archive/README.md`
- `PRODUCTION_SIGNOFF_REPORT.md`  ·  _was_ `docs/PRODUCTION_SIGNOFF_REPORT.md`
- `PROJECT_CLEANUP_RECOMMENDATIONS.md`  ·  _was_ `docs/_archive/PROJECT_CLEANUP_RECOMMENDATIONS.md`
- `QUESTION_INTELLIGENCE_LIVE_CERTIFICATION.md`  ·  _was_ `docs/QUESTION_INTELLIGENCE_LIVE_CERTIFICATION.md`
- `RED_TEAM_CERTIFICATION_AUDIT.md`  ·  _was_ `docs/RED_TEAM_CERTIFICATION_AUDIT.md`
- `RED_TEAM_FINAL_CERTIFICATION.md`  ·  _was_ `docs/RED_TEAM_FINAL_CERTIFICATION.md`
- `RED_TEAM_WAVE_1_CERTIFICATION.md`  ·  _was_ `docs/RED_TEAM_WAVE_1_CERTIFICATION.md`
- `RED_TEAM_WAVE_2_CERTIFICATION.md`  ·  _was_ `docs/RED_TEAM_WAVE_2_CERTIFICATION.md`
- `RED_TEAM_WAVE_3_CERTIFICATION.md`  ·  _was_ `docs/RED_TEAM_WAVE_3_CERTIFICATION.md`
- `RED_TEAM_WAVE_4_CERTIFICATION.md`  ·  _was_ `docs/RED_TEAM_WAVE_4_CERTIFICATION.md`
- `RED_TEAM_WAVE_5_CERTIFICATION.md`  ·  _was_ `docs/RED_TEAM_WAVE_5_CERTIFICATION.md`
- `RELEASE_CANDIDATE_PLAN.md`  ·  _was_ `docs/RELEASE_CANDIDATE_PLAN.md`
- `SOCIAL_MEDIA_INTEGRATION_PHASE2.md`  ·  _was_ `docs/SOCIAL_MEDIA_INTEGRATION_PHASE2.md`
- `WAVE0_TRIAGE_AND_GATES_CERTIFICATION.md`  ·  _was_ `docs/WAVE0_TRIAGE_AND_GATES_CERTIFICATION.md`
- `WAVE1_COMPLETION_CERTIFICATION.md`  ·  _was_ `docs/WAVE1_COMPLETION_CERTIFICATION.md`
- `WAVE1_LIVE_CERTIFICATION.md`  ·  _was_ `docs/WAVE1_LIVE_CERTIFICATION.md`
- `WAVE2_COMPLETION_CERTIFICATION.md`  ·  _was_ `docs/WAVE2_COMPLETION_CERTIFICATION.md`
- `WAVE3_COMPLETION_CERTIFICATION.md`  ·  _was_ `docs/WAVE3_COMPLETION_CERTIFICATION.md`
- `WAVE4_COMPLETION_CERTIFICATION.md`  ·  _was_ `docs/WAVE4_COMPLETION_CERTIFICATION.md`
- `WAVE5_COMPLETION_CERTIFICATION.md`  ·  _was_ `docs/WAVE5_COMPLETION_CERTIFICATION.md`
- `WHATSAPP_DEEPLINK_CERTIFICATION.md`  ·  _was_ `docs/WHATSAPP_DEEPLINK_CERTIFICATION.md`
- `WORKFLOW_CERTIFICATION_REPORT.md`  ·  _was_ `docs/WORKFLOW_CERTIFICATION_REPORT.md`

### `completed/releases/` — 143 files (historical, summarised)

Representative entries: `Exams-Slice4-Approve-Publish.md`, `Phase5-Staging-Validation.md`, `RealSchoolValidation.md`, `Staging-Migration-Recovery.md`, `v0.2-Academic-MVP.md`, `v0.3-Admissions-MVP.md`, `v0.4-Finance-MVP-Phase1.md`, `v0.5-Student-SIS-Phase1.md`, … (+135 more).

## temporary/  (24 files)

Handoffs, weekly/overnight/cycle progress reports, process/orchestration notes, status snapshots and one-off scratch reports.

- `ADVANCED_FEATURE_STATUS.md`  ·  _was_ `docs/_archive/ADVANCED_FEATURE_STATUS.md`
- `AI_COPILOT_STATUS.md`  ·  _was_ `docs/_archive/AI_COPILOT_STATUS.md`
- `AKSHARA_V1_FINAL_STATUS.md`  ·  _was_ `docs/_archive/AKSHARA_V1_FINAL_STATUS.md`
- `CLAUDE_HANDOFF.md`  ·  _was_ `docs/CLAUDE_HANDOFF.md`
- `CURSOR_WORKFLOW.md`  ·  _was_ `docs/CURSOR_WORKFLOW.md`
- `DOCUMENTATION_SYNC_REPORT.md`  ·  _was_ `docs/DOCUMENTATION_SYNC_REPORT.md`
- `FINAL_PRE_PATROL_STATUS.md`  ·  _was_ `docs/_archive/FINAL_PRE_PATROL_STATUS.md`
- `GIT_READINESS_REPORT.md`  ·  _was_ `docs/GIT_READINESS_REPORT.md`
- `INTELLIGENCE_FOUNDATION_STATUS.md`  ·  _was_ `docs/_archive/INTELLIGENCE_FOUNDATION_STATUS.md`
- `M-D3_PRECHECK_REPORT.md`  ·  _was_ `docs/M-D3_PRECHECK_REPORT.md`
- `M-D3_PUSH_REPORT.md`  ·  _was_ `docs/M-D3_PUSH_REPORT.md`
- `MULTI_AGENT_SYSTEM.md`  ·  _was_ `docs/MULTI_AGENT_SYSTEM.md`
- `ORCHESTRATOR_AGENT.md`  ·  _was_ `docs/ORCHESTRATOR_AGENT.md`
- `PATROL_COVERAGE_AUDIT.md`  ·  _was_ `docs/PATROL_COVERAGE_AUDIT.md`
- `PATROL_CURRENT_STATUS.md`  ·  _was_ `docs/_archive/PATROL_CURRENT_STATUS.md`
- `PATROL_QA_ORCHESTRATOR.md`  ·  _was_ `docs/PATROL_QA_ORCHESTRATOR.md`
- `PRE_CLAUDE_HANDOFF_REPORT.md`  ·  _was_ `docs/PRE_CLAUDE_HANDOFF_REPORT.md`
- `PRE_F4_STABILIZATION_PUSH_REPORT.md`  ·  _was_ `docs/PRE_F4_STABILIZATION_PUSH_REPORT.md`
- `PRE_F4_STABILIZATION_REPORT.md`  ·  _was_ `docs/PRE_F4_STABILIZATION_REPORT.md`
- `PRODUCTION_READINESS_PROGRESS.md`  ·  _was_ `docs/PRODUCTION_READINESS_PROGRESS.md`
- `PROJECT_BASELINE_STATUS.md`  ·  _was_ `docs/_archive/PROJECT_BASELINE_STATUS.md`
- `PROJECT_STATUS_SYNC_REPORT.md`  ·  _was_ `docs/_archive/PROJECT_STATUS_SYNC_REPORT.md`
- `RBAC_SYNC_REPORT.md`  ·  _was_ `docs/RBAC_SYNC_REPORT.md`
- `RELEASE_BASELINE.md`  ·  _was_ `docs/_archive/RELEASE_BASELINE.md`


## Post-2026-06-27 additions  (2026-07-03 reconciliation)

Historical documents that landed in the active tree *after* the 2026-06-27 cleanup and were archived
on 2026-07-03. Each was superseded or is a completed-audit artifact; none is used for current
decisions. History preserved (recover with `git log --follow`).

### → audit/
- `still_pending.md`  ·  _was_ `still_pending.md` (repo root) — Master Product & Commercial Audit, **self-declared superseded** by `docs/PRODUCT_COMMERCIAL_BACKLOG.md` (reconciled 2026-06-30). The backlog's "Reconciled from" link now points here.
- `fable-ui-ux-audit/audit_by_fable_phase1.md` … `phase4.md`  ·  _was_ `docs/design/audit_by_fable_phase{1..4}.md` — completed prior Fable UI/UX audit round (superseded by the upcoming independent Fable audit).
- `fable-ui-ux-audit/final_ui_ux_master_report.md`  ·  _was_ `docs/design/final_ui_ux_master_report.md` — summary of that prior audit round.
- `m15-visual-gap/screenshots/…` (17 PNGs)  ·  _was_ `docs/audit/m15-visual-gap/screenshots/…` — reunited with `M15_VISUAL_GAP_REPORT.md` (its relative image links now resolve again).

### → design/
- `mockups-uiux/…` (21 PNGs)  ·  _was_ `docs/UIUX/*.png` — figma-era per-role dashboard mockups (Jun 12), unreferenced by any active doc.
- `mockups/parent_home_{dark,light}.{html,png}` (4)  ·  _was_ `docs/design/mockups/…` — parent-home design mockups.

### → qa/
- `screenshots/launch_login.png`, `launch_qa_login.png`, `smoke_back_to_login.png`, `smoke_otp_screen.png`, `smoke_principal_dashboard.png`  ·  _was_ repo root — one-off launch/smoke capture PNGs.
