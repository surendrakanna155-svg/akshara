import 'package:flutter/foundation.dart';

/// Steps in the unified school startup onboarding wizard.
enum UnifiedOnboardingStep {
  schoolProfile,
  curriculum,
  academicStructure,
  fees,
  branding,
  language,
  modules,
  review,
  goLive,
}

extension UnifiedOnboardingStepLabel on UnifiedOnboardingStep {
  String get label => switch (this) {
        UnifiedOnboardingStep.schoolProfile => 'School Profile',
        UnifiedOnboardingStep.curriculum => 'Curriculum',
        UnifiedOnboardingStep.academicStructure => 'Academic Structure',
        UnifiedOnboardingStep.fees => 'Fees',
        UnifiedOnboardingStep.branding => 'Branding',
        UnifiedOnboardingStep.language => 'Language',
        UnifiedOnboardingStep.modules => 'Modules',
        UnifiedOnboardingStep.review => 'Review',
        UnifiedOnboardingStep.goLive => 'Go Live',
      };
}

@immutable
class UnifiedOnboardingProvisionSummary {
  const UnifiedOnboardingProvisionSummary({
    required this.schoolProfileUpdated,
    required this.brandingUpdated,
    required this.academicYearLabel,
    required this.classCount,
    required this.sectionCount,
    required this.feeStructureCount,
    required this.warnings,
    required this.provisioned,
  });

  final bool schoolProfileUpdated;
  final bool brandingUpdated;
  final String academicYearLabel;
  final int classCount;
  final int sectionCount;
  final int feeStructureCount;
  final List<String> warnings;
  final bool provisioned;

  factory UnifiedOnboardingProvisionSummary.fromJson(Map<String, dynamic> json) {
    return UnifiedOnboardingProvisionSummary(
      schoolProfileUpdated:
          json['schoolProfileUpdated'] as bool? ?? json['school_profile_updated'] as bool? ?? false,
      brandingUpdated:
          json['brandingUpdated'] as bool? ?? json['branding_updated'] as bool? ?? false,
      academicYearLabel: json['academicYearId']?.toString() ??
          json['academicYearLabel'] as String? ??
          '',
      classCount: json['classCount'] as int? ?? json['class_count'] as int? ?? 0,
      sectionCount: json['sectionCount'] as int? ?? json['section_count'] as int? ?? 0,
      feeStructureCount:
          json['feeStructureCount'] as int? ?? json['fee_structure_count'] as int? ?? 0,
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      provisioned: json['provisioned'] as bool? ?? false,
    );
  }
}

@immutable
class UnifiedOnboardingState {
  const UnifiedOnboardingState({
    required this.currentStep,
    required this.schoolName,
    required this.board,
    required this.curriculum,
    required this.address,
    required this.contactPhone,
    required this.contactEmail,
    required this.academicYear,
    required this.classes,
    required this.sections,
    required this.feeModel,
    required this.feeCategories,
    required this.logoUrl,
    required this.themePrimary,
    required this.themeSecondary,
    required this.brandingPreferences,
    required this.defaultLanguage,
    required this.modulesEnabled,
    required this.isLive,
    required this.lastSavedAt,
    this.goLiveValidationErrors = const [],
    this.isLoading = false,
    this.isHydrated = false,
    this.provisionSummary,
  });

  final UnifiedOnboardingStep currentStep;
  final String schoolName;
  final String board;
  final String curriculum;
  final String address;
  final String contactPhone;
  final String contactEmail;
  final String academicYear;
  final List<String> classes;
  final List<String> sections;
  final String feeModel;
  final List<String> feeCategories;
  final String logoUrl;
  final String themePrimary;
  final String themeSecondary;
  final Map<String, String> brandingPreferences;
  final String defaultLanguage;
  final List<String> modulesEnabled;
  final bool isLive;
  final DateTime? lastSavedAt;
  final List<String> goLiveValidationErrors;
  final bool isLoading;
  final bool isHydrated;
  final UnifiedOnboardingProvisionSummary? provisionSummary;

  factory UnifiedOnboardingState.initial() => const UnifiedOnboardingState(
        currentStep: UnifiedOnboardingStep.schoolProfile,
        schoolName: '',
        board: '',
        curriculum: 'CBSE',
        address: '',
        contactPhone: '',
        contactEmail: '',
        academicYear: '2026-27',
        classes: ['Grade 1', 'Grade 2', 'Grade 3'],
        sections: ['A', 'B'],
        feeModel: '',
        feeCategories: [],
        logoUrl: '',
        themePrimary: '#1565C0',
        themeSecondary: '#42A5F5',
        brandingPreferences: {},
        defaultLanguage: 'en',
        modulesEnabled: ['sis', 'finance', 'attendance'],
        isLive: false,
        lastSavedAt: null,
      );

  UnifiedOnboardingState copyWith({
    UnifiedOnboardingStep? currentStep,
    String? schoolName,
    String? board,
    String? curriculum,
    String? address,
    String? contactPhone,
    String? contactEmail,
    String? academicYear,
    List<String>? classes,
    List<String>? sections,
    String? feeModel,
    List<String>? feeCategories,
    String? logoUrl,
    String? themePrimary,
    String? themeSecondary,
    Map<String, String>? brandingPreferences,
    String? defaultLanguage,
    List<String>? modulesEnabled,
    bool? isLive,
    DateTime? lastSavedAt,
    List<String>? goLiveValidationErrors,
    bool? isLoading,
    bool? isHydrated,
    UnifiedOnboardingProvisionSummary? provisionSummary,
  }) {
    return UnifiedOnboardingState(
      currentStep: currentStep ?? this.currentStep,
      schoolName: schoolName ?? this.schoolName,
      board: board ?? this.board,
      curriculum: curriculum ?? this.curriculum,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      academicYear: academicYear ?? this.academicYear,
      classes: classes ?? this.classes,
      sections: sections ?? this.sections,
      feeModel: feeModel ?? this.feeModel,
      feeCategories: feeCategories ?? this.feeCategories,
      logoUrl: logoUrl ?? this.logoUrl,
      themePrimary: themePrimary ?? this.themePrimary,
      themeSecondary: themeSecondary ?? this.themeSecondary,
      brandingPreferences: brandingPreferences ?? this.brandingPreferences,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      modulesEnabled: modulesEnabled ?? this.modulesEnabled,
      isLive: isLive ?? this.isLive,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      goLiveValidationErrors: goLiveValidationErrors ?? this.goLiveValidationErrors,
      isLoading: isLoading ?? this.isLoading,
      isHydrated: isHydrated ?? this.isHydrated,
      provisionSummary: provisionSummary ?? this.provisionSummary,
    );
  }
}

/// Client-side go-live validation — mirrors server rules.
abstract final class UnifiedOnboardingValidation {
  static List<String> validateForGoLive(UnifiedOnboardingState state) {
    final errors = <String>[];
    if (state.schoolName.trim().isEmpty) errors.add('School name is required');
    if (state.board.trim().isEmpty && state.curriculum.trim().isEmpty) {
      errors.add('Board or curriculum is required');
    }
    if (state.address.trim().isEmpty) errors.add('School address is required');
    if (state.contactPhone.trim().isEmpty && state.contactEmail.trim().isEmpty) {
      errors.add('Contact phone or email is required');
    }
    if (state.academicYear.trim().isEmpty) errors.add('Academic year is required');
    if (state.classes.isEmpty) errors.add('At least one class is required');
    if (state.sections.isEmpty) errors.add('At least one section is required');
    if (state.feeModel.trim().isEmpty) errors.add('Fee model is required');
    if (state.feeCategories.isEmpty) {
      errors.add('At least one fee category is required');
    }
    if (state.defaultLanguage.trim().isEmpty) {
      errors.add('Default language is required');
    }
    if (state.themePrimary.trim().isEmpty) {
      errors.add('Primary theme colour is required');
    }
    return errors;
  }
}
