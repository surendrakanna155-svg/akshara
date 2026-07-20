import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Badge, Card, DataTable, Input, PageHeader, Tabs, Text, type Column, type TabItem } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { formatDateTime, humanize } from '@/lib/utils/format';
import type { SupportIncident } from '@/lib/contracts/support';
import { SUPPORT_STATUS_ORDER, supportStatusMeta } from '@/lib/contracts/support';
import { useClusters, useIncidents } from './hooks';
import { ClusterBadge, SeverityChip, SupportSectionNav, SupportStatusChip } from './shell';

function AssignmentCell({ assignedTo }: { assignedTo: string | null }) {
  if (!assignedTo)
    return (
      <span className="inline-flex items-center gap-s1 ak-label-md text-on-surface-variant/80">
        <Icon name="person_off" size={16} />
        Unassigned
      </span>
    );
  return (
    <span className="inline-flex items-center gap-s1 ak-label-md text-on-surface" title={assignedTo}>
      <Icon name="account_circle" size={16} className="text-primary" />
      <span className="ak-mono text-[12px]">{assignedTo.slice(0, 8)}</span>
    </span>
  );
}

const STATUS_TAB_ALL = 'all';

export function SupportQueuePage() {
  const navigate = useNavigate();
  // Fetch a working page unfiltered so the status tabs can show live counts and
  // group client-side. `useIncidents` carries the server-side status/paging
  // params for future scale-out.
  const incidentsQuery = useIncidents({ pageSize: 200 });
  const clustersQuery = useClusters({ pageSize: 200 });
  const [statusTab, setStatusTab] = useState<string>(STATUS_TAB_ALL);
  const [search, setSearch] = useState('');

  const clusterSize = useMemo(() => {
    const map = new Map<string, number>();
    for (const c of clustersQuery.data?.items ?? []) map.set(c.id, c.incidentCount);
    return map;
  }, [clustersQuery.data]);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Support Console"
        subtitle="Platform incident triage — investigate once, resolve many"
        icon="support_agent"
        tabs={<SupportSectionNav />}
      />

      <AsyncBoundary
        query={incidentsQuery}
        unavailableTitle="Support queue is ready"
        unavailableMessage="The cross-tenant incident queue will load here once a live platform-support session is connected."
      >
        {(data) => {
          const all = data.items;
          const counts = new Map<string, number>();
          for (const s of SUPPORT_STATUS_ORDER) counts.set(s, 0);
          for (const inc of all) counts.set(inc.supportStatus, (counts.get(inc.supportStatus) ?? 0) + 1);

          const tabs: TabItem[] = [
            { key: STATUS_TAB_ALL, label: 'All', count: all.length },
            ...SUPPORT_STATUS_ORDER.map((s) => ({
              key: s,
              label: supportStatusMeta(s).label,
              icon: supportStatusMeta(s).icon,
              count: counts.get(s) ?? 0,
            })),
          ];

          const term = search.trim().toLowerCase();
          const rows = all.filter((inc) => {
            if (statusTab !== STATUS_TAB_ALL && inc.supportStatus !== statusTab) return false;
            if (!term) return true;
            return (
              inc.publicRef.toLowerCase().includes(term) ||
              inc.title.toLowerCase().includes(term) ||
              inc.category.toLowerCase().includes(term) ||
              inc.moduleKey.toLowerCase().includes(term)
            );
          });

          const columns: Column<SupportIncident>[] = [
            {
              key: 'publicRef',
              header: 'Reference',
              sortValue: (r) => r.publicRef,
              render: (r) => (
                <div className="min-w-0">
                  <div className="ak-mono text-[12px] text-on-surface-variant">{r.publicRef || '—'}</div>
                  <div className="truncate ak-label-lg text-on-surface">{r.title || 'Untitled incident'}</div>
                </div>
              ),
            },
            {
              key: 'category',
              header: 'Category',
              hideOnMobile: true,
              sortValue: (r) => r.category,
              render: (r) => <Badge tone="neutral">{humanize(r.category) || '—'}</Badge>,
            },
            {
              key: 'moduleKey',
              header: 'Module',
              hideOnMobile: true,
              sortValue: (r) => r.moduleKey,
              render: (r) => humanize(r.moduleKey) || '—',
            },
            {
              key: 'severity',
              header: 'Severity',
              sortValue: (r) => r.severity,
              render: (r) => <SeverityChip severity={r.severity} />,
            },
            {
              key: 'sourceStatus',
              header: 'Source',
              hideOnMobile: true,
              sortValue: (r) => r.sourceStatus,
              render: (r) => <span className="ak-label-md text-on-surface-variant">{humanize(r.sourceStatus) || '—'}</span>,
            },
            {
              key: 'cluster',
              header: 'Cluster',
              render: (r) => (r.clusterId ? <ClusterBadge count={clusterSize.get(r.clusterId)} /> : <span className="text-on-surface-variant/60">—</span>),
            },
            {
              key: 'supportStatus',
              header: 'Support status',
              sortValue: (r) => r.supportStatus,
              render: (r) => <SupportStatusChip status={r.supportStatus} />,
            },
            {
              key: 'assignedTo',
              header: 'Assignee',
              hideOnMobile: true,
              render: (r) => <AssignmentCell assignedTo={r.assignedTo} />,
            },
            {
              key: 'updatedAt',
              header: 'Updated',
              align: 'right',
              hideOnMobile: true,
              sortValue: (r) => r.updatedAt,
              render: (r) => <span className="ak-body-sm text-on-surface-variant">{formatDateTime(r.updatedAt)}</span>,
            },
          ];

          return (
            <Card padded={false}>
              <div className="border-b border-outline-variant/60 px-s4 pt-s2">
                <Tabs items={tabs} value={statusTab} onChange={setStatusTab} />
              </div>
              <div className="flex flex-wrap items-center gap-s2 border-b border-outline-variant/60 p-s4">
                <div className="min-w-[240px] flex-1">
                  <Input
                    leadingIcon="search"
                    placeholder="Search reference, title, category, module…"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </div>
                <Text variant="body-sm" className="ml-auto text-on-surface-variant">
                  {rows.length} of {data.total}
                  {data.hasMore ? ' · showing first page' : ''}
                </Text>
              </div>
              <DataTable
                columns={columns}
                rows={rows}
                rowKey={(r) => r.id}
                onRowClick={(r) => navigate(`/support-console/incidents/${r.id}`)}
                emptyTitle="No incidents in this view"
                emptyMessage="Nothing matches the selected support status and search."
                emptyIcon="inbox"
              />
            </Card>
          );
        }}
      </AsyncBoundary>
    </div>
  );
}
