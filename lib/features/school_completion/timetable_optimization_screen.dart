import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/widgets.dart';
import 'school_completion_mutations_provider.dart';
import 'school_completion_models.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

class TimetableOptimizationScreen extends ConsumerStatefulWidget {
  const TimetableOptimizationScreen({super.key});

  @override
  ConsumerState<TimetableOptimizationScreen> createState() =>
      _TimetableOptimizationScreenState();
}

class _TimetableOptimizationScreenState
    extends ConsumerState<TimetableOptimizationScreen> {
  String? _selectedAcademicYearId;

  Future<void> _applyRecommendations(
    BuildContext context, {
    required String academicYearId,
    required bool applyAll,
    List<String> recommendationIds = const [],
  }) async {
    final result =
        await ref.read(applyTimetableOptimizationProvider.notifier).execute(
              ApplyTimetableOptimizationRequest(
                academicYearId: academicYearId,
                recommendationIds: recommendationIds,
                applyAll: applyAll,
              ),
            );
    if (!context.mounted || result == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: QaTestKeys.timetableOptimizationApplySuccessSnackbar,
        content: Text(result.message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(academicCatalogFutureProvider);
    final mutationState = ref.watch(applyTimetableOptimizationProvider);
    final applying = mutationState.isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Timetable Optimization')),
      body: ErpAsyncBody(
        state: resolveErpAsync(catalog, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No academic catalog available.',
        onRetry: () => ref.invalidate(academicCatalogFutureProvider),
        builder: (data) {
          _selectedAcademicYearId ??=
              data.years.isNotEmpty ? data.years.first.yearId : 'year_1';
          final yearId = _selectedAcademicYearId!;
          final optimization = ref.watch(timetableOptimizationProvider(yearId));
          return ErpAsyncBody(
            state: resolveErpAsync(optimization, isDataEmpty: (_) => false),
            loadingLabel: 'Loading',
            emptyMessage: 'No timetable optimization data available.',
            onRetry: () => ref.invalidate(timetableOptimizationProvider(yearId)),
            builder: (result) {
              final actionableRecommendations = result.recommendations
                  .where(
                    (recommendation) =>
                        !recommendation.readOnly &&
                        recommendation.recommendationId != null,
                  )
                  .toList(growable: false);
              return ListView(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
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
                  const Text('Free period analysis',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...result.freePeriodAnalysis.map(
                    (f) => ListTile(
                      title: Text(f.teacherName),
                      trailing: Text('${f.freePeriods} free'),
                    ),
                  ),
                  const Divider(),
                  const Text('Suggestions',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...result.recommendations.map(
                    (r) => ListTile(
                      title: Text(r.title),
                      subtitle: Text(r.detail),
                      trailing: !r.readOnly && r.recommendationId != null
                          ? OutlinedButton(
                              key: QaTestKeys.timetableOptimizationApplyButton(
                                r.recommendationId!,
                              ),
                              onPressed: applying
                                  ? null
                                  : () => _applyRecommendations(
                                        context,
                                        academicYearId: yearId,
                                        applyAll: false,
                                        recommendationIds: [
                                          r.recommendationId!
                                        ],
                                      ),
                              child: const Text('Apply'),
                            )
                          : null,
                    ),
                  ),
                  if (actionableRecommendations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        key: QaTestKeys.timetableOptimizationApplyAllButton,
                        onPressed: applying
                            ? null
                            : () => _applyRecommendations(
                                  context,
                                  academicYearId: yearId,
                                  applyAll: true,
                                ),
                        icon: applying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_fix_high_outlined),
                        label: const Text('Apply All'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push(RouteNames.substituteManager),
                      icon: const Icon(Icons.swap_horiz_outlined),
                      label: const Text('Open Substitute Teacher Wizard'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
