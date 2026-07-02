import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../../../admin/admin_layout.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_lead_score_chip.dart';
import '../../widgets/admissions_stage_badge.dart';

/// Leads management table (AD-02) with mobile card fallback.
class AdmissionsLeadsTable extends StatelessWidget {
  const AdmissionsLeadsTable({
    super.key,
    required this.leads,
    this.onView,
    this.onAssign,
    this.selectedLeadIds = const <String>{},
    this.onSelectChanged,
  });

  final List<AdmissionsLead> leads;
  final void Function(AdmissionsLead lead)? onView;
  final void Function(AdmissionsLead lead)? onAssign;

  /// ADM-3: ids currently ticked for a bulk action.
  final Set<String> selectedLeadIds;

  /// ADM-3: called when a row's checkbox toggles. Null disables selection.
  final void Function(AdmissionsLead lead, bool selected)? onSelectChanged;

  static const _columns = [
    DataColumn(label: Text('ID')),
    DataColumn(label: Text('Parent / Student')),
    DataColumn(label: Text('Class')),
    DataColumn(label: Text('Phone')),
    DataColumn(label: Text('Source')),
    DataColumn(label: Text('Campaign')),
    DataColumn(label: Text('Stage')),
    DataColumn(label: Text('Counselor')),
    DataColumn(label: Text('Score')),
    DataColumn(label: Text('Next F/U')),
    DataColumn(label: Text('Actions')),
  ];

  @override
  Widget build(BuildContext context) {
    if (AdminLayout.useCardLayout(context)) {
      return Column(
        children: [
          for (final lead in leads) ...[
            _LeadMobileCard(
              lead: lead,
              onView: onView,
              onAssign: onAssign,
              selected: selectedLeadIds.contains(lead.id),
              onSelectChanged: onSelectChanged,
            ),
            const SizedBox(height: AksharaSpacing.s3),
          ],
        ],
      );
    }

    return AksharaVirtualizedDataTable(
      columns: _columns,
      rowCount: leads.length,
      showCheckboxColumn: onSelectChanged != null,
      dataRowMinHeight: 56,
      semanticLabel: 'Leads table, ${leads.length} records',
      rowBuilder: (index) => _buildRow(context, leads[index]),
    );
  }

  DataRow _buildRow(BuildContext context, AdmissionsLead lead) {
    return DataRow(
      selected: selectedLeadIds.contains(lead.id),
      onSelectChanged: onSelectChanged == null
          ? null
          : (value) => onSelectChanged!(lead, value ?? false),
      cells: [
        DataCell(Text(lead.id)),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(lead.parentName),
              Text(
                lead.studentName,
                style: context.aksharaText.bodySmall.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(lead.classLabel)),
        DataCell(Text(lead.phone)),
        DataCell(Text(lead.source.label)),
        DataCell(Text(lead.campaign)),
        DataCell(AdmissionsStageBadge(stage: lead.stage)),
        DataCell(Text(lead.counselor)),
        DataCell(AdmissionsLeadScoreChip(score: lead.score)),
        DataCell(Text(lead.nextFollowUpLabel)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20),
                tooltip: 'View',
                onPressed: onView == null ? null : () => onView!(lead),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                tooltip: 'Assign',
                onPressed: onAssign == null ? null : () => onAssign!(lead),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeadMobileCard extends StatelessWidget {
  const _LeadMobileCard({
    required this.lead,
    this.onView,
    this.onAssign,
    this.selected = false,
    this.onSelectChanged,
  });

  final AdmissionsLead lead;
  final void Function(AdmissionsLead lead)? onView;
  final void Function(AdmissionsLead lead)? onAssign;
  final bool selected;
  final void Function(AdmissionsLead lead, bool selected)? onSelectChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      label: 'Lead ${lead.id}, ${lead.studentName}, ${lead.stage.label}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AksharaSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onSelectChanged != null)
                    Padding(
                      padding: const EdgeInsets.only(right: AksharaSpacing.s2),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: selected,
                          onChanged: (value) =>
                              onSelectChanged!(lead, value ?? false),
                        ),
                      ),
                    ),
                  Text(
                    lead.id,
                    style: text.labelLarge.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  AdmissionsLeadScoreChip(score: lead.score),
                ],
              ),
              Text(
                '${lead.studentName} · Class ${lead.classLabel}',
                style: text.bodyMedium,
              ),
              Text(
                lead.parentName,
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              AdmissionsStageBadge(stage: lead.stage),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                '${lead.source.label} · ${lead.counselor}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              Text(
                'Next: ${lead.nextFollowUpLabel}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Row(
                children: [
                  TextButton(
                    onPressed: onView == null ? null : () => onView!(lead),
                    child: const Text('View'),
                  ),
                  TextButton(
                    onPressed: onAssign == null ? null : () => onAssign!(lead),
                    child: const Text('Assign'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
