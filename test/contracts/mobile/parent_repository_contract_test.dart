import 'package:akshara_erp/core/repositories/api/parent/api_parent_repository.dart';
import 'package:akshara_erp/core/repositories/api/parent/dto/parent_responses_dto.dart';
import 'package:akshara_erp/core/repositories/api/parent/mapper/parent_mapper.dart';
import 'package:akshara_erp/core/repositories/api/parent/remote/parent_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parent_fixture_builder.dart';

const kQuery = RepositoryQuery.demo;
const _fixtures = ParentFixtureBuilder();
const _mapper = ParentMapper();

void main() {
  group('Parent repository contract', () {
    late MockParentRepository mockRepo;
    late ApiParentRepository apiRepo;

    setUp(() {
      mockRepo = MockParentRepository();
      apiRepo = ApiParentRepository(
        remote: ParentRemoteDataSource(Dio()),
        mapper: _mapper,
      );
    });

    test('mock and api implement ParentRepository', () {
      expect(mockRepo, isA<ParentRepository>());
      expect(apiRepo, isA<ParentRepository>());
    });

    test('getDashboard DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getDashboard(query: kQuery);
      final mapped = _mapper.toDashboard(
        ParentDashboardDto.fromJson(_fixtures.dashboardEnvelope(mockData)),
      );
      expect(mapped.childName, mockData.childName);
      expect(mapped.quickActions.length, mockData.quickActions.length);
    });

    test('getAttendance DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getAttendance(
        query: kQuery,
        month: DateTime(2026, 6, 1),
      );
      final mapped = _mapper.toAttendance(
        ParentAttendanceResponseDto.fromJson(
          _fixtures.attendanceEnvelope(mockData),
        ),
      );
      expect(mapped.kpi.attendancePercent, mockData.kpi.attendancePercent);
      expect(mapped.calendarDays.length, mockData.calendarDays.length);
    });

    test('getHomework DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getHomework(query: kQuery);
      final mapped = _mapper.toHomework(
        ParentHomeworkResponseDto.fromJson(
          _fixtures.homeworkEnvelope(mockData),
        ),
      );
      expect(mapped.items.length, mockData.items.length);
    });

    test('getExams DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getExams(query: kQuery);
      final mapped = _mapper.toExams(
        ParentExamsResponseDto.fromJson(_fixtures.examsEnvelope(mockData)),
      );
      expect(mapped.upcomingExams.length, mockData.upcomingExams.length);
    });

    test('getTimetable DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getTimetable(query: kQuery);
      final mapped = _mapper.toTimetable(
        ParentTimetableResponseDto.fromJson(
          _fixtures.timetableEnvelope(mockData),
        ),
      );
      expect(mapped.days.length, mockData.days.length);
    });

    test('getFees DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getFees(query: kQuery);
      final mapped = _mapper.toFees(
        ParentFeesResponseDto.fromJson(_fixtures.feesEnvelope(mockData)),
      );
      expect(mapped.pendingAmount, mockData.pendingAmount);
    });

    test('getReceipts DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getReceipts(query: kQuery);
      final mapped = _mapper.toReceipts(
        ParentReceiptsResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final receipt in mockData) _fixtures.receiptItem(receipt),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getFeeCertificate DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getFeeCertificate(
        query: kQuery,
        academicYear: '2025-2026',
      );
      final mapped = _mapper.toFeeCertificate(
        ParentFeeCertificateResponseDto.fromJson(
          _fixtures.feeCertificateEnvelope(mockData),
        ),
      );
      expect(mapped.studentName, mockData.studentName);
      expect(mapped.academicYear, mockData.academicYear);
      expect(mapped.totalPaidAmount, mockData.totalPaidAmount);
      expect(mapped.payments.length, mockData.payments.length);
      expect(mapped.signatoryTitle, mockData.signatoryTitle);
      expect(mapped.publicStudentId, mockData.publicStudentId);
      expect(mapped.admissionNumber, mockData.admissionNumber);
    });

    test('getFeeCertificate is a ParentRepository contract member', () {
      expect(mockRepo.getFeeCertificate, isA<Function>());
      expect(apiRepo.getFeeCertificate, isA<Function>());
    });

    test('getNotices DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getNotices(query: kQuery);
      final mapped = _mapper.toNotices(
        ParentNoticesResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final notice in mockData) _fixtures.noticeItem(notice),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getEvents DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getEvents(query: kQuery);
      final mapped = _mapper.toEvents(
        ParentEventsResponseDto.fromJson(_fixtures.eventsEnvelope(mockData)),
      );
      expect(mapped.upcomingEvents.length, mockData.upcomingEvents.length);
    });

    test('getLeaveHistory DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getLeaveHistory(query: kQuery);
      final mapped = _mapper.toLeaveHistory(
        ParentLeaveResponseDto.fromJson(
          _fixtures.listEnvelope([
            for (final request in mockData) _fixtures.leaveItem(request),
          ]),
        ),
      );
      expect(mapped.length, mockData.length);
    });

    test('getProfile DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getProfile(
        query: kQuery,
        activeChildId: 'child_ravi',
      );
      final mapped = _mapper.toProfile(
        ParentProfileResponseDto.fromJson(
          _fixtures.profileEnvelope(mockData),
        ),
      );
      expect(mapped.children.length, mockData.children.length);
    });

    test('getPaymentSummary DTO mapping matches mock output', () async {
      final mockData = await mockRepo.getPaymentSummary(
        query: kQuery,
        installmentId: 'term_2',
      );
      final mapped = _mapper.toPaymentSummary(
        ParentPaymentSummaryResponseDto.fromJson(
          _fixtures.paymentSummaryEnvelope(mockData),
        ),
      );
      expect(mapped.installmentId, mockData.installmentId);
      expect(mapped.totalAmount, mockData.totalAmount);
    });
  });
}
