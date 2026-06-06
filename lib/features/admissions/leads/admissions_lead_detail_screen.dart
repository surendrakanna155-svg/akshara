import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_warning_banner.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_layout.dart';
import '../../admin/admin_shell.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_sub_nav.dart';
import 'admissions_lead_detail_provider.dart';
import 'widgets/admissions_lead_followup_history.dart';
import 'widgets/admissions_lead_profile_panel.dart';
import 'widgets/admissions_lead_score_panel.dart';
import 'widgets/admissions_lead_status_progression.dart';
import 'widgets/admissions_lead_timeline.dart';

/// AD-04 — Lead Detail with profile, timeline, and progression.
class AdmissionsLeadDetailScreen extends ConsumerWidget {
  const AdmissionsLeadDetailScreen({
    super.key,
    required this.leadId,
  });

  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(admissionsLeadDetailLoadingProvider(leadId));
    final isError = ref.watch(admissionsLeadDetailErrorProvider(leadId));
    final isEmpty = ref.watch(admissionsLeadDetailEmptyProvider(leadId));
    final profile = ref.watch(admissionsLeadDetailProvider(leadId));
    final isMobile = AdminLayout.isMobile(context);

    return AdminContentScaffold(
      breadcrumbs: admissionsLeadDetailBreadcrumbs(
        leadLabel: profile?.lead.studentName ?? leadId,
      ),
      onMenuTap: adminShellMenuTap(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AksharaSpacing.s4),
          const AdmissionsSubNav(current: AdmissionsScreen.leads),
          const SizedBox(height: AksharaSpacing.s4),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
              child: AksharaLoadingState(semanticLabel: 'Loading lead detail'),
            )
          else if (isError)
            const AksharaErrorState(message: 'Unable to load lead detail.')
          else if (isEmpty || profile == null)
            const AksharaEmptyState(
              message: 'Lead not found.',
              icon: Icons.person_search_outlined,
            )
          else ...[
            if (profile.acquisitionReadOnly)
              const AksharaWarningBanner(
                message:
                    'Acquisition data from Marketing is read-only on this lead.',
                compactMessage: true,
                horizontalPaddingOnly: true,
                semanticLabel: 'Marketing acquisition data is read-only',
              ),
            const SizedBox(height: AksharaSpacing.s4),
            if (isMobile) ...[
              AdmissionsLeadProfilePanel(profile: profile),
              const SizedBox(height: AksharaSpacing.s4),
              AdmissionsLeadScorePanel(profile: profile),
              const SizedBox(height: AksharaSpacing.s4),
              AdmissionsLeadStatusProgression(steps: profile.statusSteps),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AdmissionsLeadProfilePanel(profile: profile),
                  ),
                  const SizedBox(width: AksharaSpacing.s4),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        AdmissionsLeadScorePanel(profile: profile),
                        const SizedBox(height: AksharaSpacing.s4),
                        AdmissionsLeadStatusProgression(
                          steps: profile.statusSteps,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AksharaSpacing.s6),
            const AksharaSectionHeader(title: 'Activity timeline'),
            const SizedBox(height: AksharaSpacing.s3),
            AdmissionsLeadTimeline(activities: profile.activities),
            const SizedBox(height: AksharaSpacing.s6),
            const AksharaSectionHeader(title: 'Follow-up history'),
            const SizedBox(height: AksharaSpacing.s3),
            AdmissionsLeadFollowUpHistory(records: profile.followUpHistory),
          ],
        ],
      ),
    );
  }
}
