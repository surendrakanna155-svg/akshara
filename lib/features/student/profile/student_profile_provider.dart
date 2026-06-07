import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_future.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../core/tenant/tenant_provider.dart';
import 'profile_models.dart';

final studentProfileLoadingProvider = StateProvider<bool>((ref) => false);
final studentProfileErrorProvider = StateProvider<bool>((ref) => false);
final studentProfileEmptyProvider = StateProvider<bool>((ref) => false);

final studentProfileFutureProvider = FutureProvider<StudentProfileData>((ref) async {
  return ref.read(studentRepositoryProvider).getProfile(query: ref.watch(repositoryQueryProvider));
});

final studentProfileProvider = Provider<StudentProfileData>((ref) {
  final data = watchRepositoryFuture(
    ref,
    ref.watch(studentProfileFutureProvider),
    manualLoading: ref.watch(studentProfileLoadingProvider),
    manualError: ref.watch(studentProfileErrorProvider),
    manualEmpty: ref.watch(studentProfileEmptyProvider),
  );
  return data ??
      ref.watch(studentProfileFutureProvider).value ??
      const StudentProfileData(
        studentName: 'Ravi Kumar',
        classLabel: '8-A',
        rollNo: '08',
        admissionNo: 'AKS-2024-0842',
        dateOfBirth: '14 Mar 2012',
        bloodGroup: 'B+',
        schoolName: 'Akshara International School',
        unreadNotifications: 2,
        parentContacts: [],
        academicSummary: [],
      );
});
