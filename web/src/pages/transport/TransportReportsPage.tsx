import { ReportsHub } from '@/components/system/ReportsHub';
import { TRANSPORT_TABS } from './shared';

export function TransportReportsPage() {
  return (
    <ReportsHub
      title="Transport reports"
      subtitle="Fleet, occupancy and compliance"
      icon="summarize"
      tabs={TRANSPORT_TABS}
      reports={[
        { key: 'occupancy', title: 'Route occupancy', description: 'Seat utilisation per route and shift.', icon: 'airline_seat_recline_normal', endpoint: '/transport/occupancy-metrics' },
        { key: 'attendance', title: 'Transport attendance', description: 'Pickup/drop attendance trends.', icon: 'fact_check' },
        { key: 'compliance', title: 'Vehicle compliance', description: 'Insurance, fitness, permit and PUC expiries.', icon: 'verified', endpoint: '/transport/reminders/document-expiry' },
        { key: 'drivers', title: 'Driver licenses', description: 'Driver license expiries and ratings.', icon: 'badge' },
      ]}
    />
  );
}
