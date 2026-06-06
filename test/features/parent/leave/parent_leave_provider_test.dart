import 'package:akshara_erp/features/parent/leave/leave_models.dart';
import 'package:akshara_erp/features/parent/leave/parent_leave_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parentLeaveProvider', () {
    test('returns mock leave history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(parentLeaveDataProvider);

      expect(data.history, isNotEmpty);
      expect(data.childName, 'Ravi Kumar');
    });

    test('leaveApplyDraft is invalid until required fields are set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(leaveApplyDraftProvider).isValid, isFalse);

      container.read(leaveApplyDraftProvider.notifier).state = const LeaveApplyDraft(
        fromDateLabel: '12 Jun 2026',
        toDateLabel: '12 Jun 2026',
        reason: 'Doctor advised rest for one day.',
      );

      expect(container.read(leaveApplyDraftProvider).isValid, isTrue);
    });

    test('parentLeaveEmptyProvider clears history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(parentLeaveEmptyProvider.notifier).state = true;

      expect(container.read(parentLeaveHistoryProvider), isEmpty);
    });
  });
}
