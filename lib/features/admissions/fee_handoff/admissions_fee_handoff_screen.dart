import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../../../core/repositories/paginated_result.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../admissions_workflow_actions.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_module_scaffold.dart';
import 'admissions_fee_handoff_provider.dart';
import 'widgets/admissions_approved_students_list.dart';
import 'widgets/admissions_fee_handoff_panel.dart';

/// AD-08 — Fee setup handoff to Finance and Student SIS.
class AdmissionsFeeHandoffScreen extends ConsumerWidget {
  const AdmissionsFeeHandoffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(admissionsFeeHandoffViewStateProvider);
    final feeStructures = ref.watch(admissionsFeeStructuresProvider);
    final selectedId = ref.watch(admissionsSelectedHandoffIdProvider);
    final isMobile = AdminLayout.isMobile(context);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.feeHandoff,
      showFilterBar: false,
      body: AdmissionsAsyncBody<PaginatedResult<ApprovedStudentHandoff>>(
        state: viewState,
        loadingLabel: 'Loading fee handoff queue',
        emptyMessage: 'No approved students ready for fee handoff.',
        emptyIcon: Icons.account_balance_wallet_outlined,
        onRetry: () => retryAdmissionsFuture(
          ref,
          admissionsApprovedHandoffsFutureProvider,
        ),
        builder: (result) {
          final handoffs = result.items;
          ApprovedStudentHandoff? selected;
          for (final item in handoffs) {
            if (item.id == selectedId) {
              selected = item;
              break;
            }
          }
          selected ??= handoffs.isEmpty ? null : handoffs.first;

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdmissionsApprovedStudentsList(
                  handoffs: handoffs,
                  selectedId: selectedId ?? selected?.id,
                  onSelect: (item) => ref
                      .read(admissionsSelectedHandoffIdProvider.notifier)
                      .state = item.id,
                ),
                if (selected != null) ...[
                  const SizedBox(height: AksharaSpacing.s4),
                  AdmissionsFeeHandoffPanel(
                    handoff: selected,
                    feeStructures: feeStructures,
                    onSendToFinance: () => runSendToFinance(
                      context,
                      ref,
                      handoffId: selected!.id,
                      feeStructureId: selected.selectedFeeStructureId ??
                          (feeStructures.isNotEmpty
                              ? feeStructures.first.id
                              : ''),
                    ),
                  ),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: AdmissionsApprovedStudentsList(
                  handoffs: handoffs,
                  selectedId: selectedId ?? selected?.id,
                  onSelect: (item) => ref
                      .read(admissionsSelectedHandoffIdProvider.notifier)
                      .state = item.id,
                ),
              ),
              const SizedBox(width: AksharaSpacing.s4),
              Expanded(
                flex: 3,
                child: selected == null
                    ? const SizedBox.shrink()
                    : AdmissionsFeeHandoffPanel(
                        handoff: selected,
                        feeStructures: feeStructures,
                        onSendToFinance: () => runSendToFinance(
                      context,
                      ref,
                      handoffId: selected!.id,
                      feeStructureId: selected.selectedFeeStructureId ??
                          (feeStructures.isNotEmpty
                              ? feeStructures.first.id
                              : ''),
                    ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
