import 'package:flutter/material.dart';

/// Transport sub-module destinations (TR-01 → TR-09).
enum TransportScreen {
  dashboard,
  routes,
  vehicles,
  drivers,
  allocation,
  attendance,
  tracking,
  reports,
  settings;

  String get label => switch (this) {
        TransportScreen.dashboard => 'Dashboard',
        TransportScreen.routes => 'Routes',
        TransportScreen.vehicles => 'Vehicles',
        TransportScreen.drivers => 'Drivers',
        TransportScreen.allocation => 'Allocation',
        TransportScreen.attendance => 'Attendance',
        TransportScreen.tracking => 'Tracking',
        TransportScreen.reports => 'Reports',
        TransportScreen.settings => 'Settings',
      };
}

enum TransportRouteStatus { active, draft, inactive }

enum TransportVehicleStatus { active, maintenance, retired }

enum TransportDriverStatus { active, onLeave, inactive }

enum TransportShift { am, pm, both }

enum TrackingStatus { moving, idle, delayed, offline }

enum TransportAttendanceStatus { picked, waiting, absent, notScheduled }

enum TransportStopStatus { completed, next, upcoming }

@immutable
class TransportKpi {
  const TransportKpi({
    required this.id,
    required this.value,
    required this.label,
    required this.icon,
    required this.accentName,
    this.detail,
  });

  final String id;
  final String value;
  final String label;
  final IconData icon;
  final String accentName;
  final String? detail;
}

@immutable
class TransportTrendPoint {
  const TransportTrendPoint({
    required this.label,
    required this.amountLakhs,
    required this.targetLakhs,
  });

  final String label;
  final double amountLakhs;
  final double targetLakhs;
}

@immutable
class TransportSegment {
  const TransportSegment({
    required this.label,
    required this.value,
    required this.percent,
  });

  final String label;
  final double value;
  final double percent;
}

@immutable
class TransportStop {
  const TransportStop({
    required this.id,
    required this.name,
    required this.sequence,
    required this.scheduledTime,
    required this.status,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final int sequence;
  final String scheduledTime;
  final TransportStopStatus status;
  final double latitude;
  final double longitude;
}

@immutable
class TransportRoute {
  const TransportRoute({
    required this.id,
    required this.name,
    required this.stopCount,
    required this.distanceKm,
    required this.amDeparture,
    required this.pmDeparture,
    required this.assignedBus,
    required this.studentCount,
    required this.status,
    required this.stops,
    required this.shift,
  });

  final String id;
  final String name;
  final int stopCount;
  final String distanceKm;
  final String amDeparture;
  final String pmDeparture;
  final String assignedBus;
  final int studentCount;
  final TransportRouteStatus status;
  final List<TransportStop> stops;
  final TransportShift shift;
}

@immutable
class TransportVehicle {
  const TransportVehicle({
    required this.id,
    required this.busNumber,
    required this.registration,
    required this.capacity,
    required this.routeName,
    required this.gpsDeviceId,
    required this.insuranceExpiry,
    required this.fitnessExpiry,
    required this.status,
    required this.occupancyPercent,
  });

  final String id;
  final String busNumber;
  final String registration;
  final int capacity;
  final String routeName;
  final String gpsDeviceId;
  final String insuranceExpiry;
  final String fitnessExpiry;
  final TransportVehicleStatus status;
  final int occupancyPercent;
}

@immutable
class TransportDriver {
  const TransportDriver({
    required this.id,
    required this.name,
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.phone,
    required this.assignedBus,
    required this.attendancePercent,
    required this.rating,
    required this.status,
  });

  final String id;
  final String name;
  final String licenseNumber;
  final String licenseExpiry;
  final String phone;
  final String assignedBus;
  final String attendancePercent;
  final String rating;
  final TransportDriverStatus status;
}

@immutable
class VehicleAssignment {
  const VehicleAssignment({
    required this.id,
    required this.busNumber,
    required this.routeName,
    required this.driverName,
    required this.shift,
    required this.studentCount,
    required this.trackingStatus,
    required this.etaLabel,
  });

  final String id;
  final String busNumber;
  final String routeName;
  final String driverName;
  final TransportShift shift;
  final int studentCount;
  final TrackingStatus trackingStatus;
  final String etaLabel;
}

@immutable
class StudentTransportAllocation {
  const StudentTransportAllocation({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.pickupStop,
    required this.dropStop,
    required this.routeId,
    required this.routeName,
    required this.busNumber,
    required this.shift,
    required this.sisStudentId,
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String pickupStop;
  final String dropStop;

  /// Empty when the student is not assigned to a route.
  final String routeId;
  final String routeName;
  final String busNumber;
  final TransportShift shift;
  final String sisStudentId;

  bool get isAssigned => routeId.isNotEmpty;
}

@immutable
class TransportAttendanceRecord {
  const TransportAttendanceRecord({
    required this.id,
    required this.studentName,
    required this.stopName,
    required this.routeName,
    required this.scheduledTime,
    required this.actualTime,
    required this.status,
    required this.parentNotified,
    required this.shift,
  });

  final String id;
  final String studentName;
  final String stopName;
  final String routeName;
  final String scheduledTime;
  final String actualTime;
  final TransportAttendanceStatus status;
  final bool parentNotified;
  final TransportShift shift;
}

@immutable
class TrackingVehicleStatus {
  const TrackingVehicleStatus({
    required this.busNumber,
    required this.routeName,
    required this.driverName,
    required this.status,
    required this.speedKph,
    required this.lastPing,
    required this.nextStop,
    required this.studentCount,
    required this.etaMinutes,
    required this.latitude,
    required this.longitude,
  });

  final String busNumber;
  final String routeName;
  final String driverName;
  final TrackingStatus status;
  final int speedKph;
  final String lastPing;
  final String nextStop;
  final int studentCount;
  final int etaMinutes;
  final double latitude;
  final double longitude;
}

@immutable
class RoutePerformance {
  const RoutePerformance({
    required this.routeName,
    required this.onTimePercent,
    required this.avgDelayMinutes,
    required this.utilizationPercent,
    required this.incidents,
  });

  final String routeName;
  final String onTimePercent;
  final int avgDelayMinutes;
  final int utilizationPercent;
  final int incidents;
}

@immutable
class OccupancyMetrics {
  const OccupancyMetrics({
    required this.totalCapacity,
    required this.allocatedSeats,
    required this.unassignedStudents,
    required this.utilizationPercent,
  });

  final int totalCapacity;
  final int allocatedSeats;
  final int unassignedStudents;
  final int utilizationPercent;
}

@immutable
class TransportDashboardData {
  const TransportDashboardData({
    required this.kpis,
    required this.vehicleAssignments,
    required this.activeDelays,
    required this.routePerformance,
    required this.occupancy,
    required this.aiInsight,
  });

  final List<TransportKpi> kpis;
  final List<VehicleAssignment> vehicleAssignments;
  final List<String> activeDelays;
  final List<RoutePerformance> routePerformance;
  final OccupancyMetrics occupancy;
  final String aiInsight;
}

@immutable
class TransportReportCatalogItem {
  const TransportReportCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.lastGenerated,
  });

  final String id;
  final String title;
  final String description;
  final String lastGenerated;
}

@immutable
class TransportReportsData {
  const TransportReportsData({
    required this.catalog,
    required this.onTimeTrend,
    required this.delayByRoute,
    required this.fuelTrend,
  });

  final List<TransportReportCatalogItem> catalog;
  final List<TransportTrendPoint> onTimeTrend;
  final List<TransportSegment> delayByRoute;
  final List<TransportTrendPoint> fuelTrend;
}

@immutable
class TransportSettingItem {
  const TransportSettingItem({
    required this.id,
    required this.label,
    required this.value,
    required this.description,
    required this.editable,
  });

  final String id;
  final String label;
  final String value;
  final String description;
  final bool editable;
}

@immutable
class TransportSettingsSection {
  const TransportSettingsSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<TransportSettingItem> items;
}

@immutable
class TransportSettingsData {
  const TransportSettingsData({
    required this.sections,
    required this.defaultShift,
  });

  final List<TransportSettingsSection> sections;
  final TransportShift defaultShift;
}

@immutable
class TransportDelayNotificationResult {
  const TransportDelayNotificationResult({
    required this.routeName,
    required this.recipientCount,
  });

  final String routeName;
  final int recipientCount;
}

@immutable
class TransportTrackingPlaceholderData {
  const TransportTrackingPlaceholderData({
    required this.vehicles,
    required this.mapPlaceholderLabel,
    required this.integrationNote,
    required this.parentAppRoute,
  });

  final List<TrackingVehicleStatus> vehicles;
  final String mapPlaceholderLabel;
  final String integrationNote;
  final String parentAppRoute;
}
