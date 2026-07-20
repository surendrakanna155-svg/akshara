import { Card, PageHeader, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { TRANSPORT_TABS } from './shared';

/**
 * Live vehicle tracking. Live GPS is a Phase-2 integration — it is a placeholder
 * in the Flutter app too (TransportTrackingPlaceholderData) and is logged as a
 * verified gap (WEB-003) rather than faked. This page is the real UI shell that
 * activates once the GPS integration is enabled.
 */
export function TrackingPage() {
  return (
    <div className="space-y-s6">
      <PageHeader title="Live tracking" subtitle="Real-time fleet positions" icon="my_location" tabs={<ModuleTabs tabs={TRANSPORT_TABS} />} />
      <Card padded={false} className="overflow-hidden">
        <div className="relative grid h-[420px] place-items-center bg-surface-container">
          {/* Map surface placeholder — real tiles + markers render when GPS is wired. */}
          <div
            className="absolute inset-0 opacity-40"
            style={{
              backgroundImage:
                'linear-gradient(rgb(var(--ak-outline-variant)) 1px, transparent 1px), linear-gradient(90deg, rgb(var(--ak-outline-variant)) 1px, transparent 1px)',
              backgroundSize: '32px 32px',
            }}
          />
          <div className="relative z-10 max-w-reading text-center">
            <span className="mx-auto mb-s4 grid h-16 w-16 place-items-center rounded-2xl bg-primary-container text-on-primary-container">
              <Icon name="my_location" size={32} />
            </span>
            <Text variant="title-md" className="text-on-surface">
              Live GPS tracking is a Phase-2 integration
            </Text>
            <Text variant="body-md" className="mt-s1 text-on-surface-variant">
              Real-time bus positions, ETAs and stop progress will render on this map once the vehicle GPS
              integration is enabled (tracked as gap WEB-003). No simulated positions are shown.
            </Text>
          </div>
        </div>
      </Card>
    </div>
  );
}
