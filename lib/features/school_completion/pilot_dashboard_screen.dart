import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/widgets.dart';
import 'school_completion_providers.dart';

class PilotDashboardScreen extends ConsumerWidget {
  const PilotDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(pilotDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Real School Pilot Toolkit')),
      body: dashboard.when(
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState(message: '$e'),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('Pilot success score'),
              trailing: Text('${data.pilotScore}/100',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ListTile(
              title: const Text('Onboarding'),
              subtitle: Text(data.onboardingStatus),
              trailing: Icon(
                data.setupWizardCompleted ? Icons.check_circle : Icons.pending,
                color: data.setupWizardCompleted ? Colors.green : Colors.orange,
              ),
            ),
            const Divider(),
            const Text('Import health', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              title: Text('${data.importHealth.committedJobs}/${data.importHealth.totalJobs} jobs committed'),
              subtitle: Text('${data.importHealth.failedRows} failed rows'),
            ),
            const Divider(),
            const Text('Teacher activation', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              title: Text('${data.teacherActivation.active}/${data.teacherActivation.total} active'),
              trailing: Text('${data.teacherActivation.activationRate}%'),
            ),
            const Divider(),
            const Text('Parent activation', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              title: Text('${data.parentActivation.active}/${data.parentActivation.total} active'),
              trailing: Text('${data.parentActivation.activationRate}%'),
            ),
            const Divider(),
            const Text('OTP delivery (7 days)', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              title: Text('${data.otpDelivery.sentLast7Days} sent'),
              subtitle: Text('${data.otpDelivery.failedLast7Days} failed'),
              trailing: Text('${data.otpDelivery.deliveryRate}%'),
            ),
          ],
        ),
      ),
    );
  }
}
