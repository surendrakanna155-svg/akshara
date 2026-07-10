abstract final class CopilotApiPaths {
  static const String assistants = '/copilot/assistants';
  static const String suggestions = '/copilot/suggestions';
  static const String economics = '/copilot/economics';
  static const String sessions = '/copilot/sessions';
  static String session(String id) => '$sessions/$id';
  static String messages(String sessionId) => '$sessions/$sessionId/messages';
}
