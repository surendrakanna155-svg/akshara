import 'package:akshara_erp/core/repositories/academic/academic_catalog_mutation.dart';
import 'package:akshara_erp/core/repositories/academic/academic_models.dart';
import 'package:akshara_erp/core/repositories/api/admissions/dto/enrollment_request_dto.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/admissions_requests.dart';
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
    ],
    classes: [
      AcademicClass(
        classId: 'class-5',
        academicYearId: 'year-1',
        className: '5',
        displayOrder: 1,
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

  group('Admissions enrollment catalog regression', () {
    test('submit payload retains text fields and adds resolved FK ids', () {
      const request = EnrollmentSubmitRequest(
        student: EnrollmentStudentProfile(
          fullName: 'Aarav Sharma',
          dateOfBirth: '2015-03-12',
          gender: 'Male',
          aadhaar: '1234-5678-9012',
        ),
        parent: EnrollmentParentInfo(
          guardianName: 'Parent Sharma',
          relationship: 'Father',
          phone: '9876543210',
        ),
        academic: EnrollmentAcademicInfo(
          seekingClass: '5',
          section: 'A',
          academicYear: '2026-27',
        ),
      );

      final enriched = enrichEnrollmentSubmitRequest(request, catalog);
      final json = EnrollmentRequestDto.submit(enriched).toJson();
      final academic = json['academic'] as Map<String, dynamic>;

      expect(academic['seeking_class'], '5');
      expect(academic['section'], 'A');
      expect(academic['academic_year'], '2026-27');
      expect(academic['academic_year_id'], 'year-1');
      expect(academic['class_id'], 'class-5');
      expect(academic['section_id'], 'section-a');
    });
  });
}
