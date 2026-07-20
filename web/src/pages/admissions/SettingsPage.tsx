import { useState } from 'react';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Button, Card, CardHeader, Input, PageHeader, Select, Switch, Text } from '@/components/ui';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { ADMISSIONS_TABS } from './shared';

// Contract loaded from /admissions/settings. Field alignment with the live DTO is
// tracked as a data-contract verification item (endpoint exists; see gap register).
interface AdmissionsSettings {
  autoAssignCounselor: boolean;
  requireDocumentsBeforeApproval: boolean;
  notifyParentOnStageChange: boolean;
  defaultAcademicYear: string;
  leadAutoArchiveDays: number;
}

const fetchSettings = () => apiFetch<AdmissionsSettings>('/admissions/settings');

export function AdmissionsSettingsPage() {
  const query = useModuleQuery(['admissions', 'settings'], fetchSettings);
  const [form, setForm] = useState<AdmissionsSettings | null>(null);
  const value = form ?? query.data ?? null;

  function set<K extends keyof AdmissionsSettings>(key: K, v: AdmissionsSettings[K]) {
    if (!value) return;
    setForm({ ...value, [key]: v });
  }

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Admissions settings"
        subtitle="Configure the admissions workflow"
        icon="settings"
        tabs={<ModuleTabs tabs={ADMISSIONS_TABS} />}
        actions={
          <Button icon="save" disabled={!form}>
            Save changes
          </Button>
        }
      />

      <AsyncBoundary
        query={query}
        unavailableTitle="Admissions settings are ready"
        unavailableMessage="Workflow configuration loads here from /admissions/settings once the backend is connected."
      >
        {() =>
          value && (
            <div className="grid grid-cols-1 gap-s4 lg:grid-cols-2">
              <Card>
                <CardHeader title="Workflow" icon="account_tree" />
                <div className="space-y-s4">
                  <Row label="Auto-assign counselor to new leads" hint="Round-robin new enquiries across available counselors.">
                    <Switch checked={value.autoAssignCounselor} onChange={(v) => set('autoAssignCounselor', v)} />
                  </Row>
                  <Row label="Require documents before approval" hint="Block approval until all mandatory documents are verified.">
                    <Switch checked={value.requireDocumentsBeforeApproval} onChange={(v) => set('requireDocumentsBeforeApproval', v)} />
                  </Row>
                  <Row label="Notify parent on stage change" hint="Send an update when a lead advances stage.">
                    <Switch checked={value.notifyParentOnStageChange} onChange={(v) => set('notifyParentOnStageChange', v)} />
                  </Row>
                </div>
              </Card>
              <Card>
                <CardHeader title="Defaults" icon="tune" />
                <div className="space-y-s4">
                  <Select
                    label="Default academic year"
                    value={value.defaultAcademicYear}
                    onChange={(e) => set('defaultAcademicYear', e.target.value)}
                    options={['2025-26', '2026-27', '2027-28'].map((y) => ({ value: y, label: y }))}
                  />
                  <Input
                    label="Auto-archive inactive leads after (days)"
                    type="number"
                    value={value.leadAutoArchiveDays}
                    onChange={(e) => set('leadAutoArchiveDays', Number(e.target.value))}
                  />
                </div>
              </Card>
            </div>
          )
        }
      </AsyncBoundary>
    </div>
  );
}

function Row({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-s4">
      <div className="min-w-0">
        <Text variant="body-md" className="text-on-surface">
          {label}
        </Text>
        {hint && (
          <Text variant="body-sm" className="text-on-surface-variant">
            {hint}
          </Text>
        )}
      </div>
      {children}
    </div>
  );
}
