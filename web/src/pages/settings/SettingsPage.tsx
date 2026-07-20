import { Card, CardHeader, PageHeader, Switch, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { useTheme, type ThemeMode } from '@/theme/ThemeProvider';
import { useAuth } from '@/lib/auth/AuthContext';
import { Avatar } from '@/components/ui';
import { cn } from '@/lib/utils/cn';
import { useState } from 'react';

/** Appearance & preferences — genuine client-side settings (theme is real state). */
export function SettingsPage() {
  const { mode, resolved, setMode } = useTheme();
  const { user } = useAuth();
  const [density, setDensity] = useState(false);
  const [reduceMotion, setReduceMotion] = useState(false);

  const themes: { key: ThemeMode; label: string; icon: string }[] = [
    { key: 'light', label: 'Light', icon: 'light_mode' },
    { key: 'dark', label: 'Dark', icon: 'dark_mode' },
    { key: 'system', label: 'System', icon: 'brightness_auto' },
  ];

  return (
    <div className="space-y-s6">
      <PageHeader title="Settings" subtitle="Appearance & preferences" icon="settings" />

      <div className="grid grid-cols-1 gap-s4 lg:grid-cols-2">
        <Card>
          <CardHeader title="Appearance" icon="palette" />
          <Text variant="label-md" className="mb-s2 text-on-surface-variant">Theme</Text>
          <div className="grid grid-cols-3 gap-s3">
            {themes.map((t) => (
              <button key={t.key} onClick={() => setMode(t.key)}
                className={cn('flex flex-col items-center gap-s2 rounded-lg border p-s4 transition-all',
                  mode === t.key ? 'border-primary bg-primary-container/40 ring-1 ring-primary' : 'border-outline-variant hover:bg-surface-low')}>
                <Icon name={t.icon} size={26} className={mode === t.key ? 'text-primary' : 'text-on-surface-variant'} />
                <span className="ak-label-md text-on-surface">{t.label}</span>
              </button>
            ))}
          </div>
          <Text variant="body-sm" className="mt-s3 text-on-surface-variant">Currently showing the <b className="text-on-surface">{resolved}</b> theme.</Text>
          <div className="mt-s5 space-y-s4">
            <Row label="Compact density" hint="Tighter spacing for dense tables."><Switch checked={density} onChange={setDensity} /></Row>
            <Row label="Reduce motion" hint="Minimise animations and transitions."><Switch checked={reduceMotion} onChange={setReduceMotion} /></Row>
          </div>
        </Card>

        <Card>
          <CardHeader title="Account" icon="account_circle" />
          {user && (
            <div className="flex items-center gap-s3">
              <Avatar name={user.name} size={52} />
              <div>
                <Text variant="title-sm" className="text-on-surface">{user.name}</Text>
                <Text variant="body-sm" className="text-on-surface-variant">{user.schoolName}</Text>
              </div>
            </div>
          )}
          <div className="mt-s5 space-y-s4">
            <Row label="Email notifications" hint="Digest of approvals and alerts."><Switch checked onChange={() => {}} /></Row>
            <Row label="Desktop notifications" hint="Browser push for urgent items."><Switch checked={false} onChange={() => {}} /></Row>
          </div>
          <Text variant="body-sm" className="mt-s4 text-on-surface-variant">
            Profile, security and role settings sync with the ERP account service when signed in with live credentials.
          </Text>
        </Card>
      </div>
    </div>
  );
}

function Row({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-s4">
      <div className="min-w-0">
        <Text variant="body-md" className="text-on-surface">{label}</Text>
        {hint && <Text variant="body-sm" className="text-on-surface-variant">{hint}</Text>}
      </div>
      {children}
    </div>
  );
}
