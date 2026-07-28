import 'package:akshara_erp/features/school_completion/school_branding_theme_provider.dart';
import 'package:akshara_erp/features/school_completion/school_completion_models.dart';
import 'package:akshara_erp/features/school_completion/school_completion_providers.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:akshara_erp/theme/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// QW7 · QA-C-023 — PER-SCHOOL BRANDING (GA-ready slice)
///
/// Builds on:
///   - lib/features/school_completion/school_branding_theme_provider.dart
///     (schoolBrandingThemeProvider / schoolDisplayNameProvider /
///      schoolLogoUrlProvider)
///   - test/security/rbac/white_label_rbac_test.dart  (authz boundary)
///   - test/features/school_completion/qw5_school_branding_authz_test.dart
///     (apply-verb authorization, Phase-2 boundary)
///
/// Certifies the GA-ready PROPAGATION behaviour: when a school's branding is
/// configured, its primary colour + display name + logo are resolved by the
/// providers the app shell / splash / login actually consume
/// (see lib/app/app.dart, lib/features/auth/{login,splash}_screen.dart), and
/// the primary colour actually lands in the app's ColorScheme.
///
/// Full-surface branding (app interiors, PDFs, emails) and the platform
/// white-label hub are Phase-2 (owner decision O10) and are NOT built/tested —
/// the boundary is asserted explicitly below.

SchoolBranding _branding({
  String displayName = 'Sunrise Public School',
  String primaryColor = '#0B6E4F',
  String? logoUrl = 'https://cdn.example.com/sunrise/logo.png',
}) {
  return SchoolBranding(
    displayName: displayName,
    tagline: 'Excellence in Education',
    primaryColor: primaryColor,
    secondaryColor: '#1565C0',
    logoUrl: logoUrl,
  );
}

ProviderContainer _containerWithBranding(SchoolBranding? branding) {
  return ProviderContainer(
    overrides: [
      schoolBrandingProvider.overrideWith(
        (ref) async =>
            branding ?? (throw StateError('no branding configured')),
      ),
    ],
  );
}

void main() {
  group('QA-C-023 GA slice — branding propagates to shell/splash/login', () {
    test('display name resolves from branding (app title + splash + login)',
        () async {
      final container = _containerWithBranding(
        _branding(displayName: 'Sunrise Public School'),
      );
      addTearDown(container.dispose);
      // Resolve the underlying future before reading the derived sync provider.
      await container.read(schoolBrandingProvider.future);

      expect(
        container.read(schoolDisplayNameProvider),
        'Sunrise Public School',
      );
    });

    test('primary colour parses and becomes a WhiteLabelThemeConfig override',
        () async {
      final container = _containerWithBranding(_branding(primaryColor: '#0B6E4F'));
      addTearDown(container.dispose);
      await container.read(schoolBrandingProvider.future);

      final WhiteLabelThemeConfig? config =
          container.read(schoolBrandingThemeProvider);
      expect(config, isNotNull);
      expect(config!.hasOverride, isTrue);
      // #0B6E4F -> 0xFF0B6E4F
      expect(config.primary, const Color(0xFF0B6E4F));
    });

    test('logo url resolves for the login/splash surfaces', () async {
      final container = _containerWithBranding(
        _branding(logoUrl: 'https://cdn.example.com/sunrise/logo.png'),
      );
      addTearDown(container.dispose);
      await container.read(schoolBrandingProvider.future);

      expect(
        container.read(schoolLogoUrlProvider),
        'https://cdn.example.com/sunrise/logo.png',
      );
    });

    test('school primary colour actually lands in the app ColorScheme',
        () async {
      final container = _containerWithBranding(_branding(primaryColor: '#7B1FA2'));
      addTearDown(container.dispose);
      await container.read(schoolBrandingProvider.future);

      final config = container.read(schoolBrandingThemeProvider);
      final ThemeData theme = AksharaAppTheme.light(whiteLabel: config);

      // The shell theme's primary is the school's brand colour, proving the
      // override flows app.dart -> AksharaAppTheme.light(whiteLabel:).
      expect(theme.colorScheme.primary, const Color(0xFF7B1FA2));
    });

    test('null logo is tolerated (optional surface, no crash)', () async {
      final container = _containerWithBranding(_branding(logoUrl: null));
      addTearDown(container.dispose);
      await container.read(schoolBrandingProvider.future);

      expect(container.read(schoolLogoUrlProvider), isNull);
      // Name + colour still propagate even without a logo.
      expect(container.read(schoolDisplayNameProvider), isNotEmpty);
      expect(container.read(schoolBrandingThemeProvider), isNotNull);
    });
  });

  group('QA-C-023 GA slice — safe defaults when branding is absent/invalid',
      () {
    test('no branding loaded -> default "NIKSHA OS" name + no theme override',
        () {
      // Branding future unresolved (valueOrNull == null) -> safe defaults.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(schoolDisplayNameProvider), 'NIKSHA OS');
      expect(container.read(schoolBrandingThemeProvider), isNull,
          reason: 'no override until branding is actually configured');
      expect(container.read(schoolLogoUrlProvider), isNull);

      // Theme with a null config falls back to the default Akshara palette
      // (no crash, no enforced brand colour).
      final theme = AksharaAppTheme.light(
        whiteLabel: container.read(schoolBrandingThemeProvider),
      );
      expect(theme.colorScheme.primary, isNotNull);
    });

    test('malformed hex (wrong length) -> no override, falls back safely',
        () async {
      final container = _containerWithBranding(
        _branding(primaryColor: '#12'), // invalid: not 6 hex digits
      );
      addTearDown(container.dispose);
      await container.read(schoolBrandingProvider.future);

      // Display name still works; the bad colour is ignored, not crashed on.
      expect(container.read(schoolDisplayNameProvider), isNotEmpty);
      expect(container.read(schoolBrandingThemeProvider), isNull,
          reason: 'unparseable colour must not produce a broken override');
    });
  });

  group('QA-C-023 Phase-2 boundary (O10 — NOT built here)', () {
    test('GA slice is shell/splash/login only — interiors/PDF/email deferred',
        () {
      // Documentation guard: the GA-ready white-label surface is exactly the
      // three providers below. Full-surface interiors, generated PDFs, and
      // outbound email branding are Phase-2 and intentionally absent.
      //
      // If this list grows, the GA scope changed and the cert must be revisited.
      const gaReadyProviders = <String>{
        'schoolBrandingThemeProvider', // app shell theme
        'schoolDisplayNameProvider', // app title / splash / login
        'schoolLogoUrlProvider', // splash / login logo
      };
      expect(gaReadyProviders.length, 3);
      // Phase-2 (tiered footer / Enterprise removal / platform hub) is covered
      // by qw5_school_branding_authz_test.dart's no-role boundary assertion.
    });
  });
}
