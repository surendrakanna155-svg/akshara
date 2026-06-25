import '../../../../features/predictions/predictions_models.dart';
import '../../interfaces/predictions_repository.dart';
import '../../repository_query.dart';
import 'remote/predictions_remote_datasource.dart';

/// Live Advanced AI Predictions repository — parses the school-scoped prediction
/// feeds (items + AI narrative) from the backend into domain models.
class ApiPredictionsRepository implements PredictionsRepository {
  ApiPredictionsRepository({required PredictionsRemoteDataSource remote})
      : _remote = remote;

  final PredictionsRemoteDataSource _remote;

  static String _str(Object? v) => v?.toString() ?? '';

  static int _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static List<Map<String, dynamic>> _items(Map<String, dynamic> data) =>
      (data['items'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

  static String _narrative(Map<String, dynamic> data) =>
      _str(data['narrative']);

  static FeeDefaultPrediction _fee(Map<String, dynamic> m) => FeeDefaultPrediction(
        studentId: _str(m['studentId']),
        studentName: _str(m['studentName']),
        className: _str(m['className']),
        outstandingInr: _int(m['outstandingInr']),
        billedInr: _int(m['billedInr']),
        daysOverdue: _int(m['daysOverdue']),
        riskScore: _int(m['riskScore']),
        riskLevel: predictionRiskLevelFromString(m['riskLevel']),
      );

  static AdmissionConversionPrediction _conversion(Map<String, dynamic> m) =>
      AdmissionConversionPrediction(
        leadId: _str(m['leadId']),
        studentName: _str(m['studentName']),
        classLabel: _str(m['classLabel']),
        source: _str(m['source']),
        stage: _str(m['stage']),
        leadScore: _str(m['leadScore']),
        ageDays: _int(m['ageDays']),
        applicationStatus:
            m['applicationStatus'] == null ? null : _str(m['applicationStatus']),
        likelihood: _int(m['likelihood']),
        band: conversionBandFromString(m['band']),
      );

  static StudentRiskPrediction _risk(Map<String, dynamic> m) =>
      StudentRiskPrediction(
        studentId: _str(m['studentId']),
        studentName: _str(m['studentName']),
        className: _str(m['className']),
        riskScore: _int(m['riskScore']),
        riskLevel: predictionRiskLevelFromString(m['riskLevel']),
        topReason: _str(m['topReason']),
      );

  @override
  Future<PredictionFeed<FeeDefaultPrediction>> getFeeDefaultRisk({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchFeeDefault(query: query);
    return PredictionFeed(
      items: _items(data).map(_fee).toList(growable: false),
      narrative: _narrative(data),
    );
  }

  @override
  Future<PredictionFeed<AdmissionConversionPrediction>> getAdmissionConversion({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchAdmissionConversion(query: query);
    return PredictionFeed(
      items: _items(data).map(_conversion).toList(growable: false),
      narrative: _narrative(data),
    );
  }

  @override
  Future<PredictionFeed<StudentRiskPrediction>> getStudentRisk({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchStudentRisk(query: query);
    return PredictionFeed(
      items: _items(data).map(_risk).toList(growable: false),
      narrative: _narrative(data),
    );
  }
}
