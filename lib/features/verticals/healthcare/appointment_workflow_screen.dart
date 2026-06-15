import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import 'healthcare_providers.dart';

class AppointmentWorkflowScreen extends ConsumerWidget {
  const AppointmentWorkflowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(healthcareAppointmentListProvider);
    return Scaffold(
      key: QaTestKeys.healthcareAppointmentScreen,
      appBar: AppBar(title: const Text('Appointment')),
      body: items.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return ListTile(
              key: QaTestKeys.healthcareAppointmentTile(item.id),
              title: Text(item.name),
              subtitle: Text(item.status),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
