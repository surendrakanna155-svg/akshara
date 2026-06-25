import '../../../features/predictions/predictions_models.dart';
import '../interfaces/predictions_repository.dart';
import '../repository_query.dart';

/// Offline Advanced AI Predictions fixtures (used until the API is enabled or as
/// the hybrid fallback). Deterministic, no PII beyond illustrative names.
class MockPredictionsRepository implements PredictionsRepository {
  @override
  Future<PredictionFeed<FeeDefaultPrediction>> getFeeDefaultRisk({
    required RepositoryQuery query,
  }) async {
    return const PredictionFeed(
      narrative:
          '3 record(s) analysed; 1 flagged at high fee-default risk. Prioritise: Aarav Shah.',
      items: [
        FeeDefaultPrediction(
          studentId: 'st-1',
          studentName: 'Aarav Shah',
          className: 'Grade 5',
          outstandingInr: 18500,
          billedInr: 20000,
          daysOverdue: 62,
          riskScore: 88,
          riskLevel: PredictionRiskLevel.critical,
        ),
        FeeDefaultPrediction(
          studentId: 'st-2',
          studentName: 'Diya Menon',
          className: 'Grade 3',
          outstandingInr: 6000,
          billedInr: 20000,
          daysOverdue: 18,
          riskScore: 41,
          riskLevel: PredictionRiskLevel.medium,
        ),
        FeeDefaultPrediction(
          studentId: 'st-3',
          studentName: 'Ishaan Rao',
          className: 'Grade 7',
          outstandingInr: 1500,
          billedInr: 20000,
          daysOverdue: 4,
          riskScore: 14,
          riskLevel: PredictionRiskLevel.low,
        ),
      ],
    );
  }

  @override
  Future<PredictionFeed<AdmissionConversionPrediction>> getAdmissionConversion({
    required RepositoryQuery query,
  }) async {
    return const PredictionFeed(
      narrative:
          '3 lead(s) analysed; 1 hot prospect. Prioritise: Nila Krishnan.',
      items: [
        AdmissionConversionPrediction(
          leadId: 'ld-1',
          studentName: 'Nila Krishnan',
          classLabel: 'Grade 1',
          source: 'website',
          stage: 'application',
          leadScore: 'hot',
          ageDays: 4,
          applicationStatus: 'under_review',
          likelihood: 90,
          band: ConversionBand.hot,
        ),
        AdmissionConversionPrediction(
          leadId: 'ld-2',
          studentName: 'Vihaan Gupta',
          classLabel: 'Grade 1',
          source: 'referral',
          stage: 'contacted',
          leadScore: 'warm',
          ageDays: 12,
          applicationStatus: null,
          likelihood: 50,
          band: ConversionBand.warm,
        ),
        AdmissionConversionPrediction(
          leadId: 'ld-3',
          studentName: 'Anaya Iyer',
          classLabel: 'Grade 2',
          source: 'walkin',
          stage: 'new_enquiry',
          leadScore: 'cold',
          ageDays: 55,
          applicationStatus: null,
          likelihood: 20,
          band: ConversionBand.cool,
        ),
      ],
    );
  }

  @override
  Future<PredictionFeed<StudentRiskPrediction>> getStudentRisk({
    required RepositoryQuery query,
  }) async {
    return const PredictionFeed(
      narrative:
          '3 record(s) analysed; 1 flagged at high academic risk. Prioritise: Aarav Shah.',
      items: [
        StudentRiskPrediction(
          studentId: 'st-1',
          studentName: 'Aarav Shah',
          className: 'Grade 5',
          riskScore: 78,
          riskLevel: PredictionRiskLevel.high,
          topReason: 'Low attendance',
        ),
        StudentRiskPrediction(
          studentId: 'st-4',
          studentName: 'Sara Pillai',
          className: 'Grade 6',
          riskScore: 47,
          riskLevel: PredictionRiskLevel.medium,
          topReason: 'Homework completion gap',
        ),
        StudentRiskPrediction(
          studentId: 'st-2',
          studentName: 'Diya Menon',
          className: 'Grade 3',
          riskScore: 22,
          riskLevel: PredictionRiskLevel.low,
          topReason: 'Stable profile',
        ),
      ],
    );
  }
}
