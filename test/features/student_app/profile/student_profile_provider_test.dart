import 'package:akshara_erp/features/student_app/profile/student_profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('studentProfile providers', () {
    test('studentProfileProvider exposes student and parent details', () async {
      final container = createMobileProviderTestContainer();
      addTearDown(container.dispose);

      await container.read(studentProfileFutureProvider.future);
      final data = container.read(studentProfileProvider);

      expect(data.studentName, 'Ravi Kumar');
      expect(data.classLabel, '8-A');
      expect(data.parentContacts, hasLength(2));
      expect(data.academicSummary, isNotEmpty);
      expect(data.initials, 'RK');
    });
  });
}
