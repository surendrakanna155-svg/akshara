import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/whatsapp_contact_button.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/akshara_empty_state.dart';
import '../../../shared/widgets/akshara_error_state.dart';
import '../../../shared/widgets/akshara_loading_state.dart';
import '../../../shared/widgets/akshara_section_header.dart';
import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../alumni_models.dart';
import '../alumni_navigation.dart';
import '../alumni_providers.dart';
import '../widgets/alumni_module_scaffold.dart';

/// AL-03 — Alumni Profile (child route, not in sub-nav).
class AlumniProfileScreen extends ConsumerWidget {
  const AlumniProfileScreen({
    super.key,
    required this.alumniId,
  });

  final String alumniId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(alumniProfileLoadingProvider);
    final isError = ref.watch(alumniProfileErrorProvider);
    final detail = ref.watch(alumniDetailProvider(alumniId));

    return AlumniModuleScaffold(
      screen: AlumniScreen.registry,
      breadcrumbs: detail == null
          ? alumniBreadcrumbs(AlumniScreen.registry)
          : alumniProfileBreadcrumbs(alumniName: detail.alumni.name),
      showFilterBar: false,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        detail: detail,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required AlumniDetail? detail,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(semanticLabel: 'Loading alumni profile'),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load alumni profile.',
      );
    }

    if (detail == null) {
      return const AksharaEmptyState(
        message: 'Alumni not found.',
        icon: Icons.person_off_outlined,
      );
    }

    final alumni = detail.alumni;
    final text = context.aksharaText;
    final isMobile = AdminLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: 'Alumni profile for ${alumni.name}',
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(AksharaSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(alumni.name, style: text.headlineSmall),
                      ),
                      _EngagementChip(status: alumni.engagementStatus),
                    ],
                  ),
                  const SizedBox(height: AksharaSpacing.s2),
                  Text(
                    'Batch ${alumni.batchYear} · ${alumni.program}',
                    style: text.bodyMedium,
                  ),
                  Text(alumni.currentRole, style: text.bodyMedium),
                  const SizedBox(height: AksharaSpacing.s3),
                  Text('${alumni.email} · ${alumni.phone}', style: text.bodySmall),
                  const SizedBox(height: AksharaSpacing.s3),
                  Wrap(
                    spacing: AksharaSpacing.s3,
                    runSpacing: AksharaSpacing.s2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      WhatsAppContactButton(
                        phone: alumni.phone,
                        label: 'WhatsApp',
                        message:
                            'Hello ${alumni.name}, greetings from the alumni '
                            'relations office. ',
                      ),
                      OutlinedButton(
                        onPressed: () => context.go(
                          RouteNames.sisStudentDetail(alumni.sisStudentId),
                        ),
                        child: Text('SIS: ${alumni.sisStudentId}'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go(RouteNames.alumniDonations),
                        child: Text('Donated ${alumni.totalDonated}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AksharaSpacing.s6),
        if (isMobile) ...[
          _EmploymentSection(history: detail.employmentHistory),
          const SizedBox(height: AksharaSpacing.s4),
          _DonationSection(items: detail.donationHistory),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _EmploymentSection(history: detail.employmentHistory)),
              const SizedBox(width: AksharaSpacing.s6),
              Expanded(child: _DonationSection(items: detail.donationHistory)),
            ],
          ),
        const SizedBox(height: AksharaSpacing.s6),
        const AksharaSectionHeader(title: 'Mentorship & events'),
        const SizedBox(height: AksharaSpacing.s3),
        Text(detail.mentorshipRole, style: text.bodyMedium),
        const SizedBox(height: AksharaSpacing.s2),
        if (detail.eventsAttended.isNotEmpty)
          Text(
            'Events: ${detail.eventsAttended.join(', ')}',
            style: text.bodySmall,
          ),
      ],
    );
  }
}

class _EmploymentSection extends StatelessWidget {
  const _EmploymentSection({required this.history});

  final List<AlumniEmploymentHistory> history;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AksharaSectionHeader(title: 'Employment history'),
            const SizedBox(height: AksharaSpacing.s3),
            for (final item in history) ...[
              Text(item.organization, style: text.titleSmall),
              Text('${item.role} · ${item.period}', style: text.bodySmall),
              const SizedBox(height: AksharaSpacing.s3),
            ],
          ],
        ),
      ),
    );
  }
}

class _DonationSection extends StatelessWidget {
  const _DonationSection({required this.items});

  final List<AlumniDonationHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AksharaSectionHeader(title: 'Donation history'),
            const SizedBox(height: AksharaSpacing.s3),
            if (items.isEmpty)
              Text('No donations recorded.', style: text.bodySmall)
            else
              for (final item in items) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.amount} — ${item.campaign}',
                        style: text.bodyMedium,
                      ),
                    ),
                    Text(item.date, style: text.bodySmall),
                  ],
                ),
                Text(
                  'Receipt ${item.financeReceiptId}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AksharaSpacing.s3),
              ],
          ],
        ),
      ),
    );
  }
}

class _EngagementChip extends StatelessWidget {
  const _EngagementChip({required this.status});

  final AlumniEngagementStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      AlumniEngagementStatus.active => ('Active', KpiAccent.success),
      AlumniEngagementStatus.inactive => ('Inactive', KpiAccent.neutral),
      AlumniEngagementStatus.pending => ('Pending', KpiAccent.warning),
    };

    return AksharaStatusChip(label: label, tone: tone);
  }
}
