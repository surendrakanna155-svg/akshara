import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';

enum BackupDestination { aksharaManaged, googleDrive, oneDrive, download }

/// Admin → Backup & Restore.
///
/// QA-R-009 (Backup & DR): this surface is a READ-ONLY status view for school
/// admins plus the school-owned export actions. Database RESTORE is deliberately
/// NOT self-serve — it is an OPERATOR-ASSISTED disaster-recovery procedure run
/// over SSH against the VPS using the documented runbook
/// (docs/BACKUP_RESTORE_RUNBOOK.md). There is no `/admin/backup/restore` backend
/// endpoint and this screen must never imply one.
class BackupRestoreScreen extends ConsumerWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          // --- read-only backup status -------------------------------------
          const AksharaSectionHeader(title: 'Backup status'),
          const SizedBox(height: AksharaSpacing.s2),
          // No app-facing backup-health endpoint is exposed to schools — backup
          // freshness lives on the operator-only `/health/backup` probe. This is
          // a clearly-labelled informational panel describing the managed cadence,
          // not a live status read.
          const AksharaKeyValueCard(
            title: 'NIKSHA-managed database backups',
            entries: [
              ('Cadence', 'Nightly · encrypted (AES-256)'),
              ('Off-site copy', 'Replicated off the server'),
              ('Recovery point (RPO)', '≈ 24 hours (nightly)'),
              ('Integrity drill', 'Automated monthly restore drill'),
            ],
          ),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            'Live backup freshness and the last restore-drill result are monitored '
            'by NIKSHA operations on the internal health dashboard. Contact support '
            'if you need a current backup report.',
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),

          const SizedBox(height: AksharaSpacing.s4),

          // --- school-owned exports ----------------------------------------
          const AksharaSectionHeader(title: 'School-owned exports'),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Export package'),
            subtitle: const Text('Google Drive · OneDrive · Download'),
            onTap: () => _showExportDialog(context),
          ),

          const SizedBox(height: AksharaSpacing.s4),

          // --- restore = operator-assisted (NOT self-serve) ----------------
          const AksharaSectionHeader(title: 'Restore'),
          const SizedBox(height: AksharaSpacing.s2),
          const AksharaWarningBanner(
            message: 'Restore is operator-assisted — there is no self-serve restore.',
            semanticLabel: 'Restore is operator-assisted. There is no self-serve restore.',
          ),
          const SizedBox(height: AksharaSpacing.s2),
          Text(
            'Restoring the database is a disaster-recovery operation performed by an '
            'NIKSHA operator over SSH, following the documented procedure in '
            'BACKUP_RESTORE_RUNBOOK.md (akshara-restore.sh --force) with an integrity '
            'drill. To request a restore, raise a support ticket — it cannot be '
            'triggered from the app.',
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export destination'),
        children: [
          for (final dest in BackupDestination.values)
            if (dest != BackupDestination.aksharaManaged)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export to ${dest.name} started')),
                  );
                },
                child: Text(dest.name),
              ),
        ],
      ),
    );
  }
}
