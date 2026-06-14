import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/security/permissions.dart';
import '../../core/security/rbac_service.dart';
import '../../core/tenant/tenant_provider.dart';
import 'evolution_models.dart';
import 'evolution_providers.dart';
import 'evolution_requests.dart';

void assertManageGrowthPlatform(Ref ref) {
  final permissions = ref.read(userPermissionsProvider);
  if (permissions == null || !permissions.has(Permission.manageGrowthPlatform)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage growth platform.',
        code: 'RBAC_MANAGE_GROWTH_PLATFORM',
      ),
    );
  }
}

void _invalidateGrowthReads(Ref ref) {
  ref.invalidate(growthDashboardProvider);
  ref.invalidate(growthCampaignsProvider);
  ref.invalidate(growthInquiriesProvider);
  ref.invalidate(growthFunnelProvider);
}

class CreateGrowthCampaignNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute(CreateGrowthCampaignRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageGrowthPlatform(ref);
      try {
        final id = await ref.read(evolutionRepositoryProvider).createGrowthCampaign(
              query: ref.read(repositoryQueryProvider),
              request: request,
            );
        _invalidateGrowthReads(ref);
        return id;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createGrowthCampaignProvider =
    AsyncNotifierProvider<CreateGrowthCampaignNotifier, String?>(
  CreateGrowthCampaignNotifier.new,
);

class CreateGrowthInquiryNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute({
    required String parentName,
    required String source,
    String? phone,
    String? gradeInterest,
    String? campaignId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageGrowthPlatform(ref);
      try {
        final id = await ref.read(evolutionRepositoryProvider).createGrowthInquiry(
              query: ref.read(repositoryQueryProvider),
              parentName: parentName,
              source: source,
              phone: phone,
              gradeInterest: gradeInterest,
              campaignId: campaignId,
            );
        _invalidateGrowthReads(ref);
        return id;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final createGrowthInquiryProvider =
    AsyncNotifierProvider<CreateGrowthInquiryNotifier, String?>(
  CreateGrowthInquiryNotifier.new,
);

class ConvertGrowthInquiryNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute(String inquiryId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageGrowthPlatform(ref);
      try {
        final leadId = await ref.read(evolutionRepositoryProvider).convertGrowthInquiry(
              query: ref.read(repositoryQueryProvider),
              inquiryId: inquiryId,
            );
        _invalidateGrowthReads(ref);
        return leadId;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final convertGrowthInquiryProvider =
    AsyncNotifierProvider<ConvertGrowthInquiryNotifier, String?>(
  ConvertGrowthInquiryNotifier.new,
);

class UpdateGrowthCampaignNotifier extends AsyncNotifier<GrowthCampaign?> {
  @override
  FutureOr<GrowthCampaign?> build() => null;

  Future<GrowthCampaign?> execute({
    required String campaignId,
    required UpdateGrowthCampaignRequest request,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageGrowthPlatform(ref);
      try {
        final campaign = await ref.read(evolutionRepositoryProvider).updateGrowthCampaign(
              query: ref.read(repositoryQueryProvider),
              campaignId: campaignId,
              request: request,
            );
        _invalidateGrowthReads(ref);
        return campaign;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final updateGrowthCampaignProvider =
    AsyncNotifierProvider<UpdateGrowthCampaignNotifier, GrowthCampaign?>(
  UpdateGrowthCampaignNotifier.new,
);

class PauseGrowthCampaignNotifier extends AsyncNotifier<GrowthCampaign?> {
  @override
  FutureOr<GrowthCampaign?> build() => null;

  Future<GrowthCampaign?> execute(String campaignId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      assertManageGrowthPlatform(ref);
      try {
        final campaign = await ref.read(evolutionRepositoryProvider).pauseGrowthCampaign(
              query: ref.read(repositoryQueryProvider),
              campaignId: campaignId,
            );
        _invalidateGrowthReads(ref);
        return campaign;
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final pauseGrowthCampaignProvider =
    AsyncNotifierProvider<PauseGrowthCampaignNotifier, GrowthCampaign?>(
  PauseGrowthCampaignNotifier.new,
);
