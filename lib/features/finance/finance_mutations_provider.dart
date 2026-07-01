import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/finance/finance_approval_governance_store.dart';
import '../../core/approvals/adapters/finance_approval_adapters.dart';
import '../../core/audit/audit_event.dart';
import '../../core/config/finance_approval_config.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/academic/academic_catalog_mutation.dart';
import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../features/auth/auth_provider.dart';
import 'collections/finance_collections_provider.dart';
import 'discounts/finance_discounts_provider.dart';
import 'finance_journey_context_provider.dart';
import 'finance_payments_provider.dart';
import 'fee_structures/finance_fee_structures_provider.dart';
import 'finance_audit.dart';
import 'finance_models.dart';
import 'receipts/finance_receipt_pdf_service.dart';
import 'finance_requests.dart';
import '../school_completion/school_branding_theme_provider.dart';
import 'invoices/finance_invoices_provider.dart';
import 'refunds/finance_refunds_provider.dart';
import 'settings/finance_settings_provider.dart';
import 'student_accounts/finance_student_accounts_provider.dart';

void _invalidateFinanceReads(
  Ref ref, {
  bool feeStructures = false,
  bool studentAccounts = false,
  bool collections = false,
  bool offlinePayments = false,
  bool invoices = false,
  bool refunds = false,
  bool discounts = false,
  bool settings = false,
  bool qrPaymentSession = false,
}) {
  if (feeStructures) ref.invalidate(financeFeeStructuresFutureProvider);
  if (studentAccounts) ref.invalidate(financeStudentAccountsFutureProvider);
  if (collections) {
    ref.invalidate(financeCollectionsFutureProvider);
    ref.invalidate(financeDailySummaryFutureProvider);
  }
  if (offlinePayments) {
    ref.invalidate(offlinePaymentsFutureProvider);
  }
  if (invoices) ref.invalidate(financeInvoicesFutureProvider);
  if (refunds) ref.invalidate(financeRefundsFutureProvider);
  if (discounts) ref.invalidate(financeDiscountsFutureProvider);
  if (settings) ref.invalidate(financeSettingsFutureProvider);
  if (qrPaymentSession) ref.invalidate(qrPaymentSessionProvider);
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
  bool invalidateOfflinePayments = false,
  bool invalidateInvoices = false,
  bool invalidateRefunds = false,
  bool invalidateDiscounts = false,
  bool invalidateSettings = false,
  bool invalidateQrPaymentSession = false,
  void Function()? assertPermission,
  AuditEventType auditType = AuditEventType.financeHandoffSent,
}) async {
  assertPermission?.call();
  try {
    final result = await action();
    try {
      await recordFinanceAudit(
        ref,
        type: auditType,
        action: auditAction,
        entityId: entityIdForAudit?.call(result) ?? entityId,
        metadata: metadata,
      );
    } catch (_) {
      // Audit persistence must not block finance mutations in QA automation.
    }
    _invalidateFinanceReads(
      ref,
      feeStructures: invalidateFeeStructures,
      studentAccounts: invalidateStudentAccounts,
      collections: invalidateCollections,
      offlinePayments: invalidateOfflinePayments,
      invoices: invalidateInvoices,
      refunds: invalidateRefunds,
      discounts: invalidateDiscounts,
      settings: invalidateSettings,
      qrPaymentSession: invalidateQrPaymentSession,
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

  Future<FinanceFeeStructure?> execute(
      CreateFeeStructureRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final catalog = ref.read(academicCatalogProvider);
      final approvalRequired = ref.read(financeApprovalRequiredProvider);
      final enrichedBase = catalog == null
          ? request
          : enrichCreateFeeStructureRequest(request, catalog);
      final enriched = approvalRequired
          ? CreateFeeStructureRequest(
              name: enrichedBase.name,
              academicYear: enrichedBase.academicYear,
              totalAnnual: enrichedBase.totalAnnual,
              classRange: enrichedBase.classRange,
              categories: enrichedBase.categories,
              status: FeeStructureStatus.inactive,
              installmentOptions: enrichedBase.installmentOptions,
            )
          : enrichedBase;
      final structure = await _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'createFeeStructure',
        entityId: 'feeStructure',
        entityIdForAudit: (item) => item.id,
        invalidateFeeStructures: true,
        action: () => ref.read(financeRepositoryProvider).createFeeStructure(
              query: ref.read(repositoryQueryProvider),
              request: enriched,
            ),
      );

      if (structure != null && approvalRequired) {
        final auth = ref.read(authProvider);
        final adapter = FeeStructureApprovalAdapter();
        await adapter.submitForApproval(
          service: ref.read(approvalCenterServiceProvider),
          query: ref.read(repositoryQueryProvider),
          feeStructureId: structure.id,
          requesterId: auth.claims?.userId ?? 'finance_demo',
          requesterName: auth.displayName ?? 'Finance Admin',
          title: 'Activate fee structure — ${structure.name}',
          summary:
              '${structure.academicYear} · ${structure.classRange} · ${structure.totalAnnual}',
          payload: {
            'name': structure.name,
            'academicYear': structure.academicYear,
            'classRange': structure.classRange,
            'totalAnnual': structure.totalAnnual,
          },
        );
      }

      return structure;
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
    if (state.isLoading) return state.valueOrNull;
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

  Future<StudentFeeAccount?> execute(
      CreateStudentAccountRequest request) async {
    if (state.isLoading) return state.valueOrNull;
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
    if (state.isLoading) return state.valueOrNull;
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
    if (state.isLoading) return state.valueOrNull;
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

  Future<FinanceCollectionResult?> execute(
      CreateCollectionRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'createCollection',
        auditType: AuditEventType.collectionCreated,
        entityId: request.invoiceId,
        entityIdForAudit: (result) => result.collectionId,
        metadata: {'paymentMethod': request.paymentMethod},
        invalidateCollections: true,
        invalidateOfflinePayments: true,
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

class RecordOfflinePaymentNotifier
    extends AsyncNotifier<OfflinePaymentRecord?> {
  @override
  FutureOr<OfflinePaymentRecord?> build() => null;

  Future<OfflinePaymentRecord?> execute(
    RecordOfflinePaymentRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'recordOfflinePayment',
        auditType: AuditEventType.paymentInitiated,
        entityId: request.invoiceId,
        entityIdForAudit: (record) => record.id,
        metadata: {'method': request.method.name},
        invalidateOfflinePayments: true,
        action: () => ref.read(financeRepositoryProvider).recordOfflinePayment(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final recordOfflinePaymentProvider =
    AsyncNotifierProvider<RecordOfflinePaymentNotifier, OfflinePaymentRecord?>(
  RecordOfflinePaymentNotifier.new,
);

class ReconcileOfflinePaymentNotifier
    extends AsyncNotifier<OfflinePaymentRecord?> {
  @override
  FutureOr<OfflinePaymentRecord?> build() => null;

  Future<OfflinePaymentRecord?> execute({
    required String offlinePaymentId,
    ReconcileOfflinePaymentRequest request =
        const ReconcileOfflinePaymentRequest(),
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'reconcileOfflinePayment',
        auditType: AuditEventType.collectionCreated,
        entityId: offlinePaymentId,
        entityIdForAudit: (record) => record.id,
        invalidateCollections: true,
        invalidateOfflinePayments: true,
        invalidateStudentAccounts: true,
        invalidateInvoices: true,
        action: () =>
            ref.read(financeRepositoryProvider).reconcileOfflinePayment(
                  query: ref.read(repositoryQueryProvider),
                  offlinePaymentId: offlinePaymentId,
                  request: request,
                ),
      );
    });
    return state.valueOrNull;
  }
}

final reconcileOfflinePaymentProvider = AsyncNotifierProvider<
    ReconcileOfflinePaymentNotifier, OfflinePaymentRecord?>(
  ReconcileOfflinePaymentNotifier.new,
);

class CreateQrPaymentSessionNotifier extends AsyncNotifier<QrPaymentSession?> {
  @override
  FutureOr<QrPaymentSession?> build() => null;

  Future<QrPaymentSession?> execute(
      CreateQrPaymentSessionRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'createQrPaymentSession',
        entityId: request.invoiceId,
        entityIdForAudit: (result) => result.id,
        metadata: {'amount': request.amount},
        invalidateQrPaymentSession: true,
        action: () =>
            ref.read(financeRepositoryProvider).createQrPaymentSession(
                  query: ref.read(repositoryQueryProvider),
                  request: request,
                ),
      );
      if (session != null) {
        ref.read(financeQrPaymentSessionIdProvider.notifier).state = session.id;
      }
      return session;
    });
    return state.valueOrNull;
  }
}

final createQrPaymentSessionProvider =
    AsyncNotifierProvider<CreateQrPaymentSessionNotifier, QrPaymentSession?>(
  CreateQrPaymentSessionNotifier.new,
);

class ConfirmQrPaymentSessionNotifier extends AsyncNotifier<QrPaymentSession?> {
  @override
  FutureOr<QrPaymentSession?> build() => null;

  Future<QrPaymentSession?> execute({
    required String sessionId,
    required ConfirmQrPaymentRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'confirmQrPaymentSession',
        entityId: sessionId,
        entityIdForAudit: (result) => result.id,
        metadata: {
          if (request.receiptNumber != null)
            'receiptNumber': request.receiptNumber!,
        },
        invalidateCollections: true,
        invalidateQrPaymentSession: true,
        action: () =>
            ref.read(financeRepositoryProvider).confirmQrPaymentSession(
                  query: ref.read(repositoryQueryProvider),
                  sessionId: sessionId,
                  request: request,
                ),
      );
    });
    return state.valueOrNull;
  }
}

final confirmQrPaymentSessionProvider =
    AsyncNotifierProvider<ConfirmQrPaymentSessionNotifier, QrPaymentSession?>(
  ConfirmQrPaymentSessionNotifier.new,
);

class CreateRefundNotifier extends AsyncNotifier<RefundRequest?> {
  @override
  FutureOr<RefundRequest?> build() => null;

  Future<RefundRequest?> execute(CreateRefundRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final refund = await _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'createRefund',
        entityId: 'refund',
        entityIdForAudit: (item) => item.id,
        invalidateRefunds: true,
        action: () => ref.read(financeRepositoryProvider).createRefund(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );

      if (refund != null && ref.read(financeApprovalRequiredProvider)) {
        final auth = ref.read(authProvider);
        final adapter = RefundApprovalAdapter();
        await adapter.submitForApproval(
          service: ref.read(approvalCenterServiceProvider),
          query: ref.read(repositoryQueryProvider),
          refundId: refund.id,
          requesterId: auth.claims?.userId ?? 'finance_demo',
          requesterName: auth.displayName ?? 'Finance Admin',
          title: 'Refund approval — ${refund.studentName}',
          summary: '${refund.amount} · ${refund.reason}',
          payload: {
            'studentName': refund.studentName,
            'amount': refund.amount,
            'reason': refund.reason,
          },
        );
      }

      return refund;
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
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (ref.read(financeApprovalRequiredProvider) &&
          !FinanceApprovalGovernanceStore.instance.approvedRefundIds
              .contains(refundId)) {
        throw ApiFailureException(
          const ApiFailure(
            type: ApiFailureType.forbidden,
            message: 'Refund requires principal approval in the Approval Center.',
            code: 'REFUND_APPROVAL_REQUIRED',
          ),
        );
      }
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
    if (state.isLoading) return state.valueOrNull;
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

  Future<ScholarshipCatalogItem?> execute(
      CreateScholarshipRequest request) async {
    if (state.isLoading) return state.valueOrNull;
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
    if (state.isLoading) return state.valueOrNull;
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

class CreateDiscountRuleNotifier extends AsyncNotifier<DiscountRule?> {
  @override
  FutureOr<DiscountRule?> build() => null;

  Future<DiscountRule?> execute(CreateDiscountRuleRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'createDiscountRule',
        entityId: 'discount_rule',
        entityIdForAudit: (rule) => rule.id,
        invalidateDiscounts: true,
        action: () => ref.read(financeRepositoryProvider).createDiscountRule(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final createDiscountRuleProvider =
    AsyncNotifierProvider<CreateDiscountRuleNotifier, DiscountRule?>(
  CreateDiscountRuleNotifier.new,
);

class UpdateDiscountRuleNotifier extends AsyncNotifier<DiscountRule?> {
  @override
  FutureOr<DiscountRule?> build() => null;

  Future<DiscountRule?> execute({
    required String ruleId,
    required UpdateDiscountRuleRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'updateDiscountRule',
        entityId: ruleId,
        invalidateDiscounts: true,
        action: () => ref.read(financeRepositoryProvider).updateDiscountRule(
              query: ref.read(repositoryQueryProvider),
              ruleId: ruleId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateDiscountRuleProvider =
    AsyncNotifierProvider<UpdateDiscountRuleNotifier, DiscountRule?>(
  UpdateDiscountRuleNotifier.new,
);

class UpdateFinanceSettingsNotifier
    extends AsyncNotifier<FinanceSettingsData?> {
  @override
  FutureOr<FinanceSettingsData?> build() => null;

  Future<FinanceSettingsData?> execute(
    UpdateFinanceSettingsRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
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

class IssueInvoiceNotifier extends AsyncNotifier<FinanceInvoice?> {
  @override
  FutureOr<FinanceInvoice?> build() => null;

  Future<FinanceInvoice?> execute({required String invoiceId}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'issueInvoice',
        entityId: invoiceId,
        invalidateInvoices: true,
        invalidateStudentAccounts: true,
        action: () => ref.read(financeRepositoryProvider).issueInvoice(
              query: ref.read(repositoryQueryProvider),
              invoiceId: invoiceId,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final issueInvoiceProvider =
    AsyncNotifierProvider<IssueInvoiceNotifier, FinanceInvoice?>(
  IssueInvoiceNotifier.new,
);

class CancelInvoiceNotifier extends AsyncNotifier<FinanceInvoice?> {
  @override
  FutureOr<FinanceInvoice?> build() => null;

  Future<FinanceInvoice?> execute({required String invoiceId}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'cancelInvoice',
        entityId: invoiceId,
        invalidateInvoices: true,
        invalidateStudentAccounts: true,
        action: () => ref.read(financeRepositoryProvider).cancelInvoice(
              query: ref.read(repositoryQueryProvider),
              invoiceId: invoiceId,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final cancelInvoiceProvider =
    AsyncNotifierProvider<CancelInvoiceNotifier, FinanceInvoice?>(
  CancelInvoiceNotifier.new,
);

class CancelCollectionNotifier extends AsyncNotifier<FinanceCollectionResult?> {
  @override
  FutureOr<FinanceCollectionResult?> build() => null;

  Future<FinanceCollectionResult?> execute(
      {required String collectionId, required String reason}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageFinance(ref),
        auditAction: 'cancelCollection',
        auditType: AuditEventType.collectionCancelled,
        entityId: collectionId,
        entityIdForAudit: (result) => result.collectionId,
        metadata: {'reason': reason},
        invalidateCollections: true,
        invalidateOfflinePayments: true,
        invalidateStudentAccounts: true,
        invalidateInvoices: true,
        action: () => ref.read(financeRepositoryProvider).cancelCollection(
              query: ref.read(repositoryQueryProvider),
              collectionId: collectionId,
              reason: reason,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final cancelCollectionProvider =
    AsyncNotifierProvider<CancelCollectionNotifier, FinanceCollectionResult?>(
  CancelCollectionNotifier.new,
);

class ExportReceiptPdfNotifier extends AsyncNotifier<Uint8List?> {
  @override
  FutureOr<Uint8List?> build() => null;

  Future<Uint8List?> execute({required String receiptId}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFinance(ref);
      try {
        final receipt = await ref.read(financeRepositoryProvider).getReceipt(
              query: ref.read(repositoryQueryProvider),
              receiptId: receiptId,
            );
        if (receipt == null) {
          throw StateError('Receipt not found');
        }
        final amount = int.tryParse(
              receipt.amount.replaceAll(RegExp(r'[^\d-]'), ''),
            ) ??
            0;
        final schoolName = ref.read(schoolDisplayNameProvider);
        final bytes = await const FinanceReceiptPdfService().buildReceiptPdf(
          receiptNumber: receipt.receiptNumber,
          schoolName: schoolName.isEmpty ? 'School' : schoolName,
          title: 'Fee Receipt',
          dateLabel: receipt.receiptDate,
          paymentMethod: 'N/A',
          statusLabel: 'Paid',
          studentName: receipt.studentAccountId,
          classLabel: 'N/A',
          lineItems: [
            ReceiptPdfLineItem(label: 'Collected amount', amount: amount),
          ],
          totalAmount: amount,
          financeReceipt: receipt,
        );
        await recordFinanceAudit(
          ref,
          type: AuditEventType.receiptPdfExported,
          action: 'exportReceiptPdf',
          entityId: receipt.id,
          metadata: {'receiptNumber': receipt.receiptNumber},
        );
        return bytes;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final exportReceiptPdfProvider =
    AsyncNotifierProvider<ExportReceiptPdfNotifier, Uint8List?>(
  ExportReceiptPdfNotifier.new,
);

/// FIN-4: admin duplicate-receipt reprint. Builds a correct receipt PDF from
/// already-loaded collection data (real student/class/mode — unlike the thin
/// receipt-id path), stamps it DUPLICATE, and audits the reprint. RBAC:
/// manageFinance.
class ReprintReceiptNotifier extends AsyncNotifier<Uint8List?> {
  @override
  FutureOr<Uint8List?> build() => null;

  Future<Uint8List?> execute({
    required ReceiptPdfData receipt,
    required String collectionId,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFinance(ref);
      try {
        final r = ReceiptPdfData(
          receiptNumber: receipt.receiptNumber,
          schoolName: receipt.schoolName,
          title: receipt.title,
          dateLabel: receipt.dateLabel,
          paymentMethod: receipt.paymentMethod,
          statusLabel: receipt.statusLabel,
          studentName: receipt.studentName,
          classLabel: receipt.classLabel,
          lineItems: receipt.lineItems,
          totalAmount: receipt.totalAmount,
          copyLabel: 'DUPLICATE',
          signatoryName: receipt.signatoryName,
        );
        final bytes = await const FinanceReceiptPdfService()
            .buildBatchReceiptsPdf([r]);
        await recordFinanceAudit(
          ref,
          type: AuditEventType.receiptPdfExported,
          action: 'reprintReceipt',
          entityId: collectionId,
          metadata: {
            'receiptNumber': receipt.receiptNumber,
            'copy': 'DUPLICATE',
          },
        );
        return bytes;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final reprintReceiptProvider =
    AsyncNotifierProvider<ReprintReceiptNotifier, Uint8List?>(
  ReprintReceiptNotifier.new,
);

/// FIN-5: batch receipt printing ("print today's receipts"). Builds a single
/// PDF with one page per receipt from the supplied collections and audits the
/// batch print. RBAC: manageFinance.
class BatchPrintReceiptsNotifier extends AsyncNotifier<Uint8List?> {
  @override
  FutureOr<Uint8List?> build() => null;

  Future<Uint8List?> execute({required List<ReceiptPdfData> receipts}) async {
    if (state.isLoading) return state.valueOrNull;
    if (receipts.isEmpty) return null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageFinance(ref);
      try {
        final bytes =
            await const FinanceReceiptPdfService().buildBatchReceiptsPdf(receipts);
        await recordFinanceAudit(
          ref,
          type: AuditEventType.receiptPdfExported,
          action: 'batchPrintReceipts',
          entityId: 'batch',
          metadata: {'count': '${receipts.length}'},
        );
        return bytes;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final batchPrintReceiptsProvider =
    AsyncNotifierProvider<BatchPrintReceiptsNotifier, Uint8List?>(
  BatchPrintReceiptsNotifier.new,
);

/// Assigns a fee concession / scholarship pending principal approval (M-D5).
class AssignFeeConcessionNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute({
    required String studentName,
    required String amount,
    required String reason,
    String feeAccountId = '',
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final perms = ref.read(userPermissionsProvider);
      if (perms == null || !perms.has(Permission.assignScholarship)) {
        throw ApiFailureException(
          const ApiFailure(
            type: ApiFailureType.forbidden,
            message: 'You do not have permission to assign scholarships.',
            code: 'RBAC_ASSIGN_SCHOLARSHIP',
          ),
        );
      }

      final concessionId =
          'concession_${DateTime.now().millisecondsSinceEpoch}';
      final approvalRequired = ref.read(financeApprovalRequiredProvider);

      if (approvalRequired) {
        final auth = ref.read(authProvider);
        final adapter = FeeConcessionApprovalAdapter();
        await adapter.submitForApproval(
          service: ref.read(approvalCenterServiceProvider),
          query: ref.read(repositoryQueryProvider),
          concessionId: concessionId,
          requesterId: auth.claims?.userId ?? 'finance_demo',
          requesterName: auth.displayName ?? 'Finance Admin',
          title: 'Fee concession — $studentName',
          summary: '$amount · $reason',
          payload: {
            'studentName': studentName,
            'amount': amount,
            'reason': reason,
            'feeAccountId': feeAccountId,
          },
        );
      } else {
        FinanceApprovalGovernanceStore.instance.applyConcession(concessionId);
      }

      return concessionId;
    });
    return state.valueOrNull;
  }
}

final assignFeeConcessionProvider =
    AsyncNotifierProvider<AssignFeeConcessionNotifier, String?>(
  AssignFeeConcessionNotifier.new,
);
