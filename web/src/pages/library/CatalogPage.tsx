import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { Button, StatusChip, type Column } from '@/components/ui';
import type { LibraryBook } from '@/lib/contracts/library';
import { BOOK_STATUS, LIBRARY_TABS } from './shared';

const fetchCatalog = () => fetchList<LibraryBook>('/library/catalog', { query: { pageSize: 300 } });

export function CatalogPage() {
  const query = useModuleQuery<ListResult<LibraryBook>>(['library', 'catalog'], fetchCatalog);
  const columns: Column<LibraryBook>[] = [
    {
      key: 'title',
      header: 'Book',
      sortValue: (r) => r.title,
      render: (r) => (
        <div className="min-w-0">
          <div className="truncate ak-label-lg text-on-surface">{r.title}</div>
          <div className="truncate text-[12px] text-on-surface-variant">{r.author}</div>
        </div>
      ),
    },
    { key: 'isbn', header: 'ISBN', hideOnMobile: true, render: (r) => <span className="ak-mono text-[12px]">{r.isbn}</span> },
    { key: 'category', header: 'Category', hideOnMobile: true },
    { key: 'shelf', header: 'Shelf', hideOnMobile: true },
    { key: 'availableCopies', header: 'Copies', align: 'right', render: (r) => `${r.availableCopies}/${r.totalCopies}` },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip {...BOOK_STATUS[r.status]} icon={false} /> },
  ];
  return (
    <ResourceList
      title="Catalog"
      subtitle="Book catalog"
      icon="menu_book"
      tabs={LIBRARY_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      actions={<Button icon="add">Add book</Button>}
      search={{ placeholder: 'Search title, author, ISBN…', match: (r, t) => r.title.toLowerCase().includes(t) || r.author.toLowerCase().includes(t) || r.isbn.toLowerCase().includes(t) }}
      filters={[{ key: 'status', placeholder: 'All statuses', options: Object.entries(BOOK_STATUS).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.status === v }]}
      unavailableTitle="Catalog is ready"
      unavailableMessage="The book catalog loads here from /library/catalog once the backend is connected."
    />
  );
}
