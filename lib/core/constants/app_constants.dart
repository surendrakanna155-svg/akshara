/// Application-wide constants.
///
/// Branding (owner decision, 2026-07-28): the product ships as **NIKSHA OS**,
/// published by **NIKSHA Technologies Pvt. Ltd.** The former "Akshara ERP" name
/// is retired from every user-facing surface. The Android package id stays
/// `com.akshara.erp` — a Play Store package id can never be changed after the
/// first upload, and it is never shown to users.
abstract final class AppConstants {
  /// Short product name. Use in headers, locks and dialogs — anywhere the
  /// product refers to itself in running text.
  static const String appName = 'NIKSHA OS';

  /// Full product title for splash, about screens and window titles.
  static const String appTitle = 'NIKSHA OS';

  /// Positioning line, shown on splash and about surfaces.
  static const String appTagline = 'The AI Operating System for Schools';

  /// Publishing entity. Required on legal screens, the Play listing and every
  /// copyright notice.
  static const String companyName = 'NIKSHA Technologies Pvt. Ltd.';
}
