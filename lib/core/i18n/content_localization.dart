import '../communication/parent_communication_store.dart';
import 'supported_languages.dart';
import 'translation_service.dart';

/// Localizes school content (notices, homework, announcements) for parent/student views.
abstract final class ContentLocalization {
  static String localize(String englishText, AksharaLanguage language) {
    return TranslationService.instance.translate(
      englishText: englishText,
      target: language,
    );
  }

  static AksharaLanguage languageForStudent(String sisStudentId) {
    return ParentCommunicationStore.instance.preferredLanguageForStudent(
      sisStudentId,
    );
  }
}
