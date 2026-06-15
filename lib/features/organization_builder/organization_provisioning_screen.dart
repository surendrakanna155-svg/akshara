import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import 'organization_builder_models.dart';
import 'organization_builder_providers.dart';

class OrganizationProvisioningScreen extends ConsumerStatefulWidget {
  const OrganizationProvisioningScreen({
    super.key,
    required this.jobId,
  });

  final String jobId;

  @override
  ConsumerState<OrganizationProvisioningScreen> createState() =>
      _OrganizationProvisioningScreenState();
}

class _OrganizationProvisioningScreenState
    extends ConsumerState<OrganizationProvisioningScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      ref.invalidate(provisioningJobProvider(widget.jobId));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(provisioningJobProvider(widget.jobId));

    return Scaffold(
      key: QaTestKeys.organizationBuilderProvisioningScreen,
      appBar: AppBar(
        title: const Text('Provisioning'),
      ),
      body: jobState.when(
        loading: () => const AksharaLoadingState(),
        error: (error, _) =>
            AksharaErrorState(message: 'Unable to load job: $error'),
        data: (job) {
          if (job.status == ProvisioningJobStatus.completed) {
            _pollTimer?.cancel();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                job.organizationName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text('Status: ${job.status.value}'),
              const SizedBox(height: 16),
              const Text(
                'Provisioning Saga',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final step in job.steps)
                _StepTile(step: step),
              if (job.status == ProvisioningJobStatus.completed)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: ListTile(
                    key: QaTestKeys.organizationBuilderProvisioningCompleted,
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Organization provisioned successfully.'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});

  final ProvisioningStep step;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: QaTestKeys.organizationBuilderProvisioningStep(step.id),
      leading: _statusIcon(step.status),
      title: Text(step.label),
      subtitle: Text(step.status.value),
    );
  }

  Widget _statusIcon(ProvisioningStepStatus status) {
    return switch (status) {
      ProvisioningStepStatus.completed =>
        const Icon(Icons.check_circle, color: Colors.green),
      ProvisioningStepStatus.running => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ProvisioningStepStatus.failed =>
        const Icon(Icons.error_outline, color: Colors.red),
      ProvisioningStepStatus.skipped =>
        const Icon(Icons.skip_next, color: Colors.grey),
      ProvisioningStepStatus.pending =>
        const Icon(Icons.radio_button_unchecked, color: Colors.grey),
    };
  }
}
