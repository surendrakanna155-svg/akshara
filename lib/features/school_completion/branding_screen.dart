import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/repository_providers.dart';
import '../../shared/async/erp_async_state.dart';
import 'school_completion_models.dart';
import 'school_completion_providers.dart';
import '../../theme/spacing.dart';

class BrandingScreen extends ConsumerStatefulWidget {
  const BrandingScreen({super.key});

  @override
  ConsumerState<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends ConsumerState<BrandingScreen> {
  final _displayName = TextEditingController();
  final _tagline = TextEditingController();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();

  @override
  void dispose() {
    _displayName.dispose();
    _tagline.dispose();
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  void _load(SchoolBranding branding) {
    _displayName.text = branding.displayName;
    _tagline.text = branding.tagline;
    _primary.text = branding.primaryColor;
    _secondary.text = branding.secondaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(schoolBrandingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Branding'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await ref.read(schoolCompletionRepositoryProvider).saveBranding(
                    query: ref.read(schoolCompletionQueryProvider),
                    branding: SchoolBranding(
                      displayName: _displayName.text.trim(),
                      tagline: _tagline.text.trim(),
                      primaryColor: _primary.text.trim(),
                      secondaryColor: _secondary.text.trim(),
                    ),
                  );
              ref.invalidate(schoolBrandingProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Branding saved')),
              );
            },
          ),
        ],
      ),
      body: ErpAsyncBody(
        state: resolveErpAsync(branding, isDataEmpty: (_) => false),
        loadingLabel: 'Loading branding',
        emptyMessage: 'No branding data available.',
        onRetry: () => ref.invalidate(schoolBrandingProvider),
        builder: (data) {
          if (_displayName.text.isEmpty) _load(data);
          return ListView(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            children: [
              TextField(controller: _displayName, decoration: const InputDecoration(labelText: 'Display name')),
              TextField(controller: _tagline, decoration: const InputDecoration(labelText: 'Tagline')),
              TextField(controller: _primary, decoration: const InputDecoration(labelText: 'Primary color')),
              TextField(controller: _secondary, decoration: const InputDecoration(labelText: 'Secondary color')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(width: 40, height: 40, color: _parseColor(_primary.text)),
                  const SizedBox(width: 8),
                  Container(width: 40, height: 40, color: _parseColor(_secondary.text)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Color _parseColor(String hex) {
    final value = hex.replaceAll('#', '');
    if (value.length == 6) {
      return Color(int.parse('FF$value', radix: 16));
    }
    return Colors.blue;
  }
}
