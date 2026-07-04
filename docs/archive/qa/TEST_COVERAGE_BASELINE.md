# QA Test Coverage Baseline (Post M13)

**Generated:** 2026-06-15 20:06 UTC  
**Baseline commit:** `8e30075`  
**Program:** Akshara QA Coverage Expansion (Post M13)

## Executive summary

| Metric | Count |
|--------|------:|
| QaTestKeys (static) | 361 |
| QaTestKeys (factory helpers) | 124 |
| QaTestKeys (total definitions) | 485 |
| Feature screens (`*_screen.dart`) | 252 |
| Route path constants | 255 |
| Patrol workflow files | 89 |
| Patrol test cases | 222 |
| Flutter unit/widget tests (gate) | 1683 |
| Keys with Patrol coverage (A) | 150 |
| Keys with any flutter test (A+B) | 211 |

### Platform readiness (Roadmap M1–M13)

| Area | Baseline |
|------|----------|
| ERP workflows | ~99.5% |
| Vision | ~98% |
| Intelligence | ~96% |
| Copilot | ~97% |
| Multi-School | ~92% |

> **Note:** Percentages above are workflow-proxy coverage from M13 certification. This baseline measures **action-level** coverage.

---

## 1. QaTestKeys inventory

Source: `lib/core/testing/qa_test_keys.dart`

| Key | Module | Action | Tested (flutter)? | Patrol? | Class |
|-----|--------|--------|:-----------------:|:-------:|:-----:|
| `admissionsApplicationSubmittedSnackbar` | Admissions | feedback | No | No | D |
| `admissionsApprovalQueueRow` | Admissions | widget | Yes | No | B |
| `admissionsApproveButton` | Admissions | button | No | No | D |
| `admissionsApprovedSnackbar` | Admissions | feedback | No | No | D |
| `admissionsCreateApplicationButton` | Admissions | button | No | No | D |
| `admissionsCreateLeadButton` | Admissions | button | Yes | No | B |
| `admissionsEnrollmentSubmittedSnackbar` | Admissions | feedback | No | No | D |
| `admissionsLeadClassField` | Admissions | field | No | No | D |
| `admissionsLeadCreatedSnackbar` | Admissions | feedback | No | No | D |
| `admissionsLeadDialogCreateButton` | Admissions | button | No | No | D |
| `admissionsLeadParentNameField` | Admissions | field | No | No | D |
| `admissionsLeadPhoneField` | Admissions | field | No | No | D |
| `admissionsLeadStudentNameField` | Admissions | field | No | No | D |
| `enrollmentContinueButton` | Admissions | button | No | No | D |
| `enrollmentStudentNameField` | Admissions | field | No | No | D |
| `enrollmentSubmitButton` | Admissions | button | Yes | No | B |
| `sisConvertEnrollmentButton` | Admissions | button | Yes | No | B |
| `erpMenuButton` | Auth/Shell | button | No | No | D |
| `erpNavModule` | Auth/Shell | navigation | No | Yes | A |
| `loginContinueButton` | Auth/Shell | button | No | No | D |
| `loginPhoneField` | Auth/Shell | field | Yes | No | B |
| `qaLoginScreen` | Auth/Shell | screen_anchor | No | No | D |
| `growthPlatformScreen` | Control Center | screen_anchor | No | Yes | A |
| `platformIntelligenceScreen` | Control Center | screen_anchor | No | No | D |
| `platformOperationsAccessReviewTile` | Control Center | widget | No | No | D |
| `platformOperationsAcknowledgeAlertButton` | Control Center | button | No | Yes | A |
| `platformOperationsAlertAcknowledgedSnackbar` | Control Center | feedback | No | Yes | A |
| `platformOperationsAlertTile` | Control Center | widget | Yes | No | B |
| `platformOperationsAlertsTab` | Control Center | navigation | No | Yes | A |
| `platformOperationsCompleteAccessReviewButton` | Control Center | button | No | No | D |
| `platformOperationsErrorsTab` | Control Center | navigation | No | No | D |
| `platformOperationsHealthTab` | Control Center | navigation | No | No | D |
| `platformOperationsHubScreen` | Control Center | screen_anchor | Yes | Yes | A |
| `platformOperationsIntelligenceHubLink` | Control Center | widget | No | No | D |
| `platformOperationsOperationsHubLink` | Control Center | widget | Yes | No | B |
| `platformOperationsOverviewTab` | Control Center | navigation | No | Yes | A |
| `platformOperationsReadinessCategory` | Control Center | widget | No | No | D |
| `platformOperationsReadinessTab` | Control Center | navigation | No | Yes | A |
| `platformOperationsRunTenantVerificationButton` | Control Center | button | No | No | D |
| `platformOperationsSecurityTab` | Control Center | navigation | No | No | D |
| `platformOperationsTabBar` | Control Center | navigation | No | No | D |
| `platformOperationsTenantTab` | Control Center | navigation | No | No | D |
| `platformOperationsTrustIntelligenceLink` | Control Center | widget | No | No | D |
| `platformOperationsWorkflowsTab` | Control Center | navigation | No | No | D |
| `aiAccessFloatingBubbleToggle` | Copilot/AI | widget | No | Yes | A |
| `aiAccessModeOption` | Copilot/AI | widget | No | Yes | A |
| `aiAccessSyncNote` | Copilot/AI | widget | No | Yes | A |
| `aiAssistantSettingsLink` | Copilot/AI | widget | No | Yes | A |
| `aiContentAudienceField` | Copilot/AI | field | No | No | D |
| `aiContentConstraintsField` | Copilot/AI | field | No | No | D |
| `aiContentCopiedSnackbar` | Copilot/AI | feedback | No | No | D |
| `aiContentCopyButton` | Copilot/AI | button | No | Yes | A |
| `aiContentGenerateButton` | Copilot/AI | button | Yes | Yes | A |
| `aiContentGeneratedCard` | Copilot/AI | ai | Yes | No | B |
| `aiContentGeneratedSnackbar` | Copilot/AI | feedback | Yes | No | B |
| `aiContentPromptField` | Copilot/AI | field | Yes | Yes | A |
| `aiContentShareButton` | Copilot/AI | button | No | Yes | A |
| `aiContentSharedSnackbar` | Copilot/AI | feedback | No | No | D |
| `aiContentToneField` | Copilot/AI | field | No | No | D |
| `aiContentTypePicker` | Copilot/AI | widget | No | No | D |
| `copilotAiEntryButton` | Copilot/AI | button | No | No | D |
| `copilotContextBanner` | Copilot/AI | feedback | No | Yes | A |
| `copilotFloatingDockCollapseButton` | Copilot/AI | button | No | No | D |
| `copilotFloatingDockContextSummary` | Copilot/AI | widget | No | Yes | A |
| `copilotFloatingDockFab` | Copilot/AI | button | Yes | Yes | A |
| `copilotFloatingDockOpenButton` | Copilot/AI | button | No | Yes | A |
| `copilotFloatingDockPanel` | Copilot/AI | widget | No | Yes | A |
| `copilotMessageField` | Copilot/AI | field | No | No | D |
| `copilotNewConversationButton` | Copilot/AI | button | No | Yes | A |
| `copilotPersonaContextBanner` | Copilot/AI | feedback | No | Yes | A |
| `copilotPersonaOpenFullButton` | Copilot/AI | button | No | No | D |
| `copilotPersonaPromptChip` | Copilot/AI | widget | No | Yes | A |
| `copilotPersonaReplyPanel` | Copilot/AI | widget | No | Yes | A |
| `copilotQuickActionReplyDialog` | Copilot/AI | widget | No | No | D |
| `copilotQuickActionTile` | Copilot/AI | widget | No | No | D |
| `copilotSendButton` | Copilot/AI | button | No | No | D |
| `copilotSidebarAiEntry` | Copilot/AI | widget | No | No | D |
| `erpCopilotButton` | Copilot/AI | button | No | No | D |
| `growthActivateCampaignButton` | Copilot/AI | button | No | No | D |
| `growthCampaignAudienceField` | Copilot/AI | field | Yes | Yes | A |
| `growthCampaignBudgetField` | Copilot/AI | field | Yes | Yes | A |
| `growthCampaignChannelField` | Copilot/AI | field | Yes | Yes | A |
| `growthCampaignCreateSubmitButton` | Copilot/AI | button | No | Yes | A |
| `growthCampaignNameField` | Copilot/AI | field | Yes | Yes | A |
| `growthCampaignRow` | Copilot/AI | widget | No | No | D |
| `growthCampaignScheduleButton` | Copilot/AI | button | Yes | No | B |
| `growthCreateCampaignButton` | Copilot/AI | button | Yes | Yes | A |
| `growthPauseCampaignButton` | Copilot/AI | button | No | No | D |
| `multiSchoolOnboardingContactEmailField` | Copilot/AI | field | Yes | Yes | A |
| `platformOperationsAiTab` | Copilot/AI | navigation | No | No | D |
| `universalAiAssistantLoadingIndicator` | Copilot/AI | widget | No | No | D |
| `universalAiAssistantStreamingToggle` | Copilot/AI | widget | No | Yes | A |
| `directorComplianceAcknowledgeButton` | Director | button | No | No | D |
| `directorComplianceAcknowledgedSnackbar` | Director | feedback | No | No | D |
| `directorCopilotLinkButton` | Director | button | No | No | D |
| `directorDashboardScreen` | Director | screen_anchor | No | No | D |
| `directorExecutiveSummaryCard` | Director | widget | No | Yes | A |
| `directorReportExportButton` | Director | button | No | Yes | A |
| `directorReportExportedSnackbar` | Director | feedback | No | Yes | A |
| `directorReportsGenerateSummaryButton` | Director | button | No | Yes | A |
| `platformOperationsDirectorPortalLink` | Director | widget | No | No | D |
| `dynamicWidgetCatalogItem` | Dynamic Widgets | widget | Yes | No | B |
| `dynamicWidgetDataSourceItem` | Dynamic Widgets | widget | Yes | No | B |
| `dynamicWidgetLayoutEditorScreen` | Dynamic Widgets | screen_anchor | No | Yes | A |
| `dynamicWidgetLayoutItem` | Dynamic Widgets | widget | No | Yes | A |
| `dynamicWidgetLayoutMoveDown` | Dynamic Widgets | widget | No | No | D |
| `dynamicWidgetLayoutMoveUp` | Dynamic Widgets | widget | No | No | D |
| `dynamicWidgetLayoutPackDropdown` | Dynamic Widgets | widget | No | No | D |
| `dynamicWidgetLayoutRoleDropdown` | Dynamic Widgets | widget | No | No | D |
| `dynamicWidgetLayoutVersion` | Dynamic Widgets | widget | Yes | No | B |
| `dynamicWidgetOpenLayoutEditorButton` | Dynamic Widgets | button | No | No | D |
| `dynamicWidgetOpenRuntimeButton` | Dynamic Widgets | button | No | Yes | A |
| `dynamicWidgetResetLayoutButton` | Dynamic Widgets | button | No | No | D |
| `dynamicWidgetRuntimeRefreshButton` | Dynamic Widgets | button | No | No | D |
| `dynamicWidgetRuntimeScreen` | Dynamic Widgets | screen_anchor | Yes | Yes | A |
| `dynamicWidgetRuntimeTile` | Dynamic Widgets | widget | Yes | Yes | A |
| `dynamicWidgetSaveLayoutButton` | Dynamic Widgets | button | No | No | D |
| `financeAssignFeePlanButton` | Finance | button | Yes | No | B |
| `financeCancelCollectionButton` | Finance | button | No | No | D |
| `financeCancelCollectionConfirmButton` | Finance | button | No | No | D |
| `financeCancelInvoiceButton` | Finance | button | No | No | D |
| `financeCancelInvoiceConfirmButton` | Finance | button | No | No | D |
| `financeCollectionAmountField` | Finance | field | No | No | D |
| `financeCollectionCancelledSnackbar` | Finance | feedback | No | No | D |
| `financeCollectionInvoiceField` | Finance | field | No | No | D |
| `financeCollectionReceiptRow` | Finance | widget | No | No | D |
| `financeCollectionSubmitButton` | Finance | button | No | No | D |
| `financeCollectionSuccessSnackbar` | Finance | feedback | No | No | D |
| `financeConfirmQrPaymentButton` | Finance | button | No | Yes | A |
| `financeFeeAccountCreatedSnackbar` | Finance | feedback | No | No | D |
| `financeGenerateQrButton` | Finance | button | Yes | Yes | A |
| `financeHandoffQueueRow` | Finance | widget | Yes | No | B |
| `financeInvoiceCancelledSnackbar` | Finance | feedback | No | No | D |
| `financeInvoiceIssuedSnackbar` | Finance | feedback | No | No | D |
| `financeIssueInvoiceButton` | Finance | button | No | No | D |
| `financeLastInvoiceIdField` | Finance | field | Yes | No | B |
| `financeOfflinePaymentAmountField` | Finance | field | No | Yes | A |
| `financeOfflinePaymentInvoiceField` | Finance | field | No | Yes | A |
| `financeOfflinePaymentReconcileSuccessSnackbar` | Finance | feedback | No | Yes | A |
| `financeOfflinePaymentReferenceField` | Finance | field | No | Yes | A |
| `financeOfflinePaymentStudentField` | Finance | field | No | Yes | A |
| `financeOfflinePaymentSubmitButton` | Finance | button | No | Yes | A |
| `financeOfflinePaymentSuccessSnackbar` | Finance | feedback | No | Yes | A |
| `financeQrAmountField` | Finance | field | Yes | No | B |
| `financeQrInvoiceField` | Finance | field | Yes | No | B |
| `financeQrPayButton` | Finance | button | No | No | D |
| `financeQrPaymentConfirmedSnackbar` | Finance | feedback | No | Yes | A |
| `financeQrReceiptField` | Finance | field | No | No | D |
| `financeReceiptSearchField` | Finance | field | No | No | D |
| `financeReconcileOfflinePaymentButton` | Finance | button | No | Yes | A |
| `financeRecordCollectionButton` | Finance | button | No | No | D |
| `financeRecordOfflinePaymentFab` | Finance | button | No | Yes | A |
| `financeReportExportPdfButton` | Finance | button | No | Yes | A |
| `financeReportExportSuccessSnackbar` | Finance | feedback | No | Yes | A |
| `hrActivateEmployeeButton` | HR | button | No | No | D |
| `hrApproveLeaveButton` | HR | button | No | No | D |
| `hrCreateEmployeeButton` | HR | button | Yes | No | B |
| `hrCreateEmployeeDialogSubmitButton` | HR | button | Yes | No | B |
| `hrCreateLeaveButton` | HR | button | Yes | No | B |
| `hrDeactivateEmployeeButton` | HR | button | Yes | No | B |
| `hrEditEmployeeButton` | HR | button | Yes | No | B |
| `hrEditEmployeeDialogSubmitButton` | HR | button | No | No | D |
| `hrEmployeeCreatedSnackbar` | HR | feedback | Yes | No | B |
| `hrEmployeeStatusSuccessSnackbar` | HR | feedback | Yes | No | B |
| `hrEmployeeUpdatedSnackbar` | HR | feedback | No | No | D |
| `hrLeaveApprovalSnackbar` | HR | feedback | No | No | D |
| `hrLeaveSuccessSnackbar` | HR | feedback | No | No | D |
| `hrPayrollExportPdfButton` | HR | button | Yes | No | B |
| `hrPayrollExportSuccessSnackbar` | HR | feedback | Yes | No | B |
| `hrPayrollProcessedSnackbar` | HR | feedback | Yes | No | B |
| `hrProcessPayrollButton` | HR | button | Yes | No | B |
| `hrRejectLeaveButton` | HR | button | No | No | D |
| `hostelAdmitDialogSubmitButton` | Hostel | button | No | No | D |
| `hostelAdmitStudentButton` | Hostel | button | No | No | D |
| `hostelAdmitSuccessSnackbar` | Hostel | feedback | No | No | D |
| `hostelAssignDialogSubmitButton` | Hostel | button | No | No | D |
| `hostelAssignRoomButton` | Hostel | button | No | No | D |
| `hostelAssignStudentButton` | Hostel | button | No | No | D |
| `hostelAssignSuccessSnackbar` | Hostel | feedback | No | No | D |
| `hostelCheckoutDialogSubmitButton` | Hostel | button | No | No | D |
| `hostelCheckoutStudentButton` | Hostel | button | No | No | D |
| `hostelCheckoutSuccessSnackbar` | Hostel | feedback | No | No | D |
| `hostelTransferStudentButton` | Hostel | button | No | No | D |
| `inventoryCreatePoButton` | Inventory | button | Yes | No | B |
| `inventoryDistributionCatalogItemField` | Inventory | field | Yes | Yes | A |
| `inventoryDistributionCreateFab` | Inventory | button | Yes | Yes | A |
| `inventoryDistributionCreateSubmitButton` | Inventory | button | Yes | Yes | A |
| `inventoryDistributionCreateSuccessSnackbar` | Inventory | feedback | Yes | Yes | A |
| `inventoryDistributionMarkDistributedButton` | Inventory | button | No | Yes | A |
| `inventoryDistributionQuantityField` | Inventory | field | Yes | Yes | A |
| `inventoryDistributionReplacementSuccessSnackbar` | Inventory | feedback | No | No | D |
| `inventoryDistributionReplacementsLink` | Inventory | widget | No | No | D |
| `inventoryDistributionRequestReplacementButton` | Inventory | button | No | No | D |
| `inventoryDistributionRow` | Inventory | widget | Yes | No | B |
| `inventoryDistributionScreen` | Inventory | screen_anchor | No | Yes | A |
| `inventoryDistributionStudentIdField` | Inventory | field | Yes | Yes | A |
| `inventoryLifecycleScreen` | Inventory | screen_anchor | Yes | Yes | A |
| `inventoryLifecycleSuccessSnackbar` | Inventory | feedback | Yes | Yes | A |
| `inventoryPoApproveHandoffButton` | Inventory | button | No | No | D |
| `inventoryPoApproveHandoffDialogButton` | Inventory | button | No | No | D |
| `inventoryPoApproveHandoffSuccessSnackbar` | Inventory | feedback | No | No | D |
| `inventoryPoReceiveHandoffButton` | Inventory | button | Yes | No | B |
| `inventoryPoReceiveHandoffDialogButton` | Inventory | button | Yes | No | B |
| `inventoryPoReceiveHandoffSuccessSnackbar` | Inventory | feedback | Yes | No | B |
| `inventoryPoSuccessSnackbar` | Inventory | feedback | No | No | D |
| `inventoryRecordLifecycleButton` | Inventory | button | Yes | Yes | A |
| `inventoryReplacementApproveButton` | Inventory | button | Yes | Yes | A |
| `inventoryReplacementApproveSuccessSnackbar` | Inventory | feedback | Yes | Yes | A |
| `inventoryReplacementFulfillButton` | Inventory | button | No | No | D |
| `inventoryReplacementFulfillSuccessSnackbar` | Inventory | feedback | No | No | D |
| `inventoryReplacementRejectButton` | Inventory | button | No | No | D |
| `inventoryReplacementRejectSuccessSnackbar` | Inventory | feedback | No | No | D |
| `inventoryReplacementRow` | Inventory | widget | Yes | No | B |
| `inventoryReplacementScreen` | Inventory | screen_anchor | No | Yes | A |
| `inventoryReportExportPdfButton` | Inventory | button | Yes | No | B |
| `inventoryReportExportSuccessSnackbar` | Inventory | feedback | Yes | No | B |
| `libraryIssueDialogSubmitButton` | Library | button | No | No | D |
| `libraryIssueScanButton` | Library | button | No | No | D |
| `libraryIssueSuccessSnackbar` | Library | feedback | No | No | D |
| `libraryReturnBookButton` | Library | button | No | No | D |
| `libraryReturnDialogSubmitButton` | Library | button | No | No | D |
| `libraryReturnScanButton` | Library | button | No | No | D |
| `libraryReturnSuccessSnackbar` | Library | feedback | No | No | D |
| `managementApprovalSuccessSnackbar` | Management | feedback | No | No | D |
| `managementApproveButton` | Management | button | No | No | D |
| `managementDashboardExportButton` | Management | button | Yes | Yes | A |
| `managementDashboardExportSnackbar` | Management | feedback | No | No | D |
| `managementDashboardExportSuccessSnackbar` | Management | feedback | No | Yes | A |
| `managementDashboardPrintButton` | Management | button | No | No | D |
| `managementDashboardShareButton` | Management | button | No | No | D |
| `managementKpiDrillButton` | Management | button | No | Yes | A |
| `managementRejectButton` | Management | button | No | No | D |
| `managementSettingsAcademicYearEditButton` | Management | button | No | No | D |
| `managementSettingsDialogField` | Management | field | Yes | No | B |
| `managementSettingsDialogSaveButton` | Management | button | Yes | No | B |
| `managementSettingsItemEditButton` | Management | button | Yes | No | B |
| `managementSettingsSaveButton` | Management | button | Yes | No | B |
| `principalQuickAction` | Management | widget | No | No | D |
| `growthInquiryParentField` | Parent | field | No | No | D |
| `parentAttendanceKpiPercent` | Parent | widget | No | No | D |
| `parentMeetingActionToggle` | Parent | widget | No | No | D |
| `parentMeetingTile` | Parent | widget | No | Yes | A |
| `parentMeetingsCreateButton` | Parent | button | No | No | D |
| `parentMeetingsCreateSubmitButton` | Parent | button | No | No | D |
| `parentMeetingsGenerateSummaryButton` | Parent | button | No | No | D |
| `parentMeetingsNotesField` | Parent | field | No | No | D |
| `parentMeetingsParentNameField` | Parent | field | No | No | D |
| `parentMeetingsSaveNotesButton` | Parent | button | No | No | D |
| `parentMeetingsScheduleFollowUpButton` | Parent | button | No | No | D |
| `parentMeetingsScreen` | Parent | screen_anchor | No | Yes | A |
| `parentMeetingsStudentIdField` | Parent | field | No | No | D |
| `parentMeetingsStudentNameField` | Parent | field | No | No | D |
| `parentMeetingsTeacherNameField` | Parent | field | No | No | D |
| `parentReceiptDownloadButton` | Parent | button | Yes | Yes | A |
| `parentReceiptPdfSuccessSnackbar` | Parent | feedback | No | Yes | A |
| `parentReceiptShareButton` | Parent | button | No | No | D |
| `dynamicWidgetRegistryScreen` | SIS | screen_anchor | Yes | Yes | A |
| `sisContinuityExecuteButton` | SIS | button | No | No | D |
| `sisContinuityExecutionSummary` | SIS | widget | No | No | D |
| `sisContinuityPlanSummary` | SIS | widget | No | No | D |
| `sisContinuityPreviewButton` | SIS | button | No | No | D |
| `sisConversionSuccessSnackbar` | SIS | feedback | No | No | D |
| `sisDocumentUploadSuccessSnackbar` | SIS | feedback | No | Yes | A |
| `sisEditProfileButton` | SIS | button | Yes | Yes | A |
| `sisEditProfileSaveButton` | SIS | button | No | Yes | A |
| `sisPerformanceExecuteButton` | SIS | button | No | No | D |
| `sisPerformancePreviewRow` | SIS | widget | No | No | D |
| `sisPromotionContinueButton` | SIS | button | No | No | D |
| `sisPromotionExecutionSummary` | SIS | widget | No | No | D |
| `sisPromotionPreviewRow` | SIS | widget | No | No | D |
| `sisPromotionSourceYearField` | SIS | field | No | No | D |
| `sisPromotionTargetYearField` | SIS | field | No | No | D |
| `sisQuarterlyExecuteButton` | SIS | button | No | No | D |
| `sisQuarterlyPreviewRow` | SIS | widget | No | No | D |
| `sisRegistrySearchField` | SIS | field | No | Yes | A |
| `sisRegistryStudentRow` | SIS | widget | Yes | Yes | A |
| `sisReshuffleExecuteButton` | SIS | button | No | No | D |
| `sisReshuffleExecutionSummary` | SIS | widget | No | No | D |
| `sisReshufflePreviewRow` | SIS | widget | No | No | D |
| `sisSectionBalanceExecuteButton` | SIS | button | No | No | D |
| `sisSectionBalancePreviewRow` | SIS | widget | No | No | D |
| `sisUploadDocumentButton` | SIS | button | Yes | Yes | A |
| `sisUploadDocumentSubmitButton` | SIS | button | No | Yes | A |
| `accommodationAccommodationAllocationScreen` | Shared | screen_anchor | No | No | D |
| `accommodationAccommodationAllocationTile` | Shared | widget | No | No | D |
| `accommodationDashboardScreen` | Shared | screen_anchor | Yes | Yes | A |
| `accommodationDashboardSummary` | Shared | widget | No | No | D |
| `accommodationIntelligenceScreen` | Shared | screen_anchor | No | No | D |
| `accommodationKpiTile` | Shared | widget | No | No | D |
| `accommodationNavLink` | Shared | navigation | No | No | D |
| `accommodationResidentScreen` | Shared | screen_anchor | No | No | D |
| `accommodationResidentTile` | Shared | widget | No | No | D |
| `accommodationRoomOccupancyScreen` | Shared | screen_anchor | No | No | D |
| `accommodationRoomOccupancyTile` | Shared | widget | No | No | D |
| `branchAssignSchoolButton` | Shared | button | Yes | Yes | A |
| `branchAssignmentSnackbar` | Shared | feedback | Yes | Yes | A |
| `branchAssignmentTile` | Shared | widget | No | No | D |
| `branchScreen` | Shared | screen_anchor | No | Yes | A |
| `branchTile` | Shared | widget | No | No | D |
| `communicationBroadcastAdminScreen` | Shared | screen_anchor | No | Yes | A |
| `communicationBroadcastHistoryList` | Shared | widget | No | No | D |
| `communicationBroadcastSendButton` | Shared | button | No | Yes | A |
| `communicationTemplateSaveButton` | Shared | button | No | No | D |
| `educationPublishRemarkButton` | Shared | button | Yes | Yes | A |
| `educationRemarkPublishedSnackbar` | Shared | feedback | Yes | Yes | A |
| `educationReportCardExportButton` | Shared | button | Yes | No | B |
| `educationReportCardExportSuccessSnackbar` | Shared | feedback | Yes | No | B |
| `educationReportRemarksTab` | Shared | navigation | Yes | Yes | A |
| `franchiseImproveButton` | Shared | button | Yes | Yes | A |
| `franchiseScreen` | Shared | screen_anchor | No | Yes | A |
| `franchiseTile` | Shared | widget | No | No | D |
| `franchiseUpdatedSnackbar` | Shared | feedback | Yes | Yes | A |
| `growthConvertInquiryButton` | Shared | button | Yes | Yes | A |
| `growthCreateInquiryButton` | Shared | button | No | No | D |
| `growthInquiryCreateSubmitButton` | Shared | button | No | No | D |
| `growthInquiryGradeField` | Shared | field | No | No | D |
| `growthInquiryRow` | Shared | widget | No | No | D |
| `growthInquirySourceField` | Shared | field | No | No | D |
| `healthcareAppointmentScreen` | Shared | screen_anchor | No | Yes | A |
| `healthcareAppointmentTile` | Shared | widget | No | No | D |
| `healthcareDashboardScreen` | Shared | screen_anchor | Yes | Yes | A |
| `healthcareDashboardSummary` | Shared | widget | No | No | D |
| `healthcareIntelligenceScreen` | Shared | screen_anchor | No | No | D |
| `healthcareKpiTile` | Shared | widget | No | No | D |
| `healthcareNavLink` | Shared | navigation | No | No | D |
| `healthcarePatientScreen` | Shared | screen_anchor | No | Yes | A |
| `healthcarePatientTile` | Shared | widget | No | No | D |
| `healthcarePractitionerScreen` | Shared | screen_anchor | No | No | D |
| `healthcarePractitionerTile` | Shared | widget | No | No | D |
| `industryActiveLabel` | Shared | widget | No | No | D |
| `industryCapabilityTile` | Shared | widget | No | Yes | A |
| `industryFrameworkLink` | Shared | widget | No | Yes | A |
| `industryHubScreen` | Shared | screen_anchor | Yes | Yes | A |
| `industryModuleToggle` | Shared | widget | No | No | D |
| `industryTypeChip` | Shared | widget | No | Yes | A |
| `logoutButton` | Shared | button | Yes | No | B |
| `logoutConfirmButton` | Shared | button | No | No | D |
| `moduleSubNavTab` | Shared | navigation | No | No | D |
| `multiSchoolActivateSchoolButton` | Shared | button | No | No | D |
| `multiSchoolActivationSnackbar` | Shared | feedback | No | No | D |
| `multiSchoolAlertCard` | Shared | widget | No | No | D |
| `multiSchoolAlertDismissedSnackbar` | Shared | feedback | Yes | Yes | A |
| `multiSchoolDeactivateSchoolButton` | Shared | button | No | No | D |
| `multiSchoolDeactivationSnackbar` | Shared | feedback | No | No | D |
| `multiSchoolDismissAlertButton` | Shared | button | Yes | Yes | A |
| `multiSchoolHealthChip` | Shared | widget | No | No | D |
| `multiSchoolOnboardingActivateSwitch` | Shared | widget | No | No | D |
| `multiSchoolOnboardingCapacityField` | Shared | field | No | No | D |
| `multiSchoolOnboardingCompletedSnackbar` | Shared | feedback | Yes | Yes | A |
| `multiSchoolOnboardingContactNameField` | Shared | field | Yes | Yes | A |
| `multiSchoolOnboardingContinueButton` | Shared | button | Yes | No | B |
| `multiSchoolOnboardingCountryField` | Shared | field | No | No | D |
| `multiSchoolOnboardingCta` | Shared | widget | No | Yes | A |
| `multiSchoolOnboardingPlanField` | Shared | field | No | No | D |
| `multiSchoolOnboardingSchoolNameField` | Shared | field | Yes | Yes | A |
| `multiSchoolOnboardingSubmitButton` | Shared | button | Yes | Yes | A |
| `multiSchoolOnboardingWizardScreen` | Shared | screen_anchor | No | Yes | A |
| `multiSchoolPortfolioScreen` | Shared | screen_anchor | No | Yes | A |
| `multiSchoolSchoolRow` | Shared | widget | No | No | D |
| `operationsHubActionCompletedSnackbar` | Shared | feedback | No | Yes | A |
| `operationsHubActionTile` | Shared | widget | No | No | D |
| `operationsHubAlertDismissedSnackbar` | Shared | feedback | No | Yes | A |
| `operationsHubAlertTile` | Shared | widget | No | No | D |
| `operationsHubCompleteActionButton` | Shared | button | No | Yes | A |
| `operationsHubDismissAlertButton` | Shared | button | No | Yes | A |
| `otpField` | Shared | field | Yes | No | B |
| `otpVerifyButton` | Shared | button | No | No | D |
| `profileButton` | Shared | button | No | Yes | A |
| `qaPersonaButton` | Shared | button | Yes | No | B |
| `receiptHistoryButton` | Shared | button | No | Yes | A |
| `resourceOptimizationAppliedSnackbar` | Shared | feedback | Yes | No | B |
| `resourceOptimizationApplyButton` | Shared | button | Yes | Yes | A |
| `resourceOptimizationDismissButton` | Shared | button | No | Yes | A |
| `resourceOptimizationDismissedSnackbar` | Shared | feedback | No | No | D |
| `resourceOptimizationTab` | Shared | navigation | No | No | D |
| `restaurantDashboardScreen` | Shared | screen_anchor | Yes | Yes | A |
| `restaurantDashboardSummary` | Shared | widget | No | No | D |
| `restaurantIntelligenceScreen` | Shared | screen_anchor | No | No | D |
| `restaurantKitchenTicketScreen` | Shared | screen_anchor | No | No | D |
| `restaurantKitchenTicketTile` | Shared | widget | No | No | D |
| `restaurantKpiTile` | Shared | widget | No | No | D |
| `restaurantNavLink` | Shared | navigation | No | No | D |
| `restaurantRestaurantOrderScreen` | Shared | screen_anchor | No | No | D |
| `restaurantRestaurantOrderTile` | Shared | widget | No | No | D |
| `restaurantRestaurantTableScreen` | Shared | screen_anchor | No | No | D |
| `restaurantRestaurantTableTile` | Shared | navigation | No | No | D |
| `salonDashboardScreen` | Shared | screen_anchor | Yes | Yes | A |
| `salonDashboardSummary` | Shared | widget | No | No | D |
| `salonIntelligenceScreen` | Shared | screen_anchor | No | No | D |
| `salonKpiTile` | Shared | widget | No | No | D |
| `salonNavLink` | Shared | navigation | No | No | D |
| `salonSalonAppointmentScreen` | Shared | screen_anchor | No | No | D |
| `salonSalonAppointmentTile` | Shared | widget | No | No | D |
| `salonSalonCustomerScreen` | Shared | screen_anchor | No | No | D |
| `salonSalonCustomerTile` | Shared | widget | No | No | D |
| `salonSalonServiceScreen` | Shared | screen_anchor | No | No | D |
| `salonSalonServiceTile` | Shared | widget | No | No | D |
| `schoolMemoriesCreateCategoryField` | Shared | field | No | No | D |
| `schoolMemoriesCreateDescriptionField` | Shared | field | Yes | Yes | A |
| `schoolMemoriesCreateFab` | Shared | button | Yes | Yes | A |
| `schoolMemoriesCreateSubmitButton` | Shared | button | Yes | Yes | A |
| `schoolMemoriesCreateTitleField` | Shared | field | Yes | Yes | A |
| `schoolMemoriesCreatedSnackbar` | Shared | feedback | No | Yes | A |
| `schoolMemoriesEventTile` | Shared | widget | No | No | D |
| `schoolMemoriesPublishButton` | Shared | button | No | Yes | A |
| `schoolMemoriesPublishedSnackbar` | Shared | feedback | No | Yes | A |
| `schoolMemoriesScreen` | Shared | screen_anchor | Yes | Yes | A |
| `schoolMemoriesStatusTabs` | Shared | navigation | No | No | D |
| `splash` | Shared | widget | No | No | D |
| `substituteAssignButton` | Shared | button | No | Yes | A |
| `substituteAssignSuccessSnackbar` | Shared | feedback | No | No | D |
| `substituteClassFilter` | Shared | widget | No | No | D |
| `substituteDayFilter` | Shared | widget | No | No | D |
| `timetableOptimizationApplyAllButton` | Shared | button | No | Yes | A |
| `timetableOptimizationApplyButton` | Shared | button | Yes | No | B |
| `timetableOptimizationApplySuccessSnackbar` | Shared | feedback | Yes | Yes | A |
| `whiteLabelActiveConfig` | Shared | widget | No | No | D |
| `whiteLabelApplyThemeButton` | Shared | button | No | No | D |
| `whiteLabelBrandingLink` | Shared | widget | No | Yes | A |
| `whiteLabelBrandingScreen` | Shared | screen_anchor | No | Yes | A |
| `whiteLabelBrandingTile` | Shared | widget | No | No | D |
| `whiteLabelDeploymentLink` | Shared | widget | No | No | D |
| `whiteLabelDeploymentScreen` | Shared | screen_anchor | No | No | D |
| `whiteLabelDeploymentTile` | Shared | widget | No | No | D |
| `whiteLabelHubScreen` | Shared | screen_anchor | Yes | Yes | A |
| `whiteLabelLogoLink` | Shared | widget | No | No | D |
| `whiteLabelLogoScreen` | Shared | screen_anchor | No | No | D |
| `whiteLabelLogoTile` | Shared | widget | No | No | D |
| `whiteLabelSaveBrandingButton` | Shared | button | No | No | D |
| `whiteLabelThemeLink` | Shared | widget | No | No | D |
| `whiteLabelThemeScreen` | Shared | screen_anchor | No | No | D |
| `whiteLabelThemeTile` | Shared | widget | No | No | D |
| `whiteLabelUploadLogoButton` | Shared | button | No | No | D |
| `workflowAutomationScreen` | Shared | screen_anchor | No | No | D |
| `workflowRunScheduledNowButton` | Shared | button | No | No | D |
| `atRiskStudentRow` | Student | widget | No | No | D |
| `teacherAttendanceSubmitButton` | Teacher | button | No | No | D |
| `teacherAttendanceSubmittedBanner` | Teacher | feedback | Yes | No | B |
| `teacherReassignmentSourceFilter` | Teacher | widget | Yes | No | B |
| `teacherReassignmentSubmitButton` | Teacher | button | No | Yes | A |
| `teacherReassignmentSuccessSnackbar` | Teacher | feedback | No | Yes | A |
| `transportActivateRouteButton` | Transport | button | Yes | No | B |
| `transportActivateRouteDialogButton` | Transport | button | No | No | D |
| `transportAssignDialogSubmitButton` | Transport | button | No | No | D |
| `transportAssignStudentButton` | Transport | button | Yes | No | B |
| `transportAssignSuccessSnackbar` | Transport | feedback | Yes | No | B |
| `transportRemoveDialogSubmitButton` | Transport | button | No | No | D |
| `transportRemoveStudentButton` | Transport | button | No | No | D |
| `transportRemoveSuccessSnackbar` | Transport | feedback | Yes | No | B |
| `transportReportExportPdfButton` | Transport | button | Yes | No | B |
| `transportReportExportSuccessSnackbar` | Transport | feedback | Yes | No | B |
| `transportRouteActivatedSnackbar` | Transport | feedback | Yes | No | B |
| `transportRouteSuccessSnackbar` | Transport | feedback | No | No | D |
| `transportSaveRouteButton` | Transport | button | Yes | No | B |
| `transportSaveRouteDialogButton` | Transport | button | No | No | D |
| `transportTransferDialogSubmitButton` | Transport | button | No | No | D |
| `transportTransferStudentButton` | Transport | button | Yes | No | B |
| `transportTransferSuccessSnackbar` | Transport | feedback | No | No | D |
| `organizationBuilderDraftRow` | Trust Intelligence | widget | No | No | D |
| `organizationBuilderHubScreen` | Trust Intelligence | screen_anchor | Yes | Yes | A |
| `organizationBuilderInterviewBackButton` | Trust Intelligence | button | No | No | D |
| `organizationBuilderInterviewChannelsField` | Trust Intelligence | field | No | No | D |
| `organizationBuilderInterviewContinueButton` | Trust Intelligence | button | Yes | Yes | A |
| `organizationBuilderInterviewModulesField` | Trust Intelligence | field | No | No | D |
| `organizationBuilderInterviewNameField` | Trust Intelligence | field | Yes | Yes | A |
| `organizationBuilderInterviewPaymentsField` | Trust Intelligence | field | No | No | D |
| `organizationBuilderInterviewPreviewButton` | Trust Intelligence | button | No | Yes | A |
| `organizationBuilderInterviewScalePrimaryField` | Trust Intelligence | field | No | Yes | A |
| `organizationBuilderInterviewScaleSecondaryField` | Trust Intelligence | field | No | Yes | A |
| `organizationBuilderInterviewScreen` | Trust Intelligence | screen_anchor | Yes | Yes | A |
| `organizationBuilderInterviewWorkflowsField` | Trust Intelligence | field | No | No | D |
| `organizationBuilderPackCard` | Trust Intelligence | widget | No | No | D |
| `organizationBuilderPreviewModule` | Trust Intelligence | widget | No | No | D |
| `organizationBuilderPreviewRole` | Trust Intelligence | widget | No | No | D |
| `organizationBuilderPreviewScreen` | Trust Intelligence | screen_anchor | No | Yes | A |
| `organizationBuilderPreviewWidget` | Trust Intelligence | widget | No | No | D |
| `organizationBuilderPreviewWorkflow` | Trust Intelligence | widget | No | No | D |
| `organizationBuilderProvisioningCompleted` | Trust Intelligence | widget | No | No | D |
| `organizationBuilderProvisioningScreen` | Trust Intelligence | screen_anchor | No | No | D |
| `organizationBuilderProvisioningStep` | Trust Intelligence | widget | No | No | D |
| `organizationBuilderRecommendation` | Trust Intelligence | widget | No | No | D |
| `organizationBuilderSchoolSetupLink` | Trust Intelligence | widget | Yes | No | B |
| `organizationBuilderStartInterviewButton` | Trust Intelligence | button | No | Yes | A |
| `organizationBuilderStartProvisioningButton` | Trust Intelligence | button | No | No | D |
| `trustIntelligenceScreen` | Trust Intelligence | screen_anchor | No | Yes | A |

---

## 2. Route inventory

Source: `lib/router/route_names.dart` + Patrol cross-reference

| Route | Module | Patrol suite | Widget/route test | Status |
|-------|--------|--------------|-------------------|--------|
| `/` | Other | — | No | D |
| `/accommodation` | Accommodation | accommodation_vertical_e2e_test.dart | Yes | A |
| `/accommodation` | Accommodation | — | No | D |
| `/accommodation/allocations` | Accommodation | — | No | D |
| `/accommodation/intelligence` | Intelligence | — | No | D |
| `/accommodation/occupancy` | Accommodation | — | No | D |
| `/accommodation/residents` | Accommodation | — | No | D |
| `/admin` | Admin | — | Yes | B |
| `/admissions` | Admissions | — | Yes | B |
| `/admissions/applications` | Admissions | — | Yes | B |
| `/admissions/approval` | Admissions | — | Yes | B |
| `/admissions/dashboard` | Admissions | — | Yes | B |
| `/admissions/documents` | Admissions | — | Yes | B |
| `/admissions/enrollment` | Admissions | — | Yes | B |
| `/admissions/fee-handoff` | Admissions | — | Yes | B |
| `/admissions/leads` | Admissions | — | Yes | B |
| `/admissions/reports` | Admissions | — | Yes | B |
| `/admissions/settings` | Admissions | — | Yes | B |
| `/ai-assistant` | Copilot/AI | universal_ai_assistant_e2e_test.dart | Yes | A |
| `/ai-content` | Copilot/AI | ai_content_generation_e2e_test.dart | Yes | A |
| `/alumni` | Alumni | — | No | D |
| `/alumni/campaigns` | Alumni | — | Yes | B |
| `/alumni/dashboard` | Alumni | — | Yes | B |
| `/alumni/donations` | Alumni | — | Yes | B |
| `/alumni/events` | Alumni | — | Yes | B |
| `/alumni/mentorship` | Alumni | — | Yes | B |
| `/alumni/profile` | Alumni | — | No | D |
| `/alumni/registry` | Alumni | — | Yes | B |
| `/alumni/reports` | Alumni | — | Yes | B |
| `/alumni/settings` | Alumni | — | Yes | B |
| `/branches` | Multi-School | branch_operations_e2e_test.dart | Yes | A |
| `/control-center` | Control Center | — | No | D |
| `/control-center/analytics` | Control Center | — | Yes | B |
| `/control-center/billing` | Control Center | — | Yes | B |
| `/control-center/crm` | Control Center | — | Yes | B |
| `/control-center/dashboard` | Control Center | — | Yes | B |
| `/control-center/features` | Control Center | — | No | D |
| `/control-center/monitoring` | Control Center | — | Yes | B |
| `/control-center/providers` | Control Center | — | No | D |
| `/control-center/roles` | Control Center | — | Yes | B |
| `/control-center/schools` | Control Center | — | Yes | B |
| `/control-center/settings` | Control Center | — | Yes | B |
| `/control-center/success` | Control Center | — | Yes | B |
| `/control-center/support` | Control Center | — | Yes | B |
| `/control-center/white-label` | Control Center | — | Yes | B |
| `/copilot` | Copilot | — | Yes | B |
| `/dashboard/dynamic` | Dynamic Widgets | — | No | D |
| `/director` | Director | — | No | D |
| `/director/admissions` | Admissions | — | No | D |
| `/director/compliance` | Director | director_portal_navigation_e2e_test.dart | No | A |
| `/director/dashboard` | Director | — | Yes | B |
| `/director/growth` | Director | — | No | D |
| `/director/marketing` | Director | — | No | D |
| `/director/portfolio` | Director | — | No | D |
| `/director/reports` | Director | director_portal_e2e_test.dart | Yes | A |
| `/director/revenue` | Director | director_portal_navigation_e2e_test.dart | No | A |
| `/director/schools` | Director | director_portal_navigation_e2e_test.dart | No | A |
| `/dynamic-widgets` | Dynamic Widgets | dynamic_widget_platform_e2e_test.dart | Yes | A |
| `/dynamic-widgets/layout` | Dynamic Widgets | dynamic_widget_platform_e2e_test.dart | No | A |
| `/dynamic-widgets/runtime` | Dynamic Widgets | — | No | D |
| `/education` | Other | education_remark_e2e_test.dart | Yes | A |
| `/employees` | HR | — | No | D |
| `/employees/360` | HR | — | No | D |
| `/finance` | Finance | — | Yes | B |
| `/finance/collections` | Finance | — | Yes | B |
| `/finance/dashboard` | Finance | — | Yes | B |
| `/finance/defaulters` | Finance | — | Yes | B |
| `/finance/discounts` | Finance | — | Yes | B |
| `/finance/executive` | Finance | — | No | D |
| `/finance/fee-assignment` | Finance | finance_invoice_e2e_test.dart | Yes | A |
| `/finance/fee-structures` | Finance | — | Yes | B |
| `/finance/intelligence` | Finance | — | No | D |
| `/finance/payments/offline` | Finance | — | No | D |
| `/finance/payments/qr` | Finance | finance_qr_payment_e2e_test.dart | No | A |
| `/finance/reconciliation` | Finance | — | Yes | B |
| `/finance/refunds` | Finance | — | Yes | B |
| `/finance/reports` | Finance | finance_exports_e2e_test.dart | Yes | A |
| `/finance/settings` | Finance | — | Yes | B |
| `/finance/student-accounts` | Finance | — | Yes | B |
| `/franchise` | Multi-School | franchise_portfolio_e2e_test.dart | Yes | A |
| `/growth` | Evolution | growth_campaign_e2e_test.dart | No | A |
| `/healthcare` | Healthcare | healthcare_vertical_e2e_test.dart | Yes | A |
| `/healthcare` | Healthcare | — | No | D |
| `/healthcare/appointments` | Healthcare | healthcare_navigation_e2e_test.dart | No | A |
| `/healthcare/intelligence` | Intelligence | — | No | D |
| `/healthcare/patients` | Healthcare | healthcare_navigation_e2e_test.dart | No | A |
| `/healthcare/practitioners` | Healthcare | — | No | D |
| `/homework-intelligence` | Other | — | No | D |
| `/hostel` | Hostel | — | No | D |
| `/hostel/attendance` | Hostel | — | Yes | B |
| `/hostel/dashboard` | Hostel | — | Yes | B |
| `/hostel/leave` | Hostel | — | Yes | B |
| `/hostel/mess` | Hostel | — | Yes | B |
| `/hostel/reports` | Hostel | — | Yes | B |
| `/hostel/rooms` | Hostel | — | Yes | B |
| `/hostel/students` | Hostel | hostel_allocation_e2e_test.dart | Yes | A |
| `/hostel/visitors` | Hostel | — | Yes | B |
| `/hr` | HR | — | Yes | B |
| `/hr/attendance` | HR | — | Yes | B |
| `/hr/dashboard` | HR | — | Yes | B |
| `/hr/employees` | HR | hr_employee_crud_e2e_test.dart | Yes | A |
| `/hr/leave` | HR | hr_leave_approval_e2e_test.dart, hr_leave_e2e_test.dart | Yes | A |
| `/hr/payroll` | HR | hr_payroll_e2e_test.dart | Yes | A |
| `/hr/performance` | HR | — | Yes | B |
| `/hr/recruitment` | HR | — | Yes | B |
| `/hr/settings` | HR | — | Yes | B |
| `/industry` | Industry | industry_framework_e2e_test.dart, industry_pack_navigation_e2e_test.dart | Yes | A |
| `/industry/framework` | Industry | — | Yes | B |
| `/intelligence` | Intelligence | — | No | D |
| `/intelligence/exam` | Intelligence | — | Yes | B |
| `/inventory` | Inventory | — | No | D |
| `/inventory/allocation` | Inventory | — | Yes | B |
| `/inventory/assets` | Inventory | — | Yes | B |
| `/inventory/categories` | Inventory | — | Yes | B |
| `/inventory/copilot` | Inventory | — | Yes | B |
| `/inventory/dashboard` | Inventory | — | Yes | B |
| `/inventory/distribution` | Inventory | book_distribution_e2e_test.dart | No | A |
| `/inventory/lifecycle` | Inventory | inventory_lifecycle_e2e_test.dart, inventory_workflows_test.dart | Yes | A |
| `/inventory/maintenance` | Inventory | — | Yes | B |
| `/inventory/procurement` | Inventory | inventory_po_e2e_test.dart | Yes | A |
| `/inventory/replacements` | Inventory | inventory_replacement_e2e_test.dart | No | A |
| `/inventory/reports` | Inventory | — | Yes | B |
| `/inventory/vendors` | Inventory | — | Yes | B |
| `/library` | Library | — | No | D |
| `/library/catalog` | Library | — | Yes | B |
| `/library/dashboard` | Library | — | Yes | B |
| `/library/fines` | Library | — | Yes | B |
| `/library/issues` | Library | library_issue_return_e2e_test.dart | Yes | A |
| `/library/members` | Library | — | Yes | B |
| `/library/reports` | Library | — | Yes | B |
| `/library/resources` | Library | — | Yes | B |
| `/library/returns` | Library | — | Yes | B |
| `/login` | Auth | — | Yes | B |
| `/management` | Management | — | No | D |
| `/management/academics` | Management | management_kpi_drill_e2e_test.dart | Yes | A |
| `/management/admissions` | Admissions | — | Yes | B |
| `/management/analytics` | Management | management_insight_routes_e2e_test.dart, management_kpi_drill_e2e_test.dart | Yes | A |
| `/management/dashboard` | Management | copilot_context_e2e_test.dart, copilot_dock_e2e_test.dart | Yes | A |
| `/management/finance` | Finance | — | Yes | B |
| `/management/intelligence` | Management | — | Yes | B |
| `/management/performance` | Management | — | Yes | B |
| `/management/settings` | Management | — | Yes | B |
| `/management/tasks` | Management | — | Yes | B |
| `/management/timetable` | Management | — | Yes | B |
| `/memories` | Memories | school_memories_admin_e2e_test.dart | No | A |
| `/multi-school/onboarding` | Multi-School | — | Yes | B |
| `/multi-school/portfolio` | Multi-School | multi_school_operations_e2e_test.dart | Yes | A |
| `/operations/hub` | Operations | operations_hub_e2e_test.dart | Yes | A |
| `/organization-builder` | Trust Intelligence | organization_builder_e2e_test.dart | Yes | A |
| `/organization/intelligence` | Intelligence | trust_intelligence_e2e_test.dart | Yes | A |
| `/otp` | Other | — | Yes | B |
| `/parent` | Parent | — | No | D |
| `/parent-meetings` | Parent | parent_meeting_summary_e2e_test.dart | No | A |
| `/parent/academic-report` | Parent | — | No | D |
| `/parent/attendance` | Parent | — | No | D |
| `/parent/dashboard` | Parent | — | Yes | B |
| `/parent/events` | Parent | — | Yes | B |
| `/parent/exams` | Parent | — | Yes | B |
| `/parent/experience` | Parent | — | No | D |
| `/parent/fees` | Parent | — | No | D |
| `/parent/homework` | Parent | — | Yes | B |
| `/parent/insights` | Parent | — | No | D |
| `/parent/leave` | Parent | — | Yes | B |
| `/parent/messages` | Parent | — | No | D |
| `/parent/notices` | Parent | — | Yes | B |
| `/parent/notifications` | Parent | — | No | D |
| `/parent/payment` | Parent | — | Yes | B |
| `/parent/profile` | Parent | ai_access_settings_e2e_test.dart | Yes | A |
| `/parent/receipts` | Parent | — | Yes | B |
| `/parent/timetable` | Parent | — | Yes | B |
| `/platform-operations` | Platform Operations | platform_operations_e2e_test.dart | Yes | A |
| `/platform-operations/alerts` | Platform Operations | — | Yes | B |
| `/principal-command` | Evolution | — | No | D |
| `/promotions` | Other | — | Yes | B |
| `/qa-login` | Auth | — | Yes | B |
| `/resource-optimization` | Operations | resource_optimization_e2e_test.dart | Yes | A |
| `/restaurant` | Restaurant | restaurant_vertical_e2e_test.dart | Yes | A |
| `/restaurant` | Restaurant | — | No | D |
| `/restaurant/intelligence` | Intelligence | — | No | D |
| `/restaurant/kitchen` | Restaurant | — | No | D |
| `/restaurant/orders` | Restaurant | — | No | D |
| `/restaurant/tables` | Restaurant | — | No | D |
| `/salon` | Salon | salon_vertical_e2e_test.dart | Yes | A |
| `/salon` | Salon | — | No | D |
| `/salon/appointments` | Salon | — | No | D |
| `/salon/customers` | Salon | — | No | D |
| `/salon/intelligence` | Intelligence | — | No | D |
| `/salon/services` | Salon | — | No | D |
| `/school/academic/progress` | School Completion | — | No | D |
| `/school/branding` | School Completion | — | No | D |
| `/school/communications/delivery` | School Completion | — | No | D |
| `/school/completion` | School Completion | — | No | D |
| `/school/lesson-analytics` | School Completion | — | No | D |
| `/school/lesson-logs` | School Completion | — | No | D |
| `/school/parent-activation` | Parent | — | No | D |
| `/school/pilot` | School Completion | — | No | D |
| `/school/rooms-allocation` | School Completion | — | No | D |
| `/school/subject-assignments` | School Completion | — | No | D |
| `/school/subjects` | School Completion | — | No | D |
| `/school/syllabus/automation` | School Completion | — | No | D |
| `/school/timetables/automate` | School Completion | — | No | D |
| `/school/timetables/intelligence` | Intelligence | — | No | D |
| `/school/timetables/optimize` | School Completion | timetable_optimization_apply_e2e_test.dart | No | A |
| `/school/timetables/reassign` | School Completion | teacher_reassignment_e2e_test.dart | No | A |
| `/school/timetables/substitute` | School Completion | substitute_teacher_e2e_test.dart | No | A |
| `/school/whatsapp-provider` | School Completion | — | No | D |
| `/settings/ai-assistant` | Copilot/AI | — | No | D |
| `/setup-wizard` | Other | — | No | D |
| `/sis` | SIS | — | Yes | B |
| `/sis/academic-assignment` | SIS | — | Yes | B |
| `/sis/admissions-conversion` | Admissions | — | Yes | B |
| `/sis/continuity` | SIS | — | No | D |
| `/sis/dashboard` | SIS | — | Yes | B |
| `/sis/onboarding` | SIS | — | No | D |
| `/sis/promotion` | SIS | — | No | D |
| `/sis/reshuffle` | SIS | — | No | D |
| `/sis/section-balance` | SIS | — | No | D |
| `/sis/students` | SIS | — | Yes | B |
| `/splash` | Auth | — | No | D |
| `/staff/login` | Auth | — | No | D |
| `/staff/otp` | Other | — | No | D |
| `/student` | Student | — | No | D |
| `/student-360` | Student | — | No | D |
| `/student/attendance` | Student | — | Yes | B |
| `/student/dashboard` | Student | — | Yes | B |
| `/student/exams` | Student | — | Yes | B |
| `/student/homework` | Student | — | Yes | B |
| `/student/notices` | Student | — | Yes | B |
| `/student/profile` | Student | — | Yes | B |
| `/student/timetable` | Student | — | Yes | B |
| `/teacher` | Teacher | — | No | D |
| `/teacher-assistant` | Teacher | — | No | D |
| `/teacher/attendance` | Teacher | — | Yes | B |
| `/teacher/dashboard` | Teacher | copilot_dock_e2e_test.dart | Yes | A |
| `/teacher/exams` | Teacher | — | Yes | B |
| `/teacher/homework` | Teacher | — | Yes | B |
| `/teacher/leave` | Teacher | — | Yes | B |
| `/teacher/messages` | Teacher | — | Yes | B |
| `/teacher/timetable` | Teacher | — | Yes | B |
| `/transport` | Transport | — | No | D |
| `/transport/allocation` | Transport | transport_allocation_e2e_test.dart | Yes | A |
| `/transport/attendance` | Transport | — | Yes | B |
| `/transport/dashboard` | Transport | — | Yes | B |
| `/transport/drivers` | Transport | — | Yes | B |
| `/transport/reports` | Transport | — | Yes | B |
| `/transport/routes` | Transport | transport_activate_e2e_test.dart, transport_route_e2e_test.dart | Yes | A |
| `/transport/settings` | Transport | — | Yes | B |
| `/transport/tracking` | Transport | — | Yes | B |
| `/transport/vehicles` | Transport | — | Yes | B |
| `/white-label` | White Label | white_label_platform_e2e_test.dart | Yes | A |
| `/white-label` | White Label | — | No | D |
| `/white-label/branding` | White Label | — | No | D |
| `/white-label/deployment` | White Label | — | No | D |
| `/white-label/logo` | White Label | — | No | D |
| `/white-label/theme` | White Label | — | No | D |

---

## 3. Screen inventory

Source: `lib/features/**/*_screen.dart`

| Screen | Module | Widget test | Patrol | Coverage % |
|--------|--------|:-----------:|:------:|:----------:|
| `timetable_hub_screen` | Other | No | No | 0% |
| `admin_module_placeholder_screen` | Admin | Yes | Yes | 100% |
| `admissions_applications_screen` | Admissions | Yes | Yes | 100% |
| `admissions_approval_screen` | Admissions | Yes | Yes | 100% |
| `admissions_dashboard_screen` | Admissions | Yes | Yes | 100% |
| `admissions_documents_screen` | Admissions | Yes | Yes | 100% |
| `admissions_enrollment_screen` | Admissions | Yes | Yes | 100% |
| `admissions_fee_handoff_screen` | Admissions | Yes | Yes | 100% |
| `admissions_lead_detail_screen` | Admissions | Yes | Yes | 100% |
| `admissions_leads_screen` | Admissions | Yes | Yes | 100% |
| `admissions_reports_screen` | Admissions | Yes | Yes | 100% |
| `admissions_settings_screen` | Admissions | Yes | Yes | 100% |
| `ai_content_screen` | AI Content | Yes | Yes | 100% |
| `alumni_campaigns_screen` | Alumni | Yes | Yes | 100% |
| `alumni_dashboard_screen` | Alumni | Yes | Yes | 100% |
| `alumni_donations_screen` | Alumni | Yes | Yes | 100% |
| `alumni_events_screen` | Alumni | Yes | Yes | 100% |
| `alumni_mentorship_screen` | Alumni | Yes | Yes | 100% |
| `alumni_profile_screen` | Alumni | Yes | Yes | 100% |
| `alumni_registry_screen` | Alumni | Yes | Yes | 100% |
| `alumni_reports_screen` | Alumni | Yes | Yes | 100% |
| `alumni_settings_screen` | Alumni | Yes | Yes | 100% |
| `login_screen` | Auth | Yes | No | 40% |
| `otp_verification_screen` | Auth | Yes | No | 40% |
| `qa_login_screen` | Auth | Yes | No | 40% |
| `splash_screen` | Auth | Yes | No | 40% |
| `staff_login_screen` | Auth | Yes | No | 40% |
| `staff_otp_screen` | Auth | No | No | 0% |
| `branch_screen` | Multi-School | Yes | Yes | 100% |
| `broadcast_admin_screen` | Admin | Yes | Yes | 100% |
| `continuity_migration_screen` | Continuity | Yes | Yes | 100% |
| `control_center_analytics_screen` | Control Center | Yes | Yes | 100% |
| `control_center_billing_screen` | Control Center | Yes | Yes | 100% |
| `control_center_crm_screen` | Control Center | Yes | Yes | 100% |
| `control_center_dashboard_screen` | Control Center | Yes | Yes | 100% |
| `control_center_features_screen` | Control Center | No | Yes | 100% |
| `platform_intelligence_screen` | Control Center | Yes | Yes | 100% |
| `control_center_monitoring_screen` | Control Center | Yes | Yes | 100% |
| `control_center_providers_screen` | Control Center | Yes | Yes | 100% |
| `control_center_roles_screen` | Control Center | Yes | Yes | 100% |
| `control_center_schools_screen` | Control Center | Yes | Yes | 100% |
| `control_center_settings_screen` | Control Center | Yes | Yes | 100% |
| `control_center_subscriptions_screen` | Control Center | Yes | Yes | 100% |
| `control_center_success_screen` | Control Center | Yes | Yes | 100% |
| `control_center_support_screen` | Control Center | Yes | Yes | 100% |
| `control_center_white_label_screen` | Control Center | Yes | Yes | 100% |
| `copilot_screen` | Copilot | Yes | Yes | 100% |
| `copilot_persona_shell_screen` | Copilot | No | Yes | 100% |
| `ai_assistant_settings_screen` | SIS | No | Yes | 100% |
| `director_admissions_screen` | Admissions | No | Yes | 100% |
| `director_compliance_screen` | Director | No | Yes | 100% |
| `director_dashboard_screen` | Director | Yes | Yes | 100% |
| `director_growth_screen` | Director | No | Yes | 100% |
| `director_marketing_screen` | Director | No | Yes | 100% |
| `director_portfolio_screen` | Director | No | Yes | 100% |
| `director_reports_screen` | Director | No | Yes | 100% |
| `director_revenue_screen` | Director | No | Yes | 100% |
| `director_schools_screen` | Director | No | Yes | 100% |
| `dynamic_widget_layout_editor_screen` | Dynamic Widgets | No | No | 0% |
| `dynamic_widget_registry_screen` | Dynamic Widgets | Yes | No | 40% |
| `dynamic_widget_runtime_screen` | Dynamic Widgets | Yes | No | 40% |
| `education_screen` | Education | Yes | Yes | 100% |
| `employee_360_screen` | Employee | No | Yes | 100% |
| `employee_platform_screen` | Employee | No | Yes | 100% |
| `dynamic_dashboard_screen` | Evolution | No | No | 0% |
| `growth_platform_screen` | Evolution | Yes | No | 40% |
| `parent_insights_screen` | Parent | No | Yes | 100% |
| `principal_command_screen` | Evolution | No | No | 0% |
| `setup_wizard_screen` | Evolution | No | No | 0% |
| `teacher_assistant_screen` | SIS | No | Yes | 100% |
| `finance_collection_detail_screen` | Finance | Yes | Yes | 100% |
| `finance_collections_screen` | Finance | Yes | Yes | 100% |
| `finance_dashboard_screen` | Finance | Yes | Yes | 100% |
| `finance_defaulters_screen` | Finance | Yes | Yes | 100% |
| `finance_discounts_screen` | Finance | Yes | Yes | 100% |
| `finance_fee_assignment_screen` | Finance | Yes | Yes | 100% |
| `finance_fee_structures_screen` | Finance | Yes | Yes | 100% |
| `finance_qr_payment_screen` | Finance | Yes | Yes | 100% |
| `finance_copilot_screen` | Finance | No | Yes | 100% |
| `finance_executive_dashboard_screen` | Finance | No | Yes | 100% |
| `finance_offline_payments_screen` | Finance | Yes | Yes | 100% |
| `finance_reconciliation_screen` | Finance | No | Yes | 100% |
| `finance_refunds_screen` | Finance | Yes | Yes | 100% |
| `finance_reports_screen` | Finance | Yes | Yes | 100% |
| `finance_settings_screen` | Finance | Yes | Yes | 100% |
| `finance_student_accounts_screen` | Finance | Yes | Yes | 100% |
| `franchise_screen` | Multi-School | Yes | Yes | 100% |
| `homework_intelligence_screen` | Intelligence | Yes | Yes | 100% |
| `hostel_attendance_screen` | Hostel | Yes | Yes | 100% |
| `hostel_dashboard_screen` | Hostel | Yes | Yes | 100% |
| `hostel_leave_screen` | Hostel | Yes | Yes | 100% |
| `hostel_mess_screen` | Hostel | Yes | Yes | 100% |
| `hostel_reports_screen` | Hostel | Yes | Yes | 100% |
| `hostel_rooms_screen` | Hostel | Yes | Yes | 100% |
| `hostel_students_screen` | Hostel | Yes | Yes | 100% |
| `hostel_visitors_screen` | Hostel | Yes | Yes | 100% |
| `hr_attendance_screen` | HR | Yes | Yes | 100% |
| `hr_dashboard_screen` | HR | Yes | Yes | 100% |
| `hr_employee_profile_screen` | HR | Yes | Yes | 100% |
| `hr_employees_screen` | HR | Yes | Yes | 100% |
| `hr_leave_screen` | HR | Yes | Yes | 100% |
| `hr_payroll_screen` | HR | Yes | Yes | 100% |
| `hr_performance_screen` | HR | Yes | Yes | 100% |
| `hr_recruitment_screen` | HR | Yes | Yes | 100% |
| `hr_settings_screen` | HR | Yes | Yes | 100% |
| `industry_hub_screen` | Industry | Yes | Yes | 100% |
| `exam_intelligence_screen` | Intelligence | No | Yes | 100% |
| `intelligence_screen` | Intelligence | Yes | Yes | 100% |
| `student_success_screen` | Intelligence | Yes | Yes | 100% |
| `teacher_effectiveness_screen` | Intelligence | Yes | Yes | 100% |
| `inventory_allocation_screen` | Inventory | Yes | Yes | 100% |
| `inventory_assets_screen` | Inventory | Yes | Yes | 100% |
| `inventory_categories_screen` | Inventory | Yes | Yes | 100% |
| `inventory_dashboard_screen` | Inventory | Yes | Yes | 100% |
| `inventory_copilot_screen` | Inventory | Yes | Yes | 100% |
| `inventory_lifecycle_screen` | Inventory | Yes | Yes | 100% |
| `inventory_maintenance_screen` | Inventory | Yes | Yes | 100% |
| `inventory_procurement_screen` | Inventory | Yes | Yes | 100% |
| `inventory_reports_screen` | Inventory | Yes | Yes | 100% |
| `inventory_vendors_screen` | Inventory | Yes | Yes | 100% |
| `inventory_distribution_screen` | Inventory | Yes | Yes | 100% |
| `inventory_replacement_screen` | Inventory | Yes | Yes | 100% |
| `library_catalog_screen` | Library | Yes | Yes | 100% |
| `library_dashboard_screen` | Library | Yes | Yes | 100% |
| `library_fines_screen` | Library | Yes | Yes | 100% |
| `library_issues_screen` | Library | Yes | Yes | 100% |
| `library_members_screen` | Library | Yes | Yes | 100% |
| `library_reports_screen` | Library | Yes | Yes | 100% |
| `library_resources_screen` | Library | Yes | Yes | 100% |
| `library_returns_screen` | Library | Yes | Yes | 100% |
| `management_academics_screen` | Management | Yes | Yes | 100% |
| `management_admissions_screen` | Admissions | Yes | Yes | 100% |
| `management_analytics_screen` | Management | Yes | Yes | 100% |
| `management_dashboard_screen` | Management | Yes | Yes | 100% |
| `management_finance_screen` | Finance | Yes | Yes | 100% |
| `intelligence_hub_screen` | Management | Yes | Yes | 100% |
| `management_performance_screen` | Management | Yes | Yes | 100% |
| `management_settings_screen` | Management | Yes | Yes | 100% |
| `management_tasks_screen` | Management | Yes | Yes | 100% |
| `school_memories_screen` | Memories | Yes | Yes | 100% |
| `school_memory_event_screen` | Memories | No | Yes | 100% |
| `multi_school_portfolio_screen` | Multi-School | Yes | Yes | 100% |
| `school_onboarding_wizard_screen` | Multi-School | Yes | Yes | 100% |
| `notifications_screen` | Notifications | No | No | 0% |
| `onboarding_hub_screen` | Onboarding | No | Yes | 100% |
| `operations_hub_screen` | Operations | Yes | Yes | 100% |
| `organization_builder_hub_screen` | Organization Builder | Yes | Yes | 100% |
| `organization_builder_interview_screen` | Organization Builder | Yes | Yes | 100% |
| `organization_builder_preview_screen` | Organization Builder | No | Yes | 100% |
| `organization_provisioning_screen` | Organization Builder | No | Yes | 100% |
| `trust_intelligence_hub_screen` | Intelligence | Yes | Yes | 100% |
| `parent_academic_report_screen` | Parent | No | Yes | 100% |
| `parent_attendance_screen` | Parent | No | Yes | 100% |
| `parent_dashboard_screen` | Parent | Yes | Yes | 100% |
| `parent_events_screen` | Parent | Yes | Yes | 100% |
| `parent_exams_screen` | Parent | Yes | Yes | 100% |
| `parent_experience_hub_screen` | Parent | No | Yes | 100% |
| `parent_fees_screen` | Parent | No | Yes | 100% |
| `parent_homework_screen` | Parent | Yes | Yes | 100% |
| `parent_leave_screen` | Parent | Yes | Yes | 100% |
| `parent_conversation_screen` | Parent | No | Yes | 100% |
| `parent_messages_screen` | Parent | No | Yes | 100% |
| `parent_notices_screen` | Parent | Yes | Yes | 100% |
| `parent_payment_screen` | Parent | Yes | Yes | 100% |
| `parent_profile_screen` | Parent | Yes | Yes | 100% |
| `parent_receipt_detail_screen` | Parent | Yes | Yes | 100% |
| `parent_receipts_screen` | Parent | Yes | Yes | 100% |
| `parent_timetable_screen` | Parent | Yes | Yes | 100% |
| `parent_meeting_detail_screen` | Parent | No | Yes | 100% |
| `parent_meetings_screen` | Parent | Yes | Yes | 100% |
| `platform_operations_hub_screen` | Platform Operations | Yes | Yes | 100% |
| `achievement_promotion_preview_screen` | Promotion | No | Yes | 100% |
| `achievement_promotion_screen` | Promotion | No | Yes | 100% |
| `resource_optimization_screen` | Operations | Yes | Yes | 100% |
| `academic_progress_screen` | School Completion | No | No | 0% |
| `branding_screen` | School Completion | Yes | No | 40% |
| `communication_analytics_screen` | School Completion | No | No | 0% |
| `communication_delivery_screen` | School Completion | No | No | 0% |
| `lesson_analytics_screen` | School Completion | No | No | 0% |
| `lesson_logs_screen` | School Completion | No | No | 0% |
| `parent_activation_dashboard_screen` | Parent | No | Yes | 100% |
| `pilot_dashboard_screen` | School Completion | No | No | 0% |
| `room_allocation_screen` | School Completion | No | Yes | 100% |
| `school_completion_hub_screen` | School Completion | No | No | 0% |
| `subject_assignment_screen` | School Completion | No | No | 0% |
| `subjects_screen` | School Completion | Yes | No | 40% |
| `substitute_manager_screen` | School Completion | Yes | No | 40% |
| `syllabus_automation_screen` | School Completion | No | No | 0% |
| `teacher_reassignment_screen` | Teacher | Yes | Yes | 100% |
| `timetable_automation_screen` | School Completion | No | No | 0% |
| `timetable_intelligence_screen` | Intelligence | No | Yes | 100% |
| `timetable_optimization_screen` | School Completion | Yes | Yes | 100% |
| `whatsapp_provider_screen` | School Completion | No | No | 0% |
| `sis_academic_assignment_screen` | SIS | Yes | Yes | 100% |
| `sis_promotion_screen` | SIS | Yes | Yes | 100% |
| `sis_reshuffle_screen` | SIS | Yes | Yes | 100% |
| `sis_section_balance_screen` | SIS | Yes | Yes | 100% |
| `sis_admissions_conversion_screen` | Admissions | Yes | Yes | 100% |
| `sis_dashboard_screen` | SIS | Yes | Yes | 100% |
| `sis_profile_screen` | SIS | Yes | Yes | 100% |
| `sis_registry_screen` | SIS | Yes | Yes | 100% |
| `student_attendance_screen` | Student | Yes | Yes | 100% |
| `student_dashboard_screen` | Student | Yes | Yes | 100% |
| `student_exams_screen` | Student | Yes | Yes | 100% |
| `student_homework_screen` | Student | Yes | Yes | 100% |
| `student_notices_screen` | Student | Yes | Yes | 100% |
| `student_profile_screen` | Student | Yes | Yes | 100% |
| `student_timetable_screen` | Student | Yes | Yes | 100% |
| `student_360_screen` | Student | Yes | Yes | 100% |
| `teacher_attendance_screen` | Teacher | Yes | Yes | 100% |
| `teacher_dashboard_screen` | Teacher | Yes | Yes | 100% |
| `teacher_exams_screen` | Teacher | Yes | Yes | 100% |
| `teacher_homework_screen` | Teacher | Yes | Yes | 100% |
| `teacher_leave_screen` | Teacher | Yes | Yes | 100% |
| `teacher_conversation_screen` | Teacher | Yes | Yes | 100% |
| `teacher_messages_screen` | Teacher | Yes | Yes | 100% |
| `teacher_timetable_screen` | Teacher | Yes | Yes | 100% |
| `transport_allocation_screen` | Transport | Yes | Yes | 100% |
| `transport_attendance_screen` | Transport | Yes | Yes | 100% |
| `transport_dashboard_screen` | Transport | Yes | Yes | 100% |
| `transport_drivers_screen` | Transport | Yes | Yes | 100% |
| `transport_reports_screen` | Transport | Yes | Yes | 100% |
| `transport_routes_screen` | Transport | Yes | Yes | 100% |
| `transport_settings_screen` | Transport | Yes | Yes | 100% |
| `transport_tracking_screen` | Transport | Yes | Yes | 100% |
| `transport_vehicles_screen` | Transport | Yes | Yes | 100% |
| `accommodation_dashboard_screen` | Accommodation | Yes | Yes | 100% |
| `accommodation_intelligence_screen` | Intelligence | No | Yes | 100% |
| `occupancy_management_screen` | Management | No | Yes | 100% |
| `resident_lifecycle_screen` | Accommodation | No | Yes | 100% |
| `room_allocation_screen` | Accommodation | No | Yes | 100% |
| `appointment_workflow_screen` | Healthcare | No | Yes | 100% |
| `healthcare_dashboard_screen` | Healthcare | Yes | Yes | 100% |
| `healthcare_intelligence_screen` | Intelligence | No | Yes | 100% |
| `patient_registry_screen` | Healthcare | No | Yes | 100% |
| `practitioner_management_screen` | Management | No | Yes | 100% |
| `hospitality_intelligence_screen` | Intelligence | No | Yes | 100% |
| `kitchen_workflow_screen` | Restaurant | No | Yes | 100% |
| `orders_screen` | Restaurant | Yes | Yes | 100% |
| `restaurant_dashboard_screen` | Restaurant | Yes | Yes | 100% |
| `table_management_screen` | Management | No | Yes | 100% |
| `appointment_scheduling_screen` | Salon | No | Yes | 100% |
| `business_intelligence_screen` | Intelligence | No | Yes | 100% |
| `customer_registry_screen` | Salon | No | Yes | 100% |
| `salon_dashboard_screen` | Salon | Yes | Yes | 100% |
| `service_tracking_screen` | Salon | No | Yes | 100% |
| `branding_profiles_screen` | White Label | No | Yes | 100% |
| `deployment_profiles_screen` | White Label | No | Yes | 100% |
| `logo_management_screen` | Management | No | Yes | 100% |
| `theme_management_screen` | Management | No | Yes | 100% |
| `white_label_hub_screen` | White Label | Yes | Yes | 100% |
| `workflow_automation_screen` | Workflow Automation | Yes | Yes | 100% |
