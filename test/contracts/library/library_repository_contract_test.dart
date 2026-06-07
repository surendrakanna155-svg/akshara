import 'package:akshara_erp/core/repositories/api/library/api_library_repository.dart';
import 'package:akshara_erp/core/repositories/api/library/dto/library_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/library/mapper/library_mapper.dart';
import 'package:akshara_erp/core/repositories/api/library/remote/library_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/library_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_library_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'library_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = LibraryFixtureBuilder();
const _mapper = LibraryMapper();

void main() {
  group('Library repository contract', () {
    late MockLibraryRepository mockRepo;
    late ApiLibraryRepository apiRepo;

    setUp(() {
      mockRepo = MockLibraryRepository();
      apiRepo = ApiLibraryRepository(
        remote: LibraryRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement LibraryRepository', () {
      expect(mockRepo, isA<LibraryRepository>());
      expect(apiRepo, isA<LibraryRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        LibraryDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
    });

    test('getCatalog DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getCatalog(query: kQuery);
      final mapped = _mapper.toCatalog(
        LibraryCatalogResponseDto.fromJson(_fixtures.catalogEnvelope(mockData)),
      );
      expect(mapped.length, mockData.length);
      expect(mapped.first.isbn, mockData.first.isbn);
    });

    test('getIssues DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getIssues(query: kQuery);
      final mapped = _mapper.toIssues(
        LibraryIssuesResponseDto.fromJson(_fixtures.issuesEnvelope(mockData)),
      );
      expect(mapped.length, mockData.length);
    });

    test('getReturns DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReturns(query: kQuery);
      final mapped = _mapper.toReturns(
        LibraryReturnsResponseDto.fromJson(_fixtures.returnsEnvelope(mockData)),
      );
      expect(mapped.length, mockData.length);
    });

    test('getMembers DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getMembers(query: kQuery);
      final mapped = _mapper.toMembers(
        LibraryMembersResponseDto.fromJson(_fixtures.membersEnvelope(mockData)),
      );
      expect(mapped.length, mockData.length);
    });

    test('getFines DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getFines(query: kQuery);
      final mapped = _mapper.toFines(
        LibraryFinesResponseDto.fromJson(_fixtures.finesEnvelope(mockData)),
      );
      expect(mapped.fines.length, mockData.fines.length);
    });

    test('getDigitalResources DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDigitalResources(query: kQuery);
      final mapped = _mapper.toDigitalResources(
        LibraryDigitalResourcesResponseDto.fromJson(
          _fixtures.digitalResourcesEnvelope(mockData),
        ),
      );
      expect(mapped.resources.length, mockData.resources.length);
    });

    test('getReports DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReports(query: kQuery);
      final mapped = _mapper.toReports(
        LibraryReportsResponseDto.fromJson(_fixtures.reportsEnvelope(mockData)),
      );
      expect(mapped.catalog.length, mockData.catalog.length);
    });
  });
}
