import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/legal/legal_links.dart';
import '../auth/auth_provider.dart';
import 'legal_gate_provider.dart';
import 'legal_models.dart';

/// Mandatory legal-acceptance gate. Shown automatically after login when the
/// backend reports outstanding policies (enforcement mode), and also reachable
/// from Profile → Legal to review the current policies (review mode).
class LegalAcceptanceScreen extends ConsumerStatefulWidget {
  const LegalAcceptanceScreen({super.key});

  static const Key acceptButtonKey = ValueKey('legal-accept-button');
  static const Key agreeCheckboxKey = ValueKey('legal-agree-checkbox');

  @override
  ConsumerState<LegalAcceptanceScreen> createState() =>
      _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends ConsumerState<LegalAcceptanceScreen> {
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    // Load (or re-load) status when the screen opens from an idle/error state —
    // e.g. when opened from the profile to review policies.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final phase = ref.read(legalGateProvider).phase;
      if (phase == LegalGatePhase.unknown || phase == LegalGatePhase.error) {
        ref.read(legalGateProvider.notifier).refresh();
      }
    });
  }

  Future<void> _viewPolicy(LegalPolicy policy) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await LegalLinks.openPolicyPath(policy.path);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('“${policy.title}” will be available online soon.'),
        ),
      );
    }
  }

  Future<void> _accept() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(legalGateProvider.notifier).acceptOutstanding();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not record your acceptance. Please try again.'),
        ),
      );
    }
    // On success the router redirects away automatically (gate is satisfied).
  }

  void _logout() => ref.read(authProvider.notifier).logout();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(legalGateProvider);
    final theme = Theme.of(context);
    final blocked = state.isBlocked;
    final isLoading = state.phase == LegalGatePhase.loading &&
        state.policies.isEmpty &&
        state.outstanding.isEmpty;

    // In enforcement mode the user must accept or log out — no back button.
    final showBack = !blocked && Navigator.of(context).canPop();

    final shown = blocked
        ? state.outstanding
        : (state.policies.isNotEmpty ? state.policies : state.outstanding);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBack,
        title: Text(blocked ? 'Before you continue' : 'Terms & Policies'),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Text(
                        blocked
                            ? 'Please review and accept the following to keep using Akshara.'
                            : 'These are the policies that apply to your account.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      for (final policy in shown) ...[
                        _PolicyCard(
                          policy: policy,
                          onView: () => _viewPolicy(policy),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'You are all up to date. There is nothing to accept right now.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      if (blocked) ...[
                        const SizedBox(height: 4),
                        CheckboxListTile(
                          key: LegalAcceptanceScreen.agreeCheckboxKey,
                          value: _agreed,
                          onChanged: state.submitting
                              ? null
                              : (v) => setState(() => _agreed = v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'I have read and agree to the policies above.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: LegalAcceptanceScreen.acceptButtonKey,
                          onPressed: (_agreed && !state.submitting)
                              ? _accept
                              : null,
                          child: state.submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Accept & continue'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: state.submitting ? null : _logout,
                          child: const Text('Decline and log out'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.policy, required this.onView});

  final LegalPolicy policy;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    policy.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  'v${policy.version}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(policy.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('View full policy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
