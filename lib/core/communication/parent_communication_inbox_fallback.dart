import 'parent_communication_models.dart';
import '../repositories/mock/mock_canonical_student_registry.dart';
import 'parent_communication_store.dart';

/// Resolves parent communication inbox from the in-memory store (API fallback).
abstract final class ParentCommunicationInboxFallback {
  static String profileChildId(String activeChildId) {
    return activeChildId.replaceAll('-', '_');
  }

  static CanonicalStudentRecord? studentForChild(String activeChildId) {
    final profileId = profileChildId(activeChildId);
    return MockCanonicalStudentRegistry.byParentChildId(profileId) ??
        MockCanonicalStudentRegistry.byParentChildId(activeChildId) ??
        MockCanonicalStudentRegistry.primaryMobileStudent;
  }

  static List<ParentCommunicationInboxItem> inboxForChild(String activeChildId) {
    final student = studentForChild(activeChildId);
    if (student == null) return const [];
    return ParentCommunicationStore.instance.inboxForStudent(student.sisStudentId);
  }

  static ParentCommunicationInboxItem? messageById(String communicationId) {
    return ParentCommunicationStore.instance.inboxItemById(communicationId);
  }

  static void markRead(String communicationId) {
    ParentCommunicationStore.instance.markRead(communicationId);
  }

  static void acknowledge(String communicationId) {
    ParentCommunicationStore.instance.markAcknowledged(communicationId);
  }
}
