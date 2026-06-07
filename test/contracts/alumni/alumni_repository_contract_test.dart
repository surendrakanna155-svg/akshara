import 'package:akshara_erp/core/repositories/api/alumni/api_alumni_repository.dart';
import 'package:akshara_erp/core/repositories/api/alumni/dto/alumni_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/alumni/mapper/alumni_mapper.dart';
import 'package:akshara_erp/core/repositories/api/alumni/remote/alumni_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/alumni_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_alumni_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'alumni_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = AlumniFixtureBuilder();
const _mapper = AlumniMapper();

void main() {
  group('Alumni repository contract', () {
    late MockAlumniRepository mockRepo;
    late ApiAlumniRepository apiRepo;

    setUp(() {
      mockRepo = MockAlumniRepository();
      apiRepo = ApiAlumniRepository(
        remote: AlumniRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement AlumniRepository', () {
      expect(mockRepo, isA<AlumniRepository>());
      expect(apiRepo, isA<AlumniRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        AlumniDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
    });

    test('getAlumniRegistry DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAlumniRegistry(query: kQuery);
      final mapped = _mapper.toRegistry(
        AlumniRegistryResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final record in mockData) _fixtures.recordItem(record),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
      expect(mapped.first.id, mockData.first.id);
    });

    test('getAlumniDetail DTO mapping matches mock output', () async {
      const alumniId = 'ALM-001';
      final mockDetail = await mockRepo.getAlumniDetail(
        query: kQuery,
        alumniId: alumniId,
      );
      expect(mockDetail, isNotNull);
      final mapped = _mapper.toAlumniDetail(
        AlumniDetailDto.fromJson(
          _fixtures.alumniDetailEnvelope(mockDetail!),
        ),
      );
      expect(mapped?.alumni.id, mockDetail.alumni.id);
      expect(mapped?.employmentHistory.length, mockDetail.employmentHistory.length);
    });

    test('getEvents DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getEvents(query: kQuery);
      final mapped = _mapper.toEvents(
        AlumniEventsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final event in mockData) _fixtures.eventItem(event),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getDonations DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDonations(query: kQuery);
      final mapped = _mapper.toDonations(
        AlumniDonationsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final donation in mockData) _fixtures.donationItem(donation),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getCampaigns DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getCampaigns(query: kQuery);
      final mapped = _mapper.toCampaigns(
        AlumniCampaignsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final campaign in mockData) _fixtures.campaignItem(campaign),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getMentorshipPairs DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getMentorshipPairs(query: kQuery);
      final mapped = _mapper.toMentorshipPairs(
        MentorshipPairsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final pair in mockData) _fixtures.mentorshipPairItem(pair),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getReports DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReports(query: kQuery);
      final mapped = _mapper.toReports(
        AlumniReportsResponseDto.fromJson(_fixtures.reportsEnvelope(mockData)),
      );
      expect(mapped.catalog.length, mockData.catalog.length);
    });

    test('getSettings DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSettings(query: kQuery);
      final mapped = _mapper.toSettings(
        AlumniSettingsResponseDto.fromJson(
          _fixtures.settingsEnvelope(mockData),
        ),
      );
      expect(mapped.sections.length, mockData.sections.length);
    });
  });
}
