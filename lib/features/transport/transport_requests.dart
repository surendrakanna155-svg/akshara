import 'transport_models.dart';

class CreateTransportRouteRequest {
  const CreateTransportRouteRequest({
    required this.name,
    this.distanceKm = '0 km',
    this.amDeparture = '7:00 AM',
    this.pmDeparture = '3:30 PM',
    this.shift = TransportShift.am,
  });

  final String name;
  final String distanceKm;
  final String amDeparture;
  final String pmDeparture;
  final TransportShift shift;
}

class CreateTransportRouteResult {
  const CreateTransportRouteResult({
    required this.route,
  });

  final TransportRoute route;
}

class ActivateTransportRouteRequest {
  const ActivateTransportRouteRequest({required this.routeId});

  final String routeId;
}

class AssignStudentTransportRequest {
  const AssignStudentTransportRequest({
    required this.allocationId,
    required this.routeId,
    required this.pickupStop,
    required this.dropStop,
    this.studentName = '',
    this.admissionNumber = '',
    this.sisStudentId = '',
    this.classLabel = '',
  });

  final String allocationId;
  final String routeId;
  final String pickupStop;
  final String dropStop;

  /// Real SIS student identity carried into the allocation so the server stores
  /// it (previously defaulted to empty strings) and the SIS Student-360 read can
  /// match the allocation back to the student record (the transport "flag").
  final String studentName;
  final String admissionNumber;
  final String sisStudentId;
  final String classLabel;
}

class RecordTransportAttendanceRequest {
  const RecordTransportAttendanceRequest({
    required this.studentName,
    required this.status,
    this.id,
    this.stopName = '',
    this.routeName = '',
    this.scheduledTime = '',
    this.actualTime = '',
    this.parentNotified = false,
    this.shift = TransportShift.am,
  });

  /// Null when recording a fresh entry; set to replace an existing record.
  final String? id;
  final String studentName;
  final String stopName;
  final String routeName;
  final String scheduledTime;
  final String actualTime;
  final TransportAttendanceStatus status;
  final bool parentNotified;
  final TransportShift shift;
}

class TransferStudentTransportRequest {
  const TransferStudentTransportRequest({
    required this.allocationId,
    required this.targetRouteId,
    required this.pickupStop,
    required this.dropStop,
  });

  final String allocationId;
  final String targetRouteId;
  final String pickupStop;
  final String dropStop;
}

class RemoveStudentTransportRequest {
  const RemoveStudentTransportRequest({required this.allocationId});

  final String allocationId;
}

class NotifyRouteDelayRequest {
  const NotifyRouteDelayRequest({
    required this.routeId,
    required this.message,
  });

  final String routeId;
  final String message;
}
