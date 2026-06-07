import 'package:akshara_erp/core/repositories/api/finance/dto/assign_fee_plan_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/create_fee_structure_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/create_refund_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/create_scholarship_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/update_finance_settings_request_dto.dart';
import 'package:akshara_erp/core/repositories/interfaces/finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_requests.dart';
import 'package:flutter_test/flutter_test.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('Finance write DTO serialization', () {
    test('create fee structure request uses snake_case keys', () {
      const request = CreateFeeStructureRequest(
        name: 'Standard Plan',
        academicYear: '2026-27',
        totalAnnual: '₹1,85,000',
        classRange: '1 – 12',
        categories: [
          FeeCategoryLine(
            category: FeeStructureCategory.tuition,
            label: 'Tuition',
            amount: '₹1,45,000',
          ),
        ],
      );
      final json = CreateFeeStructureRequestDto.fromDomain(request).toJson();
      expect(json['name'], 'Standard Plan');
      expect(json['academic_year'], '2026-27');
      expect(json['total_annual'], '₹1,85,000');
    });

    test('assign fee plan request serializes handoff and structure ids', () {
      final json = AssignFeePlanRequestDto.fromDomain(
        const AssignFeePlanRequest(
          handoffId: 'HO-1',
          feeStructureId: 'fee_std',
          installmentPlanId: 'plan_quarterly',
          studentName: 'Arjun Patel',
          admissionNumber: 'ADM-2026-0138',
        ),
      ).toJson();
      expect(json['handoff_id'], 'HO-1');
      expect(json['fee_structure_id'], 'fee_std');
      expect(json['installment_plan_id'], 'plan_quarterly');
    });

    test('create refund request serializes fee account id', () {
      final json = CreateRefundRequestDto.fromDomain(
        const CreateRefundRequest(
          feeAccountId: 'acct_1',
          amount: '₹12,000',
          reason: 'Overpayment',
        ),
      ).toJson();
      expect(json['fee_account_id'], 'acct_1');
      expect(json['amount'], '₹12,000');
    });

    test('create scholarship request serializes type', () {
      final json = CreateScholarshipRequestDto.fromDomain(
        const CreateScholarshipRequest(
          name: 'Merit Aid',
          type: ScholarshipType.needBased,
          maxDiscount: '20%',
          eligibility: 'Income below threshold',
        ),
      ).toJson();
      expect(json['name'], 'Merit Aid');
      expect(json['type'], 'need_based');
    });

    test('update settings request serializes section updates', () {
      final json = UpdateFinanceSettingsRequestDto.fromDomain(
        const UpdateFinanceSettingsRequest(
          updates: [
            FinanceSettingUpdate(
              sectionId: 'gateway',
              itemId: 'upi',
              value: 'Razorpay (live)',
            ),
          ],
        ),
      ).toJson();
      final updates = json['updates'] as List<dynamic>;
      expect((updates.first as Map)['section_id'], 'gateway');
      expect((updates.first as Map)['value'], 'Razorpay (live)');
    });
  });

  group('Mock finance write repository', () {
    late MockFinanceRepository repo;

    setUp(() {
      repo = MockFinanceRepository();
    });

    test('implements all write methods on FinanceRepository', () {
      expect(repo, isA<FinanceRepository>());
    });

    test('createFeeStructure returns persisted structure in subsequent get', () async {
      final created = await repo.createFeeStructure(
        query: kQuery,
        request: const CreateFeeStructureRequest(
          name: 'Test Structure',
          academicYear: '2026-27',
          totalAnnual: '₹2,00,000',
          classRange: '6 – 10',
          categories: [
            FeeCategoryLine(
              category: FeeStructureCategory.tuition,
              label: 'Tuition',
              amount: '₹2,00,000',
            ),
          ],
        ),
      );
      final structures = await repo.getFeeStructures(
        query: kQuery,
        academicYear: '2026-27',
      );
      expect(structures.any((structure) => structure.id == created.id), isTrue);
    });

    test('assignFeePlan creates student account', () async {
      final account = await repo.assignFeePlan(
        query: kQuery,
        request: const AssignFeePlanRequest(
          handoffId: 'HO-99',
          feeStructureId: 'fee_std',
          installmentPlanId: 'plan_quarterly',
          studentName: 'Test Student',
          admissionNumber: 'ADM-TEST-001',
          classLabel: '7',
        ),
      );
      final accounts = await repo.getStudentAccounts(query: kQuery);
      expect(accounts.items.any((item) => item.id == account.id), isTrue);
    });

    test('approveRefund marks refund as approved', () async {
      final approved = await repo.approveRefund(
        query: kQuery,
        refundId: 'ref_1',
      );
      expect(approved.status, RefundStatus.approved);
    });

    test('createScholarship appears in discounts dashboard', () async {
      final created = await repo.createScholarship(
        query: kQuery,
        request: const CreateScholarshipRequest(
          name: 'New Aid Program',
          type: ScholarshipType.merit,
          maxDiscount: '15%',
          eligibility: 'Top performers',
        ),
      );
      final dashboard = await repo.getDiscountsDashboard(query: kQuery);
      expect(
        dashboard.scholarships.any((item) => item.id == created.id),
        isTrue,
      );
    });

    test('updateSettings persists edited values', () async {
      final updated = await repo.updateSettings(
        query: kQuery,
        request: const UpdateFinanceSettingsRequest(
          updates: [
            FinanceSettingUpdate(
              sectionId: 'gateway',
              itemId: 'upi',
              value: 'Razorpay (live)',
            ),
          ],
        ),
      );
      final gateway = updated.sections
          .firstWhere((section) => section.id == 'gateway');
      final upi = gateway.items.firstWhere((item) => item.id == 'upi');
      expect(upi.value, 'Razorpay (live)');
    });
  });
}
