import 'package:akshara_erp/core/widgets/whatsapp_contact_button.dart';
import 'package:akshara_erp/features/admissions/leads/admissions_lead_detail_screen.dart';
import 'package:akshara_erp/features/alumni/profile/alumni_profile_screen.dart';
import 'package:akshara_erp/features/finance/defaulters/finance_defaulters_screen.dart';
import 'package:akshara_erp/features/inventory/vendors/inventory_vendors_screen.dart';
import 'package:akshara_erp/features/transport/drivers/transport_drivers_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers.dart';

// B5 — the reusable WhatsAppContactButton must be wired into each of the five
// target surfaces, rendering over mock data that carries a contact number.
Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: erpWidgetTestOverrides(),
      child: MaterialApp(
        theme: AksharaAppTheme.light(),
        home: screen,
      ),
    ),
  );
  await settleRiverpodFutures(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('B5 WhatsApp contact surfaces', () {
    testWidgets('Transport drivers screen wires WhatsApp button',
        (tester) async {
      await _pump(tester, const TransportDriversScreen());
      expect(find.byType(WhatsAppContactButton), findsWidgets);
    });

    testWidgets('Inventory vendors screen wires WhatsApp button',
        (tester) async {
      await _pump(tester, const InventoryVendorsScreen());
      expect(find.byType(WhatsAppContactButton), findsWidgets);
    });

    testWidgets('Finance defaulters screen wires WhatsApp button',
        (tester) async {
      await _pump(tester, const FinanceDefaultersScreen());
      expect(find.byType(WhatsAppContactButton), findsWidgets);
    });

    testWidgets('Alumni profile screen wires WhatsApp button', (tester) async {
      await _pump(tester, const AlumniProfileScreen(alumniId: 'ALM-001'));
      expect(find.byType(WhatsAppContactButton), findsWidgets);
    });

    testWidgets('Admissions lead detail screen wires WhatsApp button',
        (tester) async {
      await _pump(
        tester,
        const AdmissionsLeadDetailScreen(leadId: 'LD-1042'),
      );
      expect(find.byType(WhatsAppContactButton), findsWidgets);
    });
  });
}
