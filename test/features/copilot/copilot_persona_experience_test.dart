import 'package:akshara_erp/features/copilot/copilot_role_intelligence.dart';
import 'package:akshara_erp/features/copilot/persona/copilot_persona_experience.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CopilotPersonaExperience', () {
    test('defines experience for all configured personas', () {
      for (final persona in CopilotPersonaRole.values) {
        final experience = CopilotPersonaExperience.forPersona(persona);
        expect(experience.persona, persona);
        expect(experience.title, isNotEmpty);
        expect(experience.subtitle, isNotEmpty);
        expect(experience.focusAreas, isNotEmpty);
        expect(experience.starterPrompts, isNotEmpty);
      }
    });

    test('platform owner focuses on multi-school analytics', () {
      final experience = CopilotPersonaExperience.forPersona(
        CopilotPersonaRole.platformOwner,
      );
      expect(
        experience.focusAreas,
        contains('Multi-school analytics'),
      );
      expect(experience.focusAreas, contains('Risk detection'));
    });

    test('teacher focuses on class insights', () {
      final experience = CopilotPersonaExperience.forPersona(
        CopilotPersonaRole.teacher,
      );
      expect(experience.focusAreas, contains('Weak students'));
      expect(experience.focusAreas, contains('Homework completion'));
    });

    test('parent focuses on child performance', () {
      final experience = CopilotPersonaExperience.forPersona(
        CopilotPersonaRole.parent,
      );
      expect(experience.focusAreas, contains('Child performance'));
      expect(experience.focusAreas, contains('Upcoming exams'));
    });

    test('student focuses on study guidance', () {
      final experience = CopilotPersonaExperience.forPersona(
        CopilotPersonaRole.student,
      );
      expect(experience.focusAreas, contains('Study recommendations'));
      expect(experience.focusAreas, contains('Exam preparation'));
    });

    test('finance and hr personas include operational focus areas', () {
      final finance =
          CopilotPersonaExperience.forPersona(CopilotPersonaRole.finance);
      final hr = CopilotPersonaExperience.forPersona(CopilotPersonaRole.hr);

      expect(finance.focusAreas, contains('Fee collection trends'));
      expect(finance.starterPrompts, isNotEmpty);
      expect(hr.focusAreas, contains('Payroll readiness'));
      expect(hr.starterPrompts, isNotEmpty);
    });
  });
}
