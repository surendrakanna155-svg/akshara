import 'package:flutter/material.dart';

import '../../../../../features/transport/transport_models.dart';

/// Parses Transport API enum strings and presentation helpers.
abstract final class TransportEnumCodec {
  static TransportRouteStatus parseRouteStatus(String? value) {
    return TransportRouteStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TransportRouteStatus.active,
    );
  }

  static String routeStatusToApi(TransportRouteStatus status) => status.name;

  static TransportVehicleStatus parseVehicleStatus(String? value) {
    return TransportVehicleStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TransportVehicleStatus.active,
    );
  }

  static String vehicleStatusToApi(TransportVehicleStatus status) =>
      status.name;

  static TransportDriverStatus parseDriverStatus(String? value) {
    return TransportDriverStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TransportDriverStatus.active,
    );
  }

  static String driverStatusToApi(TransportDriverStatus status) => status.name;

  static TransportShift parseShift(String? value) {
    return TransportShift.values.firstWhere(
      (shift) => shift.name == value,
      orElse: () => TransportShift.am,
    );
  }

  static String shiftToApi(TransportShift shift) => shift.name;

  static TrackingStatus parseTrackingStatus(String? value) {
    return TrackingStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TrackingStatus.idle,
    );
  }

  static String trackingStatusToApi(TrackingStatus status) => status.name;

  static TransportAttendanceStatus parseAttendanceStatus(String? value) {
    return TransportAttendanceStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TransportAttendanceStatus.waiting,
    );
  }

  static String attendanceStatusToApi(TransportAttendanceStatus status) =>
      status.name;

  static TransportStopStatus parseStopStatus(String? value) {
    return TransportStopStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TransportStopStatus.upcoming,
    );
  }

  static String stopStatusToApi(TransportStopStatus status) => status.name;

  static IconData iconForKpi(String? iconName, String? accentName, String? id) {
    if (iconName != null && iconName.isNotEmpty) {
      return switch (iconName) {
        'directions_bus_outlined' => Icons.directions_bus_outlined,
        'schedule_outlined' => Icons.schedule_outlined,
        'warning_amber_outlined' => Icons.warning_amber_outlined,
        'groups_outlined' => Icons.groups_outlined,
        'person_off_outlined' => Icons.person_off_outlined,
        'local_gas_station_outlined' => Icons.local_gas_station_outlined,
        _ => Icons.insights_outlined,
      };
    }
    return switch (id) {
      'active_buses' => Icons.directions_bus_outlined,
      'on_time' => Icons.schedule_outlined,
      'delayed' => Icons.warning_amber_outlined,
      'picked' => Icons.groups_outlined,
      'driver_absent' => Icons.person_off_outlined,
      'fuel' => Icons.local_gas_station_outlined,
      _ => switch (accentName) {
          'primary' => Icons.directions_bus_outlined,
          'success' => Icons.groups_outlined,
          'warning' => Icons.warning_amber_outlined,
          'error' => Icons.warning_amber_outlined,
          _ => Icons.insights_outlined,
        },
    };
  }
}
