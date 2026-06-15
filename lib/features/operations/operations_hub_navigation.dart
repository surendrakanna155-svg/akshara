import '../../../router/route_names.dart';

String operationsHubModuleRoute(String module) {
  switch (module.toLowerCase()) {
    case 'intelligence':
      return RouteNames.studentSuccessIntelligence;
    case 'finance':
      return RouteNames.financeDefaulters;
    case 'inventory':
      return RouteNames.inventoryDistribution;
    case 'sis':
      return RouteNames.sisSectionBalance;
    case 'hr':
      return RouteNames.hrDashboard;
    case 'admissions':
      return RouteNames.admissionsDashboard;
    case 'management':
      return RouteNames.managementTasks;
    case 'transport':
      return RouteNames.transportDashboard;
    case 'hostel':
      return RouteNames.hostelDashboard;
    case 'library':
      return RouteNames.libraryDashboard;
    case 'alumni':
      return RouteNames.alumniDashboard;
    default:
      return RouteNames.operationsHub;
  }
}
