import 'package:akshara_erp/core/repositories/academic/academic_year_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeAcademicYearLabel', () {
    test('maps en-dash and em-dash to hyphen', () {
      expect(normalizeAcademicYearLabel('2026–27'), '2026-27');
      expect(normalizeAcademicYearLabel('2026—27'), '2026-27');
      expect(normalizeAcademicYearLabel('2026-27'), '2026-27');
    });

    test('academicYearLabelsEqual is dash-insensitive', () {
      expect(academicYearLabelsEqual('2026–27', '2026-27'), isTrue);
      expect(academicYearLabelsEqual('2025–26', '2025-26'), isTrue);
    });

    test('resolveAcademicYearSelection prefers canonical catalog label', () {
      expect(
        resolveAcademicYearSelection('2026–27', const ['2026-27', '2025-26']),
        '2026-27',
      );
      expect(
        resolveAcademicYearSelection('2024-25', const ['2026-27']),
        '2026-27',
      );
      expect(resolveAcademicYearSelection('2026–27', const []), '2026-27');
    });
  });
}
