import 'package:akshara_erp/core/repositories/api/evolution/api_evolution_repository.dart';
import 'package:akshara_erp/core/repositories/api/evolution/mapper/evolution_mapper.dart';
import 'package:akshara_erp/core/repositories/api/evolution/remote/evolution_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/evolution/remote/evolution_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/mock/mock_evolution_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/dynamic_widgets/dynamic_widget_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

void main() {
  const query = RepositoryQuery.demo;

  group('Dynamic widget platform repository contract', () {
    late MockEvolutionRepository mock;
    late ApiEvolutionRepository api;

    setUp(() async {
      mock = MockEvolutionRepository();
      final principalLayout = await mock.getRoleDashboardLayout(
        query: query,
        role: 'principal',
      );
      final layoutJson = const EvolutionMapper().roleDashboardLayoutToJson(
        principalLayout,
      );

      final dio = createFakeDio((options) {
        final path = options.path;
        if (path == EvolutionApiPaths.widgetLayoutVersions) {
          return {
            'data': {
              'items': [
                {
                  'layoutId': 'principal-dashboard-v1',
                  'role': 'principal',
                  'verticalPack': 'school',
                  'version': 1,
                  'isTenantOverride': false,
                },
              ],
            },
          };
        }
        if (path == EvolutionApiPaths.widgetRoleLayout('principal') &&
            options.method == 'GET') {
          return {'data': layoutJson};
        }
        if (path == EvolutionApiPaths.widgetRoleLayout('principal') &&
            options.method == 'PUT') {
          return {
            'data': {
              ...layoutJson,
              'version': 2,
              'isTenantOverride': true,
            },
          };
        }
        if (path == '${EvolutionApiPaths.widgetRoleLayout('principal')}/reset') {
          return {'data': layoutJson};
        }
        if (path == EvolutionApiPaths.widgetDataSources) {
          return {
            'data': {
              'items': [
                {
                  'key': 'operations.school_health',
                  'label': 'School health score',
                  'repositoryModule': 'evolution',
                  'methodName': 'getWidgetData',
                  'supportedTypes': ['kpi'],
                  'requiredPermission': 'viewOperationsHub',
                },
              ],
            },
          };
        }
        return {'data': {}};
      });

      api = ApiEvolutionRepository(
        remote: EvolutionRemoteDataSource(dio),
        mapper: const EvolutionMapper(),
      );
    });

    test('mock returns layout versions for school principal', () async {
      final versions = await mock.getWidgetLayoutVersions(
        query: query,
        role: 'principal',
        verticalPack: 'school',
      );
      expect(versions, isNotEmpty);
      expect(versions.first.role, 'principal');
    });

    test('mock principal layout aligns with evolution widget ids', () async {
      final layout = await mock.getRoleDashboardLayout(
        query: query,
        role: 'principal',
      );
      expect(
        layout.widgets.map((w) => w.id),
        containsAll(['school_health', 'fee_collection', 'student_risk']),
      );
    });

    test('mock save and reset role layout round-trip', () async {
      final original = await mock.getRoleDashboardLayout(
        query: query,
        role: 'principal',
      );
      final hidden = original.copyWith(
        widgets: [
          for (final widget in original.widgets)
            widget.id == 'school_health'
                ? widget.copyWith(visible: false)
                : widget,
        ],
      );
      final saved = await mock.saveRoleDashboardLayout(
        query: query,
        role: 'principal',
        layout: hidden,
        version: original.version,
      );
      expect(saved.version, greaterThan(original.version));
      expect(saved.isTenantOverride, isTrue);

      final reset = await mock.resetLayoutToPackDefault(
        query: query,
        role: 'principal',
        verticalPack: 'school',
      );
      expect(reset.widgets.firstWhere((w) => w.id == 'school_health').visible, isTrue);
    });

    test('mock lists widget data sources', () async {
      final sources = await mock.listWidgetDataSources(query: query);
      expect(sources, isNotEmpty);
      expect(sources.first.key, contains('.'));
    });

    test('api maps role dashboard layout from envelope', () async {
      final layout = await api.getRoleDashboardLayout(
        query: query,
        role: 'principal',
      );
      expect(layout.widgets, isNotEmpty);
      expect(layout.widgets.first.type, isA<WidgetType>());
    });

    test('api maps layout versions and data sources', () async {
      final versions = await api.getWidgetLayoutVersions(
        query: query,
        role: 'principal',
        verticalPack: 'school',
      );
      expect(versions.first.layoutId, isNotEmpty);

      final sources = await api.listWidgetDataSources(query: query);
      expect(sources.first.label, isNotEmpty);
    });
  });
}
