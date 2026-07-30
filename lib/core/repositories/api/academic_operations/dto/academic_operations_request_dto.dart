import '../../../../../features/sis/academic_operations/academic_operations_models.dart';

class YearTransitionPreviewRequestDto {
  const YearTransitionPreviewRequestDto({
    required this.sourceYearId,
    required this.targetYearId,
    required this.mappings,
  });

  factory YearTransitionPreviewRequestDto.fromDomain({
    required String sourceYearId,
    required String targetYearId,
    required List<ClassMappingRule> mappings,
  }) {
    return YearTransitionPreviewRequestDto(
      sourceYearId: sourceYearId,
      targetYearId: targetYearId,
      mappings: mappings
          .map((rule) => ClassMappingRuleDto.fromDomain(rule))
          .toList(growable: false),
    );
  }

  final String sourceYearId;
  final String targetYearId;
  final List<ClassMappingRuleDto> mappings;

  Map<String, dynamic> toJson() {
    // PRA-P0-14: backend `parseClassMappings` reads the array from `classMapping`
    // (a `mappings` key was silently ignored, so the wizard's choices never
    // reached the preview and the backend just re-suggested).
    return {
      'sourceYearId': sourceYearId,
      'targetYearId': targetYearId,
      'classMapping':
          mappings.map((rule) => rule.toJson()).toList(growable: false),
    };
  }
}

class ClassMappingRuleDto {
  const ClassMappingRuleDto({
    required this.sourceClassLabel,
    required this.sourceSection,
    required this.targetClassLabel,
    required this.targetSection,
    required this.includeStudents,
  });

  factory ClassMappingRuleDto.fromDomain(ClassMappingRule rule) {
    return ClassMappingRuleDto(
      sourceClassLabel: rule.sourceClassLabel,
      sourceSection: rule.sourceSection,
      targetClassLabel: rule.targetClassLabel,
      targetSection: rule.targetSection,
      includeStudents: rule.includeStudents,
    );
  }

  final String sourceClassLabel;
  final String sourceSection;
  final String targetClassLabel;
  final String targetSection;
  final bool includeStudents;

  Map<String, dynamic> toJson() {
    // PRA-P0-14: emit the backend contract (`sourceClassName / targetClassName /
    // keepSection / action`). The wizard's single `includeStudents` toggle maps
    // to the action: excluded => skip; an empty target (backend's graduate
    // suggestion for terminal grades) => graduate; otherwise promote.
    return {
      'sourceClassName': sourceClassLabel,
      'targetClassName': targetClassLabel,
      'keepSection': true,
      'action': !includeStudents
          ? 'skip'
          : (targetClassLabel.trim().isEmpty ? 'graduate' : 'promote'),
    };
  }
}
