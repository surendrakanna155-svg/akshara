import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { apiFetch } from '@/lib/api/client';
import { fetchList, type ListResult } from '@/lib/api/list';
import { AsyncBoundary } from '@/components/system/AsyncBoundary';
import { ResourceList } from '@/components/system/ResourceList';
import { KpiPage } from '@/components/system/KpiPage';
import { Button, Card, PageHeader, StatusChip, Text, type Column, type SemanticStatus } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { ModuleTabs } from '@/components/shell/ModuleTabs';
import { formatDate, formatDateTime, humanize } from '@/lib/utils/format';
import { FINANCE_TABS } from './shared';

interface FeeAssignmentRow { id: string; studentName: string; classLabel: string; feeStructureName: string; installmentPlan: string; status: string }
interface OfflinePaymentRow { id: string; studentName: string; amount: string; method: string; reference: string; receivedAt: string; status: string }
interface QrSession { id: string; studentName: string; amount: string; createdAt: string; status: string }

const OFFLINE_STATUS: Record<string, SemanticStatus> = { pendingReconciliation: 'warning', reconciled: 'success', bounced: 'error' };

export function FeeAssignmentPage() {
  const query = useModuleQuery<ListResult<FeeAssignmentRow>>(['finance', 'fee-assignments'], () => fetchList('/finance/fee-assignments', { query: { pageSize: 300 } }));
  const columns: Column<FeeAssignmentRow>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => (
      <div className="min-w-0"><div className="truncate ak-label-lg text-on-surface">{r.studentName}</div><div className="text-[12px] text-on-surface-variant">{r.classLabel}</div></div>
    ) },
    { key: 'feeStructureName', header: 'Fee plan', sortValue: (r) => r.feeStructureName },
    { key: 'installmentPlan', header: 'Installments', hideOnMobile: true },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'active' ? 'success' : 'warning'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Fee assignment" subtitle="Assign fee structures to students" icon="assignment_turned_in" tabs={FINANCE_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Assign fee</Button>} search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
    unavailableTitle="Fee assignment is ready" unavailableMessage="Fee assignments load from /finance/fee-assignments once connected." />;
}

export function OfflinePaymentsPage() {
  const query = useModuleQuery<ListResult<OfflinePaymentRow>>(['finance', 'offline'], () => fetchList('/finance/payments/offline', { query: { pageSize: 300 } }));
  const columns: Column<OfflinePaymentRow>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => <span className="ak-label-lg text-on-surface">{r.studentName}</span> },
    { key: 'method', header: 'Method', render: (r) => humanize(r.method) },
    { key: 'reference', header: 'Reference', hideOnMobile: true, render: (r) => <span className="ak-mono text-[12px]">{r.reference}</span> },
    { key: 'receivedAt', header: 'Received', hideOnMobile: true, render: (r) => formatDate(r.receivedAt) },
    { key: 'amount', header: 'Amount', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.amount}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={OFFLINE_STATUS[r.status] ?? 'neutral'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="Offline payments" subtitle="Cash, cheque & DD — reconciliation" icon="receipt" tabs={FINANCE_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="add">Record payment</Button>} search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
    unavailableTitle="Offline payments are ready" unavailableMessage="Offline payments load from /finance/payments/offline once connected." />;
}

export function QrPaymentPage() {
  const query = useModuleQuery<ListResult<QrSession>>(['finance', 'qr'], () => fetchList('/finance/payments/qr', { query: { pageSize: 200 } }));
  const columns: Column<QrSession>[] = [
    { key: 'studentName', header: 'Student', sortValue: (r) => r.studentName, render: (r) => <span className="ak-label-lg text-on-surface">{r.studentName}</span> },
    { key: 'createdAt', header: 'Created', hideOnMobile: true, render: (r) => formatDateTime(r.createdAt) },
    { key: 'amount', header: 'Amount', align: 'right', render: (r) => <span className="ak-tabular font-semibold text-on-surface">{r.amount}</span> },
    { key: 'status', header: 'Status', align: 'right', render: (r) => <StatusChip status={r.status === 'confirmed' ? 'success' : r.status === 'expired' ? 'error' : 'warning'} label={humanize(r.status)} icon={false} /> },
  ];
  return <ResourceList title="QR payments" subtitle="UPI / QR collection sessions" icon="qr_code_2" tabs={FINANCE_TABS} query={query} columns={columns} rowKey={(r) => r.id}
    actions={<Button icon="qr_code">New QR</Button>} search={{ placeholder: 'Search student…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
    unavailableTitle="QR payments are ready" unavailableMessage="QR payment sessions load from /finance/payments/qr once connected." />;
}

export const ReconciliationPage = () => (
  <KpiPage title="Reconciliation" subtitle="Daily collection & day-close" icon="fact_check" tabs={FINANCE_TABS} endpoint="/finance/collections/daily-summary" queryKey={['finance', 'reconciliation']}
    icons={['payments', 'account_balance', 'fact_check', 'lock']} unavailableMessage="Daily reconciliation loads from /finance/collections/daily-summary once connected." />
);
export const FinanceExecutivePage = () => (
  <KpiPage title="Finance executive" subtitle="Executive finance overview" icon="account_balance" tabs={FINANCE_TABS} endpoint="/finance/intelligence/executive" queryKey={['finance', 'executive']}
    icons={['payments', 'trending_up', 'account_balance_wallet', 'savings']} unavailableMessage="Executive finance metrics load from /finance/intelligence/executive once connected." />
);

export function FinanceCopilotPage() {
  const query = useModuleQuery(['finance', 'copilot'], () => apiFetch<{ items: { id: string; title: string; detail: string }[] }>('/finance/intelligence/copilot'));
  return (
    <div className="space-y-s6">
      <PageHeader title="Finance copilot" subtitle="AI recommendations for collections" icon="auto_awesome" tabs={<ModuleTabs tabs={FINANCE_TABS} />} />
      <AsyncBoundary query={query} unavailableTitle="Finance copilot is ready" unavailableMessage="AI recommendations load from /finance/intelligence/copilot once connected." isEmpty={(d) => !d.items?.length}>
        {(d) => (
          <div className="grid grid-cols-1 gap-s4 md:grid-cols-2">
            {d.items.map((it) => (
              <Card key={it.id}><div className="flex items-start gap-s3"><span className="grid h-9 w-9 shrink-0 place-items-center rounded-lg bg-primary-container text-on-primary-container"><Icon name="lightbulb" size={18} /></span><div><Text variant="title-sm" className="text-on-surface">{it.title}</Text><Text variant="body-sm" className="mt-s1 text-on-surface-variant">{it.detail}</Text></div></div></Card>
            ))}
          </div>
        )}
      </AsyncBoundary>
    </div>
  );
}
