import '../../../../features/employee/employee_models.dart';
import '../../../../features/homework_intelligence/homework_intelligence_models.dart';
import '../../../../features/inventory_distribution/inventory_distribution_models.dart';
import '../../../../features/student_360/student_360_models.dart';

class Phase4Mapper {
  static HomeworkIntelligencePlan homeworkPlanFromApi(Map<String, dynamic> json) {
    final plan = json['plan'] as Map<String, dynamic>? ?? json;
    return HomeworkIntelligencePlan(
      className: plan['className'] as String? ?? '',
      subjectName: plan['subjectName'] as String? ?? '',
      examType: plan['examType'] as String? ?? 'unit_test',
      weakTopics: _listOfMaps(plan['weakTopics']),
      riskStudents: _listOfMaps(plan['riskStudents']),
      revisionSuggestions: _stringList(plan['revisionSuggestions']),
      worksheetSuggestions: _listOfMaps(plan['worksheetSuggestions']),
      recommendedHomework: _listOfMaps(plan['recommendedHomework']),
      recommendedQuestionPapers: _listOfMaps(plan['recommendedQuestionPapers']),
      classRecommendations: _stringList(plan['classRecommendations']),
      studentRecommendations: _listOfMaps(plan['studentRecommendations']),
      revisionPlans: _listOfMaps(plan['revisionPlans']),
      interventionPlans: _listOfMaps(plan['interventionPlans']),
    );
  }

  static Student360Profile student360FromApi(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? json;
    return Student360Profile(
      identity: Map<String, dynamic>.from(profile['identity'] as Map? ?? {}),
      admissions: Map<String, dynamic>.from(profile['admissions'] as Map? ?? {}),
      attendance: Map<String, dynamic>.from(profile['attendance'] as Map? ?? {}),
      marks: Map<String, dynamic>.from(profile['marks'] as Map? ?? {}),
      homework: Map<String, dynamic>.from(profile['homework'] as Map? ?? {}),
      communication: Map<String, dynamic>.from(profile['communication'] as Map? ?? {}),
      fees: Map<String, dynamic>.from(profile['fees'] as Map? ?? {}),
      inventory: Map<String, dynamic>.from(profile['inventory'] as Map? ?? {}),
      activities: Map<String, dynamic>.from(profile['activities'] as Map? ?? {}),
      achievements: Map<String, dynamic>.from(profile['achievements'] as Map? ?? {}),
      risk: Map<String, dynamic>.from(profile['risk'] as Map? ?? {}),
      parentInformation: Map<String, dynamic>.from(profile['parentInformation'] as Map? ?? {}),
    );
  }

  static StudentTimelineEvent timelineFromApi(Map<String, dynamic> json) {
    return StudentTimelineEvent(
      id: json['id'] as String,
      eventType: json['eventType'] as String,
      eventAt: json['eventAt'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      sourceModule: json['sourceModule'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    );
  }

  static EmployeeDashboard employeeDashboardFromApi(Map<String, dynamic> json) {
    return EmployeeDashboard(
      totalEmployees: (json['totalEmployees'] as num?)?.toInt() ?? 0,
      activeEmployees: (json['activeEmployees'] as num?)?.toInt() ?? 0,
      roleDistribution: _listOfMaps(json['roleDistribution']),
      workloadIndex: (json['workloadIndex'] as num?)?.toInt() ?? 0,
      recentAssignments: _listOfMaps(json['recentAssignments']),
    );
  }

  static EmployeeSummary employeeSummaryFromApi(Map<String, dynamic> json) {
    return EmployeeSummary(
      id: json['id'] as String,
      employeeCode: json['employeeCode'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      status: json['status'] as String? ?? 'active',
      primaryDepartment: json['primaryDepartment'] as String?,
      userId: json['userId'] as String?,
    );
  }

  static EmployeeDetail employeeDetailFromApi(Map<String, dynamic> json) {
    return EmployeeDetail(
      summary: EmployeeSummary(
        id: json['id'] as String,
        employeeCode: json['employeeCode'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        status: json['status'] as String? ?? 'active',
        primaryDepartment: json['primaryDepartment'] as String?,
        userId: json['userId'] as String?,
      ),
      roles: (json['roles'] as List<dynamic>? ?? const [])
          .map((e) => employeeRoleFromApi(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  static EmployeeRoleAssignment employeeRoleFromApi(Map<String, dynamic> json) {
    return EmployeeRoleAssignment(
      id: json['id'] as String,
      roleCode: json['roleCode'] as String,
      effectiveFrom: json['effectiveFrom'] as String,
      effectiveTo: json['effectiveTo'] as String?,
      isPrimary: json['isPrimary'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  static InvDistributionDashboard distributionDashboardFromApi(Map<String, dynamic> json) {
    return InvDistributionDashboard(
      pendingDistributions: (json['pendingDistributions'] as num?)?.toInt() ?? 0,
      replacementRequests: (json['replacementRequests'] as num?)?.toInt() ?? 0,
      paymentPending: (json['paymentPending'] as num?)?.toInt() ?? 0,
      distributedToday: (json['distributedToday'] as num?)?.toInt() ?? 0,
      byCategory: _listOfMaps(json['byCategory']),
    );
  }

  static InvCatalogItem catalogItemFromApi(Map<String, dynamic> json) {
    return InvCatalogItem(
      id: json['id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      skuCode: json['skuCode'] as String?,
      unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
      stockOnHand: (json['stockOnHand'] as num?)?.toInt() ?? 0,
    );
  }

  static InvStudentDistribution distributionFromApi(Map<String, dynamic> json) {
    return InvStudentDistribution(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      catalogItemId: json['catalogItemId'] as String,
      itemName: json['itemName'] as String?,
      category: json['category'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'available',
      distributedAt: json['distributedAt'] as String?,
      acknowledgedAt: json['acknowledgedAt'] as String?,
      paymentRequestId: json['paymentRequestId'] as String?,
    );
  }

  static InvReplacementRequest replacementRequestFromApi(Map<String, dynamic> json) {
    return InvReplacementRequest(
      id: json['id'] as String,
      distributionId: json['distributionId'] as String,
      studentId: json['studentId'] as String,
      itemName: json['itemName'] as String?,
      category: json['category'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      requestedAt: json['requestedAt'] as String? ?? '',
      resolvedAt: json['resolvedAt'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic value) =>
      (value as List<dynamic>? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  static List<String> _stringList(dynamic value) =>
      (value as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
}
