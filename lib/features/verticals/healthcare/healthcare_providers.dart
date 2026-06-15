import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repository_providers.dart';
import '../../../core/security/permissions.dart';
import '../../../core/security/rbac_service.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'healthcare_models.dart';

final healthcareCanViewProvider = Provider<bool>((ref) {
  return ref.watch(rbacServiceProvider).hasPermission(Permission.viewHealthcare);
});

final healthcareDashboardProvider = FutureProvider<HealthcareDashboard>((ref) async {
  return ref.read(healthcareRepositoryProvider).getDashboard(
        query: ref.watch(repositoryQueryProvider),
      );
});

final healthcarePatientListProvider = FutureProvider<List<Patient>>((ref) async {
  return ref.read(healthcareRepositoryProvider).listPatients(
        query: ref.watch(repositoryQueryProvider),
      );
});

final healthcareAppointmentListProvider = FutureProvider<List<Appointment>>((ref) async {
  return ref.read(healthcareRepositoryProvider).listAppointments(
        query: ref.watch(repositoryQueryProvider),
      );
});

final healthcarePractitionerListProvider = FutureProvider<List<Practitioner>>((ref) async {
  return ref.read(healthcareRepositoryProvider).listPractitioners(
        query: ref.watch(repositoryQueryProvider),
      );
});

final healthcareIntelligenceProvider = FutureProvider<HealthcareIntelligence>((ref) async {
  return ref.read(healthcareRepositoryProvider).getIntelligence(
        query: ref.watch(repositoryQueryProvider),
      );
});