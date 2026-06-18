import 'package:akshara_erp/core/exams/exam_administration_requests.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_admin_models.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_administration_provider.dart';
import 'package:akshara_erp/features/education/education_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  setUp(() {
    ExamAdministrationStore.instance.reset();
  });

  group('examAdministration providers', () {
    test('list provider returns seeded exams', () async {
      final container = ProviderContainer(overrides: providerTestOverrides());
      addTearDown(container.dispose);

      final exams = await container.read(examAdministrationListProvider.future);
      expect(exams, isNotEmpty);
      expect(exams.any((exam) => exam.id == 'exam_math_8a'), isTrue);
    });

    test('mutation notifier creates and schedules exam', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      final created = await container
          .read(examAdminMutationProvider.notifier)
          .createExam(
            const CreateExamAdministrationRequest(
              title: 'Half-Yearly English',
              subject: 'English',
              grade: '8',
              section: 'B',
              termLabel: 'Term 2',
              dateLabel: '20 Jun 2026',
              timeLabel: '9:00 AM',
              venueLabel: 'Room 8B',
              syllabusLabel: 'Prose',
              maxMarks: 80,
              examType: EduExamType.halfYearly,
            ),
          );

      expect(created.phase, ExamLifecyclePhase.draft);

      final scheduled = await container
          .read(examAdminMutationProvider.notifier)
          .scheduleExam(created.id);
      expect(scheduled.phase, ExamLifecyclePhase.scheduled);

      final marksOpen = await container
          .read(examAdminMutationProvider.notifier)
          .openMarksEntry(created.id);
      expect(marksOpen.phase, ExamLifecyclePhase.marksEntry);
    });

    test('phase filter narrows list', () async {
      final container = ProviderContainer(overrides: providerTestOverrides());
      addTearDown(container.dispose);

      await container.read(examAdministrationListProvider.future);
      container.read(examAdminPhaseFilterProvider.notifier).state =
          ExamAdminPhaseFilter.scheduled;

      final filtered =
          container.read(examAdminFilteredListProvider).valueOrNull ?? [];
      expect(filtered.every((exam) => exam.phase == ExamLifecyclePhase.scheduled),
          isTrue);
      expect(filtered.any((exam) => exam.id == 'exam_science_8a'), isTrue);
    });
  });
}
