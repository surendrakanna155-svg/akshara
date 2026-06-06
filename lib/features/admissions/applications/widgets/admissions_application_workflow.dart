import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_kpi_card.dart';
import '../../../../theme/theme_extensions.dart';
import '../../admissions_models.dart';
import '../../widgets/admissions_responsive_grid.dart';

/// Application status workflow summary KPIs for AD-03.
class AdmissionsApplicationWorkflow extends StatelessWidget {
  const AdmissionsApplicationWorkflow({
    super.key,
    required this.summary,
  });

  final ApplicationWorkflowSummary summary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Application workflow: ${summary.draft} draft, ${summary.submitted} submitted, ${summary.underReview} under review, ${summary.approved} approved',
      child: AdmissionsResponsiveGrid(
        desktopColumns: 4,
        tabletColumns: 2,
        mobileColumns: 2,
        children: [
          SizedBox(
            height: 120,
            child: AksharaKpiCard(
              value: '${summary.draft}',
              subtitle: 'Draft',
              accent: KpiAccent.neutral,
              style: AksharaKpiCardStyle.filled,
              icon: Icons.edit_note_outlined,
            ),
          ),
          SizedBox(
            height: 120,
            child: AksharaKpiCard(
              value: '${summary.submitted}',
              subtitle: 'Submitted',
              accent: KpiAccent.primary,
              style: AksharaKpiCardStyle.filled,
              icon: Icons.send_outlined,
            ),
          ),
          SizedBox(
            height: 120,
            child: AksharaKpiCard(
              value: '${summary.underReview}',
              subtitle: 'Under review',
              accent: KpiAccent.warning,
              style: AksharaKpiCardStyle.filled,
              icon: Icons.fact_check_outlined,
            ),
          ),
          SizedBox(
            height: 120,
            child: AksharaKpiCard(
              value: '${summary.approved}',
              subtitle: 'Approved',
              accent: KpiAccent.success,
              style: AksharaKpiCardStyle.filled,
              icon: Icons.verified_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
