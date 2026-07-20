import { ReportsHub } from '@/components/system/ReportsHub';
import { ADMISSIONS_TABS } from './shared';

export function AdmissionsReportsPage() {
  return (
    <ReportsHub
      title="Admissions reports"
      subtitle="Generate and export admission insights"
      icon="summarize"
      tabs={ADMISSIONS_TABS}
      reports={[
        { key: 'pipeline', title: 'Lead pipeline', description: 'Enquiries by stage, source and counselor over a period.', icon: 'filter_alt', endpoint: '/admissions/reports' },
        { key: 'conversion', title: 'Conversion funnel', description: 'Enquiry → application → admitted → enrolled conversion rates.', icon: 'trending_up', endpoint: '/admissions/reports' },
        { key: 'source', title: 'Source effectiveness', description: 'Which campaigns and sources drive the most admissions.', icon: 'campaign', endpoint: '/admissions/reports' },
        { key: 'counselor', title: 'Counselor performance', description: 'Leads handled, follow-ups and conversions per counselor.', icon: 'support_agent', endpoint: '/admissions/reports' },
        { key: 'documents', title: 'Document compliance', description: 'Applicants with missing or unverified documents.', icon: 'folder_open', endpoint: '/admissions/reports' },
        { key: 'enrolment', title: 'Enrolment summary', description: 'New enrolments by class and section for the year.', icon: 'assignment_turned_in', endpoint: '/admissions/reports' },
      ]}
    />
  );
}
