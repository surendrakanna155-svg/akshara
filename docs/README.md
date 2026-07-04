# Akshara ERP — Active Documentation Index

> **This is the authoritative entry point.** Every document listed here is current and required for day-to-day engineering. Read these — *not* `docs/archive/`.

> _Total active documents: **~204**. Completed / superseded / historical material lives under [`docs/archive/`](archive/README.md) (kept for traceability, never read for current decisions)._

> _Last reorganised: 2026-06-27 (Documentation Cleanup — see [`DOCUMENTATION_CLEANUP_REPORT.md`](DOCUMENTATION_CLEANUP_REPORT.md)); reconciled 2026-07-03 (post-cleanup drift: certifications, decision records and backlogs indexed; historical items archived). Repo-wide start-here: [`../PROJECT_INDEX.md`](../PROJECT_INDEX.md)._


## Engineering governance (highest authority)

- [`docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`](engineering/AKSHARA_ENGINEERING_CONSTITUTION.md)
- [`docs/engineering/ENGINEERING_GATE_POLICY.md`](engineering/ENGINEERING_GATE_POLICY.md)
- [`docs/engineering/eos/EOS_RUN_LEDGER.md`](engineering/eos/EOS_RUN_LEDGER.md)
- [`docs/engineering/eos/README.md`](engineering/eos/README.md)

## Project context & entry points

- [`AGENTS.md`](../AGENTS.md)
- [`IDEAS_BACKLOG.md`](../IDEAS_BACKLOG.md)
- [`PROJECT_CONTEXT.md`](../PROJECT_CONTEXT.md)

## Current phase — QA program & active platform work

- [`docs/DATA_RELIABILITY_PLATFORM_DESIGN.md`](DATA_RELIABILITY_PLATFORM_DESIGN.md)
- [`docs/DATA_RELIABILITY_PLATFORM_PHASE0_PROGRESS.md`](DATA_RELIABILITY_PLATFORM_PHASE0_PROGRESS.md)
- [`docs/DATA_RELIABILITY_PLATFORM_CERTIFICATION.md`](DATA_RELIABILITY_PLATFORM_CERTIFICATION.md)
- [`docs/FINAL_QA_AUDIT.md`](FINAL_QA_AUDIT.md)
- [`docs/FINAL_QA_MASTER_TRACKER.md`](FINAL_QA_MASTER_TRACKER.md)
- [`docs/FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md)
- [`docs/ProjectStatus.md`](ProjectStatus.md)

## Product & commercial backlogs (source of truth)

- [`docs/PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md) — reconciled SoT (5 queues); supersedes the archived `still_pending.md` audit.
- [`docs/PRODUCT_ENHANCEMENT_BACKLOG.md`](PRODUCT_ENHANCEMENT_BACKLOG.md) — 🔒 FROZEN rev 5 (single source of truth for product-excellence work).

## Design & engineering decision records (frozen)

- [`docs/ATTENDANCE_AUTH_DESIGN_DECISION.md`](ATTENDANCE_AUTH_DESIGN_DECISION.md) — FINAL (2026-07-01): staff attendance auth = GPS geofence + anti-mock + live camera face.

## Certifications (current QA & release evidence)

> These are live evidence cross-referenced by `FINAL_QA_ROADMAP.md`, `FINAL_QA_MASTER_TRACKER.md`
> and the EOS run ledger. Kept active (not archived) so those references resolve. New milestone
> closures after this set should be born in `archive/completed/`.

- [`docs/QW1_CI_ENFORCEMENT_CERTIFICATION.md`](QW1_CI_ENFORCEMENT_CERTIFICATION.md)
- [`docs/QW1_COMPLETION_CERTIFICATION.md`](QW1_COMPLETION_CERTIFICATION.md)
- [`docs/QW1_PERSONA_RBAC_MONEY_CERTIFICATION.md`](QW1_PERSONA_RBAC_MONEY_CERTIFICATION.md)
- [`docs/QW2_COMPLETION_CERTIFICATION.md`](QW2_COMPLETION_CERTIFICATION.md)
- [`docs/QW3_COMPLETION_CERTIFICATION.md`](QW3_COMPLETION_CERTIFICATION.md)
- [`docs/QW4_BACKEND_API_CERTIFICATION.md`](QW4_BACKEND_API_CERTIFICATION.md)
- [`docs/QW5_COMPLETION_CERTIFICATION.md`](QW5_COMPLETION_CERTIFICATION.md)
- [`docs/QW6_COMPLETION_CERTIFICATION.md`](QW6_COMPLETION_CERTIFICATION.md)
- [`docs/QW7_COMPLETION_CERTIFICATION.md`](QW7_COMPLETION_CERTIFICATION.md)
- [`docs/QW8_COMPLETION_CERTIFICATION.md`](QW8_COMPLETION_CERTIFICATION.md)
- [`docs/QA_R_008_SECURITY_CERTIFICATION.md`](QA_R_008_SECURITY_CERTIFICATION.md)
- [`docs/STAFF_FACE_ID_ATTENDANCE_CERTIFICATION.md`](STAFF_FACE_ID_ATTENDANCE_CERTIFICATION.md)

## Architecture (canonical)

- [`docs/AuditArchitecture.md`](AuditArchitecture.md)
- [`docs/AuthArchitecture.md`](AuthArchitecture.md)
- [`docs/BackendArchitecture.md`](BackendArchitecture.md)
- [`docs/BACKUP_RESTORE_RUNBOOK.md`](BACKUP_RESTORE_RUNBOOK.md) — **the single canonical backup & restore runbook** (self-hosted VPS: nightly encrypted `pg_dump`, monthly restore drill, operator-over-SSH restore). `Operations/Backup-Runbook.md` + `Operations/Restore-Runbook.md` are now redirect stubs to it (consolidated 2026-07-04, DOC-7).
- [`docs/ClientBackendAlignment.md`](ClientBackendAlignment.md)
- [`docs/DEPLOYMENT_MODEL_AND_DR_PLAN.md`](DEPLOYMENT_MODEL_AND_DR_PLAN.md)
- [`docs/DatabaseArchitecture.md`](DatabaseArchitecture.md)
- [`docs/DeploymentArchitecture.md`](DeploymentArchitecture.md)
- [`docs/RBACArchitecture.md`](RBACArchitecture.md)
- [`docs/TechnicalArchitecture.md`](TechnicalArchitecture.md)
- [`docs/TenantArchitecture.md`](TenantArchitecture.md)

## Governance, charter & living checklists

- [`docs/PERFORMANCE_TARGETS.md`](PERFORMANCE_TARGETS.md)
- [`docs/PILOT_DEPLOYMENT_CHECKLIST.md`](PILOT_DEPLOYMENT_CHECKLIST.md)
- [`docs/PilotSchoolChecklist.md`](PilotSchoolChecklist.md)
- [`docs/ProductionReadinessChecklist.md`](ProductionReadinessChecklist.md)
- [`docs/ProjectCharter.md`](ProjectCharter.md)
- [`docs/ReleaseGovernance.md`](ReleaseGovernance.md)
- [`docs/StagingValidationChecklist.md`](StagingValidationChecklist.md)
- [`docs/TechnicalDebt/TD-P0-01-RLS-Enforcement.md`](TechnicalDebt/TD-P0-01-RLS-Enforcement.md)
- [`docs/TechnicalDebtRegister.md`](TechnicalDebtRegister.md)

## Design system

- [`docs/FlutterDesignSystem.md`](FlutterDesignSystem.md)
- [`docs/design/VISUAL_DESIGN_SYSTEM.md`](design/VISUAL_DESIGN_SYSTEM.md)

## Module / role specifications

- [`docs/Academic.md`](Academic.md)
- [`docs/Admissions.md`](Admissions.md)
- [`docs/AksharaControlCenter.md`](AksharaControlCenter.md)
- [`docs/Alumni.md`](Alumni.md)
- [`docs/Audit.md`](Audit.md)
- [`docs/Director.md`](Director.md)
- [`docs/HR.md`](HR.md)
- [`docs/Hostel.md`](Hostel.md)
- [`docs/Inventory.md`](Inventory.md)
- [`docs/Library.md`](Library.md)
- [`docs/Management.md`](Management.md)
- [`docs/Marketing.md`](Marketing.md)
- [`docs/Notifications.md`](Notifications.md)
- [`docs/Parent.md`](Parent.md)
- [`docs/Principal.md`](Principal.md)
- [`docs/Reports.md`](Reports.md)
- [`docs/Student.md`](Student.md)
- [`docs/StudentSIS.md`](StudentSIS.md)
- [`docs/Teacher.md`](Teacher.md)
- [`docs/Transport.md`](Transport.md)
- [`docs/finance.md`](finance.md)

## Reference inventories

- [`docs/MobileScreenInventory.md`](MobileScreenInventory.md)
- [`docs/PermissionCoverageInventory.md`](PermissionCoverageInventory.md)
- [`docs/RouteInventory.md`](RouteInventory.md)
- [`docs/SharedWidgetInventory.md`](SharedWidgetInventory.md)

## SRS — source of truth

- [`docs/Akshara_ERP_Master_Index_Guide.txt`](Akshara_ERP_Master_Index_Guide.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_1.txt`](Akshara_ERP_Master_SRS_Part_1.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_10.txt`](Akshara_ERP_Master_SRS_Part_10.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_11A.txt`](Akshara_ERP_Master_SRS_Part_11A.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_11B.txt`](Akshara_ERP_Master_SRS_Part_11B.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_11C.txt`](Akshara_ERP_Master_SRS_Part_11C.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_11D.txt`](Akshara_ERP_Master_SRS_Part_11D.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_11E.txt`](Akshara_ERP_Master_SRS_Part_11E.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_12.txt`](Akshara_ERP_Master_SRS_Part_12.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_13.txt`](Akshara_ERP_Master_SRS_Part_13.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_14.txt`](Akshara_ERP_Master_SRS_Part_14.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_15.txt`](Akshara_ERP_Master_SRS_Part_15.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_16.txt`](Akshara_ERP_Master_SRS_Part_16.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_17.txt`](Akshara_ERP_Master_SRS_Part_17.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_18.txt`](Akshara_ERP_Master_SRS_Part_18.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_19.txt`](Akshara_ERP_Master_SRS_Part_19.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_2.txt`](Akshara_ERP_Master_SRS_Part_2.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_20.txt`](Akshara_ERP_Master_SRS_Part_20.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_3.txt`](Akshara_ERP_Master_SRS_Part_3.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_4.txt`](Akshara_ERP_Master_SRS_Part_4.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_5.txt`](Akshara_ERP_Master_SRS_Part_5.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_6.txt`](Akshara_ERP_Master_SRS_Part_6.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_7.txt`](Akshara_ERP_Master_SRS_Part_7.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_8.txt`](Akshara_ERP_Master_SRS_Part_8.txt)
- [`docs/Akshara_ERP_Master_SRS_Part_9.txt`](Akshara_ERP_Master_SRS_Part_9.txt)
- [`docs/Akshara_School_ERP_SRS_v1.txt`](Akshara_School_ERP_SRS_v1.txt)

## Operations runbooks & pilot guides

- [`docs/Operations/Backup-Runbook.md`](Operations/Backup-Runbook.md)
- [`docs/Operations/Customer-Readiness-Report.md`](Operations/Customer-Readiness-Report.md)
- [`docs/Operations/Demo-School-Validation-Plan.md`](Operations/Demo-School-Validation-Plan.md)
- [`docs/Operations/Deployment-Guide.md`](Operations/Deployment-Guide.md)
- [`docs/Operations/Disaster-Recovery-Checklist.md`](Operations/Disaster-Recovery-Checklist.md)
- [`docs/Operations/First-Day-Go-Live-Checklist.md`](Operations/First-Day-Go-Live-Checklist.md)
- [`docs/Operations/Go-Live-Checklist.md`](Operations/Go-Live-Checklist.md)
- [`docs/Operations/Operational-Readiness-Report.md`](Operations/Operational-Readiness-Report.md)
- [`docs/Operations/Pilot-Issue-Tracker.md`](Operations/Pilot-Issue-Tracker.md)
- [`docs/Operations/Pilot-Onboarding-Runbook.md`](Operations/Pilot-Onboarding-Runbook.md)
- [`docs/Operations/Pilot/Demo-Data-Guide.md`](Operations/Pilot/Demo-Data-Guide.md)
- [`docs/Operations/Pilot/Parent-Guide.md`](Operations/Pilot/Parent-Guide.md)
- [`docs/Operations/Pilot/Pilot-Checklist.md`](Operations/Pilot/Pilot-Checklist.md)
- [`docs/Operations/Pilot/Principal-Guide.md`](Operations/Pilot/Principal-Guide.md)
- [`docs/Operations/Pilot/School-Onboarding-Guide.md`](Operations/Pilot/School-Onboarding-Guide.md)
- [`docs/Operations/Pilot/Teacher-Guide.md`](Operations/Pilot/Teacher-Guide.md)
- [`docs/Operations/Production-Integrations.md`](Operations/Production-Integrations.md)
- [`docs/Operations/Production-Security-Checklist.md`](Operations/Production-Security-Checklist.md)
- [`docs/Operations/Production-Validation-Report.md`](Operations/Production-Validation-Report.md)
- [`docs/Operations/Restore-Runbook.md`](Operations/Restore-Runbook.md)
- [`docs/Operations/Rollback-Checklist.md`](Operations/Rollback-Checklist.md)
- [`docs/Operations/Rollout-Checklist.md`](Operations/Rollout-Checklist.md)
- [`docs/Operations/SaaS-Launch-Checklist.md`](Operations/SaaS-Launch-Checklist.md)
- [`docs/Operations/School-Setup-Checklist.md`](Operations/School-Setup-Checklist.md)
- [`docs/Operations/UAT-Checklist-v1.0-rc1.md`](Operations/UAT-Checklist-v1.0-rc1.md)
- [`docs/Operations/guides/Parent-Activation-Guide.md`](Operations/guides/Parent-Activation-Guide.md)
- [`docs/Operations/guides/Real-School-Onboarding-Guide.md`](Operations/guides/Real-School-Onboarding-Guide.md)
- [`docs/Operations/guides/School-Admin-Quick-Start.md`](Operations/guides/School-Admin-Quick-Start.md)
- [`docs/Operations/guides/Teacher-Quick-Start.md`](Operations/guides/Teacher-Quick-Start.md)
- [`docs/Operations/templates/parent_guardian_guide.md`](Operations/templates/parent_guardian_guide.md)
- [`docs/Operations/workflows/Escalation-Workflow.md`](Operations/workflows/Escalation-Workflow.md)
- [`docs/Operations/workflows/Exam-Publish-Workflow.md`](Operations/workflows/Exam-Publish-Workflow.md)
- [`docs/Operations/workflows/Student-Risk-Workflow.md`](Operations/workflows/Student-Risk-Workflow.md)
- [`docs/Operations/workflows/Teacher-Parent-Communication-Workflow.md`](Operations/workflows/Teacher-Parent-Communication-Workflow.md)
- [`docs/Operations/workflows/Unified-Onboarding-Workflow.md`](Operations/workflows/Unified-Onboarding-Workflow.md)

## Device & release testing guides

- [`docs/Testing/Android-Tester-Pack.md`](Testing/Android-Tester-Pack.md)
- [`docs/Testing/Apple-Distribution-Audit.md`](Testing/Apple-Distribution-Audit.md)
- [`docs/Testing/Apple-Go-Live-Checklist.md`](Testing/Apple-Go-Live-Checklist.md)
- [`docs/Testing/Bug-Report-Template.md`](Testing/Bug-Report-Template.md)
- [`docs/Testing/Bug-Triage-Process.md`](Testing/Bug-Triage-Process.md)
- [`docs/Testing/CoverageGuide.md`](Testing/CoverageGuide.md)
- [`docs/Testing/Demo-Accounts.md`](Testing/Demo-Accounts.md)
- [`docs/Testing/Demo-School-Validation.md`](Testing/Demo-School-Validation.md)
- [`docs/Testing/Device-Auth-Validation-Report.md`](Testing/Device-Auth-Validation-Report.md)
- [`docs/Testing/Device-Test-Plan.md`](Testing/Device-Test-Plan.md)
- [`docs/Testing/Device-Testing-Guide.md`](Testing/Device-Testing-Guide.md)
- [`docs/Testing/Final-Device-Readiness.md`](Testing/Final-Device-Readiness.md)
- [`docs/Testing/Final-Release-Audit.md`](Testing/Final-Release-Audit.md)
- [`docs/Testing/Maestro-Setup.md`](Testing/Maestro-Setup.md)
- [`docs/Testing/Patrol-Maestro-Strategy.md`](Testing/Patrol-Maestro-Strategy.md)
- [`docs/Testing/Patrol-Red-Team-Remediation.md`](Testing/Patrol-Red-Team-Remediation.md)
- [`docs/Testing/Patrol-Setup.md`](Testing/Patrol-Setup.md)
- [`docs/Testing/Real-User-Journeys.md`](Testing/Real-User-Journeys.md)
- [`docs/Testing/Release-Asset-Audit.md`](Testing/Release-Asset-Audit.md)
- [`docs/Testing/Release-Go-Live-Audit.md`](Testing/Release-Go-Live-Audit.md)
- [`docs/Testing/TestFlight-Execution-Guide.md`](Testing/TestFlight-Execution-Guide.md)
- [`docs/Testing/TestFlight-Upload-Guide.md`](Testing/TestFlight-Upload-Guide.md)
- [`docs/Testing/Tester-Instructions.md`](Testing/Tester-Instructions.md)
- [`docs/Testing/iOS-Build-Guide.md`](Testing/iOS-Build-Guide.md)
- [`docs/Testing/iOS-Device-Install-Guide.md`](Testing/iOS-Device-Install-Guide.md)
- [`docs/Testing/iOS-Execution-Checklist.md`](Testing/iOS-Execution-Checklist.md)
- [`docs/Testing/iPhone-Tester-Pack.md`](Testing/iPhone-Tester-Pack.md)
- [`docs/Testing/v18.0-Autonomous-QA-Report.md`](Testing/v18.0-Autonomous-QA-Report.md)

## Product vision & future tracks

- [`docs/Vision/FutureVision.md`](Vision/FutureVision.md)
- [`docs/Vision/ImplementationRoadmap.md`](Vision/ImplementationRoadmap.md)
- [`docs/Vision/design/AI-Content-Generation.md`](Vision/design/AI-Content-Generation.md)
- [`docs/Vision/design/AI-Question-Paper-System.md`](Vision/design/AI-Question-Paper-System.md)
- [`docs/Vision/design/Assessment-Intelligence-Platform.md`](Vision/design/Assessment-Intelligence-Platform.md) — 🔒 Master Plan v3.0 (locked owner vision, 2026-07-02)
- [`docs/Vision/design/Dynamic-Widget-Platform.md`](Vision/design/Dynamic-Widget-Platform.md)
- [`docs/Vision/design/Franchise-Management.md`](Vision/design/Franchise-Management.md)
- [`docs/Vision/design/FutureTracks-Index.md`](Vision/design/FutureTracks-Index.md)
- [`docs/Vision/design/Multi-Branch-Management.md`](Vision/design/Multi-Branch-Management.md)
- [`docs/Vision/design/Multi-School-SaaS-Operations.md`](Vision/design/Multi-School-SaaS-Operations.md)
- [`docs/Vision/design/Observability-Monitoring.md`](Vision/design/Observability-Monitoring.md)
- [`docs/Vision/design/Security-Pen-Testing.md`](Vision/design/Security-Pen-Testing.md)
- [`docs/Vision/design/Universal-Employee-System.md`](Vision/design/Universal-Employee-System.md)
- [`docs/Vision/design/Universal-Organization-Builder-v2.md`](Vision/design/Universal-Organization-Builder-v2.md)
- [`docs/Vision/design/Universal-Workflow-Engine.md`](Vision/design/Universal-Workflow-Engine.md)
- [`docs/Vision/design/WhatsApp-Business-Integration.md`](Vision/design/WhatsApp-Business-Integration.md)

## Legal & compliance suite

- [`docs/legal/ACCEPTABLE_USE_POLICY.md`](legal/ACCEPTABLE_USE_POLICY.md)
- [`docs/legal/AI_USAGE_AND_DISCLAIMER.md`](legal/AI_USAGE_AND_DISCLAIMER.md)
- [`docs/legal/CHANGELOG.md`](legal/CHANGELOG.md)
- [`docs/legal/CHILDREN_DATA_AND_CONSENT.md`](legal/CHILDREN_DATA_AND_CONSENT.md)
- [`docs/legal/DATA_BACKUP_AND_RECOVERY_POLICY.md`](legal/DATA_BACKUP_AND_RECOVERY_POLICY.md)
- [`docs/legal/DATA_RETENTION_AND_DELETION_POLICY.md`](legal/DATA_RETENTION_AND_DELETION_POLICY.md)
- [`docs/legal/IMPLEMENTATION_ROADMAP.md`](legal/IMPLEMENTATION_ROADMAP.md)
- [`docs/legal/INSTITUTION_AGREEMENT.md`](legal/INSTITUTION_AGREEMENT.md)
- [`docs/legal/PARENT_USER_TERMS.md`](legal/PARENT_USER_TERMS.md)
- [`docs/legal/PLACEHOLDERS.md`](legal/PLACEHOLDERS.md)
- [`docs/legal/PRIVACY_POLICY.md`](legal/PRIVACY_POLICY.md)
- [`docs/legal/README.md`](legal/README.md)
- [`docs/legal/SECURITY_AND_RESPONSIBLE_DISCLOSURE.md`](legal/SECURITY_AND_RESPONSIBLE_DISCLOSURE.md)
- [`docs/legal/SUBPROCESSORS.md`](legal/SUBPROCESSORS.md)
- [`docs/legal/TERMS_AND_CONDITIONS.md`](legal/TERMS_AND_CONDITIONS.md)

## Deployment / infra (VPS) & backend

- [`backend/README.md`](../backend/README.md)
- [`deploy/akshara-vps/DEPLOYMENT.md`](../deploy/akshara-vps/DEPLOYMENT.md)
- [`deploy/akshara-vps/backup/README.md`](../deploy/akshara-vps/backup/README.md)
- [`deploy/akshara-vps/monitoring/README.md`](../deploy/akshara-vps/monitoring/README.md)
- [`deploy/akshara-vps/storage/README.md`](../deploy/akshara-vps/storage/README.md)

## QA harness docs

- [`qa/README.md`](../qa/README.md)
- [`qa/agents/README.md`](../qa/agents/README.md)
- [`qa/agents/handoff_protocol.md`](../qa/agents/handoff_protocol.md)
