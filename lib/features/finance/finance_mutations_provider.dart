import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/academic/academic_catalog_mutation.dart';
import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/tenant/tenant_provider.dart';
import 'collections/finance_collections_provider.dart';
import 'discounts/finance_discounts_provider.dart';
import 'finance_journey_context_provider.dart';
import 'fee_structures/finance_fee_structures_provider.dart';
import 'finance_audit.dart';
import 'finance_models.dart';
import 'finance_requests.dart';
import 'refunds/finance_refunds_provider.dart';
import 'settings/finance_settings_provider.dart';
import 'student_accounts/finance_student_accounts_provider.dart';

void _invalidateFinanceReads(
  Ref ref, {
  bool feeStructures = false,
  bool studentAccounts = false,
  bool collections = false,
  bool refunds = false,
  bool discounts = false,
  bool settings = false,
}) {
  if (feeStructures) ref.invalidate(financeFeeStructuresFutureProvider);
  if (studentAccounts) ref.invalidate(financeStudentAccountsFutureProvider);
  if (collections) {
    ref.invalidate(financeCollectionsFutureProvider);
    ref.invalidate(financeDailySummaryFutureProvider);
  }
  if (refunds) ref.invalidate(financeRefundsFutureProvider);
  if (discounts) ref.invalidate(financeDiscountsFutureProvider);
  if (settings) ref.invalidate(financeSettingsFutureProvider);
}

Future<T?> _runMutation<T>(
  Ref ref, {
  required Future<T> Function() action,
  required String auditAction,
  required String entityId,
  String Function(T result)? entityIdForAudit,
  Map<String, String> metadata = const {},
  bool invalidateFeeStructures = false,
  bool invalidateStudentAccounts = false,
  bool invalidateCollections = false,
  bool invalidateRefunds = false,
  bool invalidateDiscounts = false,
  bool invalidateSettings = false,
  void Function()? assertPermission,
}) async {
  assertPermission?.call();
  try {
    final result = await action();
    await recordFinanceAudit(
      ref,
      action: auditAction,
      entityId: entityIdForAudit?.call(result) ?? entityId,
      metadata: metadata,
    );
    _invalidateFinanceReads(
      ref,
      feeStructures: invalidateFeeStructures,
      studentAccounts: invalidateStudentAccounts,
      collections: invalidateCollections,
      refunds: invalidateRefunds,
      discounts: invalidateDiscounts,
      settings: invalidateSettings,
    );
    return result;
  } catch (error) {
    final failure = apiFailureMapper.fromException(error);
    throw ApiFailureException(failure);
  }
}

class CreateFeeStructureNotifier extends AsyncNotifier<FinanceFeeStructure?> {
  @override
  FutureOr<FinanceFeeStructure?> build() => null;

  Future<FinanceFeeStructure?> execute(CreateFeeStructureRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final catalog = ref.read(academicCatalogProvider);
      final enriched = catalog == null
          ? request
          : enrichCreateFeeStructureRequest(request, catalog);
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'createFeeStructure',
        entityId: 'feeStructure',
        entityIdForAudit: (structure) => structure.id,
        invalidateFeeStructures: true,
        action: () => ref.read(financeRepositoryProvider).createFeeStructure(
              query: ref.read(repositoryQueryProvider),
              request: enriched,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final createFeeStructureProvider =
    AsyncNotifierProvider<CreateFeeStructureNotifier, FinanceFeeStructure?>(
  CreateFeeStructureNotifier.new,
);

class UpdateFeeStructureNotifier extends AsyncNotifier<FinanceFeeStructure?> {
  @override
  FutureOr<FinanceFeeStructure?> build() => null;

  Future<FinanceFeeStructure?> execute({
    required String feeStructureId,
    required UpdateFeeStructureRequest request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final catalog = ref.read(academicCatalogProvider);
      final enriched = catalog == null
          ? request
          : enrichUpdateFeeStructureRequest(request, catalog);
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'updateFeeStructure',
        entityId: feeStructureId,
        invalidateFeeStructures: true,
        action: () => ref.read(financeRepositoryProvider).updateFeeStructure(
              query: ref.read(repositoryQueryProvider),
              feeStructureId: feeStructureId,
              request: enriched,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateFeeStructureProvider =
    AsyncNotifierProvider<UpdateFeeStructureNotifier, FinanceFeeStructure?>(
  UpdateFeeStructureNotifier.new,
);

class CreateStudentAccountNotifier extends AsyncNotifier<StudentFeeAccount?> {
  @override
  FutureOr<StudentFeeAccount?> build() => null;

  Future<StudentFeeAccount?> execute(CreateStudentAccountRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'createStudentAccount',
        entityId: 'studentAccount',
        entityIdForAudit: (account) => account.id,
        invalidateStudentAccounts: true,
        action: () => ref.read(financeRepositoryProvider).createStudentAccount(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final createStudentAccountProvider =
    AsyncNotifierProvider<CreateStudentAccountNotifier, StudentFeeAccount?>(
  CreateStudentAccountNotifier.new,
);

class UpdateStudentAccountNotifier extends AsyncNotifier<StudentFeeAccount?> {
  @override
  FutureOr<StudentFeeAccount?> build() => null;

  Future<StudentFeeAccount?> execute({
    required String accountId,
    required UpdateStudentAccountRequest request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'updateStudentAccount',
        entityId: accountId,
        invalidateStudentAccounts: true,
        action: () => ref.read(financeRepositoryProvider).updateStudentAccount(
              query: ref.read(repositoryQueryProvider),
              accountId: accountId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateStudentAccountProvider =
    AsyncNotifierProvider<UpdateStudentAccountNotifier, StudentFeeAccount?>(
  UpdateStudentAccountNotifier.new,
);

class AssignFeePlanNotifier extends AsyncNotifier<StudentFeeAccount?> {
  @override
  FutureOr<StudentFeeAccount?> build() => null;

  Future<StudentFeeAccount?> execute(AssignFeePlanRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final account = await _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'assignFeePlan',
        entityId: request.handoffId,
        metadata: {'feeStructureId': request.feeStructureId},
        entityIdForAudit: (account) => account.id,
        invalidateStudentAccounts: true,
        action: () => ref.read(financeRepositoryProvider).assignFeePlan(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
      if (account != null) {
        final invoices = await ref.read(financeRepositoryProvider).getInvoices(
              query: ref.read(repositoryQueryProvider).withPage(
                    1,
                    pageSize: 200,
                  ),
            );
        for (final invoice in invoices.items) {
          if (invoice.feeAssignmentId == account.id ||
              invoice.studentId == account.id) {
            ref.read(financeLastInvoiceIdProvider.notifier).state = invoice.id;
            break;
          }
        }
      }
      return account;
    });
    return state.valueOrNull;
  }
}

final assignFeePlanProvider =
    AsyncNotifierProvider<AssignFeePlanNotifier, StudentFeeAccount?>(
  AssignFeePlanNotifier.new,
);

class CreateCollectionNotifier extends AsyncNotifier<FinanceCollectionResult?> {
  @override
  FutureOr<FinanceCollectionResult?> build() => null;

  Future<FinanceCollectionResult?> execute(CreateCollectionRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'createCollection',
        entityId: request.invoiceId,
        entityIdForAudit: (result) => result.collectionId,
        metadata: {'paymentMethod': request.paymentMethod},
        invalidateCollections: true,
        invalidateStudentAccounts: true,
        action: () => ref.read(financeRepositoryProvider).createCollection(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final createCollectionProvider =
    AsyncNotifierProvider<CreateCollectionNotifier, FinanceCollectionResult?>(
  CreateCollectionNotifier.new,
);

class CreateRefundNotifier extends AsyncNotifier<RefundRequest?> {
  @override
  FutureOr<RefundRequest?> build() => null;

  Future<RefundRequest?> execute(CreateRefundRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'createRefund',
        entityId: 'refund',
        entityIdForAudit: (refund) => refund.id,
        invalidateRefunds: true,
        action: () => ref.read(financeRepositoryProvider).createRefund(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final createRefundProvider =
    AsyncNotifierProvider<CreateRefundNotifier, RefundRequest?>(
  CreateRefundNotifier.new,
);

class ApproveRefundNotifier extends AsyncNotifier<RefundRequest?> {
  @override
  FutureOr<RefundRequest?> build() => null;

  Future<RefundRequest?> execute({
    required String refundId,
    ApproveRefundRequest request = const ApproveRefundRequest(),
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertApproveRefunds(ref),
        auditAction: 'approveRefund',
        entityId: refundId,
        invalidateRefunds: true,
        action: () => ref.read(financeRepositoryProvider).approveRefund(
              query: ref.read(repositoryQueryProvider),
              refundId: refundId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final approveRefundProvider =
    AsyncNotifierProvider<ApproveRefundNotifier, RefundRequest?>(
  ApproveRefundNotifier.new,
);

class RejectRefundNotifier extends AsyncNotifier<RefundRequest?> {
  @override
  FutureOr<RefundRequest?> build() => null;

  Future<RefundRequest?> execute({required String refundId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertApproveRefunds(ref),
        auditAction: 'rejectRefund',
        entityId: refundId,
        invalidateRefunds: true,
        action: () => ref.read(financeRepositoryProvider).rejectRefund(
              query: ref.read(repositoryQueryProvider),
              refundId: refundId,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final rejectRefundProvider =
    AsyncNotifierProvider<RejectRefundNotifier, RefundRequest?>(
  RejectRefundNotifier.new,
);

class CreateScholarshipNotifier extends AsyncNotifier<ScholarshipCatalogItem?> {
  @override
  FutureOr<ScholarshipCatalogItem?> build() => null;

  Future<ScholarshipCatalogItem?> execute(CreateScholarshipRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'createScholarship',
        entityId: 'scholarship',
        entityIdForAudit: (scholarship) => scholarship.id,
        invalidateDiscounts: true,
        action: () => ref.read(financeRepositoryProvider).createScholarship(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final createScholarshipProvider =
    AsyncNotifierProvider<CreateScholarshipNotifier, ScholarshipCatalogItem?>(
  CreateScholarshipNotifier.new,
);

class UpdateScholarshipNotifier extends AsyncNotifier<ScholarshipCatalogItem?> {
  @override
  FutureOr<ScholarshipCatalogItem?> build() => null;

  Future<ScholarshipCatalogItem?> execute({
    required String scholarshipId,
    required UpdateScholarshipRequest request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'updateScholarship',
        entityId: scholarshipId,
        invalidateDiscounts: true,
        action: () => ref.read(financeRepositoryProvider).updateScholarship(
              query: ref.read(repositoryQueryProvider),
              scholarshipId: scholarshipId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateScholarshipProvider =
    AsyncNotifierProvider<UpdateScholarshipNotifier, ScholarshipCatalogItem?>(
  UpdateScholarshipNotifier.new,
);

class UpdateFinanceSettingsNotifier extends AsyncNotifier<FinanceSettingsData?> {
  @override
  FutureOr<FinanceSettingsData?> build() => null;

  Future<FinanceSettingsData?> execute(
    UpdateFinanceSettingsRequest request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'updateSettings',
        entityId: 'financeSettings',
        invalidateSettings: true,
        action: () => ref.read(financeRepositoryProvider).updateSettings(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateFinanceSettingsProvider =
    AsyncNotifierProvider<UpdateFinanceSettingsNotifier, FinanceSettingsData?>(
  UpdateFinanceSettingsNotifier.new,
);
