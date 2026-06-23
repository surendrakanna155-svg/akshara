/// Write-side request payloads for platform control center mutations.
class CreateSchoolRequest {
  const CreateSchoolRequest({
    required this.name,
    required this.plan,
    required this.region,
    required this.studentCount,
  });

  final String name;

  /// Free-text plan name; parsed to a [SubscriptionPlan] (defaults to standard).
  final String plan;
  final String region;

  /// Free-text student count; parsed to an int (defaults to 0).
  final String studentCount;
}

class CreateCrmLeadRequest {
  const CreateCrmLeadRequest({
    required this.schoolName,
    required this.contactName,
    required this.owner,
    required this.estimatedMrr,
  });

  final String schoolName;
  final String contactName;
  final String owner;

  /// Free-text estimated MRR in lakhs; parsed to a double (defaults to 0).
  final String estimatedMrr;
}
