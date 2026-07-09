import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure_mapper.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/utils/whatsapp_launcher.dart';
import '../../core/widgets/whatsapp_contact_button.dart';
import '../../shared/widgets/akshara_error_state.dart';
import '../../shared/widgets/akshara_loading_state.dart';
import 'onboarding_models.dart';
import 'onboarding_provider.dart';
import '../../theme/spacing.dart';

/// Gap-remediation #10 — invite creation is honest about delivery: creating an
/// invite only ever generates a link (`status = 'pending'`); it is marked
/// 'sent' server-side ONLY after this screen confirms a real WhatsApp launch
/// (see [WhatsAppContactButton]'s `onSent`), matching whatsapp_launcher.dart's
/// established "review and send yourself" pattern used across the app.
class OnboardingHubScreen extends ConsumerWidget {
  const OnboardingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(onboardingDashboardProvider);
    final invites = ref.watch(onboardingInvitesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('School Onboarding')),
      body: dashboard.when(
        loading: () => const AksharaLoadingState(),
        error: (error, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(error),
          onRetry: () => ref.invalidate(onboardingDashboardProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            _MetricRow(
              label: 'Pending invites',
              value: '${data.pendingInvites}',
            ),
            _MetricRow(
              label: 'Total invites',
              value: '${data.totalInvites}',
            ),
            const SizedBox(height: 16),
            const Text('Recent import jobs', style: TextStyle(fontWeight: FontWeight.bold)),
            if (data.recentJobs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s3),
                child: Text('No import jobs yet.'),
              )
            else
              ...data.recentJobs.map(
                (job) => ListTile(
                  title: Text(job.fileName),
                  subtitle: Text('${job.importType} · ${job.status} · ${job.validRows}/${job.totalRows} valid'),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _openInviteForm(context, ref),
              child: const Text('Invite parent / teacher / student'),
            ),
            const SizedBox(height: 16),
            const Text('Invites', style: TextStyle(fontWeight: FontWeight.bold)),
            invites.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s3),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s3),
                child: Text('Unable to load invites: $error'),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s3),
                      child: Text('No invites yet.'),
                    )
                  : Column(
                      children: [
                        for (final invite in items)
                          _InviteTile(
                            invite: invite,
                            onSent: () => _onInviteSent(context, ref, invite),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInviteForm(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<_InviteDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: const _InviteFormSheet(),
      ),
    );
    if (draft == null || !context.mounted) return;

    final repo = ref.read(onboardingRepositoryProvider);
    final query = ref.read(repositoryQueryProvider);
    try {
      await repo.createInvite(
        query: query,
        inviteType: draft.inviteType,
        recipientPhone: draft.phone,
        recipientLabel: draft.label,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create invite: $error')),
      );
      return;
    }
    if (!context.mounted) return;
    ref.invalidate(onboardingInvitesProvider);
    ref.invalidate(onboardingDashboardProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Invite link generated — send it via WhatsApp below to deliver it.',
        ),
      ),
    );
  }

  Future<void> _onInviteSent(
    BuildContext context,
    WidgetRef ref,
    OnboardingInvite invite,
  ) async {
    final repo = ref.read(onboardingRepositoryProvider);
    final query = ref.read(repositoryQueryProvider);
    try {
      await repo.markInviteSent(query: query, inviteId: invite.id);
    } catch (error) {
      // Best-effort confirmation: the WhatsApp chat DID open (that's what
      // triggered this callback) — a failure here only means the status
      // couldn't be confirmed server-side, so surface it but don't block.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent, but could not confirm status: $error')),
        );
      }
      return;
    }
    ref.invalidate(onboardingInvitesProvider);
    ref.invalidate(onboardingDashboardProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite sent via WhatsApp.')),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AksharaSpacing.s1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))],
      ),
    );
  }
}

/// One invite row. A 'pending' invite (link generated, nothing sent yet) gets
/// a real WhatsApp send action; any other status is a plain read-only summary.
class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite, required this.onSent});

  final OnboardingInvite invite;
  final Future<void> Function() onSent;

  @override
  Widget build(BuildContext context) {
    final message =
        'Welcome to Akshara ERP — ${invite.recipientLabel}. Open: ${invite.deepLink}';
    return ListTile(
      title: Text(invite.recipientLabel),
      subtitle: Text('${invite.inviteType} · ${invite.recipientPhone} · ${invite.status}'),
      trailing: invite.status == 'pending'
          ? WhatsAppContactButton(
              phone: invite.recipientPhone,
              message: message,
              label: 'Send via WhatsApp',
              style: WhatsAppButtonStyle.text,
              onSent: onSent,
            )
          : null,
    );
  }
}

class _InviteDraft {
  const _InviteDraft({
    required this.label,
    required this.phone,
    required this.inviteType,
  });

  final String label;
  final String phone;
  final String inviteType;
}

class _InviteFormSheet extends StatefulWidget {
  const _InviteFormSheet();

  @override
  State<_InviteFormSheet> createState() => _InviteFormSheetState();
}

class _InviteFormSheetState extends State<_InviteFormSheet> {
  final _labelController = TextEditingController();
  final _phoneController = TextEditingController();
  String _inviteType = 'parent';
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelController.text.trim();
    final phone = _phoneController.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (WhatsAppLauncher.resolvePhoneDigits(phone) == null) {
      setState(() => _error = 'Enter a valid phone number (at least 10 digits)');
      return;
    }
    Navigator.of(context).pop(
      _InviteDraft(label: label, phone: phone, inviteType: _inviteType),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AksharaSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invite someone', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AksharaSpacing.s3),
          DropdownButtonFormField<String>(
            initialValue: _inviteType,
            decoration: const InputDecoration(
              labelText: 'Invite type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'parent', child: Text('Parent')),
              DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
              DropdownMenuItem(value: 'student', child: Text('Student')),
            ],
            onChanged: (v) => setState(() => _inviteType = v ?? _inviteType),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AksharaSpacing.s3),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AksharaSpacing.s2),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AksharaSpacing.s4),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Generate invite link'),
            ),
          ),
        ],
      ),
    );
  }
}
