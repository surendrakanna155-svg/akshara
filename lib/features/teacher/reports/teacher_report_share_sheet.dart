import 'package:flutter/material.dart';

import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';

/// TCH-3 / TCH-7 — a small CSV / PDF chooser sheet shared by the teacher export
/// buttons. [onCsv] / [onPdf] run the matching [TeacherReportExporters] action.
Future<void> showTeacherExportSheet(
  BuildContext context, {
  required String title,
  required Future<void> Function() onCsv,
  required Future<void> Function() onPdf,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      Future<void> run(Future<void> Function() action) async {
        Navigator.of(sheetContext).pop();
        final messenger = ScaffoldMessenger.of(context);
        try {
          await action();
        } catch (_) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Unable to build the export.')),
          );
        }
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AksharaSpacing.s4,
            0,
            AksharaSpacing.s4,
            AksharaSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: sheetContext.aksharaText.titleMedium),
              const SizedBox(height: AksharaSpacing.s3),
              OutlinedButton.icon(
                onPressed: () => run(onCsv),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Export CSV'),
              ),
              const SizedBox(height: AksharaSpacing.s2),
              OutlinedButton.icon(
                onPressed: () => run(onPdf),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
