import 'package:flutter/foundation.dart';

/// Stable widget keys for Patrol / integration tests (QA builds only).
abstract final class QaTestKeys {
  static const splash = ValueKey<String>('qa_splash_screen');
  static const qaLoginScreen = ValueKey<String>('qa_login_screen');
  static const loginPhoneField = ValueKey<String>('login_phone_field');
  static const loginContinueButton = ValueKey<String>('login_continue_button');
  static const otpField = ValueKey<String>('otp_verification_field');
  static const otpVerifyButton = ValueKey<String>('otp_verify_button');
  static const logoutButton = ValueKey<String>('auth_logout_button');
  static const logoutConfirmButton = ValueKey<String>('auth_logout_confirm');
  static const profileButton = ValueKey<String>('profile_button');
  static const receiptHistoryButton =
      ValueKey<String>('receipt_history_button');
  static const parentReceiptDownloadButton =
      ValueKey<String>('parent_receipt_download_button');
  static const parentReceiptShareButton =
      ValueKey<String>('parent_receipt_share_button');
  static const parentReceiptPdfSuccessSnackbar =
      ValueKey<String>('parent_receipt_pdf_success_snackbar');
  static const erpMenuButton = ValueKey<String>('erp_menu_button');

  static ValueKey<String> erpNavModule(String module) =>
      ValueKey<String>('erp_nav_$module');

  static ValueKey<String> principalQuickAction(String action) =>
      ValueKey<String>('principal_qa_$action');

  static const enrollmentContinueButton =
      ValueKey<String>('enrollment_continue_button');

  static const enrollmentSubmitButton =
      ValueKey<String>('enrollment_submit_button');

  static const enrollmentStudentNameField =
      ValueKey<String>('enrollment_student_name_field');

  // --- Admissions E2E journey ---
  static const admissionsCreateLeadButton =
      ValueKey<String>('admissions_create_lead_button');

  static const admissionsLeadParentNameField =
      ValueKey<String>('admissions_lead_parent_name_field');

  static const admissionsLeadStudentNameField =
      ValueKey<String>('admissions_lead_student_name_field');

  static const admissionsLeadClassField =
      ValueKey<String>('admissions_lead_class_field');

  static const admissionsLeadPhoneField =
      ValueKey<String>('admissions_lead_phone_field');

  static const admissionsLeadDialogCreateButton =
      ValueKey<String>('admissions_lead_dialog_create_button');

  static const admissionsLeadCreatedSnackbar =
      ValueKey<String>('admissions_lead_created_snackbar');

  static const admissionsCreateApplicationButton =
      ValueKey<String>('admissions_create_application_button');

  static const admissionsApplicationSubmittedSnackbar =
      ValueKey<String>('admissions_application_submitted_snackbar');

  static const admissionsEnrollmentSubmittedSnackbar =
      ValueKey<String>('admissions_enrollment_submitted_snackbar');

  static const admissionsApproveButton =
      ValueKey<String>('admissions_approve_button');

  static ValueKey<String> admissionsApprovalQueueRow(String studentName) =>
      ValueKey<String>(
        'admissions_approval_row_${normalizeSubNavLabel(studentName)}',
      );

  static const admissionsApprovedSnackbar =
      ValueKey<String>('admissions_approved_snackbar');

  static const sisConvertEnrollmentButton =
      ValueKey<String>('sis_convert_enrollment_button');

  static const sisConversionSuccessSnackbar =
      ValueKey<String>('sis_conversion_success_snackbar');

  static const sisRegistrySearchField =
      ValueKey<String>('sis_registry_search_field');

  static const sisEditProfileButton =
      ValueKey<String>('sis_edit_profile_button');
  static const sisEditProfileSaveButton =
      ValueKey<String>('sis_edit_profile_save_button');
  static const sisUploadDocumentButton =
      ValueKey<String>('sis_upload_document_button');
  static const sisUploadDocumentSubmitButton =
      ValueKey<String>('sis_upload_document_submit_button');
  static const sisDocumentUploadSuccessSnackbar =
      ValueKey<String>('sis_document_upload_success_snackbar');

  static ValueKey<String> sisRegistryStudentRow(String studentName) =>
      ValueKey<String>(
        'sis_registry_student_${normalizeSubNavLabel(studentName)}',
      );

  static const sisPromotionSourceYearField =
      ValueKey<String>('sis_promotion_source_year');
  static const sisPromotionTargetYearField =
      ValueKey<String>('sis_promotion_target_year');
  static const sisPromotionContinueButton =
      ValueKey<String>('sis_promotion_continue_button');
  static const sisPromotionExecutionSummary =
      ValueKey<String>('sis_promotion_execution_summary');

  static ValueKey<String> sisPromotionPreviewRow(String studentId) =>
      ValueKey<String>('sis_promotion_preview_$studentId');

  static const sisReshuffleExecuteButton =
      ValueKey<String>('sis_reshuffle_execute_button');
  static const sisReshuffleExecutionSummary =
      ValueKey<String>('sis_reshuffle_execution_summary');

  static ValueKey<String> sisReshufflePreviewRow(String studentId) =>
      ValueKey<String>('sis_reshuffle_preview_$studentId');

  static const sisSectionBalanceExecuteButton =
      ValueKey<String>('sis_section_balance_execute_button');
  static const sisContinuityPreviewButton =
      ValueKey<String>('sis_continuity_preview_button');
  static const sisContinuityExecuteButton =
      ValueKey<String>('sis_continuity_execute_button');
  static const sisContinuityPlanSummary =
      ValueKey<String>('sis_continuity_plan_summary');
  static const sisContinuityExecutionSummary =
      ValueKey<String>('sis_continuity_execution_summary');
  static const sisQuarterlyExecuteButton =
      ValueKey<String>('sis_quarterly_execute_button');
  static const sisPerformanceExecuteButton =
      ValueKey<String>('sis_performance_execute_button');

  static ValueKey<String> sisSectionBalancePreviewRow(String studentId) =>
      ValueKey<String>('sis_section_balance_preview_$studentId');
  static ValueKey<String> sisQuarterlyPreviewRow(String studentId) =>
      ValueKey<String>('sis_quarterly_preview_$studentId');
  static ValueKey<String> sisPerformancePreviewRow(String studentId) =>
      ValueKey<String>('sis_performance_preview_$studentId');

  // --- Teacher attendance E2E ---
  static const teacherAttendanceSubmittedBanner =
      ValueKey<String>('teacher_attendance_submitted_banner');

  static const teacherAttendanceSubmitButton =
      ValueKey<String>('teacher_attendance_submit_button');

  // --- Finance E2E journey ---
  static ValueKey<String> financeHandoffQueueRow(String studentName) =>
      ValueKey<String>(
        'finance_handoff_row_${normalizeSubNavLabel(studentName)}',
      );

  static const financeAssignFeePlanButton =
      ValueKey<String>('finance_assign_fee_plan_button');

  static const financeFeeAccountCreatedSnackbar =
      ValueKey<String>('finance_fee_account_created_snackbar');

  static const financeRecordCollectionButton =
      ValueKey<String>('finance_record_collection_button');

  static const financeCollectionInvoiceField =
      ValueKey<String>('finance_collection_invoice_field');

  static const financeCollectionAmountField =
      ValueKey<String>('finance_collection_amount_field');

  static const financeCollectionSubmitButton =
      ValueKey<String>('finance_collection_submit_button');

  static const financeCollectionSuccessSnackbar =
      ValueKey<String>('finance_collection_success_snackbar');

  static const financeRecordOfflinePaymentFab =
      ValueKey<String>('finance_record_offline_payment_fab');
  static const financeOfflinePaymentInvoiceField =
      ValueKey<String>('finance_offline_payment_invoice_field');
  static const financeOfflinePaymentStudentField =
      ValueKey<String>('finance_offline_payment_student_field');
  static const financeOfflinePaymentAmountField =
      ValueKey<String>('finance_offline_payment_amount_field');
  static const financeOfflinePaymentReferenceField =
      ValueKey<String>('finance_offline_payment_reference_field');
  static const financeOfflinePaymentSubmitButton =
      ValueKey<String>('finance_offline_payment_submit_button');
  static const financeOfflinePaymentSuccessSnackbar =
      ValueKey<String>('finance_offline_payment_success_snackbar');
  static const financeOfflinePaymentReconcileSuccessSnackbar =
      ValueKey<String>('finance_offline_payment_reconcile_success_snackbar');

  static ValueKey<String> financeReconcileOfflinePaymentButton(
          String paymentId) =>
      ValueKey<String>('finance_reconcile_offline_payment_$paymentId');

  static const financeQrPayButton = ValueKey<String>('finance_qr_pay_button');
  static const financeQrInvoiceField =
      ValueKey<String>('finance_qr_invoice_field');
  static const financeQrAmountField =
      ValueKey<String>('finance_qr_amount_field');
  static const financeGenerateQrButton =
      ValueKey<String>('finance_generate_qr_button');
  static const financeQrReceiptField =
      ValueKey<String>('finance_qr_receipt_field');
  static const financeConfirmQrPaymentButton =
      ValueKey<String>('finance_confirm_qr_payment_button');
  static const financeQrPaymentConfirmedSnackbar =
      ValueKey<String>('finance_qr_payment_confirmed_snackbar');

  static const schoolMemoriesScreen =
      ValueKey<String>('school_memories_screen');
  static const schoolMemoriesStatusTabs =
      ValueKey<String>('school_memories_status_tabs');
  static const schoolMemoriesCreateFab =
      ValueKey<String>('school_memories_create_fab');
  static const schoolMemoriesCreateTitleField =
      ValueKey<String>('school_memories_create_title_field');
  static const schoolMemoriesCreateCategoryField =
      ValueKey<String>('school_memories_create_category_field');
  static const schoolMemoriesCreateDescriptionField =
      ValueKey<String>('school_memories_create_description_field');
  static const schoolMemoriesCreateSubmitButton =
      ValueKey<String>('school_memories_create_submit_button');
  static const schoolMemoriesCreatedSnackbar =
      ValueKey<String>('school_memories_created_snackbar');
  static const schoolMemoriesPublishButton =
      ValueKey<String>('school_memories_publish_button');
  static const schoolMemoriesPublishedSnackbar =
      ValueKey<String>('school_memories_published_snackbar');

  static ValueKey<String> schoolMemoriesEventTile(String eventId) =>
      ValueKey<String>('school_memories_event_$eventId');

  static ValueKey<String> financeCollectionReceiptRow(String receiptNumber) =>
      ValueKey<String>(
        'finance_collection_receipt_${normalizeSubNavLabel(receiptNumber)}',
      );

  static const financeReceiptSearchField =
      ValueKey<String>('finance_receipt_search_field');

  static const financeLastInvoiceIdField =
      ValueKey<String>('finance_last_invoice_id');

  static ValueKey<String> financeIssueInvoiceButton(String invoiceId) =>
      ValueKey<String>('finance_issue_invoice_$invoiceId');

  static ValueKey<String> financeCancelInvoiceButton(String invoiceId) =>
      ValueKey<String>('finance_cancel_invoice_$invoiceId');

  static const financeInvoiceIssuedSnackbar =
      ValueKey<String>('finance_invoice_issued_snackbar');

  static const financeInvoiceCancelledSnackbar =
      ValueKey<String>('finance_invoice_cancelled_snackbar');

  static ValueKey<String> financeCancelCollectionButton(String collectionId) =>
      ValueKey<String>('finance_cancel_collection_$collectionId');

  static const financeCollectionCancelledSnackbar =
      ValueKey<String>('finance_collection_cancelled_snackbar');

  static const financeCancelInvoiceConfirmButton =
      ValueKey<String>('finance_cancel_invoice_confirm_button');

  static const financeCancelCollectionConfirmButton =
      ValueKey<String>('finance_cancel_collection_confirm_button');

  static const financeReportExportPdfButton =
      ValueKey<String>('finance_report_export_pdf_button');

  static const financeReportExportSuccessSnackbar =
      ValueKey<String>('finance_report_export_success_snackbar');

  static const hrCreateLeaveButton = ValueKey<String>('hr_create_leave_button');

  static const hrLeaveSuccessSnackbar =
      ValueKey<String>('hr_leave_success_snackbar');
  static const hrLeaveApprovalSnackbar =
      ValueKey<String>('hr_leave_approval_snackbar');

  static ValueKey<String> hrApproveLeaveButton(String leaveRequestId) =>
      ValueKey<String>('hr_approve_leave_$leaveRequestId');

  static ValueKey<String> hrRejectLeaveButton(String leaveRequestId) =>
      ValueKey<String>('hr_reject_leave_$leaveRequestId');

  static const hrCreateEmployeeButton =
      ValueKey<String>('hr_create_employee_button');

  static const hrCreateEmployeeDialogSubmitButton =
      ValueKey<String>('hr_create_employee_dialog_submit_button');

  static const hrEmployeeCreatedSnackbar =
      ValueKey<String>('hr_employee_created_snackbar');

  static ValueKey<String> hrEditEmployeeButton(String employeeId) =>
      ValueKey<String>('hr_edit_employee_button_$employeeId');

  static const hrEditEmployeeDialogSubmitButton =
      ValueKey<String>('hr_edit_employee_dialog_submit_button');

  static const hrEmployeeUpdatedSnackbar =
      ValueKey<String>('hr_employee_updated_snackbar');

  static ValueKey<String> hrActivateEmployeeButton(String employeeId) =>
      ValueKey<String>('hr_activate_employee_button_$employeeId');

  static ValueKey<String> hrDeactivateEmployeeButton(String employeeId) =>
      ValueKey<String>('hr_deactivate_employee_button_$employeeId');

  static const hrEmployeeStatusSuccessSnackbar =
      ValueKey<String>('hr_employee_status_success_snackbar');

  static const hrProcessPayrollButton =
      ValueKey<String>('hr_process_payroll_button');

  static const hrPayrollProcessedSnackbar =
      ValueKey<String>('hr_payroll_processed_snackbar');

  static const hrPayrollExportPdfButton =
      ValueKey<String>('hr_payroll_export_pdf_button');

  static const hrPayrollExportSuccessSnackbar =
      ValueKey<String>('hr_payroll_export_success_snackbar');

  static const inventoryCreatePoButton =
      ValueKey<String>('inventory_create_po_button');

  static const inventoryPoSuccessSnackbar =
      ValueKey<String>('inventory_po_success_snackbar');

  static ValueKey<String> inventoryPoReceiveHandoffButton(String orderId) =>
      ValueKey<String>('inventory_po_receive_handoff_button_$orderId');

  static ValueKey<String> inventoryPoApproveHandoffButton(String orderId) =>
      ValueKey<String>('inventory_po_approve_handoff_button_$orderId');

  static const inventoryPoApproveHandoffDialogButton =
      ValueKey<String>('inventory_po_approve_handoff_dialog_button');

  static const inventoryPoApproveHandoffSuccessSnackbar =
      ValueKey<String>('inventory_po_approve_handoff_success_snackbar');

  static const inventoryPoReceiveHandoffDialogButton =
      ValueKey<String>('inventory_po_receive_handoff_dialog_button');

  static const inventoryPoReceiveHandoffSuccessSnackbar =
      ValueKey<String>('inventory_po_receive_handoff_success_snackbar');

  static const transportSaveRouteButton =
      ValueKey<String>('transport_save_route_button');

  static const transportSaveRouteDialogButton =
      ValueKey<String>('transport_save_route_dialog_button');

  static const transportRouteSuccessSnackbar =
      ValueKey<String>('transport_route_success_snackbar');

  static ValueKey<String> transportActivateRouteButton(String routeId) =>
      ValueKey<String>('transport_activate_route_button_$routeId');

  static const educationReportRemarksTab =
      ValueKey<String>('education_report_remarks_tab');

  static const transportActivateRouteDialogButton =
      ValueKey<String>('transport_activate_route_dialog_button');

  static const transportRouteActivatedSnackbar =
      ValueKey<String>('transport_route_activated_snackbar');

  static ValueKey<String> transportAssignStudentButton(String allocationId) =>
      ValueKey<String>('transport_assign_student_button_$allocationId');

  static const transportAssignDialogSubmitButton =
      ValueKey<String>('transport_assign_dialog_submit_button');

  static const transportAssignSuccessSnackbar =
      ValueKey<String>('transport_assign_success_snackbar');

  static ValueKey<String> transportTransferStudentButton(String allocationId) =>
      ValueKey<String>('transport_transfer_student_button_$allocationId');

  static const transportTransferDialogSubmitButton =
      ValueKey<String>('transport_transfer_dialog_submit_button');

  static const transportTransferSuccessSnackbar =
      ValueKey<String>('transport_transfer_success_snackbar');

  static ValueKey<String> transportRemoveStudentButton(String allocationId) =>
      ValueKey<String>('transport_remove_student_button_$allocationId');

  static const transportRemoveDialogSubmitButton =
      ValueKey<String>('transport_remove_dialog_submit_button');

  static const transportRemoveSuccessSnackbar =
      ValueKey<String>('transport_remove_success_snackbar');

  static const transportReportExportPdfButton =
      ValueKey<String>('transport_report_export_pdf_button');

  static const transportReportExportSuccessSnackbar =
      ValueKey<String>('transport_report_export_success_snackbar');

  static const inventoryRecordLifecycleButton =
      ValueKey<String>('inventory_record_lifecycle_button');

  static const inventoryLifecycleSuccessSnackbar =
      ValueKey<String>('inventory_lifecycle_success_snackbar');

  static const inventoryReportExportPdfButton =
      ValueKey<String>('inventory_report_export_pdf_button');

  static const inventoryReportExportSuccessSnackbar =
      ValueKey<String>('inventory_report_export_success_snackbar');
  static const inventoryDistributionScreen =
      ValueKey<String>('inventory_distribution_screen');
  static const inventoryDistributionCreateFab =
      ValueKey<String>('inventory_distribution_create_fab');
  static const inventoryDistributionStudentIdField =
      ValueKey<String>('inventory_distribution_student_id_field');
  static const inventoryDistributionCatalogItemField =
      ValueKey<String>('inventory_distribution_catalog_item_field');
  static const inventoryDistributionQuantityField =
      ValueKey<String>('inventory_distribution_quantity_field');
  static const inventoryDistributionCreateSubmitButton =
      ValueKey<String>('inventory_distribution_create_submit_button');
  static const inventoryDistributionCreateSuccessSnackbar =
      ValueKey<String>('inventory_distribution_create_success_snackbar');
  static const inventoryDistributionMarkDistributedSuccessSnackbar =
      ValueKey<String>(
    'inventory_distribution_mark_distributed_success_snackbar',
  );
  static const inventoryDistributionReplacementSuccessSnackbar =
      ValueKey<String>('inventory_distribution_replacement_success_snackbar');

  static ValueKey<String> inventoryDistributionRow(String distributionId) =>
      ValueKey<String>('inventory_distribution_row_$distributionId');

  static ValueKey<String> inventoryDistributionMarkDistributedButton(
    String distributionId,
  ) =>
      ValueKey<String>(
        'inventory_distribution_mark_distributed_$distributionId',
      );

  static ValueKey<String> inventoryDistributionRequestReplacementButton(
    String distributionId,
  ) =>
      ValueKey<String>(
        'inventory_distribution_request_replacement_$distributionId',
      );

  static const inventoryDistributionReplacementsLink =
      ValueKey<String>('inventory_distribution_replacements_link');

  static const inventoryReplacementScreen =
      ValueKey<String>('inventory_replacement_screen');

  static ValueKey<String> inventoryReplacementRow(String requestId) =>
      ValueKey<String>('inventory_replacement_row_$requestId');

  static ValueKey<String> inventoryReplacementApproveButton(String requestId) =>
      ValueKey<String>('inventory_replacement_approve_$requestId');

  static ValueKey<String> inventoryReplacementFulfillButton(String requestId) =>
      ValueKey<String>('inventory_replacement_fulfill_$requestId');

  static ValueKey<String> inventoryReplacementRejectButton(String requestId) =>
      ValueKey<String>('inventory_replacement_reject_$requestId');

  static const inventoryReplacementApproveSuccessSnackbar =
      ValueKey<String>('inventory_replacement_approve_success_snackbar');

  static const inventoryReplacementFulfillSuccessSnackbar =
      ValueKey<String>('inventory_replacement_fulfill_success_snackbar');

  static const inventoryReplacementRejectSuccessSnackbar =
      ValueKey<String>('inventory_replacement_reject_success_snackbar');

  static const educationPublishRemarkButton =
      ValueKey<String>('education_publish_remark_button');

  static const educationRemarkPublishedSnackbar =
      ValueKey<String>('education_remark_published_snackbar');

  static const educationReportCardExportButton =
      ValueKey<String>('education_report_card_export_button');

  static const educationReportCardExportSuccessSnackbar =
      ValueKey<String>('education_report_card_export_success_snackbar');

  static ValueKey<String> managementApproveButton(String approvalId) =>
      ValueKey<String>('management_approve_$approvalId');

  static ValueKey<String> managementRejectButton(String approvalId) =>
      ValueKey<String>('management_reject_$approvalId');

  static const managementApprovalSuccessSnackbar =
      ValueKey<String>('management_approval_success_snackbar');

  static const managementDashboardExportButton =
      ValueKey<String>('management_dashboard_export_button');

  static const managementDashboardExportSnackbar =
      ValueKey<String>('management_dashboard_export_snackbar');
  static const managementDashboardPrintButton =
      ValueKey<String>('management_dashboard_print_button');
  static const managementDashboardShareButton =
      ValueKey<String>('management_dashboard_share_button');
  static const managementDashboardExportSuccessSnackbar =
      ValueKey<String>('management_dashboard_export_success_snackbar');
  static const operationsHubAlertDismissedSnackbar =
      ValueKey<String>('operations_hub_alert_dismissed_snackbar');
  static const operationsHubActionCompletedSnackbar =
      ValueKey<String>('operations_hub_action_completed_snackbar');

  static ValueKey<String> operationsHubAlertTile(String alertId) =>
      ValueKey<String>('operations_hub_alert_$alertId');
  static ValueKey<String> operationsHubDismissAlertButton(String alertId) =>
      ValueKey<String>('operations_hub_dismiss_alert_$alertId');
  static ValueKey<String> operationsHubActionTile(String actionId) =>
      ValueKey<String>('operations_hub_action_$actionId');
  static ValueKey<String> operationsHubCompleteActionButton(String actionId) =>
      ValueKey<String>('operations_hub_complete_action_$actionId');
  static const managementSettingsSaveButton =
      ValueKey<String>('management_settings_save_button');
  static const managementSettingsAcademicYearEditButton =
      ValueKey<String>('management_settings_academic_year_edit_button');
  static const managementSettingsDialogField =
      ValueKey<String>('management_settings_dialog_field');
  static const managementSettingsDialogSaveButton =
      ValueKey<String>('management_settings_dialog_save_button');
  static ValueKey<String> managementSettingsItemEditButton(String itemId) =>
      ValueKey<String>('management_settings_item_edit_$itemId');
  static const workflowAutomationScreen =
      ValueKey<String>('workflow_automation_screen');
  static const workflowRunScheduledNowButton =
      ValueKey<String>('workflow_run_scheduled_now_button');

  static ValueKey<String> managementKpiDrillButton(String kpiId) =>
      ValueKey<String>('management_kpi_drill_$kpiId');

  static const erpCopilotButton = ValueKey<String>('erp_copilot_button');

  static const copilotContextBanner =
      ValueKey<String>('copilot_context_banner');

  static const copilotMessageField = ValueKey<String>('copilot_message_field');

  static const copilotSendButton = ValueKey<String>('copilot_send_button');

  static const copilotNewConversationButton =
      ValueKey<String>('copilot_new_conversation_button');

  static const copilotFloatingDockFab =
      ValueKey<String>('copilot_floating_dock_fab');

  static const copilotFloatingDockPanel =
      ValueKey<String>('copilot_floating_dock_panel');

  static const copilotFloatingDockCollapseButton =
      ValueKey<String>('copilot_floating_dock_collapse_button');

  static const copilotFloatingDockContextSummary =
      ValueKey<String>('copilot_floating_dock_context_summary');

  static const copilotFloatingDockOpenButton =
      ValueKey<String>('copilot_floating_dock_open_button');

  static const copilotPersonaContextBanner =
      ValueKey<String>('copilot_persona_context_banner');

  static const copilotPersonaOpenFullButton =
      ValueKey<String>('copilot_persona_open_full_button');

  static const copilotPersonaReplyPanel =
      ValueKey<String>('copilot_persona_reply_panel');

  static ValueKey<String> copilotPersonaPromptChip(String prompt) =>
      ValueKey<String>('copilot_persona_prompt_${prompt.hashCode}');

  static const copilotAiEntryButton =
      ValueKey<String>('copilot_ai_entry_button');

  static const copilotSidebarAiEntry =
      ValueKey<String>('copilot_sidebar_ai_entry');

  static const copilotQuickActionReplyDialog =
      ValueKey<String>('copilot_quick_action_reply_dialog');

  static ValueKey<String> copilotQuickActionTile(String actionId) =>
      ValueKey<String>('copilot_quick_action_$actionId');

  static ValueKey<String> aiAccessModeOption(String modeKey) =>
      ValueKey<String>('ai_access_mode_$modeKey');

  static const aiAccessFloatingBubbleToggle =
      ValueKey<String>('ai_access_floating_bubble_toggle');

  static const aiAccessSyncNote = ValueKey<String>('ai_access_sync_note');

  static const aiAssistantSettingsLink =
      ValueKey<String>('ai_assistant_settings_link');

  static ValueKey<String> atRiskStudentRow(String studentId) =>
      ValueKey<String>('at_risk_student_$studentId');

  static const libraryIssueScanButton =
      ValueKey<String>('library_issue_scan_button');

  static const libraryIssueDialogSubmitButton =
      ValueKey<String>('library_issue_dialog_submit_button');

  static const libraryIssueSuccessSnackbar =
      ValueKey<String>('library_issue_success_snackbar');

  static const libraryReturnScanButton =
      ValueKey<String>('library_return_scan_button');

  static const libraryReturnDialogSubmitButton =
      ValueKey<String>('library_return_dialog_submit_button');

  static const libraryReturnSuccessSnackbar =
      ValueKey<String>('library_return_success_snackbar');

  static ValueKey<String> libraryReturnBookButton(String issueId) =>
      ValueKey<String>('library_return_book_$issueId');

  static const hostelAdmitStudentButton =
      ValueKey<String>('hostel_admit_student_button');

  static const hostelAssignRoomButton =
      ValueKey<String>('hostel_assign_room_button');

  static const hostelAdmitDialogSubmitButton =
      ValueKey<String>('hostel_admit_dialog_submit_button');

  static const hostelAdmitSuccessSnackbar =
      ValueKey<String>('hostel_admit_success_snackbar');

  static const hostelAssignDialogSubmitButton =
      ValueKey<String>('hostel_assign_dialog_submit_button');

  static const hostelAssignSuccessSnackbar =
      ValueKey<String>('hostel_assign_success_snackbar');

  static const hostelCheckoutDialogSubmitButton =
      ValueKey<String>('hostel_checkout_dialog_submit_button');

  static const hostelCheckoutSuccessSnackbar =
      ValueKey<String>('hostel_checkout_success_snackbar');

  static ValueKey<String> hostelAssignStudentButton(String studentId) =>
      ValueKey<String>('hostel_assign_student_$studentId');

  static ValueKey<String> hostelTransferStudentButton(String studentId) =>
      ValueKey<String>('hostel_transfer_student_$studentId');

  static ValueKey<String> hostelCheckoutStudentButton(String studentId) =>
      ValueKey<String>('hostel_checkout_student_$studentId');

  static const parentAttendanceKpiPercent =
      ValueKey<String>('parent_attendance_kpi_percent');

  /// Inventory INV lifecycle screen root (Patrol route navigation target).
  static const inventoryLifecycleScreen =
      ValueKey<String>('inventory_lifecycle_screen');

  static const platformIntelligenceScreen =
      ValueKey<String>('platform_intelligence_screen');

  static const communicationBroadcastAdminScreen =
      ValueKey<String>('communication_broadcast_admin_screen');
  static const communicationBroadcastSendButton =
      ValueKey<String>('communication_broadcast_send_button');
  static const communicationTemplateSaveButton =
      ValueKey<String>('communication_template_save_button');
  static const communicationBroadcastHistoryList =
      ValueKey<String>('communication_broadcast_history_list');

  static const substituteDayFilter = ValueKey<String>('substitute_day_filter');
  static const substituteClassFilter =
      ValueKey<String>('substitute_class_filter');
  static const substituteAssignButton =
      ValueKey<String>('substitute_assign_button');
  static const substituteAssignSuccessSnackbar =
      ValueKey<String>('substitute_assign_success_snackbar');
  static const teacherReassignmentSourceFilter =
      ValueKey<String>('teacher_reassignment_source_filter');
  static const teacherReassignmentSubmitButton =
      ValueKey<String>('teacher_reassignment_submit_button');
  static const teacherReassignmentSuccessSnackbar =
      ValueKey<String>('teacher_reassignment_success_snackbar');
  static const timetableOptimizationApplyAllButton =
      ValueKey<String>('timetable_optimization_apply_all_button');
  static const timetableOptimizationApplySuccessSnackbar =
      ValueKey<String>('timetable_optimization_apply_success_snackbar');
  static const growthPlatformScreen =
      ValueKey<String>('growth_platform_screen');

  static const growthCreateCampaignButton =
      ValueKey<String>('growth_create_campaign_button');
  static const growthCreateInquiryButton =
      ValueKey<String>('growth_create_inquiry_button');
  static const growthCampaignNameField =
      ValueKey<String>('growth_campaign_name_field');
  static const growthCampaignChannelField =
      ValueKey<String>('growth_campaign_channel_field');
  static const growthCampaignBudgetField =
      ValueKey<String>('growth_campaign_budget_field');
  static const growthCampaignAudienceField =
      ValueKey<String>('growth_campaign_audience_field');
  static const growthCampaignScheduleButton =
      ValueKey<String>('growth_campaign_schedule_button');
  static const growthCampaignCreateSubmitButton =
      ValueKey<String>('growth_campaign_create_submit_button');
  static const growthInquiryParentField =
      ValueKey<String>('growth_inquiry_parent_field');
  static const growthInquirySourceField =
      ValueKey<String>('growth_inquiry_source_field');
  static const growthInquiryGradeField =
      ValueKey<String>('growth_inquiry_grade_field');
  static const growthInquiryCreateSubmitButton =
      ValueKey<String>('growth_inquiry_create_submit_button');

  static ValueKey<String> growthCampaignRow(String campaignId) =>
      ValueKey<String>('growth_campaign_row_$campaignId');
  static ValueKey<String> growthPauseCampaignButton(String campaignId) =>
      ValueKey<String>('growth_pause_campaign_button_$campaignId');
  static ValueKey<String> growthActivateCampaignButton(String campaignId) =>
      ValueKey<String>('growth_activate_campaign_button_$campaignId');
  static ValueKey<String> growthInquiryRow(String inquiryId) =>
      ValueKey<String>('growth_inquiry_row_$inquiryId');
  static ValueKey<String> growthConvertInquiryButton(String inquiryId) =>
      ValueKey<String>('growth_convert_inquiry_button_$inquiryId');

  static ValueKey<String> timetableOptimizationApplyButton(
    String recommendationId,
  ) =>
      ValueKey<String>('timetable_optimization_apply_$recommendationId');

  static String normalizeSubNavLabel(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  static ValueKey<String> moduleSubNavTab(String module, String tabLabel) =>
      ValueKey<String>(
        'erp_subnav_${module}_${normalizeSubNavLabel(tabLabel)}',
      );

  static ValueKey<String> qaPersonaButton(String label) =>
      ValueKey<String>('qa_persona_$label');
}
