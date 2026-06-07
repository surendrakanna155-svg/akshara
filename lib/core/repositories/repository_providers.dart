import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_repository_providers.dart';
import 'interfaces/admissions_repository.dart';
import 'interfaces/finance_repository.dart';
import 'interfaces/hostel_repository.dart';
import 'interfaces/hr_repository.dart';
import 'interfaces/library_repository.dart';
import 'interfaces/management_repository.dart';
import 'interfaces/sis_repository.dart';
import 'interfaces/alumni_repository.dart';
import 'interfaces/control_center_repository.dart';
import 'interfaces/inventory_repository.dart';
import 'interfaces/transport_repository.dart';
import 'mock/mock_admissions_repository.dart';
import 'mock/mock_alumni_repository.dart';
import 'mock/mock_finance_repository.dart';
import 'mock/mock_hostel_repository.dart';
import 'mock/mock_inventory_repository.dart';
import 'mock/mock_hr_repository.dart';
import 'mock/mock_library_repository.dart';
import 'mock/mock_management_repository.dart';
import 'mock/mock_sis_repository.dart';
import 'mock/mock_control_center_repository.dart';
import 'mock/mock_transport_repository.dart';
import 'repository_config.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  if (isModuleApiEnabled(ref, financeApiEnabledProvider)) {
    return ref.read(apiFinanceRepositoryProvider);
  }
  return MockFinanceRepository();
});

final admissionsRepositoryProvider = Provider<AdmissionsRepository>((ref) {
  if (isModuleApiEnabled(ref, admissionsApiEnabledProvider)) {
    return ref.read(apiAdmissionsRepositoryProvider);
  }
  return MockAdmissionsRepository();
});

final sisRepositoryProvider = Provider<SisRepository>((ref) {
  if (isModuleApiEnabled(ref, sisApiEnabledProvider)) {
    return ref.read(apiSisRepositoryProvider);
  }
  return MockSisRepository();
});

final managementRepositoryProvider = Provider<ManagementRepository>((ref) {
  if (isModuleApiEnabled(ref, managementApiEnabledProvider)) {
    return ref.read(apiManagementRepositoryProvider);
  }
  return MockManagementRepository();
});

final transportRepositoryProvider = Provider<TransportRepository>((ref) {
  if (isModuleApiEnabled(ref, transportApiEnabledProvider)) {
    return ref.read(apiTransportRepositoryProvider);
  }
  return MockTransportRepository();
});

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  if (isModuleApiEnabled(ref, hrApiEnabledProvider)) {
    return ref.read(apiHrRepositoryProvider);
  }
  return MockHrRepository();
});

final hostelRepositoryProvider = Provider<HostelRepository>((ref) {
  if (isModuleApiEnabled(ref, hostelApiEnabledProvider)) {
    return ref.read(apiHostelRepositoryProvider);
  }
  return MockHostelRepository();
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  if (isModuleApiEnabled(ref, inventoryApiEnabledProvider)) {
    return ref.read(apiInventoryRepositoryProvider);
  }
  return MockInventoryRepository();
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  if (isModuleApiEnabled(ref, libraryApiEnabledProvider)) {
    return ref.read(apiLibraryRepositoryProvider);
  }
  return MockLibraryRepository();
});

final alumniRepositoryProvider = Provider<AlumniRepository>((ref) {
  if (isModuleApiEnabled(ref, alumniApiEnabledProvider)) {
    return ref.read(apiAlumniRepositoryProvider);
  }
  return MockAlumniRepository();
});

final controlCenterRepositoryProvider = Provider<ControlCenterRepository>((ref) {
  if (isModuleApiEnabled(ref, controlCenterApiEnabledProvider)) {
    return ref.read(apiControlCenterRepositoryProvider);
  }
  return MockControlCenterRepository();
});
