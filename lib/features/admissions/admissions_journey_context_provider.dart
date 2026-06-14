import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admissions_models.dart';

/// Last lead created in-session — used to link application → lead in E2E flows.
final admissionsLastCreatedLeadProvider =
    StateProvider<AdmissionsLead?>((ref) => null);

/// Active application id for enrollment submit (set after application create/submit).
final admissionsActiveApplicationIdProvider =
    StateProvider<String?>((ref) => null);

/// Last enrollment id submitted in-session (Patrol / QA assertions).
final admissionsLastEnrollmentIdProvider = StateProvider<String?>((ref) => null);

/// Last approval id tied to the active application (set on enrollment submit).
final admissionsLastApprovalIdProvider = StateProvider<String?>((ref) => null);
