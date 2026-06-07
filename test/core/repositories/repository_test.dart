import 'package:akshara_erp/core/repositories/api/admissions/api_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/api/finance/api_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_alumni_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_management_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_sis_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_hostel_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_inventory_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_hr_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_library_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_control_center_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_transport_repository.dart';
import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Repository implementations', () {
    test('MockFinanceRepository returns Phase 1 and Phase 2 data', () async {
      final repo = MockFinanceRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(6));
      expect((await repo.getCollections(query: query)), hasLength(6));
      expect((await repo.getFeeStructures(query: query, academicYear: '2026-27')), isNotEmpty);
      expect((await repo.getStudentAccounts(query: query)), hasLength(4));
      expect((await repo.getInstallmentPlans(query: query)), hasLength(4));
      expect((await repo.getCollectionDetail(query: query, collectionId: 'col_1')), isNotNull);
      expect((await repo.getDefaultersDashboard(query: query)).defaulters, isNotEmpty);
      expect((await repo.getRefundRequests(query: query)), hasLength(3));
      expect((await repo.getDiscountsDashboard(query: query)).scholarships, hasLength(3));
      expect((await repo.getReportsData(query: query)).catalog, hasLength(4));
      expect((await repo.getSettings(query: query)).sections, isNotEmpty);
    });

    test('MockAdmissionsRepository returns admissions data', () async {
      final repo = MockAdmissionsRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(6));
      expect((await repo.getLeads(query: query)), hasLength(7));
      expect((await repo.getApplications(query: query)), hasLength(6));
      expect((await repo.getDocuments(query: query)), hasLength(6));
      expect((await repo.getPendingEnrollments(query: query)), hasLength(3));
      expect((await repo.getApprovedHandoffs(query: query)), hasLength(3));
      expect((await repo.getApprovalQueue(query: query)), hasLength(3));
    });

    test('MockSisRepository returns SIS data', () async {
      final repo = MockSisRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(6));
      expect((await repo.getStudents(query: query)), hasLength(5));
      expect(
        (await repo.getAcademicAssignment(query: query)).classOptions,
        isNotEmpty,
      );
      expect(
        (await repo.getAdmissionsConversion(query: query)).queue,
        hasLength(3),
      );
    });

    test('MockManagementRepository returns all MG screen data', () async {
      final repo = MockManagementRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(6));
      expect((await repo.getAnalytics(query: query)).classSummary, hasLength(3));
      expect((await repo.getAdmissionsFunnel(query: query)).funnelStages, hasLength(5));
      expect((await repo.getFinancialHealth(query: query)).drillLinks, hasLength(6));
      expect((await repo.getAcademicHealth(query: query)).subjectPerformance, hasLength(3));
      expect((await repo.getSchoolPerformance(query: query)).classPerformance, hasLength(3));
      expect((await repo.getTasksAndApprovals(query: query)).approvals.length, greaterThan(5));
      expect((await repo.getSettings(query: query)).sections, isNotEmpty);
    });

    test('MockTransportRepository returns all TR screen data', () async {
      final repo = MockTransportRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(6));
      expect((await repo.getRoutes(query: query)), hasLength(4));
      expect((await repo.getVehicles(query: query)), hasLength(4));
      expect((await repo.getDrivers(query: query)), hasLength(4));
      expect((await repo.getAllocations(query: query)), hasLength(4));
      expect((await repo.getAttendanceRecords(query: query)), hasLength(4));
      expect((await repo.getTrackingPlaceholder(query: query)).vehicles, hasLength(3));
      expect((await repo.getReports(query: query)).catalog, hasLength(6));
      expect((await repo.getSettings(query: query)).sections, isNotEmpty);
      expect((await repo.getOccupancyMetrics(query: query)).utilizationPercent, 88);
    });

    test('MockHostelRepository returns all HO screen data', () async {
      final repo = MockHostelRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(6));
      expect((await repo.getStudents(query: query)), hasLength(4));
      expect((await repo.getRooms(query: query)), hasLength(5));
      expect((await repo.getAttendanceRecords(query: query)), hasLength(4));
      expect((await repo.getLeaveRequests(query: query)), hasLength(4));
      expect((await repo.getMessData(query: query)).weeklyMenus, hasLength(4));
      expect((await repo.getVisitors(query: query)).activeVisitors, hasLength(2));
      expect((await repo.getReports(query: query)).catalog, hasLength(6));
      expect((await repo.getOccupancyMetrics(query: query)).utilizationPercent, 87);
    });

    test('MockLibraryRepository returns all LB screen data', () async {
      final repo = MockLibraryRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(6));
      expect((await repo.getCatalog(query: query)), hasLength(6));
      expect((await repo.getIssues(query: query)), hasLength(4));
      expect((await repo.getReturns(query: query)), hasLength(4));
      expect((await repo.getMembers(query: query)), hasLength(5));
      expect((await repo.getFines(query: query)).fines, hasLength(4));
      expect((await repo.getDigitalResources(query: query)).resources, hasLength(5));
      expect((await repo.getReports(query: query)).catalog, hasLength(6));
    });

    test('MockInventoryRepository returns all INV screen data', () async {
      final repo = MockInventoryRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(6));
      expect((await repo.getAssets(query: query)), hasLength(4));
      expect((await repo.getCategories(query: query)), hasLength(4));
      expect((await repo.getAllocations(query: query)), hasLength(4));
      expect((await repo.getMaintenanceRecords(query: query)), hasLength(4));
      expect((await repo.getProcurementOrders(query: query)), hasLength(4));
      expect((await repo.getVendors(query: query)), hasLength(4));
      expect((await repo.getReports(query: query)).catalog, hasLength(6));
    });

    test('MockAlumniRepository returns all AL screen data', () async {
      final repo = MockAlumniRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(6));
      expect((await repo.getAlumniRegistry(query: query)), hasLength(5));
      expect((await repo.getAlumniDetail(query: query, alumniId: 'ALM-001')), isNotNull);
      expect((await repo.getEvents(query: query)), hasLength(4));
      expect((await repo.getDonations(query: query)), hasLength(4));
      expect((await repo.getCampaigns(query: query)), hasLength(4));
      expect((await repo.getMentorshipPairs(query: query)), hasLength(4));
      expect((await repo.getReports(query: query)).catalog, hasLength(6));
      expect((await repo.getSettings(query: query)).sections, isNotEmpty);
    });

    test('MockControlCenterRepository returns all ACC screen data', () async {
      final repo = MockControlCenterRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(7));
      expect((await repo.getSchools(query: query)), hasLength(5));
      expect((await repo.getSubscriptions(query: query)).plans, hasLength(3));
      expect((await repo.getBilling(query: query)).invoices, hasLength(3));
      expect((await repo.getCrmPipeline(query: query)).deals, hasLength(4));
      expect((await repo.getSupportTickets(query: query)), hasLength(3));
      expect((await repo.getCustomerSuccess(query: query)).schools, hasLength(3));
      expect((await repo.getWhiteLabelConfigs(query: query)), hasLength(3));
      expect((await repo.getAnalytics(query: query)).moduleUsage, hasLength(4));
      expect((await repo.getMonitoring(query: query)).services, hasLength(4));
      expect((await repo.getRoles(query: query)).roles, hasLength(4));
      expect((await repo.getSettings(query: query)).sections, isNotEmpty);
    });

    test('MockHrRepository returns all HR screen data', () async {
      final repo = MockHrRepository();
      const query = RepositoryQuery.demo;

      expect((await repo.getDashboard(query: query)).kpis, hasLength(6));
      expect((await repo.getEmployees(query: query)), hasLength(8));
      expect((await repo.getEmployeeDetail(query: query, employeeId: 'HR-EMP-101')), isNotNull);
      expect((await repo.getAttendance(query: query)).records, hasLength(6));
      expect((await repo.getLeave(query: query)).requests, hasLength(5));
      expect((await repo.getPayroll(query: query)).entries, hasLength(4));
      expect((await repo.getRecruitment(query: query)).candidates, hasLength(5));
      expect((await repo.getPerformance(query: query)).reviews, hasLength(4));
      expect((await repo.getSettings(query: query)).sections, isNotEmpty);
    });
  });

  group('Repository providers', () {
    test('providers wire mock implementations', () async {
      final container = ProviderContainer();

      expect(container.read(financeRepositoryProvider), isA<MockFinanceRepository>());
      expect(
        container.read(admissionsRepositoryProvider),
        isA<MockAdmissionsRepository>(),
      );
      expect(container.read(sisRepositoryProvider), isA<MockSisRepository>());
      expect(
        container.read(managementRepositoryProvider),
        isA<MockManagementRepository>(),
      );
      expect(
        container.read(transportRepositoryProvider),
        isA<MockTransportRepository>(),
      );
      expect(
        container.read(hostelRepositoryProvider),
        isA<MockHostelRepository>(),
      );
      expect(container.read(hrRepositoryProvider), isA<MockHrRepository>());
      expect(
        container.read(libraryRepositoryProvider),
        isA<MockLibraryRepository>(),
      );
      expect(
        container.read(inventoryRepositoryProvider),
        isA<MockInventoryRepository>(),
      );
      expect(
        container.read(alumniRepositoryProvider),
        isA<MockAlumniRepository>(),
      );
      expect(
        container.read(controlCenterRepositoryProvider),
        isA<MockControlCenterRepository>(),
      );

      container.dispose();
    });

    test('providers wire API when enableApiMode and module flags are true', () async {
      final container = ProviderContainer(
        overrides: [
          environmentProvider.overrideWith(
            (ref) => Environment.development.copyWith(enableApiMode: true),
          ),
          financeApiEnabledProvider.overrideWith((ref) => true),
          admissionsApiEnabledProvider.overrideWith((ref) => true),
        ],
      );

      expect(
        container.read(financeRepositoryProvider),
        isA<ApiFinanceRepository>(),
      );
      expect(
        container.read(admissionsRepositoryProvider),
        isA<ApiAdmissionsRepository>(),
      );

      container.dispose();
    });
  });
}
