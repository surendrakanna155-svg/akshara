import { useMemo, useState } from 'react';
import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';
import { EmptyState, LoadingState } from './States';

export interface Column<T> {
  key: string;
  header: string;
  /** Cell renderer; falls back to `row[key]`. */
  render?: (row: T) => React.ReactNode;
  /** Value accessor used for sorting; enables sort when provided. */
  sortValue?: (row: T) => string | number;
  align?: 'left' | 'right' | 'center';
  width?: string;
  className?: string;
  /** Hide below the desktop breakpoint to keep the table readable. */
  hideOnMobile?: boolean;
}

export interface DataTableProps<T> {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  loading?: boolean;
  emptyTitle?: string;
  emptyMessage?: string;
  emptyIcon?: string;
  /** Optional trailing action column (e.g. kebab menu). */
  actions?: (row: T) => React.ReactNode;
  className?: string;
  dense?: boolean;
}

/** Ports the M15 DataTableThemeData — bordered card, highlighted heading row. */
export function DataTable<T>({
  columns,
  rows,
  rowKey,
  onRowClick,
  loading,
  emptyTitle = 'Nothing here yet',
  emptyMessage,
  emptyIcon = 'table_rows',
  actions,
  className,
  dense,
}: DataTableProps<T>) {
  const [sort, setSort] = useState<{ key: string; dir: 'asc' | 'desc' } | null>(null);

  const sorted = useMemo(() => {
    if (!sort) return rows;
    const col = columns.find((c) => c.key === sort.key);
    if (!col?.sortValue) return rows;
    const acc = col.sortValue;
    return [...rows].sort((a, b) => {
      const av = acc(a);
      const bv = acc(b);
      const cmp = typeof av === 'number' && typeof bv === 'number' ? av - bv : String(av).localeCompare(String(bv));
      return sort.dir === 'asc' ? cmp : -cmp;
    });
  }, [rows, sort, columns]);

  function toggleSort(col: Column<T>) {
    if (!col.sortValue) return;
    setSort((s) =>
      s?.key === col.key ? { key: col.key, dir: s.dir === 'asc' ? 'desc' : 'asc' } : { key: col.key, dir: 'asc' },
    );
  }

  const alignClass = (a?: 'left' | 'right' | 'center') =>
    a === 'right' ? 'text-right' : a === 'center' ? 'text-center' : 'text-left';

  return (
    <div className={cn('overflow-hidden rounded-lg border border-outline-variant', className)}>
      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr className="bg-surface-highest">
              {columns.map((c) => (
                <th
                  key={c.key}
                  style={{ width: c.width }}
                  onClick={() => toggleSort(c)}
                  className={cn(
                    'ak-table-header select-none whitespace-nowrap px-s4 py-s3 text-on-surface-variant',
                    alignClass(c.align),
                    c.sortValue && 'cursor-pointer',
                    c.hideOnMobile && 'hidden lg:table-cell',
                  )}
                >
                  <span className="inline-flex items-center gap-s1">
                    {c.header}
                    {sort?.key === c.key && <Icon name={sort.dir === 'asc' ? 'arrow_upward' : 'arrow_downward'} size={14} />}
                  </span>
                </th>
              ))}
              {actions && <th className="w-12 px-s2" />}
            </tr>
          </thead>
          <tbody>
            {sorted.map((row) => (
              <tr
                key={rowKey(row)}
                onClick={() => onRowClick?.(row)}
                className={cn(
                  'border-t border-outline-variant/60 transition-colors',
                  onRowClick && 'cursor-pointer hover:bg-surface-low',
                )}
              >
                {columns.map((c) => (
                  <td
                    key={c.key}
                    className={cn(
                      'ak-table-cell px-s4 text-on-surface',
                      dense ? 'py-s2' : 'py-s3',
                      alignClass(c.align),
                      c.hideOnMobile && 'hidden lg:table-cell',
                      c.className,
                    )}
                  >
                    {c.render ? c.render(row) : (row as Record<string, React.ReactNode>)[c.key]}
                  </td>
                ))}
                {actions && (
                  <td className="px-s2 text-right" onClick={(e) => e.stopPropagation()}>
                    {actions(row)}
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {loading && <LoadingState />}
      {!loading && sorted.length === 0 && <EmptyState icon={emptyIcon} title={emptyTitle} message={emptyMessage} />}
    </div>
  );
}
