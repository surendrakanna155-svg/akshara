import 'package:akshara_erp/features/parent/profile/parent_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parentProfileProvider', () {
    test('returns mock parent profile', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(parentProfileProvider);

      expect(data.parentName, 'Suresh Kumar');
      expect(data.schoolName, 'Akshara Public School');
      expect(data.children.length, 2);
    });

    test('parentProfileActiveChildProvider updates active child', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(parentProfileActiveChildProvider.notifier).state =
          'child_ananya';
      final data = container.read(parentProfileProvider);

      expect(
        data.children.singleWhere((child) => child.isActive).name,
        'Ananya Kumar',
      );
    });
  });
}
