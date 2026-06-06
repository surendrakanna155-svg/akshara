import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'interfaces/admissions_repository.dart';
import 'interfaces/finance_repository.dart';
import 'interfaces/sis_repository.dart';
import 'mock/mock_admissions_repository.dart';
import 'mock/mock_finance_repository.dart';
import 'mock/mock_sis_repository.dart';

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => MockFinanceRepository(),
);

final admissionsRepositoryProvider = Provider<AdmissionsRepository>(
  (ref) => MockAdmissionsRepository(),
);

final sisRepositoryProvider = Provider<SisRepository>(
  (ref) => MockSisRepository(),
);
