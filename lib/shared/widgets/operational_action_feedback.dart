import 'package:flutter/material.dart';

/// Honest MVP feedback when an action is preview-only (no backend pipeline yet).
void showAksharaOperationalPreviewSnackBar(
  BuildContext context, {
  required String action,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$action — recorded in preview mode (no server write yet).'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Report export preview — avoids implying a file was generated.
void showAksharaReportExportPreviewSnackBar(
  BuildContext context, {
  required String reportName,
  String format = 'PDF',
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '$reportName ($format) — preview only. Export pipeline not connected yet.',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
