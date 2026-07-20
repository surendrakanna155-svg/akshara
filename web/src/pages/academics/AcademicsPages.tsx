import { useMemo, useState } from 'react';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { ResourceList } from '@/components/system/ResourceList';
import { ReportsHub } from '@/components/system/ReportsHub';
import { Button, Card, DataTable, Input, PageHeader, Select, StatusChip, Text, type Column, type SemanticStatus } from '@/components/ui';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { formatDate, humanize } from '@/lib/utils/format';
import { MODULE_TABS } from '@/routes/navConfig';
import type { ExamListItem, ExamMarkRow, ExamPhase, ExamProgressItem, TimetableListItem, TimetableSubstitution } from '@/lib/contracts/academics';

const TABS = MODULE_TABS.academics;

const PHASE: Record<ExamPhase, { status: SemanticStatus; label: string }> = {
  none: { status: 'neutral', label: 'Not started' },
  scheduled: { status: 'info', label: 'Scheduled' },
  marksInProgress: { status: 'pending', label: 'Marks in progress' },
  awaitingVerification: { status: 'warning', label: 'Awaiting verification' },
  awaitingApproval: { status: 'warning', label: 'Awaiting approval' },
  returned: { status: 'error', label: 'Returned' },
  published: { status: 'success', label: 'Published' },
};
const phaseChip = (p: ExamPhase) => <StatusChip {...(PHASE[p] ?? PHASE.none)} icon={false} />;

export function ExamAdministrationPage() {
  const query = useModuleQuery<ListResult<ExamListItem>>(['exams', 'list'], () => fetchList('/academics/exams', { query: { pageSize: 300 } }));
  const columns: Column<ExamListItem>[] = [
    { key: 'title', header: 'Exam', sortValue: (r) => r.title, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.title}</div><div className="text-[12px] text-on-surface-variant">{humanize(r.examType)} · {r.termLabel}</div></div>
    ) },
    { key: 'class', header: 'Class', render: (r) => `${r.grade} · ${r.section}` },
    { key: 'subject', header: 'Subject', hideOnMobile: true },
    { key: 'dateLabel', header: 'Date', hideOnMobile: true },
    { key: 'maxMarks', header: 'Max', align: 'right', hideOnMobile: true },
    { key: 'phase', header: 'Status', align: 'right', render: (r) => phaseChip(r.phase) },
  ];
  return <ResourceList title="Examinations" subtitle="Exam schedule & lifecycle" icon="grading" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Create exam</Button>}
    search={{ placeholder: 'Search exam or subject…', match: (r, t) => r.title.toLowerCase().includes(t) || r.subject.toLowerCase().includes(t) }}
    filters={[{ key: 'phase', placeholder: 'All statuses', width: 'w-48', options: Object.entries(PHASE).map(([v, m]) => ({ value: v, label: m.label })), match: (r, v) => r.phase === v }]}
    unavailableTitle="Examinations are ready" unavailableMessage="Exams load here from /academics/exams once the backend is connected." />;
}

export function ExamMarksProgressPage() {
  const query = useModuleQuery<ListResult<ExamProgressItem>>(['exams', 'progress'], () => fetchList('/academics/exams/progress', { query: { pageSize: 300 } }));
  const columns: Column<ExamProgressItem>[] = [
    { key: 'title', header: 'Exam', sortValue: (r) => r.title, render: (r) => <span className="ak-label-lg text-on-surface">{r.title}</span> },
    { key: 'class', header: 'Class', render: (r) => `${r.grade} · ${r.section}` },
    { key: 'subject', header: 'Subject', hideOnMobile: true },
    { key: 'progress', header: 'Entered', align: 'right', render: (r) => {
      const pct = r.total ? Math.round((r.entered / r.total) * 100) : 0;
      return (
        <div className="flex items-center justify-end gap-s2">
          <div className="h-1.5 w-24 overflow-hidden rounded-full bg-surface-highest"><div className="h-full rounded-full bg-primary" style={{ width: `${pct}%` }} /></div>
          <span className="ak-tabular text-on-surface-variant">{r.entered}/{r.total}</span>
        </div>
      );
    } },
    { key: 'phase', header: 'Status', align: 'right', render: (r) => phaseChip(r.phase) },
  ];
  return <ResourceList title="Marks progress" subtitle="Marks entry status by exam" icon="checklist" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id}
    search={{ placeholder: 'Search exam…', match: (r, t) => r.title.toLowerCase().includes(t) }}
    unavailableTitle="Marks progress is ready" unavailableMessage="Marks-entry progress loads here from /academics/exams/progress once the backend is connected." />;
}

export function ExamMarksEntryPage() {
  const examsQuery = useModuleQuery<ListResult<ExamListItem>>(['exams', 'list'], () => fetchList('/academics/exams', { query: { pageSize: 300 } }));
  const [examId, setExamId] = useState('');
  const marksQuery = useModuleQuery<ListResult<ExamMarkRow>>(['exams', 'marks', examId], () => fetchList(`/academics/exams/${examId}/marks`, { query: { pageSize: 400 } }), { enabled: !!examId });
  const [edits, setEdits] = useState<Record<string, string>>({});
  const exams = examsQuery.data?.items ?? [];
  const dirty = Object.keys(edits).length > 0;

  const columns: Column<ExamMarkRow>[] = useMemo(() => [
    { key: 'rollNo', header: 'Roll', width: '80px', render: (r) => <span className="ak-mono">{r.rollNo}</span> },
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => <span className="ak-label-lg text-on-surface">{r.studentName}</span> },
    { key: 'marks', header: 'Marks', align: 'right', width: '160px', render: (r) => (
      <Input className="h-9 w-28 text-right" type="number" placeholder="—" max={r.maxMarks}
        value={edits[r.id] ?? (r.marksObtained ?? '')}
        onChange={(e) => setEdits((s) => ({ ...s, [r.id]: e.target.value }))} />
    ) },
    { key: 'max', header: 'Max', align: 'right', width: '80px', render: (r) => r.maxMarks },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.published ? 'success' : 'info'} label={humanize(r.status)} icon={false} /> },
  ], [edits]);

  return (
    <div className="space-y-s6">
      <PageHeader title="Marks entry" subtitle="Enter and verify exam marks" icon="edit_note" tabs={<ModuleTabs tabs={TABS} />}
        actions={<Button icon="save" disabled={!examId || !dirty} onClick={() => setEdits({})}>Save marks</Button>} />
      <Card>
        <div className="max-w-md">
          <AsyncBoundary query={examsQuery} unavailableTitle="Marks entry is ready" unavailableMessage="Pick an exam to enter marks once /academics/exams is connected.">
            {() => (
              <Select label="Select exam" placeholder="Choose an exam…" value={examId} onChange={(e) => { setExamId(e.target.value); setEdits({}); }}
                options={exams.map((ex) => ({ value: ex.id, label: `${ex.title} — ${ex.grade}/${ex.section} (${ex.subject})` }))} />
            )}
          </AsyncBoundary>
        </div>
      </Card>
      {examId && (
        <AsyncBoundary query={marksQuery} unavailableTitle="Marks sheet is ready" unavailableMessage="The student marks sheet loads from /academics/exams/{id}/marks once connected.">
          {(d) => <DataTable columns={columns} rows={d.items} rowKey={(r) => r.id} dense emptyTitle="No students for this exam" emptyIcon="group_off" />}
        </AsyncBoundary>
      )}
      {!examId && examsQuery.data && (
        <Text variant="body-md" className="text-center text-on-surface-variant">Select an exam above to begin marks entry.</Text>
      )}
    </div>
  );
}

export function ExamReportsPage() {
  return <ReportsHub title="Exam reports" subtitle="Results, toppers and analysis" icon="summarize" tabs={TABS}
    reports={[
      { key: 'results', title: 'Result sheets', description: 'Class and section result sheets.', icon: 'grading' },
      { key: 'reportcards', title: 'Report cards', description: 'Per-student report cards for a term.', icon: 'assignment' },
      { key: 'toppers', title: 'Toppers', description: 'Rank lists and toppers per exam.', icon: 'emoji_events' },
      { key: 'distribution', title: 'Grade distribution', description: 'Marks and grade distribution analysis.', icon: 'bar_chart' },
      { key: 'hall', title: 'Hall tickets & seating', description: 'Hall tickets and exam seating plans.', icon: 'event_seat' },
    ]} />;
}

export function TimetableHubPage() {
  const query = useModuleQuery<ListResult<TimetableListItem>>(['timetable', 'list'], () => fetchList('/academic/timetables', { query: { pageSize: 200 } }));
  const columns: Column<TimetableListItem>[] = [
    { key: 'sectionLabel', header: 'Section', sortValue: (r) => r.sectionLabel, render: (r) => <span className="ak-label-lg text-on-surface">{r.sectionLabel}</span> },
    { key: 'periodCount', header: 'Periods', align: 'right', sortValue: (r) => r.periodCount },
    { key: 'conflictCount', header: 'Conflicts', align: 'right', render: (r) => <span className={r.conflictCount > 0 ? 'font-semibold text-error' : 'text-on-surface-variant'}>{r.conflictCount}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'published' ? 'success' : r.status === 'validated' ? 'info' : r.status === 'archived' ? 'neutral' : 'warning'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Timetable" subtitle="Section timetables" icon="calendar_view_week" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="auto_awesome">Generate</Button>}
    search={{ placeholder: 'Search section…', match: (r, t) => r.sectionLabel.toLowerCase().includes(t) }}
    unavailableTitle="Timetable is ready" unavailableMessage="Section timetables load here from /academic/timetables once the backend is connected." />;
}

export function DailySubstitutionsPage() {
  const today = new Date().toISOString().slice(0, 10);
  const query = useModuleQuery<ListResult<TimetableSubstitution>>(['timetable', 'substitutions', today], () => fetchList('/academic/timetables/substitutions', { query: { pageSize: 300, date: today } }));
  const columns: Column<TimetableSubstitution>[] = [
    { key: 'subDate', header: 'Date', sortValue: (r) => r.subDate, render: (r) => formatDate(r.subDate) },
    { key: 'sectionLabel', header: 'Section', render: (r) => r.sectionLabel || '—' },
    { key: 'period', header: 'Period', hideOnMobile: true, render: (r) => (r.periodNumber ? `P${r.periodNumber} · ${r.subjectLabel ?? ''}` : '—') },
    { key: 'originalTeacherName', header: 'Original', hideOnMobile: true, render: (r) => r.originalTeacherName || '—' },
    { key: 'substituteTeacherName', header: 'Substitute', render: (r) => r.substituteTeacherName || 'Unassigned' },
    { key: 'reason', header: 'Reason', hideOnMobile: true },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status="info" label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Daily substitutions" subtitle="Cover for teachers on leave" icon="published_with_changes" tabs={TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Assign substitute</Button>}
    search={{ placeholder: 'Search teacher or section…', match: (r, t) => (r.originalTeacherName ?? '').toLowerCase().includes(t) || (r.sectionLabel ?? '').toLowerCase().includes(t) }}
    unavailableTitle="Substitutions are ready" unavailableMessage="Daily substitutions load here from /academic/timetables/substitutions once the backend is connected."
    emptyTitle="No substitutions today" emptyIcon="event_available" />;
}
