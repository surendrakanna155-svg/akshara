import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, Tooltip, type Column } from '@/components/ui';
import { Icon } from '@/components/Icon';
import type { LibraryDigitalResource } from '@/lib/contracts/library';
import { humanize } from '@/lib/utils/format';
import { LIBRARY_TABS } from './shared';

const TYPE_ICON = { ebook: 'menu_book', pdf: 'picture_as_pdf', link: 'link', video: 'smart_display' } as const;

const fetchResources = () => fetchList<LibraryDigitalResource>('/library/digital-resources', { query: { pageSize: 300 } });

export function ResourcesPage() {
  const query = useModuleQuery<ListResult<LibraryDigitalResource>>(['library', 'resources'], fetchResources);
  const columns: Column<LibraryDigitalResource>[] = [
    {
      key: 'title',
      header: 'Resource',
      sortValue: (r) => r.title,
      render: (r) => (
        <div className="flex items-center gap-s3">
          <Icon name={TYPE_ICON[r.type]} size={20} className="text-on-surface-variant" />
          <span className="ak-label-lg text-on-surface">{r.title}</span>
        </div>
      ),
    },
    { key: 'type', header: 'Type', render: (r) => humanize(r.type) },
    { key: 'classAccess', header: 'Access', hideOnMobile: true },
    { key: 'downloads', header: 'Downloads', align: 'right', sortValue: (r) => r.downloads },
    {
      key: 'visibility',
      header: 'Visible in',
      align: 'right',
      hideOnMobile: true,
      render: (r) => (
        <div className="flex justify-end gap-s1">
          {r.studentAppVisible && <Tooltip label="Student app"><Icon name="school" size={18} className="text-tertiary" /></Tooltip>}
          {r.teacherAppVisible && <Tooltip label="Teacher app"><Icon name="cast_for_education" size={18} className="text-indigo" /></Tooltip>}
        </div>
      ),
    },
  ];
  return (
    <ResourceList
      title="Digital resources"
      subtitle="E-books, PDFs, links and videos"
      icon="cloud"
      tabs={LIBRARY_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      actions={<Button icon="add">Add resource</Button>}
      search={{ placeholder: 'Search resource…', match: (r, t) => r.title.toLowerCase().includes(t) }}
      filters={[{ key: 'type', placeholder: 'All types', options: ['ebook', 'pdf', 'link', 'video'].map((v) => ({ value: v, label: humanize(v) })), match: (r, v) => r.type === v }]}
      unavailableTitle="Digital resources are ready"
      unavailableMessage="Digital resources load here from /library/digital-resources once the backend is connected."
    />
  );
}
