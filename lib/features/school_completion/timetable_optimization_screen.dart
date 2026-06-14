import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../router/route_names.dart';
import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';

class TimetableOptimizationScreen extends ConsumerWidget {
  const TimetableOptimizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(academicCatalogFutureProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Timetable Optimization')),
      body: catalog.when(
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState(message: '$e'),
        data: (data) {
          final yearId = data.years.isNotEmpty ? data.years.first.yearId : 'year_1';
          final optimization = ref.watch(timetableOptimizationProvider(yearId));
          return optimization.when(
            loading: () => const AksharaLoadingState(),
            error: (e, _) => AksharaErrorState(message: '$e'),
            data: (result) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: const Text('Quality score'),
                  trailing: Text('${result.qualityScore}/100',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  title: const Text('Conflicts'),
                  trailing: Text('${result.conflictCount}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (result.overloadAlerts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AksharaWarningBanner(
                    message:
                        '${result.overloadAlerts.length} overload alerts — review teacher schedules',
                  ),
                  ...result.overloadAlerts.map(
                    (a) => ListTile(
                      title: Text(a.teacherName),
                      subtitle: Text('${a.periodCount} periods assigned'),
                    ),
                  ),
                ],
                const Divider(),
                const Text('Free period analysis', style: TextStyle(fontWeight: FontWeight.bold)),
                ...result.freePeriodAnalysis.map(
                  (f) => ListTile(
                    title: Text(f.teacherName),
                    trailing: Text('${f.freePeriods} free'),
                  ),
                ),
                const Divider(),
                const Text('Suggestions', style: TextStyle(fontWeight: FontWeight.bold)),
                ...result.recommendations.map(
                  (r) => ListTile(title: Text(r.title), subtitle: Text(r.detail)),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(RouteNames.substituteManager),
                    icon: const Icon(Icons.swap_horiz_outlined),
                    label: const Text('Open Substitute Teacher Wizard'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
