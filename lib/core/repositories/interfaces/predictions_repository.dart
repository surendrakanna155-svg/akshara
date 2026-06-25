import '../../../features/predictions/predictions_models.dart';
import '../repository_query.dart';

/// Advanced AI Predictions (B9). Three school-scoped, read-only prediction feeds,
/// each grounded in real operational data with an optional AI narrative.
abstract class PredictionsRepository {
  Future<PredictionFeed<FeeDefaultPrediction>> getFeeDefaultRisk({
    required RepositoryQuery query,
  });

  Future<PredictionFeed<AdmissionConversionPrediction>> getAdmissionConversion({
    required RepositoryQuery query,
  });

  Future<PredictionFeed<StudentRiskPrediction>> getStudentRisk({
    required RepositoryQuery query,
  });
}
