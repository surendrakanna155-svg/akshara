import 'package:akshara_erp/core/repositories/academic/academic_catalog_placement.dart';
import 'package:akshara_erp/core/repositories/academic/academic_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = AcademicCatalogData(
    years: [
      AcademicYear(
        yearId: 'year-1',
        yearLabel: '2026-27',
        startDate: '2026-04-01',
        endDate: '2027-03-31',
        isCurrent: true,
        status: 'active',
      ),
      AcademicYear(
        yearId: 'year-2',
        yearLabel: '2027-28',
        startDate: '2027-04-01',
        endDate: '2028-03-31',
        isCurrent: false,
        status: 'active',
      ),
    ],
    classes: [
      AcademicClass(
        classId: 'class-5',
        academicYearId: 'year-1',
        className: '5',
        displayOrder: 1,
        status: 'active',
      ),
      AcademicClass(
        classId: 'class-10',
        academicYearId: 'year-2',
        className: '10',
        displayOrder: 2,
        status: 'active',
      ),
    ],
    sections: [
      AcademicSection(
        sectionId: 'section-a',
        classId: 'class-5',
        className: '5',
        sectionName: 'A',
        capacity: 40,
        strength: 0,
        status: 'active',
      ),
    ],
    teacherAssignments: [],
  );

  group('resolveAcademicCatalogPlacement', () {
    test('resolves year, class, and section from labels', () {
      final placement = resolveAcademicCatalogPlacement(
        catalog,
        academicYear: '2026-27',
        className: '5',
        sectionName: 'A',
      );
      expect(placement.academicYearId, 'year-1');
      expect(placement.classId, 'class-5');
      expect(placement.sectionId, 'section-a');
    });

    test('scopes class lookup to selected year', () {
      final placement = resolveAcademicCatalogPlacement(
        catalog,
        academicYear: '2026-27',
        className: '10',
      );
      expect(placement.academicYearId, 'year-1');
      expect(placement.classId, isNull);
    });

    test('catalogPlacementJson dual-writes snake and camel keys', () {
      final json = catalogPlacementJson(
        const AcademicCatalogPlacement(
          academicYearId: 'year-1',
          classId: 'class-5',
        ),
      );
      expect(json['academic_year_id'], 'year-1');
      expect(json['academicYearId'], 'year-1');
      expect(json['class_id'], 'class-5');
      expect(json['classId'], 'class-5');
      expect(json.containsKey('section_id'), isFalse);
    });
  });
}
