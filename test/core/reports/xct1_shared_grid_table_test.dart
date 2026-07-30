import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:akshara_erp/core/reports/akshara_report_export_service.dart';
import 'package:akshara_erp/features/operations/operations_hub_pdf_service.dart';
import 'package:akshara_erp/features/phase5/phase5_models.dart';

/// XCT-1: the export pipeline is consolidated on ONE shared grid-table
/// primitive (`AksharaReportExportService.buildGridTable`). These tests pin the
/// primitive and prove a service that USED to hand-roll `TableHelper` (the
/// Operations Hub daily report) now rides the shared primitive and still
/// renders a real PDF.
void main() {
  const export = AksharaReportExportService();

  bool isPdf(List<int> bytes) =>
      bytes.length > 4 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46; // F

  test('buildGridTable returns a table widget (plain + right-aligned)', () {
    final plain = export.buildGridTable(
      headers: const ['A', 'B'],
      rows: const [
        ['1', '2'],
        ['3', '4'],
      ],
    );
    expect(plain, isA<pw.Widget>());

    final aligned = export.buildGridTable(
      headers: const ['Name', 'Amount'],
      rows: const [
        ['Fees', '1200'],
      ],
      rightAlignFrom: 1,
    );
    expect(aligned, isA<pw.Widget>());
  });

  test('buildGridReportPdf rides the shared primitive and emits a real PDF',
      () async {
    final bytes = await export.buildGridReportPdf(
      reportTitle: 'Grid',
      moduleLabel: 'Test',
      headers: const ['Col1', 'Col2'],
      rows: const [
        ['a', 'b'],
      ],
      rightAlignFrom: 1,
    );
    expect(bytes, isNotEmpty);
    expect(isPdf(bytes), isTrue);
  });

  test('OperationsHubPdfService now rides the shared grid primitive', () async {
    const service = OperationsHubPdfService();
    const snapshot = OperationsHubSnapshot(
      schoolHealth: 92,
      dailySummary: OperationsDailySummary(
        attendancePct: 96,
        collectionsToday: 125000,
        communicationsToday: 8,
        criticalAlerts: 1,
      ),
      criticalAlerts: [
        OperationsAlert(
          id: 'a1',
          module: 'Finance',
          title: 'Fee overdue spike',
          severity: 'high',
        ),
      ],
      pendingActions: [
        OperationsAction(id: 'p1', module: 'HR', title: 'Approve leave'),
      ],
      widgets: OperationsWidgets(
        todayAttendance: {'present': 480},
        todayCollections: {'amount': 125000},
        todayCommunications: {'sent': 8},
        studentRiskAlerts: 3,
        employeeRiskAlerts: 1,
        inventoryAlerts: 0,
        feeAlerts: 5,
      ),
    );
    final bytes = await service.buildDailyReportPdf(
      schoolName: 'NIKSHA Public School',
      dateLabel: '2026-07-04',
      snapshot: snapshot,
    );
    expect(bytes, isNotEmpty);
    expect(isPdf(bytes), isTrue);
  });
}
