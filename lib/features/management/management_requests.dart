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
