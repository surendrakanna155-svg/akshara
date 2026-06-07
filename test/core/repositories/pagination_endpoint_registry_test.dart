import 'package:akshara_erp/core/repositories/pagination_endpoint_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v4.6 pagination rollout covers all 42 ERP list endpoints', () {
    assertPaginationRolloutComplete();
    expect(paginatedErpListEndpointCount, 42);
    expect(virtualizedTableEndpointCount, greaterThanOrEqualTo(7));
  });

  test('each module has at least one paginated endpoint', () {
    final modules = kPaginatedErpListEndpoints.map((e) => e.module).toSet();
    expect(modules, containsAll([
      'admissions',
      'finance',
      'sis',
      'hr',
      'transport',
      'inventory',
      'library',
      'hostel',
      'alumni',
      'control_center',
    ]));
  });
}
