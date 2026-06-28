import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/reports/akshara_report_export_service.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../admin/admin_layout.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_models.dart';
import 'director_mutations_provider.dart';
import 'director_navigation.dart';
import 'director_providers.dart';
import 'widgets/director_module_scaffold.dart';
import 'widgets/director_shared_widgets.dart';
import '../../core/errors/api_failure_mapper.dart';

class DirectorReportsScreen extends ConsumerStatefulWidget {
  const DirectorReportsScreen({super.key});

  @override
  ConsumerState<DirectorReportsScreen> createState() =>
      _DirectorReportsScreenState();
}

class _DirectorReportsScreenState extends ConsumerState<DirectorReportsScreen> {
  String? _generatedSummary;
  bool _isGeneratingSummary = false;

  static const _filters = ['Board Pack', 'Quarterly', 'Export Schedule'];

  @override
  Widget build(BuildContext context) {
    final reportsState = ref.watch(directorReportsProvider);
    final canManage = ref.watch(directorCanManageProvider);

    return CopilotContextScope(
      module: 'director',
      screen: 'Director Strategic Reports',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.reports,
        filters: _filters,
        filterTrailing: const DirectorAiAssistantLink(
          screenLabel: 'Director Strategic Reports',
          buttonKey: QaTestKeys.directorCopilotLinkButton,
        ),
        body: reportsState.when(
          loading: () => const AksharaLoadingState(),
          error: (error, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(error)),
          data: (reports) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AksharaSectionHeader(title: 'Strategic report catalog'),
              const SizedBox(height: AksharaSpacing.s3),
              // Phones stretch each report card full-width (the fixed 360 width
              // overflows the ~358px phone content column); tablet/desktop keep
              // the wrapped grid.
              if (AdminLayout.useCardLayout(context))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final report in reports) ...[
                      _reportCard(context, report, canManage),
                      const SizedBox(height: AksharaSpacing.s3),
                    ],
                  ],
                )
              else
                Wrap(
                  spacing: AksharaSpacing.s3,
                  runSpacing: AksharaSpacing.s3,
                  children: [
                    for (final report in reports)
                      SizedBox(
                        width: 360,
                        child: _reportCard(context, report, canManage),
                      ),
                  ],
                ),
              const SizedBox(height: AksharaSpacing.s5),
              Row(
                children: [
                  // Stretch the button to the available width: its long label
                  // overflows a fixed-width Row on narrow phones (~358px content
                  // column → 109px overflow). Expanded lets it wrap/shrink to fit.
                  Expanded(
                    child: FilledButton.icon(
                      key: QaTestKeys.directorReportsGenerateSummaryButton,
                      onPressed: _isGeneratingSummary ? null : _generateSummary,
                      icon: _isGeneratingSummary
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Generate AI Executive Summary'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s3),
              DirectorExecutiveSummaryCard(
                summary: _generatedSummary ??
                    'Generate a board-ready executive brief from aggregated portfolio metrics.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportCard(
    BuildContext context,
    DirectorReportItem report,
    bool canManage,
  ) {
    return Card(
      child: ListTile(
        title: Text(report.title),
        subtitle: Text(report.description),
        trailing: TextButton(
          key: QaTestKeys.directorReportExportButton(report.id),
          onPressed: canManage ? () => _exportReport(context, report.id) : null,
          child: const Text('Export'),
        ),
      ),
    );
  }

  Future<void> _generateSummary() async {
    setState(() => _isGeneratingSummary = true);
    try {
      final summary =
          await ref.read(directorRepositoryProvider).generateExecutiveSummary(
                query: ref.read(repositoryQueryProvider),
                focusArea: 'strategic_reports',
              );
      if (!mounted) return;
      setState(() => _generatedSummary = summary);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate executive summary: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSummary = false);
      }
    }
  }

  Future<void> _exportReport(BuildContext context, String reportId) async {
    try {
      final pack = await ref
          .read(directorMutationsProvider.notifier)
          .exportReport(reportId: reportId);
      await ref
          .read(aksharaReportExportServiceProvider)
          .shareDirectorBoardPackPdf(pack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: QaTestKeys.directorReportExportedSnackbar,
          content: Text('${pack.title} ready (${pack.schools.length} schools)'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export report: $error')),
      );
    }
  }
}
