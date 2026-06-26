import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure_mapper.dart';
import '../../core/tenant/tenant_provider.dart';
import '../../core/repositories/repository_providers.dart';
import '../../shared/widgets/akshara_error_state.dart';
import '../../shared/widgets/akshara_loading_state.dart';
import 'onboarding_provider.dart';
import '../../theme/spacing.dart';

class OnboardingHubScreen extends ConsumerWidget {
  const OnboardingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(onboardingDashboardProvider);
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
              onPressed: () => _runDemoStudentImport(context, ref),
              child: const Text('Preview demo student import'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _sendDemoInvite(context, ref),
              child: const Text('Send demo parent invite'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runDemoStudentImport(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(onboardingRepositoryProvider);
    final query = ref.read(repositoryQueryProvider);
    final result = await repo.previewStudentImport(
      query: query,
      fileName: 'demo_students.csv',
      rows: const [
        {
          'studentName': 'Demo Student',
          'admissionNumber': 'ADM-DEMO-001',
          'classLabel': '8',
          'sectionLabel': 'A',
          'academicYear': '2026-27',
          'parentName': 'Demo Parent',
          'parentPhone': '9876500001',
        },
      ],
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preview ready: ${result.job.validRows} valid rows')),
    );
    ref.invalidate(onboardingDashboardProvider);
  }

  Future<void> _sendDemoInvite(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(onboardingRepositoryProvider);
    final query = ref.read(repositoryQueryProvider);
    await repo.createInvite(
      query: query,
      inviteType: 'parent',
      recipientPhone: '9876500002',
      recipientLabel: 'Demo Parent',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite created')),
    );
    ref.invalidate(onboardingInvitesProvider);
    ref.invalidate(onboardingDashboardProvider);
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
