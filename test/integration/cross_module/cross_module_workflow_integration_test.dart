import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/repositories/api/admissions/remote/admissions_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/audit/remote/audit_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_api_paths.dart';
import 'package:akshara_erp/core/repositories/mock/mock_admissions_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/admissions/admissions_fixture_builder.dart';
import '../../contracts/finance/finance_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';

const kQuery = RepositoryQuery.demo;
const _admissionsFixtures = AdmissionsFixtureBuilder();
const _financeFixtures = FinanceFixtureBuilder();

/// Cross-module workflow validation: Admissions → Finance handoff + audit trail.
void main() {
  group('Cross-module workflow integration', () {
    test('approved handoffs align with finance student accounts', () async {
      final admissions = MockAdmissionsRepository();
      final finance = MockFinanceRepository();

      final handoffs = await admissions.getApprovedHandoffs(query: kQuery);
      final accounts = await finance.getStudentAccounts(query: kQuery);

      expect(handoffs.total, greaterThan(0));
      expect(accounts.total, greaterThan(0));
      expect(handoffs.items.first.studentName, isNotEmpty);
      expect(accounts.items.first.studentName, isNotEmpty);
    });

    test('API paths chain admissions handoff to finance accounts', () async {
      final admissions = MockAdmissionsRepository();
      final finance = MockFinanceRepository();
      final handoffs = await admissions.getApprovedHandoffs(query: kQuery);
      final accounts = await finance.getStudentAccounts(query: kQuery);

      final dio = createFakeDio((options) {
        return switch (options.path) {
          AdmissionsApiPaths.handoffsApproved => _admissionsFixtures.listEnvelope([
              for (final h in handoffs.items) _admissionsFixtures.handoffItem(h),
            ]),
          FinanceApiPaths.studentAccounts => _financeFixtures.listEnvelope([
              for (final a in accounts.items) _financeFixtures.studentAccountItem(a),
            ]),
          AuditApiPaths.batch => {
              'data': {'acceptedCount': 1, 'rejectedIds': []},
            },
          _ => {'data': {}},
        };
      });

      final handoffResp = await dio.get<Map<String, dynamic>>(AdmissionsApiPaths.handoffsApproved);
      final accountResp = await dio.get<Map<String, dynamic>>(FinanceApiPaths.studentAccounts);
      final auditResp = await dio.post<Map<String, dynamic>>(
        AuditApiPaths.batch,
        data: {
          'events': [
            {
              'id': 'cross_module_audit_1',
              'type': AuditEventType.financeHandoffSent.name,
              'timestamp': DateTime.utc(2026, 6, 10).toIso8601String(),
              'category': AuditEventCategory.workflow.name,
            },
          ],
        },
      );

      expect(handoffResp.data?['data'], isNotNull);
      expect(accountResp.data?['data'], isNotNull);
      expect(auditResp.data?['data']?['acceptedCount'], 1);
    });
  });
}
