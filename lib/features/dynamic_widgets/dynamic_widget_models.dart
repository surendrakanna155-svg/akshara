/// Widget presentation types supported by the dynamic widget platform.
enum WidgetType {
  kpi,
  chart,
  list,
  alert,
  action,
}

/// Grid placement hint for dashboard layout.
enum WidgetGridSize {
  full,
  half,
  third,
}

extension WidgetGridSizeX on WidgetGridSize {
  int get flex => switch (this) {
        WidgetGridSize.full => 12,
        WidgetGridSize.half => 6,
        WidgetGridSize.third => 4,
      };

  static WidgetGridSize fromString(String? value) => switch (value) {
        'full' => WidgetGridSize.full,
        'third' => WidgetGridSize.third,
        _ => WidgetGridSize.half,
      };

  String get wireValue => switch (this) {
        WidgetGridSize.full => 'full',
        WidgetGridSize.half => 'half',
        WidgetGridSize.third => 'third',
      };
}

extension WidgetTypeX on WidgetType {
  static WidgetType fromString(String? value) => switch (value) {
        'chart' => WidgetType.chart,
        'list' => WidgetType.list,
        'alert' => WidgetType.alert,
        'action' => WidgetType.action,
        _ => WidgetType.kpi,
      };

  String get wireValue => name;
}

/// Version metadata for a role-bound widget layout.
class WidgetLayoutVersion {
  const WidgetLayoutVersion({
    required this.layoutId,
    required this.role,
    required this.verticalPack,
    required this.version,
    this.updatedAt,
    this.isTenantOverride = false,
  });

  final String layoutId;
  final String role;
  final String verticalPack;
  final int version;
  final DateTime? updatedAt;
  final bool isTenantOverride;
}

/// Registry entry mapping a data source key to repository dispatch.
class WidgetDataSource {
  const WidgetDataSource({
    required this.key,
    required this.label,
    required this.repositoryModule,
    required this.methodName,
    required this.supportedTypes,
    required this.requiredPermission,
    this.description,
  });

  final String key;
  final String label;
  final String repositoryModule;
  final String methodName;
  final List<WidgetType> supportedTypes;
  final String requiredPermission;
  final String? description;
}

/// Optional navigation item emitted with a layout.
class DynamicWidgetNavItem {
  const DynamicWidgetNavItem({
    required this.label,
    required this.route,
    this.icon = 'dashboard',
  });

  final String label;
  final String route;
  final String icon;
}

/// Single widget placement in a role dashboard layout.
class DynamicWidgetItem {
  const DynamicWidgetItem({
    required this.id,
    required this.type,
    required this.title,
    required this.dataSource,
    required this.permissions,
    this.drillDown,
    this.size = WidgetGridSize.half,
    this.visible = true,
    this.order = 0,
  });

  final String id;
  final WidgetType type;
  final String title;
  final String dataSource;
  final List<String> permissions;
  final String? drillDown;
  final WidgetGridSize size;
  final bool visible;
  final int order;

  DynamicWidgetItem copyWith({
    WidgetType? type,
    String? title,
    String? dataSource,
    List<String>? permissions,
    String? drillDown,
    WidgetGridSize? size,
    bool? visible,
    int? order,
  }) {
    return DynamicWidgetItem(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      dataSource: dataSource ?? this.dataSource,
      permissions: permissions ?? this.permissions,
      drillDown: drillDown ?? this.drillDown,
      size: size ?? this.size,
      visible: visible ?? this.visible,
      order: order ?? this.order,
    );
  }
}

/// Resolved role-bound dashboard layout (pack default or tenant override).
class RoleDashboardLayout {
  const RoleDashboardLayout({
    required this.layoutId,
    required this.role,
    required this.verticalPack,
    required this.version,
    required this.widgets,
    this.navigation = const [],
    this.isTenantOverride = false,
  });

  final String layoutId;
  final String role;
  final String verticalPack;
  final int version;
  final List<DynamicWidgetItem> widgets;
  final List<DynamicWidgetNavItem> navigation;
  final bool isTenantOverride;

  RoleDashboardLayout copyWith({
    int? version,
    List<DynamicWidgetItem>? widgets,
    bool? isTenantOverride,
  }) {
    return RoleDashboardLayout(
      layoutId: layoutId,
      role: role,
      verticalPack: verticalPack,
      version: version ?? this.version,
      widgets: widgets ?? this.widgets,
      navigation: navigation,
      isTenantOverride: isTenantOverride ?? this.isTenantOverride,
    );
  }
}
