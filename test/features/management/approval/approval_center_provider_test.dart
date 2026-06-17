import 'package:akshara_erp/core/approvals/approval_category.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/repositories/mock/mock_approval_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/management/approval/approval_center_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/provider_test_overrides.dart';

void main() {
  group('Approval center providers', () {
    late ProviderContainer container;
    late MockApprovalRepository repository;

    setUp(() async {
      await initProviderTestPrefs();
      repository = MockApprovalRepository();
      container = createProviderTestContainer(
        overrides: [
          approvalRepositoryProvider.overrideWithValue(repository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('loads seeded demo approvals', () async {
      final items = await container.read(approvalCenterFutureProvider.future);
      expect(items, isNotEmpty);
      expect(
        items.any((a) => a.title.contains('Science lab upgrade')),
        isTrue,
      );
    });

    test('filters pending status', () async {
      await container.read(approvalCenterFutureProvider.future);
      container.read(approvalCenterStatusFilterProvider.notifier).state = 1;

      final filtered = container.read(approvalCenterFilteredListProvider);
      expect(filtered, isNotEmpty);
      expect(filtered.every((a) => a.status == ApprovalStatus.pending), isTrue);
    });

    test('filters academic category to exam results only', () async {
      await container.read(approvalCenterFutureProvider.future);
      container.read(approvalCenterCategoryFilterProvider.notifier).state =
          ApprovalCategory.academic;

      final filtered = container.read(approvalCenterFilteredListProvider);
      expect(filtered, isNotEmpty);
      expect(
        filtered.every((a) => a.type == ApprovalRequestType.examResults),
        isTrue,
      );
    });

    test('pending count matches pending items', () async {
      await container.read(approvalCenterFutureProvider.future);
      final items = container.read(approvalCenterListProvider);
      final pending = container.read(approvalCenterPendingCountProvider);
      expect(
        pending,
        items.where((a) => a.status == ApprovalStatus.pending).length,
      );
    });
  });
}
