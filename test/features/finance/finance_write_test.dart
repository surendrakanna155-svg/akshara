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

    test('assignFeeConcession succeeds with finance admin role', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final concessionId = await container
          .read(assignFeeConcessionProvider.notifier)
          .execute(
            studentName: 'Arjun Patel',
            amount: '₹15,000',
            reason: 'Merit scholarship',
            feeAccountId: 'acct_1',
          );

      expect(concessionId, isNotNull);
      expect(concessionId, startsWith('concession_'));
    });

    test('assignFeeConcession fails when assignScholarship permission missing',
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

      await container.read(assignFeeConcessionProvider.notifier).execute(
            studentName: 'Test Student',
            amount: '₹5,000',
            reason: 'Test',
          );

      expect(container.read(assignFeeConcessionProvider).hasError, isTrue);
    });
  });
}
