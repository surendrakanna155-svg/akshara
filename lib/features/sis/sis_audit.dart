import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_failure.dart';
import '../../core/security/rbac_service.dart';

void assertManageSis(Ref ref) {
  if (!ref.read(canManageSisProvider)) {
    throw ApiFailureException(
      const ApiFailure(
        type: ApiFailureType.forbidden,
        message: 'You do not have permission to manage SIS records.',
        code: 'RBAC_MANAGE_SIS',
      ),
    );
  }
}
