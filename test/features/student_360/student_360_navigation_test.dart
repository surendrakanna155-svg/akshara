import 'package:akshara_erp/router/phase4_navigation.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Student 360 navigation', () {
    test('student360Path builds route with student id', () {
      expect(
        student360Path('SIS-STU-10430'),
        '${RouteNames.student360}/SIS-STU-10430',
      );
    });
  });
}
