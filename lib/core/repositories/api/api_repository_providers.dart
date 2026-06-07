import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/dio_provider.dart';
import 'admissions/api_admissions_repository.dart';
import 'admissions/remote/admissions_remote_datasource.dart';
import 'finance/api_finance_repository.dart';
import 'finance/remote/finance_remote_datasource.dart';
import 'management/api_management_repository.dart';
import 'management/remote/management_remote_datasource.dart';
import 'sis/api_sis_repository.dart';
import 'sis/remote/sis_remote_datasource.dart';
import 'alumni/api_alumni_repository.dart';
import 'alumni/remote/alumni_remote_datasource.dart';
import 'hostel/api_hostel_repository.dart';
import 'hostel/remote/hostel_remote_datasource.dart';
import 'hr/api_hr_repository.dart';
import 'hr/remote/hr_remote_datasource.dart';
import 'transport/api_transport_repository.dart';
import 'transport/remote/transport_remote_datasource.dart';
import 'inventory/api_inventory_repository.dart';
import 'inventory/remote/inventory_remote_datasource.dart';
import 'library/api_library_repository.dart';
import 'library/remote/library_remote_datasource.dart';
import 'control_center/api_control_center_repository.dart';
import 'control_center/remote/control_center_remote_datasource.dart';
import 'parent/api_parent_repository.dart';
import 'parent/remote/parent_remote_datasource.dart';
import 'teacher/api_teacher_repository.dart';
import 'teacher/remote/teacher_remote_datasource.dart';
import 'student/api_student_repository.dart';
import 'student/remote/student_remote_datasource.dart';

final admissionsRemoteDataSourceProvider = Provider<AdmissionsRemoteDataSource>(
  (ref) => AdmissionsRemoteDataSource(ref.watch(dioProvider)),
);

final financeRemoteDataSourceProvider = Provider<FinanceRemoteDataSource>(
  (ref) => FinanceRemoteDataSource(ref.watch(dioProvider)),
);

final sisRemoteDataSourceProvider = Provider<SisRemoteDataSource>(
  (ref) => SisRemoteDataSource(ref.watch(dioProvider)),
);

final managementRemoteDataSourceProvider = Provider<ManagementRemoteDataSource>(
  (ref) => ManagementRemoteDataSource(ref.watch(dioProvider)),
);

final transportRemoteDataSourceProvider = Provider<TransportRemoteDataSource>(
  (ref) => TransportRemoteDataSource(ref.watch(dioProvider)),
);

final hrRemoteDataSourceProvider = Provider<HrRemoteDataSource>(
  (ref) => HrRemoteDataSource(ref.watch(dioProvider)),
);

final hostelRemoteDataSourceProvider = Provider<HostelRemoteDataSource>(
  (ref) => HostelRemoteDataSource(ref.watch(dioProvider)),
);

final alumniRemoteDataSourceProvider = Provider<AlumniRemoteDataSource>(
  (ref) => AlumniRemoteDataSource(ref.watch(dioProvider)),
);

final apiAdmissionsRepositoryProvider = Provider<ApiAdmissionsRepository>(
  (ref) => ApiAdmissionsRepository(
    remote: ref.watch(admissionsRemoteDataSourceProvider),
  ),
);

final apiFinanceRepositoryProvider = Provider<ApiFinanceRepository>(
  (ref) => ApiFinanceRepository(
    remote: ref.watch(financeRemoteDataSourceProvider),
  ),
);

final apiSisRepositoryProvider = Provider<ApiSisRepository>(
  (ref) => ApiSisRepository(remote: ref.watch(sisRemoteDataSourceProvider)),
);

final apiManagementRepositoryProvider = Provider<ApiManagementRepository>(
  (ref) => ApiManagementRepository(
    remote: ref.watch(managementRemoteDataSourceProvider),
  ),
);

final apiTransportRepositoryProvider = Provider<ApiTransportRepository>(
  (ref) => ApiTransportRepository(
    remote: ref.watch(transportRemoteDataSourceProvider),
  ),
);

final apiHrRepositoryProvider = Provider<ApiHrRepository>(
  (ref) => ApiHrRepository(
    remote: ref.watch(hrRemoteDataSourceProvider),
  ),
);

final apiHostelRepositoryProvider = Provider<ApiHostelRepository>(
  (ref) => ApiHostelRepository(
    remote: ref.watch(hostelRemoteDataSourceProvider),
  ),
);

final apiAlumniRepositoryProvider = Provider<ApiAlumniRepository>(
  (ref) => ApiAlumniRepository(
    remote: ref.watch(alumniRemoteDataSourceProvider),
  ),
);

final inventoryRemoteDataSourceProvider = Provider<InventoryRemoteDataSource>(
  (ref) => InventoryRemoteDataSource(ref.watch(dioProvider)),
);

final apiInventoryRepositoryProvider = Provider<ApiInventoryRepository>(
  (ref) => ApiInventoryRepository(
    remote: ref.watch(inventoryRemoteDataSourceProvider),
  ),
);

final libraryRemoteDataSourceProvider = Provider<LibraryRemoteDataSource>(
  (ref) => LibraryRemoteDataSource(ref.watch(dioProvider)),
);

final apiLibraryRepositoryProvider = Provider<ApiLibraryRepository>(
  (ref) => ApiLibraryRepository(
    remote: ref.watch(libraryRemoteDataSourceProvider),
  ),
);

final controlCenterRemoteDataSourceProvider =
    Provider<ControlCenterRemoteDataSource>(
  (ref) => ControlCenterRemoteDataSource(ref.watch(dioProvider)),
);

final apiControlCenterRepositoryProvider =
    Provider<ApiControlCenterRepository>(
  (ref) => ApiControlCenterRepository(
    remote: ref.watch(controlCenterRemoteDataSourceProvider),
  ),
);

final parentRemoteDataSourceProvider = Provider<ParentRemoteDataSource>(
  (ref) => ParentRemoteDataSource(ref.watch(dioProvider)),
);

final teacherRemoteDataSourceProvider = Provider<TeacherRemoteDataSource>(
  (ref) => TeacherRemoteDataSource(ref.watch(dioProvider)),
);

final studentRemoteDataSourceProvider = Provider<StudentRemoteDataSource>(
  (ref) => StudentRemoteDataSource(ref.watch(dioProvider)),
);

final apiParentRepositoryProvider = Provider<ApiParentRepository>(
  (ref) => ApiParentRepository(
    remote: ref.watch(parentRemoteDataSourceProvider),
  ),
);

final apiTeacherRepositoryProvider = Provider<ApiTeacherRepository>(
  (ref) => ApiTeacherRepository(
    remote: ref.watch(teacherRemoteDataSourceProvider),
  ),
);

final apiStudentRepositoryProvider = Provider<ApiStudentRepository>(
  (ref) => ApiStudentRepository(
    remote: ref.watch(studentRemoteDataSourceProvider),
  ),
);
