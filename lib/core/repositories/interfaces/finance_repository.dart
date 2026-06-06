import '../../../features/finance/finance_models.dart';

/// Contract for finance data access (mock or API).
abstract class FinanceRepository {
  FinanceDashboardData getDashboard();
  List<CollectionPayment> getCollections();
  DailyCollectionSummary getDailySummary();
  List<FinanceFeeStructure> getFeeStructures(String academicYear);
  List<String> getAcademicYears();
  List<StudentFeeAccount> getStudentAccounts();
  List<InstallmentPlan> getInstallmentPlans();

  CollectionDetail? getCollectionDetail(String collectionId);
  DefaultersDashboardData getDefaultersDashboard();
  List<RefundRequest> getRefundRequests();
  DiscountsDashboardData getDiscountsDashboard();
  FinanceReportsData getReportsData();
  FinanceSettingsData getSettings();
}
