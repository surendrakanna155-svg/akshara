import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/erp_role.dart';
import '../../core/security/rbac_service.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../shared/widgets/widgets.dart';
import 'dynamic_widget_models.dart';
import 'dynamic_widget_mutations_provider.dart';
import 'dynamic_widget_providers.dart';
import '../../theme/spacing.dart';

class DynamicWidgetLayoutEditorScreen extends ConsumerStatefulWidget {
  const DynamicWidgetLayoutEditorScreen({super.key});

  @override
  ConsumerState<DynamicWidgetLayoutEditorScreen> createState() =>
      _DynamicWidgetLayoutEditorScreenState();
}

class _DynamicWidgetLayoutEditorScreenState
    extends ConsumerState<DynamicWidgetLayoutEditorScreen> {
  RoleDashboardLayout? _draft;
  String? _selectedRole;

  static const _editableRoles = [
    ErpRole.superAdmin,
    ErpRole.principal,
    ErpRole.schoolAdmin,
    ErpRole.teacher,
    ErpRole.financeAdmin,
  ];

  String _resolvedLayoutRole(String role) {
    if (_editableRoles.any((r) => r.name == role)) return role;
    return ErpRole.principal.name;
  }

  @override
  Widget build(BuildContext context) {
    final String layoutRole =
        _resolvedLayoutRole(_selectedRole ?? ref.watch(dynamicWidgetRoleProvider));
    final layoutState = ref.watch(roleDashboardLayoutProvider(layoutRole));
    final saveState = ref.watch(saveRoleDashboardLayoutProvider);
    final resetState = ref.watch(resetLayoutToPackDefaultProvider);
    final rbac = ref.watch(rbacServiceProvider);
    final verticalPack = ref.watch(dynamicWidgetVerticalPackProvider);
    final canManage = canManageDynamicWidgets(rbac);

    return Scaffold(
      key: QaTestKeys.dynamicWidgetLayoutEditorScreen,
      appBar: AppBar(
        title: const Text('Layout editor'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: QaTestKeys.dynamicWidgetLayoutRoleDropdown,
                    initialValue: layoutRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final erpRole in _editableRoles)
                        DropdownMenuItem(
                          value: erpRole.name,
                          child: Text(erpRole.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedRole = value;
                        _draft = null;
                      });
                      ref.read(dynamicWidgetRoleProvider.notifier).state = value;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: QaTestKeys.dynamicWidgetLayoutPackDropdown,
                    initialValue: verticalPack,
                    decoration: const InputDecoration(
                      labelText: 'Vertical pack',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'school', child: Text('School')),
                      DropdownMenuItem(value: 'salon', child: Text('Salon')),
                      DropdownMenuItem(value: 'hospital', child: Text('Hospital')),
                      DropdownMenuItem(
                        value: 'restaurant',
                        child: Text('Restaurant'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      ref.read(dynamicWidgetVerticalPackProvider.notifier).state = value;
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: layoutState.when(
              loading: () => const AksharaLoadingState(semanticLabel: 'Loading layout'),
              error: (error, _) => AksharaErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(roleDashboardLayoutProvider(layoutRole)),
              ),
              data: (layout) {
                final current = _draft ?? layout;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AksharaSpacing.s4),
                  itemCount: current.widgets.length,
                  itemBuilder: (context, index) {
                    final widget = current.widgets[index];
                    return Card(
                      key: QaTestKeys.dynamicWidgetLayoutItem(widget.id),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: Text(widget.title),
                            subtitle: Text('${widget.type.name} · ${widget.size.wireValue}'),
                            value: widget.visible,
                            onChanged: canManage
                                ? (visible) => _updateWidget(
                                      current,
                                      widget.copyWith(visible: visible),
                                    )
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AksharaSpacing.s4, AksharaSpacing.s0, AksharaSpacing.s4, AksharaSpacing.s3),
                            child: Row(
                              children: [
                                IconButton(
                                  key: QaTestKeys.dynamicWidgetLayoutMoveUp(widget.id),
                                  icon: const Icon(Icons.arrow_upward),
                                  onPressed: !canManage || index == 0
                                      ? null
                                      : () => _moveWidget(current, index, index - 1),
                                ),
                                IconButton(
                                  key: QaTestKeys.dynamicWidgetLayoutMoveDown(widget.id),
                                  icon: const Icon(Icons.arrow_downward),
                                  onPressed: !canManage || index >= current.widgets.length - 1
                                      ? null
                                      : () => _moveWidget(current, index, index + 1),
                                ),
                                const Spacer(),
                                DropdownButton<WidgetGridSize>(
                                  value: widget.size,
                                  items: WidgetGridSize.values
                                      .map(
                                        (size) => DropdownMenuItem(
                                          value: size,
                                          child: Text(size.wireValue),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: canManage
                                      ? (size) {
                                          if (size == null) return;
                                          _updateWidget(
                                            current,
                                            widget.copyWith(size: size),
                                          );
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (canManage)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AksharaSpacing.s4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: QaTestKeys.dynamicWidgetResetLayoutButton,
                        onPressed: resetState.isLoading
                            ? null
                            : () => _resetLayout(layoutRole, verticalPack),
                        child: resetState.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Reset to pack default'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: QaTestKeys.dynamicWidgetSaveLayoutButton,
                        onPressed: saveState.isLoading || _draft == null
                            ? null
                            : () => _saveLayout(layoutRole, _draft!),
                        child: saveState.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save layout'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _updateWidget(RoleDashboardLayout layout, DynamicWidgetItem updated) {
    setState(() {
      _draft = layout.copyWith(
        widgets: [
          for (final widget in layout.widgets)
            widget.id == updated.id ? updated : widget,
        ],
      );
    });
  }

  void _moveWidget(RoleDashboardLayout layout, int from, int to) {
    final widgets = List<DynamicWidgetItem>.from(layout.widgets);
    final item = widgets.removeAt(from);
    widgets.insert(to, item);
    setState(() {
      _draft = layout.copyWith(
        widgets: [
          for (var i = 0; i < widgets.length; i++)
            widgets[i].copyWith(order: i),
        ],
      );
    });
  }

  Future<void> _saveLayout(String role, RoleDashboardLayout layout) async {
    final saved = await ref.read(saveRoleDashboardLayoutProvider.notifier).execute(
          role: role,
          layout: layout,
          version: layout.version,
        );
    if (!mounted || saved == null) return;
    setState(() => _draft = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Layout saved')),
    );
  }

  Future<void> _resetLayout(String role, String verticalPack) async {
    final layout = await ref.read(resetLayoutToPackDefaultProvider.notifier).execute(
          role: role,
          verticalPack: verticalPack,
        );
    if (!mounted || layout == null) return;
    setState(() => _draft = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Layout reset to pack default')),
    );
  }
}
