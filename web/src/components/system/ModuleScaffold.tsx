import { PageHeader, Card, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';

/**
 * Honest placeholder for a route whose full page is not yet ported from Flutter.
 * Used so navigation is complete while the parity build progresses module by
 * module. Replaced by the real page when that screen is implemented.
 */
export function ModuleScaffold({ title, icon, note }: { title: string; icon?: string; note?: string }) {
  return (
    <div className="space-y-s6">
      <PageHeader title={title} icon={icon} subtitle="Web parity in progress" />
      <Card className="grid place-items-center py-s16 text-center">
        <span className="mb-s4 grid h-16 w-16 place-items-center rounded-2xl bg-primary-container text-on-primary-container">
          <Icon name={icon ?? 'construction'} size={32} />
        </span>
        <Text variant="title-md" className="text-on-surface">
          {title} is being recreated for the web
        </Text>
        <Text variant="body-md" className="mt-s1 max-w-reading text-on-surface-variant">
          {note ??
            'This screen exists in the Akshara mobile app and is on the parity build list. It will be wired to the same design system and live data as the pages already completed.'}
        </Text>
      </Card>
    </div>
  );
}
