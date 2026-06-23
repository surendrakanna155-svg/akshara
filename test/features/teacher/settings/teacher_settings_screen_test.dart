import 'package:akshara_erp/core/providers/shared_preferences_provider.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/teacher/settings/teacher_settings_screen.dart';
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
      initialLocation: RouteNames.teacherSettings,
      routes: [
        GoRoute(
          path: RouteNames.teacherSettings,
          builder: (context, state) => const TeacherSettingsScreen(),
        ),
        GoRoute(
          path: RouteNames.appearanceSettings,
          builder: (context, state) =>
              const Scaffold(body: Text('appearance-screen')),
        ),
        GoRoute(
          path: RouteNames.aiAssistantSettings,
          builder: (context, state) =>
              const Scaffold(body: Text('ai-assistant-screen')),
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

  testWidgets('renders the Appearance and AI Assistant links', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(QaTestKeys.teacherSettingsScreen), findsOneWidget);
    expect(find.byKey(QaTestKeys.appearanceSettingsLink), findsOneWidget);
    expect(find.byKey(QaTestKeys.aiAssistantSettingsLink), findsOneWidget);
  });

  testWidgets('Appearance link navigates to the shared appearance settings',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(QaTestKeys.appearanceSettingsLink));
    await tester.pumpAndSettle();

    expect(find.text('appearance-screen'), findsOneWidget);
  });

  testWidgets('AI Assistant link navigates to the shared AI settings',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(QaTestKeys.aiAssistantSettingsLink));
    await tester.pumpAndSettle();

    expect(find.text('ai-assistant-screen'), findsOneWidget);
  });
}
