import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW2 Batch 3 — School Admin (single-school) module-write authorization.
///
/// QA-J-040 (section/performance balance commit), QA-J-041 (convert lead → SIS
/// student + create login), QA-J-042 (transfer/TC a student), QA-J-043 (AI
/// school-builder pre-fill → save), QA-J-044 (assign subjects → class teachers →
/// timetable). The commit/persistence paths exist (sis_academic_operations,
/// admissions_e2e_journey, timetable_optimization_apply, organization_builder);
/// the QW2 gap is proving the SCOPED schoolAdmin — broadest single-school role
/// but Control-Center-denied — is authorized for each, deterministically.
Permission _gate(String module, String mutationId) =>
    MutationPermissionRegistry.forModule(module)
        .firstWhere((e) => e.mutationId == mutationId)
        .permission;

void main() {
  final admin = UserPermissions.forRole(ErpRole.schoolAdmin);

  group('QW2 · school admin write authorization', () {
    test('QA-J-040 · authorized for SIS section/year operations (manageSis)', () {
      // Section/performance balance + reshuffle + year transition all gate on
      // manageSis — the SIS write permission the schoolAdmin carries.
      expect(_gate('sis', 'executeReshufflePlan'), Permission.manageSis);
      expect(_gate('sis', 'executeYearTransition'), Permission.manageSis);
      expect(admin.has(Permission.manageSis), isTrue);
    });

    test('QA-J-041 · authorized to register a converted lead as a SIS student '
        '(registerStudent → manageSis)', () {
      expect(_gate('sis', 'registerStudent'), Permission.manageSis);
      expect(admin.has(_gate('sis', 'registerStudent')), isTrue);
    });

    test('QA-J-042 · authorized to transfer / update a student (updateStudent → '
        'manageSis)', () {
      expect(_gate('sis', 'updateStudent'), Permission.manageSis);
      expect(admin.has(_gate('sis', 'updateStudent')), isTrue);
    });

    test('QA-J-043 · authorized for AI school-builder pre-fill/save '
        '(organization-builder save → manageOrganizationBuilder) + discovery', () {
      expect(_gate('organization_builder', 'saveInterviewStep'),
          Permission.manageOrganizationBuilder);
      expect(admin.has(_gate('organization_builder', 'saveInterviewStep')), isTrue);
      expect(admin.has(Permission.viewSchoolSetup), isTrue);
    });

    test('QA-J-044 · authorized for subjects → class teachers → timetable '
        '(manageSubjects/Assignments + manageAcademicTimetable)', () {
      expect(_gate('school_completion', 'reassignTeacher'),
          Permission.manageAcademicTimetable);
      expect(_gate('school_completion', 'applyTimetableOptimization'),
          Permission.manageAcademicTimetable);
      expect(admin.has(Permission.manageSubjects), isTrue);
      expect(admin.has(Permission.manageSubjectAssignments), isTrue);
      expect(admin.has(Permission.manageAcademicTimetable), isTrue);
    });

    test('school admin stays scoped — broad single-school reach but NOT the '
        'platform Control-Center', () {
      expect(admin.has(Permission.viewControlCenter), isFalse);
      expect(admin.has(Permission.manageControlCenter), isFalse);
    });
  });
}
