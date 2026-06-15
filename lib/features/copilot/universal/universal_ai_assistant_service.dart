import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/erp_role.dart';
import '../copilot_models.dart';
import '../copilot_role_intelligence.dart';
import '../copilot_screen_context.dart';

enum UniversalAiAssistantRole {
  owner,
  director,
  principal,
  teacher,
  parent,
  student,
  finance,
  hr,
}

class UniversalAiAssistantProfile {
  const UniversalAiAssistantProfile({
    required this.role,
    required this.persona,
    required this.assistantType,
    required this.systemPromptSpecialization,
  });

  final UniversalAiAssistantRole role;
  final CopilotPersonaRole persona;
  final CopilotAssistantType assistantType;
  final String systemPromptSpecialization;
}

class UniversalAiAssistantService {
  const UniversalAiAssistantService();

  UniversalAiAssistantProfile resolveRole(UniversalAiAssistantRole role) {
    return switch (role) {
      UniversalAiAssistantRole.owner => const UniversalAiAssistantProfile(
          role: UniversalAiAssistantRole.owner,
          persona: CopilotPersonaRole.organizationOwner,
          assistantType: CopilotAssistantType.principal,
          systemPromptSpecialization:
              'Give concise executive summaries across school performance, growth, and governance.',
        ),
      UniversalAiAssistantRole.director => const UniversalAiAssistantProfile(
          role: UniversalAiAssistantRole.director,
          persona: CopilotPersonaRole.directorCorrespondent,
          assistantType: CopilotAssistantType.principal,
          systemPromptSpecialization:
              'Prioritize operations, admissions, and fee outcomes with actionable next steps.',
        ),
      UniversalAiAssistantRole.principal => const UniversalAiAssistantProfile(
          role: UniversalAiAssistantRole.principal,
          persona: CopilotPersonaRole.principal,
          assistantType: CopilotAssistantType.principal,
          systemPromptSpecialization:
              'Focus on academics, attendance, and student-risk interventions at class level.',
        ),
      UniversalAiAssistantRole.teacher => const UniversalAiAssistantProfile(
          role: UniversalAiAssistantRole.teacher,
          persona: CopilotPersonaRole.teacher,
          assistantType: CopilotAssistantType.teacher,
          systemPromptSpecialization:
              'Support daily teaching execution, weak learner support, and class follow-ups.',
        ),
      UniversalAiAssistantRole.parent => const UniversalAiAssistantProfile(
          role: UniversalAiAssistantRole.parent,
          persona: CopilotPersonaRole.parent,
          assistantType: CopilotAssistantType.parentGuidance,
          systemPromptSpecialization:
              'Keep guidance family-friendly and student-specific with clear follow-up advice.',
        ),
      UniversalAiAssistantRole.student => const UniversalAiAssistantProfile(
          role: UniversalAiAssistantRole.student,
          persona: CopilotPersonaRole.student,
          assistantType: CopilotAssistantType.academic,
          systemPromptSpecialization:
              'Provide practical study plans and revision priorities based on upcoming assessments.',
        ),
      UniversalAiAssistantRole.finance => const UniversalAiAssistantProfile(
          role: UniversalAiAssistantRole.finance,
          persona: CopilotPersonaRole.finance,
          assistantType: CopilotAssistantType.finance,
          systemPromptSpecialization:
              'Focus on collection efficiency, defaulter prevention, and reconciliation quality.',
        ),
      UniversalAiAssistantRole.hr => const UniversalAiAssistantProfile(
          role: UniversalAiAssistantRole.hr,
          persona: CopilotPersonaRole.hr,
          assistantType: CopilotAssistantType.communication,
          systemPromptSpecialization:
              'Focus on workforce readiness, leave discipline, and payroll risk mitigation.',
        ),
    };
  }

  UniversalAiAssistantProfile resolveFromErpRole(ErpRole role) {
    return resolveRole(
        _universalRoleFromPersona(copilotPersonaForErpRole(role)));
  }

  UniversalAiAssistantProfile resolveFromScreenContext(
      CopilotScreenContext? context) {
    final persona = context?.personaRole;
    if (persona != null) {
      return resolveRole(_universalRoleFromPersona(persona));
    }
    if (context != null) {
      return resolveFromErpRole(context.erpRole);
    }
    return resolveRole(UniversalAiAssistantRole.director);
  }

  String buildSystemPrompt({
    required UniversalAiAssistantProfile profile,
    CopilotScreenContext? screenContext,
  }) {
    final focus = profile.persona.intelligenceFocus.join(', ');
    final screen = screenContext?.screen ?? 'AI Assistant';
    final module = screenContext?.module ?? 'general';
    return 'You are Akshara ERP Universal AI Assistant for ${profile.persona.label}. '
        '${profile.systemPromptSpecialization} '
        'Current screen: $screen. '
        'Module: $module. '
        'Keep responses role-appropriate, concise, and action-oriented. '
        'Primary focus areas: $focus.';
  }

  UniversalAiAssistantRole _universalRoleFromPersona(
      CopilotPersonaRole persona) {
    return switch (persona) {
      CopilotPersonaRole.platformOwner ||
      CopilotPersonaRole.organizationOwner =>
        UniversalAiAssistantRole.owner,
      CopilotPersonaRole.directorCorrespondent =>
        UniversalAiAssistantRole.director,
      CopilotPersonaRole.principal => UniversalAiAssistantRole.principal,
      CopilotPersonaRole.academicCoordinator ||
      CopilotPersonaRole.teacher =>
        UniversalAiAssistantRole.teacher,
      CopilotPersonaRole.parent => UniversalAiAssistantRole.parent,
      CopilotPersonaRole.student => UniversalAiAssistantRole.student,
      CopilotPersonaRole.finance => UniversalAiAssistantRole.finance,
      CopilotPersonaRole.hr => UniversalAiAssistantRole.hr,
    };
  }
}

final universalAiAssistantServiceProvider =
    Provider<UniversalAiAssistantService>((ref) {
  return const UniversalAiAssistantService();
});
