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
