export interface WidgetDefinition {
  id: string;
  title: string;
  category: string;
  requiredPermission: string;
  description?: string;
  defaultWidth: number;
  defaultHeight: number;
}

export interface DashboardWidgetPlacement {
  widgetId: string;
  order: number;
  visible: boolean;
  width: number;
  height: number;
}

export const DEFAULT_WIDGET_LAYOUT: DashboardWidgetPlacement[] = [
  { widgetId: "school_health", order: 0, visible: true, width: 2, height: 1 },
  { widgetId: "student_risk", order: 1, visible: true, width: 1, height: 1 },
  { widgetId: "fee_collection", order: 2, visible: true, width: 1, height: 1 },
  { widgetId: "attendance_risk", order: 3, visible: true, width: 1, height: 1 },
  { widgetId: "homework_summary", order: 4, visible: true, width: 1, height: 1 },
  { widgetId: "operations_summary", order: 5, visible: true, width: 2, height: 1 },
  { widgetId: "employee_workload", order: 6, visible: true, width: 1, height: 1 },
  { widgetId: "timetable_alerts", order: 7, visible: true, width: 1, height: 1 },
];
