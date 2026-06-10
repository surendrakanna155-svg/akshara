import 'package:akshara_erp/core/repositories/api/communication/dto/communication_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
