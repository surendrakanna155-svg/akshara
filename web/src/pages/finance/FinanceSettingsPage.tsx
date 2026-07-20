import { ModuleSettingsPage } from '@/components/system/ModuleSettingsPage';
import { FINANCE_TABS } from './shared';

export function FinanceSettingsPage() {
  return <ModuleSettingsPage title="Finance settings" subtitle="Configure fees, receipts and reconciliation" endpoint="/finance/settings" tabs={FINANCE_TABS} />;
}
