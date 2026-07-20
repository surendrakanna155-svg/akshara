import { ModuleSettingsPage } from '@/components/system/ModuleSettingsPage';
import { HR_TABS } from './shared';

export function HrSettingsPage() {
  return <ModuleSettingsPage title="HR settings" subtitle="Configure HR & payroll" endpoint="/hr/settings" tabs={HR_TABS} />;
}
