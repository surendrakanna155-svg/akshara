import 'package:akshara_erp/core/repositories/api/communication/api_communication_repository.dart';
import 'package:akshara_erp/core/repositories/api/communication/hybrid_communication_repository.dart';
import 'package:akshara_erp/core/repositories/api/communication/remote/communication_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/interfaces/communication_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_communication_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client↔repository parity: every [CommunicationRepository] impl (api, mock,
/// hybrid) implements the COM-1/COM-2/COM-3/COM-D1 surfaces. The api + hybrid
/// impls are asserted structurally (they compile as `CommunicationRepository`,
/// which forces the new abstract overrides); the mock impl is exercised for its
/// in-memory parity behaviour.
void main() {
  const query = RepositoryQuery(tenantId: 'tenant-1', schoolId: 'school-1');

  test('all three impls satisfy the CommunicationRepository contract', () {
    final CommunicationRepository mock = MockCommunicationRepository();
    final CommunicationRepository api = ApiCommunicationRepository(
      remote: CommunicationRemoteDataSource(Dio()),
    );
    final CommunicationRepository hybrid = HybridCommunicationRepository(
      api: ApiCommunicationRepository(
        remote: CommunicationRemoteDataSource(Dio()),
      ),
      mock: MockCommunicationRepository(),
      useApi: false,
    );

    expect(mock, isA<CommunicationRepository>());
    expect(api, isA<CommunicationRepository>());
    expect(hybrid, isA<CommunicationRepository>());
  });

  group('MockCommunicationRepository in-memory parity', () {
    test('audience segments: seeded, create adds, delete removes', () async {
      final repo = MockCommunicationRepository();
      final before = await repo.listAudienceSegments(query: query);
      expect(before, isNotEmpty);

      final created = await repo.createAudienceSegment(
        query: query,
        name: 'Grade 9 parents',
        audienceType: 'class_parents',
        className: '9',
        sectionName: 'B',
      );
      expect(created.name, 'Grade 9 parents');

      final after = await repo.listAudienceSegments(query: query);
      expect(after.length, before.length + 1);

      await repo.deleteAudienceSegment(query: query, id: created.id);
      final finalList = await repo.listAudienceSegments(query: query);
      expect(finalList.any((s) => s.id == created.id), isFalse);
    });

    test('report derives counts from the sent broadcast', () async {
      final repo = MockCommunicationRepository();
      final result = await repo.sendBroadcast(
        query: query,
        request: const BroadcastRequest(
          audience: 'all_parents',
          title: 'Fee alert',
          body: 'Clear dues',
          requiresAck: true,
        ),
      );
      expect(result.status, 'sent');

      final report = await repo.getBroadcastReport(
        query: query,
        broadcastId: result.broadcastId,
      );
      expect(report.counts.total, result.recipientCount);
      expect(report.requiresAck, isTrue);
      expect(report.counts.sent + report.counts.failed, report.counts.total);
      expect(report.counts.read + report.counts.unread, report.counts.sent);
    });

    test('scheduled broadcast is SCHEDULED, not sent', () async {
      final repo = MockCommunicationRepository();
      final result = await repo.sendBroadcast(
        query: query,
        request: BroadcastRequest(
          audience: 'all_parents',
          title: 'PTM',
          body: 'Friday',
          scheduledAt:
              DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        ),
      );
      expect(result.status, 'scheduled');
    });

    test('resend returns the unread count', () async {
      final repo = MockCommunicationRepository();
      final result = await repo.sendBroadcast(
        query: query,
        request: const BroadcastRequest(
          audience: 'all_parents',
          title: 'Fee alert',
          body: 'Clear dues',
        ),
      );
      final resent = await repo.resendBroadcastToUnread(
        query: query,
        broadcastId: result.broadcastId,
      );
      expect(resent, greaterThanOrEqualTo(0));
    });

    test('acknowledge is a no-op that does not throw', () async {
      final repo = MockCommunicationRepository();
      await expectLater(
        repo.acknowledgeNotification(query: query, deliveryId: 'd1'),
        completes,
      );
    });
  });
}
