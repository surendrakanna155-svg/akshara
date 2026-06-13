import 'package:akshara_erp/core/config/environment.dart';
import 'package:akshara_erp/core/config/environment_provider.dart';
import 'package:akshara_erp/features/auth/auth_models.dart';
import 'package:akshara_erp/features/auth/auth_provider.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo OTP is blocked when production disableDemoAuth is active', () async {
    final container = ProviderContainer(
      overrides: [
        environmentProvider.overrideWith((ref) => Environment.production),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authProvider.notifier);
    final sent = await notifier.sendOtp('9876543210', UserRole.parent);
    expect(sent, isFalse);
  });

  test('QA persona login is blocked in production profile', () async {
    final container = ProviderContainer(
      overrides: [
        environmentProvider.overrideWith((ref) => Environment.production),
      ],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(authProvider.notifier).signInQaPersona(
            QaLoginPersona.parent,
          ),
      throwsA(isA<StateError>()),
    );
  });
}
