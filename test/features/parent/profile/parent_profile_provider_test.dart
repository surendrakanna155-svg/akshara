import 'package:akshara_erp/features/parent/profile/parent_profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('parentProfileProvider', () {
    test('returns mock parent profile', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentProfileFutureProvider.future);
      final data = container.read(parentProfileProvider);

      expect(data.parentName, 'Suresh Kumar');
      expect(data.schoolName, 'NIKSHA Public School');
      expect(data.children.length, 2);
    });

    test('parentProfileActiveChildProvider updates active child', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(parentProfileFutureProvider.future);
      container.read(parentProfileActiveChildProvider.notifier).state =
          'child_ananya';
      await container.read(parentProfileFutureProvider.future);
      final data = container.read(parentProfileProvider);

      expect(
        data.children.singleWhere((child) => child.isActive).name,
        'Ananya Kumar',
      );
    });
  });
}
