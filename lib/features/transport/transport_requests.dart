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
  });

  final String allocationId;
  final String routeId;
  final String pickupStop;
  final String dropStop;
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
