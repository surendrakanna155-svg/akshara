import 'package:akshara_erp/app/app.dart';
import 'package:akshara_erp/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_test_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AksharaApp builds MaterialApp after splash bootstrap', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: authStorageTestOverrides(prefs),
        child: const AksharaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(SplashScreen.splashDuration);
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
