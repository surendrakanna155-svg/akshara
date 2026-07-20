// STEP-5 — route-contract tests for the P0 money-honesty fix (PRC-A cap 71):
// the client's fee-reduction (scholarship award / discount application)
// methods must hit the exact certified backend paths
// (`finance_fee_reductions_{repository,handlers}.ts`, routed in
// `finance_router.ts:428-451`) with the correct body shape, and the response
// must map back into the domain `FeeReduction` model. Mirrors the idiom in
// `test/integration/finance/finance_api_integration_test.dart`.

import 'package:akshara_erp/core/repositories/api/finance/api_finance_repository.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_finance_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:akshara_erp/features/finance/finance_mutations_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../contracts/finance/finance_fixture_builder.dart';
import '../../helpers/fake_dio_interceptor.dart';
import '../../helpers/provider_test_overrides.dart';

const _kQuery = RepositoryQuery.demo;
const _fixtures = FinanceFixtureBuilder();

void main() {
  group('Fee reductions API route contract', () {
    late FeeReduction pendingScholarshipAward;
    late FeeReduction pendingDiscountApplication;
    late FeeReduction approvedReduction;

    setUpAll(() async {
      await initProviderTestPrefs();
    });

    setUp(() async {
      final mockRepo = MockFinanceRepository();
      pendingScholarshipAward = await mockRepo.proposeScholarshipAward(
        query: _kQuery,
        scholarshipId: 'sch_1',
        invoiceId: 'inv_1',
        reason: 'Merit scholarship',
        percent: 10,
      );
      pendingDiscountApplication = await mockRepo.proposeDiscountApplication(
        query: _kQuery,
        discountRuleId: 'rule_1',
        invoiceId: 'inv_4',
        reason: 'Early bird payment',
        amount: 5000,
      );
      approvedReduction = await mockRepo.approveFeeReduction(
        query: _kQuery,
        reductionId: pendingScholarshipAward.id,
      );
    });

    test('proposeScholarshipAward posts to scholarship-awards with the '
        'correct body and maps a pending reduction', () async {
      Map<String, dynamic>? capturedBody;
      final dio = createFakeDio((options) {
        if (options.path == FinanceApiPaths.feeReductionScholarshipAwards &&
            options.method == 'POST') {
          capturedBody = options.data as Map<String, dynamic>;
          return _fixtures.envelope(
            _fixtures.feeReductionItem(pendingScholarshipAward),
          );
        }
        return {'data': {}};
      });
      final remote = FinanceRemoteDataSource(dio);

      final result = await remote.proposeScholarshipAward(
        query: _kQuery,
        scholarshipId: 'sch_1',
        invoiceId: 'inv_1',
        reason: 'Merit scholarship',
        percent: 10,
      );

      expect(capturedBody, {
        'scholarshipId': 'sch_1',
        'invoiceId': 'inv_1',
        'reason': 'Merit scholarship',
        'percent': 10,
      });
      expect(result.sourceKind, FeeReductionSourceKind.scholarship);
      expect(result.invoiceId, 'inv_1');
      expect(result.status, FeeReductionStatus.pending);
      expect(result.appliedAmount, '0');
    });

    test('proposeDiscountApplication posts to discount-applications with a '
        'fixed amount body', () async {
      Map<String, dynamic>? capturedBody;
      final dio = createFakeDio((options) {
        if (options.path ==
                FinanceApiPaths.feeReductionDiscountApplications &&
            options.method == 'POST') {
          capturedBody = options.data as Map<String, dynamic>;
          return _fixtures.envelope(
            _fixtures.feeReductionItem(pendingDiscountApplication),
          );
        }
        return {'data': {}};
      });
      final remote = FinanceRemoteDataSource(dio);

      final result = await remote.proposeDiscountApplication(
        query: _kQuery,
        discountRuleId: 'rule_1',
        invoiceId: 'inv_4',
        reason: 'Early bird payment',
        amount: 5000,
      );

      expect(capturedBody, {
        'discountRuleId': 'rule_1',
        'invoiceId': 'inv_4',
        'reason': 'Early bird payment',
        'amount': 5000,
      });
      expect(result.sourceKind, FeeReductionSourceKind.discount);
      expect(result.reductionKind, FeeReductionKind.fixed);
      expect(result.status, FeeReductionStatus.pending);
    });

    test('approveFeeReduction posts to the /approve route and returns the '
        'applied reduction', () async {
      final dio = createFakeDio((options) {
        if (options.path ==
                FinanceApiPaths.feeReductionApprove(
                  pendingScholarshipAward.id,
                ) &&
            options.method == 'POST') {
          return _fixtures.envelope(_fixtures.feeReductionItem(approvedReduction));
        }
        return {'data': {}};
      });
      final remote = FinanceRemoteDataSource(dio);

      final result = await remote.approveFeeReduction(
        query: _kQuery,
        reductionId: pendingScholarshipAward.id,
      );

      expect(result.status, FeeReductionStatus.approved);
      expect(double.parse(result.appliedAmount), greaterThan(0));
    });

    test('rejectFeeReduction posts to the /reject route', () async {
      final rejected = pendingDiscountApplication.copyWith(
        status: FeeReductionStatus.rejected,
      );
      final dio = createFakeDio((options) {
        if (options.path ==
                FinanceApiPaths.feeReductionReject(
                  pendingDiscountApplication.id,
                ) &&
            options.method == 'POST') {
          return _fixtures.envelope(_fixtures.feeReductionItem(rejected));
        }
        return {'data': {}};
      });
      final remote = FinanceRemoteDataSource(dio);

      final result = await remote.rejectFeeReduction(
        query: _kQuery,
        reductionId: pendingDiscountApplication.id,
      );

      expect(result.status, FeeReductionStatus.rejected);
    });

    test('reverseFeeReduction posts to the /reverse route', () async {
      final reversed = approvedReduction.copyWith(
        status: FeeReductionStatus.reversed,
      );
      final dio = createFakeDio((options) {
        if (options.path ==
                FinanceApiPaths.feeReductionReverse(approvedReduction.id) &&
            options.method == 'POST') {
          return _fixtures.envelope(_fixtures.feeReductionItem(reversed));
        }
        return {'data': {}};
      });
      final remote = FinanceRemoteDataSource(dio);

      final result = await remote.reverseFeeReduction(
        query: _kQuery,
        reductionId: approvedReduction.id,
      );

      expect(result.status, FeeReductionStatus.reversed);
    });

    test('fetchFeeReductions GETs /finance/fee-reductions with status filter '
        'query param', () async {
      Map<String, dynamic>? capturedQuery;
      final dio = createFakeDio((options) {
        if (options.path == FinanceApiPaths.feeReductions &&
            options.method == 'GET') {
          capturedQuery = options.queryParameters;
          return _fixtures.listEnvelope([
            _fixtures.feeReductionItem(pendingScholarshipAward),
            _fixtures.feeReductionItem(pendingDiscountApplication),
          ]);
        }
        return {'data': {}};
      });
      final remote = FinanceRemoteDataSource(dio);

      final response = await remote.fetchFeeReductions(
        query: _kQuery,
        status: 'pending',
      );

      expect(capturedQuery?['status'], 'pending');
      expect(response.items, hasLength(2));
    });

    test('ApiFinanceRepository.listFeeReductions maps the DTO list', () async {
      final dio = createFakeDio((options) {
        if (options.path == FinanceApiPaths.feeReductions &&
            options.method == 'GET') {
          return _fixtures.listEnvelope([
            _fixtures.feeReductionItem(pendingScholarshipAward),
          ]);
        }
        return {'data': {}};
      });
      final apiRepo = ApiFinanceRepository(remote: FinanceRemoteDataSource(dio));

      final results = await apiRepo.listFeeReductions(query: _kQuery);

      expect(results, hasLength(1));
      expect(results.first.id, pendingScholarshipAward.id);
      expect(results.first.invoiceId, 'inv_1');
    });

    test('proposeScholarshipAward provider reaches the API repository and '
        'returns a pending reduction (moves no money)', () async {
      Map<String, dynamic>? capturedBody;
      final dio = createFakeDio((options) {
        if (options.path == FinanceApiPaths.feeReductionScholarshipAwards &&
            options.method == 'POST') {
          capturedBody = options.data as Map<String, dynamic>;
          return _fixtures.envelope(
            _fixtures.feeReductionItem(pendingScholarshipAward),
          );
        }
        return {'data': {}};
      });

      final container = createProviderTestContainer(
        apiFinanceDio: dio,
        financeApiEnabled: true,
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(proposeScholarshipAwardProvider.notifier)
          .execute(
            scholarshipId: 'sch_1',
            invoiceId: 'inv_1',
            reason: 'Merit scholarship',
            percent: 10,
          );

      expect(capturedBody?['scholarshipId'], 'sch_1');
      expect(result?.status, FeeReductionStatus.pending);
    });

    test('approveFeeReduction provider posts to the approve route via the '
        'API repository', () async {
      final dio = createFakeDio((options) {
        if (options.path ==
                FinanceApiPaths.feeReductionApprove(
                  pendingScholarshipAward.id,
                ) &&
            options.method == 'POST') {
          return _fixtures.envelope(_fixtures.feeReductionItem(approvedReduction));
        }
        return {'data': {}};
      });

      final container = createProviderTestContainer(
        apiFinanceDio: dio,
        financeApiEnabled: true,
        overrides: [
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.financeAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(approveFeeReductionProvider.notifier)
          .execute(reductionId: pendingScholarshipAward.id);

      expect(result?.status, FeeReductionStatus.approved);
    });
  });
}
