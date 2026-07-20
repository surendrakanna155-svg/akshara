import { KpiPage } from '@/components/system/KpiPage';
import { MODULE_TABS } from '@/routes/navConfig';

const TABS = MODULE_TABS.director;

/** Director (multi-branch owner) executive dashboards — all KPI-driven, live-wired. */
export const DirectorDashboardPage = () => (
  <KpiPage title="Director" subtitle="Group performance overview" icon="corporate_fare" tabs={TABS} endpoint="/director/dashboard" queryKey={['director', 'dashboard']} icons={['apartment', 'account_balance', 'groups', 'trending_up']} />
);
export const DirectorSchoolsPage = () => (
  <KpiPage title="Schools" subtitle="Per-school snapshot" icon="apartment" tabs={TABS} endpoint="/director/schools" queryKey={['director', 'schools']} />
);
export const DirectorPortfolioPage = () => (
  <KpiPage title="Portfolio" subtitle="Group portfolio metrics" icon="dashboard" tabs={TABS} endpoint="/director/portfolio" queryKey={['director', 'portfolio']} />
);
export const DirectorRevenuePage = () => (
  <KpiPage title="Revenue" subtitle="Revenue & collections across schools" icon="payments" tabs={TABS} endpoint="/director/revenue" queryKey={['director', 'revenue']} icons={['payments', 'account_balance_wallet', 'savings', 'trending_up']} />
);
export const DirectorAdmissionsPage = () => (
  <KpiPage title="Admissions" subtitle="Group admissions performance" icon="how_to_reg" tabs={TABS} endpoint="/director/admissions" queryKey={['director', 'admissions']} />
);
export const DirectorGrowthPage = () => (
  <KpiPage title="Growth" subtitle="Enrolment & expansion" icon="trending_up" tabs={TABS} endpoint="/director/growth" queryKey={['director', 'growth']} />
);
export const DirectorMarketingPage = () => (
  <KpiPage title="Marketing" subtitle="Campaign & lead performance" icon="campaign" tabs={TABS} endpoint="/director/marketing" queryKey={['director', 'marketing']} />
);
export const DirectorCompliancePage = () => (
  <KpiPage title="Compliance" subtitle="Regulatory & audit status" icon="verified_user" tabs={TABS} endpoint="/director/compliance" queryKey={['director', 'compliance']} icons={['verified_user', 'gavel', 'fact_check', 'warning']} />
);
export const DirectorReportsPage = () => (
  <KpiPage title="Director reports" subtitle="Group-level reports" icon="summarize" tabs={TABS} endpoint="/director/reports" queryKey={['director', 'reports']} />
);
