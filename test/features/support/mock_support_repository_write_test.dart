import 'package:akshara_erp/core/repositories/mock/mock_support_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/support/domain/support_delivery_failure.dart';
import 'package:akshara_erp/features/support/domain/support_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// P0 regression: the in-memory support repository used to fabricate a
/// `SUP-<n>` reference on create. A user on the shipping build was shown a
/// real-looking ticket number for a report that was never sent, never stored,
/// and that Akshara Support never saw.
///
/// The rule these tests lock down: a mock may stand in for READING data it does
/// not have; it may never stand in for DELIVERING something to a human.
void main() {
  const query = RepositoryQuery.demo;

  group('MockSupportRepository — writes never pretend', () {
    test('createIncident throws notConfigured instead of minting a reference',
        () async {
      final repo = MockSupportRepository();

      await expectLater(
        repo.createIncident(
          query: query,
          input: const CreateSupportIncidentInput(
            title: 'Fee receipt PDF opens blank',
            description: 'Blank every time.',
          ),
        ),
        throwsA(
          isA<SupportDeliveryFailure>().having(
            (e) => e.reason,
            'reason',
            SupportDeliveryFailureReason.notConfigured,
          ),
        ),
      );
    });

    test('a failed create stores nothing — the list is unchanged', () async {
      final repo = MockSupportRepository();
      final before = await repo.listIncidents(query: query);

      try {
        await repo.createIncident(
          query: query,
          input: const CreateSupportIncidentInput(
            title: 'Ghost report',
            description: '',
          ),
        );
        fail('createIncident must throw');
      } on SupportDeliveryFailure {
        // expected
      }

      final after = await repo.listIncidents(query: query);
      expect(after.total, before.total);
      expect(
        after.items.where((i) => i.title == 'Ghost report'),
        isEmpty,
        reason: 'a report that was never delivered must not appear anywhere',
      );
    });

    test('postMessage throws notConfigured', () async {
      final repo = MockSupportRepository();
      final seeded = (await repo.listIncidents(query: query)).items.first;

      await expectLater(
        repo.postMessage(
          query: query,
          incidentId: seeded.id,
          body: 'any update?',
        ),
        throwsA(
          isA<SupportDeliveryFailure>().having(
            (e) => e.reason,
            'reason',
            SupportDeliveryFailureReason.notConfigured,
          ),
        ),
      );

      // …and the undelivered message is not in the conversation.
      final detail = await repo.getIncident(query: query, incidentId: seeded.id);
      expect(
        detail.messages.where((m) => m.body == 'any update?'),
        isEmpty,
      );
    });

    test('uploadAttachment throws notConfigured', () async {
      final repo = MockSupportRepository();
      final seeded = (await repo.listIncidents(query: query)).items.first;

      await expectLater(
        repo.uploadAttachment(
          query: query,
          incidentId: seeded.id,
          kind: AttachmentKind.screenshot,
          fileName: 'shot.png',
          contentType: 'image/png',
          bytes: const [1, 2, 3],
        ),
        throwsA(
          isA<SupportDeliveryFailure>().having(
            (e) => e.reason,
            'reason',
            SupportDeliveryFailureReason.notConfigured,
          ),
        ),
      );
    });
  });

  group('MockSupportRepository — reads still serve demo data', () {
    test('listIncidents returns the seeded lifecycle spread', () async {
      final repo = MockSupportRepository();
      final result = await repo.listIncidents(query: query);
      expect(result.items, isNotEmpty);
      expect(
        result.items.map((i) => i.status).toSet().length,
        greaterThan(1),
        reason: 'the seed exists so the UI exercises more than one state',
      );
    });

    test('getIncident returns a full detail for a seeded incident', () async {
      final repo = MockSupportRepository();
      final seeded = (await repo.listIncidents(query: query)).items.first;
      final detail =
          await repo.getIncident(query: query, incidentId: seeded.id);
      expect(detail.incident.id, seeded.id);
      expect(detail.events, isNotEmpty);
    });

    test('filtering by status still works', () async {
      final repo = MockSupportRepository();
      final resolved = await repo.listIncidents(
        query: query,
        status: SupportStatus.resolved,
      );
      expect(
        resolved.items.every((i) => i.status == SupportStatus.resolved),
        isTrue,
      );
    });
  });
}
