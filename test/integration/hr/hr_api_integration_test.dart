import 'package:akshara_erp/core/repositories/api/hr/api_hr_repository.dart';
import 'package:akshara_erp/core/repositories/api/hr/remote/hr_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/hr/remote/hr_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_hr_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/hr/hr_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/hr/hr_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = HrFixtureBuilder();

void main() {
  group('HR API integration', () {
    late MockHrRepository mockRepo;
    late Map<String, dynamic> Function(String path) responseForPath;

    setUp(() async {
      mockRepo = MockHrRepository();
      final dashboard = await mockRepo.getDashboard(query: kQuery);
      final employees = await mockRepo.getEmployees(query: kQuery);
      final detail = await mockRepo.getEmployeeDetail(
        query: kQuery,
        employeeId: employees.items.first.id,
      );
      final attendance = await mockRepo.getAttendance(query: kQuery);
      final leave = await mockRepo.getLeave(query: kQuery);
      final payroll = await mockRepo.getPayroll(query: kQuery);
      final recruitment = await mockRepo.getRecruitment(query: kQuery);
      final performance = await mockRepo.getPerformance(query: kQuery);
      final settings = await mockRepo.getSettings(query: kQuery);

      responseForPath = (path) => switch (path) {
            HrApiPaths.dashboard => _fixtures.dashboardEnvelope(dashboard),
            HrApiPaths.employees => _fixtures.listEnvelope([
                for (final employee in employees.items)
                  _fixtures.employeeItem(employee),
              ]),
            HrApiPaths.attendance => _fixtures.attendanceEnvelope(attendance),
            HrApiPaths.leave => _fixtures.leaveEnvelope(leave),
            HrApiPaths.payroll => _fixtures.payrollEnvelope(payroll),
            HrApiPaths.recruitment => _fixtures.recruitmentEnvelope(recruitment),
            HrApiPaths.performance => _fixtures.performanceEnvelope(performance),
            HrApiPaths.settings => _fixtures.settingsEnvelope(settings),
            _ when path.startsWith('${HrApiPaths.employees}/') =>
              _fixtures.employeeDetailEnvelope(detail!),
            _ => const {'data': {}},
          };
    });

    test('remote datasource fetches all HR read endpoints', () async {
      final remote = HrRemoteDataSource(
        createFakeDio((options) => responseForPath(options.path)),
      );

      expect((await remote.fetchDashboard(query: kQuery)).raw['kpis'], isNotNull);
      expect((await remote.fetchEmployees(query: kQuery)).items, isNotEmpty);
      expect(
        await remote.fetchEmployeeDetail(
          query: kQuery,
          employeeId: 'HR-EMP-101',
        ),
        isNotNull,
      );
      expect((await remote.fetchAttendance(query: kQuery)).raw['records'], isNotNull);
      expect((await remote.fetchLeave(query: kQuery)).raw['requests'], isNotNull);
      expect((await remote.fetchPayroll(query: kQuery)).raw['runs'], isNotNull);
      expect(
        (await remote.fetchRecruitment(query: kQuery)).raw['candidates'],
        isNotNull,
      );
      expect(
        (await remote.fetchPerformance(query: kQuery)).raw['reviews'],
        isNotNull,
      );
      expect((await remote.fetchSettings(query: kQuery)).raw['sections'], isNotNull);
    });

    test('api repository matches mock dashboard data', () async {
      final repository = ApiHrRepository(
        remote: HrRemoteDataSource(
          createFakeDio((options) => responseForPath(options.path)),
        ),
      );

      final mockData = await mockRepo.getDashboard(query: kQuery);
      final apiData = await repository.getDashboard(query: kQuery);

      expect(apiData.kpis.length, mockData.kpis.length);
      expect(apiData.aiInsight, mockData.aiInsight);
    });

    test('provider chain loads dashboard in api mode', () async {
      await initProviderTestPrefs();
      final container = createProviderTestContainer(
        apiHrDio: createFakeDio((options) => responseForPath(options.path)),
        hrApiEnabled: true,
      );
      addTearDown(container.dispose);

      final data = await container.read(hrDashboardFutureProvider.future);
      expect(data.kpis, isNotEmpty);
    });
  });
}
