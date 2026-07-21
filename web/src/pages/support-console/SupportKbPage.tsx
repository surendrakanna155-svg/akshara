import { useState } from 'react';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { Badge, Button, Card, DataTable, Dialog, Input, PageHeader, Text, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { formatDateTime, humanize } from '@/lib/utils/format';
import type { SupportKbArticle } from '@/lib/contracts/support';
import { useKbArticles } from './hooks';
import { SupportSectionNav } from './shell';

/**
 * ASIP-8 Continuous Learning — the knowledge base of resolutions the support team
 * has learned. Each article is keyed by an incident signature; when a new
 * incident shares that signature, the workspace recalls the article ("we've seen
 * this before"). Deterministic recall needs no embeddings.
 */
export function SupportKbPage() {
  const [search, setSearch] = useState('');
  const query = useKbArticles({ q: search.trim() || undefined, pageSize: 200 });
  const [active, setActive] = useState<SupportKbArticle | null>(null);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Support Console"
        subtitle="Knowledge base — resolutions the platform has learned"
        icon="support_agent"
        tabs={<SupportSectionNav />}
      />

      <AsyncBoundary
        query={query}
        unavailableTitle="Knowledge base is ready"
        unavailableMessage="Every resolved incident is distilled into a reusable article, keyed by its signature. Articles appear here once a live platform-support session is connected and incidents have been resolved."
      >
        {(data) => {
          const columns: Column<SupportKbArticle>[] = [
            {
              key: 'title',
              header: 'Learned resolution',
              sortValue: (r) => r.title || r.fingerprint,
              render: (r) => (
                <div className="min-w-0">
                  <div className="truncate ak-label-lg text-on-surface">{r.title || humanize(r.category) || 'Article'}</div>
                  <div className="ak-mono text-[12px] text-on-surface-variant truncate">{r.fingerprint}</div>
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
              key: 'resolvedCount',
              header: 'Resolved',
              align: 'right',
              sortValue: (r) => r.resolvedCount,
              render: (r) => (
                <span className="inline-flex items-center gap-s1 ak-label-lg text-on-surface" title="Times this signature was resolved">
                  <Icon name="task_alt" size={16} className="text-success" />
                  {r.resolvedCount}×
                </span>
              ),
            },
            {
              key: 'schoolsSeen',
              header: 'Schools',
              align: 'right',
              hideOnMobile: true,
              sortValue: (r) => r.schoolsSeen,
              render: (r) => (
                <span className="inline-flex items-center gap-s1 ak-label-lg text-on-surface">
                  <Icon name="hub" size={16} className="text-indigo" />
                  {r.schoolsSeen}
                </span>
              ),
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
                    placeholder="Search resolutions, root causes, category, module…"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </div>
                <Text variant="body-sm" className="ml-auto text-on-surface-variant">
                  {data.items.length} article{data.items.length === 1 ? '' : 's'}
                </Text>
              </div>
              <DataTable
                columns={columns}
                rows={data.items}
                rowKey={(r) => r.id}
                onRowClick={(r) => setActive(r)}
                emptyTitle="Nothing learned yet"
                emptyMessage="Resolving incidents builds this knowledge base automatically — each resolution becomes a reusable article keyed by the incident's signature."
                emptyIcon="school"
              />
            </Card>
          );
        }}
      </AsyncBoundary>

      <KbArticleDialog article={active} onClose={() => setActive(null)} />
    </div>
  );
}

function KbArticleDialog({ article, onClose }: { article: SupportKbArticle | null; onClose: () => void }) {
  return (
    <Dialog
      open={!!article}
      onClose={onClose}
      title={article?.title || 'Knowledge base article'}
      subtitle="A learned resolution — recalled automatically for matching incidents"
      icon="menu_book"
      size="lg"
      footer={
        <Button variant="text" onClick={onClose}>
          Close
        </Button>
      }
    >
      {article && (
        <div className="space-y-s4">
          <div className="flex flex-wrap gap-s2">
            <Badge tone="neutral">{humanize(article.category) || 'Uncategorised'}</Badge>
            {article.moduleKey && <Badge tone="primary">{humanize(article.moduleKey)}</Badge>}
            <Badge tone="success">Resolved {article.resolvedCount}×</Badge>
            <Badge tone="primary">
              {article.schoolsSeen} school{article.schoolsSeen === 1 ? '' : 's'}
            </Badge>
          </div>
          <div className="ak-mono text-[12px] text-on-surface-variant break-all">{article.fingerprint}</div>
          <KbField icon="troubleshoot" label="Root cause" value={article.rootCause} />
          <KbField icon="build" label="Resolution" value={article.resolution} />
          <div className="flex flex-wrap items-center gap-s4 ak-body-sm text-on-surface-variant">
            {article.sourceIncidentRef && (
              <span className="inline-flex items-center gap-s1">
                <Icon name="tag" size={14} />
                <span className="ak-mono text-[12px]">{article.sourceIncidentRef}</span>
              </span>
            )}
            <span className="inline-flex items-center gap-s1">
              <Icon name="update" size={14} />
              Updated {formatDateTime(article.updatedAt)}
            </span>
          </div>
        </div>
      )}
    </Dialog>
  );
}

function KbField({ icon, label, value }: { icon: string; label: string; value: string }) {
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
