import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_mutations_provider.dart';
import 'package:akshara_erp/features/finance/finance_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('Finance RBAC mutations', () {
    test('createFeeStructure fails for admissionsCounselor without manageFinance',
        () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createFeeStructureProvider.notifier).execute(
            const CreateFeeStructureRequest(
              name: 'Counselor Blocked',
              academicYear: '2026-27',
              totalAnnual: '₹1,00,000',
              classRange: '1 – 5',
              categories: [
                FeeCategoryLine(
                  category: FeeStructureCategory.tuition,
                  label: 'Tuition',
                  amount: '₹1,00,000',
                ),
              ],
            ),
          );

      expect(container.read(createFeeStructureProvider).hasError, isTrue);
    });

    test('createFeeStructure fails when manageFinance permission missing',
        () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createFeeStructureProvider.notifier).execute(
            const CreateFeeStructureRequest(
              name: 'Blocked',
              academicYear: '2026-27',
              totalAnnual: '₹1,00,000',
              classRange: '1 – 5',
              categories: [
                FeeCategoryLine(
                  category: FeeStructureCategory.tuition,
                  label: 'Tuition',
                  amount: '₹1,00,000',
                ),
              ],
            ),
          );

      expect(container.read(createFeeStructureProvider).hasError, isTrue);
    });

    test('createFeeStructure succeeds with finance admin role', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final created = await container
          .read(createFeeStructureProvider.notifier)
          .execute(
            const CreateFeeStructureRequest(
              name: 'Provider Structure',
              academicYear: '2026-27',
              totalAnnual: '₹1,50,000',
              classRange: '6 – 8',
              categories: [
                FeeCategoryLine(
                  category: FeeStructureCategory.tuition,
                  label: 'Tuition',
                  amount: '₹1,50,000',
                ),
              ],
            ),
          );

      expect(created, isNotNull);
      expect(created!.name, 'Provider Structure');
    });

    test('assignFeePlan fails when manageFinance permission missing', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.inventoryManager),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(assignFeePlanProvider.notifier).execute(
            const AssignFeePlanRequest(
              handoffId: 'handoff_2',
              feeStructureId: 'fee_std',
              installmentPlanId: 'plan_quarterly',
              studentName: 'Test',
              admissionNumber: 'ADM-1',
              classLabel: '5',
            ),
          );

      expect(container.read(assignFeePlanProvider).hasError, isTrue);
    });

    test('createCollection fails when manageFinance permission missing', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createCollectionProvider.notifier).execute(
            const CreateCollectionRequest(
              invoiceId: 'inv_1',
              amountCollected: '1000',
              paymentMethod: 'Cash',
            ),
          );

      expect(container.read(createCollectionProvider).hasError, isTrue);
    });

    test('issueInvoice succeeds with finance admin role', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final issued = await container.read(issueInvoiceProvider.notifier).execute(
            invoiceId: 'inv_3',
          );

      expect(issued, isNotNull);
      expect(issued!.invoiceStatus, InvoiceStatus.issued);
    });

    test('cancelInvoice fails when manageFinance permission missing', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cancelInvoiceProvider.notifier).execute(
            invoiceId: 'inv_3',
          );

      expect(container.read(cancelInvoiceProvider).hasError, isTrue);
    });

    test('cancelCollection succeeds with finance admin role', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(cancelCollectionProvider.notifier)
          .execute(collectionId: 'col_1', reason: 'duplicate entry');

      expect(result, isNotNull);
    });

    test('createRefund succeeds with finance admin role', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final created = await container.read(createRefundProvider.notifier).execute(
            const CreateRefundRequest(
              feeAccountId: 'acct_1',
              amount: '₹2,500',
              reason: 'Duplicate payment',
              studentName: 'Arjun Patel',
              admissionNumber: 'ADM-2026-0138',
              classLabel: '10',
              originalReceipt: 'RCP-TEST-001',
            ),
          );

      expect(created, isNotNull);
      expect(created!.status, RefundStatus.pending);
      expect(created.amount, '₹2,500');
    });

    test('createRefund fails when manageFinance permission missing', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(createRefundProvider.notifier).execute(
            const CreateRefundRequest(
              feeAccountId: 'acct_1',
              amount: '₹1,000',
              reason: 'Test',
            ),
          );

      expect(container.read(createRefundProvider).hasError, isTrue);
    });

    // STEP-5 — P0 money-honesty fix (PRC-A cap 71): replaces the old
    // "assignFeeConcession" fabricated-id tests above. The MAKER step
    // (propose*) moves no money and only needs manageFinance; the CHECKER
    // step (approve/reject/reverse) needs approveFeeConcession AND rejects
    // the proposer approving their own reduction (SoD, mirrors refunds).
    test('proposeScholarshipAward succeeds with finance admin role and moves '
        'no money', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final proposed = await container
          .read(proposeScholarshipAwardProvider.notifier)
          .execute(
            scholarshipId: 'sch_1',
            invoiceId: 'inv_1',
            reason: 'Merit scholarship',
            percent: 10,
          );

      expect(proposed, isNotNull);
      expect(proposed!.status, FeeReductionStatus.pending);
      expect(proposed.invoiceId, 'inv_1');
      expect(proposed.appliedAmount, '0');
    });

    test(
        'proposeScholarshipAward fails when manageFinance permission missing',
        () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(proposeScholarshipAwardProvider.notifier).execute(
            scholarshipId: 'sch_1',
            invoiceId: 'inv_1',
            reason: 'Test',
            percent: 10,
          );

      expect(
        container.read(proposeScholarshipAwardProvider).hasError,
        isTrue,
      );
    });

    test('approveFeeReduction actually reduces the invoice payable', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final proposed = await container
          .read(proposeDiscountApplicationProvider.notifier)
          .execute(
            discountRuleId: 'rule_1',
            invoiceId: 'inv_1',
            reason: 'Early bird payment',
            percent: 10,
          );
      expect(proposed, isNotNull);

      final approved = await container
          .read(approveFeeReductionProvider.notifier)
          .execute(reductionId: proposed!.id);

      expect(approved, isNotNull);
      expect(approved!.status, FeeReductionStatus.approved);
      expect(double.parse(approved.appliedAmount), greaterThan(0));

      final invoice = await container
          .read(financeRepositoryProvider)
          .getInvoice(query: RepositoryQuery.demo, invoiceId: 'inv_1');
      expect(invoice, isNotNull);
      expect(
        double.parse(invoice!.outstandingAmount),
        lessThan(50000),
      );
    });

    test(
        'approveFeeReduction fails when approveFeeConcession permission '
        'missing', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          // No finance permissions at all — mirrors the RBAC-gate style of
          // the other "permission missing" tests above (checked before the
          // repository is ever touched, so no pending reduction is needed).
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(approveFeeReductionProvider.notifier)
          .execute(reductionId: 'fred_test');

      expect(container.read(approveFeeReductionProvider).hasError, isTrue);
    });
  });
}
