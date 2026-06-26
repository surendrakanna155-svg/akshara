import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/parent/leave/leave_models.dart';
import 'package:akshara_erp/features/parent/leave/parent_leave_provider.dart';
import 'package:akshara_erp/features/parent/parent_active_child_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('parentLeaveProvider', () {
    test('returns mock leave history with active-child header', () async {
      // PAR-9: header reflects the active child, not a hardcoded demo student.
      final container = createMobileProviderTestContainer(
        overrides: [
          parentActiveChildProvider.overrideWithValue(
            const LinkedChild(id: 'child-ravi', name: 'Ravi Kumar', classLabel: '8-A'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(parentLeaveHistoryFutureProvider.future);
      final data = container.read(parentLeaveDataProvider);

      expect(data.history, isNotEmpty);
      expect(data.childName, 'Ravi Kumar');
    });

    test('leaveApplyDraft is invalid until required fields are set', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      expect(container.read(leaveApplyDraftProvider).isValid, isFalse);

      container.read(leaveApplyDraftProvider.notifier).state = const LeaveApplyDraft(
        fromDateLabel: '12 Jun 2026',
        toDateLabel: '12 Jun 2026',
        reason: 'Doctor advised rest for one day.',
      );

      expect(container.read(leaveApplyDraftProvider).isValid, isTrue);
    });

    test('parentLeaveEmptyProvider clears history', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(parentLeaveEmptyProvider.notifier).state = true;

      expect(container.read(parentLeaveHistoryProvider), isEmpty);
    });
  });
}
