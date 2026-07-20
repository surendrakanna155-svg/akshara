import 'package:akshara_erp/core/repositories/mock/mock_school_calendar_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/management/school_calendar/school_calendar_models.dart';
import 'package:akshara_erp/features/management/school_calendar/school_calendar_providers.dart';
import 'package:akshara_erp/features/management/school_calendar/school_calendar_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

const _demo = RepositoryQuery.demo;

CreateSchoolCalendarEventInput _holiday(String title, DateTime date) =>
    CreateSchoolCalendarEventInput(
      eventDate: date,
      title: title,
      eventType: SchoolCalendarEventType.holiday,
    );

void main() {
  group('MockSchoolCalendarRepository', () {
    test('lists, sorts and filters by event type', () async {
      final repo =
          MockSchoolCalendarRepository(store: SchoolCalendarMockStore.empty());

      await repo.createEvent(
        query: _demo,
        input: CreateSchoolCalendarEventInput(
          eventDate: DateTime(2026, 8, 15),
          title: 'Independence Day',
          eventType: SchoolCalendarEventType.holiday,
        ),
      );
      await repo.createEvent(
        query: _demo,
        input: CreateSchoolCalendarEventInput(
          eventDate: DateTime(2026, 3, 8),
          title: 'Annual Day',
          eventType: SchoolCalendarEventType.event,
        ),
      );

      final all = await repo.listEvents(query: _demo);
      expect(all, hasLength(2));
      // Sorted ascending by date (Annual Day in March before Aug holiday).
      expect(all.first.title, 'Annual Day');

      final holidays = await repo.listEvents(
        query: _demo,
        eventType: SchoolCalendarEventType.holiday,
      );
      expect(holidays, hasLength(1));
      expect(holidays.single.title, 'Independence Day');
    });
  });

  group('schoolCalendarEventsProvider (load + add + delete)', () {
    late SchoolCalendarMockStore store;
    late ProviderContainer container;

    setUp(() {
      store = SchoolCalendarMockStore.empty();
      container = ProviderContainer(
        overrides: [
          schoolCalendarRepositoryProvider.overrideWithValue(
            MockSchoolCalendarRepository(store: store),
          ),
          repositoryQueryProvider.overrideWithValue(_demo),
        ],
      );
      addTearDown(container.dispose);
    });

    test('loads empty, reflects an added event, then a delete', () async {
      // LOAD — starts empty.
      var events = await container.read(schoolCalendarEventsProvider.future);
      expect(events, isEmpty);

      // ADD — via the repository, then invalidate the read.
      final created = await container
          .read(schoolCalendarRepositoryProvider)
          .createEvent(
            query: _demo,
            input: _holiday('Republic Day', DateTime(2026, 1, 26)),
          );
      container.invalidate(schoolCalendarEventsProvider);
      events = await container.read(schoolCalendarEventsProvider.future);
      expect(events, hasLength(1));
      expect(events.single.title, 'Republic Day');
      expect(events.single.eventType, SchoolCalendarEventType.holiday);

      // DELETE — removes it.
      await container
          .read(schoolCalendarRepositoryProvider)
          .deleteEvent(query: _demo, id: created.id);
      container.invalidate(schoolCalendarEventsProvider);
      events = await container.read(schoolCalendarEventsProvider.future);
      expect(events, isEmpty);
    });

    test('type filter narrows the provider result', () async {
      final repo = container.read(schoolCalendarRepositoryProvider);
      await repo.createEvent(
        query: _demo,
        input: _holiday('Winter break', DateTime(2026, 12, 20)),
      );
      await repo.createEvent(
        query: _demo,
        input: CreateSchoolCalendarEventInput(
          eventDate: DateTime(2026, 3, 1),
          title: 'Exam week',
          eventType: SchoolCalendarEventType.exam,
        ),
      );

      container.read(schoolCalendarFilterProvider.notifier).state =
          SchoolCalendarEventType.exam;
      final filtered =
          await container.read(schoolCalendarEventsProvider.future);
      expect(filtered, hasLength(1));
      expect(filtered.single.title, 'Exam week');
    });
  });

  group('SchoolCalendarScreen gating', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required ErpRole role,
      required SchoolCalendarMockStore store,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: erpWidgetTestOverrides([
            schoolCalendarRepositoryProvider.overrideWithValue(
              MockSchoolCalendarRepository(store: store),
            ),
            repositoryQueryProvider.overrideWithValue(_demo),
            rbacServiceProvider.overrideWithValue(
              RbacService(UserPermissions.forRole(role)),
            ),
          ]),
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const SchoolCalendarScreen(),
          ),
        ),
      );
      await settleRiverpodFutures(tester);
      await tester.pumpAndSettle();
    }

    testWidgets('manage role sees events and the Add-event affordance',
        (tester) async {
      final store = SchoolCalendarMockStore.empty()
        ..create(_holiday('Republic Day', DateTime(2026, 1, 26)));

      await pumpScreen(tester, role: ErpRole.principal, store: store);

      expect(find.text('Republic Day'), findsOneWidget);
      expect(find.text('Add event'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });

    testWidgets('view-only role hides Add + delete affordances',
        (tester) async {
      final store = SchoolCalendarMockStore.empty()
        ..create(_holiday('Republic Day', DateTime(2026, 1, 26)));

      // teacher is seeded with viewSchoolCalendar only (no manage).
      await pumpScreen(tester, role: ErpRole.teacher, store: store);

      expect(find.text('Republic Day'), findsOneWidget);
      expect(find.text('Add event'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });
}
