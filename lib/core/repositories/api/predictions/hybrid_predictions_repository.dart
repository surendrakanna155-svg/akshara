import '../../../../features/predictions/predictions_models.dart';
import '../../interfaces/predictions_repository.dart';
import '../../mock/mock_predictions_repository.dart';
import '../../repository_query.dart';
import '../hybrid_write_fallback.dart';
import 'api_predictions_repository.dart';

/// API reads with mock fallback when the API is disconnected.
class HybridPredictionsRepository implements PredictionsRepository {
  HybridPredictionsRepository({
    required ApiPredictionsRepository api,
    required MockPredictionsRepository mock,
  })  : _api = api,
        _mock = mock;

  final ApiPredictionsRepository _api;
  final MockPredictionsRepository _mock;

  @override
  Future<PredictionFeed<FeeDefaultPrediction>> getFeeDefaultRisk({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getFeeDefaultRisk(query: query),
        mockCall: () => _mock.getFeeDefaultRisk(query: query),
      );

  @override
  Future<PredictionFeed<AdmissionConversionPrediction>> getAdmissionConversion({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getAdmissionConversion(query: query),
        mockCall: () => _mock.getAdmissionConversion(query: query),
      );

  @override
  Future<PredictionFeed<StudentRiskPrediction>> getStudentRisk({
    required RepositoryQuery query,
  }) =>
      withMockWriteFallback(
        apiCall: () => _api.getStudentRisk(query: query),
        mockCall: () => _mock.getStudentRisk(query: query),
      );
}
