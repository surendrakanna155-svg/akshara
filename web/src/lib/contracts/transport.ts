/** Transport contracts — mirror lib/features/transport/transport_models.dart. */
export type TransportRouteStatus = 'active' | 'draft' | 'inactive';
export type TransportVehicleStatus = 'active' | 'maintenance' | 'retired';
export type TransportDriverStatus = 'active' | 'onLeave' | 'inactive';
export type TransportShift = 'am' | 'pm' | 'both';
export type TransportAttendanceStatus = 'picked' | 'waiting' | 'absent' | 'notScheduled';

export interface TransportRoute {
  id: string;
  name: string;
  stopCount: number;
  distanceKm: string;
  amDeparture: string;
  pmDeparture: string;
  assignedBus: string;
  studentCount: number;
  status: TransportRouteStatus;
  shift: TransportShift;
}

export interface TransportVehicle {
  id: string;
  busNumber: string;
  registration: string;
  capacity: number;
  routeName: string;
  gpsDeviceId: string;
  insuranceExpiry: string;
  fitnessExpiry: string;
  permitExpiry: string;
  status: TransportVehicleStatus;
  occupancyPercent: number;
  model: string;
}

export interface TransportDriver {
  id: string;
  name: string;
  licenseNumber: string;
  licenseExpiry: string;
  phone: string;
  assignedBus: string;
  attendancePercent: string;
  rating: string;
  status: TransportDriverStatus;
}

export interface StudentTransportAllocation {
  id: string;
  studentName: string;
  admissionNumber: string;
  classLabel: string;
  pickupStop: string;
  dropStop: string;
  routeName: string;
  busNumber: string;
  shift: TransportShift;
}

export interface TransportAttendanceRecord {
  id: string;
  studentName: string;
  stopName: string;
  routeName: string;
  scheduledTime: string;
  actualTime: string;
  status: TransportAttendanceStatus;
  parentNotified: boolean;
  shift: TransportShift;
}

export interface TransportKpi {
  id: string;
  label: string;
  value: string;
  delta?: number;
}

export interface TransportDashboardData {
  kpis: TransportKpi[];
  activeDelays: string[];
  aiInsight?: string;
}
