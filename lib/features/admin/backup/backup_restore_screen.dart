import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';

enum BackupJobType { schoolBackup, tenantBackup, exportPackage }

enum BackupDestination { aksharaManaged, googleDrive, oneDrive, download }

class BackupRestoreScreen extends ConsumerWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        children: [
          const AksharaSectionHeader(title: 'Akshara-managed backups'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('School backup'),
            subtitle: const Text('Nightly incremental · encrypted'),
            onTap: () => _showJobDialog(context, BackupJobType.schoolBackup),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Tenant backup'),
            subtitle: const Text('Full organization snapshot'),
            onTap: () => _showJobDialog(context, BackupJobType.tenantBackup),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'School-owned exports'),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Export package'),
            subtitle: const Text('Google Drive · OneDrive · Download'),
            onTap: () => _showExportDialog(context),
          ),
          const SizedBox(height: AksharaSpacing.s4),
          const AksharaSectionHeader(title: 'Restore'),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore school'),
            subtitle: const Text('Requires admin approval · see runbook'),
            onTap: () => _showRestoreDialog(context),
          ),
        ],
      ),
    );
  }

  void _showJobDialog(BuildContext context, BackupJobType type) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Queue ${type.name}'),
        content: const Text(
          'Backup job queued. Track progress in Operations audit log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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

  void _showRestoreDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore school'),
        content: const Text(
          'Restore validates manifest before commit. See BACKUP_RESTORE_RUNBOOK.md.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Validate snapshot'),
          ),
        ],
      ),
    );
  }
}
