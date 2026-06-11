import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/permissions.dart';
import '../../../core/tenant/tenant_provider.dart';
import '../../../core/repositories/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';

/// v12.9 / v13.0 — Super-admin provider + vault management (no API key display).
class ControlCenterProvidersScreen extends ConsumerStatefulWidget {
  const ControlCenterProvidersScreen({super.key});

  @override
  ConsumerState<ControlCenterProvidersScreen> createState() =>
      _ControlCenterProvidersScreenState();
}

class _ControlCenterProvidersScreenState extends ConsumerState<ControlCenterProvidersScreen> {
  final _credential = TextEditingController();
  String _category = 'ai';
  String _providerName = 'openai';
  bool _saving = false;

  @override
  void dispose() {
    _credential.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(controlCenterProvidersDataProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.providers,
      showFilterBar: false,
      body: data.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
          child: AksharaLoadingState(semanticLabel: 'Loading providers'),
        ),
        error: (e, _) => AksharaErrorState(message: '$e'),
        data: (snapshot) => ListView(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          children: [
            const AksharaWarningBanner(
              message:
                  'Super admin only. API keys are encrypted in vault — never shown after save.',
            ),
            _usagePanel(snapshot.usage),
            const Divider(height: 32),
            const Text('Configured providers', style: TextStyle(fontWeight: FontWeight.bold)),
            ...snapshot.providers.map(_providerTile),
            const Divider(height: 32),
            AksharaManageAction(
              permission: Permission.managePlatformProviders,
              child: _configureForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _usagePanel(PlatformUsageAnalytics usage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usage · ${usage.totalEvents} events',
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
        const Text('Configure provider', style: TextStyle(fontWeight: FontWeight.bold)),
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
            DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
            DropdownMenuItem(value: 'claude', child: Text('Claude')),
            DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
            DropdownMenuItem(value: 'msg91', child: Text('MSG91')),
            DropdownMenuItem(value: 'gupshup', child: Text('Gupshup')),
          ],
          onChanged: (v) => setState(() => _providerName = v ?? 'openai'),
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
      await ref.read(controlCenterRepositoryProvider).saveProvider(
            query: ref.read(repositoryQueryProvider),
            providerCategory: _category,
            providerName: _providerName,
            credential: _credential.text.trim().isEmpty ? null : _credential.text.trim(),
            isActive: true,
            isPrimary: true,
          );
      _credential.clear();
      ref.invalidate(controlCenterProvidersDataProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
