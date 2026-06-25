import 'package:akshara_erp/core/repositories/repository_config.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/predictions/predictions_models.dart';
import 'package:akshara_erp/features/predictions/predictions_providers.dart';
import 'package:akshara_erp/features/predictions/predictions_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the three prediction sections with AI narrative',
      (tester) async {
    const fee = PredictionFeed<FeeDefaultPrediction>(
      narrative: '2 record(s) analysed; 1 flagged at high fee-default risk.',
      items: [
        FeeDefaultPrediction(
          studentId: 's1', studentName: 'Asha', className: 'Grade 5',
          outstandingInr: 9000, billedInr: 10000, daysOverdue: 80,
          riskScore: 88, riskLevel: PredictionRiskLevel.critical,
        ),
      ],
    );
    const conv = PredictionFeed<AdmissionConversionPrediction>(
      narrative: '1 hot prospect.',
      items: [
        AdmissionConversionPrediction(
          leadId: 'l1', studentName: 'Meena', classLabel: 'Grade 1',
          source: 'website', stage: 'application', leadScore: 'hot',
          ageDays: 5, applicationStatus: 'under_review', likelihood: 90,
          band: ConversionBand.hot,
        ),
      ],
    );
    const risk = PredictionFeed<StudentRiskPrediction>(
      narrative: '1 flagged at high academic risk.',
      items: [
        StudentRiskPrediction(
          studentId: 's1', studentName: 'Asha', className: 'Grade 5',
          riskScore: 78, riskLevel: PredictionRiskLevel.high,
          topReason: 'Low attendance',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Gate open + all sections permitted.
          entitlementApiEnabledProvider.overrideWithValue(false),
          predictionsCanViewFeeDefaultProvider.overrideWithValue(true),
          predictionsCanViewConversionProvider.overrideWithValue(true),
          predictionsCanViewStudentRiskProvider.overrideWithValue(true),
          feeDefaultPredictionsProvider.overrideWith((ref) async => fee),
          admissionConversionPredictionsProvider.overrideWith((ref) async => conv),
          studentRiskPredictionsProvider.overrideWith((ref) async => risk),
        ],
        child: MaterialApp(
          theme: AksharaAppTheme.light(),
          home: const PredictionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(QaTestKeys.predictionsScreen), findsOneWidget);
    expect(find.byKey(QaTestKeys.predictionsFeeDefaultSection), findsOneWidget);
    expect(find.byKey(QaTestKeys.predictionsConversionSection), findsOneWidget);
    expect(find.byKey(QaTestKeys.predictionsStudentRiskSection), findsOneWidget);
    expect(find.text('Fee-default risk'), findsOneWidget);
    expect(find.text('Admission conversion likelihood'), findsOneWidget);
    expect(find.text('Student academic risk'), findsOneWidget);
    expect(find.textContaining('high fee-default risk'), findsOneWidget);
  });
}
