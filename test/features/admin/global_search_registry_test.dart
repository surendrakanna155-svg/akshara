import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/features/admin/global_search/global_search_registry.dart';
import 'package:akshara_erp/router/route_names.dart';

void main() {
  test('global search finds finance destinations', () {
    final results = GlobalSearchRegistry.search('defaulter');
    expect(results.any((e) => e.route == RouteNames.financeDefaulters), isTrue);
  });

  test('global search matches module keywords', () {
    final results = GlobalSearchRegistry.search('enrollment');
    expect(results.any((e) => e.route == RouteNames.admissionsEnrollment), isTrue);
  });
}
