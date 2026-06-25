import 'package:akshara_erp/core/communication/parent_communication_models.dart';
import 'package:akshara_erp/core/communication/parent_communication_store.dart';
import 'package:akshara_erp/core/communication/teacher_parent_templates.dart';
import 'package:akshara_erp/core/i18n/supported_languages.dart';
import 'package:akshara_erp/core/i18n/translation_service.dart';
import 'package:akshara_erp/core/repositories/mock/mock_canonical_student_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    ParentCommunicationStore.instance.reset();
  });

  group('TranslationService', () {
    test('translates attendance template to Telugu without AI', () {
      const english =
          'Your child was absent from school today. Kindly ensure regular attendance and inform the school if there are any concerns.';
      final translated = TranslationService.instance.translate(
        englishText: english,
        target: AksharaLanguage.telugu,
      );
      expect(translated, isNot(english));
      expect(translated, contains('పిల్లవాడు'));
    });

    test('returns English unchanged for English target', () {
      const text = 'Hello parent';
      expect(
        TranslationService.instance.translate(
          englishText: text,
          target: AksharaLanguage.english,
        ),
        text,
      );
    });
  });

  group('TeacherParentTemplates', () {
    test('resolves predefined templates without AI', () {
      final message = TeacherParentTemplates.resolve(
        reason: ParentCommunicationReason.attendanceLow,
        tone: ParentCommunicationTone.polite,
      );
      expect(message, isNotEmpty);
      expect(message.toLowerCase(), isNot(contains('ai')));
    });
  });

  group('ParentCommunicationStore', () {
    test('sends in-app message with translation', () {
      final student = MockCanonicalStudentRegistry.primaryMobileStudent;
      final result = ParentCommunicationStore.instance.send(
        request: ParentCommunicationSendRequest(
          sisStudentId: student.sisStudentId,
          reason: ParentCommunicationReason.attendanceLow,
          tone: ParentCommunicationTone.polite,
          channels: {ParentCommunicationChannel.inApp},
        ),
        senderName: 'Priya Sharma',
      );

      expect(result.record.usedAi, isFalse);
      expect(result.record.translatedMessage, isNotEmpty);
      expect(result.record.originalMessage, isNotEmpty);
      expect(
        ParentCommunicationStore.instance
            .timelineForStudent(student.sisStudentId),
        hasLength(1),
      );
    });

    test('builds WhatsApp URI with parent phone', () {
      final result = ParentCommunicationStore.instance.send(
        request: const ParentCommunicationSendRequest(
          sisStudentId: MockCanonicalStudentRegistry.primaryMobileStudentId,
          reason: ParentCommunicationReason.feeReminder,
          tone: ParentCommunicationTone.friendlyReminder,
          channels: {ParentCommunicationChannel.whatsApp},
        ),
        senderName: 'Priya Sharma',
        parentPhone: '919876543210',
      );

      expect(result.whatsAppLaunchUri, startsWith('https://wa.me/919876543210'));
    });
  });
}
