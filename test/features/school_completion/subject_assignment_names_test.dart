import 'package:akshara_erp/core/repositories/academic/academic_catalog_provider.dart';
import 'package:akshara_erp/core/repositories/academic/academic_models.dart';
import 'package:akshara_erp/core/repositories/mock/mock_school_completion_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/school_completion/school_completion_models.dart';
import 'package:akshara_erp/features/school_completion/school_completion_providers.dart';
import 'package:akshara_erp/features/school_completion/subject_assignment_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Teacher/subject UUIDs the screen must NEVER render raw.
const _teacherUuid = 'a1b2c3d4-teacher-uuid';
const _subjectUuid = 'f9e8d7c6-subject-uuid';

const _catalog = AcademicCatalogData(
  years: [
    AcademicYear(
      yearId: 'year_1',
      yearLabel: '2026-27',
      startDate: '2026-04-01',
      endDate: '2027-03-31',
      isCurrent: true,
      status: 'active',
    ),
  ],
  classes: [],
  sections: [],
  teacherAssignments: [
    AcademicTeacherAssignment(
      assignmentId: 'asg_1',
      teacherId: _teacherUuid,
      teacherName: 'Priya Sharma',
      classId: 'c1',
      className: '8',
      sectionId: 's1',
      sectionName: 'A',
      role: 'subject_teacher',
      isPrimary: true,
    ),
  ],
);

const _subjects = <AcademicSubject>[
  AcademicSubject(
    id: _subjectUuid,
    subjectCode: 'MATH',
    subjectName: 'Mathematics',
    category: 'core',
    gradeLabels: [],
    status: 'active',
  ),
];

Widget _app() {
  return ProviderScope(
    overrides: [
      schoolCompletionRepositoryProvider
          .overrideWithValue(MockSchoolCompletionRepository()),
      repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
      academicCatalogFutureProvider.overrideWith((_) async => _catalog),
      subjectsProvider.overrideWith((_) async => _subjects),
      teacherSubjectAssignmentsProvider.overrideWith(
        (_) async => const [
          TeacherSubjectAssignment(
            id: 'tsa_1',
            academicYearId: 'year_1',
            teacherUserId: _teacherUuid,
            subjectId: _subjectUuid,
            periodsPerWeek: 6,
            isPrimary: true,
            status: 'active',
          ),
        ],
      ),
      subjectWorkloadProvider.overrideWith(
        (_) async => const [
          SubjectWorkloadEntry(
            teacherUserId: _teacherUuid,
            subjectId: _subjectUuid,
            totalPeriods: 6,
            assignmentCount: 1,
            isOverloaded: false,
          ),
        ],
      ),
      userPermissionsProvider.overrideWithValue(
        UserPermissions.forRole(ErpRole.superAdmin),
      ),
    ],
    child: MaterialApp(
      theme: AksharaAppTheme.light(),
      home: const SubjectAssignmentScreen(),
    ),
  );
}

Future<void> _openTeacherTab(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Teacher Allocation'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('teacher allocation list renders names, never raw UUIDs',
      (tester) async {
    await _openTeacherTab(tester);

    // Assignment row + workload row both show the resolved names.
    expect(find.textContaining('Priya Sharma'), findsWidgets);
    expect(find.textContaining('Mathematics'), findsWidgets);

    // The raw UUIDs must not appear anywhere on screen.
    expect(find.textContaining(_teacherUuid), findsNothing);
    expect(find.textContaining(_subjectUuid), findsNothing);
  });
}
