import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/communication/parent_communication_models.dart';
import '../../../core/communication/parent_communication_store.dart';
import '../../../core/communication/teacher_parent_templates.dart';
import 'teacher_teaching_context_provider.dart';
import '../../../core/i18n/supported_languages.dart';
import '../../../core/i18n/translation_service.dart';
import '../../../core/repositories/mock/mock_canonical_student_registry.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../notifications/notifications_provider.dart';
import '../teacher_requests.dart';

final teacherCommunicationSourceConcernProvider =
    StateProvider<String?>((ref) => null);

final teacherCanSendParentCommunicationProvider = Provider<bool>((ref) {
  return ref.watch(resolvedTeacherTeachingContextProvider).isClassTeacher;
});

final teacherCommunicationStudentsProvider =
    Provider<List<CanonicalStudentRecord>>((ref) {
  final context = ref.watch(resolvedTeacherTeachingContextProvider);
  if (context.isClassTeacher) {
    return MockCanonicalStudentRegistry.forClass(
      context.classTeacherGrade!,
      context.classTeacherSection!,
    );
  }
  return MockCanonicalStudentRegistry.all
      .where((s) => context.teachingClassLabels.contains(s.classLabel))
      .toList(growable: false);
});

final teacherCommunicationReasonProvider =
    StateProvider<ParentCommunicationReason>(
  (ref) => ParentCommunicationReason.attendanceLow,
);

final teacherCommunicationToneProvider =
    StateProvider<ParentCommunicationTone>(
  (ref) => ParentCommunicationTone.polite,
);

final teacherCommunicationChannelsProvider =
    StateProvider<Set<ParentCommunicationChannel>>(
  (ref) => {ParentCommunicationChannel.inApp},
);

final teacherCommunicationSelectedStudentProvider =
    StateProvider<String?>((ref) => null);

final teacherCommunicationPreviewProvider = Provider<String>((ref) {
  final reason = ref.watch(teacherCommunicationReasonProvider);
  final tone = ref.watch(teacherCommunicationToneProvider);
  final studentId = ref.watch(teacherCommunicationSelectedStudentProvider);
  final student = studentId == null
      ? null
      : MockCanonicalStudentRegistry.byId(studentId);
  return TeacherParentTemplates.resolve(
    reason: reason,
    tone: tone,
    studentName: student?.studentName ?? 'your child',
  );
});

final teacherCommunicationTranslationPreviewProvider =
    Provider<TranslatedMessagePair>((ref) {
  final english = ref.watch(teacherCommunicationPreviewProvider);
  final studentId = ref.watch(teacherCommunicationSelectedStudentProvider);
  final language = studentId == null
      ? AksharaLanguage.english
      : ParentCommunicationStore.instance
          .preferredLanguageForStudent(studentId);
  return TranslationService.instance.pair(
    englishText: english,
    target: language,
  );
});

Future<ParentCommunicationSendResult?> sendTeacherParentCommunication(
  WidgetRef ref, {
  String? customMessage,
  bool useAi = false,
  String? sourceConcernId,
}) async {
  return ref.read(sendTeacherParentCommunicationProvider.notifier).execute(
        customMessage: customMessage,
        useAi: useAi,
        sourceConcernId: sourceConcernId,
      );
}

class SendTeacherParentCommunicationNotifier
    extends AsyncNotifier<ParentCommunicationSendResult?> {
  @override
  FutureOr<ParentCommunicationSendResult?> build() => null;

  Future<ParentCommunicationSendResult?> execute({
    String? customMessage,
    bool useAi = false,
    String? sourceConcernId,
  }) async {
    final studentId = ref.read(teacherCommunicationSelectedStudentProvider);
    if (studentId == null) return null;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final concernId =
          sourceConcernId ?? ref.read(teacherCommunicationSourceConcernProvider);
      return ref.read(teacherRepositoryProvider).sendParentCommunication(
            query: ref.read(repositoryQueryProvider),
            teachingContext: ref.read(resolvedTeacherTeachingContextProvider),
            request: TeacherParentCommunicationSendRequest(
              sisStudentId: studentId,
              reason: ref.read(teacherCommunicationReasonProvider),
              tone: ref.read(teacherCommunicationToneProvider),
              channels: ref.read(teacherCommunicationChannelsProvider),
              customMessage: customMessage,
              useAi: useAi,
              sourceConcernId: concernId,
            ),
          );
    });
    ref.invalidate(pendingSubjectConcernsProvider);
    ref.invalidate(notificationsProvider);
    return state.valueOrNull;
  }
}

final sendTeacherParentCommunicationProvider = AsyncNotifierProvider<
    SendTeacherParentCommunicationNotifier,
    ParentCommunicationSendResult?>(SendTeacherParentCommunicationNotifier.new);

final studentCommunicationTimelineProvider =
    Provider.family<List<ParentCommunicationRecord>, String>((ref, studentId) {
  return ParentCommunicationStore.instance.timelineForStudent(studentId);
});
