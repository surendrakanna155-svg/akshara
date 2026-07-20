import type { SemanticStatus } from '@/components/ui';
import type {
  TransportAttendanceStatus,
  TransportDriverStatus,
  TransportRouteStatus,
  TransportVehicleStatus,
} from '@/lib/contracts/transport';
import { MODULE_TABS } from '@/routes/navConfig';

export const TRANSPORT_TABS = MODULE_TABS.transport;

export const ROUTE_STATUS: Record<TransportRouteStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' },
  draft: { status: 'neutral', label: 'Draft' },
  inactive: { status: 'neutral', label: 'Inactive' },
};

export const VEHICLE_STATUS: Record<TransportVehicleStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' },
  maintenance: { status: 'warning', label: 'Maintenance' },
  retired: { status: 'neutral', label: 'Retired' },
};

export const DRIVER_STATUS: Record<TransportDriverStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' },
  onLeave: { status: 'warning', label: 'On leave' },
  inactive: { status: 'neutral', label: 'Inactive' },
};

export const TRANSPORT_ATTENDANCE: Record<TransportAttendanceStatus, { status: SemanticStatus; label: string }> = {
  picked: { status: 'success', label: 'Picked up' },
  waiting: { status: 'info', label: 'Waiting' },
  absent: { status: 'error', label: 'Absent' },
  notScheduled: { status: 'neutral', label: 'Not scheduled' },
};

export const SHIFT_LABEL = { am: 'Morning', pm: 'Afternoon', both: 'Both' } as const;
