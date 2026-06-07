import 'package:akshara_erp/core/repositories/api/admissions/api_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/admissions_applications_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/admissions_approval_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/admissions_dashboard_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/admissions_documents_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/admissions_enrollments_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/admissions_handoffs_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/admissions_leads_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/admissions_reports_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/admissions_settings_dto.dart';
import 'package:akshara_erp/core/repositories/api/admissions/mapper/admissions_mapper.dart';
import 'package:akshara_erp/core/repositories/api/admissions/remote/admissions_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';
import 'admissions_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = AdmissionsFixtureBuilder();

void main() {
  group('Admissions repository contract', () {
    late MockAdmissionsRepository mockRepo;
    late ApiAdmissionsRepository apiRepo;

    setUp(() {
      mockRepo = MockAdmissionsRepository();
      apiRepo = ApiAdmissionsRepository(
        remote: AdmissionsRemoteDataSource(Dio()),
        mapper: const AdmissionsMapper(),
      );
    });

    test('mock and api implement AdmissionsRepository', () {
      expect(mockRepo, isA<AdmissionsRepository>());
      expect(apiRepo, isA<AdmissionsRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = const AdmissionsMapper().toDashboard(
        AdmissionsDashboardDto.fromJson(
          _fixtures.dashboardEnvelope(mockData),
        ),
      );

      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
      expect(mapped.pipeline.length, mockData.pipeline.length);
      expect(mapped.followUps.length, mockData.followUps.length);
    });

    test('getLeads DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getLeads(query: kQuery);
      final dto = AdmissionsLeadsResponseDto.fromJson(
        _fixtures.listEnvelope([
          for (final lead in mockData) _fixtures.leadItem(lead),
        ]),
      );
      final mapped = const AdmissionsMapper().toLeads(dto);

      expect(mapped.length, mockData.length);
      expect(mapped.first.id, mockData.first.id);
      expect(mapped.first.studentName, mockData.first.studentName);
    });

    test('getApplications DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getApplications(query: kQuery);
      final mapped = const AdmissionsMapper().toApplications(
        AdmissionsApplicationsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final app in mockData) _fixtures.applicationItem(app),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.first.status, mockData.first.status);
    });

    test('getDocuments DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDocuments(query: kQuery);
      final mapped = const AdmissionsMapper().toDocuments(
        AdmissionsDocumentsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final doc in mockData) _fixtures.documentItem(doc),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.first.documentType, mockData.first.documentType);
    });

    test('getPendingEnrollments DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getPendingEnrollments(query: kQuery);
      final mapped = const AdmissionsMapper().toPendingEnrollments(
        AdmissionsEnrollmentsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final record in mockData) _fixtures.enrollmentItem(record),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.last.previewStudentId, mockData.last.previewStudentId);
    });

    test('getApprovedHandoffs DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getApprovedHandoffs(query: kQuery);
      final mapped = const AdmissionsMapper().toApprovedHandoffs(
        AdmissionsHandoffsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final handoff in mockData) _fixtures.handoffItem(handoff),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.first.handoffStatus, mockData.first.handoffStatus);
    });

    test('getFeeStructureOptions DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getFeeStructureOptions(query: kQuery);
      final mapped = const AdmissionsMapper().toFeeStructureOptions(
        AdmissionsFeeStructuresResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final option in mockData) _fixtures.feeStructureItem(option),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.first.label, mockData.first.label);
    });

    test('getApprovalQueue DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getApprovalQueue(query: kQuery);
      final mapped = const AdmissionsMapper().toApprovalQueue(
        AdmissionsApprovalQueueResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final item in mockData) _fixtures.approvalItem(item),
          ]),
        ),
      );

      expect(mapped.length, mockData.length);
      expect(mapped.first.aiScore, mockData.first.aiScore);
    });

    test('getReports DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReports(query: kQuery);
      final mapped = const AdmissionsMapper().toReports(
        AdmissionsReportsDto.fromJson(_fixtures.reportsEnvelope(mockData)),
      );

      expect(mapped.funnelSegments.length, mockData.funnelSegments.length);
      expect(mapped.sourceAnalysis.length, mockData.sourceAnalysis.length);
    });

    test('getSettings DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSettings(query: kQuery);
      final mapped = const AdmissionsMapper().toSettings(
        AdmissionsSettingsDto.fromJson(_fixtures.settingsEnvelope(mockData)),
      );

      expect(mapped.leadStages.length, mockData.leadStages.length);
      expect(mapped.notificationTemplates.length,
          mockData.notificationTemplates.length);
    });

    test('getEnrollmentPrefill DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getEnrollmentPrefill(query: kQuery);
      final mapped = const AdmissionsMapper().toEnrollmentPrefill(
        EnrollmentPrefillDto.fromJson(
          _fixtures.enrollmentPrefillEnvelope(mockData),
        ),
      );

      expect(mapped.student.fullName, mockData.student.fullName);
      expect(mapped.academic.seekingClass, mockData.academic.seekingClass);
    });

    test('ApiAdmissionsRepository returns mock-equivalent via fake Dio', () async {
      final mockDashboard = await mockRepo.getDashboard(query: kQuery);
      final mockLeads = await mockRepo.getLeads(query: kQuery);

      final dio = createFakeDio((options) {
        if (options.path.endsWith('/dashboard')) {
          return _fixtures.dashboardEnvelope(mockDashboard);
        }
        if (options.path.endsWith('/leads')) {
          return _fixtures.listEnvelope([
            for (final lead in mockLeads) _fixtures.leadItem(lead),
          ]);
        }
        return {'data': {}};
      });

      final api = ApiAdmissionsRepository(
        remote: AdmissionsRemoteDataSource(dio),
      );

      final dashboard = await api.getDashboard(query: kQuery);
      final leads = await api.getLeads(query: kQuery);

      expect(dashboard.kpis.length, mockDashboard.kpis.length);
      expect(leads.length, mockLeads.length);
      expect(leads.first.id, mockLeads.first.id);
    });
  });
}
