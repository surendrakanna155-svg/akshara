import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/permissions.dart';
import '../../../../core/tenant/tenant_provider.dart';
import '../../../../core/repositories/repository_providers.dart';
import '../../../../router/route_guards.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../theme/spacing.dart';
import '../control_center_models.dart';
import '../control_center_mutations_provider.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';
import '../../../../core/errors/api_failure_mapper.dart';

/// v12.9 / v13.0 — Super-admin provider + vault management (no API key display).
class ControlCenterProvidersScreen extends ConsumerStatefulWidget {
  const ControlCenterProvidersScreen({super.key});

  @override
  ConsumerState<ControlCenterProvidersScreen> createState() =>
      _ControlCenterProvidersScreenState();
}

class _ControlCenterProvidersScreenState extends ConsumerState<ControlCenterProvidersScreen> {
  final _credential = TextEditingController();
  final _model = TextEditingController();
  String _category = 'ai';
  String _providerName = 'openrouter';
  bool _saving = false;

  final _aiWalletUnits = TextEditingController();
  final _aiWalletReason = TextEditingController();
  final _aiWalletExternalRef = TextEditingController();
  String _aiWalletEntryType = 'top_up';
  bool _grantingCredits = false;

  @override
  void dispose() {
    _credential.dispose();
    _model.dispose();
    _aiWalletUnits.dispose();
    _aiWalletReason.dispose();
    _aiWalletExternalRef.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(controlCenterProvidersDataProvider);
    final wallet = ref.watch(controlCenterAiWalletFutureProvider);
    final storageQuota = ref.watch(controlCenterStorageQuotaFutureProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.providers,
      showFilterBar: false,
      body: data.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
          child: AksharaLoadingState(semanticLabel: 'Loading providers'),
        ),
        error: (e, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
        data: (snapshot) => ListView(
          // The scaffold already hosts this body inside a SingleChildScrollView,
          // so the list must shrink-wrap and defer scrolling to the parent
          // (a bare ListView gets unbounded height here → layout assertion).
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            const AksharaWarningBanner(
              message:
                  'Super admin only. API keys are encrypted in vault — never shown after save.',
            ),
            _usagePanel(snapshot.usage),
            const Divider(height: 32),
            Text('Configured providers', style: Theme.of(context).textTheme.titleSmall),
            ...snapshot.providers.map(_providerTile),
            const Divider(height: 32),
            AksharaManageAction(
              permission: Permission.managePlatformProviders,
              child: _configureForm(),
            ),
            _aiWalletSection(wallet),
            _storageQuotaSection(storageQuota),
          ],
        ),
      ),
    );
  }

  /// PRC-A Batch 3 — AI Credit Wallet. The whole section is gated on
  /// `viewAiWallet`; the grant form inside is separately gated on
  /// `manageAiCredits` (superAdmin only — see [AksharaManageAction] below).
  Widget _aiWalletSection(AsyncValue<AiWalletData> wallet) {
    return PermissionGuard(
      permission: Permission.viewAiWallet,
      fallback: const SizedBox.shrink(),
      child: Padding(
        padding: const EdgeInsets.only(top: AksharaSpacing.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            Text('AI Credit Wallet', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            wallet.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s6),
                child: AksharaLoadingState(semanticLabel: 'Loading AI credit wallet'),
              ),
              error: (e, _) =>
                  AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _aiWalletBalanceCard(data.balance),
                  const SizedBox(height: AksharaSpacing.s3),
                  Text('Recent ledger', style: Theme.of(context).textTheme.titleSmall),
                  if (data.entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s2),
                      child: Text('No credit entries yet.'),
                    )
                  else
                    ...data.entries.map(_aiWalletEntryTile),
                  const SizedBox(height: AksharaSpacing.s2),
                  AksharaManageAction(
                    permission: Permission.manageAiCredits,
                    child: _grantCreditsForm(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiWalletBalanceCard(AiWalletBalance balance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Available: ${balance.availableUnits}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: AksharaSpacing.s3),
                _aiWalletHealthChip(balance.health),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Wrap(
              spacing: AksharaSpacing.s4,
              runSpacing: AksharaSpacing.s1,
              children: [
                Text('Granted: ${balance.grantedUnits}'),
                Text('Debited: ${balance.debitedUnits}'),
                Text('Reserved: ${balance.reservedUnits}'),
                Text('Last top-up: ${balance.lastTopUpUnits}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiWalletHealthChip(AiWalletHealth health) {
    final Color color = switch (health) {
      AiWalletHealth.healthy => Colors.green,
      AiWalletHealth.low => Colors.amber,
      AiWalletHealth.empty => Colors.red,
    };
    final String label = switch (health) {
      AiWalletHealth.healthy => 'Healthy',
      AiWalletHealth.low => 'Low',
      AiWalletHealth.empty => 'Empty',
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _aiWalletEntryTile(AiCreditEntry entry) {
    final sign = entry.units > 0 ? '+' : '';
    return ListTile(
      dense: true,
      title: Text('${entry.entryType} · $sign${entry.units}'),
      subtitle: Text(entry.reason),
      trailing: Text(entry.createdAt.isEmpty ? '—' : entry.createdAt.split('T').first),
    );
  }

  Widget _grantCreditsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Grant credits', style: Theme.of(context).textTheme.titleSmall),
        DropdownButtonFormField<String>(
          initialValue: _aiWalletEntryType,
          decoration: const InputDecoration(labelText: 'Entry type'),
          items: const [
            DropdownMenuItem(value: 'top_up', child: Text('Top-up (adds credit)')),
            DropdownMenuItem(value: 'adjustment', child: Text('Adjustment (correction)')),
            DropdownMenuItem(value: 'expiry', child: Text('Expiry (removes credit)')),
          ],
          onChanged: (v) => setState(() => _aiWalletEntryType = v ?? 'top_up'),
        ),
        TextField(
          controller: _aiWalletUnits,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(
            labelText: 'Units',
            helperText: _aiWalletEntryType == 'top_up'
                ? 'Must be positive'
                : _aiWalletEntryType == 'expiry'
                    ? 'Must be negative'
                    : 'Non-zero — positive or negative',
          ),
        ),
        TextField(
          controller: _aiWalletReason,
          decoration: const InputDecoration(
            labelText: 'Reason',
            helperText: 'Required — every grant is audited',
          ),
        ),
        TextField(
          controller: _aiWalletExternalRef,
          decoration: const InputDecoration(labelText: 'External reference (optional)'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _grantingCredits ? null : _grantCredits,
          child: _grantingCredits ? const Text('Granting…') : const Text('Grant credits'),
        ),
      ],
    );
  }

  Future<void> _grantCredits() async {
    final units = int.tryParse(_aiWalletUnits.text.trim());
    final reason = _aiWalletReason.text.trim();
    if (units == null || units == 0 || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A non-zero units value and a reason are required.')),
      );
      return;
    }

    setState(() => _grantingCredits = true);
    try {
      await ref.read(grantAiCreditsProvider.notifier).execute(
            entryType: _aiWalletEntryType,
            units: units,
            reason: reason,
            externalRef:
                _aiWalletExternalRef.text.trim().isEmpty ? null : _aiWalletExternalRef.text.trim(),
          );
      final error = ref.read(grantAiCreditsProvider).hasError;
      if (!mounted) return;
      if (error) {
        final failure = apiFailureMapper.fromException(
          ref.read(grantAiCreditsProvider).error!,
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
        return;
      }
      _aiWalletUnits.clear();
      _aiWalletReason.clear();
      _aiWalletExternalRef.clear();
      ref.invalidate(controlCenterAiWalletFutureProvider);
    } finally {
      if (mounted) setState(() => _grantingCredits = false);
    }
  }

  /// PRC-A Batch 4 — Storage Quota. Read-only: usage is written internally by
  /// the upload/delete paths, so unlike the wallet there is no mutation form
  /// here — the whole section is gated on `viewStorageQuota`.
  Widget _storageQuotaSection(AsyncValue<StorageQuotaData> storageQuota) {
    return PermissionGuard(
      permission: Permission.viewStorageQuota,
      fallback: const SizedBox.shrink(),
      child: Padding(
        padding: const EdgeInsets.only(top: AksharaSpacing.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            Text('Storage', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AksharaSpacing.s2),
            storageQuota.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s6),
                child: AksharaLoadingState(semanticLabel: 'Loading storage quota'),
              ),
              error: (e, _) =>
                  AksharaErrorState.fromFailure(apiFailureMapper.fromException(e)),
              data: (data) => _storageQuotaCard(data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storageQuotaCard(StorageQuotaData data) {
    final limit = data.limitBytes;
    final used = data.usedBytes;
    final progress = (limit != null && limit > 0) ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final color = _storageQuotaHealthColor(data.health);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  data.planName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: AksharaSpacing.s3),
                _storageQuotaHealthChip(data.health),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s2),
            Text(
              limit != null
                  ? '${_formatBytes(used)} of ${_formatBytes(limit)} used'
                  : '${_formatBytes(used)} used · unlimited plan',
            ),
            if (limit != null) ...[
              const SizedBox(height: AksharaSpacing.s2),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
            if (!data.enforced) ...[
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                'Not enforced yet — the cap is not currently blocking uploads.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).hintColor,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _storageQuotaHealthColor(StorageQuotaHealth health) {
    return switch (health) {
      StorageQuotaHealth.unlimited => Colors.blueGrey,
      StorageQuotaHealth.healthy => Colors.green,
      StorageQuotaHealth.low => Colors.amber,
      StorageQuotaHealth.full => Colors.red,
    };
  }

  Widget _storageQuotaHealthChip(StorageQuotaHealth health) {
    final color = _storageQuotaHealthColor(health);
    final label = switch (health) {
      StorageQuotaHealth.unlimited => 'Unlimited',
      StorageQuotaHealth.healthy => 'Healthy',
      StorageQuotaHealth.low => 'Low',
      StorageQuotaHealth.full => 'Full',
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }

  /// Human-readable byte formatting — GiB/MiB/KiB, falling back to raw bytes.
  String _formatBytes(int bytes) {
    const gib = 1024 * 1024 * 1024;
    const mib = 1024 * 1024;
    const kib = 1024;
    if (bytes >= gib) return '${(bytes / gib).toStringAsFixed(2)} GiB';
    if (bytes >= mib) return '${(bytes / mib).toStringAsFixed(1)} MiB';
    if (bytes >= kib) return '${(bytes / kib).toStringAsFixed(1)} KiB';
    return '$bytes B';
  }

  Widget _usagePanel(PlatformUsageAnalytics usage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AksharaSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usage · ${usage.totalEvents} events',
                style: Theme.of(context).textTheme.titleSmall),
            Text('Estimated cost ₹${usage.totalCostInr.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            ...usage.byCategory.entries.map(
              (e) => ListTile(
                dense: true,
                title: Text(e.key.toUpperCase()),
                trailing: Text('${e.value.events} · ₹${e.value.costInr}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerTile(PlatformProviderConfig p) {
    return ListTile(
      title: Text('${p.providerCategory.toUpperCase()} · ${p.providerName}'),
      subtitle: Text(
        p.hasCredential ? 'Credential stored · ${p.healthStatus}' : 'No credential',
      ),
      trailing: Text(p.isPrimary ? 'Primary' : (p.isActive ? 'Active' : 'Inactive')),
    );
  }

  Widget _configureForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Configure provider', style: Theme.of(context).textTheme.titleSmall),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: const [
            DropdownMenuItem(value: 'ai', child: Text('AI')),
            DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
            DropdownMenuItem(value: 'sms', child: Text('SMS')),
          ],
          onChanged: (v) => setState(() => _category = v ?? 'ai'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _providerName,
          decoration: const InputDecoration(labelText: 'Provider'),
          items: const [
            DropdownMenuItem(value: 'openrouter', child: Text('OpenRouter (Claude/GPT/Gemini)')),
            DropdownMenuItem(value: 'anthropic', child: Text('Anthropic (Claude direct)')),
            DropdownMenuItem(value: 'msg91', child: Text('MSG91')),
            DropdownMenuItem(value: 'gupshup', child: Text('Gupshup')),
          ],
          onChanged: (v) => setState(() => _providerName = v ?? 'openrouter'),
        ),
        if (_category == 'ai')
          Padding(
            padding: const EdgeInsets.only(top: AksharaSpacing.s2),
            child: TextField(
              controller: _model,
              decoration: InputDecoration(
                labelText: 'Model (optional)',
                helperText: _providerName == 'openrouter'
                    ? 'Default: anthropic/claude-sonnet-4-6 · e.g. anthropic/claude-opus-4-8, openai/gpt-4o-mini'
                    : 'Default: claude-opus-4-8 · e.g. claude-sonnet-4-6',
              ),
            ),
          ),
        TextField(
          controller: _credential,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'API key / credential',
            helperText: 'Encrypted at rest — not displayed after save',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const Text('Saving…') : const Text('Save & health-check'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final model = _model.text.trim();
      await ref.read(controlCenterRepositoryProvider).saveProvider(
            query: ref.read(repositoryQueryProvider),
            providerCategory: _category,
            providerName: _providerName,
            credential: _credential.text.trim().isEmpty ? null : _credential.text.trim(),
            isActive: true,
            isPrimary: true,
            config: _category == 'ai' && model.isNotEmpty ? {'model': model} : null,
          );
      _credential.clear();
      ref.invalidate(controlCenterProvidersDataProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
