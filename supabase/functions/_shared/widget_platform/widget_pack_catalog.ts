// B11 — Dynamic Widget Platform: role/vertical-pack catalog.
//
// Reference data for the role-bound, vertical-pack dashboard contract consumed by
// the Flutter `dynamic_widgets` feature (data-source registry + per-role default
// layouts). This is the server-side source of truth that mirrors the client mock
// (`MockEvolutionRepository`) one-to-one so the live platform resolves real
// layouts instead of silently falling back to the in-app mock. Pure data + pure
// builders — no DB, no I/O.

export interface WidgetDataSourceDef {
  key: string;
  label: string;
  repositoryModule: string;
  methodName: string;
  supportedTypes: string[];
  requiredPermission: string;
  description?: string;
}

export interface DynamicWidgetItemDef {
  id: string;
  type: "kpi" | "chart" | "list" | "alert" | "action";
  title: string;
  dataSource: string;
  permissions: string[];
  drillDown?: string;
  size: "full" | "half" | "third";
  visible: boolean;
  order: number;
}

export interface DynamicWidgetNavItemDef {
  label: string;
  route: string;
  icon: string;
}

export interface RoleDashboardLayoutDef {
  layoutId: string;
  role: string;
  verticalPack: string;
  version: number;
  widgets: DynamicWidgetItemDef[];
  navigation: DynamicWidgetNavItemDef[];
  isTenantOverride: boolean;
}

/** Roles that ship a default dashboard layout in the school pack. */
export const DEFAULT_ROLES = ["principal", "schoolAdmin", "teacher", "financeAdmin"];

export const WIDGET_DATA_SOURCES: WidgetDataSourceDef[] = [
  {
    key: "operations.school_health",
    label: "School health score",
    repositoryModule: "evolution",
    methodName: "getWidgetData",
    supportedTypes: ["kpi", "chart"],
    requiredPermission: "viewOperationsHub",
    description: "Overall school health aggregate",
  },
  {
    key: "intelligence.student_risk",
    label: "Student risk alerts",
    repositoryModule: "evolution",
    methodName: "getWidgetData",
    supportedTypes: ["alert", "list"],
    requiredPermission: "viewStudentRisk",
  },
  {
    key: "finance.fee_collection",
    label: "Fee collections",
    repositoryModule: "evolution",
    methodName: "getWidgetData",
    supportedTypes: ["kpi"],
    requiredPermission: "viewFinance",
  },
  {
    key: "intelligence.attendance_risk",
    label: "Attendance risk",
    repositoryModule: "evolution",
    methodName: "getWidgetData",
    supportedTypes: ["alert", "kpi"],
    requiredPermission: "viewStudentRisk",
  },
  {
    key: "academics.homework_summary",
    label: "Homework completion",
    repositoryModule: "evolution",
    methodName: "getWidgetData",
    supportedTypes: ["kpi", "chart"],
    requiredPermission: "viewHomeworkIntelligence",
  },
  {
    key: "operations.summary",
    label: "Operations actions",
    repositoryModule: "evolution",
    methodName: "getOperationsActions",
    supportedTypes: ["list", "action"],
    requiredPermission: "viewOperationsHub",
  },
];

const NAVIGATION: DynamicWidgetNavItemDef[] = [
  { label: "Operations", route: "/operations/hub", icon: "dashboard" },
];

function schoolWidgets(role: string): DynamicWidgetItemDef[] {
  switch (role) {
    case "teacher":
      return [
        {
          id: "homework_summary",
          type: "kpi",
          title: "Homework Summary",
          dataSource: "academics.homework_summary",
          permissions: ["viewHomeworkIntelligence"],
          drillDown: "/homework-intelligence",
          size: "half",
          visible: true,
          order: 0,
        },
        {
          id: "operations_summary",
          type: "list",
          title: "Operations Summary",
          dataSource: "operations.summary",
          permissions: ["viewOperationsHub"],
          drillDown: "/operations/hub",
          size: "half",
          visible: true,
          order: 1,
        },
      ];
    case "financeAdmin":
      return [
        {
          id: "fee_collection",
          type: "kpi",
          title: "Fee Collection",
          dataSource: "finance.fee_collection",
          permissions: ["viewFinance"],
          drillDown: "/finance/dashboard",
          size: "full",
          visible: true,
          order: 0,
        },
      ];
    default:
      return [
        {
          id: "school_health",
          type: "kpi",
          title: "School Health",
          dataSource: "operations.school_health",
          permissions: ["viewOperationsHub"],
          drillDown: "/operations/hub",
          size: "half",
          visible: true,
          order: 0,
        },
        {
          id: "student_risk",
          type: "alert",
          title: "Student Risk",
          dataSource: "intelligence.student_risk",
          permissions: ["viewStudentRisk"],
          drillDown: "/intelligence/student-success",
          size: "half",
          visible: true,
          order: 1,
        },
        {
          id: "fee_collection",
          type: "kpi",
          title: "Fee Collection",
          dataSource: "finance.fee_collection",
          permissions: ["viewFinance"],
          drillDown: "/finance/dashboard",
          size: "half",
          visible: true,
          order: 2,
        },
        {
          id: "attendance_risk",
          type: "alert",
          title: "Attendance Risk",
          dataSource: "intelligence.attendance_risk",
          permissions: ["viewStudentRisk"],
          drillDown: "/sis/attendance",
          size: "half",
          visible: true,
          order: 3,
        },
      ];
  }
}

function operationsWidget(
  id: string,
  title: string,
  type: DynamicWidgetItemDef["type"],
  dataSource: string,
  order: number,
): DynamicWidgetItemDef {
  return {
    id,
    type,
    title,
    dataSource,
    permissions: ["viewOperationsHub"],
    size: "half",
    visible: true,
    order,
  };
}

function salonWidgets(): DynamicWidgetItemDef[] {
  return [
    operationsWidget("chair_utilization", "Chair Utilization", "kpi", "salon.chair_utilization", 0),
    operationsWidget("appointment_pipeline", "Appointment Pipeline", "chart", "salon.appointment_pipeline", 1),
  ];
}

function hospitalWidgets(): DynamicWidgetItemDef[] {
  return [
    operationsWidget("bed_occupancy", "Bed Occupancy", "kpi", "hospital.bed_occupancy", 0),
    operationsWidget("opd_queue", "OPD Queue", "list", "hospital.opd_queue", 1),
  ];
}

function restaurantWidgets(): DynamicWidgetItemDef[] {
  return [
    operationsWidget("active_covers", "Active Covers", "kpi", "restaurant.active_covers", 0),
    operationsWidget("ticket_time", "Kitchen Ticket Time", "alert", "restaurant.ticket_time", 1),
  ];
}

/** Builds the pack-default layout for a role + vertical pack (mirror of the mock). */
export function packDefaultLayout(role: string, verticalPack: string): RoleDashboardLayoutDef {
  const widgets = verticalPack === "salon"
    ? salonWidgets()
    : verticalPack === "hospital"
    ? hospitalWidgets()
    : verticalPack === "restaurant"
    ? restaurantWidgets()
    : schoolWidgets(role);
  return {
    layoutId: `${role}-dashboard-v1`,
    role,
    verticalPack,
    version: 1,
    widgets,
    navigation: NAVIGATION,
    isTenantOverride: false,
  };
}
