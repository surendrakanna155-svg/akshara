import '../../../features/platform/control_center/control_center_models.dart';
import '../../../features/platform/control_center/control_center_requests.dart';

/// Mutable control center records produced by operator write actions
/// (e.g. onboarding a new school). Merged ahead of the seed lists so new
/// entries surface immediately in the mock repository.
final class MockControlCenterWriteStore {
  MockControlCenterWriteStore._();

  static final MockControlCenterWriteStore instance =
      MockControlCenterWriteStore._();

  final List<PlatformSchool> schools = [];
  final List<CrmDeal> deals = [];
  final List<AiCreditEntry> aiCreditEntries = [];
  int _schoolSequence = 9000;
  int _dealSequence = 900;
  int _aiCreditSequence = 500;

  void reset() {
    schools.clear();
    deals.clear();
    aiCreditEntries.clear();
    _schoolSequence = 9000;
    _dealSequence = 900;
    _aiCreditSequence = 500;
  }

  /// Onboards a new school. New schools start on a trial plan footing with a
  /// neutral health score and zero MRR until billing is configured.
  PlatformSchool createSchool(CreateSchoolRequest request) {
    final name = request.name.trim();
    if (name.isEmpty) {
      throw StateError('School name is required');
    }

    final sequence = ++_schoolSequence;
    final school = PlatformSchool(
      id: 'SCH-$sequence',
      name: name,
      plan: _parsePlan(request.plan),
      studentCount: int.tryParse(request.studentCount.trim()) ?? 0,
      status: PlatformSchoolStatus.trial,
      createdDate: _today(),
      mrrLakhs: 0,
      healthScore: 70,
      region: request.region.trim().isEmpty ? '—' : request.region.trim(),
      tenantId: 'tenant_new_$sequence',
    );
    schools.insert(0, school);
    return school;
  }

  /// Adds a new sales lead to the CRM pipeline. New leads enter at the lead
  /// stage with today as their last activity.
  CrmDeal createLead(CreateCrmLeadRequest request) {
    final schoolName = request.schoolName.trim();
    if (schoolName.isEmpty) {
      throw StateError('School name is required');
    }

    final deal = CrmDeal(
      id: 'DEAL-${++_dealSequence}',
      schoolName: schoolName,
      contactName:
          request.contactName.trim().isEmpty ? '—' : request.contactName.trim(),
      stage: CrmPipelineStage.lead,
      estimatedMrrLakhs: double.tryParse(request.estimatedMrr.trim()) ?? 0,
      owner: request.owner.trim().isEmpty ? 'Unassigned' : request.owner.trim(),
      lastActivity: _today(),
    );
    deals.insert(0, deal);
    return deal;
  }

  /// Appends a signed credit-ledger row, enforcing the same sign rules as
  /// `ai_credit_entries_units_sign_check` / `grantCredits()` server-side —
  /// there is no UPDATE/DELETE path by design (a compensating row only).
  AiCreditEntry grantAiCredits({
    required String entryType,
    required int units,
    required String reason,
    String? externalRef,
  }) {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw StateError('reason is required');
    }
    if (units == 0) {
      throw StateError('units must be a non-zero integer');
    }
    if (entryType == 'top_up' && units <= 0) {
      throw StateError('a top_up must add credit (units > 0)');
    }
    if (entryType == 'expiry' && units >= 0) {
      throw StateError('an expiry must remove credit (units < 0)');
    }

    final entry = AiCreditEntry(
      id: 'AICR-${++_aiCreditSequence}',
      entryType: entryType,
      units: units,
      reason: trimmedReason,
      actorId: 'mock_super_admin',
      externalRef: externalRef,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    aiCreditEntries.insert(0, entry);
    return entry;
  }

  static SubscriptionPlan _parsePlan(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.contains('enterprise')) return SubscriptionPlan.enterprise;
    if (value.contains('premium')) return SubscriptionPlan.premium;
    return SubscriptionPlan.standard;
  }

  static String _today() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
