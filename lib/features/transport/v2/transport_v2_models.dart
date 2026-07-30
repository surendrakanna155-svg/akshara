import 'package:flutter/foundation.dart';

/// Transport v2 domain models — the client half of
/// `docs/engineering/TRANSPORT_DOMAIN_CONTRACT.md`.
///
/// WHY THESE ARE NEW TYPES RATHER THAN AN EVOLUTION OF `transport_models.dart`
///
/// The legacy models encode the exact defects the Bus Tracking audit found and
/// cannot represent the v2 contract:
///   * `TransportRoute.assignedBus` is a String. In v2 there IS no such field —
///     the vehicle comes from a DATED assignment row, which is what makes
///     substitution and temporary replacement ordinary records (P-3). Keeping a
///     scalar would re-import the bug that silently disabled three features.
///   * `TransportStop.latitude/longitude` default to 0 — the value every legacy
///     stop received. Here a coordinate is a required, validated value object.
///   * stop times were free-text Strings. Here they are `TimeOfDay?`.
///   * allocations carried frozen `routeName`/`busNumber` copies that went stale.
///
/// Canonical field names match §2 of the contract exactly. No aliases.

/// A validated geographic point. Construction rejects the values that made the
/// legacy model unusable, so an invalid coordinate cannot exist in memory.
@immutable
class GeoPoint {
  const GeoPoint._(this.latitude, this.longitude);

  /// Returns null when the pair is unusable, so callers must handle absence
  /// rather than silently receiving (0, 0).
  static GeoPoint? tryParse(num? lat, num? lng) {
    if (lat == null || lng == null) return null;
    final la = lat.toDouble();
    final ln = lng.toDouble();
    if (la.isNaN || ln.isNaN) return null;
    if (la < -90 || la > 90 || ln < -180 || ln > 180) return null;
    // NULL Island. Not merely out of range — this is the precise signature of a
    // dropped coordinate, which is what the legacy write path produced for
    // EVERY stop created through the product.
    if (la.abs() < 0.0001 && ln.abs() < 0.0001) return null;
    return GeoPoint._(la, ln);
  }

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() =>
      'GeoPoint(${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})';
}

/// A stop time. Stored as minutes-from-midnight so it is orderable and
/// subtractable — the property free-text times lacked, which is why schedule
/// adherence and ETA were arithmetically impossible before BUS-038.
@immutable
class StopTime implements Comparable<StopTime> {
  const StopTime(this.minutesFromMidnight);

  /// Parses the backend's canonical `HH:MM`. Returns null for anything else —
  /// never a coerced guess.
  static StopTime? tryParse(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return StopTime(h * 60 + min);
  }

  final int minutesFromMidnight;

  int get hour => minutesFromMidnight ~/ 60;
  int get minute => minutesFromMidnight % 60;

  /// Wire format — always the canonical `HH:MM` the backend parses.
  String toWire() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Display format for Indian schools (12-hour with meridiem).
  String toDisplay() {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final meridiem = hour < 12 ? 'AM' : 'PM';
    return '$h12:${minute.toString().padLeft(2, '0')} $meridiem';
  }

  @override
  int compareTo(StopTime other) =>
      minutesFromMidnight.compareTo(other.minutesFromMidnight);

  @override
  bool operator ==(Object other) =>
      other is StopTime && other.minutesFromMidnight == minutesFromMidnight;

  @override
  int get hashCode => minutesFromMidnight.hashCode;
}

enum RouteV2Status { draft, active, inactive }

enum RouteV2Shift { am, pm }

enum RouteV2Direction { pickup, drop }

enum StopV2Status { active, needsLocation, retired }

T _enumOr<T>(Map<String, T> table, String? raw, T fallback) =>
    table[(raw ?? '').trim()] ?? fallback;

/// A school-owned stop. Shared across the AM and PM route (BUS-040), which is
/// why it carries no route reference.
@immutable
class TransportStopV2 {
  const TransportStopV2({
    required this.id,
    required this.name,
    required this.location,
    required this.geofenceRadiusM,
    required this.addressText,
    required this.landmark,
    required this.status,
  });

  factory TransportStopV2.fromJson(Map<String, dynamic> json) {
    return TransportStopV2(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      location: GeoPoint.tryParse(
        json['latitude'] as num?,
        json['longitude'] as num?,
      ),
      geofenceRadiusM: (json['geofenceRadiusM'] as num?)?.toInt() ?? 100,
      addressText: json['addressText'] as String? ?? '',
      landmark: json['landmark'] as String? ?? '',
      status: _enumOr(const {
        'active': StopV2Status.active,
        'needs_location': StopV2Status.needsLocation,
        'retired': StopV2Status.retired,
      }, json['status'] as String?, StopV2Status.active),
    );
  }

  final String id;
  final String name;

  /// Null ONLY for a migrated legacy stop awaiting a pin (BUS-030). Such a stop
  /// blocks route publication, so the gap is loud rather than silent.
  final GeoPoint? location;
  final int geofenceRadiusM;
  final String addressText;
  final String landmark;
  final StopV2Status status;

  bool get needsLocation =>
      status == StopV2Status.needsLocation || location == null;
}

/// A stop as it appears ON a route: the shared stop plus this route's own
/// sequence and times.
@immutable
class RouteStopV2 {
  const RouteStopV2({
    required this.stop,
    required this.sequence,
    required this.pickupTime,
    required this.dropTime,
    required this.dwellSeconds,
  });

  factory RouteStopV2.fromJson(Map<String, dynamic> json) {
    return RouteStopV2(
      stop: TransportStopV2.fromJson(json),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      // BUS-006/BUS-038: canonical names, typed. No `scheduledTime` alias.
      pickupTime: StopTime.tryParse(json['pickupTime'] as String?),
      dropTime: StopTime.tryParse(json['dropTime'] as String?),
      dwellSeconds: (json['dwellSeconds'] as num?)?.toInt() ?? 60,
    );
  }

  final TransportStopV2 stop;
  final int sequence;
  final StopTime? pickupTime;
  final StopTime? dropTime;
  final int dwellSeconds;

  bool get hasNoTimes => pickupTime == null && dropTime == null;

  String get timesLabel {
    if (hasNoTimes) return 'Time not set';
    return [
      if (pickupTime != null) 'Pickup ${pickupTime!.toDisplay()}',
      if (dropTime != null) 'Drop ${dropTime!.toDisplay()}',
    ].join(' · ');
  }
}

/// The crew and vehicle in force for a route on a given date.
@immutable
class RouteAssignmentV2 {
  const RouteAssignmentV2({
    required this.assignmentId,
    required this.vehicleId,
    required this.vehicleRegistration,
    required this.driverId,
    required this.driverName,
    required this.attendantId,
    required this.attendantName,
    required this.isSubstitute,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.reason,
  });

  factory RouteAssignmentV2.fromJson(Map<String, dynamic> json) {
    return RouteAssignmentV2(
      assignmentId: json['assignmentId'] as String? ?? json['id'] as String? ?? '',
      vehicleId: json['vehicleId'] as String?,
      vehicleRegistration: json['vehicleRegistration'] as String?,
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      attendantId: json['attendantId'] as String?,
      attendantName: json['attendantName'] as String?,
      isSubstitute: (json['assignmentKind'] as String?) == 'substitute' ||
          json['isSubstitute'] == true,
      effectiveFrom: json['effectiveFrom'] as String? ?? '',
      effectiveTo: json['effectiveTo'] as String?,
      reason: json['reason'] as String? ?? '',
    );
  }

  final String assignmentId;
  final String? vehicleId;
  final String? vehicleRegistration;
  final String? driverId;
  final String? driverName;
  final String? attendantId;
  final String? attendantName;

  /// True when a bounded substitute row is covering the permanent arrangement.
  /// Surfaced so a covering driver is told that is what is happening (BUS-051).
  final bool isSubstitute;
  final String effectiveFrom;
  final String? effectiveTo;
  final String reason;

  bool get hasVehicle => (vehicleId ?? '').isNotEmpty;
  bool get hasDriver => (driverId ?? '').isNotEmpty;
}

/// Why a route cannot be published. Mirrors the backend's blocker vocabulary so
/// the checklist and the gate can never disagree (BUS-042).
enum RouteBlocker {
  needsAtLeastTwoStops,
  stopsMissingLocation,
  noStudentsAllocated,
  noVehicleAssigned,
  noDriverAssigned,
  driverLicenceExpired,
  routeNotFound,
  unknown;

  static RouteBlocker fromWire(String raw) => switch (raw) {
        'needs_at_least_two_stops' => RouteBlocker.needsAtLeastTwoStops,
        'stops_missing_location' => RouteBlocker.stopsMissingLocation,
        'no_students_allocated' => RouteBlocker.noStudentsAllocated,
        'no_vehicle_assigned' => RouteBlocker.noVehicleAssigned,
        'no_driver_assigned' => RouteBlocker.noDriverAssigned,
        'driver_licence_expired' => RouteBlocker.driverLicenceExpired,
        'route_not_found' => RouteBlocker.routeNotFound,
        _ => RouteBlocker.unknown,
      };

  /// Actionable label — the admin must know what to DO, not just that something
  /// is wrong. The legacy activate endpoint gave no signal at all.
  String get label => switch (this) {
        RouteBlocker.needsAtLeastTwoStops => 'Add at least two stops',
        RouteBlocker.stopsMissingLocation =>
          'Place every stop on the map — some have no location',
        RouteBlocker.noStudentsAllocated => 'Allocate at least one student',
        RouteBlocker.noVehicleAssigned => 'Assign a bus',
        RouteBlocker.noDriverAssigned => 'Assign a driver',
        RouteBlocker.driverLicenceExpired =>
          'The assigned driver’s licence has expired',
        RouteBlocker.routeNotFound => 'Route not found',
        RouteBlocker.unknown => 'Configuration incomplete',
      };
}

@immutable
class RouteReadinessV2 {
  const RouteReadinessV2({required this.ready, required this.blockers});

  factory RouteReadinessV2.fromJson(Map<String, dynamic> json) {
    final raw = json['blockers'];
    return RouteReadinessV2(
      ready: json['ready'] == true,
      blockers: [
        if (raw is List)
          for (final b in raw) RouteBlocker.fromWire(b.toString()),
      ],
    );
  }

  final bool ready;
  final List<RouteBlocker> blockers;
}

/// A route TEMPLATE. Carries no vehicle, no driver and no derived counts —
/// operational state belongs to the assignment and the trip (P-3, P-4).
@immutable
class TransportRouteV2 {
  const TransportRouteV2({
    required this.id,
    required this.name,
    required this.code,
    required this.shift,
    required this.direction,
    required this.status,
    required this.defaultDepartureTime,
    required this.defaultReturnTime,
    required this.distanceM,
    required this.stops,
    required this.assignment,
    required this.studentCount,
  });

  factory TransportRouteV2.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'];
    final rawAssignment = json['assignment'];
    return TransportRouteV2(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      shift: _enumOr(const {'am': RouteV2Shift.am, 'pm': RouteV2Shift.pm},
          json['shift'] as String?, RouteV2Shift.am),
      direction: _enumOr(const {
        'pickup': RouteV2Direction.pickup,
        'drop': RouteV2Direction.drop,
      }, json['direction'] as String?, RouteV2Direction.pickup),
      status: _enumOr(const {
        'draft': RouteV2Status.draft,
        'active': RouteV2Status.active,
        'inactive': RouteV2Status.inactive,
      }, json['status'] as String?, RouteV2Status.draft),
      defaultDepartureTime:
          StopTime.tryParse(json['defaultDepartureTime'] as String?),
      defaultReturnTime: StopTime.tryParse(json['defaultReturnTime'] as String?),
      distanceM: (json['distanceM'] as num?)?.toInt(),
      stops: [
        if (rawStops is List)
          for (final s in rawStops)
            if (s is Map<String, dynamic>) RouteStopV2.fromJson(s),
      ]..sort((a, b) => a.sequence.compareTo(b.sequence)),
      assignment: rawAssignment is Map<String, dynamic>
          ? RouteAssignmentV2.fromJson(rawAssignment)
          : null,
      studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String code;
  final RouteV2Shift shift;
  final RouteV2Direction direction;
  final RouteV2Status status;
  final StopTime? defaultDepartureTime;
  final StopTime? defaultReturnTime;
  final int? distanceM;
  final List<RouteStopV2> stops;

  /// Null when the route is unstaffed for the queried date — a first-class
  /// state, not an empty string (BUS-050).
  final RouteAssignmentV2? assignment;
  final int studentCount;

  int get stopCount => stops.length;
  bool get isActive => status == RouteV2Status.active;

  /// Stops still awaiting a map pin. Blocks publication (BUS-042).
  List<RouteStopV2> get stopsMissingLocation =>
      stops.where((s) => s.stop.needsLocation).toList();

  /// True when stop times do not increase along the sequence. Surfaced as a
  /// warning, not a hard block — a real route can legitimately cross midnight.
  bool get hasNonMonotonicTimes {
    StopTime? previous;
    for (final s in stops) {
      final t = s.pickupTime;
      if (t == null) continue;
      if (previous != null && t.compareTo(previous) < 0) return true;
      previous = t;
    }
    return false;
  }

  String get distanceLabel =>
      distanceM == null ? '—' : '${(distanceM! / 1000).toStringAsFixed(1)} km';
}

/// Capacity for a route on a date (BUS-044).
@immutable
class RouteCapacityV2 {
  const RouteCapacityV2({
    required this.routeName,
    required this.capacity,
    required this.current,
    required this.unbounded,
  });

  factory RouteCapacityV2.fromJson(Map<String, dynamic> json) {
    return RouteCapacityV2(
      routeName: json['routeName'] as String? ?? '',
      capacity: (json['capacity'] as num?)?.toInt(),
      current: (json['current'] as num?)?.toInt() ?? 0,
      unbounded: json['unbounded'] == true || json['capacity'] == null,
    );
  }

  final String routeName;

  /// Null means NO vehicle is assigned yet, so capacity is unknown/unbounded.
  /// It must never render as 0 — that would read as "this bus has no seats".
  final int? capacity;
  final int current;
  final bool unbounded;

  bool wouldExceed(int adding) =>
      capacity != null && current + adding > capacity!;

  String get label =>
      unbounded ? '$current allocated · no bus assigned' : '$current / $capacity';
}

/// A route that has no resolvable crew for a date, and why (BUS-050).
@immutable
class UnstaffedRouteV2 {
  const UnstaffedRouteV2({
    required this.routeId,
    required this.routeName,
    required this.missing,
  });

  factory UnstaffedRouteV2.fromJson(Map<String, dynamic> json) =>
      UnstaffedRouteV2(
        routeId: json['routeId'] as String? ?? json['route_id'] as String? ?? '',
        routeName:
            json['routeName'] as String? ?? json['route_name'] as String? ?? '',
        missing: json['missing'] as String? ?? 'no_assignment',
      );

  final String routeId;
  final String routeName;
  final String missing;

  String get reasonLabel => switch (missing) {
        'no_assignment' => 'No bus or driver assigned',
        'no_driver' => 'No driver assigned',
        'no_vehicle' => 'No bus assigned',
        'driver_unavailable' => 'Driver is on leave — assign a substitute',
        _ => 'Needs attention',
      };
}
