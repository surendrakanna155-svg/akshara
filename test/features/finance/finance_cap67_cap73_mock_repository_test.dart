// Cap 67 (class/section binding) + Cap 73 (mid-year admission proration) —
// MockFinanceRepository coverage, so offline/demo mode honours the same
// contract as the real API (models/requests/DTOs/mapper are covered
// separately; this proves the mock REPOSITORY LAYER itself).

import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/finance/finance_fee_proration.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const query = RepositoryQuery.demo;

  group('Cap 67 — class/section binding (mock repository)', () {
    test('createFeeStructure stores the class/section binding', () async {
      final repo = MockFinanceRepository();
      final structure = await repo.createFeeStructure(
        query: query,
        request: const CreateFeeStructureRequest(
          name: 'Class 5 Plan',
          academicYear: '2026-27',
          totalAnnual: '₹50,000',
          classRange: 'Class 5',
          className: '5',
          sectionName: 'A',
          categories: [],
        ),
      );
      expect(structure.isClassBound, true);
      expect(structure.className, '5');
      expect(structure.sectionName, 'A');
    });

    test('createFeeStructure with no binding fields stays unbound', () async {
      final repo = MockFinanceRepository();
      final structure = await repo.createFeeStructure(
        query: query,
        request: const CreateFeeStructureRequest(
          name: 'Unbound Plan',
          academicYear: '2026-27',
          totalAnnual: '₹50,000',
          classRange: 'Classes 1-5',
          categories: [],
        ),
      );
      expect(structure.isClassBound, false);
      expect(structure.className, isNull);
    });

    test('updateFeeStructure with no binding fields leaves an existing binding untouched', () async {
      final repo = MockFinanceRepository();
      final created = await repo.createFeeStructure(
        query: query,
        request: const CreateFeeStructureRequest(
          name: 'Bound',
          academicYear: '2026-27',
          totalAnnual: '₹50,000',
          classRange: 'Class 5',
          className: '5',
          categories: [],
        ),
      );
      final updated = await repo.updateFeeStructure(
        query: query,
        feeStructureId: created.id,
        request: const UpdateFeeStructureRequest(totalAnnual: '₹55,000'),
      );
      expect(updated.className, '5');
      expect(updated.totalAnnual, '₹55,000');
    });

    test('updateFeeStructure with unbindClass clears an existing binding', () async {
      final repo = MockFinanceRepository();
      final created = await repo.createFeeStructure(
        query: query,
        request: const CreateFeeStructureRequest(
          name: 'Bound',
          academicYear: '2026-27',
          totalAnnual: '₹50,000',
          classRange: 'Class 5',
          className: '5',
          sectionName: 'A',
          categories: [],
        ),
      );
      final updated = await repo.updateFeeStructure(
        query: query,
        feeStructureId: created.id,
        request: const UpdateFeeStructureRequest(unbindClass: true),
      );
      expect(updated.isClassBound, false);
      expect(updated.className, isNull);
      expect(updated.sectionName, isNull);
    });

    test('bulkAssignFeeStructure rejects an empty student list explicitly (mock has no roster to auto-resolve from)', () async {
      final repo = MockFinanceRepository();
      final structure = await repo.createFeeStructure(
        query: query,
        request: const CreateFeeStructureRequest(
          name: 'Class 5 Plan',
          academicYear: '2026-27',
          totalAnnual: '₹50,000',
          classRange: 'Class 5',
          className: '5',
          categories: [],
        ),
      );
      expect(
        () => repo.bulkAssignFeeStructure(
          query: query,
          request: BulkAssignFeePlanRequest(
            feeStructureId: structure.id,
            academicYear: '2026-27',
            studentIds: const [],
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('Cap 73 (owner decision #5) — mid-year admission proration (mock repository)', () {
    test('REGRESSION GUARD: with no override, assignFeePlan charges the FULL annual amount', () async {
      final repo = MockFinanceRepository();
      final structure = await repo.createFeeStructure(
        query: query,
        request: const CreateFeeStructureRequest(
          name: 'Standard',
          academicYear: '2026-27',
          totalAnnual: '₹50000',
          classRange: 'Class 5',
          categories: [],
        ),
      );
      final account = await repo.assignFeePlan(
        query: query,
        request: AssignFeePlanRequest(
          handoffId: 'handoff-1',
          feeStructureId: structure.id,
          installmentPlanId: 'plan-1',
          admissionDate: '2026-10-01', // mid-year — must NOT matter here
        ),
      );
      expect(account.totalDue, '₹50000');
      expect(account.proration, isNotNull);
      expect(account.proration!.policy, FeeProrationPolicy.fullAnnual);
      expect(account.proration!.isOverride, false);
    });

    test('an explicit prorate override charges LESS than the full annual amount for a late admission', () async {
      final repo = MockFinanceRepository();
      final structure = await repo.createFeeStructure(
        query: query,
        request: const CreateFeeStructureRequest(
          name: 'Standard',
          academicYear: '2026-27',
          totalAnnual: '₹50000',
          classRange: 'Class 5',
          categories: [],
        ),
      );
      final account = await repo.assignFeePlan(
        query: query,
        request: AssignFeePlanRequest(
          handoffId: 'handoff-1',
          feeStructureId: structure.id,
          installmentPlanId: 'plan-1',
          admissionDate: '2027-03-20', // last month of an April-start year
          prorationPolicyOverride: FeeProrationPolicy.prorateFromAdmissionMonth,
          prorationOverrideReason: 'Owner-approved exception',
        ),
      );
      final charged = double.parse(account.totalDue.replaceAll(RegExp(r'[₹,\s]'), ''));
      expect(charged, lessThan(50000));
      expect(charged, greaterThan(0));
      expect(account.proration!.isOverride, true);
      expect(account.proration!.overrideReason, 'Owner-approved exception');
      expect(account.proration!.monthsCharged, 1);
    });

    test('an override with no reason is rejected', () async {
      final repo = MockFinanceRepository();
      final structure = await repo.createFeeStructure(
        query: query,
        request: const CreateFeeStructureRequest(
          name: 'Standard',
          academicYear: '2026-27',
          totalAnnual: '₹50000',
          classRange: 'Class 5',
          categories: [],
        ),
      );
      expect(
        () => repo.assignFeePlan(
          query: query,
          request: AssignFeePlanRequest(
            handoffId: 'handoff-1',
            feeStructureId: structure.id,
            installmentPlanId: 'plan-1',
            prorationPolicyOverride: FeeProrationPolicy.prorateFromAdmissionMonth,
          ),
        ),
        throwsA(isA<FeeProrationOverrideReasonRequiredError>()),
      );
    });

    test('bulkAssignFeeStructure applies the SAME proration uniformly across the batch', () async {
      final repo = MockFinanceRepository();
      final structure = await repo.createFeeStructure(
        query: query,
        request: const CreateFeeStructureRequest(
          name: 'Standard',
          academicYear: '2026-27',
          totalAnnual: '₹50000',
          classRange: 'Class 5',
          categories: [],
        ),
      );
      final result = await repo.bulkAssignFeeStructure(
        query: query,
        request: BulkAssignFeePlanRequest(
          feeStructureId: structure.id,
          academicYear: '2026-27',
          studentIds: const ['s1', 's2', 's3'],
          admissionDate: '2027-03-20',
          prorationPolicyOverride: FeeProrationPolicy.prorateFromAdmissionMonth,
          prorationOverrideReason: 'Batch exception',
        ),
      );
      expect(result.assigned.length, 3);
      final totals = result.assigned.map((a) => a.totalDue).toSet();
      expect(totals.length, 1); // identical charge for every student
      for (final a in result.assigned) {
        expect(a.proration!.monthsCharged, 1);
      }
    });
  });
}
