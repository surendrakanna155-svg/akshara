import 'package:akshara_erp/features/student/profile/student_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('studentProfile providers', () {
    test('studentProfileProvider exposes student and parent details', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final data = container.read(studentProfileProvider);

      expect(data.studentName, 'Ravi Kumar');
      expect(data.classLabel, '8-A');
      expect(data.parentContacts, hasLength(2));
      expect(data.academicSummary, isNotEmpty);
      expect(data.initials, 'RK');
    });
  });
}
