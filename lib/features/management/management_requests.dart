import 'management_models.dart';

class ResolveManagementApprovalRequest {
  const ResolveManagementApprovalRequest({
    required this.approvalId,
    required this.status,
  });

  final String approvalId;
  final ManagementApprovalStatus status;
}

class ManagementSettingUpdate {
  const ManagementSettingUpdate({
    required this.sectionId,
    required this.itemId,
    required this.value,
  });

  final String sectionId;
  final String itemId;
  final String value;
}

class UpdateManagementSettingsRequest {
  const UpdateManagementSettingsRequest({
    this.academicYear,
    this.updates = const [],
  });

  final String? academicYear;
  final List<ManagementSettingUpdate> updates;
}
