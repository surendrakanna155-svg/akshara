import '../../core/ai/ai_inference_models.dart';
import '../../core/ai/ai_inference_pipeline.dart';
import '../../core/repositories/repository_query.dart';
import 'resource_optimization_models.dart';

abstract class ResourceOptimizationRepository {
  Future<List<OptimizationRecommendation>> listRecommendations({
    required RepositoryQuery query,
    required ResourceOptimizationDomain domain,
  });

  Future<void> applyRecommendation({
    required RepositoryQuery query,
    required ResourceOptimizationDomain domain,
    required String recommendationId,
  });

  Future<void> dismissRecommendation({
    required RepositoryQuery query,
    required ResourceOptimizationDomain domain,
    required String recommendationId,
  });
}

class MockResourceOptimizationRepository
    implements ResourceOptimizationRepository {
  MockResourceOptimizationRepository({required AiInferencePipeline pipeline})
      : _pipeline = pipeline;

  final AiInferencePipeline _pipeline;
  final Set<String> _appliedIds = <String>{};
  final Set<String> _dismissedIds = <String>{};

  @override
  Future<List<OptimizationRecommendation>> listRecommendations({
    required RepositoryQuery query,
    required ResourceOptimizationDomain domain,
  }) async {
    try {
      final response = await _pipeline.complete(
        AiInferenceRequest(
          prompt: _buildPrompt(domain: domain, query: query),
          taskType: aiTaskTypeName(AiInferenceTaskType.resourceOptimization),
          systemPrompt: 'Akshara ERP resource optimization engine',
          context: {
            'module': 'resource_optimization',
            'domain': domain.name,
            'schoolId': query.schoolId,
            'organizationId': query.organizationId,
            'tenantId': query.tenantId,
          },
        ),
      );

      final parsed = _parseRecommendations(domain, response.content);
      final base = parsed.isEmpty ? _fallbackRecommendations(domain) : parsed;
      return base
          .map(
            (recommendation) => recommendation.copyWith(
              applied: _appliedIds.contains(recommendation.id),
              dismissed: _dismissedIds.contains(recommendation.id),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return _fallbackRecommendations(domain)
          .map(
            (recommendation) => recommendation.copyWith(
              applied: _appliedIds.contains(recommendation.id),
              dismissed: _dismissedIds.contains(recommendation.id),
            ),
          )
          .toList(growable: false);
    }
  }

  @override
  Future<void> applyRecommendation({
    required RepositoryQuery query,
    required ResourceOptimizationDomain domain,
    required String recommendationId,
  }) async {
    _dismissedIds.remove(recommendationId);
    _appliedIds.add(recommendationId);
  }

  @override
  Future<void> dismissRecommendation({
    required RepositoryQuery query,
    required ResourceOptimizationDomain domain,
    required String recommendationId,
  }) async {
    _appliedIds.remove(recommendationId);
    _dismissedIds.add(recommendationId);
  }

  String _buildPrompt({
    required ResourceOptimizationDomain domain,
    required RepositoryQuery query,
  }) {
    return 'Generate 3 concise optimization recommendations for ${domain.promptContext}. '
        'Return each line as: id|title|summary|expectedImpact|confidence(0-100). '
        'Tenant: ${query.tenantId}, school: ${query.schoolId}, organization: ${query.organizationId}.';
  }

  List<OptimizationRecommendation> _parseRecommendations(
    ResourceOptimizationDomain domain,
    String content,
  ) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final recommendations = <OptimizationRecommendation>[];
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length < 5) continue;
      final confidence = int.tryParse(parts[4].trim()) ?? 72;
      recommendations.add(
        OptimizationRecommendation(
          id: _sanitizeId(parts[0], domain),
          domain: domain,
          title: parts[1].trim(),
          summary: parts[2].trim(),
          expectedImpact: parts[3].trim(),
          confidence: confidence.clamp(0, 100),
        ),
      );
    }
    return recommendations;
  }

  String _sanitizeId(String rawId, ResourceOptimizationDomain domain) {
    final normalized =
        rawId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    if (normalized.isEmpty) {
      return '${domain.name}_rec';
    }
    return normalized;
  }

  List<OptimizationRecommendation> _fallbackRecommendations(
    ResourceOptimizationDomain domain,
  ) {
    return switch (domain) {
      ResourceOptimizationDomain.staffing => const [
          OptimizationRecommendation(
            id: 'staffing_balance_load',
            domain: ResourceOptimizationDomain.staffing,
            title: 'Balance high-load teacher sections',
            summary: 'Move one Grade 8 science section to available faculty.',
            expectedImpact: 'Reduce overload alerts by 30%.',
            confidence: 88,
          ),
          OptimizationRecommendation(
            id: 'staffing_substitute_pool',
            domain: ResourceOptimizationDomain.staffing,
            title: 'Create substitute standby pool',
            summary: 'Reserve two free-period teachers for first-half slots.',
            expectedImpact: 'Cut last-minute substitutions by 40%.',
            confidence: 82,
          ),
          OptimizationRecommendation(
            id: 'staffing_reduce_idle',
            domain: ResourceOptimizationDomain.staffing,
            title: 'Consolidate idle support periods',
            summary:
                'Merge low-utilization support sessions into focused blocks.',
            expectedImpact: 'Free 6 weekly periods for remediation.',
            confidence: 75,
          ),
        ],
      ResourceOptimizationDomain.timetable => const [
          OptimizationRecommendation(
            id: 'timetable_conflict_swap',
            domain: ResourceOptimizationDomain.timetable,
            title: 'Swap overlapping grade blocks',
            summary: 'Swap Grade 7 lab with Grade 9 language period on Wed.',
            expectedImpact: 'Resolve 4 timetable conflicts.',
            confidence: 85,
          ),
          OptimizationRecommendation(
            id: 'timetable_cluster_labs',
            domain: ResourceOptimizationDomain.timetable,
            title: 'Cluster lab sessions by floor',
            summary: 'Align science labs in consecutive periods per wing.',
            expectedImpact: 'Reduce transition downtime by 18 minutes/day.',
            confidence: 78,
          ),
          OptimizationRecommendation(
            id: 'timetable_even_distribution',
            domain: ResourceOptimizationDomain.timetable,
            title: 'Even out heavy subject spread',
            summary: 'Avoid back-to-back heavy theory subjects for Grades 6-8.',
            expectedImpact: 'Improve timetable quality score by 6 points.',
            confidence: 73,
          ),
        ],
      ResourceOptimizationDomain.room => const [
          OptimizationRecommendation(
            id: 'room_reassign_lab',
            domain: ResourceOptimizationDomain.room,
            title: 'Reassign underutilized chemistry lab',
            summary: 'Shift lower-grade practicals to Lab-2 in second half.',
            expectedImpact: 'Increase lab utilization from 52% to 74%.',
            confidence: 84,
          ),
          OptimizationRecommendation(
            id: 'room_capacity_alignment',
            domain: ResourceOptimizationDomain.room,
            title: 'Align class size to room capacity',
            summary:
                'Move Grade 10-B to Room 304 with higher seating capacity.',
            expectedImpact: 'Remove 2 daily overflow incidents.',
            confidence: 80,
          ),
          OptimizationRecommendation(
            id: 'room_reduce_idle_blocks',
            domain: ResourceOptimizationDomain.room,
            title: 'Reduce idle room blocks',
            summary:
                'Auto-fill single-period room gaps with activity sessions.',
            expectedImpact: 'Recover 9 room-periods weekly.',
            confidence: 71,
          ),
        ],
      ResourceOptimizationDomain.transport => const [
          OptimizationRecommendation(
            id: 'transport_rebalance_route_3',
            domain: ResourceOptimizationDomain.transport,
            title: 'Rebalance Route-3 load',
            summary: 'Shift 12 students from Route-3 to Route-5 morning run.',
            expectedImpact: 'Bring occupancy from 112% to 95%.',
            confidence: 86,
          ),
          OptimizationRecommendation(
            id: 'transport_stagger_pickups',
            domain: ResourceOptimizationDomain.transport,
            title: 'Stagger high-density pickups',
            summary: 'Adjust three adjacent stops by 7-10 minutes.',
            expectedImpact: 'Reduce average delay by 11%.',
            confidence: 79,
          ),
          OptimizationRecommendation(
            id: 'transport_fleet_pairing',
            domain: ResourceOptimizationDomain.transport,
            title: 'Optimize spare fleet pairing',
            summary: 'Assign standby van to afternoon peak corridor only.',
            expectedImpact: 'Save 6 driver-hours per week.',
            confidence: 74,
          ),
        ],
    };
  }
}
