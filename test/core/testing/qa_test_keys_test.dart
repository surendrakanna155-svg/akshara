import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/auth/qa_login_persona.dart';

void main() {
  test('QaTestKeys persona keys are stable per enum name', () {
    for (final persona in QaLoginPersona.values) {
      expect(
        QaTestKeys.qaPersonaButton(persona.name).value,
        'qa_persona_${persona.name}',
      );
    }
  });

  test('auth flow keys are non-empty strings', () {
    expect(QaTestKeys.loginPhoneField.value, 'login_phone_field');
    expect(QaTestKeys.otpField.value, 'otp_verification_field');
    expect(QaTestKeys.logoutButton.value, 'auth_logout_button');
  });
}
