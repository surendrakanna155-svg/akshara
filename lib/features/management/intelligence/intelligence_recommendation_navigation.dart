import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../intelligence/operations/operations_intelligence.dart';
import '../../intelligence/unified/unified_recommendation_intelligence.dart';
import '../../../router/route_names.dart';

void navigateIntelligenceRecommendation(
  BuildContext context,
  UnifiedRecommendationSource source,
) {
  final route = switch (source) {
    UnifiedRecommendationSource.atRisk => RouteNames.studentSuccessIntelligence,
    UnifiedRecommendationSource.attendance =>
      RouteNames.studentSuccessIntelligence,
    UnifiedRecommendationSource.feeCollection => RouteNames.financeDefaulters,
    UnifiedRecommendationSource.teacherIntervention =>
      RouteNames.teacherEffectiveness,
    UnifiedRecommendationSource.promotion => RouteNames.sisPromotion,
    UnifiedRecommendationSource.operations => RouteNames.operationsHub,
  };
  context.go(route);
}

void navigateOperationsHint(
  BuildContext context,
  OperationsHintKind kind,
) {
  final route = switch (kind) {
    OperationsHintKind.sectionBalance => RouteNames.sisSectionBalance,
    OperationsHintKind.teacherContinuity => RouteNames.teacherReassignment,
    OperationsHintKind.workflowAutomation =>
      RouteNames.managementWorkflowAutomation,
  };
  context.go(route);
}
