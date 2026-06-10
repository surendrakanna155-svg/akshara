import '../academic/academic_models.dart';
import '../academic/academic_repository.dart';
import '../pagination_helpers.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Mock academic catalog — mirrors legacy SIS assignment dropdown data.
class MockAcademicRepository implements AcademicRepository {
  static const _classNames = [
    'Nursery',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];

  static const _sectionNames = ['A', 'B', 'C', 'D'];

  static const _yearLabels = ['2026–27', '2025–26', '2024–25'];

  static const _yearId = 'mock-year-current';
  static const _yearIds = [
    'mock-year-2026',
    'mock-year-2025',
    'mock-year-2024',
  ];

  static final List<AcademicClass> _classes = [
    for (var i = 0; i < _classNames.length; i++)
      AcademicClass(
        classId: 'mock-class-${_classNames[i]}',
        academicYearId: _yearId,
        className: _classNames[i],
        displayOrder: i,
        status: 'active',
      ),
  ];

  static final List<AcademicSection> _sections = [
    for (final classItem in _classes)
      for (final sectionName in _sectionNames)
        AcademicSection(
          sectionId: 'mock-section-${classItem.className}-$sectionName',
          classId: classItem.classId,
          className: classItem.className,
          sectionName: sectionName,
          capacity: 40,
          strength: 32,
          status: 'active',
        ),
  ];

  static final List<AcademicYear> _years = [
    for (var i = 0; i < _yearLabels.length; i++)
      AcademicYear(
        yearId: _yearIds[i],
        yearLabel: _yearLabels[i],
        startDate: '202${6 - i}-04-01',
        endDate: '202${7 - i}-03-31',
        isCurrent: i == 0,
        status: 'active',
      ),
  ];

  static final List<AcademicTeacherAssignment> _teacherAssignments = [
    const AcademicTeacherAssignment(
      assignmentId: 'mock-assignment-1',
      teacherId: 'mock-teacher-1',
      teacherName: 'Staging Teacher A',
      classId: 'mock-class-5',
      className: '5',
      sectionId: 'mock-section-5-A',
      sectionName: 'A',
      role: 'class_teacher',
      isPrimary: true,
    ),
    const AcademicTeacherAssignment(
      assignmentId: 'mock-assignment-2',
      teacherId: 'mock-teacher-2',
      teacherName: 'Staging Teacher B',
      classId: 'mock-class-10',
      className: '10',
      sectionId: 'mock-section-10-B',
      sectionName: 'B',
      role: 'class_teacher',
      isPrimary: true,
    ),
  ];

  @override
  Future<PaginatedResult<AcademicYear>> getYears({
    required RepositoryQuery query,
  }) async {
    return paginateList(_years, query);
  }

  @override
  Future<PaginatedResult<AcademicClass>> getClasses({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    var items = _classes;
    if (academicYearId != null) {
      items = items
          .where((item) => item.academicYearId == academicYearId)
          .toList(growable: false);
    }
    return paginateList(items, query);
  }

  @override
  Future<PaginatedResult<AcademicSection>> getSections({
    required RepositoryQuery query,
    String? classId,
    String? academicYearId,
  }) async {
    var items = _sections;
    if (classId != null) {
      items = items.where((item) => item.classId == classId).toList(
            growable: false,
          );
    }
    if (academicYearId != null) {
      final classIds = _classes
          .where((item) => item.academicYearId == academicYearId)
          .map((item) => item.classId)
          .toSet();
      items = items
          .where((item) => classIds.contains(item.classId))
          .toList(growable: false);
    }
    return paginateList(items, query);
  }

  @override
  Future<PaginatedResult<AcademicTeacherAssignment>> getTeacherAssignments({
    required RepositoryQuery query,
    String? classId,
    String? sectionId,
  }) async {
    var items = _teacherAssignments;
    if (classId != null) {
      items = items.where((item) => item.classId == classId).toList(
            growable: false,
          );
    }
    if (sectionId != null) {
      items = items.where((item) => item.sectionId == sectionId).toList(
            growable: false,
          );
    }
    return paginateList(items, query);
  }
}
