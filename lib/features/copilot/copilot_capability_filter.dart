import '../../core/school_config/school_capability_registry.dart';
import '../../core/school_config/school_configuration_models.dart';

/// Maps copilot user prompts and screen modules to capability gates.
abstract final class CopilotCapabilityFilter {
  static const _topicKeywords = <String, List<String>>{
    'transport': ['transport', 'bus', 'route', 'fleet'],
    'hostel': ['hostel', 'residential', 'warden', 'dorm'],
    'library': ['library', 'book', 'circulation'],
    'inventory': ['inventory', 'procurement', 'asset', 'stock'],
    'alumni': ['alumni', 'graduate'],
    'payroll': ['payroll', 'salary', 'compensation'],
  };

  static String? disabledTopicMessage({
    required String userMessage,
    required SchoolCapabilities capabilities,
    String? module,
    SchoolCapabilities? planCeiling,
  }) {
    final lower = userMessage.toLowerCase();
    final moduleLower = module?.toLowerCase() ?? '';

    for (final entry in _topicKeywords.entries) {
      final topic = entry.key;
      final keywords = entry.value;
      final mentioned =
          keywords.any(lower.contains) || moduleLower.contains(topic);
      if (!mentioned) continue;
      if (!SchoolCapabilityRegistry.isCopilotTopicEnabled(topic, capabilities)) {
        final label = topic.replaceAll('_', ' ');
        // Plan-locked (ceiling off) → upgrade; school-disabled → enable in config.
        final planLocked = planCeiling != null &&
            !SchoolCapabilityRegistry.isCopilotTopicEnabled(topic, planCeiling);
        if (planLocked) {
          return '**$label is not included in your current plan**\n\n'
              'Copilot cannot help with $label until it is unlocked. Open '
              '**Plan & Entitlements** to upgrade — no payment is taken in the app.';
        }
        return '**$label module is disabled for this school**\n\n'
            'Copilot cannot provide operational guidance on $label while the '
            'capability flag is off. Enable it in school configuration or '
            'ask about an enabled module instead.';
      }
    }
    return null;
  }
}
