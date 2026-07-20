import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'incident_module_resolver.dart';
import 'incident_telemetry.dart';

/// The auto-collected technical context posted on incident create. Mirrors the
/// backend `ClientContext` wire shape (camelCase request body) exactly — the
/// reporter never types any of this (ASIP_DESIGN §4).
@immutable
class IncidentContext {
  const IncidentContext({
    this.appVersion,
    this.platform,
    this.deviceModel,
    this.osVersion,
    this.sessionId,
    this.screenRoute,
    this.moduleKey,
    this.correlationIds = const [],
    this.breadcrumbs = const [],
    this.recentApiCalls = const [],
  });

  final String? appVersion;
  final String? platform;
  final String? deviceModel;
  final String? osVersion;
  final String? sessionId;
  final String? screenRoute;
  final String? moduleKey;
  final List<String> correlationIds;
  final List<IncidentBreadcrumb> breadcrumbs;
  final List<IncidentApiCall> recentApiCalls;

  Map<String, dynamic> toJson() => {
        if (appVersion != null) 'appVersion': appVersion,
        if (platform != null) 'platform': platform,
        if (deviceModel != null) 'deviceModel': deviceModel,
        if (osVersion != null) 'osVersion': osVersion,
        if (sessionId != null) 'sessionId': sessionId,
        if (screenRoute != null) 'screenRoute': screenRoute,
        if (moduleKey != null) 'moduleKey': moduleKey,
        'correlationIds': correlationIds,
        'breadcrumbs': [for (final b in breadcrumbs) b.toJson()],
        'recentApiCalls': [for (final c in recentApiCalls) c.toJson()],
      };
}

/// Device / OS / app-version probe. Abstracted so the [IncidentContextService]
/// can be unit-tested with a fake and so no plugin is invoked in a pure Dart
/// test (where the platform channels are absent).
abstract class IncidentEnvironmentProbe {
  Future<String?> appVersion();
  Future<String?> deviceModel();
  Future<String?> osVersion();
  String platform();
}

/// Production probe backed by `package_info_plus` + `device_info_plus`. Every
/// call is defensive: a probe failure yields null and never blocks a report.
class PlatformIncidentEnvironmentProbe implements IncidentEnvironmentProbe {
  PlatformIncidentEnvironmentProbe({DeviceInfoPlugin? deviceInfo})
      : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  String? _appVersion;
  bool _appVersionResolved = false;
  BaseDeviceInfo? _cachedDeviceInfo;
  bool _deviceInfoResolved = false;

  @override
  String platform() => resolvePlatformLabel();

  @override
  Future<String?> appVersion() async {
    if (_appVersionResolved) return _appVersion;
    _appVersionResolved = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber.isEmpty ? '' : '+${info.buildNumber}';
      _appVersion = '${info.version}$build';
    } on Object {
      _appVersion = null;
    }
    return _appVersion;
  }

  @override
  Future<String?> deviceModel() async {
    final info = await _resolveDeviceInfo();
    if (info == null) return null;
    try {
      if (info is AndroidDeviceInfo) return '${info.manufacturer} ${info.model}';
      if (info is IosDeviceInfo) return info.utsname.machine;
      if (info is MacOsDeviceInfo) return info.model;
      if (info is WindowsDeviceInfo) return info.computerName;
      if (info is LinuxDeviceInfo) return info.prettyName;
      if (info is WebBrowserInfo) return info.browserName.name;
    } on Object {
      return null;
    }
    return null;
  }

  @override
  Future<String?> osVersion() async {
    final info = await _resolveDeviceInfo();
    if (info == null) return null;
    try {
      if (info is AndroidDeviceInfo) {
        return 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      }
      if (info is IosDeviceInfo) return '${info.systemName} ${info.systemVersion}';
      if (info is MacOsDeviceInfo) {
        return 'macOS ${info.majorVersion}.${info.minorVersion}.${info.patchVersion}';
      }
      if (info is WindowsDeviceInfo) return 'Windows ${info.displayVersion}';
      if (info is LinuxDeviceInfo) return info.versionId;
      if (info is WebBrowserInfo) return info.appVersion;
    } on Object {
      return null;
    }
    return null;
  }

  Future<BaseDeviceInfo?> _resolveDeviceInfo() async {
    if (_deviceInfoResolved) return _cachedDeviceInfo;
    _deviceInfoResolved = true;
    try {
      _cachedDeviceInfo = await _deviceInfo.deviceInfo;
    } on Object {
      _cachedDeviceInfo = null;
    }
    return _cachedDeviceInfo;
  }
}

/// Assembles the [IncidentContext] on demand from the passive telemetry buffer +
/// the environment probe + the current session id. Called once, at the moment
/// the reporter submits an issue.
class IncidentContextService {
  IncidentContextService({
    required IncidentEnvironmentProbe probe,
    required IncidentTelemetryBuffer buffer,
    required Future<String?> Function() sessionIdReader,
  })  : _probe = probe,
        _buffer = buffer,
        _sessionIdReader = sessionIdReader;

  final IncidentEnvironmentProbe _probe;
  final IncidentTelemetryBuffer _buffer;
  final Future<String?> Function() _sessionIdReader;

  Future<IncidentContext> capture() async {
    // Probe device/app/session concurrently; each is independently defensive.
    final appVersion = await _safe(_probe.appVersion);
    final deviceModel = await _safe(_probe.deviceModel);
    final osVersion = await _safe(_probe.osVersion);
    final sessionId = await _safe(_sessionIdReader);

    final screenRoute = _buffer.currentRoute;
    final moduleKey = _buffer.currentModule ?? deriveIncidentModuleKey(screenRoute);

    return IncidentContext(
      appVersion: appVersion,
      platform: _probe.platform(),
      deviceModel: deviceModel,
      osVersion: osVersion,
      sessionId: sessionId,
      screenRoute: screenRoute,
      moduleKey: moduleKey,
      correlationIds: _buffer.correlationIds,
      breadcrumbs: _buffer.breadcrumbs,
      recentApiCalls: _buffer.recentApiCalls,
    );
  }

  Future<String?> _safe(Future<String?> Function() read) async {
    try {
      return await read();
    } on Object {
      return null;
    }
  }
}
