import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/login_screen.dart';
import 'package:akshara_erp/features/auth/otp_verification_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

/// QW1 · QA-F-001 (OTP verification screen render + 6-digit gate + resend) and
/// QA-F-002 (Login screen phone-entry render + 10-digit validation gating).
///
/// Both screens were 0% lcov / never pumped. These cover the router-free core:
/// render, field validation, and the OTP gate. (The post-validation navigation +
/// sending-spinner paths are exercised by the Patrol auth journeys.)
Future<void> _pump(WidgetTester tester, Widget screen) async {
  useMobileViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('QA-F-002 · LoginScreen', () {
    testWidgets('renders the phone field + continue button', (tester) async {
      await _pump(tester, const LoginScreen());

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(QaTestKeys.loginPhoneField), findsOneWidget);
      expect(find.byKey(QaTestKeys.loginContinueButton), findsOneWidget);
    });

    testWidgets('rejects an invalid phone number on submit', (tester) async {
      await _pump(tester, const LoginScreen());

      await tester.enterText(find.byKey(QaTestKeys.loginPhoneField), '123');
      await tester.tap(find.byKey(QaTestKeys.loginContinueButton));
      await tester.pump();

      // Validation fails → error shown, no navigation off the login screen.
      expect(find.text('Enter a valid 10-digit number'), findsOneWidget);
      expect(find.byKey(QaTestKeys.loginPhoneField), findsOneWidget);
    });

    testWidgets('accepts a valid 10-digit number (no validation error)',
        (tester) async {
      await _pump(tester, const LoginScreen());

      await tester.enterText(
          find.byKey(QaTestKeys.loginPhoneField), '9876543210');
      await tester.pump();

      // Field accepts exactly 10 digits and shows no inline validation error.
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('Enter a valid 10-digit number'), findsNothing);
    });
  });

  group('QA-F-001 · OtpVerificationScreen', () {
    testWidgets('renders the OTP field, verify button + masked phone',
        (tester) async {
      await _pump(
        tester,
        const OtpVerificationScreen(
          phoneNumber: '9876543210',
          role: UserRole.parent,
        ),
      );

      expect(find.text('Verify OTP'), findsOneWidget);
      expect(find.byKey(QaTestKeys.otpField), findsOneWidget);
      expect(find.byKey(QaTestKeys.otpVerifyButton), findsOneWidget);
      // Masked phone keeps first 2 + last 2 digits.
      expect(find.textContaining('98******10'), findsOneWidget);

      // Tear down the screen so its periodic resend Timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('resend is disabled during the countdown', (tester) async {
      await _pump(
        tester,
        const OtpVerificationScreen(phoneNumber: '9876543210'),
      );

      // Countdown starts at 30s → resend gated.
      expect(find.textContaining('Resend in'), findsOneWidget);
      final resend = tester.widget<TextButton>(
        find.ancestor(
          of: find.textContaining('Resend in'),
          matching: find.byType(TextButton),
        ),
      );
      expect(resend.onPressed, isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows an error snackbar for a short OTP', (tester) async {
      await _pump(
        tester,
        const OtpVerificationScreen(phoneNumber: '9876543210'),
      );

      await tester.enterText(find.byKey(QaTestKeys.otpField), '123');
      await tester.tap(find.byKey(QaTestKeys.otpVerifyButton));
      await tester.pump(); // surface the snackbar

      expect(find.text('Enter the 6-digit OTP'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
