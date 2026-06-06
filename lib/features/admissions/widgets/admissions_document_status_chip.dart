import 'package:flutter/material.dart';

import '../../../shared/widgets/akshara_status_chip.dart';
import '../../../theme/theme_extensions.dart';
import '../admissions_models.dart';

/// Document verification status chip (AD-06).
class AdmissionsDocumentStatusChip extends StatelessWidget {
  const AdmissionsDocumentStatusChip({
    super.key,
    required this.status,
  });

  final DocumentVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      DocumentVerificationStatus.missing => KpiAccent.error,
      DocumentVerificationStatus.uploaded => KpiAccent.warning,
      DocumentVerificationStatus.verified => KpiAccent.success,
      DocumentVerificationStatus.rejected => KpiAccent.error,
    };

    return AksharaStatusChip(
      label: status.label,
      tone: tone,
      semanticLabel: 'Document status ${status.label}',
    );
  }
}
