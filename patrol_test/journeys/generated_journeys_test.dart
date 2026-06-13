// GENERATED — do not edit by hand. Run: python3 scripts/qa/generate_patrol_journeys.py
import 'package:patrol/patrol.dart';

import 'package:akshara_erp/features/auth/qa_login_persona.dart';

import '../helpers/patrol_app.dart';
import '../helpers/patrol_helpers.dart';

void main() {
  patrolTest(
    'journey: erp admissions dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.superAdmin);
      await assertVisibleText($, 'Total Leads', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_admissions_dashboard', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp admissions leads',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Admissions');
      await assertVisibleText($, 'Leads', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_admissions_leads', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp admissions enrollment',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Admissions');
      await assertVisibleText($, 'Enrollment', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_admissions_enrollment', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp admissions reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.principal, 'Admissions');
      await assertVisibleText($, 'Reports', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_admissions_reports', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp admissions approval',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.principal, 'Admissions');
      await assertVisibleText($, 'Approval', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_admissions_approval', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp finance dashboard',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await assertVisibleText($, 'Fee Collected (MTD)', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_finance_dashboard', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp finance collections',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.finance, 'Finance');
      await assertVisibleText($, 'Collections', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_finance_collections', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp finance defaulters',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.finance, 'Finance');
      await assertVisibleText($, 'Defaulters', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_finance_defaulters', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp finance structures',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.finance, 'Finance');
      await assertVisibleText($, 'Fee Structures', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_finance_structures', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp finance reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.finance, 'Finance');
      await assertVisibleText($, 'Reports', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_finance_reports', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp finance refunds',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.finance, 'Finance');
      await assertVisibleText($, 'Refunds', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_finance_refunds', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp finance receipt verify',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.finance, 'Finance');
      await assertVisibleText($, 'Receipt', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_finance_receipt_verify', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp fee collect',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.finance, 'Finance');
      await assertVisibleText($, 'Collect', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_fee_collect', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp fee generate',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.finance, 'Finance');
      await assertVisibleText($, 'Generate', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_fee_generate', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp hr employees',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'HR');
      await assertVisibleText($, 'Employees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_hr_employees', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp hr attendance',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'HR');
      await assertVisibleText($, 'Attendance', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_hr_attendance', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp hr payroll',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'HR');
      await assertVisibleText($, 'Payroll', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_hr_payroll', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp hr create teacher nav',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'HR');
      await assertVisibleText($, 'Employees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_hr_create_teacher_nav', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp hr settings',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'HR');
      await assertVisibleText($, 'HR', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_hr_settings', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp sis students',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'SIS');
      await assertVisibleText($, 'Students', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_sis_students', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp sis onboarding',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'SIS');
      await assertVisibleText($, 'Students', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_sis_onboarding', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp sis student edit',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'SIS');
      await assertVisibleText($, 'Students', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_sis_student_edit', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp student promote nav',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'SIS');
      await assertVisibleText($, 'Students', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_student_promote_nav', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp school creation nav',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Management');
      await assertVisibleText($, 'School', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_school_creation_nav', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp inventory assets',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.inventory);
      await assertVisibleText($, 'Total Assets', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_inventory_assets', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp inventory distribution',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.inventory, 'Inventory');
      await assertVisibleText($, 'Distribution', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_inventory_distribution', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp inventory maintenance',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.inventory, 'Inventory');
      await assertVisibleText($, 'Maintenance', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_inventory_maintenance', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp management analytics',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await assertVisibleText($, 'Principal overview', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_management_analytics', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp management settings',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.principal, 'Management');
      await assertVisibleText($, 'Settings', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_management_settings', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp management tasks',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.principal, 'Management');
      await assertVisibleText($, 'Tasks', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_management_tasks', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp control center',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Management');
      await assertVisibleText($, 'Control', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_control_center', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp principal mgmt',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await assertVisibleText($, 'Principal overview', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_principal_mgmt', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp communications mgmt',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Management');
      await assertVisibleText($, 'Communication', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_communications_mgmt', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp exam reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Education');
      await assertVisibleText($, 'Exam', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_exam_reports', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp homework intel',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Education');
      await assertVisibleText($, 'Homework', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_homework_intel', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp timetable mgmt',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Education');
      await assertVisibleText($, 'Timetable', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_timetable_mgmt', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp transport routes',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Transport');
      await assertVisibleText($, 'Routes', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_transport_routes', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp hostel rooms',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Hostel');
      await assertVisibleText($, 'Rooms', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_hostel_rooms', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp library catalog',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Library');
      await assertVisibleText($, 'Catalog', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_library_catalog', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: erp alumni registry',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Management');
      await assertVisibleText($, 'Alumni', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_erp_alumni_registry', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: teacher home',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_teacher_home', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: teacher attendance mark',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_teacher_attendance_mark', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: teacher attendance submit',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_teacher_attendance_submit', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: teacher homework queue',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_teacher_homework_queue', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: teacher homework review',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_teacher_homework_review', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: teacher exams',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_teacher_exams', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: teacher timetable',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_teacher_timetable', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: teacher messages',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_teacher_messages', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: teacher leave',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_teacher_leave', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: teacher settings',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_teacher_settings', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: parent home refresh',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_parent_home_refresh', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: parent fees tab',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_parent_fees_tab', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: parent homework',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_parent_homework', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: parent attendance detail',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_parent_attendance_detail', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: parent notices',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_parent_notices', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: parent events',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_parent_events', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: parent profile',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_parent_profile', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: parent timetable',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_parent_timetable', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: parent pay fee',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_parent_pay_fee', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: parent receipts',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.parent);
      await assertVisibleText($, 'Fees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_parent_receipts', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: student home',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertVisibleText($, 'Home', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_student_home', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: student attendance',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertVisibleText($, 'Home', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_student_attendance', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: student homework due',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertVisibleText($, 'Home', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_student_homework_due', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: student exam schedule',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertVisibleText($, 'Home', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_student_exam_schedule', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: student notices',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertVisibleText($, 'Home', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_student_notices', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: student profile',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertVisibleText($, 'Home', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_student_profile', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: student settings',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertVisibleText($, 'Home', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_student_settings', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: student timetable day',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.student);
      await assertVisibleText($, 'Home', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_student_timetable_day', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow school creation',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Management');
      await assertVisibleText($, 'School', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_school_creation', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow teacher creation',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'HR');
      await assertVisibleText($, 'Employees', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_teacher_creation', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow student creation',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'SIS');
      await assertVisibleText($, 'Students', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_student_creation', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow parent creation',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'SIS');
      await assertVisibleText($, 'Students', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_parent_creation', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow attendance',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_attendance', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow homework',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.teacher);
      await assertVisibleText($, "Today's Classes", timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_homework', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow fees',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.finance);
      await assertVisibleText($, 'Fee Collected (MTD)', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_fees', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow inventory',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.inventory);
      await assertVisibleText($, 'Total Assets', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_inventory', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow exams',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Education');
      await assertVisibleText($, 'Exam', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_exams', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow reports',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.finance, 'Finance');
      await assertVisibleText($, 'Reports', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_reports', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow timetable',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Education');
      await assertVisibleText($, 'Timetable', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_timetable', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow communications',
    config: aksharaPatrolConfig(),
    ($) async {
      await openErpModule($, QaLoginPersona.superAdmin, 'Management');
      await assertVisibleText($, 'Communication', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_communications', subdir: 'journeys');
    },
  );

  patrolTest(
    'journey: workflow analytics',
    config: aksharaPatrolConfig(),
    ($) async {
      await bootstrapAndLogin($, QaLoginPersona.principal);
      await assertVisibleText($, 'Principal overview', timeout: const Duration(seconds: 25));
      await capturePatrolScreenshot($, 'journey_workflow_analytics', subdir: 'journeys');
    },
  );

}
