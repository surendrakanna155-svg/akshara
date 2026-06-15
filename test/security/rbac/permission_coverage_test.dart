import 'package:akshara_erp/core/security/mutation_permission_registry.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mutation permission coverage', () {
    test('registry includes admissions finance and sis mutations', () {
      for (final module in ['admissions', 'finance', 'sis']) {
        expect(
          MutationPermissionRegistry.forModule(module),
          isNotEmpty,
          reason: module,
        );
      }
    });

    test('approveRefund requires approveRefunds permission', () {
      final entry = MutationPermissionRegistry.entries.firstWhere(
        (e) => e.mutationId == 'approveRefund',
      );
      expect(entry.permission, Permission.approveRefunds);
      expect(entry.kind, 'approve');
    });

    test('all entries use manage or approve permission enums', () {
      for (final entry in MutationPermissionRegistry.entries) {
        expect(
          entry.permission.name.startsWith('manage') ||
              entry.permission.name.startsWith('approve'),
          isTrue,
          reason: entry.mutationId,
        );
      }
    });

    test('Batch A inventory procurement mutations registered', () {
      for (final id in [
        'createProcurementOrder',
        'approveProcurementHandoff',
        'receiveProcurementHandoff',
      ]) {
        expect(
          MutationPermissionRegistry.entries.any((e) => e.mutationId == id),
          isTrue,
          reason: id,
        );
      }
    });

    test('Batch A admissions settings mutation registered', () {
      final entry = MutationPermissionRegistry.entries.firstWhere(
        (e) => e.mutationId == 'updateSettings' && e.moduleId == 'admissions',
      );
      expect(entry.permission, Permission.manageAdmissions);
    });

    test('Batch A communication mutations registered', () {
      for (final id in ['sendBroadcast', 'saveTemplate']) {
        final entry = MutationPermissionRegistry.entries.firstWhere(
          (e) => e.mutationId == id,
        );
        expect(entry.moduleId, 'communication');
      }
    });

    test('Batch A HR leave mutations registered', () {
      for (final id in ['approveLeaveRequest', 'rejectLeaveRequest']) {
        final entry = MutationPermissionRegistry.entries.firstWhere(
          (e) => e.mutationId == id,
        );
        expect(entry.moduleId, 'hr');
        expect(entry.permission, Permission.manageHr);
      }
    });

    test('Batch A finance receipt export mutation registered', () {
      final entry = MutationPermissionRegistry.entries.firstWhere(
        (e) => e.mutationId == 'exportReceiptPdf',
      );
      expect(entry.permission, Permission.manageFinance);
    });

    test('parent meetings mutations registered', () {
      for (final id in [
        'createMeeting',
        'saveNotes',
        'generateSummary',
        'completeAction',
        'scheduleFollowUp',
      ]) {
        final entry = MutationPermissionRegistry.entries.firstWhere(
          (e) => e.mutationId == id && e.moduleId == 'parent_meetings',
        );
        expect(entry.moduleId, 'parent_meetings');
        expect(entry.permission, Permission.manageAcademicProgress);
      }
    });

    test('school completion timetable apply mutation registered', () {
      final entry = MutationPermissionRegistry.entries.firstWhere(
        (e) => e.mutationId == 'applyTimetableOptimization',
      );
      expect(entry.moduleId, 'school_completion');
      expect(entry.permission, Permission.manageAcademicTimetable);
      expect(entry.kind, 'manage');
    });

    test('multi-school operations mutations registered', () {
      for (final id in [
        'activateSchool',
        'deactivateSchool',
        'completeOnboarding',
        'dismissAlert',
        'completeAction',
      ]) {
        final entry = MutationPermissionRegistry.entries.firstWhere(
          (e) => e.mutationId == id,
        );
        expect(entry.moduleId, 'multi_school');
        expect(entry.permission, Permission.manageMultiSchoolOperations);
        expect(entry.kind, 'manage');
      }
    });

    test('branch and franchise mutations registered', () {
      final branch = MutationPermissionRegistry.entries.firstWhere(
        (e) => e.mutationId == 'assignBranchSchool',
      );
      expect(branch.moduleId, 'branch');
      expect(branch.permission, Permission.manageBranchOperations);

      final franchise = MutationPermissionRegistry.entries.firstWhere(
        (e) => e.mutationId == 'improveFranchiseScore',
      );
      expect(franchise.moduleId, 'franchise');
      expect(franchise.permission, Permission.manageFranchiseOperations);
    });

    test('organization builder mutations registered', () {
      for (final id in [
        'saveInterviewStep',
        'generatePreview',
        'startProvisioning',
      ]) {
        final entry = MutationPermissionRegistry.entries.firstWhere(
          (e) => e.mutationId == id,
        );
        expect(entry.moduleId, 'organization_builder');
        expect(entry.permission, Permission.manageOrganizationBuilder);
        expect(entry.kind, 'manage');
      }
    });

    test('platform operations mutations registered', () {
      for (final id in [
        'acknowledgeAlert',
        'runTenantVerification',
        'completeAccessReview',
      ]) {
        final entry = MutationPermissionRegistry.entries.firstWhere(
          (e) => e.mutationId == id,
        );
        expect(entry.moduleId, 'platform_operations');
        expect(entry.permission, Permission.managePlatformOperations);
        expect(entry.kind, 'manage');
      }
    });

    test('dynamic widget mutations registered', () {
      for (final id in ['saveRoleDashboardLayout', 'resetLayoutToPackDefault']) {
        final entry = MutationPermissionRegistry.entries.firstWhere(
          (e) => e.mutationId == id,
        );
        expect(entry.moduleId, 'dynamic_widgets');
        expect(entry.permission, Permission.manageDynamicWidgets);
        expect(entry.kind, 'manage');
      }
    });

    test('director portal mutations registered', () {
      for (final id in ['acknowledgeCompliance', 'exportReport']) {
        final entry = MutationPermissionRegistry.entries.firstWhere(
          (e) => e.mutationId == id,
        );
        expect(entry.moduleId, 'director');
        expect(entry.permission, Permission.manageDirectorPortal);
      }
    });
  });
}
