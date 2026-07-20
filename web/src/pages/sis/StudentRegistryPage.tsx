import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
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
import { normalizeSisStudent } from '@/lib/contracts/sis';
import type { SisRegistryResponse, SisStudent, SisStudentStatus } from '@/lib/contracts/sis';
import { formatDate } from '@/lib/utils/format';
import { SIS_TABS } from './SisPages';

const STATUS_MAP: Record<SisStudentStatus, { status: SemanticStatus; label: string }> = {
  active: { status: 'success', label: 'Active' },
  prospect: { status: 'info', label: 'Prospect' },
  transferred: { status: 'warning', label: 'Transferred' },
  exited: { status: 'neutral', label: 'Exited' },
  alumni: { status: 'pending', label: 'Alumni' },
};

// Live, verified endpoint: GET /sis/students → listEnvelope(items, {total,…}).
// Normalizes to { items, total } regardless of a bare-array or {students} shape.
async function fetchRegistry(): Promise<SisRegistryResponse> {
  const raw = await apiFetch<SisRegistryResponse | SisStudent[] | { students: SisStudent[]; total?: number }>(
    '/sis/students',
    { query: { pageSize: 200 } },
  );
  const list: SisStudent[] = Array.isArray(raw)
    ? raw
    : 'items' in raw
      ? raw.items
      : raw.students;
  const total = Array.isArray(raw) ? raw.length : 'items' in raw ? (raw.total ?? raw.items.length) : (raw.total ?? raw.students.length);
  return { items: (list ?? []).map(normalizeSisStudent), total };
}

export function StudentRegistryPage() {
  const navigate = useNavigate();
  const query = useModuleQuery(['sis', 'registry'], fetchRegistry);
  const [search, setSearch] = useState('');
  const [classFilter, setClassFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [selected, setSelected] = useState<SisStudent | null>(null);

  return (
    <div className="space-y-s6">
      <PageHeader
        title="Students"
        subtitle="Student information system — registry"
        icon="groups"
        tabs={<ModuleTabs tabs={SIS_TABS} />}
        actions={
          <>
            <Button variant="outlined" icon="upload_file">
              Import
            </Button>
            <Button icon="person_add">Add student</Button>
          </>
        }
      />

      <AsyncBoundary
        query={query}
        unavailableTitle="Student registry is ready"
        unavailableMessage="The full registry — searchable and filterable by class, section and status — will load here once the SIS endpoint is connected."
      >
        {(data) => {
          const students = data.items ?? [];
          const classes = Array.from(new Set(students.map((s) => s.classLabel))).sort();
          const term = search.trim().toLowerCase();
          const rows = students.filter((s) => {
            if (classFilter && s.classLabel !== classFilter) return false;
            if (statusFilter && s.status !== statusFilter) return false;
            if (!term) return true;
            return (
              s.studentName.toLowerCase().includes(term) ||
              s.admissionNumber.toLowerCase().includes(term) ||
              (s.publicStudentId ?? '').toLowerCase().includes(term) ||
              s.guardianName.toLowerCase().includes(term)
            );
          });

          const columns: Column<SisStudent>[] = [
            {
              key: 'studentName',
              header: 'Student',
              sortValue: (r) => r.studentName,
              render: (r) => (
                <div className="flex items-center gap-s3">
                  <Avatar name={r.studentName} size={36} />
                  <div className="min-w-0">
                    <div className="truncate ak-label-lg text-on-surface">{r.studentName}</div>
                    <div className="ak-mono text-[12px] text-on-surface-variant">{r.publicStudentId || r.admissionNumber}</div>
                  </div>
                </div>
              ),
            },
            { key: 'classLabel', header: 'Class', sortValue: (r) => r.classLabel, render: (r) => `${r.classLabel} · ${r.section}` },
            { key: 'guardianName', header: 'Guardian', sortValue: (r) => r.guardianName, hideOnMobile: true },
            { key: 'phone', header: 'Phone', hideOnMobile: true, render: (r) => <span className="ak-mono text-[13px]">{r.phone}</span> },
            {
              key: 'enrolledAt',
              header: 'Enrolled',
              align: 'right',
              hideOnMobile: true,
              sortValue: (r) => r.enrolledAt,
              render: (r) => formatDate(r.enrolledAt),
            },
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
                  <Input
                    leadingIcon="search"
                    placeholder="Search name, admission no., guardian…"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                  />
                </div>
                <Select
                  className="w-40"
                  placeholder="All classes"
                  value={classFilter}
                  onChange={(e) => setClassFilter(e.target.value)}
                  options={classes.map((c) => ({ value: c, label: c }))}
                />
                <Select
                  className="w-40"
                  placeholder="All statuses"
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                  options={Object.entries(STATUS_MAP).map(([v, m]) => ({ value: v, label: m.label }))}
                />
                <Text variant="body-sm" className="ml-auto text-on-surface-variant">
                  {rows.length} of {data.total ?? students.length}
                </Text>
              </div>
              <DataTable
                columns={columns}
                rows={rows}
                rowKey={(r) => r.id}
                onRowClick={setSelected}
                emptyTitle="No students match your filters"
                emptyIcon="person_search"
              />
            </Card>
          );
        }}
      </AsyncBoundary>

      <Drawer
        open={!!selected}
        onClose={() => setSelected(null)}
        title={selected?.studentName}
        subtitle={selected ? `${selected.classLabel} · Section ${selected.section}` : undefined}
        footer={
          <>
            <Button variant="outlined" onClick={() => setSelected(null)}>
              Close
            </Button>
            <Button icon="open_in_new" onClick={() => selected && navigate(`/sis/students/${selected.id}`)}>Open profile</Button>
          </>
        }
      >
        {selected && (
          <div className="space-y-s5">
            <div className="flex items-center gap-s3">
              <Avatar name={selected.studentName} size={56} />
              <div>
                <Text variant="title-md">{selected.studentName}</Text>
                <Text variant="body-sm" className="ak-mono text-on-surface-variant">
                  {selected.publicStudentId || selected.admissionNumber}
                </Text>
              </div>
              <div className="ml-auto">
                <StatusChip {...STATUS_MAP[selected.status]} />
              </div>
            </div>
            <dl className="grid grid-cols-2 gap-s4">
              {[
                ['Admission No.', selected.admissionNumber, 'badge'],
                ['Academic Year', selected.academicYear, 'calendar_today'],
                ['Gender', selected.gender, 'wc'],
                ['Date of Birth', formatDate(selected.dateOfBirth), 'cake'],
                ['Guardian', selected.guardianName, 'family_restroom'],
                ['Phone', selected.phone, 'call'],
                ['Email', selected.email, 'mail'],
                ['Enrolled', formatDate(selected.enrolledAt), 'event_available'],
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
