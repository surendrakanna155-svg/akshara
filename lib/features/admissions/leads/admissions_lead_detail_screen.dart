import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure.dart';
import '../../../core/security/permissions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../admin/admin_content_scaffold.dart';
import '../../admin/admin_layout.dart';
import '../../admin/admin_shell.dart';
import '../admissions_workflow_actions.dart';
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
    final detailAsync = ref.watch(admissionsLeadDetailDataProvider(leadId));
    final isLoading = ref.watch(admissionsLeadDetailLoadingProvider(leadId)) ||
        detailAsync.isLoading;
    final isError = ref.watch(admissionsLeadDetailErrorProvider(leadId)) ||
        detailAsync.hasError;
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
            AksharaErrorState.fromFailure(
              const ApiFailure(
                type: ApiFailureType.unknown,
                message: 'Unable to load lead detail.',
                code: 'LEAD_DETAIL',
              ),
              onRetry: () =>
                  ref.invalidate(admissionsLeadDetailDataProvider(leadId)),
            )
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
            const SizedBox(height: AksharaSpacing.s4),
            Wrap(
              spacing: AksharaSpacing.s2,
              runSpacing: AksharaSpacing.s2,
              children: [
                AksharaManageAction(
                  permission: Permission.manageAdmissions,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        showAddLeadNoteDialog(context, ref, leadId),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Add note'),
                  ),
                ),
                AksharaManageAction(
                  permission: Permission.manageAdmissions,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        showAddFollowUpDialog(context, ref, leadId),
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('Add follow-up'),
                  ),
                ),
                AksharaManageAction(
                  permission: Permission.manageAdmissions,
                  child: OutlinedButton.icon(
                    onPressed: () => showAddLeadNoteDialog(
                      context,
                      ref,
                      leadId,
                      activityType: 'call',
                      dialogTitle: 'Log call',
                      fieldLabel: 'Call summary',
                      successMessage: 'Call logged',
                    ),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Log call'),
                  ),
                ),
                AksharaManageAction(
                  permission: Permission.manageAdmissions,
                  child: OutlinedButton.icon(
                    onPressed: () => showAddLeadNoteDialog(
                      context,
                      ref,
                      leadId,
                      activityType: 'whatsapp',
                      dialogTitle: 'Log WhatsApp',
                      fieldLabel: 'WhatsApp message',
                      successMessage: 'WhatsApp logged',
                    ),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Log WhatsApp'),
                  ),
                ),
                AksharaManageAction(
                  permission: Permission.manageAdmissions,
                  child: OutlinedButton.icon(
                    onPressed: () => showChangeLeadStageDialog(
                      context,
                      ref,
                      profile.lead,
                    ),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Change stage'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
