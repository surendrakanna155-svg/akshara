import { Button, Card, PageHeader, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs, type ModuleTab } from '@/components/shell/ModuleTabs';

export interface ReportDef {
  key: string;
  title: string;
  description: string;
  icon: string;
  /** Endpoint that generates/exports this report (disabled until backend ready). */
  endpoint?: string;
}

/**
 * Reusable reports catalog. Lists the report types a module offers; each triggers
 * its live export endpoint. No fabricated report data — the catalog is the
 * module's real report menu; generation happens server-side.
 */
export function ReportsHub({
  title,
  subtitle,
  icon,
  tabs,
  reports,
  ready = false,
}: {
  title: string;
  subtitle?: string;
  icon?: string;
  tabs?: ModuleTab[];
  reports: ReportDef[];
  /** When the export endpoint is wired, enable the generate buttons. */
  ready?: boolean;
}) {
  return (
    <div className="space-y-s6">
      <PageHeader title={title} subtitle={subtitle} icon={icon} tabs={tabs ? <ModuleTabs tabs={tabs} /> : undefined} />
      <div className="grid grid-cols-1 gap-s4 sm:grid-cols-2 xl:grid-cols-3">
        {reports.map((r) => (
          <Card key={r.key} className="flex flex-col">
            <span className="mb-s3 grid h-11 w-11 place-items-center rounded-xl bg-primary-container text-on-primary-container">
              <Icon name={r.icon} size={24} />
            </span>
            <Text variant="title-sm" className="text-on-surface">
              {r.title}
            </Text>
            <Text variant="body-sm" className="mt-s1 flex-1 text-on-surface-variant">
              {r.description}
            </Text>
            <div className="mt-s4 flex gap-s2">
              <Button size="sm" variant="outlined" icon="visibility" disabled={!ready}>
                Preview
              </Button>
              <Button size="sm" icon="download" disabled={!ready}>
                Export
              </Button>
            </div>
          </Card>
        ))}
      </div>
      {!ready && (
        <Text variant="body-sm" className="text-on-surface-variant">
          Report generation activates once the module's export endpoint is connected.
        </Text>
      )}
    </div>
  );
}
