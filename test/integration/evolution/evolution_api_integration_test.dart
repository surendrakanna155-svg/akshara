import 'package:akshara_erp/core/repositories/api/evolution/api_evolution_repository.dart';
import 'package:akshara_erp/core/repositories/api/evolution/remote/evolution_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/evolution/remote/evolution_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_evolution_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('Evolution API integration', () {
    late MockEvolutionRepository mockRepo;
    late ApiEvolutionRepository apiRepo;

    setUp(() async {
      mockRepo = MockEvolutionRepository();
      final widgets = await mockRepo.listWidgets(query: kQuery);
      final layout = await mockRepo.getDashboardLayout(query: kQuery);
      final widgetData = await mockRepo.getWidgetData(query: kQuery);
      final teacher = await mockRepo.getTeacherAssistantInsights(query: kQuery);
      final principal = await mockRepo.getPrincipalCommandCenter(query: kQuery);
      final growth = await mockRepo.getGrowthDashboard(query: kQuery);
      final funnel = await mockRepo.getGrowthFunnel(query: kQuery);

      final dio = createFakeDio((options) {
        if (options.path == EvolutionApiPaths.widgetRegistry) {
          return {
            'data': {
              'items': widgets
                  .map(
                    (w) => {
                      'id': w.id,
                      'title': w.title,
                      'category': w.category,
                      'requiredPermission': w.requiredPermission,
                    },
                  )
                  .toList(),
            },
          };
        }
        if (options.path == EvolutionApiPaths.widgetDashboardLayout && options.method == 'GET') {
          return {
            'data': {
              'layout': layout
                  .map(
                    (p) => {
                      'widgetId': p.widgetId,
                      'order': p.order,
                      'visible': p.visible,
                      'width': p.width,
                      'height': p.height,
                    },
                  )
                  .toList(),
            },
          };
        }
        if (options.path == EvolutionApiPaths.widgetData) {
          return {
            'data': {
              'widgets': {
                for (final e in widgetData.entries)
                  e.key: {
                    'widgetId': e.value.widgetId,
                    'title': e.value.title,
                    'value': e.value.value,
                    'summary': e.value.summary,
                  },
              },
            },
          };
        }
        if (options.path == EvolutionApiPaths.teacherAssistantInsights) {
          return {
            'data': {
              'riskStudents': teacher.riskStudents,
              'weakTopics': teacher.weakTopics,
              'homeworkConcerns': teacher.homeworkConcerns,
              'suggestedActions': teacher.suggestedActions,
              'lessonPlanSuggestions': teacher.lessonPlanSuggestions,
              'parentMeetingSummaries': teacher.parentMeetingSummaries,
            },
          };
        }
        if (options.path == EvolutionApiPaths.principalCommandCenter) {
          return {
            'data': {
              'topPriorities': principal.topPriorities,
              'executiveSummary': principal.executiveSummary,
              'actionRecommendations': principal.actionRecommendations,
              'monthlyImprovement': principal.monthlyImprovement,
              'riskOverview': principal.riskOverview,
              'widgets': principal.widgets,
              'priorityEngineScore': principal.priorityEngineScore,
            },
          };
        }
        if (options.path == EvolutionApiPaths.growthDashboard) {
          return {
            'data': {
              'campaigns': growth.campaigns,
              'inquiries': growth.inquiries,
              'conversionRate': growth.conversionRate,
              'totalInquiries': growth.totalInquiries,
              'activeCampaigns': growth.activeCampaigns,
            },
          };
        }
        if (options.path == EvolutionApiPaths.growthFunnel) {
          return {
            'data': {
              'stages': funnel.stages,
              'campaignAttribution': funnel.campaignAttribution,
              'sourceAttribution': funnel.sourceAttribution,
              'convertedCount': funnel.convertedCount,
              'totalInquiries': funnel.totalInquiries,
            },
          };
        }
        return {'data': {}};
      });

      apiRepo = ApiEvolutionRepository(remote: EvolutionRemoteDataSource(dio));
    });

    test('listWidgets maps registry items', () async {
      final items = await apiRepo.listWidgets(query: kQuery);
      expect(items.length, greaterThanOrEqualTo(4));
    });

    test('getWidgetData returns live payloads', () async {
      final data = await apiRepo.getWidgetData(query: kQuery);
      expect(data['school_health']?.value, isNotEmpty);
    });

    test('getPrincipalCommandCenter includes priority engine score', () async {
      final center = await apiRepo.getPrincipalCommandCenter(query: kQuery);
      expect(center.priorityEngineScore, isNotNull);
    });

    test('getGrowthFunnel returns funnel stages', () async {
      final funnel = await apiRepo.getGrowthFunnel(query: kQuery);
      expect(funnel.stages, isNotEmpty);
    });
  });
}
