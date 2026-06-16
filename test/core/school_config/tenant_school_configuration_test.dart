import 'package:akshara_erp/core/school_config/school_configuration_models.dart';
import 'package:akshara_erp/core/school_config/tenant_school_configuration_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tenantId = 'tenant_config_test';

  test('tenant store provides cross-admin consistency', () {
    final store = TenantSchoolConfigurationStore.instance;
    final config = SchoolConfiguration.demoDefault().copyWith(
      branchCount: 5,
    );

    store.write(
      tenantId: tenantId,
      config: config,
      actorLabel: 'Admin A',
    );

    final readBack = store.read(tenantId);
    expect(readBack?.branchCount, 5);
    expect(store.auditForTenant(tenantId), isNotEmpty);
  });
}
