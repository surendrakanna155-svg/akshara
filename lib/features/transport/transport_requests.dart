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
    this.allowOverCapacity = false,
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

  /// TRN-7 — when true, override the route's vehicle capacity guard (the backend
  /// returns 409 CAPACITY_EXCEEDED without it). Set on the confirm-dialog retry.
  final bool allowOverCapacity;

  AssignStudentTransportRequest copyWith({bool? allowOverCapacity}) {
    return AssignStudentTransportRequest(
      allocationId: allocationId,
      routeId: routeId,
      pickupStop: pickupStop,
      dropStop: dropStop,
      studentName: studentName,
      admissionNumber: admissionNumber,
      sisStudentId: sisStudentId,
      classLabel: classLabel,
      allowOverCapacity: allowOverCapacity ?? this.allowOverCapacity,
    );
  }
}

// ─── TRN-1/TRN-2: vehicle & driver CRUD ───────────────────────────────────────

class CreateTransportVehicleRequest {
  const CreateTransportVehicleRequest({
    required this.registration,
    this.model = '',
    this.capacity = 0,
    this.status = TransportVehicleStatus.active,
    this.insuranceExpiry = '',
    this.fitnessExpiry = '',
    this.pucExpiry = '',
    this.permitExpiry = '',
    this.roadTaxExpiry = '',
  });

  final String registration;
  final String model;
  final int capacity;
  final TransportVehicleStatus status;

  /// ISO YYYY-MM-DD; empty = omit the field on the write.
  final String insuranceExpiry;
  final String fitnessExpiry;
  final String pucExpiry;
  final String permitExpiry;
  final String roadTaxExpiry;
}

class UpdateTransportVehicleRequest {
  const UpdateTransportVehicleRequest({
    required this.id,
    this.registration,
    this.model,
    this.capacity,
    this.status,
    this.insuranceExpiry,
    this.fitnessExpiry,
    this.pucExpiry,
    this.permitExpiry,
    this.roadTaxExpiry,
  });

  final String id;

  /// Null = leave unchanged; a value (incl. empty string for dates) = set it.
  final String? registration;
  final String? model;
  final int? capacity;
  final TransportVehicleStatus? status;
  final String? insuranceExpiry;
  final String? fitnessExpiry;
  final String? pucExpiry;
  final String? permitExpiry;
  final String? roadTaxExpiry;
}

class DeleteTransportVehicleRequest {
  const DeleteTransportVehicleRequest({required this.id});

  final String id;
}

class CreateTransportDriverRequest {
  const CreateTransportDriverRequest({
    required this.name,
    required this.licenseNumber,
    this.phone = '',
    this.status = TransportDriverStatus.active,
    this.licenseExpiry = '',
  });

  final String name;
  final String licenseNumber;
  final String phone;
  final TransportDriverStatus status;
  final String licenseExpiry;
}

class UpdateTransportDriverRequest {
  const UpdateTransportDriverRequest({
    required this.id,
    this.name,
    this.licenseNumber,
    this.phone,
    this.status,
    this.licenseExpiry,
  });

  final String id;
  final String? name;
  final String? licenseNumber;
  final String? phone;
  final TransportDriverStatus? status;
  final String? licenseExpiry;
}

class DeleteTransportDriverRequest {
  const DeleteTransportDriverRequest({required this.id});

  final String id;
}

// ─── TRN-4: stop editor ───────────────────────────────────────────────────────

class AddTransportStopRequest {
  const AddTransportStopRequest({
    required this.routeId,
    required this.name,
    this.pickupTime = '',
    this.dropTime = '',
  });

  final String routeId;
  final String name;
  final String pickupTime;
  final String dropTime;
}

class UpdateTransportStopRequest {
  const UpdateTransportStopRequest({
    required this.routeId,
    required this.stopId,
    this.name,
    this.pickupTime,
    this.dropTime,
  });

  final String routeId;
  final String stopId;
  final String? name;
  final String? pickupTime;
  final String? dropTime;
}

class RemoveTransportStopRequest {
  const RemoveTransportStopRequest({
    required this.routeId,
    required this.stopId,
  });

  final String routeId;
  final String stopId;
}

class ReorderTransportStopsRequest {
  const ReorderTransportStopsRequest({
    required this.routeId,
    required this.stopOrder,
  });

  final String routeId;

  /// The full permutation of the route's current stop ids in the new order.
  final List<String> stopOrder;
}

// ─── TRN-5: bulk allocation ───────────────────────────────────────────────────

class BulkAllocateTransportRequest {
  const BulkAllocateTransportRequest({
    required this.routeId,
    required this.pickupStop,
    required this.dropStop,
    this.sisStudentIds = const [],
    this.className,
    this.sectionName,
    this.shift = TransportShift.both,
    this.allowOverCapacity = false,
  });

  final String routeId;
  final String pickupStop;
  final String dropStop;

  /// Explicit student ids OR resolve from [className]/[sectionName].
  final List<String> sisStudentIds;
  final String? className;
  final String? sectionName;
  final TransportShift shift;
  final bool allowOverCapacity;

  BulkAllocateTransportRequest copyWith({bool? allowOverCapacity}) {
    return BulkAllocateTransportRequest(
      routeId: routeId,
      pickupStop: pickupStop,
      dropStop: dropStop,
      sisStudentIds: sisStudentIds,
      className: className,
      sectionName: sectionName,
      shift: shift,
      allowOverCapacity: allowOverCapacity ?? this.allowOverCapacity,
    );
  }
}

// ─── TRN-8: document-expiry reminder ──────────────────────────────────────────

class SendTransportDocumentExpiryReminderRequest {
  const SendTransportDocumentExpiryReminderRequest({this.withinDays = 30});

  final int withinDays;
}

// ─── TRN-9: raise a Finance transport-fee demand ──────────────────────────────

class RaiseTransportDemandRequest {
  const RaiseTransportDemandRequest({
    required this.sisStudentId,
    required this.routeId,
    required this.feeStructureId,
    required this.academicYear,
    this.term = 'annual',
    this.allocationId = '',
  });

  final String sisStudentId;
  final String routeId;
  final String feeStructureId;
  final String academicYear;
  final String term;
  final String allocationId;
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
