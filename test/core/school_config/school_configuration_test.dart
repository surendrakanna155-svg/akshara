import 'package:akshara_erp/core/school_config/school_capability_registry.dart';
import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/school_config/school_configuration_storage.dart';
import 'package:akshara_erp/features/admin/models/admin_nav_models.dart';
import 'package:akshara_erp/core/school_config/school_dashboard_adapter.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initProviderTestPrefs();
  });

  group('SchoolConfiguration', () {
    test('serializes and restores from JSON', () {
      final original = SchoolConfiguration(
        schoolType: SchoolType.highSchool,
        curriculum: SchoolCurriculum.cbse,
        capabilities: const SchoolCapabilities(
          transport: false,
          hostel: true,
          library: false,
        ),
        operationsModel: SchoolOperationsModel.singleSchool,
        branchCount: 2,
        configuredAt: DateTime(2026, 6, 16),
      );

      final restored = SchoolConfiguration.fromJson(original.toJson());
      expect(restored.schoolType, SchoolType.highSchool);
      expect(restored.capabilities.transport, isFalse);
      expect(restored.capabilities.library, isFalse);
      expect(restored.branchCount, 2);
    });

    test('storage persists configuration', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = SchoolConfigurationStorage(prefs);
      const config = SchoolConfiguration(
        schoolType: SchoolType.primary,
        curriculum: SchoolCurriculum.icse,
        capabilities: SchoolCapabilities(transport: false),
        operationsModel: SchoolOperationsModel.schoolGroup,
        branchCount: 4,
      );

      await storage.write(config);
      final loaded = storage.readSync();
      expect(loaded?.capabilities.transport, isFalse);
      expect(loaded?.operationsModel, SchoolOperationsModel.schoolGroup);
    });
  });

  group('SchoolCapabilityRegistry', () {
    test('hides transport module when disabled', () {
      const capabilities = SchoolCapabilities(transport: false);
      expect(
        SchoolCapabilityRegistry.isAdminModuleEnabled(
          AdminModule.transport,
          capabilities,
        ),
        isFalse,
      );
      expect(
        SchoolCapabilityRegistry.isAdminModuleEnabled(
          AdminModule.finance,
          capabilities,
        ),
        isTrue,
      );
    });

    test('enabledModuleIds reflects capabilities', () {
      const capabilities = SchoolCapabilities(
        transport: false,
        hostel: false,
        library: true,
        trustOrganization: true,
      );
      final modules = SchoolCapabilityRegistry.enabledModuleIds(capabilities);
      expect(modules, contains('library'));
      expect(modules, isNot(contains('transport')));
      expect(modules, isNot(contains('hostel')));
      expect(modules, contains('trust_intelligence'));
    });
  });

  group('Parent dashboard adaptation', () {
    test('filters transport notices when transport disabled', () {
      final data = ParentDashboardData.mock();
      final adapted = adaptParentDashboard(
        data,
        const SchoolCapabilities(transport: false),
      );
      expect(
        adapted.notices.any((n) => n.title.toLowerCase().contains('transport')),
        isFalse,
      );
    });
  });
}
