import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/qa_test_keys.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../../admissions_models.dart';
import '../../leads/admissions_leads_provider.dart';

/// ADM-5: picks a real lead to seed a new application, replacing the old
/// hard-coded 'New Student' placeholder. Reuses the leads future provider so the
/// picker always reflects the live pipeline.
///
/// Returns the selected [AdmissionsLead], or null if the operator cancels.
Future<AdmissionsLead?> showAdmissionsLeadPickerDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showDialog<AdmissionsLead>(
    context: context,
    builder: (dialogContext) => const _LeadPickerDialog(),
  );
}

class _LeadPickerDialog extends ConsumerStatefulWidget {
  const _LeadPickerDialog();

  @override
  ConsumerState<_LeadPickerDialog> createState() => _LeadPickerDialogState();
}

class _LeadPickerDialogState extends ConsumerState<_LeadPickerDialog> {
  AdmissionsLead? _selected;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(admissionsLeadsFutureProvider);

    return AlertDialog(
      title: const Text('Select a lead'),
      content: SizedBox(
        width: 420,
        child: leadsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AksharaSpacing.s6),
            child: AksharaLoadingState(semanticLabel: 'Loading leads'),
          ),
          error: (error, _) => const AksharaEmptyState(
            message: 'Unable to load leads.',
            icon: Icons.error_outline,
          ),
          data: (result) {
            final leads = _query.isEmpty
                ? result.items
                : result.items
                    .where((lead) =>
                        lead.studentName
                            .toLowerCase()
                            .contains(_query.toLowerCase()) ||
                        lead.parentName
                            .toLowerCase()
                            .contains(_query.toLowerCase()) ||
                        lead.id.toLowerCase().contains(_query.toLowerCase()))
                    .toList();
            if (result.items.isEmpty) {
              return const AksharaEmptyState(
                message: 'No leads yet. Create a lead first.',
                icon: Icons.contacts_outlined,
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search leads',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: AksharaSpacing.s3),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final lead in leads)
                        ListTile(
                          key: QaTestKeys.admissionsLeadPickerOption(lead.id),
                          selected: _selected?.id == lead.id,
                          leading: Icon(
                            _selected?.id == lead.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text('${lead.studentName} · ${lead.id}'),
                          subtitle: Text(
                            '${lead.parentName} · Class ${lead.classLabel}',
                          ),
                          contentPadding: EdgeInsets.zero,
                          onTap: () => setState(() => _selected = lead),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.admissionsLeadPickerConfirmButton,
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('Create application'),
        ),
      ],
    );
  }
}
