import { createBrowserRouter, Navigate, useLocation } from 'react-router-dom';
import type { ReactElement } from 'react';
import { AppShell } from '@/components/shell/AppShell';
import { LoginPage } from '@/pages/auth/LoginPage';
import { OtpVerificationPage } from '@/pages/auth/OtpVerificationPage';
import { DashboardPage } from '@/pages/admin/DashboardPage';
import { StudentRegistryPage } from '@/pages/sis/StudentRegistryPage';
import {
  SisDashboardPage,
  TransfersPage,
  AdmissionsConversionPage,
  PromotionPage,
  ReshufflePage,
  SectionBalancePage,
  AcademicAssignmentPage,
} from '@/pages/sis/SisPages';
import { EmployeesPage } from '@/pages/hr/EmployeesPage';
import { HrDashboardPage } from '@/pages/hr/HrDashboardPage';
import { HrAttendancePage } from '@/pages/hr/AttendancePage';
import { HrLeavePage } from '@/pages/hr/LeavePage';
import { HrPayrollPage } from '@/pages/hr/PayrollPage';
import { HrRecruitmentPage } from '@/pages/hr/RecruitmentPage';
import { HrPerformancePage } from '@/pages/hr/PerformancePage';
import { HrReportsPage } from '@/pages/hr/HrReportsPage';
import { HrSettingsPage } from '@/pages/hr/HrSettingsPage';
import { LeadsPage } from '@/pages/admissions/LeadsPage';
import { AdmissionsDashboardPage } from '@/pages/admissions/AdmissionsDashboardPage';
import { ApplicationsPage } from '@/pages/admissions/ApplicationsPage';
import { ApprovalPage } from '@/pages/admissions/ApprovalPage';
import { DocumentsPage } from '@/pages/admissions/DocumentsPage';
import { EnrollmentPage } from '@/pages/admissions/EnrollmentPage';
import { AdmissionsReportsPage } from '@/pages/admissions/ReportsPage';
import { AdmissionsSettingsPage } from '@/pages/admissions/SettingsPage';
import { FinanceDashboardPage } from '@/pages/finance/FinanceDashboardPage';
import { CollectionsPage } from '@/pages/finance/CollectionsPage';
import { StudentAccountsPage } from '@/pages/finance/StudentAccountsPage';
import { FeeStructuresPage } from '@/pages/finance/FeeStructuresPage';
import { DefaultersPage } from '@/pages/finance/DefaultersPage';
import { RefundsPage } from '@/pages/finance/RefundsPage';
import { DiscountsPage } from '@/pages/finance/DiscountsPage';
import { FinanceReportsPage } from '@/pages/finance/FinanceReportsPage';
import { FinanceSettingsPage } from '@/pages/finance/FinanceSettingsPage';
import {
  FeeAssignmentPage,
  OfflinePaymentsPage,
  QrPaymentPage,
  ReconciliationPage,
  FinanceExecutivePage,
  FinanceCopilotPage,
} from '@/pages/finance/FinanceExtraPages';
import { TransportDashboardPage } from '@/pages/transport/TransportDashboardPage';
import { RoutesPage } from '@/pages/transport/RoutesPage';
import { VehiclesPage } from '@/pages/transport/VehiclesPage';
import { DriversPage } from '@/pages/transport/DriversPage';
import { AllocationsPage } from '@/pages/transport/AllocationsPage';
import { TransportAttendancePage } from '@/pages/transport/TransportAttendancePage';
import { TrackingPage } from '@/pages/transport/TrackingPage';
import { TransportReportsPage } from '@/pages/transport/TransportReportsPage';
import { TransportSettingsPage } from '@/pages/transport/TransportSettingsPage';
import { LibraryDashboardPage } from '@/pages/library/LibraryDashboardPage';
import { CatalogPage } from '@/pages/library/CatalogPage';
import { IssuesPage, OverduePage } from '@/pages/library/IssuesPage';
import { ReturnsPage } from '@/pages/library/ReturnsPage';
import { MembersPage } from '@/pages/library/MembersPage';
import { FinesPage } from '@/pages/library/FinesPage';
import { ResourcesPage } from '@/pages/library/ResourcesPage';
import { LibraryReportsPage } from '@/pages/library/LibraryReportsPage';
import {
  HostelDashboardPage,
  HostelStudentsPage,
  RoomsPage,
  HostelAttendancePage,
  HostelLeavePage,
  VisitorsPage,
  MessPage,
  HostelReportsPage,
} from '@/pages/hostel/HostelPages';
import {
  InventoryDashboardPage,
  AssetsPage,
  CategoriesPage,
  InvAllocationsPage,
  DistributionPage,
  MaintenancePage,
  ProcurementPage,
  VendorsPage,
  StockPage,
  StockApprovalsPage,
  LifecyclePage,
  ReplacementPage,
  InventoryCopilotPage,
  InventoryReportsPage,
} from '@/pages/inventory/InventoryPages';
import {
  AlumniDashboardPage,
  RegistryPage,
  CampaignsPage,
  DonationsPage,
  EventsPage,
  MentorshipPage,
  AlumniReportsPage,
  AlumniSettingsPage,
} from '@/pages/alumni/AlumniPages';
import {
  DirectorDashboardPage,
  DirectorSchoolsPage,
  DirectorPortfolioPage,
  DirectorRevenuePage,
  DirectorAdmissionsPage,
  DirectorGrowthPage,
  DirectorMarketingPage,
  DirectorCompliancePage,
  DirectorReportsPage,
} from '@/pages/director/DirectorPages';
import {
  IntelligenceHubPage,
  StudentSuccessPage,
  TeacherEffectivenessPage,
  ExamIntelligencePage,
  HomeworkIntelligencePage,
  TrustIntelligencePage,
  AiEconomicsPage,
} from '@/pages/intelligence/IntelligencePages';
import {
  ManagementDashboardPage,
  ManagementAnalyticsPage,
  ManagementAdmissionsPage,
  ManagementFinancePage,
  ManagementAcademicsPage,
  ManagementPerformancePage,
  ApprovalCenterPage,
  ManagementTasksPage,
  ManagementSettingsPage,
} from '@/pages/management/ManagementPages';
import { AttendanceOverviewPage, AttendanceRegisterPage, AttendanceCorrectionsPage } from '@/pages/attendance/AttendancePages';
import { SettingsPage } from '@/pages/settings/SettingsPage';
import {
  ParentDashboardPage,
  ParentExperienceHubPage,
  ParentAcademicReportPage,
  ParentAttendancePage,
  ParentTimetablePage,
  ParentHomeworkPage,
  ParentExamsPage,
  ParentReportCardPage,
  ParentFeesPage,
  ParentPaymentPage,
  ParentReceiptsPage,
  ParentNoticesPage,
  ParentEventsPage,
  ParentMessagesPage,
  ParentLeavePage,
  ParentPtmPage,
  ParentTransportPage,
  ParentActionInboxPage,
  ParentFamilyViewPage,
  ParentProfilePage,
} from '@/pages/parent/ParentPages';
import {
  TeacherTodayPage,
  TeacherDashboardPage,
  ClassTeacherDashboardPage,
  TeacherAttendancePage,
  MyAttendancePage,
  TeacherTimetablePage,
  TeacherHomeworkPage,
  TeacherHomeworkHistoryPage,
  TeacherHomeworkCreatePage,
  TeacherExamsPage,
  TeacherMessagesPage,
  TeacherParentCommunicationPage,
  TeacherStudentRiskPage,
  TeacherLeavePage,
  TeacherLeaveApprovalsPage,
  TeacherProfilePage,
  TeacherSettingsPage,
} from '@/pages/teacher/TeacherPages';
import {
  StudentDashboardPage,
  StudentProgressPage,
  StudentAttendancePage,
  StudentHomeworkPage,
  StudentExamsPage,
  StudentTimetablePage,
  StudentNoticesPage,
  StudentReportCardPage,
  StudentProfilePage,
} from '@/pages/student/StudentPages';
import { CommunicationPage, NotificationsPage, ReportsHubPage, OnboardingPage, SchoolConfigPage } from '@/pages/engage/EngagePages';
import {
  SchoolCompletionHubPage,
  SubjectsPage,
  SubjectAssignmentPage,
  ClassTeacherAssignmentPage,
  TeacherReassignmentPage,
  RoomAllocationPage,
  LessonLogsPage,
  SubstituteManagerPage,
  TimetableAutomationPage,
  TimetableOptimizationPage,
  TimetableIntelligencePage,
  SyllabusAutomationPage,
  LessonAnalyticsPage,
  AcademicProgressPage,
  CommunicationAnalyticsPage,
  CommunicationDeliveryPage,
  ParentActivationPage,
  PilotDashboardPage,
  BrandingPage,
  WhatsAppProviderPage,
} from '@/pages/schoolops/SchoolOpsPages';
import {
  ExamAdministrationPage,
  ExamMarksProgressPage,
  ExamMarksEntryPage,
  ExamReportsPage,
  TimetableHubPage,
  DailySubstitutionsPage,
} from '@/pages/academics/AcademicsPages';
import * as Misc from '@/pages/misc/MiscPages';
import {
  SisStudentDetailPage,
  CollectionDetailPage,
  LeadDetailPage,
  ReceiptDetailPage,
  TeacherConversationPage,
  ParentConversationPage,
} from '@/pages/detail/DetailPages';
import {
  SupportConsoleGate,
  SupportQueuePage,
  SupportIncidentPage,
  SupportClustersPage,
  SupportClusterDetailPage,
  SupportKbPage,
} from '@/pages/support-console';
import { ModuleScaffold } from '@/components/system/ModuleScaffold';
import { useAuth } from '@/lib/auth/AuthContext';
import { ROLE_META } from '@/lib/auth/roles';
import { ERP_NAV, PORTAL_NAV } from '@/routes/navConfig';
import type { NavItem } from '@/routes/navConfig';

function Splash() {
  return (
    <div className="grid h-screen place-items-center bg-surface-low">
      <div className="flex flex-col items-center gap-s4">
        <span className="grid h-14 w-14 animate-pulse place-items-center rounded-2xl bg-primary text-2xl font-bold text-on-primary">A</span>
        <span className="ak-label-md text-on-surface-variant">Loading Akshara…</span>
      </div>
    </div>
  );
}

function RequireAuth({ children }: { children: ReactElement }) {
  const { user, ready } = useAuth();
  const location = useLocation();
  if (!ready) return <Splash />;
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  return children;
}

function PublicOnly({ children }: { children: ReactElement }) {
  const { user, ready } = useAuth();
  if (!ready) return <Splash />;
  if (user) return <Navigate to={ROLE_META[user.role].landing} replace />;
  return children;
}

function RootRedirect() {
  const { user } = useAuth();
  return <Navigate to={user ? ROLE_META[user.role].landing : '/login'} replace />;
}

/** Real pages that are fully implemented. Everything else falls back to a scaffold. */
const REAL_PAGES: Record<string, ReactElement> = {
  '/admin/dashboard': <DashboardPage />,
  '/sis/registry': <StudentRegistryPage />,
  '/sis/dashboard': <SisDashboardPage />,
  '/sis/academic-assignment': <AcademicAssignmentPage />,
  '/sis/admissions-conversion': <AdmissionsConversionPage />,
  '/sis/promotion': <PromotionPage />,
  '/sis/reshuffle': <ReshufflePage />,
  '/sis/section-balance': <SectionBalancePage />,
  '/sis/transfers': <TransfersPage />,
  '/academics': <ExamAdministrationPage />,
  '/academics/exams': <ExamAdministrationPage />,
  '/academics/exams/marks-entry': <ExamMarksEntryPage />,
  '/academics/exams/progress': <ExamMarksProgressPage />,
  '/academics/exams/reports': <ExamReportsPage />,
  '/academics/timetable': <TimetableHubPage />,
  '/academics/substitutions': <DailySubstitutionsPage />,
  '/communication': <CommunicationPage />,
  '/reports': <ReportsHubPage />,
  '/settings': <SettingsPage />,
  '/school-config': <SchoolConfigPage />,
  '/onboarding': <OnboardingPage />,
  '/school-completion': <SchoolCompletionHubPage />,
  '/school-completion/subjects': <SubjectsPage />,
  '/school-completion/subject-assignment': <SubjectAssignmentPage />,
  '/school-completion/class-teacher-assignment': <ClassTeacherAssignmentPage />,
  '/school-completion/teacher-reassignment': <TeacherReassignmentPage />,
  '/school-completion/room-allocation': <RoomAllocationPage />,
  '/school-completion/lesson-logs': <LessonLogsPage />,
  '/school-completion/substitute-manager': <SubstituteManagerPage />,
  '/school-completion/timetable-automation': <TimetableAutomationPage />,
  '/school-completion/timetable-optimization': <TimetableOptimizationPage />,
  '/school-completion/timetable-intelligence': <TimetableIntelligencePage />,
  '/school-completion/syllabus-automation': <SyllabusAutomationPage />,
  '/school-completion/lesson-analytics': <LessonAnalyticsPage />,
  '/school-completion/academic-progress': <AcademicProgressPage />,
  '/school-completion/communication-analytics': <CommunicationAnalyticsPage />,
  '/school-completion/communication-delivery': <CommunicationDeliveryPage />,
  '/school-completion/parent-activation': <ParentActivationPage />,
  '/school-completion/pilot-dashboard': <PilotDashboardPage />,
  '/school-completion/branding': <BrandingPage />,
  '/school-completion/whatsapp-provider': <WhatsAppProviderPage />,
  '/parent/dashboard': <ParentDashboardPage />,
  '/parent/experience-hub': <ParentExperienceHubPage />,
  '/parent/academic-report': <ParentAcademicReportPage />,
  '/parent/attendance': <ParentAttendancePage />,
  '/parent/timetable': <ParentTimetablePage />,
  '/parent/homework': <ParentHomeworkPage />,
  '/parent/exams': <ParentExamsPage />,
  '/parent/report-card': <ParentReportCardPage />,
  '/parent/fees': <ParentFeesPage />,
  '/parent/payment': <ParentPaymentPage />,
  '/parent/receipts': <ParentReceiptsPage />,
  '/parent/notices': <ParentNoticesPage />,
  '/parent/events': <ParentEventsPage />,
  '/parent/messages': <ParentMessagesPage />,
  '/parent/leave': <ParentLeavePage />,
  '/parent/ptm': <ParentPtmPage />,
  '/parent/transport': <ParentTransportPage />,
  '/parent/action-inbox': <ParentActionInboxPage />,
  '/parent/family': <ParentFamilyViewPage />,
  '/parent/profile': <ParentProfilePage />,
  '/teacher/today': <TeacherTodayPage />,
  '/teacher/dashboard': <TeacherDashboardPage />,
  '/teacher/class-teacher-dashboard': <ClassTeacherDashboardPage />,
  '/teacher/attendance': <TeacherAttendancePage />,
  '/teacher/my-attendance': <MyAttendancePage />,
  '/teacher/timetable': <TeacherTimetablePage />,
  '/teacher/homework': <TeacherHomeworkPage />,
  '/teacher/homework/create': <TeacherHomeworkCreatePage />,
  '/teacher/homework/history': <TeacherHomeworkHistoryPage />,
  '/teacher/exams': <TeacherExamsPage />,
  '/teacher/messages': <TeacherMessagesPage />,
  '/teacher/parent-communication': <TeacherParentCommunicationPage />,
  '/teacher/student-risk': <TeacherStudentRiskPage />,
  '/teacher/leave': <TeacherLeavePage />,
  '/teacher/leave-approvals': <TeacherLeaveApprovalsPage />,
  '/teacher/profile': <TeacherProfilePage />,
  '/teacher/settings': <TeacherSettingsPage />,
  '/student/dashboard': <StudentDashboardPage />,
  '/student/attendance': <StudentAttendancePage />,
  '/student/timetable': <StudentTimetablePage />,
  '/student/homework': <StudentHomeworkPage />,
  '/student/exams': <StudentExamsPage />,
  '/student/report-card': <StudentReportCardPage />,
  '/student/progress': <StudentProgressPage />,
  '/student/notices': <StudentNoticesPage />,
  '/student/profile': <StudentProfilePage />,
  '/attendance': <AttendanceOverviewPage />,
  '/attendance/register': <AttendanceRegisterPage />,
  '/attendance/corrections': <AttendanceCorrectionsPage />,
  '/management/dashboard': <ManagementDashboardPage />,
  '/management/analytics': <ManagementAnalyticsPage />,
  '/management/admissions': <ManagementAdmissionsPage />,
  '/management/finance': <ManagementFinancePage />,
  '/management/academics': <ManagementAcademicsPage />,
  '/management/performance': <ManagementPerformancePage />,
  '/management/approvals': <ApprovalCenterPage />,
  '/management/tasks': <ManagementTasksPage />,
  '/management/settings': <ManagementSettingsPage />,
  '/director/dashboard': <DirectorDashboardPage />,
  '/director/schools': <DirectorSchoolsPage />,
  '/director/portfolio': <DirectorPortfolioPage />,
  '/director/revenue': <DirectorRevenuePage />,
  '/director/admissions': <DirectorAdmissionsPage />,
  '/director/growth': <DirectorGrowthPage />,
  '/director/marketing': <DirectorMarketingPage />,
  '/director/compliance': <DirectorCompliancePage />,
  '/director/reports': <DirectorReportsPage />,
  '/intelligence': <IntelligenceHubPage />,
  '/intelligence/student-success': <StudentSuccessPage />,
  '/intelligence/teacher-effectiveness': <TeacherEffectivenessPage />,
  '/intelligence/exams': <ExamIntelligencePage />,
  '/intelligence/homework': <HomeworkIntelligencePage />,
  '/intelligence/trust': <TrustIntelligencePage />,
  '/intelligence/ai-economics': <AiEconomicsPage />,
  '/hr/dashboard': <HrDashboardPage />,
  '/hr/employees': <EmployeesPage />,
  '/hr/attendance': <HrAttendancePage />,
  '/hr/leave': <HrLeavePage />,
  '/hr/payroll': <HrPayrollPage />,
  '/hr/recruitment': <HrRecruitmentPage />,
  '/hr/performance': <HrPerformancePage />,
  '/hr/reports': <HrReportsPage />,
  '/hr/settings': <HrSettingsPage />,
  '/admissions/dashboard': <AdmissionsDashboardPage />,
  '/admissions/leads': <LeadsPage />,
  '/admissions/applications': <ApplicationsPage />,
  '/admissions/approval': <ApprovalPage />,
  '/admissions/documents': <DocumentsPage />,
  '/admissions/enrollment': <EnrollmentPage />,
  '/admissions/reports': <AdmissionsReportsPage />,
  '/admissions/settings': <AdmissionsSettingsPage />,
  '/finance/dashboard': <FinanceDashboardPage />,
  '/finance/collections': <CollectionsPage />,
  '/finance/student-accounts': <StudentAccountsPage />,
  '/finance/fee-structures': <FeeStructuresPage />,
  '/finance/defaulters': <DefaultersPage />,
  '/finance/refunds': <RefundsPage />,
  '/finance/discounts': <DiscountsPage />,
  '/finance/reports': <FinanceReportsPage />,
  '/finance/settings': <FinanceSettingsPage />,
  '/finance/fee-assignment': <FeeAssignmentPage />,
  '/finance/offline-payments': <OfflinePaymentsPage />,
  '/finance/qr-payment': <QrPaymentPage />,
  '/finance/reconciliation': <ReconciliationPage />,
  '/finance/executive': <FinanceExecutivePage />,
  '/finance/copilot': <FinanceCopilotPage />,
  '/transport/dashboard': <TransportDashboardPage />,
  '/transport/routes': <RoutesPage />,
  '/transport/vehicles': <VehiclesPage />,
  '/transport/drivers': <DriversPage />,
  '/transport/allocation': <AllocationsPage />,
  '/transport/attendance': <TransportAttendancePage />,
  '/transport/tracking': <TrackingPage />,
  '/transport/reports': <TransportReportsPage />,
  '/transport/settings': <TransportSettingsPage />,
  '/library/dashboard': <LibraryDashboardPage />,
  '/library/catalog': <CatalogPage />,
  '/library/issues': <IssuesPage />,
  '/library/returns': <ReturnsPage />,
  '/library/members': <MembersPage />,
  '/library/fines': <FinesPage />,
  '/library/overdue': <OverduePage />,
  '/library/resources': <ResourcesPage />,
  '/library/reports': <LibraryReportsPage />,
  '/hostel/dashboard': <HostelDashboardPage />,
  '/hostel/students': <HostelStudentsPage />,
  '/hostel/rooms': <RoomsPage />,
  '/hostel/attendance': <HostelAttendancePage />,
  '/hostel/leave': <HostelLeavePage />,
  '/hostel/mess': <MessPage />,
  '/hostel/visitors': <VisitorsPage />,
  '/hostel/reports': <HostelReportsPage />,
  '/inventory/dashboard': <InventoryDashboardPage />,
  '/inventory/stock': <StockPage />,
  '/inventory/stock-approvals': <StockApprovalsPage />,
  '/inventory/assets': <AssetsPage />,
  '/inventory/categories': <CategoriesPage />,
  '/inventory/allocation': <InvAllocationsPage />,
  '/inventory/distribution': <DistributionPage />,
  '/inventory/maintenance': <MaintenancePage />,
  '/inventory/replacement': <ReplacementPage />,
  '/inventory/procurement': <ProcurementPage />,
  '/inventory/vendors': <VendorsPage />,
  '/inventory/lifecycle': <LifecyclePage />,
  '/inventory/reports': <InventoryReportsPage />,
  '/inventory/copilot': <InventoryCopilotPage />,
  '/alumni/dashboard': <AlumniDashboardPage />,
  '/alumni/registry': <RegistryPage />,
  '/alumni/campaigns': <CampaignsPage />,
  '/alumni/donations': <DonationsPage />,
  '/alumni/events': <EventsPage />,
  '/alumni/mentorship': <MentorshipPage />,
  '/alumni/reports': <AlumniReportsPage />,
  '/alumni/settings': <AlumniSettingsPage />,
  // Evolution
  '/growth': <Misc.GrowthPlatformPage />,
  '/parent-insights': <Misc.ParentInsightsPage />,
  '/principal-command': <Misc.PrincipalCommandPage />,
  '/teacher-assistant': <Misc.TeacherAssistantPage />,
  '/setup-wizard': <Misc.SetupWizardPage />,
  // Copilot / AI
  '/copilot': <Misc.CopilotPage />,
  '/ai-assistant': <Misc.CopilotPersonaShellPage />,
  '/ai-content': <Misc.AiContentPage />,
  '/settings/ai-assistant': <Misc.AiAssistantSettingsPage />,
  // Memories
  '/memories': <Misc.SchoolMemoriesPage />,
  '/memories/event': <Misc.MemoryEventPage />,
  // Dynamic widgets
  '/dynamic-widgets/registry': <Misc.DynamicWidgetRegistryPage />,
  '/dynamic-widgets/editor': <Misc.DynamicWidgetLayoutEditorPage />,
  '/dynamic-widgets/runtime': <Misc.DynamicWidgetRuntimePage />,
  // 360 views
  '/employee/360': <Misc.Employee360Page />,
  '/employee/platform': <Misc.EmployeePlatformPage />,
  '/student-360': <Misc.Student360Page />,
  // Entitlements
  '/entitlements': <Misc.PlanEntitlementsPage />,
  '/entitlements/assign': <Misc.OrgPlanAssignmentPage />,
  // Achievement
  '/achievement-promotion': <Misc.AchievementPromotionPage />,
  '/achievement-promotion/preview': <Misc.AchievementPreviewPage />,
  // Operations / platform-lite
  '/operations': <Misc.OperationsHubPage />,
  '/resource-optimization': <Misc.ResourceOptimizationPage />,
  '/predictions': <Misc.PredictionsPage />,
  '/industry': <Misc.IndustryHubPage />,
  '/workflow': <Misc.WorkflowAutomationPage />,
  '/continuity': <Misc.ContinuityMigrationPage />,
  // Admin
  '/admin': <Misc.AdminHubPage />,
  '/admin/backup-restore': <Misc.BackupRestorePage />,
  // Legal
  '/legal-acceptance': <Misc.LegalAcceptancePage />,
  // Education
  '/education': <Misc.EducationPage />,
  '/education/question-paper': <Misc.QuestionPaperDetailPage />,
  // Parent meetings (staff)
  '/parent-meetings': <Misc.ParentMeetingsPage />,
  '/parent-meetings/detail': <Misc.ParentMeetingDetailPage />,
};

// Every nav path across the ERP console + portals gets a route so navigation is
// complete; unbuilt ones render an honest ModuleScaffold until ported.
function collectNavItems(): NavItem[] {
  const seen = new Set<string>();
  const all: NavItem[] = [...ERP_NAV.flatMap((s) => s.items), ...Object.values(PORTAL_NAV).flat()];
  return all.filter((i) => (seen.has(i.path) ? false : (seen.add(i.path), true)));
}

// Union of nav-item paths and any real pages not surfaced in the nav (module
// sub-pages like /admissions/leads), so every built page is routed.
const navItems = collectNavItems();
const navByPath = new Map(navItems.map((i) => [i.path, i]));
const allPaths = new Set<string>([...navItems.map((i) => i.path), ...Object.keys(REAL_PAGES)]);

const navChildren = Array.from(allPaths).map((path) => {
  const item = navByPath.get(path);
  return {
    path: path.replace(/^\//, ''),
    element: REAL_PAGES[path] ?? <ModuleScaffold title={item?.label ?? 'Page'} icon={item?.icon} />,
  };
});

export const router = createBrowserRouter([
  { path: '/login', element: <PublicOnly><LoginPage /></PublicOnly> },
  { path: '/staff/login', element: <PublicOnly><LoginPage /></PublicOnly> },
  { path: '/qa-login', element: <PublicOnly><LoginPage /></PublicOnly> },
  { path: '/otp', element: <PublicOnly><OtpVerificationPage /></PublicOnly> },
  { path: '/staff/otp', element: <PublicOnly><OtpVerificationPage /></PublicOnly> },
  {
    path: '/',
    element: (
      <RequireAuth>
        <AppShell />
      </RequireAuth>
    ),
    children: [
      { index: true, element: <RootRedirect /> },
      ...navChildren,
      // ASIP Support Console (scoped unfreeze) — gated on the platformSupport
      // permission by SupportConsoleGate; additive, does not touch frozen pages.
      {
        path: 'support-console',
        element: <SupportConsoleGate />,
        children: [
          { index: true, element: <SupportQueuePage /> },
          { path: 'incidents/:id', element: <SupportIncidentPage /> },
          { path: 'clusters', element: <SupportClustersPage /> },
          { path: 'clusters/:id', element: <SupportClusterDetailPage /> },
          { path: 'kb', element: <SupportKbPage /> },
        ],
      },
      // Parametric detail routes (deep-linkable record views)
      { path: 'sis/students/:id', element: <SisStudentDetailPage /> },
      { path: 'finance/collections/:id', element: <CollectionDetailPage /> },
      { path: 'admissions/leads/:id', element: <LeadDetailPage /> },
      { path: 'parent/receipts/:id', element: <ReceiptDetailPage /> },
      { path: 'teacher/messages/:id', element: <TeacherConversationPage /> },
      { path: 'parent/messages/:id', element: <ParentConversationPage /> },
      { path: 'notifications', element: <NotificationsPage /> },
      { path: '*', element: <ModuleScaffold title="Page" icon="description" note="This route is part of the parity build and will be implemented with its module." /> },
    ],
  },
], {
  // Serve under a sub-path when built with a Vite `base` (e.g. --base=/review/).
  // Defaults to root for normal `/` builds, so this is a no-op in production.
  basename:
    import.meta.env.BASE_URL && import.meta.env.BASE_URL !== '/'
      ? import.meta.env.BASE_URL.replace(/\/$/, '')
      : undefined,
});
