import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/profile/teacher_profile_screen.dart';
import 'package:akshara_erp/router/route_names.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: RouteNames.teacherProfile,
      routes: [
        GoRoute(
          path: RouteNames.teacherProfile,
          builder: (context, state) => const TeacherProfileScreen(),
        ),
        GoRoute(
          path: RouteNames.teacherSettings,
          builder: (context, state) =>
              const Scaffold(body: Text('settings-screen')),
        ),
      ],
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          theme: AksharaAppTheme.light(),
          routerConfig: buildRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the teacher identity and teaching details',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(QaTestKeys.teacherProfileScreen), findsOneWidget);
    // Demo teaching context resolves to Priya Sharma (class teacher, Maths).
    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.textContaining('Mathematics'), findsWidgets);
    expect(find.text('Teaching details'), findsOneWidget);
  });

  testWidgets('Settings link navigates to teacher settings', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(QaTestKeys.teacherProfileSettingsLink));
    await tester.pumpAndSettle();

    expect(find.text('settings-screen'), findsOneWidget);
  });
}
