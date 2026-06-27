import 'package:akshara_erp/core/repositories/api/communication/dto/communication_dto.dart';
import 'package:akshara_erp/core/repositories/api/communication/remote/communication_api_paths.dart';
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
  });
}
