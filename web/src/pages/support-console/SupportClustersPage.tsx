import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Badge, Card, DataTable, Input, PageHeader, Select, Text, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { formatDateTime, humanize } from '@/lib/utils/format';
import type { SupportCluster } from '@/lib/contracts/support';
import { useClusters } from './hooks';
import { SupportSectionNav } from './shell';

export function SupportClustersPage() {
  const navigate = useNavigate();
  const query = useClusters({ pageSize: 200 });
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  const statuses = useMemo(
    () => Array.from(new Set((query.data?.items ?? []).map((c) => c.status).filter(Boolean))).sort(),
    [query.data],
  );

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Support Console"
        subtitle="Incident clusters — investigate once, resolve many"
        icon="support_agent"
        tabs={<SupportSectionNav />}
      />

      <AsyncBoundary
        query={query}
        unavailableTitle="Clusters are ready"
        unavailableMessage="Deterministically-clustered incidents (same category, module and error signature across schools) will load here once a live platform-support session is connected."
      >
        {(data) => {
          const term = search.trim().toLowerCase();
          const rows = data.items.filter((c) => {
            if (statusFilter && c.status !== statusFilter) return false;
            if (!term) return true;
            return (
              c.title.toLowerCase().includes(term) ||
              c.category.toLowerCase().includes(term) ||
              c.moduleKey.toLowerCase().includes(term) ||
              c.clusterKey.toLowerCase().includes(term)
            );
          });

          const columns: Column<SupportCluster>[] = [
            {
              key: 'title',
              header: 'Cluster',
              sortValue: (r) => r.title || r.clusterKey,
              render: (r) => (
                <div className="min-w-0">
                  <div className="truncate ak-label-lg text-on-surface">{r.title || humanize(r.clusterKey) || 'Cluster'}</div>
                  <div className="ak-mono text-[12px] text-on-surface-variant">{r.clusterKey}</div>
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
              key: 'incidentCount',
              header: 'Schools',
              align: 'right',
              sortValue: (r) => r.incidentCount,
              render: (r) => (
                <span className="inline-flex items-center gap-s1 ak-label-lg text-on-surface">
                  <Icon name="hub" size={16} className="text-indigo" />
                  {r.incidentCount}
                </span>
              ),
            },
            {
              key: 'status',
              header: 'Status',
              sortValue: (r) => r.status,
              render: (r) => <Badge tone={r.status === 'resolved' ? 'success' : 'primary'}>{humanize(r.status) || '—'}</Badge>,
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
              <div className="flex flex-wrap items-center gap-s2 border-b border-outline-variant/60 p-s4">
                <div className="min-w-[240px] flex-1">
                  <Input
                    leadingIcon="search"
                    placeholder="Search cluster, category, module…"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </div>
                <Select
                  className="w-44"
                  placeholder="All statuses"
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                  options={statuses.map((s) => ({ value: s, label: humanize(s) }))}
                />
                <Text variant="body-sm" className="ml-auto text-on-surface-variant">
                  {rows.length} of {data.total}
                </Text>
              </div>
              <DataTable
                columns={columns}
                rows={rows}
                rowKey={(r) => r.id}
                onRowClick={(r) => navigate(`/support-console/clusters/${r.id}`)}
                emptyTitle="No clusters"
                emptyMessage="Incidents cluster automatically when they share a category, module and error signature across schools."
                emptyIcon="hub"
              />
            </Card>
          );
        }}
      </AsyncBoundary>
    </div>
  );
}
