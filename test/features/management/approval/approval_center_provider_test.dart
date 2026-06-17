import 'package:akshara_erp/core/approvals/approval_audit.dart';
import 'package:akshara_erp/core/approvals/approval_category.dart';
import 'package:akshara_erp/core/approvals/approval_permissions.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/errors/api_failure.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/permissions.dart';
import 'package:akshara_erp/features/auth/auth_claims.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/management/approval/approval_center_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_test_overrides.dart';
import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('Approval center providers — M-D2 certification', () {
    late ProviderContainer container;
    late MockApprovalRepository repository;

    setUp(() async {
      await initProviderTestPrefs();
      repository = MockApprovalRepository();
      container = createProviderTestContainer(
        overrides: [
          approvalRepositoryProvider.overrideWithValue(repository),
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9999999999',
              displayName: 'Principal Test',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(erpRole: ErpRole.principal),
            ),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('approval queue loads seeded demo data', () async {
      final items = await container.read(approvalCenterFutureProvider.future);
      expect(items.length, greaterThanOrEqualTo(10));
      expect(
        items.any((a) => a.title.contains('Science lab upgrade')),
        isTrue,
      );
    });

    test('status filter — pending only', () async {
      await container.read(approvalCenterFutureProvider.future);
      container.read(approvalCenterStatusFilterProvider.notifier).state = 1;
      final filtered = container.read(approvalCenterFilteredListProvider);
      expect(filtered, isNotEmpty);
      expect(filtered.every((a) => a.status == ApprovalStatus.pending), isTrue);
    });

    test('status filter — approved only', () async {
      await container.read(approvalCenterFutureProvider.future);
      container.read(approvalCenterStatusFilterProvider.notifier).state = 2;
      final filtered = container.read(approvalCenterFilteredListProvider);
      expect(filtered, isNotEmpty);
      expect(filtered.every((a) => a.status == ApprovalStatus.approved), isTrue);
      expect(
        filtered.any((a) => a.title.startsWith('Digital ads')),
        isTrue,
      );
    });

    test('status filter — rejected only', () async {
      await container.read(approvalCenterFutureProvider.future);
      container.read(approvalCenterStatusFilterProvider.notifier).state = 3;
      final filtered = container.read(approvalCenterFilteredListProvider);
      expect(filtered, isNotEmpty);
      expect(filtered.every((a) => a.status == ApprovalStatus.rejected), isTrue);
      expect(
        filtered.any((a) => a.title.startsWith('Sports day')),
        isTrue,
      );
    });

    group('category filters', () {
      Future<void> load() =>
          container.read(approvalCenterFutureProvider.future);

      test('academic → exam results only', () async {
        await load();
        container.read(approvalCenterCategoryFilterProvider.notifier).state =
            ApprovalCategory.academic;
        final filtered = container.read(approvalCenterFilteredListProvider);
        expect(filtered, isNotEmpty);
        expect(
          filtered.every((a) => a.type == ApprovalRequestType.examResults),
          isTrue,
        );
      });

      test('attendance → attendance correction only', () async {
        await load();
        container.read(approvalCenterCategoryFilterProvider.notifier).state =
            ApprovalCategory.attendance;
        final filtered = container.read(approvalCenterFilteredListProvider);
        expect(filtered, isNotEmpty);
        expect(
          filtered.every(
            (a) => a.type == ApprovalRequestType.attendanceCorrection,
          ),
          isTrue,
        );
      });

      test('leave → student and staff leave', () async {
        await load();
        container.read(approvalCenterCategoryFilterProvider.notifier).state =
            ApprovalCategory.leave;
        final filtered = container.read(approvalCenterFilteredListProvider);
        expect(filtered.length, greaterThanOrEqualTo(2));
        expect(
          filtered.every(
            (a) =>
                a.type == ApprovalRequestType.studentLeave ||
                a.type == ApprovalRequestType.staffLeave,
          ),
          isTrue,
        );
      });

      test('finance → budget/expense/admission types', () async {
        await load();
        container.read(approvalCenterCategoryFilterProvider.notifier).state =
            ApprovalCategory.finance;
        final filtered = container.read(approvalCenterFilteredListProvider);
        expect(filtered, isNotEmpty);
        expect(
          filtered.any((a) => a.type == ApprovalRequestType.budget),
          isTrue,
        );
        expect(
          filtered.every((a) => ApprovalCategory.finance.matchesType(a.type)),
          isTrue,
        );
      });

      test('inventory → PO only', () async {
        await load();
        container.read(approvalCenterCategoryFilterProvider.notifier).state =
            ApprovalCategory.inventory;
        final filtered = container.read(approvalCenterFilteredListProvider);
        expect(filtered, isNotEmpty);
        expect(
          filtered.every((a) => a.type == ApprovalRequestType.inventoryPo),
          isTrue,
        );
      });
    });

    test('approve action transitions pending to approved', () async {
      await container.read(approvalCenterFutureProvider.future);
      final pending = container
          .read(approvalCenterListProvider)
          .firstWhere((a) => a.type == ApprovalRequestType.examResults);

      final result = await container
          .read(resolveApprovalRequestProvider.notifier)
          .approve(request: pending);

      expect(result, isNotNull);
      expect(result!.status, ApprovalStatus.approved);
      expect(result.decidedByName, isNotNull);

      await container.read(approvalCenterFutureProvider.future);
      final updated = container
          .read(approvalCenterListProvider)
          .firstWhere((a) => a.id == pending.id);
      expect(updated.status, ApprovalStatus.approved);
    });

    test('reject action requires non-empty comment', () async {
      await container.read(approvalCenterFutureProvider.future);
      final pending = container
          .read(approvalCenterListProvider)
          .firstWhere((a) => a.type == ApprovalRequestType.studentLeave);

      final result = await container
          .read(resolveApprovalRequestProvider.notifier)
          .reject(request: pending, comment: '   ');

      expect(result, isNull);
      expect(
        container.read(resolveApprovalRequestProvider).hasError,
        isTrue,
      );
    });

    test('reject with comment transitions to rejected', () async {
      await container.read(approvalCenterFutureProvider.future);
      final pending = container
          .read(approvalCenterListProvider)
          .firstWhere((a) => a.type == ApprovalRequestType.examResults);

      final result = await container
          .read(resolveApprovalRequestProvider.notifier)
          .reject(
            request: pending,
            comment: 'Insufficient documentation for certification test.',
          );

      expect(result, isNotNull);
      expect(result!.status, ApprovalStatus.rejected);
      expect(result.decisionComment, isNotEmpty);
    });

    test('audit history includes approve after decision', () async {
      await initProviderTestPrefs();
      final auditRepo = MockApprovalRepository();
      final auditContainer = createProviderTestContainer(
        overrides: [
          approvalRepositoryProvider.overrideWithValue(auditRepo),
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '9999999999',
              displayName: 'Principal Test',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(erpRole: ErpRole.principal),
            ),
          ),
        ],
      );
      addTearDown(auditContainer.dispose);

      await auditContainer.read(approvalCenterFutureProvider.future);
      final pending = auditContainer
          .read(approvalCenterListProvider)
          .firstWhere((a) => a.type == ApprovalRequestType.attendanceCorrection);

      await auditContainer
          .read(resolveApprovalRequestProvider.notifier)
          .approve(request: pending);

      final audit = await auditContainer.read(
        approvalCenterAuditFutureProvider(pending.id).future,
      );
      expect(
        audit.any((e) => e.action == ApprovalAuditAction.approved),
        isTrue,
      );
      expect(
        audit.any((e) => e.action == ApprovalAuditAction.submitted),
        isTrue,
      );
    });

    test('RBAC denies teacher approving exam results', () async {
      final teacherRepo = MockApprovalRepository();
      final teacherContainer = createProviderTestContainer(
        overrides: [
          approvalRepositoryProvider.overrideWithValue(teacherRepo),
          authStateOverride(
            AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: '7777777777',
              displayName: 'Teacher',
              role: UserRole.staff,
              claims: AuthClaims.demoForRole(erpRole: ErpRole.teacher),
            ),
          ),
        ],
      );
      addTearDown(teacherContainer.dispose);

      await teacherContainer.read(approvalCenterFutureProvider.future);
      final exam = teacherContainer
          .read(approvalCenterListProvider)
          .firstWhere((a) => a.type == ApprovalRequestType.examResults);

      final result = await teacherContainer
          .read(resolveApprovalRequestProvider.notifier)
          .approve(request: exam);

      expect(result, isNull);
      expect(
        teacherContainer.read(resolveApprovalRequestProvider).hasError,
        isTrue,
      );
      final error = teacherContainer.read(resolveApprovalRequestProvider).error;
      expect(error, isA<ApiFailureException>());
    });

    test('approvalPermissionForType maps admission to approveAdmissions', () {
      expect(
        approvalPermissionForType(ApprovalRequestType.admission),
        Permission.approveAdmissions,
      );
      expect(
        approvalPermissionForType(ApprovalRequestType.examResults),
        Permission.approveExamResults,
      );
      expect(
        approvalPermissionForType(ApprovalRequestType.inventoryPo),
        Permission.manageInventory,
      );
    });

    group('M-D3 exam adapter side effects', () {
      setUp(() {
        ExamAdministrationStore.instance.reset();
      });

      test('approve examResults publishes exam session in store', () async {
        final repo = MockApprovalRepository();
        final sideEffectContainer = createProviderTestContainer(
          overrides: [
            approvalRepositoryProvider.overrideWithValue(repo),
            authStateOverride(
              AuthState(
                status: AuthStatus.authenticated,
                phoneNumber: '9999999999',
                displayName: 'Principal Test',
                role: UserRole.staff,
                claims: AuthClaims.demoForRole(erpRole: ErpRole.principal),
              ),
            ),
          ],
        );
        addTearDown(sideEffectContainer.dispose);

        await sideEffectContainer.read(approvalCenterFutureProvider.future);
        final pending = sideEffectContainer
            .read(approvalCenterListProvider)
            .firstWhere((a) => a.type == ApprovalRequestType.examResults);

        expect(
          ExamAdministrationStore.instance.examById('exam_math_8a')!.phase,
          isNot(ExamLifecyclePhase.published),
        );

        final result = await sideEffectContainer
            .read(resolveApprovalRequestProvider.notifier)
            .approve(request: pending);

        expect(result, isNotNull);
        expect(
          ExamAdministrationStore.instance.examById('exam_math_8a')!.phase,
          ExamLifecyclePhase.published,
        );
        expect(ExamAdministrationStore.instance.hasPublishedResults, isTrue);
      });

      test('reject examResults stores principal comment without publishing', () async {
        final repo = MockApprovalRepository();
        final sideEffectContainer = createProviderTestContainer(
          overrides: [
            approvalRepositoryProvider.overrideWithValue(repo),
            authStateOverride(
              AuthState(
                status: AuthStatus.authenticated,
                phoneNumber: '9999999999',
                displayName: 'Principal Test',
                role: UserRole.staff,
                claims: AuthClaims.demoForRole(erpRole: ErpRole.principal),
              ),
            ),
          ],
        );
        addTearDown(sideEffectContainer.dispose);

        await sideEffectContainer.read(approvalCenterFutureProvider.future);
        final pending = sideEffectContainer
            .read(approvalCenterListProvider)
            .firstWhere((a) => a.type == ApprovalRequestType.examResults);

        final result = await sideEffectContainer
            .read(resolveApprovalRequestProvider.notifier)
            .reject(
              request: pending,
              comment: 'Verify absentee roll before resubmitting.',
            );

        expect(result, isNotNull);
        expect(ExamAdministrationStore.instance.hasPublishedResults, isFalse);
        expect(
          ExamAdministrationStore.instance.rejectionCommentFor('exam_math_8a'),
          'Verify absentee roll before resubmitting.',
        );
      });
    });
  });
}
