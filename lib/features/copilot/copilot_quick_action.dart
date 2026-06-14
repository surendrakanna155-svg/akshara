import 'copilot_role_intelligence.dart';

/// Long-press quick actions on AI entry points (INTEL-05).
enum CopilotQuickAction {
  explainScreen('Explain this screen'),
  summarizeKpis('Summarize KPIs'),
  showAlerts('Show alerts'),
  showRisks('Show risks'),
  suggestedActions('Suggested actions'),
  openFullCopilot('Open full copilot');

  const CopilotQuickAction(this.label);

  final String label;

  String promptForPersona(CopilotPersonaRole persona) => switch (this) {
        CopilotQuickAction.explainScreen =>
          'Explain what I can do on this ${persona.label} screen.',
        CopilotQuickAction.summarizeKpis =>
          'Summarize the KPIs visible on this screen.',
        CopilotQuickAction.showAlerts =>
          'What alerts should I know about right now?',
        CopilotQuickAction.showRisks =>
          'What risks are flagged for my scope?',
        CopilotQuickAction.suggestedActions =>
          'What actions do you suggest I take next?',
        CopilotQuickAction.openFullCopilot => '',
      };
}
