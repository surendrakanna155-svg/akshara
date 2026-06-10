import '../../../../../features/onboarding/onboarding_models.dart';
import '../dto/onboarding_dto.dart';

class OnboardingMapper {
  const OnboardingMapper();

  OnboardingDashboardData toDashboard(OnboardingDashboardDto dto) {
    final raw = dto.raw;
    final jobs = (raw['recentJobs'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_toJob)
        .toList();
    return OnboardingDashboardData(
      recentJobs: jobs,
      pendingInvites: raw['pendingInvites'] as int? ?? 0,
      totalInvites: raw['totalInvites'] as int? ?? 0,
    );
  }

  OnboardingImportPreviewResult toPreview(OnboardingImportPreviewDto dto) {
    final raw = dto.raw;
    final preview = (raw['preview'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => OnboardingImportPreviewRow(
            rowNumber: row['rowNumber'] as int? ?? 0,
            status: row['status'] as String? ?? 'invalid',
            errors: (row['errors'] as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .toList(),
          ),
        )
        .toList();
    return OnboardingImportPreviewResult(
      job: _toJob(raw['job'] as Map<String, dynamic>? ?? const {}),
      preview: preview,
    );
  }

  OnboardingImportJob toJob(OnboardingImportJobDto dto) => _toJob(dto.raw);

  List<OnboardingInvite> toInvites(OnboardingInvitesListDto dto) {
    return [for (final item in dto.items) _toInvite(item)];
  }

  OnboardingInvite toInvite(OnboardingInviteDto dto) => _toInvite(dto.raw);

  OnboardingImportJob _toJob(Map<String, dynamic> raw) {
    return OnboardingImportJob(
      id: raw['id'] as String? ?? '',
      importType: raw['importType'] as String? ?? '',
      status: raw['status'] as String? ?? '',
      fileName: raw['fileName'] as String? ?? '',
      totalRows: raw['totalRows'] as int? ?? 0,
      validRows: raw['validRows'] as int? ?? 0,
      invalidRows: raw['invalidRows'] as int? ?? 0,
      duplicateRows: raw['duplicateRows'] as int? ?? 0,
      committedRows: raw['committedRows'] as int? ?? 0,
    );
  }

  OnboardingInvite _toInvite(Map<String, dynamic> raw) {
    return OnboardingInvite(
      id: raw['id']?.toString() ?? '',
      inviteType: raw['invite_type'] as String? ?? raw['inviteType'] as String? ?? '',
      recipientPhone: raw['recipient_phone'] as String? ?? raw['recipientPhone'] as String? ?? '',
      recipientLabel: raw['recipient_label'] as String? ?? raw['recipientLabel'] as String? ?? '',
      status: raw['status'] as String? ?? '',
      channel: raw['channel'] as String? ?? '',
      deepLink: raw['deep_link'] as String? ?? raw['deepLink'] as String? ?? '',
      whatsappLink: raw['whatsappLink'] as String?,
    );
  }
}
