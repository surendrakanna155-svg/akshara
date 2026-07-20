import { useState } from 'react';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import {
  Avatar,
  Button,
  Card,
  DataTable,
  Drawer,
  Input,
  PageHeader,
  Select,
  StatusChip,
  Text,
  type Column,
  type SemanticStatus,
} from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import type { HrEmployee, HrEmployeeStatus } from '@/lib/contracts/hr';
import { formatDate, humanize } from '@/lib/utils/format';
import { HR_TABS } from './shared';

const STATUS_MAP: Record<HrEmployeeStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' },
  onLeave: { status: 'warning', label: 'On leave' },
  probation: { status: 'info', label: 'Probation' },
  inactive: { status: 'neutral', label: 'Inactive' },
};

const DEPARTMENTS = ['academics', 'administration', 'transport', 'finance', 'hr', 'support'];

const fetchEmployees = () => fetchList<HrEmployee>('/hr/employees', { query: { pageSize: 200 } });

export function EmployeesPage() {
  const query = useModuleQuery<ListResult<HrEmployee>>(['hr', 'employees'], fetchEmployees);
  const [search, setSearch] = useState('');
  const [dept, setDept] = useState('');
  const [status, setStatus] = useState('');
  const [selected, setSelected] = useState<HrEmployee | null>(null);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Staff & HR"
        subtitle="Employee directory"
        icon="badge"
        tabs={<ModuleTabs tabs={HR_TABS} />}
        actions={
          <>
            <Button variant="outlined" icon="download">
              Export
            </Button>
            <Button icon="person_add">Add employee</Button>
          </>
        }
      />

      <AsyncBoundary
        query={query}
        unavailableTitle="Employee directory is ready"
        unavailableMessage="The staff directory — searchable by name, department and status — loads here from /hr/employees once the backend is connected."
      >
        {(data) => {
          const term = search.trim().toLowerCase();
          const rows = data.items.filter((e) => {
            if (dept && e.department !== dept) return false;
            if (status && e.status !== status) return false;
            if (!term) return true;
            return (
              e.name.toLowerCase().includes(term) ||
              e.employeeCode.toLowerCase().includes(term) ||
              e.designation.toLowerCase().includes(term)
            );
          });

          const columns: Column<HrEmployee>[] = [
            {
              key: 'name',
              header: 'Employee',
              sortValue: (r) => r.name,
              render: (r) => (
                <div className="flex items-center gap-s3">
                  <Avatar name={r.name} size={36} />
                  <div className="min-w-0">
                    <div className="truncate ak-label-lg text-on-surface">{r.name}</div>
                    <div className="ak-mono text-[12px] text-on-surface-variant">{r.employeeCode}</div>
                  </div>
                </div>
              ),
            },
            { key: 'department', header: 'Department', sortValue: (r) => r.department, render: (r) => humanize(r.department) },
            { key: 'designation', header: 'Designation', sortValue: (r) => r.designation, hideOnMobile: true },
            { key: 'phone', header: 'Phone', hideOnMobile: true, render: (r) => <span className="ak-mono text-[13px]">{r.phone}</span> },
            {
              key: 'status',
              header: 'Status',
              align: 'right',
              render: (r) => <StatusChip {...STATUS_MAP[r.status]} icon={false} />,
            },
          ];

          return (
            <Card padded={false}>
              <div className="flex flex-wrap items-center gap-s2 border-b border-outline-variant/60 p-s4">
                <div className="min-w-[240px] flex-1">
                  <Input leadingIcon="search" placeholder="Search name, code, designation…" value={search} onChange={(e) => setSearch(e.target.value)} />
                </div>
                <Select className="w-44" placeholder="All departments" value={dept} onChange={(e) => setDept(e.target.value)} options={DEPARTMENTS.map((d) => ({ value: d, label: humanize(d) }))} />
                <Select className="w-40" placeholder="All statuses" value={status} onChange={(e) => setStatus(e.target.value)} options={Object.entries(STATUS_MAP).map(([v, m]) => ({ value: v, label: m.label }))} />
                <Text variant="body-sm" className="ml-auto text-on-surface-variant">
                  {rows.length} of {data.total}
                </Text>
              </div>
              <DataTable columns={columns} rows={rows} rowKey={(r) => r.id} onRowClick={setSelected} emptyTitle="No employees match your filters" emptyIcon="person_search" />
            </Card>
          );
        }}
      </AsyncBoundary>

      <Drawer
        open={!!selected}
        onClose={() => setSelected(null)}
        title={selected?.name}
        subtitle={selected ? selected.designation : undefined}
        footer={
          <>
            <Button variant="outlined" onClick={() => setSelected(null)}>
              Close
            </Button>
            <Button icon="open_in_new">Open profile</Button>
          </>
        }
      >
        {selected && (
          <div className="space-y-s5">
            <div className="flex items-center gap-s3">
              <Avatar name={selected.name} size={56} />
              <div>
                <Text variant="title-md">{selected.name}</Text>
                <Text variant="body-sm" className="ak-mono text-on-surface-variant">
                  {selected.employeeCode}
                </Text>
              </div>
              <div className="ml-auto">
                <StatusChip {...STATUS_MAP[selected.status]} />
              </div>
            </div>
            <dl className="grid grid-cols-2 gap-s4">
              {[
                ['Department', humanize(selected.department), 'apartment'],
                ['Role', humanize(selected.role), 'work'],
                ['Designation', selected.designation, 'badge'],
                ['Class teacher of', selected.classLabel ?? '—', 'class'],
                ['Phone', selected.phone, 'call'],
                ['Email', selected.email, 'mail'],
                ['Joined', formatDate(selected.joinDate), 'event_available'],
                ['Teacher app', selected.teacherAppLinked ? 'Linked' : 'Not linked', 'phone_iphone'],
              ].map(([label, value, icon]) => (
                <div key={label} className="flex items-start gap-s2">
                  <Icon name={icon} size={18} className="mt-[2px] text-on-surface-variant" />
                  <div className="min-w-0">
                    <Text variant="label-md" className="text-on-surface-variant">
                      {label}
                    </Text>
                    <Text variant="body-md" className="truncate text-on-surface">
                      {value || '—'}
                    </Text>
                  </div>
                </div>
              ))}
            </dl>
          </div>
        )}
      </Drawer>
    </div>
  );
}
