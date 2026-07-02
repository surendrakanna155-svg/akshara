import 'package:akshara_erp/core/repositories/api/communication/dto/communication_dto.dart';
import 'package:akshara_erp/core/repositories/api/communication/remote/communication_api_paths.dart';
import 'package:akshara_erp/core/repositories/interfaces/communication_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // MJ-M12: client↔deployed-router path parity for the communication module.
  //
  // COMMU-3 root cause: the mock repository implements createTemplate /
  // updateTemplate / listBroadcastHistory, so widget tests pass even when the
  // live router lacks the route — broken journeys slipped past the gate.
  //
  // This group pins every `CommunicationApiPaths` constant to the EXACT path
  // string the deployed router registers. The Deno-side counterpart
  // (`supabase/functions/_shared/communication/communication_route_parity_test.ts`)
  // asserts the router resolves each of these same strings. Together they form a
  // two-sided contract: a future drift where the client calls a path the router
  // does not expose (or vice-versa) fails one of these tests instead of 404ing
  // live behind a mock. Keep the two literal lists in sync.
  group('Communication client↔router path parity', () {
    test('templates collection path matches deployed route', () {
      expect(CommunicationApiPaths.templates, '/communications/templates');
    });

    test('template item path matches deployed PUT route', () {
      // The client issues PUT /communications/templates/{id}; the router
      // registers PUT /communications/templates/:id (MJ-M12). Before this fix
      // the route was missing and the call 404'd live while the mock masked it.
      expect(
        CommunicationApiPaths.template('tpl-1'),
        '/communications/templates/tpl-1',
      );
    });

    test('broadcasts path matches deployed route', () {
      expect(CommunicationApiPaths.broadcasts, '/communications/broadcasts');
    });

    test('broadcast history path matches deployed route', () {
      expect(
        CommunicationApiPaths.broadcastHistory,
        '/communications/broadcasts/history',
      );
    });

    test('process-queue path matches deployed route', () {
      expect(
        CommunicationApiPaths.processQueue,
        '/communications/notifications/process-queue',
      );
    });

    test('parent notification paths match deployed routes', () {
      expect(
        CommunicationApiPaths.parentNotifications,
        '/parent/notifications',
      );
      expect(
        CommunicationApiPaths.parentMarkRead,
        '/parent/notifications/mark-read',
      );
      expect(
        CommunicationApiPaths.parentMarkAllRead,
        '/parent/notifications/mark-all-read',
      );
      expect(
        CommunicationApiPaths.parentDeviceRegister,
        '/parent/device-tokens/register',
      );
      expect(
        CommunicationApiPaths.parentDeviceUnregister,
        '/parent/device-tokens/unregister',
      );
    });

    test('student notifications path matches deployed route', () {
      expect(
        CommunicationApiPaths.studentNotifications,
        '/student/notifications',
      );
    });

    // COM-1/COM-2/COM-3/COM-D1: new surfaces pinned to the deployed router.
    test('audience-segments collection path matches deployed route', () {
      expect(
        CommunicationApiPaths.audienceSegments,
        '/communications/audience-segments',
      );
    });

    test('audience-segment item path matches deployed DELETE route', () {
      expect(
        CommunicationApiPaths.audienceSegment('seg-1'),
        '/communications/audience-segments/seg-1',
      );
    });

    test('broadcast report path matches deployed GET route', () {
      expect(
        CommunicationApiPaths.broadcastReport('b1'),
        '/communications/broadcasts/b1/report',
      );
    });

    test('broadcast resend path matches deployed POST route', () {
      expect(
        CommunicationApiPaths.broadcastResend('b1'),
        '/communications/broadcasts/b1/resend',
      );
    });

    test('notification acknowledge path matches deployed POST route', () {
      expect(
        CommunicationApiPaths.notificationAcknowledge('d1'),
        '/communications/notifications/d1/acknowledge',
      );
    });
  });

  group('CommunicationMapper', () {
    final mapper = CommunicationMapper();

    test('toNotification maps API payload', () {
      final notification = mapper.toNotification(
        CommunicationNotificationDto.fromJson({
          'id': 'n1',
          'title': 'Fee reminder',
          'preview': 'Due soon',
          'timestamp': '2026-06-10T10:00:00.000Z',
          'category': 'fee',
          'isRead': false,
          'isUrgent': true,
          'childContext': 'Ravi · 8-A',
        }),
      );
      expect(notification.id, 'n1');
      expect(notification.category.name, 'fee');
      expect(notification.isUrgent, isTrue);
    });

    test('renderTemplate variables via CommunicationTemplate mapping', () {
      final template = mapper.toTemplate(
        CommunicationTemplateDto.fromJson({
          'id': 't1',
          'code': 'fee_reminder_push',
          'channel': 'push',
          'subjectTemplate': 'Fee — {{term}}',
          'bodyTemplate': '₹{{amount}} due',
          'variables': ['term', 'amount'],
        }),
      );
      expect(template.variables, ['term', 'amount']);
    });

    // COM-D1: the notification mapper carries the ack fields.
    test('toNotification carries requiresAck + acknowledgedAt', () {
      final pending = mapper.toNotification(
        CommunicationNotificationDto.fromJson({
          'id': 'n2',
          'title': 'Exam notice',
          'preview': 'Read + confirm',
          'timestamp': '2026-06-10T10:00:00.000Z',
          'category': 'academic',
          'requiresAck': true,
          'acknowledgedAt': null,
        }),
      );
      expect(pending.requiresAck, isTrue);
      expect(pending.acknowledgedAt, isNull);
      expect(pending.needsAcknowledgement, isTrue);

      final done = mapper.toNotification(
        CommunicationNotificationDto.fromJson({
          'id': 'n3',
          'title': 'Exam notice',
          'preview': 'Read + confirm',
          'timestamp': '2026-06-10T10:00:00.000Z',
          'category': 'academic',
          'requiresAck': true,
          'acknowledgedAt': '2026-06-11T09:00:00.000Z',
        }),
      );
      expect(done.needsAcknowledgement, isFalse);
      expect(done.acknowledgedAt, isNotNull);
    });

    // COM-1: report response maps to the domain report shape.
    test('toBroadcastReport maps broadcast + counts + unread roster', () {
      final report = mapper.toBroadcastReport(
        BroadcastReportResponseDto.fromJson({
          'broadcast': {
            'id': 'b1',
            'title': 'Fee alert',
            'audience': 'all_parents',
            'status': 'sent',
            'requiresAck': true,
            'sentAt': '2026-06-10T10:00:00.000Z',
            'scheduledAt': null,
          },
          'counts': {
            'total': 40,
            'sent': 38,
            'failed': 2,
            'pending': 0,
            'read': 20,
            'unread': 18,
            'acknowledged': 10,
          },
          'unreadRecipients': [
            {'userId': 'u1', 'name': 'Ravi'},
            {'userId': 'u2', 'name': 'Meera'},
          ],
        }),
      );
      expect(report.id, 'b1');
      expect(report.requiresAck, isTrue);
      expect(report.counts.total, 40);
      expect(report.counts.acknowledged, 10);
      expect(report.unreadRecipients, hasLength(2));
      expect(report.unreadRecipients.first.name, 'Ravi');
    });

    test('toResendCount reads resent', () {
      expect(
        mapper.toResendCount(
          ResendBroadcastResponseDto.fromJson({
            'broadcastId': 'b1',
            'resent': 7,
          }),
        ),
        7,
      );
    });

    test('toAudienceSegment maps camelCase keys', () {
      final segment = mapper.toAudienceSegment(
        AudienceSegmentDto.fromJson({
          'id': 's1',
          'name': 'Grade 8 parents',
          'audienceType': 'class_parents',
          'className': '8',
          'sectionName': 'A',
        }),
      );
      expect(segment.audienceType, 'class_parents');
      expect(segment.className, '8');
      expect(segment.sectionName, 'A');
    });
  });

  group('BroadcastRequestDto.fromDomain', () {
    test('sends snake_case fields and omits nulls', () {
      final json = BroadcastRequestDto.fromDomain(
        const BroadcastRequest(
          audience: 'class_parents',
          title: 'Meeting',
          body: 'PTM on Friday',
          audienceClass: '8',
          audienceSection: 'A',
          requiresAck: true,
          scheduledAt: '2026-07-10T09:00:00.000Z',
        ),
      ).toJson();

      expect(json['audience'], 'class_parents');
      expect(json['audience_class'], '8');
      expect(json['audience_section'], 'A');
      expect(json['requires_ack'], true);
      expect(json['scheduled_at'], '2026-07-10T09:00:00.000Z');
    });

    test('omits optional fields when unset (immediate, no class)', () {
      final json = BroadcastRequestDto.fromDomain(
        const BroadcastRequest(
          audience: 'all_parents',
          title: 'Notice',
          body: 'Body',
        ),
      ).toJson();

      expect(json.containsKey('audience_class'), isFalse);
      expect(json.containsKey('audience_section'), isFalse);
      expect(json.containsKey('requires_ack'), isFalse);
      expect(json.containsKey('scheduled_at'), isFalse);
    });
  });

  group('CreateAudienceSegmentRequestDto.fromArgs', () {
    test('sends snake_case audience_type + class/section, omits empties', () {
      final json = CreateAudienceSegmentRequestDto.fromArgs(
        name: 'Grade 8 parents',
        audienceType: 'class_parents',
        className: '8',
        sectionName: '',
      ).toJson();

      expect(json['name'], 'Grade 8 parents');
      expect(json['audience_type'], 'class_parents');
      expect(json['class_name'], '8');
      expect(json.containsKey('section_name'), isFalse);
    });
  });
}
