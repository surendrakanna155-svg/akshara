import 'package:akshara_erp/core/repositories/api/admissions/dto/enrollment_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/dto/create_fee_structure_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/admissions_conversion_request_dto.dart';
import 'package:akshara_erp/core/repositories/api/sis/dto/enrollment_request_dto.dart';
import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/admissions_requests.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_requests.dart';
import 'package:akshara_erp/features/sis/sis_requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('5C.3 soft FK dual-write payloads', () {
    test('admissions submit includes catalog FK ids in academic block', () {
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
          academicYearId: 'year-1',
          classId: 'class-5',
          sectionId: 'section-a',
        ),
      );

      final academic =
          EnrollmentRequestDto.submit(request).toJson()['academic']
              as Map<String, dynamic>;

      expect(academic['seeking_class'], '5');
      expect(academic['academic_year'], '2026-27');
      expect(academic['academic_year_id'], 'year-1');
      expect(academic['class_id'], 'class-5');
      expect(academic['section_id'], 'section-a');
    });

    test('SIS enrollment create dual-writes catalog ids', () {
      final json = EnrollmentCreateRequestDto.fromAcademicAssignment(
        const AcademicAssignmentRequest(
          studentId: 'student-1',
          classLabel: '5',
          section: 'A',
          academicYear: '2026-27',
          academicYearId: 'year-1',
          classId: 'class-5',
          sectionId: 'section-a',
        ),
      ).toJson();

      expect(json['className'], '5');
      expect(json['academic_year_id'], 'year-1');
      expect(json['classId'], 'class-5');
      expect(json['section_id'], 'section-a');
    });

    test('SIS conversion dual-writes catalog ids', () {
      final json = AdmissionsConversionRequestDto.fromDomain(
        const AdmissionsConversionRequest(
          enrollmentId: 'enr-1',
          classLabel: '5',
          section: 'A',
          academicYear: '2026-27',
          academicYearId: 'year-1',
          classId: 'class-5',
        ),
      ).toJson();

      expect(json['academicYearId'], 'year-1');
      expect(json['class_id'], 'class-5');
    });

    test('finance create dual-writes academic_year_id', () {
      final json = CreateFeeStructureRequestDto.fromDomain(
        const CreateFeeStructureRequest(
          name: 'Primary Fees',
          academicYear: '2026-27',
          totalAnnual: '145000',
          classRange: '1-5',
          categories: [
            FeeCategoryLine(
              category: FeeStructureCategory.tuition,
              label: 'Tuition',
              amount: '145000',
            ),
          ],
          academicYearId: 'year-1',
        ),
      ).toJson();

      expect(json['academic_year'], '2026-27');
      expect(json['academic_year_id'], 'year-1');
      expect(json['academicYearId'], 'year-1');
    });
  });
}
