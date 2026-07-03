import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/permissions.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/akshara_view_action.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/theme_extensions.dart';
import '../phase5/phase5_providers.dart';
import 'operations_hub_mutations_provider.dart';
import 'operations_hub_navigation.dart';
import '../../theme/spacing.dart';

class OperationsHubScreen extends ConsumerWidget {
  const OperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(operationsHubProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Operations Hub'),
        actions: [
          AksharaViewAction(
            permission: Permission.viewOperationsHub,
            child: IconButton(
              key: QaTestKeys.operationsHubExportButton,
              tooltip: 'Export daily report',
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _exportDailyReport(context, ref),
            ),
          ),
        ],
      ),
      body: hub.when(
        data: (h) {
          return ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              Card(
                child: ListTile(
                  title: const Text('School Health'),
                  trailing: Text(
                    '${h.schoolHealth}/100',
                    style: context.aksharaText.titleLarge,
                  ),
                ),
              ),
              Text('Daily Summary',
                  style: context.aksharaText.titleMedium),
              ListTile(
                title: const Text('Attendance'),
                trailing: Text('${h.dailySummary.attendancePct}%'),
              ),
              ListTile(
                title: const Text('Collections today'),
                trailing: Text(
                    '₹${h.dailySummary.collectionsToday.toStringAsFixed(0)}'),
              ),
              ListTile(
                title: const Text('Communications'),
                trailing: Text('${h.dailySummary.communicationsToday}'),
              ),
              const SizedBox(height: 8),
              Text('Critical Alerts',
                  style: context.aksharaText.titleMedium),
              if (h.criticalAlerts.isEmpty)
                const AksharaEmptyState(
                  message:
                      'No critical alerts — school operations are running smoothly today.',
                )
              else
                ...h.criticalAlerts.map(
                  (a) => ListTile(
                    key: QaTestKeys.operationsHubAlertTile(a.id),
                    onTap: () => context.go(operationsHubModuleRoute(a.module)),
                    title: Text(a.title),
                    subtitle: Text(a.module),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(label: Text(a.severity)),
                        IconButton(
                          key: QaTestKeys.operationsHubDismissAlertButton(a.id),
                          tooltip: 'Dismiss alert',
                          icon: const Icon(Icons.close),
                          onPressed: () => _dismissAlert(
                            context,
                            ref,
                            alertId: a.id,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text('Pending Actions',
                  style: context.aksharaText.titleMedium),
              if (h.pendingActions.isEmpty)
                const AksharaEmptyState(
                  message:
                      'No pending actions — all operational tasks are up to date.',
                )
              else
                ...h.pendingActions.map(
                  (a) => ListTile(
                    key: QaTestKeys.operationsHubActionTile(a.id),
                    onTap: () => context.go(operationsHubModuleRoute(a.module)),
                    title: Text(a.title),
                    subtitle: Text(a.module),
                    trailing: FilledButton.tonal(
                      key: QaTestKeys.operationsHubCompleteActionButton(a.id),
                      onPressed: () => _completeAction(
                        context,
                        ref,
                        actionId: a.id,
                      ),
                      child: const Text('Complete'),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text('Widgets', style: context.aksharaText.titleMedium),
              ListTile(
                title: const Text('Student risk alerts'),
                trailing: Text('${h.widgets.studentRiskAlerts}'),
              ),
              ListTile(
                title: const Text('Employee risk alerts'),
                trailing: Text('${h.widgets.employeeRiskAlerts}'),
              ),
              ListTile(
                title: const Text('Inventory alerts'),
                trailing: Text('${h.widgets.inventoryAlerts}'),
              ),
              ListTile(
                title: const Text('Fee alerts'),
                trailing: Text('${h.widgets.feeAlerts}'),
              ),
            ],
          );
        },
        loading: () =>
            const AksharaLoadingState(semanticLabel: 'Loading operations hub'),
        error: (e, _) => AksharaErrorState(
          message: 'Unable to load operations hub.',
          onRetry: () => ref.invalidate(operationsHubProvider),
        ),
      ),
    );
  }

  Future<void> _exportDailyReport(BuildContext context, WidgetRef ref) async {
    final Uint8List? bytes;
    try {
      bytes = await ref
          .read(exportOperationsHubReportProvider.notifier)
          .execute();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to export daily report: $error')),
      );
      return;
    }
    if (!context.mounted || bytes == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.operationsHubExportSuccessSnackbar,
        content: Text('Daily school report PDF generated'),
      ),
    );
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Wrap(
              runSpacing: AksharaSpacing.s3,
              children: [
                ListTile(
                  key: QaTestKeys.operationsHubExportPrintButton,
                  leading: const Icon(Icons.print_outlined),
                  title: const Text('Print daily report'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref
                        .read(operationsHubPdfServiceProvider)
                        .printDailyReport(bytes!);
                  },
                ),
                ListTile(
                  key: QaTestKeys.operationsHubExportShareButton,
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share daily report'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref
                        .read(operationsHubPdfServiceProvider)
                        .shareDailyReport(
                          bytes: bytes!,
                          fileName: 'daily_school_report.pdf',
                        );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _dismissAlert(
    BuildContext context,
    WidgetRef ref, {
    required String alertId,
  }) async {
    final result = await ref
        .read(dismissOperationsAlertProvider.notifier)
        .execute(alertId);
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.operationsHubAlertDismissedSnackbar,
        content: Text('Alert dismissed.'),
      ),
    );
  }

  Future<void> _completeAction(
    BuildContext context,
    WidgetRef ref, {
    required String actionId,
  }) async {
    final result = await ref
        .read(completeOperationsActionProvider.notifier)
        .execute(actionId);
    if (result == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.operationsHubActionCompletedSnackbar,
        content: Text('Action marked as complete.'),
      ),
    );
  }
}
