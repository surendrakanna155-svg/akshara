import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure_mapper.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../admin/admin_layout.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_models.dart';
import 'director_mutations_provider.dart';
import 'director_navigation.dart';
import 'director_providers.dart';
import 'widgets/director_module_scaffold.dart';
import 'widgets/director_shared_widgets.dart';

class DirectorComplianceScreen extends ConsumerWidget {
  const DirectorComplianceScreen({super.key});

  static const _filters = ['All Categories', 'Due Soon', 'Overdue'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorComplianceProvider);
    final canManage = ref.watch(directorCanManageProvider);
    return CopilotContextScope(
      module: 'director',
      screen: 'Director Compliance Monitoring',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.compliance,
        filters: _filters,
        filterTrailing: const DirectorAiAssistantLink(
          screenLabel: 'Director Compliance Monitoring',
        ),
        body: state.when(
          loading: () => const AksharaLoadingState(),
          error: (error, _) => AksharaErrorState.fromFailure(
            apiFailureMapper.fromException(error),
            onRetry: () => ref.invalidate(directorComplianceProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const AksharaEmptyState(
                message: 'No compliance actions pending.',
              );
            }
            // Phones + portrait tablets collapse the 7-column table into stacked
            // cards; landscape/desktop keep the data table. Both paths share the
            // same acknowledge action so the QA key + snackbar are identical.
            if (AdminLayout.useCardLayout(context)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items) ...[
                    _ComplianceCard(
                      item: item,
                      canManage: canManage,
                      onAcknowledge: () => _acknowledge(context, ref, item),
                    ),
                    const SizedBox(height: AksharaSpacing.s3),
                  ],
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AksharaVirtualizedDataTable(
                  columns: const [
                    DataColumn(label: Text('School')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Requirement')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Due')),
                    DataColumn(label: Text('Owner')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rowCount: items.length,
                  rowBuilder: (index) => _buildRow(
                    context,
                    ref,
                    item: items[index],
                    canManage: canManage,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  DataRow _buildRow(
    BuildContext context,
    WidgetRef ref, {
    required DirectorComplianceItem item,
    required bool canManage,
  }) {
    return DataRow(
      cells: [
        DataCell(Text(item.schoolName)),
        DataCell(Text(item.category)),
        DataCell(Text(item.requirement)),
        DataCell(DirectorComplianceStatusChip(status: item.status)),
        DataCell(Text(item.dueDate.toIso8601String().split('T').first)),
        DataCell(Text(item.owner)),
        DataCell(
          item.acknowledged
              ? Icon(Icons.check_circle, color: context.akshara.success)
              : TextButton(
                  key: QaTestKeys.directorComplianceAcknowledgeButton(item.id),
                  onPressed:
                      canManage ? () => _acknowledge(context, ref, item) : null,
                  child: const Text('Acknowledge'),
                ),
        ),
      ],
    );
  }

  Future<void> _acknowledge(
    BuildContext context,
    WidgetRef ref,
    DirectorComplianceItem item,
  ) async {
    await ref
        .read(directorMutationsProvider.notifier)
        .acknowledgeCompliance(complianceId: item.id);
    ref.invalidate(directorComplianceProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: QaTestKeys.directorComplianceAcknowledgedSnackbar,
        content: Text('Compliance item acknowledged.'),
      ),
    );
  }
}

class _ComplianceCard extends StatelessWidget {
  const _ComplianceCard({
    required this.item,
    required this.canManage,
    required this.onAcknowledge,
  });

  final DirectorComplianceItem item;
  final bool canManage;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final due = item.dueDate.toIso8601String().split('T').first;
    return Semantics(
      label: 'Compliance ${item.requirement} for ${item.schoolName}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.schoolName, style: text.titleSmall),
                  ),
                  DirectorComplianceStatusChip(status: item.status),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text('${item.category} · ${item.requirement}',
                  style: text.bodySmall),
              Text('Due $due · Owner ${item.owner}', style: text.bodySmall),
              const SizedBox(height: AksharaSpacing.s2),
              Align(
                alignment: Alignment.centerRight,
                child: item.acknowledged
                    ? Icon(Icons.check_circle, color: context.akshara.success)
                    : TextButton(
                        key: QaTestKeys.directorComplianceAcknowledgeButton(
                            item.id),
                        onPressed: canManage ? onAcknowledge : null,
                        child: const Text('Acknowledge'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
