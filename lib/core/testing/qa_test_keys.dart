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
  static const receiptHistoryButton = ValueKey<String>('receipt_history_button');
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

  static ValueKey<String> sisRegistryStudentRow(String studentName) =>
      ValueKey<String>(
        'sis_registry_student_${normalizeSubNavLabel(studentName)}',
      );

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

  static ValueKey<String> financeCollectionReceiptRow(String receiptNumber) =>
      ValueKey<String>(
        'finance_collection_receipt_${normalizeSubNavLabel(receiptNumber)}',
      );

  static const financeReceiptSearchField =
      ValueKey<String>('finance_receipt_search_field');

  static const financeLastInvoiceIdField =
      ValueKey<String>('finance_last_invoice_id');

  static const financeReportExportPdfButton =
      ValueKey<String>('finance_report_export_pdf_button');

  static const financeReportExportSuccessSnackbar =
      ValueKey<String>('finance_report_export_success_snackbar');

  static const hrCreateLeaveButton = ValueKey<String>('hr_create_leave_button');

  static const hrLeaveSuccessSnackbar =
      ValueKey<String>('hr_leave_success_snackbar');

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

  static String normalizeSubNavLabel(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  static ValueKey<String> moduleSubNavTab(String module, String tabLabel) =>
      ValueKey<String>(
        'erp_subnav_${module}_${normalizeSubNavLabel(tabLabel)}',
      );

  static ValueKey<String> qaPersonaButton(String label) =>
      ValueKey<String>('qa_persona_$label');
}
