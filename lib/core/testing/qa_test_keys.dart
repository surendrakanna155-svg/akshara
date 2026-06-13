import 'package:flutter/foundation.dart';

/// Stable widget keys for Patrol / integration tests (QA builds only).
abstract final class QaTestKeys {
  static const splash = ValueKey<String>('qa_splash_screen');
  static const qaLoginScreen = ValueKey<String>('qa_login_screen');
  static const loginPhoneField = ValueKey<String>('login_phone_field');
  static const loginContinueButton = ValueKey<String>('login_continue_button');
  static const otpField = ValueKey<String>('otp_verification_field');
  static const otpVerifyButton = ValueKey<String>('otp_verify_button');
  static const logoutButton = ValueKey<String>('auth_logout_button');
  static const logoutConfirmButton = ValueKey<String>('auth_logout_confirm');
  static const profileButton = ValueKey<String>('profile_button');
  static const receiptHistoryButton = ValueKey<String>('receipt_history_button');
  static const erpMenuButton = ValueKey<String>('erp_menu_button');

  static ValueKey<String> erpNavModule(String module) =>
      ValueKey<String>('erp_nav_$module');

  static ValueKey<String> principalQuickAction(String action) =>
      ValueKey<String>('principal_qa_$action');

  static const enrollmentContinueButton =
      ValueKey<String>('enrollment_continue_button');

  /// Inventory INV lifecycle screen root (Patrol route navigation target).
  static const inventoryLifecycleScreen =
      ValueKey<String>('inventory_lifecycle_screen');

  static String normalizeSubNavLabel(String label) =>
      label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  static ValueKey<String> moduleSubNavTab(String module, String tabLabel) =>
      ValueKey<String>(
        'erp_subnav_${module}_${normalizeSubNavLabel(tabLabel)}',
      );

  static ValueKey<String> qaPersonaButton(String label) =>
      ValueKey<String>('qa_persona_$label');
}
