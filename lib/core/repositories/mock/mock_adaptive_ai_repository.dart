// Adaptive AI (P3-AI-2 / W2) — in-memory mock. Deterministic canned data so the
// Adaptive AI surfaces render before the backend flag (ADAPTIVE_AI_API_ENABLED)
// is turned on, mirroring how the other Mock repositories seed realistic data.

import '../../../features/adaptive_ai/adaptive_ai_models.dart';
import '../interfaces/adaptive_ai_repository.dart';
import '../repository_query.dart';

class MockAdaptiveAiRepository implements AdaptiveAiRepository {
  final Set<String> _dismissed = {};

  @override
  Future<AdaptiveFeed> getPriorityFeed({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) async {
    final items = _seedItems(persona, withActions: false)
        .where((i) => !_dismissed.contains(i.itemKey))
        .toList();
    return AdaptiveFeed(
      persona: persona,
      items: limit == null ? items : items.take(limit).toList(),
      criticalCount: items.where((i) => i.isCritical).length,
    );
  }

  @override
  Future<AdaptiveFeed> getRecommendations({
    required RepositoryQuery query,
    required String persona,
    int? limit,
  }) async {
    final items = _seedItems(persona, withActions: true)
        .where((i) => !_dismissed.contains(i.itemKey))
        .toList();
    return AdaptiveFeed(
      persona: persona,
      items: limit == null ? items : items.take(limit).toList(),
      criticalCount: items.where((i) => i.isCritical).length,
    );
  }

  @override
  Future<void> sendRecommendationFeedback({
    required RepositoryQuery query,
    required String itemKey,
    required String itemType,
    required AdaptiveFeedbackAction action,
  }) async {
    if (action == AdaptiveFeedbackAction.accept) {
      _dismissed.remove(itemKey);
    } else {
      _dismissed.add(itemKey);
    }
  }

  @override
  Future<List<AdaptiveQuickAction>> getQuickActions({
    required RepositoryQuery query,
    required String persona,
  }) async {
    switch (persona) {
      case 'parent':
        return const [
          AdaptiveQuickAction(
            id: 'parent_homework_summary',
            label: 'Homework summary',
            tier: 't1',
            resolver: QuickActionResolver(kind: 'endpoint', target: '/parent/homework/summary'),
          ),
          AdaptiveQuickAction(
            id: 'parent_fee_reminder_explanation',
            label: 'Explain fee due',
            tier: 't1',
            resolver: QuickActionResolver(kind: 'endpoint', target: '/parent/fees/summary'),
          ),
        ];
      case 'teacher':
        return const [
          AdaptiveQuickAction(
            id: 'teacher_class_attendance_summary',
            label: 'Attendance summary',
            tier: 't1',
            resolver: QuickActionResolver(kind: 'endpoint', target: '/analytics/dashboard'),
          ),
          AdaptiveQuickAction(
            id: 'teacher_weak_chapters',
            label: 'Show weak chapters',
            tier: 't1',
            resolver: QuickActionResolver(kind: 'endpoint', target: '/intelligence/exam/weak-chapters'),
          ),
        ];
      default:
        return const [
          AdaptiveQuickAction(
            id: 'principal_today_priorities',
            label: "Today's priorities",
            tier: 't1',
            resolver: QuickActionResolver(
              kind: 'endpoint',
              target: '/intelligence/priorities?persona=principal',
            ),
          ),
          AdaptiveQuickAction(
            id: 'principal_high_risk_students',
            label: 'High-risk students',
            tier: 't1',
            resolver: QuickActionResolver(
              kind: 'endpoint',
              target: '/intelligence/risk/students?riskLevel=high',
            ),
          ),
          AdaptiveQuickAction(
            id: 'principal_school_health',
            label: 'School health summary',
            tier: 't1',
            resolver: QuickActionResolver(kind: 'endpoint', target: '/intelligence/principal/center'),
          ),
        ];
    }
  }

  @override
  Future<UniversalSearchResult> universalSearch({
    required RepositoryQuery query,
    required String term,
    int? limit,
  }) async {
    if (term.trim().length < 2) return UniversalSearchResult.empty(term);
    return UniversalSearchResult(
      query: term,
      groups: const [
        SearchGroup(
          category: 'students',
          label: 'Students',
          total: 2,
          results: [
            SearchResultItem(
              category: 'students',
              id: 'stu-1',
              title: 'Ramesh Kumar',
              subtitle: 'Class 6-B · Roll 12 · Adm# 2024-101',
              deepLink: '/students/stu-1',
            ),
            SearchResultItem(
              category: 'students',
              id: 'stu-2',
              title: 'Ramesh Iyer',
              subtitle: 'Class 8-A · Roll 4 · Adm# 2022-058',
              deepLink: '/students/stu-2',
            ),
          ],
        ),
      ],
    );
  }

  List<AdaptivePriorityItem> _seedItems(String persona, {required bool withActions}) {
    AdaptiveAction? act(String label, String deepLink, [Map<String, dynamic> payload = const {}]) =>
        withActions ? AdaptiveAction(label: label, deepLink: deepLink, payload: payload) : null;

    return [
      AdaptivePriorityItem(
        itemKey: 'fee:collection',
        type: 'follow_up',
        title: 'Fee collection pressure elevated',
        detail: 'Open-invoice pressure is at 72/100. Review the defaulter list and cadence.',
        score: 61,
        reason: 'elevated priority',
        action: act('Open recovery call queue', '/finance/recovery/call-queue'),
      ),
      AdaptivePriorityItem(
        itemKey: 'risk:student:stu-1',
        type: 'exception',
        title: 'At-risk student in 6-B',
        detail: 'Risk score 88/100 (critical). Review interventions — no automated action taken.',
        score: 82,
        reason: 'critical severity',
        action: act('Review student risk', '/intelligence/risk/students/stu-1', {'studentId': 'stu-1'}),
      ),
      AdaptivePriorityItem(
        itemKey: 'ops:timetable',
        type: 'exception',
        title: 'Review timetable conflicts',
        detail: 'Timetable health is 64/100 (below target). Run the conflict review before publish.',
        score: 34,
        reason: 'elevated priority',
        action: act('Review timetable conflicts', '/timetable/conflicts'),
      ),
    ];
  }
}
