import { useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import {
  Badge,
  Button,
  Card,
  CardHeader,
  Dialog,
  Divider,
  PageHeader,
  Select,
  StatusChip,
  Text,
  Textarea,
  useToast,
} from '@/components/ui';
import { Icon } from '@/components/Icon';
import { formatDateTime, humanize } from '@/lib/utils/format';
import {
  SUPPORT_STATUS_ORDER,
  supportStatusMeta,
  type SupportCluster,
  type SupportIncident,
  type SupportIncidentDetail,
  type SupportInvestigation,
  type SupportNote,
  type SupportStatus,
} from '@/lib/contracts/support';
import {
  useAddNote,
  useAssignIncident,
  useEscalateIncident,
  useHandoff,
  useIncidentDetail,
  useInvestigateIncident,
  useResolveIncident,
  useSetSupportStatus,
} from './hooks';
import { AiSuggestedBanner, EvidenceCard, JsonBlock, KeyValue, MetaPill } from './components';
import { SeverityChip, SupportStatusChip } from './shell';

export function SupportIncidentPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const query = useIncidentDetail(id);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Incident workspace"
        icon="contact_support"
        breadcrumbs={[
          { label: 'Support Console', onClick: () => navigate('/support-console') },
          { label: 'Incident' },
        ]}
      />
      <AsyncBoundary
        query={query}
        unavailableTitle="Incident workspace is ready"
        unavailableMessage="The full investigation package — evidence, AI diagnosis, notes and resolution — will load here once a live platform-support session is connected."
      >
        {(detail) => <IncidentWorkspace id={id} detail={detail} onRefetch={query.refetch} />}
      </AsyncBoundary>
    </div>
  );
}

function IncidentWorkspace({
  id,
  detail,
  onRefetch,
}: {
  id: string;
  detail: SupportIncidentDetail;
  onRefetch: () => void;
}) {
  const { incident, evidence, notes, cluster } = detail;
  return (
    <div className="grid grid-cols-1 gap-s6 xl:grid-cols-3">
      <div className="space-y-s6 xl:col-span-2">
        <HeaderCard incident={incident} cluster={cluster} />
        <ActionsCard id={id} incident={incident} cluster={cluster} onRefetch={onRefetch} />
        <EvidencePanel evidence={evidence} />
        <AiDiagnosisPanel id={id} />
        <NotesPanel id={id} notes={notes} />
      </div>
      <div className="space-y-s6">
        <DetailsSidebar incident={incident} />
        {cluster && <ClusterSidebar cluster={cluster} />}
      </div>
    </div>
  );
}

function HeaderCard({ incident, cluster }: { incident: SupportIncident; cluster: SupportCluster | null }) {
  return (
    <Card>
      <div className="flex flex-wrap items-start justify-between gap-s3">
        <div className="min-w-0">
          <div className="flex items-center gap-s2">
            <Text variant="body-sm" className="ak-mono text-on-surface-variant">
              {incident.publicRef || '—'}
            </Text>
            {incident.escalatedAt && (
              <span className="inline-flex items-center gap-s1 rounded-full bg-error-container px-s2 py-[2px] ak-label-sm font-medium text-error">
                <Icon name="priority_high" size={14} />
                Escalated
              </span>
            )}
          </div>
          <Text variant="headline-sm" as="h2" className="mt-s1 text-on-surface">
            {incident.title || 'Untitled incident'}
          </Text>
        </div>
        <div className="flex flex-wrap items-center gap-s2">
          <SeverityChip severity={incident.severity} />
          <SupportStatusChip status={incident.supportStatus} />
        </div>
      </div>
      {incident.description && (
        <Text variant="body-md" className="mt-s3 whitespace-pre-wrap text-on-surface-variant">
          {incident.description}
        </Text>
      )}
      <div className="mt-s4 flex flex-wrap gap-s2">
        <Badge tone="neutral">{humanize(incident.category) || 'Uncategorised'}</Badge>
        <Badge tone="neutral">Source: {humanize(incident.sourceStatus) || '—'}</Badge>
        {incident.moduleKey && <Badge tone="primary">{humanize(incident.moduleKey)}</Badge>}
        {cluster && (
          <Badge tone="primary">
            Cluster of {cluster.incidentCount} school{cluster.incidentCount === 1 ? '' : 's'}
          </Badge>
        )}
      </div>
    </Card>
  );
}

function ActionsCard({
  id,
  incident,
  cluster,
  onRefetch,
}: {
  id: string;
  incident: SupportIncident;
  cluster: SupportCluster | null;
  onRefetch: () => void;
}) {
  const toast = useToast();
  const assign = useAssignIncident(id);
  const setStatus = useSetSupportStatus(id);
  const escalate = useEscalateIncident(id);
  const [resolveOpen, setResolveOpen] = useState(false);
  const [handoffOpen, setHandoffOpen] = useState(false);

  const assigned = !!incident.assignedTo;

  return (
    <Card>
      <CardHeader title="Actions" subtitle="Assign, triage, escalate, resolve" icon="bolt" />
      <div className="flex flex-wrap items-center gap-s2">
        <Button
          variant={assigned ? 'outlined' : 'filled'}
          icon="person_add"
          loading={assign.isPending}
          onClick={() =>
            assign.mutate(
              {},
              {
                onSuccess: () => toast.success('Assigned to you'),
                onError: (e) => toast.error(e.message),
              },
            )
          }
        >
          Assign to me
        </Button>
        {assigned && (
          <Button
            variant="text"
            icon="person_remove"
            loading={assign.isPending}
            onClick={() =>
              assign.mutate(
                { assignedTo: null },
                { onSuccess: () => toast.success('Unassigned'), onError: (e) => toast.error(e.message) },
              )
            }
          >
            Unassign
          </Button>
        )}

        <div className="w-px self-stretch bg-outline-variant/60" />

        <div className="flex items-center gap-s2">
          <Text variant="label-md" className="text-on-surface-variant">
            Support status
          </Text>
          <Select
            className="w-52"
            value={incident.supportStatus}
            disabled={setStatus.isPending}
            options={SUPPORT_STATUS_ORDER.map((s) => ({ value: s, label: supportStatusMeta(s).label }))}
            onChange={(e) => {
              const next = e.target.value as SupportStatus;
              if (next === incident.supportStatus) return;
              setStatus.mutate(
                { status: next },
                {
                  onSuccess: () => toast.success(`Status → ${supportStatusMeta(next).label}`),
                  onError: (err) => toast.error(err.message),
                },
              );
            }}
          />
        </div>

        <div className="w-px self-stretch bg-outline-variant/60" />

        <Button
          variant="outlined"
          icon="trending_up"
          loading={escalate.isPending}
          disabled={!!incident.escalatedAt}
          onClick={() =>
            escalate.mutate(undefined, {
              onSuccess: () => toast.success('Escalated to engineering'),
              onError: (e) => toast.error(e.message),
            })
          }
        >
          {incident.escalatedAt ? 'Escalated' : 'Escalate'}
        </Button>
        <Button variant="outlined" icon="ios_share" onClick={() => setHandoffOpen(true)}>
          Engineering handoff
        </Button>
        <Button variant="filled" icon="task_alt" onClick={() => setResolveOpen(true)}>
          Resolve
        </Button>
      </div>

      <ResolveDialog
        id={id}
        open={resolveOpen}
        cluster={cluster}
        onClose={() => setResolveOpen(false)}
        onResolved={onRefetch}
      />
      <HandoffDialog id={id} publicRef={incident.publicRef} open={handoffOpen} onClose={() => setHandoffOpen(false)} />
    </Card>
  );
}

function EvidencePanel({ evidence }: { evidence: SupportIncidentDetail['evidence'] }) {
  return (
    <Card>
      <CardHeader
        title="Evidence"
        subtitle="Auto-captured at report time — client context, breadcrumbs, API calls, audit events, diagnostics"
        icon="fingerprint"
      />
      {evidence.length === 0 ? (
        <Text variant="body-sm" className="italic text-on-surface-variant">
          No evidence snapshot was captured for this incident.
        </Text>
      ) : (
        <div className="space-y-s4">
          {evidence.map((e, i) => (
            <EvidenceCard key={`${e.kind}-${i}`} kind={e.kind} payload={e.payload} collectedAt={e.collectedAt} />
          ))}
        </div>
      )}
    </Card>
  );
}

function AiDiagnosisPanel({ id }: { id: string }) {
  const toast = useToast();
  const investigate = useInvestigateIncident(id);
  const [result, setResult] = useState<SupportInvestigation | null>(null);

  const run = () =>
    investigate.mutate(undefined, {
      onSuccess: (r) => {
        setResult(r);
        toast.success('AI draft ready — review before acting');
      },
      onError: (e) => toast.error(e.message),
    });

  const pct = result ? (result.confidence <= 1 ? Math.round(result.confidence * 100) : Math.round(result.confidence)) : 0;

  return (
    <Card>
      <CardHeader
        title="AI diagnosis"
        subtitle="Deterministic-first draft to speed up triage — the engineer decides"
        icon="neurology"
        action={
          <Button
            size="sm"
            variant={result ? 'outlined' : 'filled'}
            icon="auto_awesome"
            loading={investigate.isPending}
            onClick={run}
          >
            {result ? 'Re-investigate' : 'Investigate'}
          </Button>
        }
      />
      {!result ? (
        <Text variant="body-sm" className="text-on-surface-variant">
          Run an AI-assisted investigation to draft a summary, likely root cause and a recommended fix from the captured
          evidence. Nothing is applied automatically.
        </Text>
      ) : (
        <div className="space-y-s4">
          <AiSuggestedBanner />
          <div className="flex flex-wrap items-center gap-s2">
            <StatusChip
              status={result.method === 'ai_enriched' ? 'pending' : 'info'}
              icon={result.method === 'ai_enriched' ? 'auto_awesome' : 'function'}
              label={result.method === 'ai_enriched' ? 'AI-enriched' : 'Deterministic'}
            />
            <Badge tone="neutral">Confidence {pct}%</Badge>
            {result.model && <Badge tone="neutral">Model: {result.model}</Badge>}
            {result.clusterSize > 0 && <Badge tone="primary">Across {result.clusterSize} incidents</Badge>}
          </div>
          <AiField icon="summarize" label="Summary" value={result.summary} />
          <AiField icon="troubleshoot" label="Likely root cause" value={result.likelyRootCause} />
          <AiField icon="build" label="Recommended fix" value={result.recommendedFix} />
        </div>
      )}
    </Card>
  );
}

function AiField({ icon, label, value }: { icon: string; label: string; value: string }) {
  return (
    <div className="rounded-md border border-outline-variant/60 bg-surface-low p-s4">
      <div className="mb-s1 flex items-center gap-s2">
        <Icon name={icon} size={18} className="text-on-surface-variant" />
        <Text variant="label-lg" className="text-on-surface-variant">
          {label}
        </Text>
      </div>
      <Text variant="body-md" className="whitespace-pre-wrap text-on-surface">
        {value || '—'}
      </Text>
    </div>
  );
}

function NotesPanel({ id, notes }: { id: string; notes: SupportNote[] }) {
  const toast = useToast();
  const addNote = useAddNote(id);
  const [draft, setDraft] = useState('');

  const submit = () => {
    const body = draft.trim();
    if (!body) return;
    addNote.mutate(
      { body },
      {
        onSuccess: () => {
          setDraft('');
          toast.success('Note added');
        },
        onError: (e) => toast.error(e.message),
      },
    );
  };

  return (
    <Card>
      <CardHeader title="Internal notes" subtitle="Support-team-only working thread" icon="forum" />
      {notes.length === 0 ? (
        <Text variant="body-sm" className="italic text-on-surface-variant">
          No internal notes yet.
        </Text>
      ) : (
        <div className="space-y-s3">
          {notes.map((n) => (
            <div key={n.id} className="rounded-md border border-outline-variant/60 bg-surface-low p-s3">
              <div className="mb-s1 flex items-center gap-s2 ak-label-sm text-on-surface-variant">
                <Icon name="account_circle" size={16} />
                <span className="ak-mono text-[12px]">{n.authorUserId.slice(0, 8) || 'support'}</span>
                <span className="opacity-60">·</span>
                <span>{formatDateTime(n.createdAt)}</span>
              </div>
              <Text variant="body-md" className="whitespace-pre-wrap text-on-surface">
                {n.body}
              </Text>
            </div>
          ))}
        </div>
      )}
      <Divider className="my-s4" />
      <div className="space-y-s2">
        <Textarea
          rows={3}
          placeholder="Add an internal note…"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
        />
        <div className="flex justify-end">
          <Button icon="add_comment" loading={addNote.isPending} disabled={!draft.trim()} onClick={submit}>
            Add note
          </Button>
        </div>
      </div>
    </Card>
  );
}

function DetailsSidebar({ incident }: { incident: SupportIncident }) {
  return (
    <Card>
      <CardHeader title="Environment" subtitle="Where the issue was reported" icon="lan" />
      <div className="grid grid-cols-1 gap-s3">
        <MetaPill icon="widgets" label="Module" value={humanize(incident.moduleKey) || '—'} />
        <MetaPill icon="route" label="Screen route" value={<span className="ak-mono text-[12px]">{incident.screenRoute || '—'}</span>} />
        <MetaPill icon="new_releases" label="App version" value={incident.appVersion || '—'} />
        <MetaPill icon="devices" label="Platform" value={humanize(incident.platform) || '—'} />
      </div>
      <Divider className="my-s4" />
      <div className="space-y-s3">
        <KeyValue icon="fmd_good" label="Source school" value={<span className="ak-mono text-[12px]">{incident.sourceSchoolId || '—'}</span>} />
        <KeyValue icon="schedule" label="First seen" value={formatDateTime(incident.firstSeenAt)} />
        <KeyValue icon="cloud_done" label="Mirrored" value={formatDateTime(incident.mirroredAt)} />
        <KeyValue icon="update" label="Updated" value={formatDateTime(incident.updatedAt)} />
      </div>
    </Card>
  );
}

function ClusterSidebar({ cluster }: { cluster: SupportCluster }) {
  const navigate = useNavigate();
  return (
    <Card>
      <CardHeader title="Cluster" subtitle="Investigate once, resolve many" icon="hub" />
      <Text variant="title-sm" className="text-on-surface">
        {cluster.title || humanize(cluster.clusterKey)}
      </Text>
      <div className="mt-s2 flex flex-wrap gap-s2">
        <Badge tone="primary">
          {cluster.incidentCount} school{cluster.incidentCount === 1 ? '' : 's'}
        </Badge>
        <Badge tone="neutral">{humanize(cluster.status) || '—'}</Badge>
        {cluster.category && <Badge tone="neutral">{humanize(cluster.category)}</Badge>}
      </div>
      {cluster.rootCause && (
        <div className="mt-s3">
          <Text variant="label-md" className="text-on-surface-variant">
            Root cause
          </Text>
          <Text variant="body-sm" className="text-on-surface">
            {cluster.rootCause}
          </Text>
        </div>
      )}
      <Button
        className="mt-s4"
        variant="outlined"
        fullWidth
        icon="open_in_new"
        onClick={() => navigate(`/support-console/clusters/${cluster.id}`)}
      >
        Open cluster
      </Button>
    </Card>
  );
}

function ResolveDialog({
  id,
  open,
  cluster,
  onClose,
  onResolved,
}: {
  id: string;
  open: boolean;
  cluster: SupportCluster | null;
  onClose: () => void;
  onResolved: () => void;
}) {
  const toast = useToast();
  const resolve = useResolveIncident(id);
  const [resolution, setResolution] = useState('');
  const [resolveCluster, setResolveCluster] = useState(false);

  const submit = () => {
    const text = resolution.trim();
    if (!text) return;
    resolve.mutate(
      { resolution: text, resolveCluster: resolveCluster || undefined },
      {
        onSuccess: (r) => {
          toast.success(`Resolved ${r.count} incident${r.count === 1 ? '' : 's'}`);
          setResolution('');
          setResolveCluster(false);
          onResolved();
          onClose();
        },
        onError: (e) => toast.error(e.message),
      },
    );
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Resolve incident"
      subtitle="Records the resolution and closes the incident"
      icon="task_alt"
      footer={
        <>
          <Button variant="text" onClick={onClose}>
            Cancel
          </Button>
          <Button icon="check" loading={resolve.isPending} disabled={!resolution.trim()} onClick={submit}>
            Confirm resolution
          </Button>
        </>
      }
    >
      <div className="space-y-s4">
        <Textarea
          label="Resolution"
          required
          rows={4}
          placeholder="Describe the fix / outcome communicated to the school…"
          value={resolution}
          onChange={(e) => setResolution(e.target.value)}
        />
        {cluster && cluster.incidentCount > 1 && (
          <label className="flex cursor-pointer items-start gap-s2 rounded-md border border-outline-variant/60 bg-surface-low p-s3">
            <input
              type="checkbox"
              className="mt-[3px] h-[18px] w-[18px] accent-primary"
              checked={resolveCluster}
              onChange={(e) => setResolveCluster(e.target.checked)}
            />
            <span>
              <Text variant="label-lg" className="text-on-surface">
                Resolve the whole cluster ({cluster.incidentCount} schools)
              </Text>
              <Text variant="body-sm" className="text-on-surface-variant">
                Applies this resolution to every incident sharing this cluster — "investigate once, resolve many".
              </Text>
            </span>
          </label>
        )}
      </div>
    </Dialog>
  );
}

function HandoffDialog({
  id,
  publicRef,
  open,
  onClose,
}: {
  id: string;
  publicRef: string;
  open: boolean;
  onClose: () => void;
}) {
  const toast = useToast();
  const query = useHandoff(id, open);

  const packageJson = query.data ? JSON.stringify(query.data, null, 2) : '';

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(packageJson);
      toast.success('Engineering package copied');
    } catch {
      toast.error('Could not copy to clipboard');
    }
  };

  const download = () => {
    try {
      const blob = new Blob([packageJson], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${publicRef || 'incident'}-handoff.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      toast.error('Could not download package');
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Engineering handoff"
      subtitle="Complete, deterministic investigation package"
      icon="engineering"
      size="xl"
      footer={
        <>
          <Button variant="text" onClick={onClose}>
            Close
          </Button>
          <Button variant="outlined" icon="content_copy" disabled={!packageJson} onClick={copy}>
            Copy
          </Button>
          <Button icon="download" disabled={!packageJson} onClick={download}>
            Download package
          </Button>
        </>
      }
    >
      <AsyncBoundary
        query={query}
        unavailableTitle="Handoff package ready"
        unavailableMessage="The engineering package assembles once a live platform-support session is connected."
      >
        {(pkg) => (
          <div className="space-y-s4">
            <div className="grid grid-cols-1 gap-s3 sm:grid-cols-2">
              <MetaPill icon="tag" label="Incident ref" value={<span className="ak-mono text-[12px]">{pkg.incidentRef || publicRef}</span>} />
              <MetaPill icon="category" label="Category" value={humanize(pkg.category) || '—'} />
              <MetaPill icon="warning" label="Severity" value={humanize(pkg.severity) || '—'} />
              <MetaPill
                icon="hub"
                label="Cluster"
                value={pkg.cluster ? `${pkg.cluster.affectedIncidents} affected` : 'Not clustered'}
              />
            </div>
            <div>
              <Text variant="label-md" className="mb-s1 text-on-surface-variant">
                Full package (JSON)
              </Text>
              <JsonBlock value={pkg} className="max-h-[45vh]" />
            </div>
          </div>
        )}
      </AsyncBoundary>
    </Dialog>
  );
}
