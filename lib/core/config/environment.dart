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
  });

  final EnvironmentName name;
  final String apiBaseUrl;
  final bool enableApiMode;
  final bool enableLogging;

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
  );

  static const production = Environment(
    name: EnvironmentName.production,
    apiBaseUrl: 'https://api.aksharaerp.com/v1',
    enableApiMode: false,
    enableLogging: false,
  );

  /// Resolves environment from `--dart-define=APP_ENV=development|staging|production`.
  static Environment fromDartDefine() {
    const raw = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    return switch (raw.toLowerCase()) {
      'staging' => staging,
      'production' => production,
      _ => development,
    };
  }

  Environment copyWith({
    EnvironmentName? name,
    String? apiBaseUrl,
    bool? enableApiMode,
    bool? enableLogging,
  }) {
    return Environment(
      name: name ?? this.name,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      enableApiMode: enableApiMode ?? this.enableApiMode,
      enableLogging: enableLogging ?? this.enableLogging,
    );
  }
}
