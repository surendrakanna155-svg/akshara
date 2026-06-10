import 'package:akshara_erp/core/repositories/academic/academic_repository.dart';
import 'package:akshara_erp/core/repositories/academic/api/academic_api_paths.dart';
import 'package:akshara_erp/core/repositories/academic/api/academic_mapper.dart';
import 'package:akshara_erp/core/repositories/academic/api/academic_remote_data_source.dart';
import 'package:akshara_erp/core/repositories/academic/api/api_academic_repository.dart';
import 'package:akshara_erp/core/repositories/academic/api/dto/academic_catalog_response_dto.dart';
import 'package:akshara_erp/core/repositories/academic/api/dto/academic_class_dto.dart';
import 'package:akshara_erp/core/repositories/academic/api/dto/academic_section_dto.dart';
import 'package:akshara_erp/core/repositories/academic/api/dto/academic_teacher_assignment_dto.dart';
import 'package:akshara_erp/core/repositories/academic/api/dto/academic_year_dto.dart';
import 'package:akshara_erp/core/repositories/academic/hybrid_academic_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_academic_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Academic client alignment', () {
    test('catalog paths match deployed routes', () {
      expect(AcademicApiPaths.years, '/academic/years');
      expect(AcademicApiPaths.classes, '/academic/classes');
      expect(AcademicApiPaths.sections, '/academic/sections');
      expect(
        AcademicApiPaths.teacherAssignments,
        '/academic/teacher-assignments',
      );
    });

    test('year DTO coerces numeric JSON fields', () {
      final dto = AcademicClassDto.fromJson({
        'classId': 'class-1',
        'academicYearId': 'year-1',
        'className': '5',
        'displayOrder': 5.0,
        'status': 'active',
      });
      expect(dto.displayOrder, 5);
    });

    test('year DTO maps camelCase contract fields', () {
      final dto = AcademicYearDto.fromJson({
        'yearId': 'year-1',
        'yearLabel': '2026-27',
        'startDate': '2026-04-01',
        'endDate': '2027-03-31',
        'isCurrent': true,
        'status': 'active',
      });

      expect(dto.yearId, 'year-1');
      expect(dto.yearLabel, '2026-27');
      expect(dto.isCurrent, isTrue);
    });

    test('year DTO normalizes en-dash labels from API payloads', () {
      final dto = AcademicYearDto.fromJson({
        'yearId': 'year-1',
        'yearLabel': '2026–27',
        'startDate': '2026-04-01',
        'endDate': '2027-03-31',
        'isCurrent': true,
        'status': 'active',
      });
      expect(dto.yearLabel, '2026-27');
    });

    test('catalog list envelope parses nested data.items', () {
      final response = AcademicCatalogResponseDto.classes({
        'data': {
          'items': [
            {
              'classId': 'class-1',
              'academicYearId': 'year-1',
              'className': '5',
              'displayOrder': 5,
              'status': 'active',
            },
          ],
          'pagination': {
            'page': 1,
            'pageSize': 20,
            'total': 1,
            'hasMore': false,
          },
        },
      });

      expect(response.items, hasLength(1));
      expect(response.items.first.className, '5');
    });

    test('mapper converts DTOs to domain models', () {
      const mapper = AcademicMapper();
      final year = mapper.toYear(
        AcademicYearDto.fromJson({
          'yearId': 'year-1',
          'yearLabel': '2026-27',
          'startDate': '2026-04-01',
          'endDate': '2027-03-31',
          'isCurrent': true,
          'status': 'active',
        }),
      );
      final section = mapper.toSection(
        AcademicSectionDto.fromJson({
          'sectionId': 'sec-1',
          'classId': 'class-1',
          'className': '5',
          'sectionName': 'A',
          'capacity': 40,
          'strength': 32,
          'status': 'active',
        }),
      );
      final assignment = mapper.toTeacherAssignment(
        AcademicTeacherAssignmentDto.fromJson({
          'assignmentId': 'assign-1',
          'teacherId': 'teacher-1',
          'teacherName': 'Staging Teacher A',
          'classId': 'class-1',
          'className': '5',
          'sectionId': 'sec-1',
          'sectionName': 'A',
          'role': 'class_teacher',
          'isPrimary': true,
        }),
      );

      expect(year.yearLabel, '2026-27');
      expect(section.sectionName, 'A');
      expect(assignment.teacherName, 'Staging Teacher A');
    });

    test('hybrid and mock repositories implement AcademicRepository', () {
      final hybrid = HybridAcademicRepository(
        api: ApiAcademicRepository(
          remote: AcademicRemoteDataSource(Dio()),
        ),
      );
      expect(hybrid, isA<AcademicRepository>());
      expect(MockAcademicRepository(), isA<AcademicRepository>());
    });
  });
}
