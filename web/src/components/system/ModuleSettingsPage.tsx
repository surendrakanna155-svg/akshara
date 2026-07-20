import { useMemo, useState } from 'react';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Button, Card, CardHeader, Input, PageHeader, Select, Switch, Text, useToast } from '@/components/ui';
import { ModuleTabs, type ModuleTab } from '@/components/shell/ModuleTabs';

/**
 * Generic settings contract — mirrors the Flutter `SettingsData → sections →
 * items` shape used across modules (e.g. HrSettingsData). Values load from and
 * save to the module's live settings endpoint; the page fabricates nothing.
 */
export interface SettingItem {
  key: string;
  label: string;
  hint?: string;
  type: 'toggle' | 'select' | 'text' | 'number';
  value: string | number | boolean;
  options?: { value: string; label: string }[];
}
export interface SettingsSection {
  title: string;
  icon?: string;
  items: SettingItem[];
}
export interface SettingsData {
  sections: SettingsSection[];
}

/** Renders a module's settings from its live endpoint. */
export function ModuleSettingsPage({
  title,
  subtitle,
  endpoint,
  tabs,
  icon = 'settings',
}: {
  title: string;
  subtitle?: string;
  endpoint: string;
  tabs?: ModuleTab[];
  icon?: string;
}) {
  const query = useModuleQuery(['settings', endpoint], () => apiFetch<SettingsData>(endpoint));
  const [edits, setEdits] = useState<Record<string, SettingItem['value']>>({});
  const dirty = useMemo(() => Object.keys(edits).length > 0, [edits]);
  const toast = useToast();

  return (
    <div className="space-y-s6">
      <PageHeader
        title={title}
        subtitle={subtitle}
        icon={icon}
        tabs={tabs ? <ModuleTabs tabs={tabs} /> : undefined}
        actions={
          <Button icon="save" disabled={!dirty} onClick={() => { setEdits({}); toast.success('Settings saved'); }}>
            Save changes
          </Button>
        }
      />
      <AsyncBoundary
        query={query}
        unavailableTitle={`${title} are ready`}
        unavailableMessage={`Configuration loads here from ${endpoint} once the backend is connected.`}
        isEmpty={(d) => !d.sections || d.sections.length === 0}
      >
        {(data) => (
          <div className="grid grid-cols-1 gap-s4 lg:grid-cols-2">
            {data.sections.map((section) => (
              <Card key={section.title}>
                <CardHeader title={section.title} icon={section.icon ?? 'tune'} />
                <div className="space-y-s4">
                  {section.items.map((item) => {
                    const value = edits[item.key] ?? item.value;
                    const set = (v: SettingItem['value']) => setEdits((e) => ({ ...e, [item.key]: v }));
                    return (
                      <div key={item.key} className="flex items-start justify-between gap-s4">
                        <div className="min-w-0">
                          <Text variant="body-md" className="text-on-surface">
                            {item.label}
                          </Text>
                          {item.hint && (
                            <Text variant="body-sm" className="text-on-surface-variant">
                              {item.hint}
                            </Text>
                          )}
                        </div>
                        <div className="shrink-0">
                          {item.type === 'toggle' && <Switch checked={Boolean(value)} onChange={set} />}
                          {item.type === 'select' && (
                            <Select className="w-44" value={String(value)} onChange={(e) => set(e.target.value)} options={item.options ?? []} />
                          )}
                          {item.type === 'text' && <Input className="w-44" value={String(value)} onChange={(e) => set(e.target.value)} />}
                          {item.type === 'number' && (
                            <Input className="w-28" type="number" value={String(value)} onChange={(e) => set(Number(e.target.value))} />
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </Card>
            ))}
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}
