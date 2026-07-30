import { useNavigate, useParams } from 'react-router-dom';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Badge, Card, CardHeader, DataTable, PageHeader, Text, type Column } from '@/components/ui';
import { formatDateTime, humanize } from '@/lib/utils/format';
import type { SupportIncident } from '@/lib/contracts/support';
import { useClusterDetail, type ClusterDetail } from './hooks';
import { SeverityChip, SupportStatusChip } from './shell';

export function SupportClusterDetailPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const query = useClusterDetail(id);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Cluster"
        icon="hub"
        breadcrumbs={[
          { label: 'Support Console', onClick: () => navigate('/support-console') },
          { label: 'Clusters', onClick: () => navigate('/support-console/clusters') },
          { label: 'Detail' },
        ]}
      />
      <AsyncBoundary
        query={query}
        unavailableTitle="Cluster detail is ready"
        unavailableMessage="The cluster and its member incidents will load here once a live platform-support session is connected."
      >
        {(data) => <ClusterView data={data} onOpenIncident={(iid) => navigate(`/support-console/incidents/${iid}`)} />}
      </AsyncBoundary>
    </div>
  );
}

function ClusterView({ data, onOpenIncident }: { data: ClusterDetail; onOpenIncident: (id: string) => void }) {
  const { cluster, incidents } = data;

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
      key: 'sourceSchoolId',
      header: 'School',
      hideOnMobile: true,
      render: (r) => <span className="ak-mono text-[12px] text-on-surface-variant">{r.sourceSchoolId || '—'}</span>,
    },
    {
      key: 'severity',
      header: 'Severity',
      sortValue: (r) => r.severity,
      render: (r) => <SeverityChip severity={r.severity} />,
    },
    {
      key: 'supportStatus',
      header: 'Support status',
      sortValue: (r) => r.supportStatus,
      render: (r) => <SupportStatusChip status={r.supportStatus} />,
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
    <div className="space-y-s6">
      <Card>
        <div className="flex flex-wrap items-start justify-between gap-s3">
          <div className="min-w-0">
            <Text variant="headline-sm" as="h2" className="text-on-surface">
              {cluster.title || humanize(cluster.clusterKey) || 'Cluster'}
            </Text>
            <Text variant="body-sm" className="ak-mono text-on-surface-variant">
              {cluster.clusterKey}
            </Text>
          </div>
          <div className="flex flex-wrap items-center gap-s2">
            <Badge tone="primary">
              {cluster.incidentCount} school{cluster.incidentCount === 1 ? '' : 's'}
            </Badge>
            <Badge tone={cluster.status === 'resolved' ? 'success' : 'neutral'}>{humanize(cluster.status) || '—'}</Badge>
          </div>
        </div>
        <div className="mt-s3 flex flex-wrap gap-s2">
          {cluster.category && <Badge tone="neutral">{humanize(cluster.category)}</Badge>}
          {cluster.moduleKey && <Badge tone="neutral">{humanize(cluster.moduleKey)}</Badge>}
          <Badge tone="neutral">Updated {formatDateTime(cluster.updatedAt)}</Badge>
        </div>
        {(cluster.rootCause || cluster.resolution) && (
          <div className="mt-s4 grid grid-cols-1 gap-s4 sm:grid-cols-2">
            {cluster.rootCause && (
              <div className="rounded-md border border-outline-variant/60 bg-surface-low p-s4">
                <Text variant="label-lg" className="text-on-surface-variant">
                  Root cause
                </Text>
                <Text variant="body-md" className="whitespace-pre-wrap text-on-surface">
                  {cluster.rootCause}
                </Text>
              </div>
            )}
            {cluster.resolution && (
              <div className="rounded-md border border-outline-variant/60 bg-surface-low p-s4">
                <Text variant="label-lg" className="text-on-surface-variant">
                  Resolution
                </Text>
                <Text variant="body-md" className="whitespace-pre-wrap text-on-surface">
                  {cluster.resolution}
                </Text>
              </div>
            )}
          </div>
        )}
      </Card>

      <Card padded={false}>
        <div className="px-s5 pt-s5">
          <CardHeader title="Member incidents" subtitle={`${incidents.length} affected`} icon="list_alt" />
        </div>
        <DataTable
          columns={columns}
          rows={incidents}
          rowKey={(r) => r.id}
          onRowClick={(r) => onOpenIncident(r.id)}
          emptyTitle="No member incidents"
          emptyIcon="list_alt"
        />
      </Card>
    </div>
  );
}
