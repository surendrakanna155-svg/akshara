import 'package:akshara_erp/features/parent/events/events_models.dart';
import 'package:akshara_erp/features/parent/events/parent_events_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('parentEventsProvider', () {
    test('returns upcoming and past events', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentEventsFutureProvider.future);
      final data = container.read(parentEventsProvider);

      expect(data.childName, 'Ravi Kumar');
      expect(data.upcomingEvents, isNotEmpty);
      expect(data.pastEvents, isNotEmpty);
    });

    test('parentEventSectionProvider defaults to upcoming', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      expect(
        container.read(parentEventSectionProvider),
        EventSection.upcoming,
      );
    });

    test('parentEventsEmptyProvider clears both sections', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      container.read(parentEventsEmptyProvider.notifier).state = true;
      final data = container.read(parentEventsProvider);

      expect(data.upcomingEvents, isEmpty);
      expect(data.pastEvents, isEmpty);
    });
  });
}
