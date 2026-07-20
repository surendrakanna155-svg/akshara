import { useModuleQuery } from '@/lib/api/useModuleQuery';
import { fetchList, type ListResult } from '@/lib/api/list';
import { ResourceList } from '@/components/system/ResourceList';
import { StatusChip, type Column } from '@/components/ui';
import type { AdmissionsDocumentRow } from '@/lib/contracts/admissions';
import { humanize } from '@/lib/utils/format';
import { ADMISSIONS_TABS, DOC_STATUS } from './shared';

const fetchDocuments = () => fetchList<AdmissionsDocumentRow>('/admissions/documents', { query: { pageSize: 200 } });

export function DocumentsPage() {
  const query = useModuleQuery<ListResult<AdmissionsDocumentRow>>(['admissions', 'documents'], fetchDocuments);

  const columns: Column<AdmissionsDocumentRow>[] = [
    { key: 'studentName', header: 'Applicant', sortValue: (r) => r.studentName },
    { key: 'classLabel', header: 'Class', sortValue: (r) => r.classLabel },
    { key: 'docType', header: 'Document', sortValue: (r) => r.docType, render: (r) => humanize(r.docType) },
    { key: 'status', header: 'Verification', align: 'right', render: (r) => <StatusChip {...DOC_STATUS[r.status]} /> },
  ];

  return (
    <ResourceList
      title="Documents"
      subtitle="Applicant document verification"
      icon="folder_open"
      tabs={ADMISSIONS_TABS}
      query={query}
      columns={columns}
      rowKey={(r) => r.id}
      search={{ placeholder: 'Search applicant…', match: (r, t) => r.studentName.toLowerCase().includes(t) }}
      filters={[
        {
          key: 'status',
          placeholder: 'All statuses',
          options: Object.entries(DOC_STATUS).map(([v, m]) => ({ value: v, label: m.label })),
          match: (r, v) => r.status === v,
        },
      ]}
      unavailableTitle="Document tracking is ready"
      unavailableMessage="Applicant documents and their verification status load here from /admissions/documents once the backend is connected."
      emptyTitle="No documents match your filters"
      emptyIcon="folder_off"
    />
  );
}
