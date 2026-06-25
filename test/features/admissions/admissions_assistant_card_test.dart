import 'package:akshara_erp/features/admissions/admissions_models.dart';
import 'package:akshara_erp/features/admissions/dashboard/admissions_intelligence_provider.dart';
import 'package:akshara_erp/features/admissions/dashboard/widgets/admissions_assistant_card.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _funnel = AdmissionsFunnelSummary(
  totalLeads: 248,
  hotLeads: 34,
  conversionRate: 14.5,
  pendingFollowUps: 12,
  unassignedLeads: 7,
  stageCounts: {'new_enquiry': 28, 'contacted': 45},
  topSource: 'website',
  topSourceCount: 96,
);

Future<void> _pump(
  WidgetTester tester,
  AdmissionsIntelligenceData? data,
) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        admissionsIntelligenceProvider.overrideWithValue(data),
      ],
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: AdmissionsAssistantCard()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('AdmissionsAssistantCard', () {
    testWidgets('renders next best actions and funnel chips', (tester) async {
      await _pump(
        tester,
        const AdmissionsIntelligenceData(
          funnel: _funnel,
          nextBestActions: [
            AdmissionsNextBestAction(
              id: 'urgent_hot_lead:1',
              kind: 'stalled_hot_lead',
              priority: AdmissionsActionPriority.urgent,
              title: 'Hot lead cooling: Ananya',
              detail: 'Reach out today.',
              cta: 'Call now',
              leadId: '1',
            ),
            AdmissionsNextBestAction(
              id: 'pending_follow_ups',
              kind: 'pending_follow_ups',
              priority: AdmissionsActionPriority.high,
              title: '12 follow-ups pending',
              detail: 'Clear them today.',
              cta: 'Review follow-ups',
              count: 12,
            ),
          ],
        ),
      );

      expect(find.text('AI Admissions Assistant'), findsOneWidget);
      expect(find.text('Hot lead cooling: Ananya'), findsOneWidget);
      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('Call now'), findsOneWidget);
      expect(find.text('248 leads'), findsOneWidget);
    });

    testWidgets('shows all-caught-up when no actions', (tester) async {
      await _pump(
        tester,
        const AdmissionsIntelligenceData(
          funnel: _funnel,
          nextBestActions: [],
        ),
      );
      expect(
        find.textContaining('all caught up'),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing while loading (null)', (tester) async {
      await _pump(tester, null);
      expect(find.text('AI Admissions Assistant'), findsNothing);
    });
  });
}
