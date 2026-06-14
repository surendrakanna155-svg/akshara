import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

void main() {
  test('QaTestKeys persona keys are stable per enum name', () {
    for (final persona in QaLoginPersona.values) {
      expect(
        QaTestKeys.qaPersonaButton(persona.name).value,
        'qa_persona_${persona.name}',
      );
    }
  });

  test('auth flow keys are non-empty strings', () {
    expect(QaTestKeys.loginPhoneField.value, 'login_phone_field');
    expect(QaTestKeys.otpField.value, 'otp_verification_field');
    expect(QaTestKeys.logoutButton.value, 'auth_logout_button');
  });

  test('admissions E2E journey keys are stable', () {
    expect(QaTestKeys.admissionsCreateLeadButton.value, 'admissions_create_lead_button');
    expect(QaTestKeys.enrollmentSubmitButton.value, 'enrollment_submit_button');
    expect(QaTestKeys.sisConvertEnrollmentButton.value, 'sis_convert_enrollment_button');
    expect(
      QaTestKeys.sisRegistryStudentRow('Patrol E2E Student').value,
      'sis_registry_student_patrol_e2e_student',
    );
    expect(
      QaTestKeys.admissionsApprovalQueueRow('Patrol E2E Student').value,
      'admissions_approval_row_patrol_e2e_student',
    );
    expect(
      QaTestKeys.financeHandoffQueueRow('Ananya Reddy').value,
      'finance_handoff_row_ananya_reddy',
    );
    expect(QaTestKeys.financeAssignFeePlanButton.value, 'finance_assign_fee_plan_button');
    expect(QaTestKeys.financeLastInvoiceIdField.value, 'finance_last_invoice_id');
    expect(
      QaTestKeys.teacherAttendanceSubmittedBanner.value,
      'teacher_attendance_submitted_banner',
    );
  });

  test('Phase 1 completion workflow keys are stable', () {
    expect(QaTestKeys.hrProcessPayrollButton.value, 'hr_process_payroll_button');
    expect(QaTestKeys.hrPayrollProcessedSnackbar.value, 'hr_payroll_processed_snackbar');
    expect(QaTestKeys.inventoryRecordLifecycleButton.value, 'inventory_record_lifecycle_button');
    expect(QaTestKeys.inventoryLifecycleSuccessSnackbar.value, 'inventory_lifecycle_success_snackbar');
    expect(
      QaTestKeys.transportActivateRouteButton('route_15').value,
      'transport_activate_route_button_route_15',
    );
    expect(
      QaTestKeys.educationReportRemarksTab.value,
      'education_report_remarks_tab',
    );
    expect(QaTestKeys.transportRouteActivatedSnackbar.value, 'transport_route_activated_snackbar');
    expect(QaTestKeys.educationPublishRemarkButton.value, 'education_publish_remark_button');
    expect(QaTestKeys.educationRemarkPublishedSnackbar.value, 'education_remark_published_snackbar');
    expect(QaTestKeys.hrPayrollExportPdfButton.value, 'hr_payroll_export_pdf_button');
    expect(QaTestKeys.inventoryReportExportPdfButton.value, 'inventory_report_export_pdf_button');
    expect(QaTestKeys.transportReportExportPdfButton.value, 'transport_report_export_pdf_button');
    expect(QaTestKeys.educationReportCardExportButton.value, 'education_report_card_export_button');
    expect(
      QaTestKeys.inventoryPoReceiveHandoffButton('po_1').value,
      'inventory_po_receive_handoff_button_po_1',
    );
    expect(
      QaTestKeys.inventoryPoReceiveHandoffSuccessSnackbar.value,
      'inventory_po_receive_handoff_success_snackbar',
    );
  });

  test('HR employee CRUD keys are stable', () {
    expect(QaTestKeys.hrCreateEmployeeButton.value, 'hr_create_employee_button');
    expect(
      QaTestKeys.hrCreateEmployeeDialogSubmitButton.value,
      'hr_create_employee_dialog_submit_button',
    );
    expect(
      QaTestKeys.hrEmployeeCreatedSnackbar.value,
      'hr_employee_created_snackbar',
    );
    expect(
      QaTestKeys.hrEditEmployeeButton('HR-EMP-102').value,
      'hr_edit_employee_button_HR-EMP-102',
    );
    expect(
      QaTestKeys.hrDeactivateEmployeeButton('HR-EMP-102').value,
      'hr_deactivate_employee_button_HR-EMP-102',
    );
    expect(
      QaTestKeys.hrEmployeeStatusSuccessSnackbar.value,
      'hr_employee_status_success_snackbar',
    );
  });

  test('Transport allocation keys are stable', () {
    expect(
      QaTestKeys.transportAssignStudentButton('alloc_5').value,
      'transport_assign_student_button_alloc_5',
    );
    expect(
      QaTestKeys.transportAssignSuccessSnackbar.value,
      'transport_assign_success_snackbar',
    );
    expect(
      QaTestKeys.transportTransferStudentButton('alloc_5').value,
      'transport_transfer_student_button_alloc_5',
    );
    expect(
      QaTestKeys.transportRemoveSuccessSnackbar.value,
      'transport_remove_success_snackbar',
    );
  });
}
