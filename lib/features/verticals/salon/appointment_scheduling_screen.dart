import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import 'salon_providers.dart';

class AppointmentSchedulingScreen extends ConsumerWidget {
  const AppointmentSchedulingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(salonSalonAppointmentListProvider);
    return Scaffold(
      key: QaTestKeys.salonSalonAppointmentScreen,
      appBar: AppBar(title: const Text('SalonAppointment')),
      body: items.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return ListTile(
              key: QaTestKeys.salonSalonAppointmentTile(item.id),
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
