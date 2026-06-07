import 'package:akshara_erp/core/audit/audit_event.dart';
import 'package:akshara_erp/core/audit/audit_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('audit logger stores and reads events locally', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final logger = AuditLogger(prefs);

    await logger.logTyped(
      type: AuditEventType.login,
      userId: 'user_1',
      tenantId: 'tenant_1',
      metadata: {'role': 'staff'},
    );

    final events = await logger.readAll();
    expect(events, hasLength(1));
    expect(events.first.type, AuditEventType.login);
    expect(events.first.userId, 'user_1');
  });
}
