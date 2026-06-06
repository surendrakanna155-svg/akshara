import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_layout.dart';
import '../admissions_models.dart';
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
    final isLoading = ref.watch(admissionsFeeHandoffLoadingProvider);
    final isError = ref.watch(admissionsFeeHandoffErrorProvider);
    final isEmpty = ref.watch(admissionsFeeHandoffEmptyProvider);
    final handoffs = ref.watch(admissionsApprovedHandoffsProvider);
    final feeStructures = ref.watch(admissionsFeeStructuresProvider);
    final selectedId = ref.watch(admissionsSelectedHandoffIdProvider);
    final isMobile = AdminLayout.isMobile(context);

    ApprovedStudentHandoff? selected;
    for (final item in handoffs) {
      if (item.id == selectedId) {
        selected = item;
        break;
      }
    }
    selected ??= handoffs.isEmpty ? null : handoffs.first;

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.feeHandoff,
      showFilterBar: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
              child: AksharaLoadingState(
                semanticLabel: 'Loading fee handoff queue',
              ),
            )
          else if (isError)
            const AksharaErrorState(message: 'Unable to load fee handoff data.')
          else if (isEmpty || handoffs.isEmpty)
            const AksharaEmptyState(
              message: 'No approved students ready for fee handoff.',
              icon: Icons.account_balance_wallet_outlined,
            )
          else if (isMobile) ...[
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
                onSendToFinance: () {},
              ),
            ],
          ] else
            Row(
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
                          onSendToFinance: () {},
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
