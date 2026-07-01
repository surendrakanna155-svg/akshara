import 'package:akshara_erp/core/exams/exam_administration_requests.dart';
import 'package:akshara_erp/core/exams/exam_administration_store.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/academics/exam_admin/exam_marks_entry_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  setUp(() {
    ExamAdministrationStore.instance.reset();
    ExamAdministrationStore.instance.ensureSeeded();
  });

  group('examMarksEntry providers', () {
    test('loads marks roster for seeded exam', () async {
      final container = ProviderContainer(overrides: providerTestOverrides());
      addTearDown(container.dispose);

      final marks =
          await container.read(examMarksListProvider('exam_math_8a').future);
      expect(marks, isNotEmpty);
    });

    test('updateMark saves valid score', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      final pending = await container
          .read(examMarksListProvider('exam_math_8a').future);
      final target = pending.firstWhere((mark) => mark.marksObtained == null);

      await container.read(examMarksMutationProvider.notifier).updateMark(
            markEntryId: target.id,
            marksObtained: 35,
          );

      final refreshed =
          await container.read(examMarksListProvider('exam_math_8a').future);
      final updated = refreshed.firstWhere((mark) => mark.id == target.id);
      expect(updated.marksObtained, 35);
    });

    test('processResults fails when marks incomplete', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container
            .read(examMarksMutationProvider.notifier)
            .processResults('exam_math_8a'),
        throwsA(isA<Object>()),
      );
    });

    // EXM-1 — fast bulk marks save.
    test('bulkSaveMarks persists changed rows + reports failures', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.principal),
          ),
        ],
      );
      addTearDown(container.dispose);

      final pending = await container
          .read(examMarksListProvider('exam_math_8a').future);
      final open = pending.firstWhere((m) => m.marksObtained == null);

      final result = await container
          .read(examMarksMutationProvider.notifier)
          .bulkSaveMarks(
            examId: 'exam_math_8a',
            entries: [
              BulkExamMarkEntry(markEntryId: open.id, marksObtained: 29),
              const BulkExamMarkEntry(
                markEntryId: 'missing-id',
                marksObtained: 5,
              ),
            ],
          );
      expect(result.savedCount, 1);
      expect(result.failedCount, 1);

      final refreshed = await container
          .read(examMarksListProvider('exam_math_8a').future);
      expect(refreshed.firstWhere((m) => m.id == open.id).marksObtained, 29);
    });

    test('bulkSaveMarks is denied without manageExamMarks', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.parent),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(examMarksMutationProvider.notifier).bulkSaveMarks(
              examId: 'exam_math_8a',
              entries: const [
                BulkExamMarkEntry(markEntryId: 'x', marksObtained: 10),
              ],
            ),
        throwsA(isA<Object>()),
      );
    });

    // EXM-2 — marks-entry progress board provider.
    test('examMarksEntryProgressProvider lists exams awaiting marks', () async {
      final container = ProviderContainer(overrides: providerTestOverrides());
      addTearDown(container.dispose);

      final rows =
          await container.read(examMarksEntryProgressProvider.future);
      final math = rows.firstWhere((r) => r.examId == 'exam_math_8a');
      expect(math.pending, greaterThanOrEqualTo(1));
      expect(math.enteredCount, math.totalCount - math.pending);
    });
  });
}
