import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/reports/akshara_report_export_service.dart';
import '../../../router/route_names.dart';
import '../../../shared/async/erp_async_state.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme_extensions.dart';
import '../../../theme/spacing.dart';
import '../widgets/finance_module_scaffold.dart';
import '../finance_models.dart';
import 'finance_intelligence_provider.dart';

/// Finance Executive Dashboard — collection health and risk students.
class FinanceExecutiveDashboardScreen extends ConsumerWidget {
  const FinanceExecutiveDashboardScreen({super.key});

  static const _periodFilters = ['This month', 'This quarter', 'YTD'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(financeExecutiveProvider);
    final periodIndex = ref.watch(_financeExecutivePeriodProvider);

    return FinanceModuleScaffold(
      screen: FinanceScreen.executiveDashboard,
      showFilterBar: false,
      body: ErpAsyncBody(
        state: resolveErpAsync(data, isDataEmpty: (_) => false),
        loadingLabel: 'Loading',
        emptyMessage: 'No finance executive data available.',
        onRetry: () => ref.invalidate(financeExecutiveProvider),
        builder: (snapshot) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AksharaAnalyticsFilterBar(
              filters: _periodFilters,
              selectedIndex: periodIndex,
              onSelected: (index) =>
                  ref.read(_financeExecutivePeriodProvider.notifier).state = index,
              trailing: OutlinedButton.icon(
                onPressed: () async {
                  final service = ref.read(aksharaReportExportServiceProvider);
                  final bytes = await service.buildTabularReportPdf(
                    reportTitle: 'Finance Executive Dashboard',
                    moduleLabel: 'Finance · Executive',
                    generatedAtLabel: DateTime.now().toIso8601String(),
                    rows: [
                      MapEntry(
                        'Collection health',
                        '${snapshot.collectionHealthScore}',
                      ),
                      MapEntry(
                        'Outstanding',
                        '${snapshot.outstandingCollections}',
                      ),
                      MapEntry(
                        'Expected collections',
                        '${snapshot.expectedCollections}',
                      ),
                      MapEntry(
                        'Risk students',
                        '${snapshot.riskStudents.length}',
                      ),
                    ],
                  );
                  if (!context.mounted) return;
                  await service.previewPdf(
                    documentName: 'finance_executive_dashboard.pdf',
                    bytes: bytes,
                  );
                },
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export'),
              ),
            ),
            AksharaAnalyticsSummaryRow(
              metrics: [
                AksharaAnalyticsMetric(
                  value: '${snapshot.collectionHealthScore}',
                  label: 'Collection health',
                  accent: snapshot.collectionHealthScore >= 70
                      ? KpiAccent.success
                      : KpiAccent.warning,
                  icon: Icons.health_and_safety_outlined,
                  detail: '/100 score',
                ),
                AksharaAnalyticsMetric(
                  value: '₹${snapshot.expectedCollections}',
                  label: 'Expected collections',
                  accent: KpiAccent.primary,
                  icon: Icons.trending_up,
                ),
                AksharaAnalyticsMetric(
                  value: '₹${snapshot.outstandingCollections}',
                  label: 'Outstanding',
                  accent: KpiAccent.error,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            if (snapshot.collectionHealthScore < 70) ...[
              const SizedBox(height: AksharaSpacing.s4),
              AksharaWarningBanner(
                message:
                    'Collection health below target — review defaulter follow-ups',
                actionLabel: 'View defaulters',
                onAction: () => context.go(RouteNames.financeDefaulters),
              ),
            ],
            const SizedBox(height: AksharaSpacing.s6),
            const AksharaSectionHeader(title: 'Risk students'),
            const SizedBox(height: AksharaSpacing.s3),
            if (snapshot.riskStudents.isEmpty)
              const AksharaEmptyState(
                message: 'No high-risk students for this period.',
                icon: Icons.people_outline,
              )
            else
              for (final student in snapshot.riskStudents)
                Padding(
                  padding: const EdgeInsets.only(bottom: AksharaSpacing.s3),
                  child: AksharaSurfaceCard(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${student.riskScore}%'),
                      ),
                      title: Text(student.studentName),
                      subtitle: Text('₹${student.outstandingAmount} outstanding'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(RouteNames.financeDefaulters),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

final _financeExecutivePeriodProvider = StateProvider<int>((ref) => 0);
