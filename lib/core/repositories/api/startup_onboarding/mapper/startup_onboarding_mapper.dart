import '../../../../../features/onboarding/unified_onboarding_models.dart';

class StartupOnboardingMapper {
  const StartupOnboardingMapper();

  UnifiedOnboardingState fromJson(Map<String, dynamic> json) {
    return UnifiedOnboardingState(
      currentStep: _stepFromApi(json['currentStep'] as String? ??
          json['current_step'] as String?),
      schoolName: json['schoolName'] as String? ?? json['school_name'] as String? ?? '',
      board: json['board'] as String? ?? '',
      curriculum: json['curriculum'] as String? ?? 'CBSE',
      address: json['address'] as String? ?? '',
      contactPhone: json['contactPhone'] as String? ?? json['contact_phone'] as String? ?? '',
      contactEmail: json['contactEmail'] as String? ?? json['contact_email'] as String? ?? '',
      academicYear: json['academicYear'] as String? ?? json['academic_year'] as String? ?? '2026-27',
      classes: _stringList(json['classes']),
      sections: _stringList(json['sections']),
      feeModel: json['feeModel'] as String? ?? json['fee_model'] as String? ?? '',
      feeCategories: _stringList(json['feeCategories'] ?? json['fee_categories']),
      logoUrl: json['logoUrl'] as String? ?? json['logo_url'] as String? ?? '',
      themePrimary: json['themePrimary'] as String? ?? json['theme_primary'] as String? ?? '#1565C0',
      themeSecondary: json['themeSecondary'] as String? ?? json['theme_secondary'] as String? ?? '#42A5F5',
      brandingPreferences: _stringMap(json['brandingPreferences'] ?? json['branding_preferences']),
      defaultLanguage: json['defaultLanguage'] as String? ?? json['default_language'] as String? ?? 'en',
      modulesEnabled: _stringList(json['modulesEnabled'] ?? json['modules_enabled']),
      isLive: json['isLive'] as bool? ?? json['is_live'] as bool? ?? false,
      lastSavedAt: _parseDate(json['lastSavedAt'] ?? json['last_saved_at'] ?? json['updatedAt'] ?? json['updated_at']),
      goLiveValidationErrors: _stringList(json['validationErrors'] ?? json['validation_errors']),
      provisionSummary: json['provision'] is Map<String, dynamic>
          ? UnifiedOnboardingProvisionSummary.fromJson(
              json['provision'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toPayload(UnifiedOnboardingState state) {
    return {
      'currentStep': _stepToApi(state.currentStep),
      'schoolName': state.schoolName,
      'board': state.board,
      'curriculum': state.curriculum,
      'address': state.address,
      'contactPhone': state.contactPhone,
      'contactEmail': state.contactEmail,
      'academicYear': state.academicYear,
      'classes': state.classes,
      'sections': state.sections,
      'feeModel': state.feeModel,
      'feeCategories': state.feeCategories,
      'logoUrl': state.logoUrl,
      'themePrimary': state.themePrimary,
      'themeSecondary': state.themeSecondary,
      'brandingPreferences': state.brandingPreferences,
      'defaultLanguage': state.defaultLanguage,
      'modulesEnabled': state.modulesEnabled,
    };
  }

  UnifiedOnboardingStep _stepFromApi(String? value) {
    return UnifiedOnboardingStep.values.firstWhere(
      (step) => step.name == value,
      orElse: () => UnifiedOnboardingStep.schoolProfile,
    );
  }

  String _stepToApi(UnifiedOnboardingStep step) => step.name;

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList(growable: false);
  }

  Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map((key, val) => MapEntry(key.toString(), val?.toString() ?? ''));
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
