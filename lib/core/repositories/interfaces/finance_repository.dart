import '../../../features/finance/finance_models.dart';
import '../../../features/finance/finance_requests.dart';
import '../repository_query.dart';

/// Contract for finance data access (mock or API).
abstract class FinanceRepository {
  Future<FinanceDashboardData> getDashboard({required RepositoryQuery query});
  Future<List<CollectionPayment>> getCollections({required RepositoryQuery query});
  Future<DailyCollectionSummary> getDailySummary({required RepositoryQuery query});
  Future<List<FinanceFeeStructure>> getFeeStructures({required RepositoryQuery query, required String academicYear});
  Future<List<String>> getAcademicYears({required RepositoryQuery query});
  Future<List<StudentFeeAccount>> getStudentAccounts({required RepositoryQuery query});
  Future<List<InstallmentPlan>> getInstallmentPlans({required RepositoryQuery query});

  Future<CollectionDetail?> getCollectionDetail({required RepositoryQuery query, required String collectionId});
  Future<DefaultersDashboardData> getDefaultersDashboard({required RepositoryQuery query});
  Future<List<RefundRequest>> getRefundRequests({required RepositoryQuery query});
  Future<DiscountsDashboardData> getDiscountsDashboard({required RepositoryQuery query});
  Future<FinanceReportsData> getReportsData({required RepositoryQuery query});
  Future<FinanceSettingsData> getSettings({required RepositoryQuery query});

  Future<FinanceFeeStructure> createFeeStructure({
    required RepositoryQuery query,
    required CreateFeeStructureRequest request,
  });

  Future<FinanceFeeStructure> updateFeeStructure({
    required RepositoryQuery query,
    required String feeStructureId,
    required UpdateFeeStructureRequest request,
  });

  Future<StudentFeeAccount> createStudentAccount({
    required RepositoryQuery query,
    required CreateStudentAccountRequest request,
  });

  Future<StudentFeeAccount> updateStudentAccount({
    required RepositoryQuery query,
    required String accountId,
    required UpdateStudentAccountRequest request,
  });

  Future<StudentFeeAccount> assignFeePlan({
    required RepositoryQuery query,
    required AssignFeePlanRequest request,
  });

  Future<RefundRequest> createRefund({
    required RepositoryQuery query,
    required CreateRefundRequest request,
  });

  Future<RefundRequest> approveRefund({
    required RepositoryQuery query,
    required String refundId,
    ApproveRefundRequest request = const ApproveRefundRequest(),
  });

  Future<ScholarshipCatalogItem> createScholarship({
    required RepositoryQuery query,
    required CreateScholarshipRequest request,
  });

  Future<ScholarshipCatalogItem> updateScholarship({
    required RepositoryQuery query,
    required String scholarshipId,
    required UpdateScholarshipRequest request,
  });

  Future<FinanceSettingsData> updateSettings({
    required RepositoryQuery query,
    required UpdateFinanceSettingsRequest request,
  });
}
