import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/communication/parent_communication_models.dart';
import 'package:akshara_erp/core/i18n/supported_languages.dart';
import 'package:akshara_erp/core/repositories/api/parent/dto/parent_communication_dto.dart';
import 'package:akshara_erp/core/repositories/api/parent/mapper/parent_mapper.dart';

void main() {
  group('ParentMapper communication inbox', () {
    const mapper = ParentMapper();

    test('maps inbox response DTO to domain items', () {
      final dto = ParentCommunicationInboxResponseDto.fromJson({
        'success': true,
        'data': {
          'items': [
            {
              'id': 'comm_1',
              'sisStudentId': 'SIS-STU-10430',
              'studentName': 'Ravi Kumar',
              'senderName': 'Priya Sharma',
              'reasonLabel': 'Low attendance',
              'originalMessage': 'English body',
              'translatedMessage': 'Telugu body',
              'targetLanguage': 'te',
              'channels': ['inApp'],
              'sentAt': '2026-06-15T10:00:00.000Z',
              'sentAtLabel': 'Just now',
              'deliveryStatus': 'delivered',
              'isUnread': true,
            },
          ],
        },
      });

      final items = mapper.toCommunicationInbox(dto);
      expect(items, hasLength(1));
      expect(items.first.id, 'comm_1');
      expect(items.first.targetLanguage, AksharaLanguage.telugu);
      expect(items.first.channels, contains(ParentCommunicationChannel.inApp));
      expect(items.first.isUnread, isTrue);
    });
  });
}
