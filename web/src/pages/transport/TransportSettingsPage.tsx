import { ModuleSettingsPage } from '@/components/system/ModuleSettingsPage';
import { TRANSPORT_TABS } from './shared';

export function TransportSettingsPage() {
  return <ModuleSettingsPage title="Transport settings" subtitle="Configure fleet, routes and alerts" endpoint="/transport/settings" tabs={TRANSPORT_TABS} />;
}
