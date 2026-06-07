#!/usr/bin/env python3
"""Update repository_test.dart for async tenant-aware repos."""
import re
from pathlib import Path

path = Path(__file__).resolve().parent.parent / "test/core/repositories/repository_test.dart"
content = path.read_text()

content = content.replace(
    "import 'package:akshara_erp/core/repositories/repository_config.dart';",
    "import 'package:akshara_erp/core/repositories/repository_config.dart';\n"
    "import 'package:akshara_erp/core/repositories/repository_query.dart';",
)

# Make test callbacks async
content = re.sub(
    r"test\('([^']+)', \(\) \{",
    r"test('\1', () async {",
    content,
)

# Add query const after repo creation
content = re.sub(
    r"(final repo = Mock\w+Repository\(\);)\n",
    r"\1\n      const query = RepositoryQuery.demo;\n",
    content,
)

# Method call transforms
replacements = [
    (r"repo\.getDashboard\(\)", r"(await repo.getDashboard(query: query))"),
    (r"repo\.getCollections\(\)", r"(await repo.getCollections(query: query))"),
    (r"repo\.getFeeStructures\('([^']+)'\)", r"(await repo.getFeeStructures(query: query, academicYear: '\1'))"),
    (r"repo\.getStudentAccounts\(\)", r"(await repo.getStudentAccounts(query: query))"),
    (r"repo\.getInstallmentPlans\(\)", r"(await repo.getInstallmentPlans(query: query))"),
    (r"repo\.getCollectionDetail\('([^']+)'\)", r"(await repo.getCollectionDetail(query: query, collectionId: '\1'))"),
    (r"repo\.getDefaultersDashboard\(\)", r"(await repo.getDefaultersDashboard(query: query))"),
    (r"repo\.getRefundRequests\(\)", r"(await repo.getRefundRequests(query: query))"),
    (r"repo\.getDiscountsDashboard\(\)", r"(await repo.getDiscountsDashboard(query: query))"),
    (r"repo\.getReportsData\(\)", r"(await repo.getReportsData(query: query))"),
    (r"repo\.getSettings\(\)", r"(await repo.getSettings(query: query))"),
    (r"repo\.getLeads\(\)", r"(await repo.getLeads(query: query))"),
    (r"repo\.getApplications\(\)", r"(await repo.getApplications(query: query))"),
    (r"repo\.getDocuments\(\)", r"(await repo.getDocuments(query: query))"),
    (r"repo\.getPendingEnrollments\(\)", r"(await repo.getPendingEnrollments(query: query))"),
    (r"repo\.getApprovedHandoffs\(\)", r"(await repo.getApprovedHandoffs(query: query))"),
    (r"repo\.getApprovalQueue\(\)", r"(await repo.getApprovalQueue(query: query))"),
    (r"repo\.getStudents\(\)", r"(await repo.getStudents(query: query))"),
    (r"repo\.getClassOptions\(\)", r"(await repo.getClassOptions(query: query))"),
    (r"repo\.getSectionOptions\(\)", r"(await repo.getSectionOptions(query: query))"),
    (r"repo\.getAnalytics\(\)", r"(await repo.getAnalytics(query: query))"),
    (r"repo\.getAdmissionsFunnel\(\)", r"(await repo.getAdmissionsFunnel(query: query))"),
    (r"repo\.getFinancialHealth\(\)", r"(await repo.getFinancialHealth(query: query))"),
    (r"repo\.getAcademicHealth\(\)", r"(await repo.getAcademicHealth(query: query))"),
    (r"repo\.getSchoolPerformance\(\)", r"(await repo.getSchoolPerformance(query: query))"),
    (r"repo\.getTasksAndApprovals\(\)", r"(await repo.getTasksAndApprovals(query: query))"),
    (r"repo\.getRoutes\(\)", r"(await repo.getRoutes(query: query))"),
    (r"repo\.getVehicles\(\)", r"(await repo.getVehicles(query: query))"),
    (r"repo\.getDrivers\(\)", r"(await repo.getDrivers(query: query))"),
    (r"repo\.getAllocations\(\)", r"(await repo.getAllocations(query: query))"),
    (r"repo\.getAttendanceRecords\(\)", r"(await repo.getAttendanceRecords(query: query))"),
    (r"repo\.getTrackingPlaceholder\(\)", r"(await repo.getTrackingPlaceholder(query: query))"),
    (r"repo\.getReports\(\)", r"(await repo.getReports(query: query))"),
    (r"repo\.getOccupancyMetrics\(\)", r"(await repo.getOccupancyMetrics(query: query))"),
    (r"repo\.getRooms\(\)", r"(await repo.getRooms(query: query))"),
    (r"repo\.getLeaveRequests\(\)", r"(await repo.getLeaveRequests(query: query))"),
    (r"repo\.getMessData\(\)", r"(await repo.getMessData(query: query))"),
    (r"repo\.getVisitors\(\)", r"(await repo.getVisitors(query: query))"),
    (r"repo\.getCatalog\(\)", r"(await repo.getCatalog(query: query))"),
    (r"repo\.getIssues\(\)", r"(await repo.getIssues(query: query))"),
    (r"repo\.getReturns\(\)", r"(await repo.getReturns(query: query))"),
    (r"repo\.getMembers\(\)", r"(await repo.getMembers(query: query))"),
    (r"repo\.getFines\(\)", r"(await repo.getFines(query: query))"),
    (r"repo\.getDigitalResources\(\)", r"(await repo.getDigitalResources(query: query))"),
    (r"repo\.getAssets\(\)", r"(await repo.getAssets(query: query))"),
    (r"repo\.getCategories\(\)", r"(await repo.getCategories(query: query))"),
    (r"repo\.getMaintenanceRecords\(\)", r"(await repo.getMaintenanceRecords(query: query))"),
    (r"repo\.getProcurementOrders\(\)", r"(await repo.getProcurementOrders(query: query))"),
    (r"repo\.getVendors\(\)", r"(await repo.getVendors(query: query))"),
    (r"repo\.getAlumniRegistry\(\)", r"(await repo.getAlumniRegistry(query: query))"),
    (r"repo\.getAlumniDetail\('([^']+)'\)", r"(await repo.getAlumniDetail(query: query, alumniId: '\1'))"),
    (r"repo\.getEvents\(\)", r"(await repo.getEvents(query: query))"),
    (r"repo\.getDonations\(\)", r"(await repo.getDonations(query: query))"),
    (r"repo\.getCampaigns\(\)", r"(await repo.getCampaigns(query: query))"),
    (r"repo\.getMentorshipPairs\(\)", r"(await repo.getMentorshipPairs(query: query))"),
    (r"repo\.getSchools\(\)", r"(await repo.getSchools(query: query))"),
    (r"repo\.getSubscriptions\(\)", r"(await repo.getSubscriptions(query: query))"),
    (r"repo\.getBilling\(\)", r"(await repo.getBilling(query: query))"),
    (r"repo\.getCrmPipeline\(\)", r"(await repo.getCrmPipeline(query: query))"),
    (r"repo\.getSupportTickets\(\)", r"(await repo.getSupportTickets(query: query))"),
    (r"repo\.getCustomerSuccess\(\)", r"(await repo.getCustomerSuccess(query: query))"),
    (r"repo\.getWhiteLabelConfigs\(\)", r"(await repo.getWhiteLabelConfigs(query: query))"),
    (r"repo\.getMonitoring\(\)", r"(await repo.getMonitoring(query: query))"),
    (r"repo\.getRoles\(\)", r"(await repo.getRoles(query: query))"),
    (r"repo\.getEmployees\(\)", r"(await repo.getEmployees(query: query))"),
    (r"repo\.getEmployeeDetail\('([^']+)'\)", r"(await repo.getEmployeeDetail(query: query, employeeId: '\1'))"),
    (r"repo\.getAttendance\(\)", r"(await repo.getAttendance(query: query))"),
    (r"repo\.getLeave\(\)", r"(await repo.getLeave(query: query))"),
    (r"repo\.getPayroll\(\)", r"(await repo.getPayroll(query: query))"),
    (r"repo\.getRecruitment\(\)", r"(await repo.getRecruitment(query: query))"),
    (r"repo\.getPerformance\(\)", r"(await repo.getPerformance(query: query))"),
]

for pattern, repl in replacements:
    content = re.sub(pattern, repl, content)

path.write_text(content)
print("Updated repository_test.dart")
