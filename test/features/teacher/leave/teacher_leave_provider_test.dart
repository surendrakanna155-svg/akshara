import 'package:akshara_erp/features/teacher/leave/leave_models.dart';
import 'package:akshara_erp/features/teacher/leave/teacher_leave_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('teacherLeave providers', () {
    test('teacherLeaveBalanceProvider exposes leave balance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final balance = container.read(teacherLeaveBalanceProvider);

      expect(balance.casualRemaining, 6);
      expect(balance.sickRemaining, 4);
      expect(balance.earnedRemaining, 12);
    });

    test('teacherLeaveHistoryProvider exposes approval timeline', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final history = container.read(teacherLeaveHistoryProvider);

      expect(history, hasLength(2));
      expect(history.first.timeline, isNotEmpty);
      expect(history.first.status, TeacherLeaveStatus.pending);
    });

    test('teacherLeaveApplyDraftProvider validates apply form', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(teacherLeaveApplyDraftProvider).isValid, isFalse);

      container.read(teacherLeaveApplyDraftProvider.notifier).state =
          const TeacherLeaveApplyDraft(
        fromDateLabel: '18 Jun 2026',
        toDateLabel: '18 Jun 2026',
        reason: 'Medical appointment in the afternoon.',
      );

      expect(container.read(teacherLeaveApplyDraftProvider).isValid, isTrue);
    });

    test('teacherLeaveEmptyProvider clears history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(teacherLeaveEmptyProvider.notifier).state = true;
      expect(container.read(teacherLeaveHistoryProvider), isEmpty);
    });
  });
}
