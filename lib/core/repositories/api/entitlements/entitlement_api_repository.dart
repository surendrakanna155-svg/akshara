import 'package:dio/dio.dart';

import '../../../entitlements/entitlement_models.dart';
import '../admissions/dto/api_envelope_dto.dart';

/// Read-only client for the entitlement layer (B2 Step 2 backend):
///   GET /plans        — public plan catalog.
///   GET /subscription — the current org's resolved plan/entitlements/limits.
///
/// Entitlement layer only — there is no assign/pay/renew call on the client.
class EntitlementApiRepository {
  EntitlementApiRepository(this._dio);

  final Dio _dio;

  /// Fetches the public plan catalog.
  Future<List<SubscriptionPlan>> fetchPlans() async {
    final response = await _dio.get<Map<String, dynamic>>('/plans');
    final data = ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
    final raw = data['plans'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => SubscriptionPlan.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Fetches the current org's resolved subscription, or `null` if the response
  /// carries no subscription payload (caller then applies the Trial fallback).
  Future<ResolvedSubscription?> fetchSubscription() async {
    final response = await _dio.get<Map<String, dynamic>>('/subscription');
    final data = ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
    final raw = data['subscription'];
    if (raw is! Map<String, dynamic>) return null;
    return ResolvedSubscription.fromJson(raw);
  }

  // ─── SuperAdmin plan assignment (managePlatformSubscriptions) ──────────────

  /// Lists every organization with its current plan (`GET /platform/subscriptions`).
  Future<List<OrganizationPlanAssignment>> fetchAssignableOrganizations() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/platform/subscriptions');
    final data = ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
    final raw = data['organizations'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) =>
            OrganizationPlanAssignment.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Assigns/changes an organization's plan
  /// (`PUT /platform/organizations/{id}/subscription`). No payment is taken.
  Future<OrganizationPlanAssignment> assignSubscription({
    required String organizationId,
    required String planSlug,
    String? status,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/platform/organizations/$organizationId/subscription',
      data: {
        'planSlug': planSlug,
        if (status != null) 'status': status,
      },
    );
    final data = ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
    final raw = data['organization'];
    if (raw is Map<String, dynamic>) {
      return OrganizationPlanAssignment.fromJson(raw);
    }
    return OrganizationPlanAssignment(
      organizationId: organizationId,
      organizationName: '',
      organizationSlug: '',
      planSlug: planSlug,
      status: status ?? (planSlug == 'trial' ? 'trial' : 'active'),
    );
  }
}
