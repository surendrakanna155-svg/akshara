import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
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
          error: (error, _) => AksharaErrorState(message: '$error'),
          data: (items) {
            if (items.isEmpty) {
              return const AksharaEmptyState(
                message: 'No compliance actions pending.',
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
              ? const Icon(Icons.check_circle, color: Colors.green)
              : TextButton(
                  key: QaTestKeys.directorComplianceAcknowledgeButton(item.id),
                  onPressed: canManage
                      ? () async {
                          await ref
                              .read(directorMutationsProvider.notifier)
                              .acknowledgeCompliance(complianceId: item.id);
                          ref.invalidate(directorComplianceProvider);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              key: QaTestKeys
                                  .directorComplianceAcknowledgedSnackbar,
                              content: Text('Compliance item acknowledged.'),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Acknowledge'),
                ),
        ),
      ],
    );
  }
}
