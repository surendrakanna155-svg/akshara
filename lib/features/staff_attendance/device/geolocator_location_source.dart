import 'package:geolocator/geolocator.dart';

import '../attendance_capture_sources.dart';
import '../staff_attendance_models.dart';

/// Real [AttendanceLocationSource] (Slice 3 device adapter) using `geolocator`.
///
/// Per docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §4: every attendance event needs
/// a FRESH high-accuracy fix — never a cached/last-known position — with
/// mock-provider detection. [Geolocator.getCurrentPosition] always requests a
/// new fix from the platform (unlike `getLastKnownPosition`), so this never
/// serves a stale cached fix.
///
/// The constructor does NO plugin work — every geolocator call happens inside
/// [acquire] so constructing this source (e.g. at provider-build time) is safe
/// in widget tests that never actually tap "check in".
class GeolocatorLocationSource implements AttendanceLocationSource {
  const GeolocatorLocationSource();

  /// A fresh fix must complete within this window; a slow/absent fix is
  /// reported as unavailable rather than left to hang indefinitely.
  static const Duration fixTimeLimit = Duration(seconds: 15);

  @override
  Future<AttendanceLocationFix> acquire() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const AttendanceCaptureException(
        AttendanceCaptureStep.location,
        'LOCATION_OFF',
        'Turn on location services to record attendance.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const AttendanceCaptureException(
        AttendanceCaptureStep.location,
        'LOCATION_PERMISSION',
        'Location permission is required to record attendance.',
      );
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: fixTimeLimit,
        ),
      );
    } catch (e) {
      // Covers TimeoutException (no fix within fixTimeLimit) and any platform
      // failure — fail loud with a location-step exception, never a stale fix.
      throw const AttendanceCaptureException(
        AttendanceCaptureStep.location,
        'LOCATION_UNAVAILABLE',
        'Could not get a fresh location fix. Move to an open area and try again.',
      );
    }

    return AttendanceLocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
      // Android mock-location-provider detection; always false on platforms
      // (e.g. iOS) that don't expose it — the SERVER re-validates regardless.
      isMock: position.isMocked,
      capturedAt: position.timestamp,
    );
  }
}
