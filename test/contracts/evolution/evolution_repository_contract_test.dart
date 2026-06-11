import 'package:akshara_erp/core/repositories/api/evolution/api_evolution_repository.dart';
import 'package:akshara_erp/core/repositories/api/evolution/mapper/evolution_mapper.dart';
import 'package:akshara_erp/core/repositories/api/evolution/remote/evolution_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_evolution_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

void main() {
  const query = RepositoryQuery.demo;

  group('Evolution repository contract parity', () {
    late MockEvolutionRepository mock;
    late ApiEvolutionRepository api;
    late Map<String, dynamic> mockDashboardLayout;
    late Map<String, dynamic> mockWidgetData;

    setUp(() async {
      mock = MockEvolutionRepository();
      mockDashboardLayout = {
        for (final p in await mock.getDashboardLayout(query: query))
          p.widgetId: {
            'widgetId': p.widgetId,
            'order': p.order,
            'visible': p.visible,
            'width': p.width,
            'height': p.height,
          },
      };
      mockWidgetData = {
        for (final entry in (await mock.getWidgetData(query: query)).entries)
          entry.key: {
            'widgetId': entry.value.widgetId,
            'title': entry.value.title,
            'value': entry.value.value,
            'summary': entry.value.summary,
            'metrics': entry.value.metrics,
            'alerts': entry.value.alerts,
          },
      };

      final dio = createFakeDio((options) {
        final path = options.path;
        if (path == '/widgets/registry') {
          return {'data': {'items': []}};
        }
        if (path == '/widgets/dashboard/layout' && options.method == 'GET') {
          return {
            'data': {
              'layout': mockDashboardLayout.values.toList(),
            },
          };
        }
        if (path == '/widgets/data') {
          return {'data': {'widgets': mockWidgetData}};
        }
        if (path == '/teacher-assistant/insights') {
          return {'data': {}};
        }
        if (path == '/principal-command/center') {
          return {'data': {}};
        }
        if (path == '/growth/dashboard') {
          return {'data': {}};
        }
        if (path == '/growth/funnel') {
          return {'data': {}};
        }
        return {'data': {}};
      });

      api = ApiEvolutionRepository(
        remote: EvolutionRemoteDataSource(dio),
        mapper: const EvolutionMapper(),
      );
    });

    test('mock setup wizard returns structured session', () async {
      final session = await mock.createSetupWizard(
        query: query,
        inputs: {'studentCount': 250, 'teacherCount': 10},
      );
      expect(session.steps, isNotEmpty);
      expect(session.warnings, isNotEmpty);
    });

    test('mock widget data covers all default widgets', () async {
      final data = await mock.getWidgetData(query: query);
      expect(data.keys, containsAll([
        'school_health',
        'student_risk',
        'fee_collection',
        'attendance_risk',
        'homework_summary',
        'operations_summary',
        'employee_workload',
        'timetable_alerts',
      ]));
    });

    test('API mapper parses dashboard layout from envelope', () async {
      final layout = await api.getDashboardLayout(query: query);
      expect(layout, isNotEmpty);
      expect(layout.first.widgetId, isNotEmpty);
    });

    test('mock growth funnel and convert inquiry', () async {
      final funnel = await mock.getGrowthFunnel(query: query);
      expect(funnel.stages, isNotEmpty);

      final inquiryId = await mock.createGrowthInquiry(
        query: query,
        parentName: 'Test Parent',
        source: 'website',
      );
      final leadId = await mock.convertGrowthInquiry(query: query, inquiryId: inquiryId);
      expect(leadId, isNotEmpty);
    });

    test('mock parent language preference round-trip', () async {
      await mock.saveParentLanguagePreference(query: query, language: 'hindi');
      final lang = await mock.getParentLanguagePreference(query: query);
      expect(lang, 'hindi');
    });

    test('mock operations actions returns actionable items', () async {
      final actions = await mock.getOperationsActions(query: query);
      expect(actions, isNotEmpty);
      expect(actions.first.actionType, isNotEmpty);
    });
  });
}
