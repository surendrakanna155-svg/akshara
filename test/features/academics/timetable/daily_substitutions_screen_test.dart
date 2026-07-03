import 'package:akshara_erp/core/repositories/interfaces/timetable_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/academics/timetable/substitutions/daily_substitutions_screen.dart';
import 'package:akshara_erp/features/academics/timetable/timetable_models.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controllable fake that only implements the methods the substitutions screen
/// exercises. Records create/delete calls so tests can assert wiring.
class _FakeTimetableRepository implements TimetableRepository {
  _FakeTimetableRepository({this.busy = false});

  final bool busy;
  final List<TimetableSubstitution> store = [];
  final List<TimetableTeacherOnLeave> onLeave = [];
  final List<CreateSubstitutionRequest> createCalls = [];
  final List<String> deleteCalls = [];
  var _seq = 0;

  @override
  Future<DailySubstitutionsBundle> listSubstitutions({
    required RepositoryQuery query,
    required String date,
  }) async {
    return DailySubstitutionsBundle(
      date: date,
      substitutions: List.of(store),
      onLeave: List.of(onLeave),
    );
  }

  @override
  Future<TimetableSubstitution> createSubstitution({
    required RepositoryQuery query,
    required CreateSubstitutionRequest request,
  }) async {
    createCalls.add(request);
    if (busy) throw const SubstituteBusyException('Already teaching this period.');
    _seq += 1;
    final sub = TimetableSubstitution(
      id: 'sub_$_seq',
      periodId: request.periodId,
      subDate: request.subDate,
      substituteTeacherId: request.substituteTeacherId,
      periodNumber: 1,
      subjectLabel: 'Mathematics',
    );
    store.add(sub);
    return sub;
  }

  @override
  Future<void> deleteSubstitution({
    required RepositoryQuery query,
    required String id,
  }) async {
    deleteCalls.add(id);
    store.removeWhere((s) => s.id == id);
  }

  @override
  Future<TimetableDetail> getTimetable({
    required RepositoryQuery query,
    required String timetableId,
  }) async {
    return TimetableDetail(
      timetable: TimetableEntry(
        id: timetableId,
        academicYearId: 'y',
        sectionId: 's',
        status: TimetableStatus.published,
        version: 1,
        periodsPerDay: 6,
        daysPerWeek: 5,
        updatedAt: DateTime(2026, 7, 3),
      ),
      periods: const [
        TimetablePeriod(
          id: 'period_1',
          timetableId: 'tt',
          dayOfWeek: 1,
          periodNumber: 1,
          subjectLabel: 'Mathematics',
          roomLabel: 'Room 201',
          teacherId: 'HR-EMP-101',
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

Widget _app(TimetableRepository repo) {
  return ProviderScope(
    overrides: [
      timetableRepositoryProvider.overrideWithValue(repo),
      repositoryQueryProvider.overrideWithValue(RepositoryQuery.demo),
      userPermissionsProvider.overrideWithValue(
        UserPermissions.forRole(ErpRole.superAdmin),
      ),
    ],
    child: MaterialApp(
      theme: AksharaAppTheme.light(),
      home: const DailySubstitutionsScreen(),
    ),
  );
}

/// Opens the Add-cover sheet and fills the period + a named substitute teacher.
Future<void> _fillCoverForm(WidgetTester tester, {String teacher = 'Priya Sharma'}) async {
  await tester.tap(find.byKey(QaTestKeys.dailySubstitutionsAddButton));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(QaTestKeys.dailySubstitutionsPeriodPicker));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Day 1 · P1 · Mathematics').last);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(QaTestKeys.dailySubstitutionsTeacherPicker));
  await tester.pumpAndSettle();
  await tester.tap(find.text(teacher).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on-leave teachers come from the server response', (tester) async {
    final repo = _FakeTimetableRepository()
      ..onLeave.add(const TimetableTeacherOnLeave(teacherId: 'HR-EMP-101'));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('On approved leave:'), findsOneWidget);
  });

  testWidgets('empty state shown when no cover assigned', (tester) async {
    final repo = _FakeTimetableRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('No cover assigned for this day yet.'), findsOneWidget);
  });

  testWidgets('creating a substitution calls the repo and it appears in the list',
      (tester) async {
    final repo = _FakeTimetableRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _fillCoverForm(tester);

    await tester.tap(find.byKey(QaTestKeys.dailySubstitutionsSaveButton));
    await tester.pumpAndSettle();

    expect(repo.createCalls, hasLength(1));
    expect(repo.createCalls.single.periodId, 'period_1');
    expect(
      find.byKey(QaTestKeys.dailySubstitutionsCreatedSnackbar),
      findsOneWidget,
    );
    // The newly-created cover is re-listed and rendered.
    expect(
      find.byKey(QaTestKeys.dailySubstitutionRow('sub_1')),
      findsOneWidget,
    );
  });

  testWidgets('SUBSTITUTE_BUSY surfaces a friendly inline error', (tester) async {
    final repo = _FakeTimetableRepository(busy: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _fillCoverForm(tester);

    await tester.tap(find.byKey(QaTestKeys.dailySubstitutionsSaveButton));
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.dailySubstitutionsBusyError), findsOneWidget);
    expect(find.text('Already teaching this period.'), findsOneWidget);
  });

  testWidgets('deleting a substitution calls the repo and removes the row',
      (tester) async {
    final repo = _FakeTimetableRepository()
      ..store.add(const TimetableSubstitution(
        id: 'sub_existing',
        periodId: 'period_1',
        subDate: '2026-07-03',
        substituteTeacherId: 'HR-EMP-102',
        periodNumber: 1,
        subjectLabel: 'Mathematics',
      ));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(
      find.byKey(QaTestKeys.dailySubstitutionRow('sub_existing')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(QaTestKeys.dailySubstitutionDeleteButton('sub_existing')),
    );
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, contains('sub_existing'));
    expect(
      find.byKey(QaTestKeys.dailySubstitutionsDeletedSnackbar),
      findsOneWidget,
    );
    expect(
      find.byKey(QaTestKeys.dailySubstitutionRow('sub_existing')),
      findsNothing,
    );
  });
}
