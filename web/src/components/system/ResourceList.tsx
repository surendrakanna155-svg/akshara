import { useState, type ReactNode } from 'react';
import { AsyncBoundary, type AsyncState } from '@/components/system/AsyncBoundary';
import { Card, DataTable, Input, PageHeader, Select, Text, type Column, type SelectOption } from '@/components/ui';
import type { ListResult } from '@/lib/api/list';
import type { ModuleTab } from '@/components/shell/ModuleTabs';
import { ModuleTabs } from '@/components/shell/ModuleTabs';

export interface FilterDef<T> {
  key: string;
  placeholder: string;
  options: SelectOption[];
  match: (row: T, value: string) => boolean;
  width?: string;
}

export interface ResourceListProps<T> {
  title: string;
  subtitle?: string;
  icon?: string;
  breadcrumbs?: { label: string; onClick?: () => void }[];
  actions?: ReactNode;
  tabs?: ModuleTab[];
  query: AsyncState<ListResult<T>>;
  columns: Column<T>[];
  rowKey: (row: T) => string;
  search?: { placeholder: string; match: (row: T, term: string) => boolean };
  filters?: FilterDef<T>[];
  onRowClick?: (row: T) => void;
  unavailableTitle?: string;
  unavailableMessage?: string;
  emptyTitle?: string;
  emptyIcon?: string;
  /** Extra content (drawers/dialogs) rendered alongside the list. */
  children?: ReactNode;
}

/**
 * The canonical ERP list page: header (+ optional module tabs) → live/states →
 * search + filters → sortable table → optional detail. No fabricated data; all
 * rows come from the live endpoint via `query`.
 */
export function ResourceList<T>({
  title,
  subtitle,
  icon,
  breadcrumbs,
  actions,
  tabs,
  query,
  columns,
  rowKey,
  search,
  filters = [],
  onRowClick,
  unavailableTitle,
  unavailableMessage,
  emptyTitle = 'Nothing matches your filters',
  emptyIcon = 'search_off',
  children,
}: ResourceListProps<T>) {
  const [term, setTerm] = useState('');
  const [state, setState] = useState<Record<string, string>>({});

  return (
    <div className="space-y-s6">
      <PageHeader
        title={title}
        subtitle={subtitle}
        icon={icon}
        breadcrumbs={breadcrumbs}
        actions={actions}
        tabs={tabs ? <ModuleTabs tabs={tabs} /> : undefined}
      />

      <AsyncBoundary query={query} unavailableTitle={unavailableTitle} unavailableMessage={unavailableMessage}>
        {(data) => {
          const t = term.trim().toLowerCase();
          const rows = data.items.filter((r) => {
            if (t && search && !search.match(r, t)) return false;
            for (const f of filters) {
              const v = state[f.key];
              if (v && !f.match(r, v)) return false;
            }
            return true;
          });

          return (
            <Card padded={false}>
              {(search || filters.length > 0) && (
                <div className="flex flex-wrap items-center gap-s2 border-b border-outline-variant/60 p-s4">
                  {search && (
                    <div className="min-w-[220px] flex-1">
                      <Input leadingIcon="search" placeholder={search.placeholder} value={term} onChange={(e) => setTerm(e.target.value)} />
                    </div>
                  )}
                  {filters.map((f) => (
                    <Select
                      key={f.key}
                      className={f.width ?? 'w-40'}
                      placeholder={f.placeholder}
                      value={state[f.key] ?? ''}
                      onChange={(e) => setState((s) => ({ ...s, [f.key]: e.target.value }))}
                      options={f.options}
                    />
                  ))}
                  <Text variant="body-sm" className="ml-auto text-on-surface-variant">
                    {rows.length} of {data.total}
                  </Text>
                </div>
              )}
              <DataTable columns={columns} rows={rows} rowKey={rowKey} onRowClick={onRowClick} emptyTitle={emptyTitle} emptyIcon={emptyIcon} />
            </Card>
          );
        }}
      </AsyncBoundary>

      {children}
    </div>
  );
}
