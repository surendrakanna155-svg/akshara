import 'package:akshara_erp/core/repositories/api/transport/api_transport_repository.dart';
import 'package:akshara_erp/core/repositories/api/transport/dto/transport_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/transport/mapper/transport_mapper.dart';
import 'package:akshara_erp/core/repositories/api/transport/remote/transport_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/transport_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_transport_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'transport_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = TransportFixtureBuilder();
const _mapper = TransportMapper();

void main() {
  group('Transport repository contract', () {
    late MockTransportRepository mockRepo;
    late ApiTransportRepository apiRepo;

    setUp(() {
      mockRepo = MockTransportRepository();
      apiRepo = ApiTransportRepository(
        remote: TransportRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement TransportRepository', () {
      expect(mockRepo, isA<TransportRepository>());
      expect(apiRepo, isA<TransportRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        TransportDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.kpis.length, mockData.kpis.length);
      expect(mapped.aiInsight, mockData.aiInsight);
    });

    test('getRoutes DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getRoutes(query: kQuery);
      final mapped = [
        for (final item
            in TransportRoutesResponseDto.fromJson(
              _fixtures.routesEnvelope(mockData.items),
            ).items)
          _mapper.toRoute(item),
      ];
      expect(mapped.length, mockData.items.length);
      expect(mapped.first.name, mockData.items.first.name);
    });

    test('getVehicles DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getVehicles(query: kQuery);
      final mapped = [
        for (final item
            in TransportVehiclesResponseDto.fromJson(
              _fixtures.vehiclesEnvelope(mockData),
            ).items)
          _mapper.toVehicle(item),
      ];
      expect(mapped.length, mockData.length);
    });

    test('getDrivers DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDrivers(query: kQuery);
      final mapped = [
        for (final item
            in TransportDriversResponseDto.fromJson(
              _fixtures.driversEnvelope(mockData),
            ).items)
          _mapper.toDriver(item),
      ];
      expect(mapped.length, mockData.length);
    });

    test('getAllocations DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAllocations(query: kQuery);
      final mapped = [
        for (final item
            in TransportAllocationsResponseDto.fromJson(
              _fixtures.allocationsEnvelope(mockData),
            ).items)
          _mapper.toAllocation(item),
      ];
      expect(mapped.length, mockData.length);
    });

    test('getAttendanceRecords DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAttendanceRecords(query: kQuery);
      final mapped = [
        for (final item
            in TransportAttendanceResponseDto.fromJson(
              _fixtures.attendanceEnvelope(mockData),
            ).items)
          _mapper.toAttendanceRecord(item),
      ];
      expect(mapped.length, mockData.length);
    });

    test('getTrackingPlaceholder DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getTrackingPlaceholder(query: kQuery);
      final mapped = _mapper.toTrackingPlaceholder(
        TransportTrackingDto.fromJson(_fixtures.trackingEnvelope(mockData)),
      );
      expect(mapped.vehicles.length, mockData.vehicles.length);
    });

    test('getReports DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReports(query: kQuery);
      final mapped = _mapper.toReports(
        TransportReportsDto.fromJson(_fixtures.reportsEnvelope(mockData)),
      );
      expect(mapped.catalog.length, mockData.catalog.length);
    });

    test('getSettings DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getSettings(query: kQuery);
      final mapped = _mapper.toSettings(
        TransportSettingsDto.fromJson(_fixtures.settingsEnvelope(mockData)),
      );
      expect(mapped.sections.length, mockData.sections.length);
    });

    test('getOccupancyMetrics DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getOccupancyMetrics(query: kQuery);
      final mapped = _mapper.toOccupancyMetrics(
        OccupancyMetricsDto.fromJson(
          _fixtures.occupancyMetricsEnvelope(mockData),
        ),
      );
      expect(mapped.totalCapacity, mockData.totalCapacity);
    });
  });
}
