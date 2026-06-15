import '../../../features/copilot/copilot_models.dart';
import '../../../features/copilot/copilot_screen_context.dart';
import '../../../features/copilot/copilot_stub_responses.dart';
import '../../ai/ai_inference_models.dart';
import '../../ai/ai_inference_pipeline.dart';
import '../interfaces/copilot_repository.dart';
import '../repository_query.dart';

class MockCopilotRepository implements CopilotRepository {
  MockCopilotRepository({AiInferencePipeline? pipeline}) : _pipeline = pipeline {
    _sessions.addAll([
      CopilotSession(
        id: 'copilot_session_1',
        assistantType: CopilotAssistantType.finance,
        title: 'Summarize collections and defaulters',
        status: 'active',
        createdAt: DateTime(2026, 6, 8, 10, 30),
        updatedAt: DateTime(2026, 6, 8, 10, 35),
      ),
      CopilotSession(
        id: 'copilot_session_2',
        assistantType: CopilotAssistantType.admissions,
        title: 'Admissions funnel this month',
        status: 'active',
        createdAt: DateTime(2026, 6, 7, 15, 0),
        updatedAt: DateTime(2026, 6, 7, 15, 5),
      ),
    ]);
    _messages['copilot_session_1'] = [
      CopilotMessage(
        id: 'msg_1',
        sessionId: 'copilot_session_1',
        role: 'user',
        content: 'Summarize collections and defaulters',
        createdAt: DateTime(2026, 6, 8, 10, 30),
      ),
      CopilotMessage(
        id: 'msg_2',
        sessionId: 'copilot_session_1',
        role: 'assistant',
        content:
            'Finance snapshot (read-only):\n- Completed collections: 128\n- Open AP commitments: 1 (₹12,500.00)\n- Defaulters remain elevated in Grade 9.',
        createdAt: DateTime(2026, 6, 8, 10, 31),
        metadata: const {'model': 'akshara-stub', 'stub': true},
      ),
    ];
  }

  final List<CopilotSession> _sessions = [];
  final Map<String, List<CopilotMessage>> _messages = {};
  final AiInferencePipeline? _pipeline;

  static const _assistants = [
    CopilotAssistant(
      type: CopilotAssistantType.admissions,
      label: 'Admissions Assistant',
      description: 'Summarize funnel metrics and explain admissions stages.',
      skills: ['summarize', 'explain', 'search', 'report', 'operational_qa'],
    ),
    CopilotAssistant(
      type: CopilotAssistantType.finance,
      label: 'Finance Assistant',
      description: 'Collections, defaulters, and inventory-finance reconciliation.',
      skills: ['summarize', 'explain', 'search', 'report', 'operational_qa'],
    ),
    CopilotAssistant(
      type: CopilotAssistantType.sis,
      label: 'SIS Assistant',
      description: 'Student registry and enrollment insights.',
      skills: ['summarize', 'explain', 'search', 'report', 'operational_qa'],
    ),
    CopilotAssistant(
      type: CopilotAssistantType.academic,
      label: 'Academic Assistant',
      description: 'Academic catalog and teacher assignment guidance.',
      skills: ['summarize', 'explain', 'search', 'report', 'operational_qa'],
    ),
    CopilotAssistant(
      type: CopilotAssistantType.communication,
      label: 'Communication Assistant',
      description: 'Templates, broadcasts, and delivery metrics (read-only).',
      skills: ['summarize', 'explain', 'search', 'report', 'operational_qa'],
    ),
    CopilotAssistant(
      type: CopilotAssistantType.parentGuidance,
      label: 'Parent Guidance Assistant',
      description: 'Staff guidance for parent FAQs and communication tone.',
      skills: ['parent_faq', 'draft_guidance', 'explain', 'operational_qa'],
    ),
    CopilotAssistant(
      type: CopilotAssistantType.teacher,
      label: 'Teacher Copilot',
      description: 'Class attendance, homework, and timetable guidance.',
      skills: ['attendance', 'timetable', 'class_insights', 'operational_qa'],
    ),
    CopilotAssistant(
      type: CopilotAssistantType.principal,
      label: 'Principal Copilot',
      description: 'School health, risks, and executive briefings.',
      skills: ['executive_summary', 'risk_briefing', 'health_score', 'operational_qa'],
    ),
  ];

  static const _suggestions = {
    CopilotAssistantType.admissions: [
      'Summarize the admissions funnel this month',
      'Explain pending application stages',
      'Which leads need follow-up?',
    ],
    CopilotAssistantType.finance: [
      'Summarize collections and defaulters',
      'Explain open AP commitments from inventory',
      'Generate a finance operations snapshot',
    ],
    CopilotAssistantType.sis: [
      'How many active student enrollments do we have?',
      'Summarize recent enrollment changes',
    ],
    CopilotAssistantType.academic: [
      'Summarize the academic catalog for this year',
      'Which sections lack teacher assignments?',
    ],
    CopilotAssistantType.communication: [
      'Summarize notification templates available',
      'Explain broadcast delivery metrics',
    ],
    CopilotAssistantType.parentGuidance: [
      'How should I explain a fee balance to a parent?',
      'Draft a polite absence follow-up message',
    ],
    CopilotAssistantType.teacher: [
      'Which students need attendance follow-up?',
      'Summarize homework completion for my class',
    ],
    CopilotAssistantType.principal: [
      'Summarize school health for this week',
      'Which at-risk students need attention?',
    ],
  };

  @override
  Future<List<CopilotAssistant>> getAssistants({required RepositoryQuery query}) async {
    return _assistants;
  }

  @override
  Future<CopilotSuggestions> getSuggestions({
    required RepositoryQuery query,
    required CopilotAssistantType assistantType,
  }) async {
    return CopilotSuggestions(
      assistantType: assistantType,
      prompts: _suggestions[assistantType] ?? const [],
    );
  }

  @override
  Future<List<CopilotSession>> getSessions({required RepositoryQuery query}) async {
    return List<CopilotSession>.from(_sessions)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<CopilotSession> createSession({
    required RepositoryQuery query,
    required CopilotAssistantType assistantType,
    String? title,
  }) async {
    final session = CopilotSession(
      id: 'copilot_session_${_sessions.length + 1}',
      assistantType: assistantType,
      title: title ?? 'New conversation',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _sessions.insert(0, session);
    _messages[session.id] = [];
    return session;
  }

  @override
  Future<CopilotSessionDetail> getSession({
    required RepositoryQuery query,
    required String sessionId,
  }) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    return CopilotSessionDetail(
      session: session,
      messages: List<CopilotMessage>.from(_messages[sessionId] ?? const []),
    );
  }

  @override
  Future<CopilotSendMessageResult> sendMessage({
    required RepositoryQuery query,
    required String sessionId,
    required String content,
    CopilotScreenContext? screenContext,
  }) async {
    final now = DateTime.now();
    final reply = await _resolveReply(content, screenContext);
    final userMessage = CopilotMessage(
      id: 'msg_user_$now',
      sessionId: sessionId,
      role: 'user',
      content: content,
      createdAt: now,
      metadata: screenContext == null ? const {} : {'screenContext': screenContext.toJson()},
    );
    final assistantMessage = CopilotMessage(
      id: 'msg_assistant_$now',
      sessionId: sessionId,
      role: 'assistant',
      content: reply,
      createdAt: now.add(const Duration(seconds: 1)),
      metadata: {
        'model': _pipeline != null ? 'akshara-inference' : 'akshara-stub',
        'stub': _pipeline == null,
        'contextAware': true,
      },
    );
    _messages.putIfAbsent(sessionId, () => []).addAll([userMessage, assistantMessage]);
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index >= 0) {
      _sessions[index] = CopilotSession(
        id: _sessions[index].id,
        assistantType: _sessions[index].assistantType,
        title: _sessions[index].title == 'New conversation'
            ? content.trim().split('\n').first
            : _sessions[index].title,
        status: _sessions[index].status,
        createdAt: _sessions[index].createdAt,
        updatedAt: now,
      );
    }
    return CopilotSendMessageResult(
      userMessage: userMessage,
      assistantMessage: assistantMessage,
      model: _pipeline != null ? 'akshara-inference' : 'akshara-stub',
      stub: _pipeline == null,
    );
  }

  Future<String> _resolveReply(
    String content,
    CopilotScreenContext? screenContext,
  ) async {
    final pipeline = _pipeline;
    if (pipeline == null) {
      return buildContextAwareStubReply(
        userMessage: content,
        screenContext: screenContext,
      );
    }
    final response = await pipeline.complete(
      AiInferenceRequest(
        prompt: content,
        taskType: aiTaskTypeName(AiInferenceTaskType.copilotChat),
        systemPrompt: 'Akshara ERP copilot assistant',
        context: screenContext?.toJson() ?? const {},
      ),
    );
    return response.content;
  }
}
