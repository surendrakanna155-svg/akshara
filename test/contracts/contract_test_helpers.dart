import 'package:akshara_erp/core/repositories/repository_query.dart';

const kContractQuery = RepositoryQuery.demo;

/// Builds KPI JSON from mock dashboard labels for contract parity checks.
Map<String, dynamic> kpiJson({
  required String id,
  required String value,
  required String label,
  String accentName = 'primary',
  String? detail,
}) {
  return {
    'id': id,
    'value': value,
    'label': label,
    'accentName': accentName,
    if (detail != null) 'detail': detail,
  };
}
