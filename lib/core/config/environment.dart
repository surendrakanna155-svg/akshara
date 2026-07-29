import 'package:flutter/foundation.dart' show kReleaseMode;

/// Deployment environment for API and feature configuration.
enum EnvironmentName {
  development,
  staging,
  production;

  String get label => switch (this) {
        EnvironmentName.development => 'Development',
        EnvironmentName.staging => 'Staging',
        EnvironmentName.production => 'Production',
      };
}

/// Immutable environment snapshot consumed by network and repository layers.
class Environment {
  const Environment({
    required this.name,
    required this.apiBaseUrl,
    required this.enableApiMode,
    required this.enableLogging,
    this.requireTls = false,
    this.requireAuthentication = false,
    this.disableDemoAuth = false,
    this.enableQaLogin = false,
  });

  final EnvironmentName name;
  final String apiBaseUrl;
  final bool enableApiMode;
  final bool enableLogging;

  /// When true, API base URL must use HTTPS.
  final bool requireTls;

  /// When true, Dio rejects requests without a valid access token.
  final bool requireAuthentication;

  /// When true, mock OTP / demo persona shortcuts are disabled.
  final bool disableDemoAuth;

  /// When true, show instant QA persona login (never enabled in production).
  final bool enableQaLogin;

  static const development = Environment(
    name: EnvironmentName.development,
    apiBaseUrl: 'http://localhost:8080/v1',
    enableApiMode: false,
    enableLogging: true,
  );

  static const staging = Environment(
    name: EnvironmentName.staging,
    apiBaseUrl: 'https://staging-api.aksharaerp.com/v1',
    enableApiMode: false,
    enableLogging: true,
    disableDemoAuth: true,
  );

  // Live backend: the public Akshara edge API on the VPS. Routes are served at
  // the ROOT (no `/v1` suffix). Overridable via `--dart-define=API_BASE_URL`.
  // `enableApiMode` stays false here so unit/Patrol tests that build the
  // production env keep running on mocks; the live release turns it on via
  // `config/live_release.json` (see scripts/build_release.sh).
  static const production = Environment(
    name: EnvironmentName.production,
    apiBaseUrl: 'https://api.nikshaos.in',
    enableApiMode: false,
    enableLogging: false,
    requireTls: true,
    requireAuthentication: true,
    disableDemoAuth: true,
  );

  /// Resolves environment from dart-defines:
  /// - `APP_ENV=development|staging|production`
  /// - `API_BASE_URL` (optional override)
  /// - `ENABLE_API_MODE=true` (master API switch)
  /// When true, explicit local demo/testing auth (role picker + mock OTP) is allowed.
  /// Requires `--dart-define=ENABLE_DEMO_AUTH=true`. Off by default for staging/production.
  static Environment fromDartDefine() {
    const raw = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    const enableApiMode = bool.fromEnvironment(
      'ENABLE_API_MODE',
      defaultValue: false,
    );
    const enableDemoAuth = bool.fromEnvironment(
      'ENABLE_DEMO_AUTH',
      defaultValue: false,
    );
    const qaAutomation = bool.fromEnvironment(
      'QA_AUTOMATION',
      defaultValue: false,
    );
    const enableQaLoginDefine = bool.fromEnvironment(
      'ENABLE_QA_LOGIN',
      defaultValue: false,
    );
    final base = switch (raw.toLowerCase()) {
      'staging' => staging,
      'production' => production,
      _ => development,
    };
    var resolved = base;
    if (apiBaseUrl.isNotEmpty) {
      resolved = resolved.copyWith(apiBaseUrl: apiBaseUrl);
    }
    if (enableApiMode) {
      resolved = resolved.copyWith(enableApiMode: true);
    }
    if (enableDemoAuth) {
      resolved = resolved.copyWith(disableDemoAuth: false);
    }
    final wantsQaLogin = qaAutomation || enableQaLoginDefine;
    if (wantsQaLogin && resolved.name != EnvironmentName.production) {
      resolved = resolved.copyWith(
        enableQaLogin: true,
        disableDemoAuth: false,
        enableApiMode: false,
      );
    }
    return guardForRelease(resolved, isRelease: kReleaseMode, rawAppEnv: raw);
  }

  /// Fail-closed release guard (SEC-1 / SEC-2 / SEC-9 / SEC-10).
  ///
  /// A **release** binary must run the `production` environment against a real
  /// backend (`enableApiMode`) with **no** demo/QA shortcuts. Any other
  /// configuration (missing/`development`/`staging`/unknown `APP_ENV`, or API
  /// mode off) is refused by throwing, so the app cannot start — and therefore
  /// cannot authenticate — in an insecure configuration. In non-release builds
  /// (debug/profile/tests) the resolved environment is returned unchanged.
  ///
  /// Extracted as a pure, `isRelease`-parameterised function so the fail-closed
  /// behaviour is unit-testable without a real release build.
  static Environment guardForRelease(
    Environment resolved, {
    required bool isRelease,
    required String rawAppEnv,
  }) {
    if (!isRelease) return resolved;
    if (resolved.name != EnvironmentName.production) {
      throw StateError(
        'Insecure release build: APP_ENV must be "production" (was "$rawAppEnv"). '
        'Refusing to start with a non-production configuration.',
      );
    }
    if (!resolved.enableApiMode) {
      throw StateError(
        'Insecure release build: ENABLE_API_MODE must be true in production. '
        'Refusing to start against mock auth/data.',
      );
    }
    // Belt-and-suspenders: demo/mock and QA persona shortcuts can never be
    // active in a release binary, regardless of the defines that were passed.
    return resolved.copyWith(disableDemoAuth: true, enableQaLogin: false);
  }

  Environment copyWith({
    EnvironmentName? name,
    String? apiBaseUrl,
    bool? enableApiMode,
    bool? enableLogging,
    bool? requireTls,
    bool? requireAuthentication,
    bool? disableDemoAuth,
    bool? enableQaLogin,
  }) {
    return Environment(
      name: name ?? this.name,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      enableApiMode: enableApiMode ?? this.enableApiMode,
      enableLogging: enableLogging ?? this.enableLogging,
      requireTls: requireTls ?? this.requireTls,
      requireAuthentication: requireAuthentication ?? this.requireAuthentication,
      disableDemoAuth: disableDemoAuth ?? this.disableDemoAuth,
      enableQaLogin: enableQaLogin ?? this.enableQaLogin,
    );
  }
}
