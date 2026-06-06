import '../admin/models/admin_nav_models.dart';
import '../../router/route_names.dart';

/// Admissions sub-module destinations (AD-01 → AD-10).
enum AdmissionsScreen {
  dashboard,
  leads,
  applications,
  enrollment,
  documents,
  approval,
  feeHandoff,
  reports,
  settings;

  String get route => switch (this) {
        AdmissionsScreen.dashboard => RouteNames.admissionsDashboard,
        AdmissionsScreen.leads => RouteNames.admissionsLeads,
        AdmissionsScreen.applications => RouteNames.admissionsApplications,
        AdmissionsScreen.enrollment => RouteNames.admissionsEnrollment,
        AdmissionsScreen.documents => RouteNames.admissionsDocuments,
        AdmissionsScreen.approval => RouteNames.admissionsApproval,
        AdmissionsScreen.feeHandoff => RouteNames.admissionsFeeHandoff,
        AdmissionsScreen.reports => RouteNames.admissionsReports,
        AdmissionsScreen.settings => RouteNames.admissionsSettings,
      };

  String get label => switch (this) {
        AdmissionsScreen.dashboard => 'Dashboard',
        AdmissionsScreen.leads => 'Leads',
        AdmissionsScreen.applications => 'Applications',
        AdmissionsScreen.enrollment => 'Enrollment',
        AdmissionsScreen.documents => 'Documents',
        AdmissionsScreen.approval => 'Approval',
        AdmissionsScreen.feeHandoff => 'Fee Handoff',
        AdmissionsScreen.reports => 'Reports',
        AdmissionsScreen.settings => 'Settings',
      };
}

/// Primary admissions sub-navigation tabs (excludes lead detail).
const List<AdmissionsScreen> kAdmissionsNavScreens = [
  AdmissionsScreen.dashboard,
  AdmissionsScreen.leads,
  AdmissionsScreen.applications,
  AdmissionsScreen.enrollment,
  AdmissionsScreen.documents,
  AdmissionsScreen.approval,
  AdmissionsScreen.feeHandoff,
  AdmissionsScreen.reports,
  AdmissionsScreen.settings,
];

/// @deprecated Use [kAdmissionsNavScreens].
const List<AdmissionsScreen> kAdmissionsPhase1Screens = kAdmissionsNavScreens;

/// Breadcrumbs for an admissions screen inside the admin shell.
List<AdminBreadcrumb> admissionsBreadcrumbs(AdmissionsScreen screen) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Admissions',
      route: RouteNames.admissionsDashboard,
    ),
    AdminBreadcrumb(label: screen.label),
  ];
}

/// Breadcrumbs for AD-04 lead detail nested under Leads.
List<AdminBreadcrumb> admissionsLeadDetailBreadcrumbs({
  required String leadLabel,
}) {
  return [
    const AdminBreadcrumb(
      label: 'Admin Hub',
      route: RouteNames.admin,
    ),
    const AdminBreadcrumb(
      label: 'Admissions',
      route: RouteNames.admissionsDashboard,
    ),
    const AdminBreadcrumb(
      label: 'Leads',
      route: RouteNames.admissionsLeads,
    ),
    AdminBreadcrumb(label: leadLabel),
  ];
}

/// Resolves [AdmissionsScreen] from a router location path.
AdmissionsScreen? admissionsScreenForLocation(String location) {
  if (location.startsWith('${RouteNames.admissionsLeads}/')) {
    return AdmissionsScreen.leads;
  }

  for (final screen in AdmissionsScreen.values) {
    if (location == screen.route || location.startsWith('${screen.route}/')) {
      return screen;
    }
  }
  if (location == RouteNames.admissions) {
    return AdmissionsScreen.dashboard;
  }
  return null;
}
