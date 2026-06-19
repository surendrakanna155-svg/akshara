import 'package:flutter/foundation.dart';

/// Stable widget keys for Patrol / integration tests (QA builds only).
abstract final class QaTestKeys {
  static const splash = ValueKey<String>('qa_splash_screen');
  static const qaLoginScreen = ValueKey<String>('qa_login_screen');
  static const qaPersonaSwitcherBar = ValueKey<String>('qa_persona_switcher_bar');
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
  static const sisRegistryExportButton =
      ValueKey<String>('sis_registry_export_button');
  static const sisRegistryExportSuccessSnackbar =
      ValueKey<String>('sis_registry_export_success_snackbar');

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

  static ValueKey<String> sisOpenStudent360Button(String studentId) =>
      ValueKey<String>('sis_open_student_360_$studentId');

  static const financeCreateRefundButton =
      ValueKey<String>('finance_create_refund_button');
  static const financeCreateRefundSubmitButton =
      ValueKey<String>('finance_create_refund_submit_button');
  static const financeRefundCreatedSnackbar =
      ValueKey<String>('finance_refund_created_snackbar');

  static const examAdminCreateButton =
      ValueKey<String>('exam_admin_create_button');
  static const examAdminCreateSubmitButton =
      ValueKey<String>('exam_admin_create_submit_button');
  static ValueKey<String> examAdminScheduleButton(String examId) =>
      ValueKey<String>('exam_admin_schedule_$examId');
  static ValueKey<String> examAdminOpenMarksButton(String examId) =>
      ValueKey<String>('exam_admin_open_marks_$examId');
  static ValueKey<String> examAdminEnterMarksButton(String examId) =>
      ValueKey<String>('exam_admin_enter_marks_$examId');
  static ValueKey<String> examAdminProcessResultsButton(String examId) =>
      ValueKey<String>('exam_admin_process_results_$examId');
  static ValueKey<String> examAdminSubmitApprovalButton(String examId) =>
      ValueKey<String>('exam_admin_submit_approval_$examId');
  static ValueKey<String> examAdminVerifyCoordinatorButton(String examId) =>
      ValueKey<String>('exam_admin_verify_coordinator_$examId');
  static ValueKey<String> examAdminApprovalStatusChip(String examId) =>
      ValueKey<String>('exam_admin_approval_status_$examId');
  static ValueKey<String> examAdminMarkField(String markId) =>
      ValueKey<String>('exam_admin_mark_field_$markId');
  static ValueKey<String> examAdminMarkSaveButton(String markId) =>
      ValueKey<String>('exam_admin_mark_save_$markId');

  static const financeAssignConcessionButton =
      ValueKey<String>('finance_assign_concession_button');
  static const financeAssignConcessionSubmitButton =
      ValueKey<String>('finance_assign_concession_submit_button');
  static const financeAssignConcessionSuccessSnackbar =
      ValueKey<String>('finance_assign_concession_success_snackbar');
  static const financeCreateFeeStructureSubmitButton =
      ValueKey<String>('finance_create_fee_structure_submit_button');

  static const teacherAttendanceCorrectionButton =
      ValueKey<String>('teacher_attendance_correction_button');
  static const teacherAttendanceCorrectionSubmitButton =
      ValueKey<String>('teacher_attendance_correction_submit_button');

  static ValueKey<String> teacherExamMarkField(String markId) =>
      ValueKey<String>('teacher_exam_mark_field_$markId');
  static ValueKey<String> teacherExamMarkSaveButton(String markId) =>
      ValueKey<String>('teacher_exam_mark_save_$markId');
  static const teacherExamSelector =
      ValueKey<String>('teacher_exam_selector');
  static ValueKey<String> classTeacherLeaveApprove(String id) =>
      ValueKey<String>('class_teacher_leave_approve_$id');
  static ValueKey<String> classTeacherLeaveReject(String id) =>
      ValueKey<String>('class_teacher_leave_reject_$id');
  static const parentReportCardButton =
      ValueKey<String>('parent_report_card_button');
  static const studentReportCardButton =
      ValueKey<String>('student_report_card_button');
  static const reportCardRankChip =
      ValueKey<String>('report_card_rank_chip');
  static const reportCardRemark =
      ValueKey<String>('report_card_remark');
  static const reportCardShareButton =
      ValueKey<String>('report_card_share_button');
  static const teacherExamRemarkField =
      ValueKey<String>('teacher_exam_remark_field');
  static const teacherExamRemarkSaveButton =
      ValueKey<String>('teacher_exam_remark_save_button');
  static ValueKey<String> teacherExamRemarkButton(String markId) =>
      ValueKey<String>('teacher_exam_remark_$markId');

  static const parentAttendanceCorrectionButton =
      ValueKey<String>('parent_attendance_correction_button');
  static const parentAttendanceCorrectionSubmitButton =
      ValueKey<String>('parent_attendance_correction_submit_button');
  static const parentAttendanceCorrectionSuccessSnackbar =
      ValueKey<String>('parent_attendance_correction_success_snackbar');

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

  static const approvalCenterScreen =
      ValueKey<String>('approval_center_screen');

  static ValueKey<String> approvalApproveButton(String approvalId) =>
      ValueKey<String>('approval_approve_$approvalId');

  static ValueKey<String> approvalRejectButton(String approvalId) =>
      ValueKey<String>('approval_reject_$approvalId');

  /// Teacher exam submit for approval (M-D3).
  static const examSubmitApprovalButton =
      ValueKey<String>('exam_submit_approval_button');

  /// Teacher exam submit for coordinator verification (M-A5).
  static const examSubmitVerificationButton =
      ValueKey<String>('exam_submit_verification_button');

  /// Student 360 tab bar (Phase C).
  static const student360TabBar = ValueKey<String>('student_360_tab_bar');
  static const student360ExportButton =
      ValueKey<String>('student_360_export_button');
  static const student360ExportSuccessSnackbar =
      ValueKey<String>('student_360_export_success_snackbar');
  static ValueKey<String> examMarksExportButton(String examId) =>
      ValueKey<String>('exam_marks_export_$examId');

  /// Finance audit register export (Phase E).
  static const financeAuditRegisterExportButton =
      ValueKey<String>('finance_audit_register_export_button');

  static const financeReportExportExcelButton =
      ValueKey<String>('finance_report_export_excel_button');

  /// Principal approves exam results in approval center (M-D3).
  static ValueKey<String> examPrincipalApproveButton(String approvalId) =>
      ValueKey<String>('exam_principal_approve_$approvalId');

  static const approvalTypeFilterAcademic =
      ValueKey<String>('approval_type_filter_academic');

  static const approvalTypeFilterAttendance =
      ValueKey<String>('approval_type_filter_attendance');

  static const approvalTypeFilterLeave =
      ValueKey<String>('approval_type_filter_leave');

  static const approvalTypeFilterFinance =
      ValueKey<String>('approval_type_filter_finance');

  static const approvalTypeFilterInventory =
      ValueKey<String>('approval_type_filter_inventory');

  static const openApprovalCenterButton =
      ValueKey<String>('open_approval_center_button');

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

  static const universalAiAssistantStreamingToggle =
      ValueKey<String>('universal_ai_assistant_streaming_toggle');

  static const universalAiAssistantLoadingIndicator =
      ValueKey<String>('universal_ai_assistant_loading_indicator');

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
  static const trustIntelligenceScreen =
      ValueKey<String>('trust_intelligence_screen');
  static ValueKey<String> trustRecommendationCard(String id) =>
      ValueKey<String>('trust_recommendation_$id');
  static const branchScreen = ValueKey<String>('branch_screen');
  static const branchAssignSchoolButton =
      ValueKey<String>('branch_assign_school_button');
  static const branchAssignmentSnackbar =
      ValueKey<String>('branch_assignment_snackbar');
  static const franchiseScreen = ValueKey<String>('franchise_screen');
  static const franchiseUpdatedSnackbar =
      ValueKey<String>('franchise_updated_snackbar');

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
  static const resourceOptimizationAppliedSnackbar =
      ValueKey<String>('resource_optimization_applied_snackbar');
  static const resourceOptimizationDismissedSnackbar =
      ValueKey<String>('resource_optimization_dismissed_snackbar');
  static const aiContentTypePicker = ValueKey<String>('ai_content_type_picker');
  static const aiContentPromptField =
      ValueKey<String>('ai_content_prompt_field');
  static const aiContentAudienceField =
      ValueKey<String>('ai_content_audience_field');
  static const aiContentToneField = ValueKey<String>('ai_content_tone_field');
  static const aiContentConstraintsField =
      ValueKey<String>('ai_content_constraints_field');
  static const aiContentGenerateButton =
      ValueKey<String>('ai_content_generate_button');
  static const aiContentGeneratedCard =
      ValueKey<String>('ai_content_generated_card');
  static const aiContentGeneratedSnackbar =
      ValueKey<String>('ai_content_generated_snackbar');
  static const aiContentCopyButton = ValueKey<String>('ai_content_copy_button');
  static const aiContentShareButton =
      ValueKey<String>('ai_content_share_button');
  static const aiContentCopiedSnackbar =
      ValueKey<String>('ai_content_copied_snackbar');
  static const aiContentSharedSnackbar =
      ValueKey<String>('ai_content_shared_snackbar');
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

  static ValueKey<String> resourceOptimizationTab(String domain) =>
      ValueKey<String>('resource_optimization_tab_$domain');

  static ValueKey<String> resourceOptimizationApplyButton(
    String recommendationId,
  ) =>
      ValueKey<String>('resource_optimization_apply_$recommendationId');

  static ValueKey<String> resourceOptimizationDismissButton(
    String recommendationId,
  ) =>
      ValueKey<String>('resource_optimization_dismiss_$recommendationId');

  static const parentMeetingsScreen =
      ValueKey<String>('parent_meetings_screen');
  static const parentMeetingsCreateButton =
      ValueKey<String>('parent_meetings_create_button');
  static const parentMeetingsStudentIdField =
      ValueKey<String>('parent_meetings_student_id_field');
  static const parentMeetingsStudentNameField =
      ValueKey<String>('parent_meetings_student_name_field');
  static const parentMeetingsParentNameField =
      ValueKey<String>('parent_meetings_parent_name_field');
  static const parentMeetingsTeacherNameField =
      ValueKey<String>('parent_meetings_teacher_name_field');
  static const parentMeetingsCreateSubmitButton =
      ValueKey<String>('parent_meetings_create_submit_button');
  static const parentMeetingsNotesField =
      ValueKey<String>('parent_meetings_notes_field');
  static const parentMeetingsSaveNotesButton =
      ValueKey<String>('parent_meetings_save_notes_button');
  static const parentMeetingsGenerateSummaryButton =
      ValueKey<String>('parent_meetings_generate_summary_button');
  static const parentMeetingsScheduleFollowUpButton =
      ValueKey<String>('parent_meetings_schedule_follow_up_button');

  static ValueKey<String> parentMeetingTile(String meetingId) =>
      ValueKey<String>('parent_meeting_tile_$meetingId');

  // --- Red Team remediation (parent/student mobile + admin security) ---
  static const parentDashboardScreen =
      ValueKey<String>('parent_dashboard_screen');
  static ValueKey<String> parentDashboardQuickAction(String actionId) =>
      ValueKey<String>('parent_dashboard_qa_$actionId');
  static ValueKey<String> parentDashboardNotice(String noticeId) =>
      ValueKey<String>('parent_dashboard_notice_$noticeId');
  static const parentNoticeCarousel =
      ValueKey<String>('parent_notice_carousel');

  static const parentTransportScreen =
      ValueKey<String>('parent_transport_screen');
  static const parentPtmScreen = ValueKey<String>('parent_ptm_screen');

  static const studentDashboardScreen =
      ValueKey<String>('student_dashboard_screen');
  static ValueKey<String> studentDashboardQuickAction(String actionId) =>
      ValueKey<String>('student_dashboard_qa_$actionId');

  static const studentReportCardScreen =
      ValueKey<String>('student_report_card_screen');
  static const studentProgressScreen =
      ValueKey<String>('student_progress_screen');

  static const adminHubScreen = ValueKey<String>('admin_hub_screen');
  static ValueKey<String> adminHubModuleCard(String moduleLabel) =>
      ValueKey<String>(
        'admin_hub_module_${normalizeSubNavLabel(moduleLabel)}',
      );

  static const accessDeniedScreen =
      ValueKey<String>('access_denied_screen');

  static ValueKey<String> parentMeetingActionToggle(String actionId) =>
      ValueKey<String>('parent_meeting_action_toggle_$actionId');

  static const directorDashboardScreen =
      ValueKey<String>('director_dashboard_screen');
  static const directorCopilotLinkButton =
      ValueKey<String>('director_copilot_link_button');
  static const directorReportsGenerateSummaryButton =
      ValueKey<String>('director_reports_generate_summary_button');
  static const directorExecutiveSummaryCard =
      ValueKey<String>('director_executive_summary_card');
  static const directorReportExportedSnackbar =
      ValueKey<String>('director_report_exported_snackbar');
  static const directorComplianceAcknowledgedSnackbar =
      ValueKey<String>('director_compliance_acknowledged_snackbar');

  static ValueKey<String> directorComplianceAcknowledgeButton(
    String complianceId,
  ) =>
      ValueKey<String>('director_compliance_ack_$complianceId');

  static ValueKey<String> directorReportExportButton(String reportId) =>
      ValueKey<String>('director_report_export_$reportId');

  static ValueKey<String> branchTile(String branchId) =>
      ValueKey<String>('branch_tile_$branchId');

  static ValueKey<String> branchAssignmentTile(String assignmentId) =>
      ValueKey<String>('branch_assignment_tile_$assignmentId');

  static ValueKey<String> franchiseTile(String franchiseId) =>
      ValueKey<String>('franchise_tile_$franchiseId');

  static ValueKey<String> franchiseImproveButton(String franchiseId) =>
      ValueKey<String>('franchise_improve_button_$franchiseId');

  static const multiSchoolPortfolioScreen =
      ValueKey<String>('multi_school_portfolio_screen');
  static const multiSchoolOnboardingCta =
      ValueKey<String>('multi_school_onboarding_cta');
  static const multiSchoolAlertDismissedSnackbar =
      ValueKey<String>('multi_school_alert_dismissed_snackbar');
  static const multiSchoolActivationSnackbar =
      ValueKey<String>('multi_school_activation_snackbar');
  static const multiSchoolDeactivationSnackbar =
      ValueKey<String>('multi_school_deactivation_snackbar');

  static ValueKey<String> multiSchoolAlertCard(String alertId) =>
      ValueKey<String>('multi_school_alert_$alertId');
  static ValueKey<String> multiSchoolDismissAlertButton(String alertId) =>
      ValueKey<String>('multi_school_dismiss_alert_$alertId');
  static ValueKey<String> multiSchoolSchoolRow(String schoolId) =>
      ValueKey<String>('multi_school_school_row_$schoolId');
  static ValueKey<String> multiSchoolActivateSchoolButton(String schoolId) =>
      ValueKey<String>('multi_school_activate_school_$schoolId');
  static ValueKey<String> multiSchoolDeactivateSchoolButton(String schoolId) =>
      ValueKey<String>('multi_school_deactivate_school_$schoolId');
  static ValueKey<String> multiSchoolHealthChip(int score) =>
      ValueKey<String>('multi_school_health_chip_$score');

  static const multiSchoolOnboardingWizardScreen =
      ValueKey<String>('multi_school_onboarding_wizard_screen');
  static const multiSchoolOnboardingSchoolNameField =
      ValueKey<String>('multi_school_onboarding_school_name_field');
  static const multiSchoolOnboardingContactNameField =
      ValueKey<String>('multi_school_onboarding_contact_name_field');
  static const multiSchoolOnboardingContactEmailField =
      ValueKey<String>('multi_school_onboarding_contact_email_field');
  static const multiSchoolOnboardingPlanField =
      ValueKey<String>('multi_school_onboarding_plan_field');
  static const multiSchoolOnboardingCountryField =
      ValueKey<String>('multi_school_onboarding_country_field');
  static const multiSchoolOnboardingCapacityField =
      ValueKey<String>('multi_school_onboarding_capacity_field');
  static const multiSchoolOnboardingActivateSwitch =
      ValueKey<String>('multi_school_onboarding_activate_switch');
  static const multiSchoolOnboardingSubmitButton =
      ValueKey<String>('multi_school_onboarding_submit_button');
  static const multiSchoolOnboardingContinueButton =
      ValueKey<String>('multi_school_onboarding_continue_button');
  static const multiSchoolOnboardingCompletedSnackbar =
      ValueKey<String>('multi_school_onboarding_completed_snackbar');

  // Unified startup onboarding (/admin/onboarding/unified)
  static const unifiedOnboardingScreen =
      ValueKey<String>('unified_onboarding_screen');
  static const unifiedOnboardingSchoolNameField =
      ValueKey<String>('unified_onboarding_school_name');
  static const unifiedOnboardingAddressField =
      ValueKey<String>('unified_onboarding_address');
  static const unifiedOnboardingContactPhoneField =
      ValueKey<String>('unified_onboarding_contact_phone');
  static const unifiedOnboardingContactEmailField =
      ValueKey<String>('unified_onboarding_contact_email');
  static const unifiedOnboardingContinueButton =
      ValueKey<String>('unified_onboarding_continue');
  static const unifiedOnboardingGoLiveButton =
      ValueKey<String>('unified_onboarding_go_live');
  static const unifiedOnboardingGoLiveSuccess =
      ValueKey<String>('unified_onboarding_go_live_success');
  static const unifiedOnboardingProvisionSummary =
      ValueKey<String>('unified_onboarding_provision_summary');

  static const organizationBuilderHubScreen =
      ValueKey<String>('organization_builder_hub_screen');
  static const organizationBuilderInterviewScreen =
      ValueKey<String>('organization_builder_interview_screen');
  static const organizationBuilderPreviewScreen =
      ValueKey<String>('organization_builder_preview_screen');
  static const organizationBuilderProvisioningScreen =
      ValueKey<String>('organization_builder_provisioning_screen');

  // FV-PLAT-14 Smart School Configuration
  static const schoolDiscoveryScreen =
      ValueKey<String>('school_discovery_screen');
  static const schoolDiscoveryHubCard =
      ValueKey<String>('school_discovery_hub_card');
  static const schoolDiscoveryAppliedSnackbar =
      ValueKey<String>('school_discovery_applied_snackbar');
  static const schoolDiscoveryBranchCountSlider =
      ValueKey<String>('school_discovery_branch_count_slider');
  static const schoolDiscoveryCapabilityTransport =
      ValueKey<String>('school_discovery_capability_transport');
  static const schoolDiscoveryCapabilityHostel =
      ValueKey<String>('school_discovery_capability_hostel');
  static const schoolDiscoveryCapabilityLibrary =
      ValueKey<String>('school_discovery_capability_library');
  static const schoolDiscoveryCapabilityInventory =
      ValueKey<String>('school_discovery_capability_inventory');
  static const schoolDiscoveryCapabilityAlumni =
      ValueKey<String>('school_discovery_capability_alumni');
  static const schoolDiscoveryCapabilityHrPayroll =
      ValueKey<String>('school_discovery_capability_hr_payroll');
  static const schoolDiscoveryCapabilityMultiBranch =
      ValueKey<String>('school_discovery_capability_multi_branch');
  static const schoolDiscoveryCapabilityTrust =
      ValueKey<String>('school_discovery_capability_trust');
  static ValueKey<String> schoolDiscoverySchoolTypeOption(String storageKey) =>
      ValueKey<String>('school_discovery_school_type_$storageKey');
  static ValueKey<String> schoolDiscoveryCurriculumOption(String storageKey) =>
      ValueKey<String>('school_discovery_curriculum_$storageKey');
  static ValueKey<String> schoolDiscoveryOperationsOption(String storageKey) =>
      ValueKey<String>('school_discovery_operations_$storageKey');
  static const organizationBuilderSchoolSetupLink =
      ValueKey<String>('organization_builder_school_setup_link');
  static const organizationBuilderInterviewBackButton =
      ValueKey<String>('organization_builder_interview_back_button');
  static const organizationBuilderInterviewContinueButton =
      ValueKey<String>('organization_builder_interview_continue_button');
  static const organizationBuilderInterviewPreviewButton =
      ValueKey<String>('organization_builder_interview_preview_button');
  static const organizationBuilderInterviewNameField =
      ValueKey<String>('organization_builder_interview_name_field');
  static const organizationBuilderInterviewScalePrimaryField =
      ValueKey<String>('organization_builder_interview_scale_primary_field');
  static const organizationBuilderInterviewScaleSecondaryField =
      ValueKey<String>('organization_builder_interview_scale_secondary_field');
  static const organizationBuilderInterviewModulesField =
      ValueKey<String>('organization_builder_interview_modules_field');
  static const organizationBuilderInterviewWorkflowsField =
      ValueKey<String>('organization_builder_interview_workflows_field');
  static const organizationBuilderInterviewChannelsField =
      ValueKey<String>('organization_builder_interview_channels_field');
  static const organizationBuilderInterviewPaymentsField =
      ValueKey<String>('organization_builder_interview_payments_field');
  static const organizationBuilderStartProvisioningButton =
      ValueKey<String>('organization_builder_start_provisioning_button');
  static const organizationBuilderProvisioningCompleted =
      ValueKey<String>('organization_builder_provisioning_completed');

  static ValueKey<String> organizationBuilderPackCard(String packId) =>
      ValueKey<String>('organization_builder_pack_$packId');
  static ValueKey<String> organizationBuilderStartInterviewButton(
    String packId,
  ) =>
      ValueKey<String>('organization_builder_start_interview_$packId');
  static ValueKey<String> organizationBuilderDraftRow(String draftId) =>
      ValueKey<String>('organization_builder_draft_$draftId');
  static ValueKey<String> organizationBuilderRecommendation(String recId) =>
      ValueKey<String>('organization_builder_recommendation_$recId');
  static ValueKey<String> organizationBuilderPreviewModule(String moduleId) =>
      ValueKey<String>('organization_builder_preview_module_$moduleId');
  static ValueKey<String> organizationBuilderPreviewRole(String roleId) =>
      ValueKey<String>('organization_builder_preview_role_$roleId');
  static ValueKey<String> organizationBuilderPreviewWidget(String widgetId) =>
      ValueKey<String>('organization_builder_preview_widget_$widgetId');
  static ValueKey<String> organizationBuilderPreviewWorkflow(
    String workflowId,
  ) =>
      ValueKey<String>('organization_builder_preview_workflow_$workflowId');
  static ValueKey<String> organizationBuilderProvisioningStep(String stepId) =>
      ValueKey<String>('organization_builder_provisioning_step_$stepId');

  static const dynamicWidgetRegistryScreen =
      ValueKey<String>('dynamic_widget_registry_screen');
  static const dynamicWidgetLayoutEditorScreen =
      ValueKey<String>('dynamic_widget_layout_editor_screen');
  static const dynamicWidgetRuntimeScreen =
      ValueKey<String>('dynamic_widget_runtime_screen');
  static const dynamicWidgetOpenRuntimeButton =
      ValueKey<String>('dynamic_widget_open_runtime_button');
  static const dynamicWidgetOpenLayoutEditorButton =
      ValueKey<String>('dynamic_widget_open_layout_editor_button');
  static const dynamicWidgetLayoutRoleDropdown =
      ValueKey<String>('dynamic_widget_layout_role_dropdown');
  static const dynamicWidgetLayoutPackDropdown =
      ValueKey<String>('dynamic_widget_layout_pack_dropdown');
  static const dynamicWidgetSaveLayoutButton =
      ValueKey<String>('dynamic_widget_save_layout_button');
  static const dynamicWidgetResetLayoutButton =
      ValueKey<String>('dynamic_widget_reset_layout_button');
  static const dynamicWidgetRuntimeRefreshButton =
      ValueKey<String>('dynamic_widget_runtime_refresh_button');

  static ValueKey<String> dynamicWidgetCatalogItem(String widgetId) =>
      ValueKey<String>('dynamic_widget_catalog_$widgetId');
  static ValueKey<String> dynamicWidgetDataSourceItem(String key) =>
      ValueKey<String>('dynamic_widget_data_source_$key');
  static ValueKey<String> dynamicWidgetLayoutVersion(String role) =>
      ValueKey<String>('dynamic_widget_layout_version_$role');
  static ValueKey<String> dynamicWidgetLayoutItem(String widgetId) =>
      ValueKey<String>('dynamic_widget_layout_item_$widgetId');
  static ValueKey<String> dynamicWidgetLayoutMoveUp(String widgetId) =>
      ValueKey<String>('dynamic_widget_layout_move_up_$widgetId');
  static ValueKey<String> dynamicWidgetLayoutMoveDown(String widgetId) =>
      ValueKey<String>('dynamic_widget_layout_move_down_$widgetId');
  static ValueKey<String> dynamicWidgetRuntimeTile(String widgetId) =>
      ValueKey<String>('dynamic_widget_runtime_tile_$widgetId');

  static const platformOperationsHubScreen =
      ValueKey<String>('platform_operations_hub_screen');
  static const platformOperationsTabBar =
      ValueKey<String>('platform_operations_tab_bar');
  static const platformOperationsOverviewTab =
      ValueKey<String>('platform_operations_overview_tab');
  static const platformOperationsHealthTab =
      ValueKey<String>('platform_operations_health_tab');
  static const platformOperationsErrorsTab =
      ValueKey<String>('platform_operations_errors_tab');
  static const platformOperationsWorkflowsTab =
      ValueKey<String>('platform_operations_workflows_tab');
  static const platformOperationsAiTab =
      ValueKey<String>('platform_operations_ai_tab');
  static const platformOperationsAlertsTab =
      ValueKey<String>('platform_operations_alerts_tab');
  static const platformOperationsSecurityTab =
      ValueKey<String>('platform_operations_security_tab');
  static const platformOperationsTenantTab =
      ValueKey<String>('platform_operations_tenant_tab');
  static const platformOperationsReadinessTab =
      ValueKey<String>('platform_operations_readiness_tab');
  static const platformOperationsOperationsHubLink =
      ValueKey<String>('platform_operations_operations_hub_link');
  static const platformOperationsIntelligenceHubLink =
      ValueKey<String>('platform_operations_intelligence_hub_link');
  static const platformOperationsDirectorPortalLink =
      ValueKey<String>('platform_operations_director_portal_link');
  static const platformOperationsTrustIntelligenceLink =
      ValueKey<String>('platform_operations_trust_intelligence_link');
  static const platformOperationsRunTenantVerificationButton =
      ValueKey<String>('platform_operations_run_tenant_verification_button');
  static const platformOperationsAlertAcknowledgedSnackbar =
      ValueKey<String>('platform_operations_alert_acknowledged_snackbar');

  static ValueKey<String> platformOperationsAlertTile(String alertId) =>
      ValueKey<String>('platform_operations_alert_tile_$alertId');
  static ValueKey<String> platformOperationsAcknowledgeAlertButton(
    String alertId,
  ) =>
      ValueKey<String>('platform_operations_ack_alert_$alertId');
  static ValueKey<String> platformOperationsAccessReviewTile(String reviewId) =>
      ValueKey<String>('platform_operations_access_review_$reviewId');
  static ValueKey<String> platformOperationsCompleteAccessReviewButton(
    String reviewId,
  ) =>
      ValueKey<String>('platform_operations_complete_access_review_$reviewId');
  static ValueKey<String> platformOperationsReadinessCategory(
    String categoryId,
  ) =>
      ValueKey<String>('platform_operations_readiness_category_$categoryId');

  // FV-32 — Industry Framework
  static const industryHubScreen = ValueKey<String>('industry_hub_screen');
  static const industryFrameworkLink = ValueKey<String>('industry_framework_link');
  static const industryActiveLabel = ValueKey<String>('industry_active_label');
  static ValueKey<String> industryTypeChip(String value) =>
      ValueKey<String>('industry_type_chip_$value');
  static ValueKey<String> industryModuleToggle(String moduleId) =>
      ValueKey<String>('industry_module_toggle_$moduleId');
  static ValueKey<String> industryCapabilityTile(String industry) =>
      ValueKey<String>('industry_capability_$industry');

  // FV-33 — Healthcare
  static const healthcareDashboardScreen =
      ValueKey<String>('healthcare_dashboard_screen');
  static const healthcareDashboardSummary =
      ValueKey<String>('healthcare_dashboard_summary');
  static ValueKey<String> healthcareKpiTile(String id) =>
      ValueKey<String>('healthcare_kpi_$id');
  static ValueKey<String> healthcareNavLink(String route) =>
      ValueKey<String>('healthcare_nav_$route');
  static const healthcarePatientScreen =
      ValueKey<String>('healthcare_patient_screen');
  static ValueKey<String> healthcarePatientTile(String id) =>
      ValueKey<String>('healthcare_patient_$id');
  static const healthcareAppointmentScreen =
      ValueKey<String>('healthcare_appointment_screen');
  static ValueKey<String> healthcareAppointmentTile(String id) =>
      ValueKey<String>('healthcare_appointment_$id');
  static const healthcarePractitionerScreen =
      ValueKey<String>('healthcare_practitioner_screen');
  static ValueKey<String> healthcarePractitionerTile(String id) =>
      ValueKey<String>('healthcare_practitioner_$id');
  static const healthcareIntelligenceScreen =
      ValueKey<String>('healthcare_intelligence_screen');

  // FV-34 — Salon
  static const salonDashboardScreen = ValueKey<String>('salon_dashboard_screen');
  static const salonDashboardSummary = ValueKey<String>('salon_dashboard_summary');
  static ValueKey<String> salonKpiTile(String id) =>
      ValueKey<String>('salon_kpi_$id');
  static ValueKey<String> salonNavLink(String route) =>
      ValueKey<String>('salon_nav_$route');
  static const salonSalonCustomerScreen =
      ValueKey<String>('salon_customer_screen');
  static ValueKey<String> salonSalonCustomerTile(String id) =>
      ValueKey<String>('salon_customer_$id');
  static const salonSalonAppointmentScreen =
      ValueKey<String>('salon_appointment_screen');
  static ValueKey<String> salonSalonAppointmentTile(String id) =>
      ValueKey<String>('salon_appointment_$id');
  static const salonSalonServiceScreen =
      ValueKey<String>('salon_service_screen');
  static ValueKey<String> salonSalonServiceTile(String id) =>
      ValueKey<String>('salon_service_$id');
  static const salonIntelligenceScreen =
      ValueKey<String>('salon_intelligence_screen');

  // FV-35 — Restaurant
  static const restaurantDashboardScreen =
      ValueKey<String>('restaurant_dashboard_screen');
  static const restaurantDashboardSummary =
      ValueKey<String>('restaurant_dashboard_summary');
  static ValueKey<String> restaurantKpiTile(String id) =>
      ValueKey<String>('restaurant_kpi_$id');
  static ValueKey<String> restaurantNavLink(String route) =>
      ValueKey<String>('restaurant_nav_$route');
  static const restaurantRestaurantTableScreen =
      ValueKey<String>('restaurant_table_screen');
  static ValueKey<String> restaurantRestaurantTableTile(String id) =>
      ValueKey<String>('restaurant_table_$id');
  static const restaurantRestaurantOrderScreen =
      ValueKey<String>('restaurant_order_screen');
  static ValueKey<String> restaurantRestaurantOrderTile(String id) =>
      ValueKey<String>('restaurant_order_$id');
  static const restaurantKitchenTicketScreen =
      ValueKey<String>('restaurant_kitchen_screen');
  static ValueKey<String> restaurantKitchenTicketTile(String id) =>
      ValueKey<String>('restaurant_kitchen_$id');
  static const restaurantIntelligenceScreen =
      ValueKey<String>('restaurant_intelligence_screen');

  // FV-36 — Accommodation
  static const accommodationDashboardScreen =
      ValueKey<String>('accommodation_dashboard_screen');
  static const accommodationDashboardSummary =
      ValueKey<String>('accommodation_dashboard_summary');
  static ValueKey<String> accommodationKpiTile(String id) =>
      ValueKey<String>('accommodation_kpi_$id');
  static ValueKey<String> accommodationNavLink(String route) =>
      ValueKey<String>('accommodation_nav_$route');
  static const accommodationResidentScreen =
      ValueKey<String>('accommodation_resident_screen');
  static ValueKey<String> accommodationResidentTile(String id) =>
      ValueKey<String>('accommodation_resident_$id');
  static const accommodationRoomOccupancyScreen =
      ValueKey<String>('accommodation_occupancy_screen');
  static ValueKey<String> accommodationRoomOccupancyTile(String id) =>
      ValueKey<String>('accommodation_occupancy_$id');
  static const accommodationAccommodationAllocationScreen =
      ValueKey<String>('accommodation_allocation_screen');
  static ValueKey<String> accommodationAccommodationAllocationTile(String id) =>
      ValueKey<String>('accommodation_allocation_$id');
  static const accommodationIntelligenceScreen =
      ValueKey<String>('accommodation_intelligence_screen');

  // FV-PLAT-11 — White Label
  static const whiteLabelHubScreen = ValueKey<String>('white_label_hub_screen');
  static const whiteLabelActiveConfig = ValueKey<String>('white_label_active_config');
  static const whiteLabelBrandingLink = ValueKey<String>('white_label_branding_link');
  static const whiteLabelThemeLink = ValueKey<String>('white_label_theme_link');
  static const whiteLabelLogoLink = ValueKey<String>('white_label_logo_link');
  static const whiteLabelDeploymentLink =
      ValueKey<String>('white_label_deployment_link');
  static const whiteLabelBrandingScreen =
      ValueKey<String>('white_label_branding_screen');
  static ValueKey<String> whiteLabelBrandingTile(String id) =>
      ValueKey<String>('white_label_branding_$id');
  static const whiteLabelSaveBrandingButton =
      ValueKey<String>('white_label_save_branding_button');
  static const whiteLabelThemeScreen = ValueKey<String>('white_label_theme_screen');
  static ValueKey<String> whiteLabelThemeTile(String id) =>
      ValueKey<String>('white_label_theme_$id');
  static ValueKey<String> whiteLabelApplyThemeButton(String id) =>
      ValueKey<String>('white_label_apply_theme_$id');
  static const whiteLabelLogoScreen = ValueKey<String>('white_label_logo_screen');
  static ValueKey<String> whiteLabelLogoTile(String id) =>
      ValueKey<String>('white_label_logo_$id');
  static const whiteLabelUploadLogoButton =
      ValueKey<String>('white_label_upload_logo_button');
  static const whiteLabelDeploymentScreen =
      ValueKey<String>('white_label_deployment_screen');
  static ValueKey<String> whiteLabelDeploymentTile(String id) =>
      ValueKey<String>('white_label_deployment_$id');

  static String normalizeSubNavLabel(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  static ValueKey<String> moduleSubNavTab(String module, String tabLabel) =>
      ValueKey<String>(
        'erp_subnav_${module}_${normalizeSubNavLabel(tabLabel)}',
      );

  static ValueKey<String> qaPersonaButton(String label) =>
      ValueKey<String>('qa_persona_$label');
}
